// ============================================================================
// MaoLib.Mapper — Map Entity Utilities for L4D2
// ============================================================================
// Helpers for prop spawning, director control, player utilities,
// and entity finding. Wraps native API calls with safety checks.
//
// USAGE:
//   MaoLib.Mapper.ShuffleArray(arr)
//   MaoLib.Mapper.SpawnReducedProps(propsTable, density, spawnFn)
//   MaoLib.Mapper.GetClosestSurvivor(pos, includeIncap, includeDead)
//   MaoLib.Mapper.TriggerMegaMob()
//   MaoLib.Mapper.StaggerPlayer(player, fromPos)
//   MaoLib.Mapper.GiveTempHealth(player, amount)
//   MaoLib.Mapper.ExtinguishPlayer(player)
//   MaoLib.Mapper.RevivePlayer(player, useDefib)
//   MaoLib.Mapper.FindNearest(classname, pos, radius)
// ============================================================================

::MaoLib.Mapper <- {
    Debug = 0

    function Dbg(msg) { if (Debug) printl("[MaoLib.Mapper][DEBUG] " + msg) }

    // ============================================================
    // SECTION 1: Array Utilities
    // ============================================================

    /**
     * Fisher-Yates shuffle (in-place). Canonical single implementation.
     * @param {array} arr  Array to shuffle
     * @return {array}     Same array, shuffled
     */
    function ShuffleArray(arr) {
        local n = arr.len()
        for (local i = n - 1; i > 0; i--) {
            local j = RandomInt(0, i)
            local temp = arr[i]; arr[i] = arr[j]; arr[j] = temp
        }
        return arr
    }

    // ============================================================
    // SECTION 2: Prop Spawning
    // ============================================================

    /**
     * Spawn a reduced random subset of props from a reference data table.
     * Useful for MapRefresh-style prop distribution with density control.
     *
     * @param {table}    propsTable  Table of prop entries (name → data)
     * @param {float}    density     Fraction to spawn (0.0-1.0, default 0.6)
     * @param {function} spawnFn     Callback: function(data, name) → bool
     * @return {int} number of successfully spawned props
     */
    function SpawnReducedProps(propsTable, density = 0.6, spawnFn = null) {
        if (!propsTable || spawnFn == null) { Dbg("SpawnReducedProps: missing args"); return 0 }

        local propList = []
        foreach (name, data in propsTable)
            propList.append({ name = name, data = data })

        ShuffleArray(propList)

        local count = (propList.len() * density).tointeger()
        if (count < 1 && propList.len() > 0) count = 1

        local spawned = 0
        for (local i = 0; i < count && i < propList.len(); i++) {
            if (spawnFn(propList[i].data, propList[i].name)) spawned++
        }

        return spawned
    }

    // ============================================================
    // SECTION 3: Director Helpers
    // ============================================================

    /**
     * Get the closest survivor to a position.
     * Safe wrapper over Director.GetClosestSurvivor().
     */
    function GetClosestSurvivor(pos, incap = true, dead = false) {
        try {
            local s = Director.GetClosestSurvivor(pos, incap, dead)
            if (s && s.IsValid()) return s
        } catch(e) {}
        return null
    }

    /**
     * Trigger a mega mob event (panic + reset mob timer).
     */
    function TriggerMegaMob() {
        try {
            Director.PlayMegaMobWarningSounds()
            Director.ResetMobTimer()
        } catch(e) {
            printl("[MaoLib.Mapper] TriggerMegaMob FAILED: " + e)
        }
    }

    // ============================================================
    // SECTION 4: Player Utilities
    // ============================================================

    /**
     * Stagger a player from a direction.
     * @param {entity} player   Target player
     * @param {Vector} fromPos  Source position (direction auto-computed)
     */
    function StaggerPlayer(player, fromPos) {
        if (!player || !player.IsValid()) return
        try { player.Stagger(fromPos) } catch(e) {}
    }

    /**
     * Give temporary health buffer to a player.
     */
    function GiveTempHealth(player, amount) {
        if (!player || !player.IsValid()) return
        try { player.SetHealthBuffer(amount) } catch(e) {}
    }

    /**
     * Extinguish a burning player.
     */
    function ExtinguishPlayer(player) {
        if (!player || !player.IsValid()) return
        try { player.Extinguish() } catch(e) {}
    }

    /**
     * Revive a player from incap or death.
     */
    function RevivePlayer(player, useDefib = false) {
        if (!player || !player.IsValid()) return
        try {
            if (useDefib) player.ReviveByDefib()
            else player.ReviveFromIncap()
        } catch(e) {}
    }

    // ============================================================
    // SECTION 5: Entity Finders
    // ============================================================

    /**
     * Find nearest entity by classname within radius.
     * @param {string} classname  Entity classname (e.g. "prop_physics")
     * @param {Vector} pos        Search origin
     * @param {float}  radius     Search radius
     * @return {entity} or null
     */
    function FindNearest(classname, pos, radius) {
        try {
            local ent = Entities.FindByClassnameNearest(classname, pos, radius)
            if (ent && ent.IsValid()) return ent
        } catch(e) {}
        return null
    }

    function Init() { Dbg("Mapper initialized") }
}

::MaoLib.Mapper.Init()
printl("[MaoLib.Mapper] Loaded successfully")
