//=============================================================================
// mapspawn_addon.nut — Entry Point del L4C VScript Music Manager
// Carga: l4c_music_tracks.nut → l4c_music_core.nut → l4c_music_events.nut
//=============================================================================
// Cargar en getroottable() para acceso global
//=============================================================================

// --- Cargar catálogo de tracks (primero, sin dependencias) ---
IncludeScript("l4c_music_tracks", getroottable());

// --- Cargar core (depende de tracks pero no de eventos) ---
IncludeScript("l4c_music_core", getroottable());

// --- Cargar eventos (depende de core) ---
IncludeScript("l4c_music_events", getroottable());

// --- Verificar carga ---
if ("L4C_Music" in getroottable() && "Init" in ::L4C_Music) {
    printl("[L4C_Music] ✓ Sistema cargado correctamente v" + (::L4C_Music.Debug == 0 ? "" : " (Debug=" + ::L4C_Music.Debug + ")"));
} else {
    printl("[L4C_Music][ERROR] Falló la carga del Music Manager");
}
