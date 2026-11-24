//! Deskcite product API. HTTPS uses the shared libcurl engine; event
//! connections delegate to mesgd-pki. No automatic refresh or request replay.
pub use mesgd_pki as mesgd_sdk;
use mesgd_pki::mesgd;
use serde_json::Value;
use std::ffi::{c_char, c_int, c_long, CString};
use std::sync::{Once, OnceLock, RwLock};

#[repr(C)]
struct NativeResponse {
    status: c_long,
    body: *mut u8,
    body_len: usize,
    headers: *mut u8,
    headers_len: usize,
}
extern "C" {
    fn dc_origin_valid(origin: *const c_char) -> c_int;
    fn dc_http(
        origin: *const c_char,
        token: *const c_char,
        method: *const c_char,
        path: *const c_char,
        payload: *const c_char,
        ca: *const c_char,
        timeout: c_long,
        out: *mut NativeResponse,
    ) -> c_int;
    fn dc_response_free(out: *mut NativeResponse);
    fn curl_global_init(flags: c_long) -> c_int;
}
#[derive(Debug)]
pub struct Response {
    pub status: u16,
    pub headers: String,
    pub body: Vec<u8>,
}
impl Response {
    pub fn json(&self) -> Result<Value, serde_json::Error> {
        serde_json::from_slice(&self.body)
    }
}
#[derive(Debug)]
pub enum Error {
    InvalidInput,
    Transport(i32),
    Http(Response),
    Json(serde_json::Error),
}
impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::InvalidInput => write!(f, "invalid Deskcite input"),
            Self::Transport(c) => write!(f, "Deskcite transport error {c}"),
            Self::Http(r) => write!(f, "Deskcite HTTP {}", r.status),
            Self::Json(e) => e.fmt(f),
        }
    }
}
impl std::error::Error for Error {}
fn cstring(s: &str) -> Result<CString, Error> {
    CString::new(s).map_err(|_| Error::InvalidInput)
}
fn token_valid(t: &str) -> bool {
    !t.is_empty() && t.bytes().all(|b| (33..127).contains(&b))
}
fn quote(s: &str) -> String {
    s.bytes()
        .map(|b| {
            if b.is_ascii_alphanumeric() || b"-_.~".contains(&b) {
                (b as char).to_string()
            } else {
                format!("%{b:02X}")
            }
        })
        .collect()
}
fn document_path(path: &str) -> Result<String, Error> {
    if !path.starts_with("/deskcite/documents/")
        || path
            .bytes()
            .any(|b| b <= 32 || b == 127 || b"?#\\".contains(&b))
    {
        return Err(Error::InvalidInput);
    }
    let mut bytes = Vec::new();
    let p = path.as_bytes();
    let mut i = 0;
    while i < p.len() {
        if p[i] == b'%' {
            if i + 2 >= p.len() {
                return Err(Error::InvalidInput);
            }
            let hex = std::str::from_utf8(&p[i + 1..i + 3]).map_err(|_| Error::InvalidInput)?;
            bytes.push(u8::from_str_radix(hex, 16).map_err(|_| Error::InvalidInput)?);
            i += 3;
        } else {
            bytes.push(p[i]);
            i += 1;
        }
    }
    if bytes.iter().any(|b| *b < 32 || *b == 127 || *b == b'\\')
        || bytes.split(|b| *b == b'/').any(|s| s == b"." || s == b"..")
    {
        return Err(Error::InvalidInput);
    }
    Ok(path.into())
}
pub struct Client {
    origin: CString,
    token: RwLock<String>,
    pub ca_file: Option<String>,
    pub timeout_ms: c_long,
}
impl Client {
    pub fn new(origin: &str, token: &str) -> Result<Self, Error> {
        static INIT: Once = Once::new();
        INIT.call_once(|| assert_eq!(unsafe { curl_global_init(3) }, 0));
        let origin = cstring(origin.trim_end_matches('/'))?;
        if unsafe { dc_origin_valid(origin.as_ptr()) } != 1 || !token_valid(token) {
            return Err(Error::InvalidInput);
        }
        Ok(Self {
            origin,
            token: RwLock::new(token.into()),
            ca_file: None,
            timeout_ms: 30000,
        })
    }
    pub fn set_token(&self, token: &str) -> Result<(), Error> {
        if !token_valid(token) {
            return Err(Error::InvalidInput);
        }
        *self.token.write().unwrap() = token.into();
        Ok(())
    }
    pub fn call(&self, operation: &str, args: Value) -> Result<Response, Error> {
        static OPS: OnceLock<Value> = OnceLock::new();
        let ops =
            OPS.get_or_init(|| serde_json::from_str(include_str!("operations.json")).unwrap());
        let spec = ops.get(operation).ok_or(Error::InvalidInput)?;
        let fields = args.as_object().ok_or(Error::InvalidInput)?;
        let mut path = spec["path"].as_str().unwrap().to_string();
        match spec["kind"].as_str().unwrap() {
            "id" => {
                let id = args["id"]
                    .as_str()
                    .filter(|s| !s.is_empty())
                    .ok_or(Error::InvalidInput)?;
                path.push_str(&quote(id));
            }
            "document" => path = document_path(args["path"].as_str().ok_or(Error::InvalidInput)?)?,
            "none" if !fields.is_empty() => return Err(Error::InvalidInput),
            _ => (),
        }
        let payload = if spec["kind"] == "json" {
            Some(cstring(&args.to_string())?)
        } else {
            None
        };
        let method = cstring(spec["method"].as_str().unwrap())?;
        let path = cstring(&path)?;
        let token = cstring(&self.token.read().unwrap())?;
        let ca = self.ca_file.as_ref().map(|s| cstring(s)).transpose()?;
        let mut raw = NativeResponse {
            status: 0,
            body: std::ptr::null_mut(),
            body_len: 0,
            headers: std::ptr::null_mut(),
            headers_len: 0,
        };
        let result = unsafe {
            dc_http(
                self.origin.as_ptr(),
                token.as_ptr(),
                method.as_ptr(),
                path.as_ptr(),
                payload.as_ref().map_or(std::ptr::null(), |s| s.as_ptr()),
                ca.as_ref().map_or(std::ptr::null(), |s| s.as_ptr()),
                self.timeout_ms,
                &mut raw,
            )
        };
        if result != 0 {
            return Err(Error::Transport(result));
        }
        let body = if raw.body_len == 0 {
            Vec::new()
        } else {
            unsafe { std::slice::from_raw_parts(raw.body, raw.body_len) }.to_vec()
        };
        let headers = if raw.headers_len == 0 {
            String::new()
        } else {
            String::from_utf8_lossy(unsafe {
                std::slice::from_raw_parts(raw.headers, raw.headers_len)
            })
            .into_owned()
        };
        let response = Response {
            status: raw.status as u16,
            headers,
            body,
        };
        unsafe { dc_response_free(&mut raw) };
        if !(200..300).contains(&response.status) {
            return Err(Error::Http(response));
        }
        Ok(response)
    }
    pub fn question(&self, id: &str) -> Result<Response, Error> {
        self.call("question", serde_json::json!({"id":id}))
    }
    pub fn document(&self, path: &str) -> Result<Response, Error> {
        self.call("document", serde_json::json!({"path":path}))
    }
    pub fn events<F: FnMut(Value) + 'static>(
        &self,
        handler: F,
        mut options: mesgd::Options,
    ) -> Result<mesgd::Conn, Box<dyn std::error::Error>> {
        options.token = Some(self.token.read().unwrap().clone());
        let url = format!(
            "wss://{}/deskcite/events",
            self.origin.to_str()?.trim_start_matches("https://")
        );
        let mut conn = mesgd::connect(&url, options)?;
        conn.on("*", handler);
        Ok(conn)
    }
}
include!("operations.rs");
