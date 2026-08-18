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
struct GetDataQuery {
    space: String,
    var: String,
}

#[derive(Deserialize)]
struct ClearSpaceQuery {
    space: String,
}

fn load_spaces_from_disk(
    storage_dir: &PathBuf,
) -> HashMap<String, HashMap<String, String>> {
    let mut spaces = HashMap::new();

    let entries = match fs::read_dir(storage_dir) {
        Ok(entries) => entries,
        Err(_) => return spaces,
    };

    for entry in entries.filter_map(Result::ok) {
        let path = entry.path();

        // Only process .json files
        if path.extension().and_then(|e| e.to_str()) != Some("json") {
            continue;
        }

        let space_name = match path.file_stem().and_then(|s| s.to_str()) {
            Some(name) => name.to_string(),
            None => continue,
        };

        match fs::read_to_string(&path) {
            Ok(contents) => {
                match serde_json::from_str::<HashMap<String, String>>(&contents) {
                    Ok(space_map) => {
                        println!(
                            "Loaded space '{}' with {} variables",
                            space_name,
                            space_map.len()
                        );

                        spaces.insert(space_name, space_map);
                    }
                    Err(err) => {
                        eprintln!(
                            "Failed to parse {}: {}",
                            path.display(),
                            err
                        );
                    }
                }
            }
            Err(err) => {
                eprintln!(
                    "Failed to read {}: {}",
                    path.display(),
                    err
                );
            }
        }
    }

    spaces
}

#[tokio::main]
async fn main() {
    // 1. Read ini configuration (Fallback to default if file doesn't exist)
    let storage_dir = PathBuf::from("./data_store");
    fs::create_dir_all(&storage_dir).unwrap();

//    let state = AppState {
//        storage_dir,
//        spaces_data: Arc::new(RwLock::new(HashMap::new())),
//    };

    let loaded_data = load_spaces_from_disk(&storage_dir);
    println!("Loaded {} spaces", loaded_data.len());
    let state = AppState {
      storage_dir,
      spaces_data: Arc::new(RwLock::new(loaded_data)),
    };

    // 2. Build Router
    let app = Router::new()
        .route("/", get(dashboard_handler))
        .route("/data/set", get(set_data_handler))
        .route("/data/set", post(set_data_post_handler))
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

fn set_value(
    state: &AppState,
    space: String,
    var: String,
    val: String,
) -> Result<(), String> {
    let mut lock = state.spaces_data.write().unwrap();
    let space_map = lock
        .entry(space.clone())
        .or_insert_with(HashMap::new);
    space_map.insert(var, val);

    let file_path = state.storage_dir.join(format!("{}.json", space));
    let json = serde_json::to_string_pretty(&*space_map)
        .map_err(|e| e.to_string())?;
    fs::write(file_path, json)
        .map_err(|e| e.to_string())?;
    Ok(())
}


// Handler: /data/set?space=some_space&var=server1_svc_stopped&val=true
async fn set_data_handler(
    State(state): State<AppState>,
    Query(query): Query<SetDataQuery>,
) -> impl IntoResponse {
    match set_value(&state, payload.space, payload.var, payload.val) {
        Ok(_) => Json(serde_json::json!({ "status": "ok" })),
        Err(e) => Json(serde_json::json!({
            "status": "error",
            "message": e
        })),
    }
}

async fn set_data_post_handler(
    State(state): State<AppState>,
    Json(query): Json<SetDataQuery>,
) -> impl IntoResponse {
    match set_value(&state, payload.space, payload.var, payload.val) {
        Ok(_) => Json(serde_json::json!({ "status": "ok" })),
        Err(e) => Json(serde_json::json!({
            "status": "error",
            "message": e
        })),
    }
//    set_value( &state, payload.space, payload.var, payload.val, );
//    Json(serde_json::json!({ "status": "ok" }))
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
