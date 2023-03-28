use super::{GlobalTabStore, MessageT, ROFI_BIND_ADDR};

// Conflicting implementations for IO
// use futures::prelude::*;
use async_std::net::{TcpListener, TcpStream};
use async_std::prelude::*;
use async_std::channel::Sender;
use async_std::task;
use futures::FutureExt;

const BUF_SIZE: usize = 1024;

pub async fn run(
    store: GlobalTabStore,
    send_to_webext: Sender<MessageT>,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut tcp_task_handles = Vec::new();
    let listener: TcpListener = TcpListener::bind(ROFI_BIND_ADDR).await?;

    // Errors in a specific listener should not crash the whole program
    loop {
        let stream: TcpStream = match listener.accept().await {
            Ok((s, addr)) => {
                debug!("Connection from Rofi at {:?}", addr);
                s
            }
            Err(e) => {
                error!("Failed to accept connection from Rofi script: {:?}", e);
                continue;
            }
        };

        tcp_task_handles.push(task::spawn(
            handle_tcp_stream(stream, send_to_webext.clone(), store.clone()).map(|result| {
                if let Err(e) = result {
                    warn!("TCP stream task terminated with error message: {}", e);
                }
            }),
        ));
    }
}

// The error type of this function doesn't matter (fails transparently). No point doing proper error handling
// Returns a string representation of the error because Send requirement (due to task::spawn) means Box<dyn Error> won't work
async fn handle_tcp_stream(
    mut stream: TcpStream,
    send_to_webext: Sender<MessageT>,
    store: GlobalTabStore,
) -> Result<(), String> {
    let stream_request: String = read_stream(&mut stream).await.map_err(debug_error)?;
    debug!("Got request from Rofi: {}", &stream_request);

    // Obtain Mutex lock inside if branches to avoid deadlock on await

    if stream_request.starts_with("GET") {
        let tabs_json_string = {
            let store_lock = store.lock().await;
            store_lock.to_string()
        };
        stream
            .write(tabs_json_string.as_bytes())
            .await
            .map_err(debug_error)?;
        stream.flush().await.map_err(debug_error)?;
    } else if stream_request.starts_with("SET ") {
        let tab_name = &stream_request[4..];
        if tab_name.len() == 0 {
            return Err(format!("SET request empty"));
        }

        let tab = {
            let store_lock = store.lock().await;
            store_lock.get_by_name(tab_name)
        };

        let tab_id = tab.map(|t| t.id.to_string()).map_err(debug_error)?;

        // channel must not be full, would prevent TcpStream from shutting down, making rofi hang
        send_to_webext.send(tab_id).await;
    } else {
        return Err(format!("Invalid request: {}", &stream_request));
    }

    stream
        .shutdown(async_std::net::Shutdown::Both)
        .map_err(debug_error)?;
    
    debug!("handle_tcp_stream finished");
    Ok(())
}

async fn read_stream(stream: &mut TcpStream) -> Result<String, Box<dyn std::error::Error>> {
    let mut data: Vec<u8> = Vec::new();
    let mut buffer: [u8; BUF_SIZE] = [0; BUF_SIZE];

    loop {
        let bytes_read = stream.read(&mut buffer).await?;
        if bytes_read == BUF_SIZE {
            data.extend_from_slice(&buffer);
        } else {
            data.extend_from_slice(&buffer[0..bytes_read]);
            break;
        }
    }

    Ok(String::from_utf8(data)?)
}

fn debug_error(e: impl std::fmt::Debug) -> String {
    format!("{:?}", e)
}
