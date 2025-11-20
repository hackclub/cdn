use maud::{html, Markup};
use axum::{
    extract::Extension,
    response::{Html, IntoResponse, Redirect},
    http::{StatusCode, HeaderMap},
    Json,
};
use serde::Serialize;

use crate::db::DB_POOL;
use crate::db::schema::{User, File};
use crate::auth::session::get_user_from_session;

#[derive(Serialize)]
pub(crate) struct DashboardData {
    user: User,
    total_files: i64,
    total_size: i64,
    files: Vec<File>,
}

pub(crate) async fn dashboard(headers: HeaderMap) -> impl IntoResponse {
    let session_token = headers
        .get("cookie")
        .and_then(|v| v.to_str().ok())
        .and_then(|cookies| {
            cookies
                .split(';')
                .find(|c| c.trim().starts_with("session="))
                .map(|c| c.trim().trim_start_matches("session="))
        });

    let user_id = match session_token {
        Some(token) => match get_user_from_session(token).await {
            Some(id) => id,
            None => return Redirect::to("/auth/login").into_response(),
        },
        None => return Redirect::to("/auth/login").into_response(),
    };

    let db = DB_POOL.get().await.unwrap();

    let user: User = match db
        .query_one(
            "SELECT id, slack_id, slack_username, slack_avatar, api_key, created_at FROM users WHERE id = $1",
            &[&user_id],
        )
        .await
    {
        Ok(row) => User {
            id: row.get(0),
            slack_id: row.get(1),
            slack_username: row.get(2),
            slack_avatar: row.get(3),
            api_key: row.get(4),
            created_at: row.get(5),
        },
        Err(_) => return (StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user").into_response(),
    };

    let files: Vec<File> = match db
        .query(
            "SELECT id, user_id, storage_uuid, public_uuid, filename, size, url, sha, created_at
             FROM files WHERE user_id = $1 ORDER BY created_at DESC",
            &[&user_id],
        )
        .await
    {
        Ok(rows) => rows
            .iter()
            .map(|row| File {
                id: row.get(0),
                user_id: row.get(1),
                storage_uuid: row.get(2),
                public_uuid: row.get(3),
                filename: row.get(4),
                size: row.get(5),
                url: row.get(6),
                sha: row.get(7),
                created_at: row.get(8),
            })
            .collect(),
        Err(_) => vec![],
    };

    let total_files = files.len() as i64;
    let total_size: i64 = files.iter().map(|f| f.size).sum();

    Html(render_dashboard(&user, total_files, total_size, &files).into_string()).into_response()
}

fn render_dashboard(user: &User, total_files: i64, total_size: i64, files: &[File]) -> Markup {
    let size_mb = total_size as f64 / 1048576.0;

    html! {
        html {
            head {
                title { "Dashboard - Hack Club CDN" }
                link rel="icon" type="image/svg+xml" href="/api/favicon.svg" {}
                style {
                    "@font-face {
                        font-family: 'Phantom Sans';
                        src: url('https://assets.hackclub.com/fonts/Phantom_Sans_0.7/Regular.woff') format('woff'),
                             url('https://assets.hackclub.com/fonts/Phantom_Sans_0.7/Regular.woff2') format('woff2');
                        font-weight: normal;
                        font-style: normal;
                        font-display: swap;
                    }
                    body {
                        font-family: 'Phantom Sans', sans-serif;
                        background: #0a0a0a;
                        color: #ffffff;
                        padding: 2rem;
                        max-width: 1200px;
                        margin: 0 auto;
                    }
                    .header {
                        display: flex;
                        justify-content: space-between;
                        align-items: center;
                        margin-bottom: 2rem;
                    }
                    .user-info {
                        display: flex;
                        align-items: center;
                        gap: 1rem;
                    }
                    .avatar {
                        width: 48px;
                        height: 48px;
                        border-radius: 50%;
                    }
                    .stats {
                        display: grid;
                        grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                        gap: 1rem;
                        margin-bottom: 2rem;
                    }
                    .stat-card {
                        background: #1a1a1a;
                        padding: 1.5rem;
                        border-radius: 8px;
                    }
                    .api-key-section {
                        background: #1a1a1a;
                        padding: 1.5rem;
                        border-radius: 8px;
                        margin-bottom: 2rem;
                    }
                    .api-key {
                        font-family: monospace;
                        background: #0a0a0a;
                        padding: 0.5rem;
                        border-radius: 4px;
                        word-break: break-all;
                    }
                    .files-table {
                        width: 100%;
                        border-collapse: collapse;
                        background: #1a1a1a;
                        border-radius: 8px;
                        overflow: hidden;
                    }
                    .files-table th,
                    .files-table td {
                        padding: 1rem;
                        text-align: left;
                        border-bottom: 1px solid #333;
                    }
                    .files-table th {
                        background: #222;
                    }
                    a { color: #ec3750; text-decoration: none; }
                    a:hover { text-decoration: underline; }
                    button {
                        background: #ec3750;
                        color: white;
                        border: none;
                        padding: 0.5rem 1rem;
                        border-radius: 4px;
                        cursor: pointer;
                    }
                    button:hover { background: #d63447; }
                    .delete-btn {
                        background: #ff6b6b;
                        padding: 0.25rem 0.75rem;
                        font-size: 0.875rem;
                    }"
                }
            }
            body {
                div class="header" {
                    div class="user-info" {
                        @if let Some(avatar) = &user.slack_avatar {
                            img class="avatar" src=(avatar) alt="Avatar" {}
                        }
                        div {
                            h1 { "Welcome, " (user.slack_username) }
                            p { a href="/auth/logout" { "Logout" } }
                        }
                    }
                    a href="/" { "← Back to Metrics" }
                }

                div class="stats" {
                    div class="stat-card" {
                        h3 { "Total Files" }
                        p style="font-size: 2rem;" { (total_files) }
                    }
                    div class="stat-card" {
                        h3 { "Total Size" }
                        p style="font-size: 2rem;" { (format!("{:.2} MB", size_mb)) }
                    }
                }

                div class="api-key-section" {
                    h2 { "Your API Key" }
                    p { "Use this key in the " code { "x-api-key" } " header when uploading files." }
                    div class="api-key" { (user.api_key) }
                }

                h2 { "Your Files" }
                @if files.is_empty() {
                    p { "No files uploaded yet." }
                } @else {
                    table class="files-table" {
                        thead {
                            tr {
                                th { "Filename" }
                                th { "Size" }
                                th { "URL" }
                                th { "Uploaded" }
                                th { "Actions" }
                            }
                        }
                        tbody {
                            @for file in files {
                                tr {
                                    td { (file.filename) }
                                    td { (format!("{:.2} KB", file.size as f64 / 1024.0)) }
                                    td { a href=(file.url) target="_blank" { "View" } }
                                    td { (file.created_at.format("%Y-%m-%d %H:%M")) }
                                    td {
                                        button class="delete-btn" onclick=(format!("deleteFile('{}')", file.public_uuid)) {
                                            "Delete"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                script {
                    "async function deleteFile(uuid) {
                        if (!confirm('Are you sure you want to delete this file?')) return;
                        const response = await fetch(`/api/files/${uuid}`, {
                            method: 'DELETE',
                            headers: { 'x-api-key': '" (user.api_key) "' }
                        });
                        if (response.ok) {
                            window.location.reload();
                        } else {
                            alert('Failed to delete file');
                        }
                    }"
                }
            }
        }
    }
}

pub(crate) async fn regenerate_api_key(Extension(user_id): Extension<i32>) -> impl IntoResponse {
    use ring::rand::{SystemRandom, SecureRandom};
    use base64::{Engine, engine::general_purpose::STANDARD};

    let rng = SystemRandom::new();
    let mut key = [0u8; 32];
    rng.fill(&mut key).unwrap();
    let new_api_key = STANDARD.encode(key);

    let db = DB_POOL.get().await.unwrap();

    match db
        .execute(
            "UPDATE users SET api_key = $1 WHERE id = $2",
            &[&new_api_key, &user_id],
        )
        .await
    {
        Ok(_) => Json(serde_json::json!({ "api_key": new_api_key })).into_response(),
        Err(_) => (StatusCode::INTERNAL_SERVER_ERROR, "Failed to regenerate API key").into_response(),
    }
}
