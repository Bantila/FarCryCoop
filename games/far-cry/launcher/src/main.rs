// FarCryCoop launcher: a lobby where friends see each other's shirt color and loadout, then the
// host starts the game for everyone; or wait for a Steam invite. Talks to the game only through
// files the mod already reads: Mods\FarCryCoop\prefs.lua (COOP ClientStuff) and
// Mods\FarCryCoop\join.txt (FarCryCoopNet.asi runs its one console line).
// Lives in the game folder, next to Bin32.
#![windows_subsystem = "windows"]

mod lobby;

use serde_json::Value;
use std::path::PathBuf;
use std::process::Command;
use tauri::AppHandle;

const WEAPONS: [&str; 10] = ["Falcon", "MP5", "P90", "M4", "AG36", "OICW", "Shotgun", "SniperRifle", "M249", "RL"];

fn exe_dir() -> PathBuf {
    std::env::current_exe().unwrap().parent().unwrap().to_path_buf()
}

// Bin32 folder of the game. The launcher lives in the game folder, not in Bin32: Windows loads
// DLLs from the exe's folder first, and the game's old version.dll / dbghelp.dll there crashed it.
// FARCRYCOOP_GAME points to the game folder for development.
fn bin32() -> Result<PathBuf, String> {
    let dev = PathBuf::from(std::env::var("FARCRYCOOP_GAME").unwrap_or_default());
    [exe_dir(), dev]
        .iter()
        .map(|d| d.join("Bin32"))
        .find(|b| b.join("FarCry.exe").exists())
        .ok_or_else(|| "FarCry.exe not found: put the launcher into the Far Cry folder (next to Bin32)".into())
}

fn mod_dir() -> Result<PathBuf, String> {
    Ok(bin32()?.parent().unwrap().join("Mods").join("FarCryCoop"))
}

#[tauri::command]
fn load_settings() -> String {
    std::fs::read_to_string(exe_dir().join("FarCryCoopLauncher.json")).unwrap_or_else(|_| "{}".into())
}

#[tauri::command]
fn save_settings(json: String) -> Result<(), String> {
    std::fs::write(exe_dir().join("FarCryCoopLauncher.json"), json).map_err(|e| e.to_string())
}

// our player as saved by the UI: name, color, weapons
fn me() -> Value {
    lobby::clean_me(&serde_json::from_str(&load_settings()).unwrap_or_default())
}

// default player name: p_name from the game's system.cfg
#[tauri::command]
fn game_name() -> String {
    let cfg = bin32().map(|b| b.parent().unwrap().join("system.cfg")).unwrap_or_default();
    std::fs::read_to_string(cfg)
        .unwrap_or_default()
        .lines()
        .find_map(|l| l.trim().strip_prefix("p_name").map(|r| r.trim_start_matches([' ', '=']).trim_matches('"').to_string()))
        .unwrap_or_default()
}

// campaign levels: folders of Levels without the multiplayer maps
#[tauri::command]
fn list_maps() -> Result<Vec<String>, String> {
    let levels = bin32()?.parent().unwrap().join("Levels");
    let mut maps: Vec<String> = std::fs::read_dir(&levels)
        .map_err(|e| format!("{}: {}", levels.display(), e))?
        .filter_map(|e| e.ok())
        .filter(|e| e.path().is_dir())
        .map(|e| e.file_name().to_string_lossy().into_owned())
        .filter(|n| !n.to_lowercase().starts_with("mp_") && n != "Demo" && n != "newcontrol")
        .collect();
    maps.sort();
    Ok(maps)
}

// the line goes into the game console as is: allow only map name characters
fn host_line(map: &str) -> Result<String, String> {
    if map.is_empty() || !map.chars().all(|c| c.is_ascii_alphanumeric() || c == '_') {
        return Err("bad map".into());
    }
    Ok(format!("#CoopMap(\"{}\")", map))
}

fn write_join(line: &str) -> Result<(), String> {
    std::fs::write(mod_dir()?.join("join.txt"), line).map_err(|e| e.to_string())
}

// write prefs.lua, then start the Steam bridge and the game; `line` runs in the game console
fn start_game(me: &Value, loadout: bool, line: Option<String>) -> Result<(), String> {
    let bin = bin32()?;
    let moddir = mod_dir()?;
    let weapons: Vec<&str> = me["weapons"].as_array().map(|a| a.iter().filter_map(|w| w.as_str()).collect()).unwrap_or_default();
    // Lua 4 reads it: plain ASCII, no BOM
    let prefs = format!(
        "COOP_Color={}\r\nCOOP_Weapons=\"{}\"\r\nCOOP_LoadoutMode={}\r\n",
        me["color"].as_u64().unwrap_or(1),
        weapons.join(" "),
        loadout as u8
    );
    std::fs::write(moddir.join("prefs.lua"), prefs).map_err(|e| e.to_string())?;
    match line {
        Some(l) => write_join(&l)?,
        None => {
            let _ = std::fs::remove_file(moddir.join("join.txt")); // an old line must not run
        }
    }
    let steam = moddir.join("Steam");
    if steam.join("FarCryCoopSteam.exe").exists() {
        Command::new(steam.join("FarCryCoopSteam.exe")).current_dir(&steam).spawn().map_err(|e| e.to_string())?;
    }
    Command::new(bin.join("FarCry.exe"))
        .args(["-DEVMODE", "-MOD:FarCryCoop"])
        .current_dir(&bin)
        .spawn()
        .map_err(|e| e.to_string())?;
    Ok(())
}

// wait for a Steam invite: the bridge writes join.txt when the player accepts it
#[tauri::command]
fn launch_steam() -> Result<(), String> {
    start_game(&me(), false, None)
}

#[tauri::command]
fn lobby_host(app: AppHandle, map: String, loadout: bool) -> Result<(), String> {
    lobby::host(app, me(), map, loadout)
}

#[tauri::command]
fn lobby_join(app: AppHandle, ip: String) -> Result<(), String> {
    lobby::join(app, ip.trim().to_string(), me())
}

#[tauri::command]
fn lobby_update(app: AppHandle, map: String, loadout: bool) {
    lobby::update(&app, me(), map, loadout)
}

#[tauri::command]
fn lobby_start(app: AppHandle) -> Result<(), String> {
    lobby::start(app)
}

#[tauri::command]
fn lobby_leave(app: AppHandle) {
    lobby::leave(&app)
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            load_settings, save_settings, game_name, list_maps, launch_steam,
            lobby_host, lobby_join, lobby_update, lobby_start, lobby_leave
        ])
        .setup(|app| {
            // WebView2 keeps its profile in %LOCALAPPDATA% by default: keep it next to the launcher
            tauri::WebviewWindowBuilder::new(app, "main", tauri::WebviewUrl::App("index.html".into()))
                .title("Far Cry Coop")
                .inner_size(900.0, 620.0)
                .resizable(false)
                .data_directory(exe_dir().join("FarCryCoopLauncherData"))
                .build()?;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("tauri");
}
