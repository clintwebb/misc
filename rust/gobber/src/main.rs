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
    path::Path,
    path::PathBuf,
    sync::{Arc, RwLock},
};

#[derive(Debug, Clone)]
struct ServerConfig {
    host: String,
    port: u16,
    storage_dir: PathBuf,
}

impl Default for ServerConfig {
    fn default() -> Self {
        Self {
            host: "0.0.0.0".to_string(),
            port: 8080,
            storage_dir: PathBuf::from("/data/goober"),
        }
    }
}

// use std::path::{Path, PathBuf};

fn find_config_file() -> Option<PathBuf> {
    let local = PathBuf::from("./goober.ini");
    if local.exists() {
        return Some(local);
    }

    let etc_single = PathBuf::from("/etc/goober.ini");
    if etc_single.exists() {
        return Some(etc_single);
    }

    let etc_dir = Path::new("/etc/goober");

    if etc_dir.exists() && etc_dir.is_dir() {
        if let Ok(entries) = fs::read_dir(etc_dir) {
            for entry in entries.flatten() {
                let path = entry.path();

                if path.extension().and_then(|s| s.to_str()) == Some("ini") {
                    return Some(path);
                }
            }
        }
    }

    None
}

use configparser::ini::Ini;

fn load_config() -> ServerConfig {
    let mut cfg = ServerConfig::default();

    let Some(config_file) = find_config_file() else {
        println!("No configuration file found, using defaults");
        return cfg;
    };

    println!("Loading config from {}", config_file.display());

    let mut ini = configparser::ini::Ini::new();

    match ini.load(config_file.to_string_lossy().as_ref()) {
        Ok(_) => {
            if let Some(host) = ini.get("Server", "Host") {
                cfg.host = host;
            }

            if let Some(port) = ini.get("Server", "Port") {
                if let Ok(port) = port.parse::<u16>() {
                    cfg.port = port;
                }
            }

            if let Some(storage) = ini.get("Server", "Storage") {
                cfg.storage_dir = PathBuf::from(storage);
            }
        }
        Err(e) => {
            eprintln!("Failed to load config: {}", e);
        }
    }

    cfg
}

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
    let config = load_config();

    println!("Host: {}", config.host);
    println!("Port: {}", config.port);
    println!("Storage: {}", config.storage_dir.display());

    let storage_dir = config.storage_dir.clone();

    fs::create_dir_all(&storage_dir).unwrap();

    let loaded_data = load_spaces_from_disk(&storage_dir);

    println!("Loaded {} spaces", loaded_data.len());

    let state = AppState {
        storage_dir,
        spaces_data: Arc::new(RwLock::new(loaded_data)),
    };

    let app = Router::new()
        .route("/", get(dashboard_handler))
        .route("/data/set", get(set_data_handler))
        .route("/data/set", post(set_data_post_handler))
        .route("/data/get", get(get_data_handler))
        .route("/data/clear", get(clear_data_handler))
        .with_state(state);

    let bind_addr = format!("{}:{}", config.host, config.port);

    println!("Binding to {}", bind_addr);

    let listener = tokio::net::TcpListener::bind(&bind_addr)
        .await
        .unwrap();

    axum::serve(listener, app)
        .await
        .unwrap();
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
    Query(payload): Query<SetDataQuery>,
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
    Json(payload): Json<SetDataQuery>,
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
