use std::env;
use std::sync::LazyLock;
use oauth2::{
    basic::BasicClient, AuthUrl, ClientId, ClientSecret, RedirectUrl, TokenUrl,
};

pub(crate) static OAUTH_CLIENT: LazyLock<BasicClient> = LazyLock::new(|| {
    BasicClient::new(
        ClientId::new(env::var("SLACK_CLIENT_ID").expect("SLACK_CLIENT_ID must be set")),
        Some(ClientSecret::new(env::var("SLACK_CLIENT_SECRET").expect("SLACK_CLIENT_SECRET must be set"))),
        AuthUrl::new("https://slack.com/oauth/authorize".to_string()).unwrap(),
        Some(TokenUrl::new("https://slack.com/api/oauth.access".to_string()).unwrap()),
    )
    .set_redirect_uri(RedirectUrl::new(env::var("SLACK_REDIRECT_URI").expect("SLACK_REDIRECT_URI must be set")).unwrap())
});
