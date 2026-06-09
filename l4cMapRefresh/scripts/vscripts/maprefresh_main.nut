// ============================================================
// MapRefresh - maprefresh_main.nut (v3)
// Core loader: detects current map and loads map-specific scripts
// ============================================================
// Scope: getroottable() via IncludeScript("maprefresh_main", getroottable())
// Dependencies: MaoLib (hard), MaoLib_VFX, MaoLib.Mapper
// ============================================================
// Fixes in v3:
//  - Replaced SessionState.MapName with Director.GetMapName() (native)
//  - Removed fragile MapRefresh_init_guard (prevented retry on error)
//  - Added _initialized flag inside ::MapRefresh (resets on map change)
//  - Added try/catch on all major operations
//  - Cleaner architecture: LoadMapScript calls per-map Init() directly
// ============================================================

::MapRefresh <- {
    // Config
    DEBUG = false,

    // State
    _initialized = false,
    LoadedMap = "",
    CurrentMapScript = null,

    // Maps with active scripts (registered here)
    SupportedMaps = {
        c1m1_hotel = true,
        c1m2_streets = true,
        c2m1_highway = true,
        c2m2_fairgrounds = true,
        c2m3_coaster = true,
        c2m4_barns = true,
        c3m2_swamp = true,
        c3m3_shantytown = true,
        c5m1_waterfront = true,
        c5m2_park = true,
        c5m3_cemetery = true,
        c5m4_quarter = true,
        c8m1_apartment = true,
        c8m2_subway = true,
        c8m3_sewers = true,
        c8m4_interior = true,
        c8m5_rooftop = true,
    },

    // --------------------------------------------------------------------------
    function Dbg(msg) {
        if (DEBUG) printl("[MapRefresh] " + msg)
    }

    // --------------------------------------------------------------------------
    // INIT — called from OnGameEvent_round_start_post_nav via timer
    // --------------------------------------------------------------------------
    function Init() {
        if (_initialized) {
            Dbg("Already initialized, skipping")
            return
        }

        local mapName = ""
        try {
            mapName = Director.GetMapName()
        } catch(e) {
            printl("[MapRefresh] ERROR Director.GetMapName(): " + e)
            return
        }

        LoadedMap = mapName
        printl("[MapRefresh] Initializing for: " + mapName)

        // Load subsystems (safe to re-include — tables merge)
        try { IncludeScript("maprefresh_utils", getroottable()) } catch(e) {
            printl("[MapRefresh] ERROR loading utils: " + e)
        }
        try { IncludeScript("maprefresh_proptypes", getroottable()) } catch(e) {
            printl("[MapRefresh] ERROR loading proptypes: " + e)
        }
        try { IncludeScript("maprefresh_refdata", getroottable()) } catch(e) {
            printl("[MapRefresh] ERROR loading refdata: " + e)
        }

        // Supported map?
        if (mapName in SupportedMaps && SupportedMaps[mapName]) {
            _initialized = true
            LoadMapScript(mapName)
        } else {
            printl("[MapRefresh] No refresh script for: " + mapName)
            _initialized = true  // Still mark done to avoid retry
        }
    }

    // --------------------------------------------------------------------------
    // Load per-map script + call its Init() after delay
    // --------------------------------------------------------------------------
    function LoadMapScript(mapName) {
        printl("[MapRefresh] Loading script: " + mapName)

        try {
            IncludeScript(mapName, getroottable())
            printl("[MapRefresh] Script loaded: " + mapName)
        } catch(e) {
            printl("[MapRefresh] ERROR IncludeScript(" + mapName + "): " + e)
            return
        }

        // Verify the table exists
        if (!(mapName in ::MapRefresh)) {
            printl("[MapRefresh] WARNING: " + mapName + " table not found after IncludeScript")
            return
        }

        // Store reference
        CurrentMapScript = ::MapRefresh[mapName]

        // Init after short delay (ensures entities are ready)
        MaoLib.DelayCall(function() {
            try {
                if (CurrentMapScript != null && "Init" in CurrentMapScript) {
                    CurrentMapScript.Init()
                    printl("[MapRefresh] " + mapName + " initialized")
                } else {
                    printl("[MapRefresh] WARNING: " + mapName + " has no Init()")
                }
            } catch(e) {
                printl("[MapRefresh] ERROR Init " + mapName + ": " + e)
            }
        })
    }
}

// ==============================================================================
// Game Events
// ==============================================================================

::MapRefreshEvents <- {
    function OnGameEvent_round_start_post_nav(params) {
        // Small delay to ensure everything is loaded
        MaoLib.DelayCall(@() ::MapRefresh.Init(), 1.0)
    }

    function OnGameEvent_round_end(params) {
        // Cleanup current map's timers and effects
        if (CurrentMapScript != null && "_Cleanup" in CurrentMapScript) {
            try {
                CurrentMapScript._Cleanup()
                Dbg("Called _Cleanup() for " + LoadedMap)
            } catch(e) {
                printl("[MapRefresh] ERROR _Cleanup: " + e)
            }
        }
        // Allow re-init for next round if needed
        // (VScript VM resets on map change, so this is a safety net)
        ::MapRefresh._initialized = false
        ::MapRefresh.LoadedMap = ""
        ::MapRefresh.CurrentMapScript = null
    }
}

__CollectGameEventCallbacks(::MapRefreshEvents)

printl("[MapRefresh] Loader v3 ready")
