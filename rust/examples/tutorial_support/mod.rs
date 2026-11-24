use deskcite::Client;
use std::{
    env,
    error::Error,
    fs::{self, OpenOptions},
    io::Write,
    os::unix::fs::OpenOptionsExt,
    path::Path,
};
pub fn load() -> Result<(Client, String), Box<dyn Error>> {
    let token = if let Ok(path) = env::var("DESKCITE_TOKEN_FILE") {
        fs::read_to_string(path)?.trim().to_owned()
    } else {
        env::var("DESKCITE_TOKEN")?
    };
    let mut c = Client::new(&env::var("DESKCITE_URL")?, &token)?;
    c.ca_file = env::var("DESKCITE_CA").ok();
    Ok((c, token))
}
#[allow(dead_code)]
pub fn store(token: &str) -> Result<(), Box<dyn Error>> {
    let target = env::var("DESKCITE_TOKEN_FILE")?;
    let p = Path::new(&target);
    let temp = p
        .parent()
        .ok_or("missing parent")?
        .join(format!(".rotate-{}", std::process::id()));
    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(&temp)?;
    let result = (|| -> Result<(), Box<dyn Error>> {
        writeln!(file, "{token}")?;
        file.sync_all()?;
        fs::rename(&temp, p)?;
        Ok(())
    })();
    if result.is_err() {
        let _ = fs::remove_file(temp);
    }
    result
}
