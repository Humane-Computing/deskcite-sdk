use deskcite::{mesgd_sdk, Client, Error};
use serde_json::{json, Value};
#[test]
fn input() {
    assert!(Client::new("http://example.test", "token").is_err());
    assert!(Client::new("https://u@example.test", "token").is_err());
    assert!(Client::new("https://example.test", "bad\r\ntoken").is_err());
    let c = Client::new("https://example.test", "token").unwrap();
    assert!(matches!(
        c.document("/deskcite/documents/%2e%2e/x"),
        Err(Error::InvalidInput)
    ));
}
#[test]
fn live() -> Result<(), Box<dyn std::error::Error>> {
    let Ok(origin) = std::env::var("DS_TEST_URL") else {
        return Ok(());
    };
    let ca = std::env::var("DS_TEST_CA")?;
    let mut c = Client::new(&origin, "test-bearer")?;
    c.ca_file = Some(ca.clone());
    let ops: Value = serde_json::from_str(include_str!("../../api/operations.json"))?;
    for (op, spec) in ops.as_object().unwrap() {
        if ["refresh", "question", "document"].contains(&op.as_str()) {
            continue;
        }
        let args = if spec["kind"] == "json" {
            json!({"text":"café & ?","q":"test","action":"calendar"})
        } else {
            json!({})
        };
        assert_eq!(c.call(op, args)?.json()?["ok"], true);
    }
    assert!(c.question("id/ ?#")?.json()?["path"]
        .as_str()
        .unwrap()
        .ends_with("id%2F%20%3F%23"));
    assert_eq!(
        c.document("/deskcite/documents/a%20b.pdf")?.body,
        vec![0, 255, 10]
    );
    for (text, status) in [("__error__", 503), ("__redirect__", 302)] {
        match c.similar(json!({"text":text})) {
            Err(Error::Http(r)) => {
                assert_eq!(r.status, status);
                assert!(!r.body.is_empty());
            }
            _ => panic!("expected HTTP error"),
        }
    }
    c.set_token(c.refresh()?.json()?["access_token"].as_str().unwrap())?;
    assert_eq!(c.status()?.json()?["credential"], "rotated");
    let mut connector = openssl::ssl::SslConnector::builder(openssl::ssl::SslMethod::tls())?;
    connector.set_ca_file(ca)?;
    let pki = mesgd_sdk::PKI::generate(&std::env::var("DS_TEST_KEY_FILE")?)?;
    let event = std::rc::Rc::new(std::cell::RefCell::new(Value::Null));
    let received = event.clone();
    let mut conn = c.events(
        move |m| *received.borrow_mut() = m,
        mesgd_sdk::mesgd::Options {
            pki,
            token: None,
            server_pub: None,
            connector: Some(connector.build()),
        },
    )?;
    conn.recv()?;
    assert_eq!(event.borrow()["type"], "import.done");
    conn.close()?;
    Ok(())
}
