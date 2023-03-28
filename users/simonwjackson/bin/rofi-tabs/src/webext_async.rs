use std::net::SocketAddr;

use async_std::net::{TcpListener, TcpStream};
use async_std::channel::Receiver;
use async_tungstenite::tungstenite::Message;
use async_tungstenite::WebSocketStream;
use futures::{prelude::*, FutureExt};

use super::{GlobalTabStore, MessageT, WEBEXT_BIND_ADDR};


#[derive(Debug)]
enum ListenState {
    Connected {
        websocket_stream_future: stream::StreamFuture<stream::SplitStream<WebSocketStream<TcpStream>>>,
        websocket_stream_sink: stream::SplitSink<WebSocketStream<TcpStream>, Message>,
    },
    Disconnected
}

impl ListenState {
    pub async fn new(accept_result: std::io::Result<(TcpStream, SocketAddr)>) -> Self {
        debug!("got a connection attempt on {}", WEBEXT_BIND_ADDR);
        match accept_result {
            Ok((s, addr)) => {
                match async_tungstenite::accept_async(s).await {
                    Ok(websocket) => {
                        info!("successful connection from browser at {:?}", addr);
                        let (sink, stream) = websocket.split();
                        ListenState::Connected { websocket_stream_future: stream.into_future(), websocket_stream_sink: sink }
                    },
                    Err(_) => {
                        warn!("failed connection attempt at websocket creation");
                        ListenState::Disconnected
                    }
                }
            },
            Err(_) => {
                warn!("failed connection attempt at accept");
                ListenState::Disconnected
            }
        }
    }

    pub fn is_connected(&self) -> bool {
        match self {
            ListenState::Connected { .. } => true,
            ListenState::Disconnected => false
        }
    }

    // Maybe try to close the stream on Drop? Or is that done automatically?
}


pub async fn run(
    store: GlobalTabStore,
    recv_from_rofi: Receiver<MessageT>,
) -> Result<(), Box<dyn std::error::Error>> {

    let bound_listener: TcpListener = TcpListener::bind(WEBEXT_BIND_ADDR).await?;
    
    // ListenState implements the Unpin marker trait (because all its fields do) so we can select on `&mut contained_future`
    let mut listen_state = ListenState::Disconnected;

    // `pin_mut` pins a value on the stack so that it (redeclared to be a Pin<&mut T>) acts like a mutable reference to an unmovable future (important for async stuff)
    let f1_tcp_accept = bound_listener.accept().fuse();
    futures::pin_mut!(f1_tcp_accept);

    let f2_rofi_recv = recv_from_rofi.recv().fuse();
    futures::pin_mut!(f2_rofi_recv);
    
    loop {
        match listen_state  {
            // Move everything out of ListenState and reconstruct it in every branch to satisfy the crab
            ListenState::Connected { mut websocket_stream_future, mut websocket_stream_sink} => {
                futures::select! {
                    conn = f1_tcp_accept => {
                        f1_tcp_accept.set(bound_listener.accept().fuse());

                        let listen_state_maybe = ListenState::new(conn).await;
                        // Failed or spam connection attempts should not disrupt an existing connection
                        if listen_state_maybe.is_connected() {
                            listen_state = listen_state_maybe;
                            continue;
                        } 
                    },
                    channel_item = f2_rofi_recv => {
                        f2_rofi_recv.set(recv_from_rofi.recv().fuse());

                        match channel_item {
                            Ok(msg) => { 
                                if let Err(e) = handle_rofi_channel_message(msg, &mut websocket_stream_sink).await {
                                    error!("send to websocket_sink failed, so disconnecting: {:?}", e);
                                    listen_state = ListenState::Disconnected;
                                    continue;
                                }
                            },
                            Err(e) => {
                                error!("recv_channel broken or closed. probably unrecoverable so exiting: {:?}", e);
                                return Err(Box::new(e));
                            }
                        };
                    },
                    ws_item = &mut websocket_stream_future => {
                        let (stream_item, stream_tail) = ws_item;
                        // Oops, didn't read the documentation carefully enough
                        // https://docs.rs/futures/latest/futures/stream/trait.StreamExt.html#method.into_future
                        websocket_stream_future = stream_tail.into_future();
                        
                        match stream_item {
                            Some(Ok(Message::Text(msg))) => { handle_ws_stream_message(msg, store.clone()).await; },
                            Some(Err(e)) => { error!("read from websocket stream errored out: {:?}", e) },
                            // Must treat None as disconnection to prevent infinite loop
                            None => {
                                debug!("browser disconnected"); 
                                listen_state = ListenState::Disconnected;
                                continue;
                            },
                            z => { debug!("ignored an irrelevant item from websocket stream: {:?}", z) }
                        }
                    },
                    complete => {
                        error!("unhandleable edge case select!ng in ListenState::Connected where all futures have completed. exiting via panic! to prevent an infinite loop");
                        panic!("this is a bug and should not happen. please submit an issue on gitlab!");
                    }
                }

                listen_state = ListenState::Connected { websocket_stream_future, websocket_stream_sink };
            },
            // No active browser connection, so listen for new browser connections while discarding any tab set/get messages
            ListenState::Disconnected => {
                futures::select! {
                    conn = f1_tcp_accept => {
                        f1_tcp_accept.set(bound_listener.accept().fuse());
                        listen_state = ListenState::new(conn).await;
                        continue;    
                    },
                    msg = f2_rofi_recv => {
                        f2_rofi_recv.set(recv_from_rofi.recv().fuse());

                        info!("a message from recv_channel was dropped because there is no active browser connection: {:?}", &msg);
                        drop(msg);
                    },
                    complete => {
                        error!("unhandleable edge case select!ng in ListenState::Disconnected where all futures have completed. exiting via panic! to prevent an infinite loop");
                        panic!("this is a bug and should not happen. please submit an issue on gitlab!");
                    }
                }
            }
        }
        // maybe safeguard against rogue infinite loop slowing down system?
        // std::thread::sleep(std::time::Duration::from_millis(10));
    }
}


async fn handle_ws_stream_message(msg: String, store: GlobalTabStore) {
    // Display tab errors but ignore them as next request could be valid, possibly invalid string, etc...
    let mut store_lock = store.lock().await;

    if let Err(e) = store_lock.update_from_string(msg) {
        dbg!(e);
    }
}


// Sends SET_TAB request received with tab id from channel
async fn handle_rofi_channel_message<S: futures::Sink<Message> + Unpin>(
    msg: MessageT,
    sink: &mut S,
) -> Result<(), WebExtError> where S::Error: std::fmt::Debug {
    debug!("Got rofi channel message: {:?}", &msg);

    sink.send(Message::Text(msg)).await.map_err(|e| {
        error!("Unexpected error encountered in WebSocket stream while sending from sink: {:?}", e);
        WebExtError::SinkError
    })?;

    Ok(())
}


#[derive(Debug)]
pub enum WebExtError {
    ChannelBroken,
    SinkError,
}

impl std::error::Error for WebExtError {}

impl std::fmt::Display for WebExtError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}
