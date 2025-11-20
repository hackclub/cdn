use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub(crate) struct User {
    pub id: i32,
    pub slack_id: String,
    pub slack_username: String,
    pub slack_avatar: Option<String>,
    pub api_key: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub(crate) struct File {
    pub id: i32,
    pub user_id: i32,
    pub storage_uuid: Uuid,
    pub public_uuid: Uuid,
    pub filename: String,
    pub size: i64,
    pub url: String,
    pub sha: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub(crate) struct FileStats {
    pub total_files: i64,
    pub total_size: i64,
    pub files: Vec<File>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub(crate) struct DailyUpload {
    pub date: String,
    pub count: i64,
    pub size: i64,
}
