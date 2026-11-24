mod tutorial_support;
use deskcite::Error;
fn main() -> Result<(), Box<dyn std::error::Error>> {
    std::env::var("DESKCITE_TOKEN_FILE")?;
    let (c, old) = tutorial_support::load()?;
    let reply = c.refresh()?.json()?;
    let token = reply["access_token"]
        .as_str()
        .ok_or("missing replacement")?;
    tutorial_support::store(token)?;
    c.set_token(token)?;
    c.status()?;
    c.set_token(&old)?;
    match c.status() {
        Err(Error::Http(r)) if r.status == 401 => {}
        _ => return Err("old bearer was not rejected with 401".into()),
    };
    c.set_token(token)?;
    println!("Credential rotated and saved; replacement works; old bearer rejected.");
    Ok(())
}
