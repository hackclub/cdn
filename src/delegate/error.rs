use std::{
    error::Error,
    io::{Error as IoError, ErrorKind},
};

use tracing::error;
use serde_json::json;
use axum::{
    body::Body,
    http::StatusCode,
    response::{IntoResponse, Response},
};

pub struct APIError {
    pub code: StatusCode,
    pub body: Option<&'static str>,
}

impl IntoResponse for APIError {
    fn into_response(self) -> Response<Body> {
        let reason = self
            .body
            .unwrap_or(self.code.canonical_reason().unwrap_or("Unknown error"));
        error!("Status code based error: {}", reason);

        let body: Body = json!({ "error": reason }).to_string().into();

        Response::builder()
            .status(self.code)
            .header("Content-Type", "application/json")
            .body(body)
            .unwrap()
    }
}

impl<E> From<E> for APIError
where
    E: Error + Send + Sync + 'static,
{
    fn from(err: E) -> Self {
        error!("API Error: {}", err.to_string());
        APIError {
            code: StatusCode::INTERNAL_SERVER_ERROR,
            body: Some("Internal server error"),
        }
    }
}

impl From<APIError> for IoError {
    fn from(api_error: APIError) -> Self {
        IoError::new(ErrorKind::Other, api_error.body.unwrap_or("Unknown error"))
    }
}