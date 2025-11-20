mod api;
mod auth;
mod dashboard;
mod db;
mod delegate;
mod gateways;
mod metrics;

use std::sync::LazyLock;
use std::env;
use utoipa::OpenApi;
use tokio::net::TcpListener;
use tracing_subscriber::fmt;
use s3::{bucket::Bucket, creds::Credentials, region::Region};
use axum::{
    Router,
    http::{HeaderValue, Request},
    middleware::{self, Next},
    response::{Response, Redirect},
    routing::{get, post, delete},
};

use crate::metrics::metrics;
use crate::auth::middleware::require_api_key;
use crate::gateways::legacy::{singleton_upload, v1_new, v2_new, v3_new};
use crate::gateways::files::delete_file;
use crate::auth::{login, callback, logout};
use crate::dashboard::{dashboard, regenerate_api_key};

fn get_env(key: &str) -> String {
    env::var(key).unwrap_or_else(|_| panic!("{} must be set", key))
}

pub(crate) static ENDPOINT: LazyLock<String> = LazyLock::new(|| get_env("AWS_ENDPOINT"));
pub(crate) static CDN: LazyLock<String> = LazyLock::new(|| get_env("AWS_CDN_URL"));
pub(crate) static PROD_DOMAIN: LazyLock<String> = LazyLock::new(|| get_env("PROD_DOMAIN"));

pub(crate) static BUCKET: LazyLock<Box<Bucket>> = LazyLock::new(|| {
    Bucket::new(
        &get_env("AWS_BUCKET_NAME"),
        Region::Custom {
            region: get_env("AWS_REGION"),
            endpoint: get_env("AWS_ENDPOINT"),
        },
        Credentials::new(
            Some(&get_env("AWS_ACCESS_KEY_ID")),
            Some(&get_env("AWS_SECRET_ACCESS_KEY")),
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
    dotenvy::dotenv().ok();
    fmt::init();

    db::init_schema().await;

    let legacy = Router::new()
        .route("/v1/new", post(v1_new))
        .route("/v2/new", post(v2_new))
        .route("/v3/new", post(v3_new))
        .layer(middleware::from_fn(
            |req: Request<_>, next: Next| async move {
                let mut data: Response = next.run(req).await;
                data.headers_mut()
                    .insert("Deprecated", HeaderValue::from_static("true"));
                data
            },
        ))
        .layer(middleware::from_fn(require_api_key));

    let docs_router = Router::new()
        .route("/docs", get(api::docs))
        .route("/favicon.svg", get(api::favicon))
        .route("/openapi.json", get(api::openapi_axle));

    let protected_api = Router::new()
        .route("/files/{uuid}", delete(delete_file))
        .layer(middleware::from_fn(require_api_key));

    let api_router = docs_router
        .merge(legacy)
        .merge(protected_api);

    let auth_router = Router::new()
        .route("/login", get(login))
        .route("/callback", get(callback))
        .route("/logout", get(logout));

    let dashboard_router = Router::new()
        .route("/", get(dashboard))
        .route("/regenerate-key", post(regenerate_api_key));

    let redirect_router = Router::new()
        .route("/docs", get(|| async { Redirect::permanent("/api/docs") }))
        .route("/v1/docs", get(|| async { Redirect::permanent("/api/docs") }))
        .route("/v2/docs", get(|| async { Redirect::permanent("/api/docs") }))
        .route("/v3/docs", get(|| async { Redirect::permanent("/api/docs") }));

    let upload_router = Router::new()
        .route("/upload", post(singleton_upload))
        .layer(middleware::from_fn(require_api_key));

    let app = Router::new()
        .route("/", get(metrics))
        .nest("/api", api_router)
        .nest("/auth", auth_router)
        .nest("/dashboard", dashboard_router)
        .merge(upload_router)
        .merge(redirect_router);

    let port = get_env("PORT");
    axum::serve(
        TcpListener::bind(format!("0.0.0.0:{}", port))
            .await
            .unwrap(),
        app,
    )
    .await
    .unwrap();
}
