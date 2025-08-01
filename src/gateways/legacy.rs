use std::collections::HashMap;

use serde_json::json;
use futures::future::try_join_all;
use axum::{Json, response::IntoResponse, http::HeaderMap};

use crate::CDN;
use crate::delegate::UploadResult;
use crate::delegate::multiplexed_uploader;
use crate::api::modals::{_V1Output, _V2Output, _V3Output};

type URLVec = Json<Vec<String>>;

#[utoipa::path(
    post,
    path = "/api/v1/new",
    request_body = Vec<String>,
    responses((status = 200, description = "Upload successful", body = _V1Output)),
    tag = "Legacy Endpoints"
)]
pub async fn v1_new(headers: HeaderMap, Json(body): URLVec) -> impl IntoResponse {
    let slack_token = headers.get("x-download-authorization").and_then(|h| h.to_str().ok());
    let results = try_join_all(
        body.iter()
            .map(|url| {
                async move { multiplexed_uploader(&url, false, slack_token.as_deref()).await }
            }),
    )
    .await;

    match results {
        Ok(results) => {
            let split: Vec<String> = results
                .into_iter()
                .map(|combo| combo.deployed_url.clone())
                .collect();
            Json(split).into_response()
        }
        Err(error) => error.into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/api/v2/new",
    request_body = Vec<String>,
    responses((status = 200, description = "Upload successful - returns fileName: fileUrl mapping", body = _V2Output)),
    tag = "Legacy Endpoints"
)]
pub async fn v2_new(headers: HeaderMap, Json(body): URLVec) -> impl IntoResponse {
    let slack_token = headers.get("x-download-authorization").and_then(|h| h.to_str().ok());
    let results = try_join_all(
        body.iter()
            .map(|url| {
                async move { multiplexed_uploader(&url, false, slack_token).await }
            }),
    )
    .await;

    match results {
        Ok(results) => {
            let split: HashMap<String, String> = results
                .into_iter()
                .map(|combo| (combo.file.clone(), combo.deployed_url.clone()))
                .collect();
            Json(split).into_response()
        }
        Err(error) => error.into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/api/v3/new",
    request_body = Vec<String>,
    responses((status = 200, description = "Upload successful", body = _V3Output)),
    tag = "Legacy Endpoints"
)]
pub async fn v3_new(headers: HeaderMap, Json(body): URLVec) -> impl IntoResponse {
    let slack_token = headers.get("x-download-authorization").and_then(|h| h.to_str().ok());
    let results = try_join_all(
        body.iter()
            .map(|url| {
                async move { multiplexed_uploader(&url, true, slack_token).await }
            }),
    )
    .await;

    match results {
        Ok(results) => Json(json!({ "files": results, "cdnBase": CDN })).into_response(),
        Err(error) => error.into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/api/upload",
    request_body = String,
    responses((status = 200, description = "Upload successful", body = UploadResult)),
    tag = "Legacy Endpoints"
)]
pub async fn singleton_upload(headers: HeaderMap, Json(body): Json<String>) -> impl IntoResponse {
    let slack_token = headers.get("x-download-authorization").and_then(|h| h.to_str().ok());
    let result = multiplexed_uploader(&body, false, slack_token).await;

    match result {
        Ok(result) => Json(result).into_response(),
        Err(error) => error.into_response(),
    }
}
