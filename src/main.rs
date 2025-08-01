mod api;
mod metrics;
mod delegate;
mod gateways;

use std::sync::LazyLock;

use utoipa::OpenApi;
use sled::{Db, open};
use dotenvy_macro::dotenv;
use tokio::net::TcpListener;
use s3::{bucket::Bucket, creds::Credentials, region::Region};
use axum::{
    Router,
    http::{HeaderValue, Request},
    middleware::{self, Next},
    response::{Response, Redirect},
    routing::{get, post},
};

use crate::metrics::metrics;

use gateways::legacy::{singleton_upload, v1_new, v2_new, v3_new};

pub(self) const DATABASE_PATH: &'static str = dotenv!("SLED_PATH");

pub(crate) const ENDPOINT: &'static str = dotenv!("AWS_ENDPOINT");
pub(crate) const CDN: &'static str = dotenv!("AWS_CDN_URL");
pub(crate) const PROD_DOMAIN: &'static str = dotenv!("PROD_DOMAIN");

pub(crate) static DATABASE: LazyLock<Db> =
    LazyLock::new(|| open(DATABASE_PATH).expect("Couldn't open the database"));

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

#[derive(OpenApi)]
#[openapi(
    paths(
        gateways::legacy::v1_new,
        gateways::legacy::v2_new,
        gateways::legacy::v3_new,
        gateways::legacy::singleton_upload
    ),
    components(schemas(
        delegate::UploadResult,
        api::modals::_LegacyInput,
        api::modals::_V1Output,
        api::modals::_V2Output,
        api::modals::_V3Output,
        api::modals::_SingletonInput
    )),
    info(
        title = "Hack Club CDN",
        version = "1.0.0",
        description = "Deep under the waves and storms there lies a [vault](https://app.slack.com/client/T0266FRGM/C016DEDUL87)",
        contact(name = "Hack Club", url = "https://hackclub.com"),
        terms_of_service = "https://hackclub.com/conduct/"
    ),
    tags(
        (name = "Legacy Endpoints", description = "Deprecated legacy upload endpoints")
    )
)]
pub struct ApiDoc;

#[tokio::main]
async fn main() {
    // preflight (ensure the metrics exist)
    if !DATABASE.contains_key("num_files").unwrap_or(false) {
        DATABASE.insert("num_files", &[0; 32]).unwrap();
    }
    if !DATABASE.contains_key("size_files").unwrap_or(false) {
        DATABASE.insert("size_files", &[0; 32]).unwrap();
    }

    let legacy = Router::new()
        .route("/v1/new", post(v1_new))
        .route("/v2/new", post(v2_new))
        .route("/v3/new", post(v3_new))
        .route("/upload", post(singleton_upload))
        .layer(middleware::from_fn(
            |req: Request<_>, next: Next| async move {
                let mut data: Response = next.run(req).await;
                data.headers_mut()
                    .insert("Deprecated", HeaderValue::from_static("true"));
                data
            },
        ));

    let docs_router = Router::new()
        .route("/docs", get(api::docs))
        .route("/openapi.json", get(api::openapi_axle))
        .route("/favicon.svg", get(api::favicon));

    let api_router = docs_router.merge(legacy);

    let redirect_router = Router::new()
        .route("/docs", get(|| async { Redirect::permanent("/api/docs") }))
        .route("/v1/docs", get(|| async { Redirect::permanent("/api/docs") }))
        .route("/v2/docs", get(|| async { Redirect::permanent("/api/docs") }))
        .route("/v3/docs", get(|| async { Redirect::permanent("/api/docs") }));

    let app = Router::new()
        .route("/", get(metrics))
        .merge(redirect_router)
        .nest("/api", api_router);

    axum::serve(
        TcpListener::bind(format!("127.0.0.1:{}", dotenv!("PORT")))
            .await
            .unwrap(),
        app,
    )
    .await
    .unwrap();
}
