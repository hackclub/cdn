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

pub(crate) async fn init_connection() {
    let _ = DB_POOL.get().await.expect("Failed to connect to database");
}
