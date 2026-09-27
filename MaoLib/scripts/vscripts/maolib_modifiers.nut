// ============================================================================
// MaoLib.Modifiers — Speed & Friction Modifier Registry
// ============================================================================
// Centralized system for stacking speed and friction modifiers on players.
// Multiple scripts can register modifiers without conflict.
//
// RULES:
//   - Speed: ALL active multipliers are MULTIPLIED together (1.0 * m1 * m2 * ...)
//   - Friction: The HIGHEST (most restrictive) value wins
//   - Duration: -1 = permanent, >0 = seconds until auto-expiry
//   - Source: String identifier for clearing specific modifiers
//
// USAGE:
//   MaoLib.Modifiers.RegisterSpeed(player, 1.5, 5.0, "my_speed_boost")
//   MaoLib.Modifiers.RegisterFriction(player, 2.0, 3.0, "my_slow")
//   local speed = MaoLib.Modifiers.GetSpeedMultiplier(player)
//   local friction = MaoLib.Modifiers.GetFriction(player)
//   MaoLib.Modifiers.ClearAll(player)
//   MaoLib.Modifiers.ClearSource(player, "my_speed_boost")
//   MaoLib.Modifiers.ListActive(player)
//
// NOTE: This module only REGISTERS modifiers. The actual application
// of m_flLaggedMovementValue should be done by a think loop in your
// script (e.g., every 0.3s, read modifiers and apply to player).
//
// Example consumption:
//   MaoLib.AddTimer("my_mod_apply", 0.3, function() {
//     foreach (p in MaoLib.YieldSurvivors()) {
//       local mult = MaoLib.Modifiers.GetSpeedMultiplier(p)
//       NetProps.SetPropFloat(p, "m_flLaggedMovementValue", mult)
//     }
//   })
// ============================================================================

if ("MaoLib_Modifiers_init_guard" in getroottable()) return;
getroottable()["MaoLib_Modifiers_init_guard"] <- true;

::MaoLib.Modifiers <- {
    Debug = 0

    function Dbg(msg) { if (Debug) printl("[MaoLib.Modifiers][DEBUG] " + msg) }
    function DbgWarn(msg) { printl("[MaoLib.Modifiers][WARN] " + msg) }

    // Data[uid] = { speed: [ {mult, expire, source}, ... ], friction: [ {val, expire, source}, ... ] }
    Data = {}
    ThinkActive = false

    // ============================================================
    // THINK — Auto-cleanup expired modifiers
    // ============================================================
    function _StartThink()
    {
        if (ThinkActive) return
        ThinkActive = true
        ::MaoLib.AddTimer("maolib_modifiers_think", 1.0, function() { ::MaoLib.Modifiers._Think() })
    }

    function _StopThink()
    {
        if (!ThinkActive) return
        ThinkActive = false
        ::MaoLib.RemoveTimer("maolib_modifiers_think")
    }

    function _Think()
    {
        _CleanupAllExpired()
        if (Data.len() == 0) _StopThink()
    }

    // ============================================================
    // REGISTER SPEED
    // ============================================================
    function RegisterSpeed(player, multiplier, duration, source = "unknown")
    {
        if (!_ValidatePlayer(player)) return false

        local uid = _GetUID(player)
        local expire = (duration < 0) ? -1.0 : (Time() + duration)
        _InitPlayerData(uid)

        local replaced = false
        foreach (entry in Data[uid].speed)
        {
            if (entry.source == source)
            {
                entry.mult = multiplier.tofloat()
                entry.expire = expire
                replaced = true
                break
            }
        }

        if (!replaced)
            Data[uid].speed.append({ mult = multiplier.tofloat(), expire = expire, source = source })

        _BackupToPlayerState(uid, "speed_mods", Data[uid].speed)
        _StartThink()
        return true
    }

    // ============================================================
    // REGISTER FRICTION
    // ============================================================
    function RegisterFriction(player, friction, duration, source = "unknown")
    {
        if (!_ValidatePlayer(player)) return false

        local uid = _GetUID(player)
        local expire = (duration < 0) ? -1.0 : (Time() + duration)
        _InitPlayerData(uid)

        local replaced = false
        foreach (entry in Data[uid].friction)
        {
            if (entry.source == source)
            {
                entry.val = friction.tofloat()
                entry.expire = expire
                replaced = true
                break
            }
        }

        if (!replaced)
            Data[uid].friction.append({ val = friction.tofloat(), expire = expire, source = source })

        _BackupToPlayerState(uid, "friction_mods", Data[uid].friction)
        _StartThink()
        return true
    }

    // ============================================================
    // GET SPEED MULTIPLIER
    // ============================================================
    // Returns 1.0 if no modifiers active
    function GetSpeedMultiplier(player)
    {
        if (!_ValidatePlayer(player)) return 1.0
        local uid = _GetUID(player)
        if (!(uid in Data)) return 1.0

        _CleanupExpired(uid)
        local result = 1.0
        foreach (entry in Data[uid].speed) result *= entry.mult
        return result
    }

    // ============================================================
    // GET FRICTION
    // ============================================================
    // Returns maximum (most restrictive) friction, or 1.0 if none
    function GetFriction(player)
    {
        if (!_ValidatePlayer(player)) return 1.0
        local uid = _GetUID(player)
        if (!(uid in Data)) return 1.0

        _CleanupExpired(uid)
        local maxFriction = 1.0
        foreach (entry in Data[uid].friction)
            if (entry.val > maxFriction) maxFriction = entry.val
        return maxFriction
    }

    // ============================================================
    // CLEAR
    // ============================================================
    function ClearAll(player)
    {
        if (!_ValidatePlayer(player)) return false
        local uid = _GetUID(player)
        if (uid in Data) delete Data[uid]
        _BackupToPlayerState(uid, "speed_mods", null)
        _BackupToPlayerState(uid, "friction_mods", null)
        if (Data.len() == 0) _StopThink()
        return true
    }

    function ClearSource(player, source)
    {
        if (!_ValidatePlayer(player)) return false
        local uid = _GetUID(player)
        if (!(uid in Data)) return false

        Data[uid].speed = _FilterBySource(Data[uid].speed, source)
        Data[uid].friction = _FilterBySource(Data[uid].friction, source)

        _BackupToPlayerState(uid, "speed_mods", Data[uid].speed)
        _BackupToPlayerState(uid, "friction_mods", Data[uid].friction)
        return true
    }

    // ============================================================
    // DEBUG: List active modifiers for a player
    // ============================================================
    function ListActive(player)
    {
        if (!_ValidatePlayer(player)) { printl("[MaoLib.Modifiers] ListActive: invalid player"); return }
        local uid = _GetUID(player)
        local now = Time()
        printl("=== MaoLib.Modifiers Active for uid=" + uid + " ===")
        if (!(uid in Data)) { printl("  No modifiers registered"); return }

        _CleanupExpired(uid)
        printl("  SPEED (" + Data[uid].speed.len() + "):")
        foreach (e in Data[uid].speed)
            printl("    [" + e.source + "] mult=" + e.mult + " rem=" + (e.expire < 0 ? "∞" : format("%.1fs", e.expire - now)))
        printl("  FRICTION (" + Data[uid].friction.len() + "):")
        foreach (e in Data[uid].friction)
            printl("    [" + e.source + "] val=" + e.val + " rem=" + (e.expire < 0 ? "∞" : format("%.1fs", e.expire - now)))
        printl("  RESULT: speed=" + GetSpeedMultiplier(player) + " friction=" + GetFriction(player))
    }

    // ============================================================
    // INTERNAL HELPERS
    // ============================================================
    function _ValidatePlayer(p) { return p && p.IsValid() && p.IsPlayer() }
    function _GetUID(p) { return "" + p.GetEntityIndex() }

    function _InitPlayerData(uid)
    {
        if (!(uid in Data)) Data[uid] <- { speed = [], friction = [] }
    }

    function _CleanupExpired(uid)
    {
        if (!(uid in Data)) return
        local now = Time()
        Data[uid].speed = _FilterExpired(Data[uid].speed, now)
        Data[uid].friction = _FilterExpired(Data[uid].friction, now)
        if (Data[uid].speed.len() == 0 && Data[uid].friction.len() == 0)
        {
            delete Data[uid]
            _BackupToPlayerState(uid, "speed_mods", null)
            _BackupToPlayerState(uid, "friction_mods", null)
        }
    }

    function _CleanupAllExpired()
    {
        local now = Time()
        local emptyUids = []
        foreach (uid, pd in Data)
        {
            local changed = false
            local ns = _FilterExpired(pd.speed, now)
            if (ns.len() != pd.speed.len()) changed = true
            pd.speed = ns
            local nf = _FilterExpired(pd.friction, now)
            if (nf.len() != pd.friction.len()) changed = true
            pd.friction = nf
            if (pd.speed.len() == 0 && pd.friction.len() == 0) emptyUids.append(uid)
        }
        foreach (uid in emptyUids)
        {
            delete Data[uid]
            _BackupToPlayerState(uid, "speed_mods", null)
            _BackupToPlayerState(uid, "friction_mods", null)
        }
    }

    function _FilterExpired(arr, now)
    {
        local result = []
        foreach (e in arr)
            if (e.expire < 0 || e.expire > now) result.append(e)
        return result
    }

    function _FilterBySource(arr, source)
    {
        local result = []
        foreach (e in arr)
            if (e.source != source) result.append(e)
        return result
    }

    function _BackupToPlayerState(uid, key, value)
    {
        if (!("PlayerState" in ::MaoLib)) return
        try {
            if (value == null) ::MaoLib.PlayerState.Delete(uid, key)
            else ::MaoLib.PlayerState.Set(uid, key, value)
        } catch (e) {}
    }
}

// Register auto-cleanup with PlayerState (if available)
if ("PlayerState" in ::MaoLib)
{
    ::MaoLib.PlayerState.RegisterOnClear("MaoLib_Modifiers", function(uid) {
        if (uid in ::MaoLib.Modifiers.Data) delete ::MaoLib.Modifiers.Data[uid]
        if (::MaoLib.Modifiers.Data.len() == 0 && ::MaoLib.Modifiers.ThinkActive)
            ::MaoLib.Modifiers._StopThink()
    })
}

printl("[MaoLib.Modifiers] Loaded successfully")
