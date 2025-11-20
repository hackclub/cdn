pub(crate) mod schema;

use std::env;
use std::sync::LazyLock;
use deadpool_postgres::{Config, Pool, Runtime, ManagerConfig, RecyclingMethod};
use tokio_postgres::NoTls;

pub(crate) static DB_POOL: LazyLock<Pool> = LazyLock::new(|| {
    let mut cfg = Config::new();
    cfg.url = Some(env::var("DATABASE_URL").expect("DATABASE_URL must be set"));
    cfg.manager = Some(ManagerConfig {
        recycling_method: RecyclingMethod::Fast,
    });
    cfg.create_pool(Some(Runtime::Tokio1), NoTls).unwrap()
});

pub(crate) async fn init_schema() {
    let client = DB_POOL.get().await.unwrap();

    client.execute(
        "CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            slack_id VARCHAR(255) UNIQUE NOT NULL,
            slack_username VARCHAR(255) NOT NULL,
            slack_avatar TEXT,
            api_key VARCHAR(64) UNIQUE NOT NULL,
            created_at TIMESTAMPTZ DEFAULT NOW()
        )",
        &[],
    ).await.unwrap();

    client.execute(
        "CREATE TABLE IF NOT EXISTS files (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            storage_uuid UUID NOT NULL,
            public_uuid UUID UNIQUE NOT NULL,
            filename TEXT NOT NULL,
            size BIGINT NOT NULL,
            url TEXT NOT NULL,
            sha TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW()
        )",
        &[],
    ).await.unwrap();

    client.execute(
        "CREATE INDEX IF NOT EXISTS idx_files_user_id ON files(user_id)",
        &[],
    ).await.unwrap();

    client.execute(
        "CREATE INDEX IF NOT EXISTS idx_files_public_uuid ON files(public_uuid)",
        &[],
    ).await.unwrap();

    client.execute(
        "CREATE INDEX IF NOT EXISTS idx_users_api_key ON users(api_key)",
        &[],
    ).await.unwrap();
}
