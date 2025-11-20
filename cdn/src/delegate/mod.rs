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
use crate::db::DB_POOL;

use error::APIError;

#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub(crate) struct UploadResult {
    #[serde(rename = "deployedUrl")]
    pub deployed_url: String,
    pub size: usize,
    pub file: String,
    pub sha: Option<String>,
}

pub(crate) async fn _upload_direct() {}

#[inline(always)]
pub(crate) async fn multiplexed_uploader<'a>(
    url: &'a str,
    hash: bool,
    slack: Option<&'a HeaderValue>,
    user_id: i32,
) -> Result<UploadResult, APIError> {
    let storage_uuid = Uuid::now_v7();
    let public_uuid = Uuid::now_v7();

    let mut sha1 = Context::new(&SHA1_FOR_LEGACY_USE_ONLY);
    let client = Client::builder()
        .user_agent("HackclubCDN/1.0")
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

    let storage_key = storage_uuid.to_string();
    let info = BUCKET.put_object_stream(&mut reader, &storage_key).await?;

    let sha = hash.then(|| encode(sha1.finish()));

    let filename = url
        .split('/')
        .last()
        .unwrap_or("unknown")
        .split('?')
        .next()
        .unwrap_or("unknown")
        .to_string();

    let deployed_url = format!("{}/{}", &*CDN, public_uuid);

    let db = DB_POOL.get().await.unwrap();
    db.execute(
        "INSERT INTO files (user_id, storage_uuid, public_uuid, filename, size, url, sha)
         VALUES ($1, $2, $3, $4, $5, $6, $7)",
        &[
            &user_id,
            &storage_uuid,
            &public_uuid,
            &filename,
            &(info.uploaded_bytes() as i64),
            &deployed_url,
            &sha,
        ],
    )
    .await
    .map_err(|_| APIError {
        code: StatusCode::INTERNAL_SERVER_ERROR,
        body: Some("Failed to store file metadata"),
    })?;

    let result = UploadResult {
        deployed_url,
        size: info.uploaded_bytes(),
        file: public_uuid.to_string(),
        sha,
    };

    Ok(result)
}
