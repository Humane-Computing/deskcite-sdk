use deskcite::mesgd_sdk::mesgd::{Options, SendOpts};
use deskcite::mesgd_sdk::{mesgd, PKI};
use openssl::ssl::{SslConnector, SslMethod};
use serde_json::{json, Value};
use std::{env, error::Error, sync::mpsc};

fn main() -> Result<(), Box<dyn Error>> {
    let role = env::args().nth(1).ok_or("usage: pubsub server|client")?;
    if role != "server" && role != "client" {
        return Err("usage: pubsub server|client".into());
    }
    let address = if role == "server" {
        "service"
    } else {
        "client"
    };
    let origin = env::var("MESGD_WSS")?;
    let mut connector = SslConnector::builder(SslMethod::tls())?;
    if let Ok(ca) = env::var("MESGD_CA") {
        connector.set_ca_file(ca)?;
    }
    let key_file = env::var("MESGD_KEY_FILE").unwrap_or_else(|_| format!("{role}-keys.json"));
    let identity = if std::path::Path::new(&key_file).exists() {
        PKI::init(&key_file)?
    } else {
        PKI::generate(&key_file)?
    };
    let mut conn = mesgd::connect(
        &format!("{}/to={address}", origin.trim_end_matches('/')),
        Options {
            pki: identity,
            token: env::var("MESGD_TOKEN").ok(),
            server_pub: None,
            connector: Some(connector.build()),
        },
    )?;
    let (tx, rx) = mpsc::channel::<Value>();
    let typ = if role == "server" {
        "echo.request"
    } else {
        "echo.reply"
    };
    conn.on(typ, move |message| {
        let _ = tx.send(message);
    });
    println!("ready: {role}");
    if role == "client" {
        conn.send(
            json!({"to":"service", "from":"client", "type":"echo.request",
                         "body":{"text":"hello"}}),
            SendOpts::default(),
        )?;
    }
    loop {
        conn.recv()?;
        if let Ok(message) = rx.try_recv() {
            if role == "client" {
                println!("{}", message["body"]);
                conn.close()?;
                return Ok(());
            }
            println!("agent received: {}", message["body"]);
            conn.send(
                json!({"to":message["from"], "from":"service",
                             "type":"echo.reply", "body":message["body"]}),
                SendOpts::default(),
            )?;
        }
    }
}
