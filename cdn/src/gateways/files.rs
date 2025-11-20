use axum::{
    extract::{Path, Extension},
    response::IntoResponse,
    http::StatusCode,
};
use uuid::Uuid;

use crate::db::DB_POOL;
use crate::BUCKET;

pub(crate) async fn delete_file(
    Path(public_uuid): Path<Uuid>,
    Extension(user_id): Extension<i32>,
) -> impl IntoResponse {
    let db = DB_POOL.get().await.unwrap();

    let file_data: Option<(Uuid, i32)> = db
        .query_opt(
            "SELECT storage_uuid, user_id FROM files WHERE public_uuid = $1",
            &[&public_uuid],
        )
        .await
        .ok()
        .flatten()
        .map(|row| (row.get(0), row.get(1)));

    let (storage_uuid, file_user_id) = match file_data {
        Some(data) => data,
        None => return (StatusCode::NOT_FOUND, "File not found").into_response(),
    };

    if file_user_id != user_id {
        return (StatusCode::FORBIDDEN, "You don't own this file").into_response();
    }

    match BUCKET.delete_object(&storage_uuid.to_string()).await {
        Ok(_) => {}
        Err(_) => return (StatusCode::INTERNAL_SERVER_ERROR, "Failed to delete from storage").into_response(),
    }

    match db
        .execute("DELETE FROM files WHERE public_uuid = $1", &[&public_uuid])
        .await
    {
        Ok(_) => (StatusCode::OK, "File deleted").into_response(),
        Err(_) => (StatusCode::INTERNAL_SERVER_ERROR, "Failed to delete from database").into_response(),
    }
}
