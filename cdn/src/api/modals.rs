use std::collections::HashMap;

use serde::Serialize;
use utoipa::ToSchema;

use crate::delegate::UploadResult;

#[derive(Serialize, ToSchema)]
pub struct _LegacyInput {
    pub urls: Vec<String>,
}

#[derive(Serialize, ToSchema)]
pub struct _V1Output(pub Vec<String>);

#[derive(Serialize, ToSchema)]
pub struct _V2Output(pub HashMap<String, String>);

#[derive(Serialize, ToSchema)]
#[allow(non_snake_case)]
pub struct _V3Output {
    pub files: Vec<UploadResult>,
    pub cdnBase: String, // might as well suppress the warning cuz this is purely for docs
}

#[derive(Serialize, ToSchema)]
pub struct _SingletonInput {
    pub url: String,
}
