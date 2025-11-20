pub(crate) mod oauth;
pub(crate) mod session;
pub(crate) mod middleware;

use axum::{
    extract::Query,
    response::{IntoResponse, Redirect},
    http::{StatusCode, header, HeaderMap},
};
use serde::Deserialize;
use oauth2::{
    AuthorizationCode, CsrfToken, Scope,
    TokenResponse, reqwest::async_http_client,
};
use base64::{Engine, engine::general_purpose::STANDARD};

use crate::db::DB_POOL;
use crate::auth::oauth::OAUTH_CLIENT;
use crate::auth::session::{generate_session_token, SESSION_STORE};

#[derive(Debug, Deserialize)]
pub(crate) struct AuthRequest {
    code: String,
    state: String,
}

#[derive(Debug, Deserialize)]
struct SlackUserInfo {
    ok: bool,
    user: SlackUser,
}

#[derive(Debug, Deserialize)]
struct SlackUser {
    id: String,
    name: String,
    profile: SlackProfile,
}

#[derive(Debug, Deserialize)]
struct SlackProfile {
    image_512: Option<String>,
}

pub(crate) async fn login() -> impl IntoResponse {
    let (auth_url, _csrf_token) = OAUTH_CLIENT
        .authorize_url(CsrfToken::new_random)
        .add_scope(Scope::new("users:read".to_string()))
        .url();

    Redirect::to(auth_url.as_str())
}

pub(crate) async fn callback(Query(params): Query<AuthRequest>) -> impl IntoResponse {
    let token_result = OAUTH_CLIENT
        .exchange_code(AuthorizationCode::new(params.code))
        .request_async(async_http_client)
        .await;

    let token = match token_result {
        Ok(t) => t,
        Err(_) => return (StatusCode::INTERNAL_SERVER_ERROR, "Failed to exchange code").into_response(),
    };

    let client = reqwest::Client::new();
    let user_info: SlackUserInfo = match client
        .get("https://slack.com/api/users.identity")
        .bearer_auth(token.access_token().secret())
        .send()
        .await
    {
        Ok(resp) => match resp.json().await {
            Ok(info) => info,
            Err(_) => return (StatusCode::INTERNAL_SERVER_ERROR, "Failed to parse user info").into_response(),
        },
        Err(_) => return (StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user info").into_response(),
    };

    if !user_info.ok {
        return (StatusCode::UNAUTHORIZED, "Slack authentication failed").into_response();
    }

    let db = DB_POOL.get().await.unwrap();

    let api_key = generate_api_key();

    let user_id: i32 = match db.query_one(
        "INSERT INTO users (slack_id, slack_username, slack_avatar, api_key)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (slack_id) DO UPDATE
         SET slack_username = EXCLUDED.slack_username,
             slack_avatar = EXCLUDED.slack_avatar
         RETURNING id",
        &[&user_info.user.id, &user_info.user.name, &user_info.user.profile.image_512, &api_key],
    ).await {
        Ok(row) => row.get(0),
        Err(_) => return (StatusCode::INTERNAL_SERVER_ERROR, "Database error").into_response(),
    };

    let session_token = generate_session_token();
    SESSION_STORE.lock().await.insert(session_token.clone(), user_id);

    let mut headers = HeaderMap::new();
    headers.insert(
        header::SET_COOKIE,
        format!("session={}; Path=/; HttpOnly; SameSite=Lax; Max-Age=2592000", session_token)
            .parse()
            .unwrap(),
    );

    (headers, Redirect::to("/dashboard")).into_response()
}

fn generate_api_key() -> String {
    use ring::rand::{SystemRandom, SecureRandom};
    let rng = SystemRandom::new();
    let mut key = [0u8; 32];
    rng.fill(&mut key).unwrap();
    STANDARD.encode(key)
}

pub(crate) async fn logout() -> impl IntoResponse {
    let mut headers = HeaderMap::new();
    headers.insert(
        header::SET_COOKIE,
        "session=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0"
            .parse()
            .unwrap(),
    );
    (headers, Redirect::to("/")).into_response()
}
