// ============================================================================
// MaoLib.StatusEffects — DoT System + Flat Key-Value Registry v3.0
// ============================================================================
// Minimalist status effects system. Two subsystems:
//
// 1. DoT (Damage over Time):
//    - Apply a damage-over-time effect to any entity
//    - Automatic tick every 1.0s, with an immediate tick at 0.05s
//    - Damage accumulator prevents fractional loss from tointeger()
//    - Auto-cleanup when victim dies or DoT expires
//
// 2. Flat Key-Value Registry:
//    - Simple Set/Get/Remove by player + key + source
//    - No stacking rules — your script decides how to combine values
//    - Each key can have multiple sources (e.g., two different buffs)
//    - Auto-expiry via lazy cleanup on Get()
//
// USAGE — DoT:
//   MaoLib.StatusEffects.ApplyDoT(victim, "bleed", 5.0, 3.0, attacker)
//   MaoLib.StatusEffects.RemoveDoT(victim, "bleed")
//   MaoLib.StatusEffects.ClearAllDoTs()
//
// USAGE — Registry:
//   MaoLib.StatusEffects.Set(player, "my_buff", 50, 5.0, "my_source")
//   local data = MaoLib.StatusEffects.Get(player, "my_buff")
//     → returns table: { source1 = { value=50, expire=1234.5 }, ... } or null
//   MaoLib.StatusEffects.Remove(player, "my_buff", "my_source")
//   MaoLib.StatusEffects.Clear(player)
//
// ⚠️ No automatic hooks! Your script reads StatusEffects.Get() when needed.
// ============================================================================

if ("MaoLib_Status_init_guard" in getroottable()) return;
getroottable()["MaoLib_Status_init_guard"] <- true;

::MaoLib.StatusEffects <- {
    Debug = 0

    function Dbg(msg) { if (Debug) printl("[Status][DBG] " + msg) }
    function DbgWarn(msg) { printl("[Status][WARN] " + msg) }

    // ============================================================
    // DOT SUBSYSTEM
    // ============================================================
    DoTTimers = {}

    /**
     * Apply a damage-over-time effect.
     * @param {entity} victim       Target entity
     * @param {string} dotType      Identifier (e.g., "bleed", "burn", "poison")
     * @param {float}  dps          Damage per second
     * @param {float}  duration     Duration in seconds
     * @param {entity} attacker     Attacker entity
     * @return {bool} success
     *
     * Ticks every 1.0s + immediate tick at 0.05s.
     * Damage type used: DMG_BULLET (1<<1). Change via TakeDamage() call.
     */
    function ApplyDoT(victim, dotType, dps, duration, attacker)
    {
        if (!victim || !victim.IsValid()) return false
        if (dps <= 0 || duration <= 0) return false

        local uid = victim.GetEntityIndex().tostring()
        local timerName = "dot_" + dotType + "_" + uid

        // Remove existing DoT of same type on same victim
        RemoveDoT(victim, dotType)

        local endTime = Time() + duration
        local tickDmg = dps
        local dmgAccumulator = 0.0

        // Immediate first tick (next frame) — prevents short-lived victims
        // from dying before the first 1.0s tick
        ::MaoLib.DelayCall(function() {
            if (!victim || !victim.IsValid()) return
            if (NetProps.GetPropInt(victim, "m_lifeState") != 0) return
            if (Time() >= endTime) return
            local atk = (attacker && attacker.IsValid()) ? attacker : victim
            dmgAccumulator += tickDmg
            local dmgInt = dmgAccumulator.tointeger()
            if (dmgInt > 0) {
                victim.TakeDamage(dmgInt, (1 << 1), atk)
                dmgAccumulator -= dmgInt
            }
        }, 0.05)

        // Main tick every 1.0s
        ::MaoLib.AddTimer(timerName, 1.0, function() {
            if (!victim || !victim.IsValid()) { ::MaoLib.RemoveTimer(timerName); return }
            if (NetProps.GetPropInt(victim, "m_lifeState") != 0) { ::MaoLib.RemoveTimer(timerName); return }
            if (Time() >= endTime) { ::MaoLib.RemoveTimer(timerName); return }
            local atk = (attacker && attacker.IsValid()) ? attacker : victim
            dmgAccumulator += tickDmg
            local dmgInt = dmgAccumulator.tointeger()
            if (dmgInt > 0) {
                victim.TakeDamage(dmgInt, (1 << 1), atk)
                dmgAccumulator -= dmgInt
            }
        })

        if (!(uid in DoTTimers)) DoTTimers[uid] <- {}
        DoTTimers[uid][dotType] <- timerName
        return true
    }

    function RemoveDoT(victim, dotType)
    {
        if (!victim || !victim.IsValid()) return
        local uid = victim.GetEntityIndex().tostring()
        if (uid in DoTTimers && dotType in DoTTimers[uid]) {
            ::MaoLib.RemoveTimer(DoTTimers[uid][dotType])
            delete DoTTimers[uid][dotType]
            if (DoTTimers[uid].len() == 0) delete DoTTimers[uid]
        }
    }

    function ClearAllDoTs()
    {
        foreach (uid, types in DoTTimers)
            foreach (type, timerName in types)
                ::MaoLib.RemoveTimer(timerName)
        DoTTimers = {}
    }

    // ============================================================
    // FLAT KEY-VALUE REGISTRY
    // ============================================================
    // Data[entindex][key][source] = { value, expire }
    //
    // No stacking rules — your script iterates and decides.
    // This makes the system predictable and easy to debug.
    // ============================================================
    Data = {}

    /**
     * Set a key-value for a player with optional duration.
     * @param {entity} player     Target player
     * @param {string} key        Key name
     * @param {any}    value      Value to store
     * @param {float}  duration   Seconds, -1 = permanent
     * @param {string} source     Identifier for the source
     */
    function Set(player, key, value, duration = -1, source = "generic")
    {
        if (!player || !player.IsValid() || !player.IsPlayer()) return false
        if (typeof key != "string" || key == "") { DbgWarn("Set: key invalid"); return false }

        local uid = player.GetEntityIndex().tostring()
        if (!(uid in Data)) Data[uid] <- {}
        if (!(key in Data[uid])) Data[uid][key] <- {}

        Data[uid][key][source] <- {
            value = value,
            expire = (duration < 0) ? -1.0 : (Time() + duration)
        }

        return true
    }

    /**
     * Get all sources for a key on a player.
     * Returns table { source1 = { value, expire }, ... } or null.
     */
    function Get(player, key)
    {
        if (!player || !player.IsValid()) return null
        local uid = player.GetEntityIndex().tostring()
        if (!(uid in Data) || !(key in Data[uid])) return null

        _CleanupExpired(uid, key)
        if (Data[uid][key].len() == 0) return null

        return Data[uid][key]
    }

    /**
     * Remove a source from a key, or the entire key if no source specified.
     */
    function Remove(player, key, source = "")
    {
        if (!player || !player.IsValid()) return false
        local uid = player.GetEntityIndex().tostring()
        if (!(uid in Data) || !(key in Data[uid])) return false

        if (source == "") {
            delete Data[uid][key]
            if (Data[uid].len() == 0) delete Data[uid]
            return true
        } else if (source in Data[uid][key]) {
            delete Data[uid][key][source]
            if (Data[uid][key].len() == 0) delete Data[uid][key]
            if (Data[uid].len() == 0) delete Data[uid]
        }
        return true
    }

    /**
     * Clear ALL data for a player (keys + DoTs).
     */
    function Clear(player)
    {
        if (!player || !player.IsValid()) return false
        local uid = player.GetEntityIndex().tostring()
        if (uid in Data) delete Data[uid]
        if (uid in DoTTimers) {
            foreach (type, timerName in DoTTimers[uid])
                ::MaoLib.RemoveTimer(timerName)
            delete DoTTimers[uid]
        }
        return true
    }

    function ClearAll()
    {
        Data = {}
        ClearAllDoTs()
    }

    // ============================================================
    // INTERNAL: Expired entry cleanup (lazy, on Get())
    // ============================================================
    function _CleanupExpired(uid, key)
    {
        if (!(uid in Data) || !(key in Data[uid])) return
        local now = Time()
        local toRemove = []
        foreach (source, entry in Data[uid][key]) {
            if (entry.expire >= 0 && entry.expire <= now)
                toRemove.append(source)
        }
        foreach (source in toRemove) delete Data[uid][key][source]
        if (Data[uid][key].len() == 0) delete Data[uid][key]
        if (Data[uid].len() == 0) delete Data[uid]
    }
}

printl("[MaoLib.StatusEffects] v3.0 loaded — DoT + Flat Registry")
