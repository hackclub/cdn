pub(crate) mod modals;

use maud::html;
use utoipa::{OpenApi, openapi::ServerBuilder};
use axum::{
    Json,
    http::{StatusCode, header},
    response::{Html, IntoResponse},
};

use crate::ApiDoc;
use crate::PROD_DOMAIN;

pub(crate) async fn docs() -> impl IntoResponse {
    Html(html! {
        html {
            head {
                title { "Hack Club CDN Documentation" }
                link rel="icon" href="/api/favicon.svg" {}
                script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference" {}
            }
            body {
                div id="app" {}
                script {
                    "const app = Scalar.createApiReference('#app', { url: '/api/openapi.json', hideDownloadButton: true, hideClientButton: true, hideModels: true });"
                }
            }
        }
    }.into_string())
}

pub(crate) async fn openapi_axle() -> impl IntoResponse {
    let mut openapi = ApiDoc::openapi();

    openapi.servers = Some(vec![
        ServerBuilder::new()
            .url(PROD_DOMAIN.clone())
            .description(Some("Production"))
            .build(),
    ]);
    Json(openapi)
}

pub(crate) async fn favicon() -> impl IntoResponse {
    const FAVICON_SVG: &[u8] = include_bytes!("../../media/icon-rounded.svg");

    (
        StatusCode::OK,
        [(header::CONTENT_TYPE, "image/svg+xml")],
        FAVICON_SVG,
    )
}
