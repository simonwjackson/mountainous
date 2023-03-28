#[macro_use]
extern crate serde_derive;

#[macro_use]
extern crate log;

mod tabs;
mod tcp_async;
mod webext_async;

use async_std::sync::{Arc, Mutex};
use async_std::channel::unbounded;
use async_std::task;
use futures::prelude::*;

type GlobalTabStore = Arc<Mutex<tabs::TabStore>>;
type MessageT = String;

const WEBEXT_BIND_ADDR: &'static str = "127.0.0.1:8081";
const ROFI_BIND_ADDR: &'static str = "127.0.0.1:8082";

async fn main_async() {
    let store: GlobalTabStore = Arc::new(Mutex::new(tabs::TabStore::new()));
    let (send, recv) = unbounded::<MessageT>();

    let (xrun_result, pending_future) = future::select(
        tcp_async::run(store.clone(), send).boxed(),
        webext_async::run(store.clone(), recv).boxed(),
    )
    .await
    .factor_first();

    drop(pending_future);
    xrun_result.expect("Program terminated with error");
}

fn init_logging() {
    #[cfg(debug_assertions)]
    let level = log::LevelFilter::Debug;

    #[cfg(not(debug_assertions))]
    let level = log::LevelFilter::Info;

    pretty_env_logger::formatted_timed_builder()
        .filter_module("rofi_server", level)
        .init();
}

fn main() {
    init_logging();
    info!("Starting rofi_server");
    debug!("Debug logging is enabled");
    
    task::block_on(main_async());
}
