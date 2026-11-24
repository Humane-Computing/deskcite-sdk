fn main() {
    println!("cargo:rerun-if-changed=../c/deskcite_http.c");
    println!("cargo:rerun-if-changed=../c/deskcite_http.h");
    cc::Build::new()
        .file("../c/deskcite_http.c")
        .include("../c")
        .compile("deskcite_http");
    println!("cargo:rustc-link-lib=curl");
}
