mod db;

use std::env;
use std::sync::LazyLock;
use tokio::net::TcpListener;
use tracing_subscriber::fmt;
use uuid::Uuid;
use axum::{
    Router,
    extract::Path,
    response::{Response, IntoResponse},
    http::{StatusCode, header},
    routing::get,
};
use reqwest::Client;

use crate::db::DB_POOL;

fn get_env(key: &str) -> String {
    env::var(key).unwrap_or_else(|_| panic!("{} must be set", key))
}

pub(crate) static HETZNER_BASE_URL: LazyLock<String> = LazyLock::new(|| get_env("HETZNER_BASE_URL"));

static HTTP_CLIENT: LazyLock<Client> = LazyLock::new(|| {
    Client::builder()
        .build()
        .expect("Failed to create HTTP client")
});

async fn proxy_file(Path(public_uuid): Path<Uuid>) -> impl IntoResponse {
    let db = DB_POOL.get().await.unwrap();

    let storage_uuid: Option<Uuid> = db
        .query_opt(
            "SELECT storage_uuid FROM files WHERE public_uuid = $1",
            &[&public_uuid],
        )
        .await
        .ok()
        .flatten()
        .map(|row| row.get(0));

    let storage_uuid = match storage_uuid {
        Some(uuid) => uuid,
        None => return (StatusCode::NOT_FOUND, "File not found").into_response(),
    };

    let hetzner_url = format!("{}/{}", *HETZNER_BASE_URL, storage_uuid);

    match HTTP_CLIENT.get(&hetzner_url).send().await {
        Ok(response) => {
            let status = response.status();
            let headers = response.headers().clone();

            let body = match response.bytes().await {
                Ok(bytes) => bytes,
                Err(_) => return (StatusCode::INTERNAL_SERVER_ERROR, "Failed to read file").into_response(),
            };

            let mut resp = Response::builder().status(status);

            for (key, value) in headers.iter() {
                if key != header::HOST && key != header::CONNECTION {
                    resp = resp.header(key, value);
                }
            }

            match resp.body(axum::body::Body::from(body)) {
                Ok(r) => r.into_response(),
                Err(_) => (StatusCode::INTERNAL_SERVER_ERROR, "Failed to build response").into_response(),
            }
        }
        Err(_) => (StatusCode::BAD_GATEWAY, "Failed to fetch from storage").into_response(),
    }
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    fmt::init();

    db::init_connection().await;

    let app = Router::new().route("/{uuid}", get(proxy_file));

    let port = get_env("HETZNER_PROXY_PORT");
    axum::serve(
        TcpListener::bind(format!("0.0.0.0:{}", port))
            .await
            .unwrap(),
        app,
    )
    .await
    .unwrap();
}
