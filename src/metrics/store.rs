use tracing::{error, info};
use serde::{Deserialize, Serialize};
use bincode::{
    config,
    serde::{decode_from_slice, encode_to_vec},
};

use crate::DATABASE;
use crate::delegate::UploadResult;

#[derive(Serialize, Deserialize, Debug)]
struct Counter(u64);

#[derive(Serialize, Deserialize, Debug)]
struct FileSize(usize);

fn increment_totals(size: usize) {
    let _ = DATABASE.fetch_and_update("num_files", |current_bytes| {
        let (mut counter, _) =
            decode_from_slice::<Counter, _>(current_bytes.unwrap(), config::standard()).unwrap();
        counter.0 += 1;
        Some(encode_to_vec(counter, config::standard()).unwrap())
    });

    let _ = DATABASE.fetch_and_update("size_files", |current_bytes| {
        let (mut file_size, _) =
            decode_from_slice::<FileSize, _>(current_bytes.unwrap(), config::standard()).unwrap();
        file_size.0 += size;
        Some(encode_to_vec(file_size, config::standard()).unwrap())
    });
}

pub async fn get_totals() -> (u64, usize) {
    let (size_files, _) = decode_from_slice::<FileSize, _>(
        &DATABASE.get("size_files").unwrap().unwrap(),
        config::standard(),
    )
    .unwrap();
    let (num_files, _) = decode_from_slice::<Counter, _>(
        &DATABASE.get("num_files").unwrap().unwrap(),
        config::standard(),
    )
    .unwrap();
    (num_files.0, size_files.0)
}

pub async fn store_file(result: &UploadResult) {
    let bytes = match encode_to_vec(&result, config::standard()) {
        Ok(b) => b,
        Err(e) => {
            error!("Could not encode UploadResult for '{result:?}': {e}");
            return;
        }
    };

    if let Err(e) = DATABASE.insert(&result.file, bytes) {
        error!("Failed to insert {result:?} into sled: {e}");
        return;
    }

    increment_totals(result.size);

    info!("Stored file successfully: {result:?}");
}
