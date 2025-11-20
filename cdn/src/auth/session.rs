use std::collections::HashMap;
use std::sync::LazyLock;
use tokio::sync::Mutex;
use base64::{Engine, engine::general_purpose::STANDARD};

pub(crate) static SESSION_STORE: LazyLock<Mutex<HashMap<String, i32>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

pub(crate) fn generate_session_token() -> String {
    use ring::rand::{SystemRandom, SecureRandom};
    let rng = SystemRandom::new();
    let mut token = [0u8; 32];
    rng.fill(&mut token).unwrap();
    STANDARD.encode(token)
}

pub(crate) async fn get_user_from_session(session_token: &str) -> Option<i32> {
    SESSION_STORE.lock().await.get(session_token).copied()
}
