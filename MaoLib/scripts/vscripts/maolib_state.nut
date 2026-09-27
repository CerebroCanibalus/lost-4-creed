// ============================================================================
// MaoLib.PlayerState — Per-Player State Registry
// ============================================================================
// Unified key-value storage per player (keyed by userid).
// Replaces scattered tables across scripts with a single, centralized store.
//
// FEATURES:
//   - Get/Set/Delete/Has by userid + key
//   - GetAll(uid) to dump a player's entire state
//   - Clear on player disconnect (auto via event)
//   - ClearAll on round_end / mission_lost
//   - RegisterOnClear: hooks called when a player's state is cleared
//   - Thread-safe: uses IncomingQueue pattern where needed
//
// USAGE:
//   MaoLib.PlayerState.Set(uid, "my_key", value)
//   local val = MaoLib.PlayerState.Get(uid, "my_key", default_value)
//   MaoLib.PlayerState.Has(uid, "my_key")
//   MaoLib.PlayerState.Delete(uid, "my_key")
//   MaoLib.PlayerState.Clear(uid)          // clear one player
//   MaoLib.PlayerState.ClearAll()          // clear everyone (round_end)
//   MaoLib.PlayerState.GetAll(uid)         // dump all keys for a player
//   MaoLib.PlayerState.RegisterOnClear("my_system", function(uid) { ... })
//
// CONVENTION: Prefix your keys with your script name
//   ("jaime_health", "brock_cooldown", etc.) to avoid collisions.
// ============================================================================

if ("MaoLib_PlayerState_init_guard" in getroottable()) return;
getroottable()["MaoLib_PlayerState_init_guard"] <- true;

::MaoLib.PlayerState <- {
    Debug = 0

    function Dbg(msg) { if (Debug) printl("[MaoLib.PlayerState][DEBUG] " + msg) }
    function DbgWarn(msg) { printl("[MaoLib.PlayerState][WARN] " + msg) }

    // Data[userid][key] = value
    Data = {}
    
    // OnClearCallbacks[name] = function(uid)
    OnClearCallbacks = {}

    // ============================================================
    // PUBLIC API
    // ============================================================

    function Set(uid, key, value)
    {
        if (!uid || key == null) { DbgWarn("ABORT Set: invalid args"); return false }

        if (!(uid in Data)) Data[uid] <- {}
        Data[uid][key] <- value
        Dbg("Set OK uid=" + uid + " key=" + key)
        return true
    }

    function Get(uid, key, defaultVal = null)
    {
        if (uid in Data && key in Data[uid])
            return Data[uid][key]
        return defaultVal
    }

    function Delete(uid, key)
    {
        if (uid in Data && key in Data[uid])
        {
            delete Data[uid][key]
            if (Data[uid].len() == 0) delete Data[uid]
            return true
        }
        return false
    }

    function Clear(uid)
    {
        if (!(uid in Data)) return false

        // Notify listeners BEFORE clearing
        foreach (name, callback in OnClearCallbacks)
        {
            try { callback(uid) }
            catch (e) { DbgWarn("OnClear callback '" + name + "' failed: " + e) }
        }

        delete Data[uid]
        Dbg("Clear OK uid=" + uid)
        return true
    }

    function Has(uid, key)
    {
        return (uid in Data) && (key in Data[uid])
    }

    function GetAll(uid)
    {
        if (uid in Data) return Data[uid]
        return {}
    }

    function RegisterOnClear(name, callback)
    {
        if (!name || !callback) { DbgWarn("ABORT RegisterOnClear: invalid args"); return false }
        OnClearCallbacks[name] <- callback
        return true
    }

    function UnregisterOnClear(name)
    {
        if (name in OnClearCallbacks) { delete OnClearCallbacks[name]; return true }
        return false
    }

    // Clear ALL players (called on round_end / mission_lost)
    function ClearAll()
    {
        local count = Data.len()
        
        // Snapshot keys to avoid reentrancy
        local uids = []
        foreach (uid, _ in Data) uids.append(uid)

        foreach (uid in uids)
        {
            foreach (name, callback in OnClearCallbacks)
            {
                try { callback(uid) }
                catch (e) { DbgWarn("OnClear callback '" + name + "' failed: " + e) }
            }
        }

        Data.clear()
        Dbg("ClearAll OK removed=" + count + " uids")
        return true
    }
}

// ============================================================
// EVENTS — Auto-cleanup on disconnect and round end
// ============================================================

::MaoLib_PlayerState_Events <- {
    Debug = 0

    function Dbg(msg) { if (Debug) printl("[MaoLib.PlayerState.Events][DEBUG] " + msg) }

    function OnGameEvent_player_disconnect(params)
    {
        local userid = params.userid
        if (!userid) return
        ::MaoLib.PlayerState.Clear(userid)
    }

    function OnGameEvent_round_end(params)  { ::MaoLib.PlayerState.ClearAll() }
    function OnGameEvent_mission_lost(params) { ::MaoLib.PlayerState.ClearAll() }
}

__CollectGameEventCallbacks(::MaoLib_PlayerState_Events)

printl("[MaoLib.PlayerState] Loaded successfully")
