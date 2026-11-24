mod tutorial_support;
use serde_json::json;
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let (c, _) = tutorial_support::load()?;
    let result = c
        .similar(json!({"text":"How do I upload a document in Deskcite?","n":3}))?
        .json()?;
    for row in result["rows"].as_array().ok_or("missing rows")? {
        println!(
            "{}\nSource: {}",
            row["answer"].as_str().ok_or("missing answer")?,
            row["path"].as_str().ok_or("missing source")?
        )
    }
    Ok(())
}
