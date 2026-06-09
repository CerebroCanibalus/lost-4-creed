// ============================================================
// l4cMapRefresh - director_base_addon.nut
// Map Refresh System - Entry Point
// Makes vanilla maps feel fresh with unexpected changes
// ============================================================
// Load order: After l4cCoreAddon (MaoLib must be loaded)
// Scope: DirectorScript (standard director_base_addon convention)
// ============================================================

printl("[MapRefresh] Loading Map Refresh System...");

// Include the main MapRefresh system
IncludeScript("maprefresh_main", getroottable());

printl("[MapRefresh] Map Refresh System loaded successfully.");
