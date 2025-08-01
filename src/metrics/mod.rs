pub(crate) mod store;

use maud::html;
use store::get_totals;
use axum::response::{Html, IntoResponse};

pub(crate) async fn metrics() -> impl IntoResponse {
    let (num_files, size_files) = get_totals().await;

    // mb conversion cuz no one is reading bytes!!
    let size_mb = size_files as f64 / 1048576.0;

    Html(html! {
        html {
            head {
                title { "CDN Metrics" }
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
                    }
                    h1 { margin-bottom: 1rem; }
                    ul { margin-bottom: 1rem; }
                    p { margin: 0.1rem; }
                    a { color: #ec3750; }"
                }
            }
            body {
                h1 { "CDN Metrics" }
                ul {
                    li { "Files stored: " (num_files) }
                    li { "Total size: " (format!("{:.2} MB", size_mb)) " (" (size_files) " bytes)" }
                }
                p { 
                    "Docs available " a href="/api/docs" { "here" } 
                }
                p {
                    "Repo available " a href="https://github.com/hackclub/cdn" { "here" }
                }
            }
        }
    }.into_string())
}
