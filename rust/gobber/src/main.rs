use axum::{
    extract::{Json, Query, State},
    response::{Html, IntoResponse},
    routing::{get, post},
    Router,
};
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    fs,
    path::PathBuf,
    sync::{Arc, RwLock},
};

#[derive(Clone)]
struct AppState {
    storage_dir: PathBuf,
    // In-memory key-value map per space: HashMap<space_name, HashMap<var_name, String>>
    spaces_data: Arc<RwLock<HashMap<String, HashMap<String, String>>>>,
}

#[derive(Deserialize)]
struct SetDataQuery {
    space: String,
    var: String,
    val: String,
}
#[derive(Deserialize)]
struct SetDataRequest {
    space: String,
    var: String,
    val: String,
}

#[derive(Deserialize)]
struct GetDataQuery {
    space: String,
    var: String,
}

#[derive(Deserialize)]
struct ClearSpaceQuery {
    space: String,
}

#[tokio::main]
async fn main() {
    // 1. Read ini configuration (Fallback to default if file doesn't exist)
    let storage_dir = PathBuf::from("./data_store");
    fs::create_dir_all(&storage_dir).unwrap();

    let state = AppState {
        storage_dir,
        spaces_data: Arc::new(RwLock::new(HashMap::new())),
    };

    // 2. Build Router
    let app = Router::new()
        .route("/", get(dashboard_handler))
        .route("/data/set", get(set_data_handler).post(set_data_handler))
        .route("/data/get", get(get_data_handler))
        .route("/data/clear", get(clear_data_handler))
        .with_state(state);

    // 3. Start Web Server
    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await.unwrap();
    println!("Server running on http://0.0.0.0:8080");
    axum::serve(listener, app).await.unwrap();
}

// Handler: Basic Web UI Dashboard
async fn dashboard_handler() -> Html<&'static str> {
    Html(
        r#"
        <!DOCTYPE html>
        <html>
        <head><title>Coordination Service Dashboard</title></head>
        <body>
            <h1>Server Coordination Dashboard</h1>
            <p>Status: Active</p>
        </body>
        </html>
    "#,
    )
}

// Handler: /data/set?space=some_space&var=server1_svc_stopped&val=true
async fn set_data_handler(
    State(state): State<AppState>,
    Query(query): Query<SetDataQuery>,
) -> impl IntoResponse {
    let mut lock = state.spaces_data.write().unwrap();
    let space_map = lock.entry(query.space.clone()).or_insert_with(HashMap::new);
    space_map.insert(query.var.clone(), query.val.clone());

    // Flush to disk file
    let file_path = state.storage_dir.join(format!("{}.json", query.space));
    if let Ok(json) = serde_json::to_string_pretty(&*space_map) {
        let _ = fs::write(file_path, json);
    }

    Json(serde_json::json!({ "status": "ok" }))
}




// Handler: /data/get?space=some_space&var=server1_svc_stopped
async fn get_data_handler(
    State(state): State<AppState>,
    Query(query): Query<GetDataQuery>,
) -> impl IntoResponse {
    let lock = state.spaces_data.read().unwrap();
    let val = lock
        .get(&query.space)
        .and_then(|space_map| space_map.get(&query.var))
        .cloned()
        .unwrap_or_else(|| "undefined".to_string());

    Json(serde_json::json!({ "value": val }))
}

// Handler: /data/clear?space=some_space
async fn clear_data_handler(
    State(state): State<AppState>,
    Query(query): Query<ClearSpaceQuery>,
) -> impl IntoResponse {
    let mut lock = state.spaces_data.write().unwrap();
    if let Some(space_map) = lock.get_mut(&query.space) {
        space_map.clear();
    }

    let file_path = state.storage_dir.join(format!("{}.json", query.space));
    let _ = fs::remove_file(file_path);

    Json(serde_json::json!({ "status": "space_cleared" }))
}
