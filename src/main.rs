mod delegate;
mod metrics;

use std::sync::LazyLock;

use axum::Router;
use dotenvy_macro::dotenv;
use tokio::net::TcpListener;
use s3::{bucket::Bucket, creds::Credentials, region::Region};

pub(crate) const ENDPOINT: &'static str = dotenv!("AWS_ENDPOINT");

pub(crate) static BUCKET: LazyLock<Box<Bucket>> = LazyLock::new(|| {
    Bucket::new(
        dotenv!("AWS_BUCKET_NAME"),
        Region::Custom {
            region: dotenv!("AWS_REGION").to_string(),
            endpoint: ENDPOINT.to_string(),
        },
        Credentials::new(
            Some(dotenv!("AWS_ACCESS_KEY_ID")),
            Some(dotenv!("AWS_SECRET_ACCESS_KEY")),
            None,
            None,
            None,
        )
        .unwrap(),
    )
    .unwrap()
});

#[tokio::main]
async fn main() {
    let app = Router::new();

    axum::serve(
        TcpListener::bind(format!("127.0.0.1:{}", dotenv!("PORT")))
            .await
            .unwrap(),
        app,
    )
    .await
    .unwrap();
}