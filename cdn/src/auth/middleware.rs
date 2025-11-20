use axum::{
    extract::Request,
    middleware::Next,
    response::{Response, IntoResponse},
    http::{StatusCode, HeaderMap},
};

use crate::db::DB_POOL;

pub(crate) async fn require_api_key(
    headers: HeaderMap,
    mut request: Request,
    next: Next,
) -> Result<Response, impl IntoResponse> {
    let api_key = headers
        .get("x-api-key")
        .and_then(|v| v.to_str().ok());

    let api_key = match api_key {
        Some(key) => key,
        None => return Err((StatusCode::UNAUTHORIZED, "API key required")),
    };

    let db = DB_POOL.get().await.unwrap();

    let user_id: Option<i32> = db
        .query_opt("SELECT id FROM users WHERE api_key = $1", &[&api_key])
        .await
        .ok()
        .flatten()
        .map(|row| row.get(0));

    match user_id {
        Some(id) => {
            request.extensions_mut().insert(id);
            Ok(next.run(request).await)
        }
        None => Err((StatusCode::UNAUTHORIZED, "Invalid API key")),
    }
}
