pub(crate) mod error;

use uuid::Uuid;
use hex::encode;
use reqwest::Client;
use utoipa::ToSchema;
use futures::TryStreamExt;
use tokio_util::io::StreamReader;
use serde::{Deserialize, Serialize};
use axum::http::{HeaderValue, StatusCode};
use ring::digest::{Context, SHA1_FOR_LEGACY_USE_ONLY};

use crate::CDN;
use crate::BUCKET;
use crate::metrics::store::store_file;

use error::APIError;

#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub(crate) struct UploadResult {
    #[serde(rename = "deployedUrl")]
    pub deployed_url: String,
    pub size: usize,
    pub file: String,
    pub sha: Option<String>,
}

// later
pub(crate) async fn _upload_direct() {}

#[inline(always)]
pub(crate) async fn multiplexed_uploader<'a>(
    url: &'a str,
    hash: bool,
    slack: Option<&'a HeaderValue>,
) -> Result<UploadResult, APIError> {
    let key = Uuid::now_v7().to_string();

    let mut sha1 = Context::new(&SHA1_FOR_LEGACY_USE_ONLY);
    let client = Client::builder()
        .user_agent("Hackclub/CDN")
        .build()?;

    let mut request = client.get(url);
    
    if url.contains("files.slack.com") {
        match slack {
            Some(token) => {
                request = request.header("Authorization", format!("Bearer {}", token.to_str()?));
            }
            None => {
                return Err(APIError {
                    code: StatusCode::BAD_REQUEST,
                    body: Some("x-download-authorization is required to download Slack files!"),
                });
            }
        }
    }
    
    let mut reader = StreamReader::new(
        request
            .send()
            .await?
            .bytes_stream()
            .map_err(APIError::from)
            .map_ok(|chunk| {
                if hash {
                    sha1.update(&chunk);
                }
                chunk
            }),
    );

    let info = BUCKET.put_object_stream(&mut reader, &key).await?;

    let sha = hash.then(|| encode(sha1.finish()));

    let result = UploadResult {
        deployed_url: format!("{CDN}/{key}"),
        size: info.uploaded_bytes(),
        file: key,
        sha,
    };

    store_file(&result).await;

    Ok(result)
}
