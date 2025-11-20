use maud::html;
use axum::{
    response::{Html, IntoResponse},
    http::HeaderMap,
};

use crate::db::DB_POOL;
use crate::auth::session::get_user_from_session;

pub(crate) async fn metrics(headers: HeaderMap) -> impl IntoResponse {
    let db = DB_POOL.get().await.unwrap();

    let total_files: i64 = match db.query_one("SELECT COUNT(*) FROM files", &[]).await {
        Ok(row) => row.try_get::<_, i64>(0).unwrap_or(0),
        Err(_) => 0,
    };

    let total_size: i64 = match db.query_one("SELECT COALESCE(SUM(size), 0) FROM files", &[]).await {
        Ok(row) => row.try_get::<_, i64>(0).unwrap_or(0),
        Err(_) => 0,
    };

    let daily_stats: Vec<(String, i64)> = db
        .query(
            "SELECT DATE(created_at) as date, COUNT(*) as count
             FROM files
             WHERE created_at >= NOW() - INTERVAL '30 days'
             GROUP BY DATE(created_at)
             ORDER BY date",
            &[],
        )
        .await
        .map(|rows| {
            rows.iter()
                .map(|row| {
                    let date: chrono::NaiveDate = row.get(0);
                    let count: i64 = row.get(1);
                    (date.to_string(), count)
                })
                .collect()
        })
        .unwrap_or_default();

    let session_token = headers
        .get("cookie")
        .and_then(|v| v.to_str().ok())
        .and_then(|cookies| {
            cookies
                .split(';')
                .find(|c| c.trim().starts_with("session="))
                .map(|c| c.trim().trim_start_matches("session="))
        });

    let user_info: Option<(String, Option<String>)> = match session_token {
        Some(token) => match get_user_from_session(token).await {
            Some(user_id) => {
                db.query_one(
                    "SELECT slack_username, slack_avatar FROM users WHERE id = $1",
                    &[&user_id],
                )
                .await
                .ok()
                .map(|row| (row.get(0), row.get(1)))
            }
            None => None,
        },
        None => None,
    };

    let size_mb = total_size as f64 / 1048576.0;

    Html(html! {
        html {
            head {
                title { "CDN Metrics" }
                link rel="icon" type="image/svg+xml" href="/api/favicon.svg" {}
                script src="https://cdn.jsdelivr.net/npm/chart.js" {}
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
                    .user-section {
                        display: flex;
                        align-items: center;
                        gap: 1rem;
                    }
                    .avatar {
                        width: 40px;
                        height: 40px;
                        border-radius: 50%;
                    }
                    .login-btn {
                        background: #ec3750;
                        color: white;
                        padding: 0.5rem 1rem;
                        border-radius: 4px;
                        text-decoration: none;
                        display: inline-block;
                    }
                    .login-btn:hover {
                        background: #d63447;
                    }
                    h1 { margin-bottom: 1rem; }
                    ul { margin-bottom: 1rem; }
                    p { margin: 0.5rem 0; }
                    a { color: #ec3750; text-decoration: none; }
                    a:hover { text-decoration: underline; }
                    .chart-container {
                        background: #1a1a1a;
                        padding: 2rem;
                        border-radius: 8px;
                        margin: 2rem 0;
                    }
                    canvas {
                        max-height: 300px;
                    }"
                }
            }
            body {
                div class="header" {
                    h1 { "CDN Metrics" }
                    div class="user-section" {
                        @if let Some((username, avatar)) = &user_info {
                            @if let Some(avatar_url) = avatar {
                                img class="avatar" src=(avatar_url) alt="Avatar" {}
                            }
                            span { (username) }
                            a href="/dashboard" { "Dashboard" }
                        } @else {
                            a class="login-btn" href="/auth/login" { "Login with Slack" }
                        }
                    }
                }

                ul {
                    li { "Files stored: " (total_files) }
                    li { "Total size: " (format!("{:.2} MB", size_mb)) " (" (total_size) " bytes)" }
                }

                div class="chart-container" {
                    h2 { "Daily Uploads (Last 30 Days)" }
                    canvas id="uploadsChart" {}
                }

                p {
                    "Docs available " a href="/api/docs" { "here" }
                }
                p {
                    "Repo available " a href="https://github.com/hackclub/cdn" { "here" }
                }

                script {
                    "const ctx = document.getElementById('uploadsChart');
                    const labels = " (serde_json::to_string(&daily_stats.iter().map(|(d, _)| d).collect::<Vec<_>>()).unwrap()) ";
                    const data = " (serde_json::to_string(&daily_stats.iter().map(|(_, c)| c).collect::<Vec<_>>()).unwrap()) ";
                    new Chart(ctx, {
                        type: 'line',
                        data: {
                            labels: labels,
                            datasets: [{
                                label: 'Uploads',
                                data: data,
                                borderColor: '#ec3750',
                                backgroundColor: 'rgba(236, 55, 80, 0.1)',
                                tension: 0.3,
                                fill: true
                            }]
                        },
                        options: {
                            responsive: true,
                            maintainAspectRatio: true,
                            plugins: {
                                legend: {
                                    labels: { color: '#ffffff' }
                                }
                            },
                            scales: {
                                y: {
                                    beginAtZero: true,
                                    ticks: { color: '#ffffff' },
                                    grid: { color: '#333' }
                                },
                                x: {
                                    ticks: { color: '#ffffff' },
                                    grid: { color: '#333' }
                                }
                            }
                        }
                    });"
                }
            }
        }
    }.into_string())
}
