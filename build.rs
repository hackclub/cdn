fn main() {
    println!("cargo:rerun-if-changed=.env"); // dotenvy macro doesn't trigger rebuild if .env changed
}
