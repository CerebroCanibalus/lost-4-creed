// ============================================================================
// MaoLib_Mapper — Map Entity Utilities for L4D2 VScript
// Part of MaoLib (l4cCoreAddon)
// 
// Replaces VSLib's EntityOutputs with native VScript approach.
// Provides helpers for entity outputs, director options,
// prop spawning, and player/entity utilities.
//
// Requires: MaoLib core (maolib.nut)
// ============================================================================

::MaoLib.Mapper <- {

    // -------------------------------------------------------------------------
    // Debug
    // -------------------------------------------------------------------------
    Debug = 0

    function Dbg(msg) {
        if (Debug) printl("[MaoLib.Mapper][DEBUG] " + msg)
    }

    // -------------------------------------------------------------------------
    // SECTION 1: Entity Outputs
    // -------------------------------------------------------------------------
    // These replace VSLib's EntityOutputs.AddOutput with native alternatives.
    //
    // Two approaches:
    //   1) ConnectOutput — connect entity output to a VScript callback function
    //      (cleanest, no intermediary entities)
    //   2) AddOutput — add I/O between two game entities
    //      (for when you need entity→entity connections)
    // -------------------------------------------------------------------------

    /**
     * Connect an entity's output directly to a VScript callback function.
     * 
     * When the entity fires 'outputName', the global function 'callbackName'
     * is called automatically — no intermediary logic_relay needed.
     *
     * @param {entity} entity  The entity whose output to hook
     * @param {string} output  Output name (e.g. "OnTrigger", "OnTimer")
     * @param {string} callbackName  Global function name (e.g. "::MyFunction")
     * @returns {bool} true if successful
     *
     * Example:
     *   MaoLib.Mapper.ConnectOutput(relay, "OnTrigger", "::MapRefresh.c1m1_hotel.OnTopButtonPressed")
     */
    function ConnectOutput(entity, output, callbackName) {
        if (!entity || !entity.IsValid()) {
            Dbg("ConnectOutput: invalid entity")
            return false
        }
        try {
            entity.ConnectOutput(output, callbackName)
            Dbg("Connected " + entity.GetName() + ":" + output + " -> " + callbackName)
            return true
        } catch(e) {
            printl("[MaoLib.Mapper] ConnectOutput FAILED: " + e)
            return false
        }
    }

    /**
     * Disconnect an entity output from a VScript callback.
     */
    function DisconnectOutput(entity, output, callbackName) {
        if (!entity || !entity.IsValid()) return false
        try {
            entity.DisconnectOutput(output, callbackName)
            return true
        } catch(e) {
            return false
        }
    }

    /**
     * Add an I/O connection between two entities (entity→entity).
     * 
     * When 'sourceEntity' fires 'outputName', the 'targetEntity' receives
     * the 'inputName' input with optional parameter/delay/times.
     *
     * Uses DoEntFire internally since CScriptEntityOutputs global name
     * is not documented — DoEntFire is the reliable native alternative
     * that achieves the same effect at the engine level.
     *
     * @param {entity} sourceEntity  Entity that fires the output
     * @param {string} outputName    Output name (unused with DoEntFire, kept for API compat)
     * @param {string} targetName    Target entity name
     * @param {string} inputName     Input to fire on target
     * @param {string} param         Parameter for the input
     * @param {float}  delay         Delay in seconds
     * @param {int}    times         Times to fire (-1 = infinite)
     *
     * Example:
     *   MaoLib.Mapper.AddOutput(relay, "OnTrigger", "zombiespawner", "SpawnZombie", "", 0.0, -1)
     */
    function AddOutput(sourceEntity, outputName, targetName, inputName, param = "", delay = 0.0, times = -1) {
        if (!sourceEntity || !sourceEntity.IsValid()) {
            Dbg("AddOutput: invalid source entity")
            return false
        }
        try {
            // DoEntFire: "target, input, param, delay, activator, caller"
            DoEntFire(targetName, inputName, param, delay, sourceEntity, sourceEntity)
            Dbg("AddOutput: " + targetName + " -> " + inputName + " (delay=" + delay + ")")
            return true
        } catch(e) {
            printl("[MaoLib.Mapper] AddOutput FAILED: " + e)
            return false
        }
    }

    /**
     * Spawn an entity with outputs embedded in keyvalues.
     *
     * Entity outputs can be specified as keyvalue strings:
     *   "OnTimer" -> "target,input,param,delay,times"
     *
     * @param {string} classname  Entity class name
     * @param {table}  keyvalues  Base keyvalues (origin, model, etc.)
     * @param {table}  outputs    Output keyvalues: { OnTimer = "target,input,param,delay,times" }
     * @returns {entity} spawned entity or null
     *
     * Example:
     *   MaoLib.Mapper.SpawnWithOutput("logic_timer", {
     *       targetname = "mytimer",
     *       RefireTime = 0.5
     *   }, {
     *       OnTimer = "zombiespawner,SpawnZombie,,0,-1"
     *   })
     */
    function SpawnWithOutput(classname, keyvalues, outputs = {}) {
        // Clone to avoid mutating caller's table
        local kv = clone(keyvalues)
        foreach (outName, outVal in outputs) {
            kv[outName] <- outVal
        }
        local ent = SpawnEntityFromTable(classname, kv)
        if (ent && ent.IsValid()) {
            Dbg("Spawned " + classname + " (" + ent.GetName() + ") with " + outputs.len() + " outputs")
        }
        return ent
    }


    // -------------------------------------------------------------------------
    // SECTION 2: Director Options
    // -------------------------------------------------------------------------

    /**
     * Apply DirectorOptions to g_MapScript.
     * Walks up the scope chain if needed.
     *
     * @param {table} options  Table of DirectorOptions key/value pairs
     */
    function ApplyDirectorOptions(options) {
        local target = null

        if ("g_MapScript" in getroottable() && "DirectorOptions" in ::g_MapScript) {
            target = ::g_MapScript.DirectorOptions
        } else if ("DirectorOptions" in getroottable()) {
            target = ::DirectorOptions
        } else {
            printl("[MaoLib.Mapper] WARNING: No DirectorOptions scope found")
            return
        }

        foreach (key, value in options) {
            target[key] <- value
        }
        Dbg("Applied " + options.len() + " DirectorOptions")
    }


    // -------------------------------------------------------------------------
    // SECTION 3: Prop Spawning
    // -------------------------------------------------------------------------

    /**
     * Fisher-Yates shuffle (in-place).
     * Single canonical implementation — no more duplication across map scripts.
     */
    function ShuffleArray(arr) {
        local n = arr.len()
        for (local i = n - 1; i > 0; i--) {
            local j = RandomInt(0, i)
            local temp = arr[i]
            arr[i] = arr[j]
            arr[j] = temp
        }
        return arr
    }

    /**
     * Spawn a reduced random subset of props from a refdata table.
     *
     * @param {table} propsTable  Table of prop entries from refdata
     * @param {float} density     Fraction to spawn (0.0 - 1.0, default 0.6)
     * @param {function} spawnFn  Function to call for each prop (receives data, name)
     * @returns {int} number of successfully spawned props
     *
     * Example:
     *   MaoLib.Mapper.SpawnReducedProps(::MapRefresh.c1m1_Props, 0.6,
     *       function(data, name) { return ::MapRefresh.Utils.SpawnProp(data, name) })
     */
    function SpawnReducedProps(propsTable, density = 0.6, spawnFn = null) {
        if (!propsTable || spawnFn == null) {
            Dbg("SpawnReducedProps: missing props table or spawn function")
            return 0
        }

        // Build array from table
        local propList = []
        foreach (name, data in propsTable) {
            propList.append({ name = name, data = data })
        }

        // Shuffle
        ShuffleArray(propList)

        // Take subset
        local count = (propList.len() * density).tointeger()
        if (count < 1 && propList.len() > 0) count = 1

        local spawned = 0
        for (local i = 0; i < count && i < propList.len(); i++) {
            local p = propList[i]
            if (spawnFn(p.data, p.name)) spawned++
        }

        Dbg("Spawned " + spawned + "/" + count + " props (" + density * 100 + "%)")
        return spawned
    }


    // -------------------------------------------------------------------------
    // SECTION 4: Director Helpers (wrappers over natives)
    // -------------------------------------------------------------------------

    /**
     * Get the closest survivor to a position.
     * Wrapper over Director.GetClosestSurvivor() for safety.
     *
     * @param {Vector} pos      Origin to search from
     * @param {bool}   incap    Include incapacitated survivors (default true)
     * @param {bool}   dead     Include dead survivors (default false)
     * @returns {entity} closest survivor, or null
     */
    function GetClosestSurvivor(pos, incap = true, dead = false) {
        try {
            local s = Director.GetClosestSurvivor(pos, incap, dead)
            if (s && s.IsValid()) return s
        } catch(e) {}
        return null
    }

    /**
     * Trigger a horde panic event sound and reset the mob timer.
     */
    function TriggerMegaMob() {
        try {
            Director.PlayMegaMobWarningSounds()
            Director.ResetMobTimer()
            Dbg("Triggered MegaMob")
        } catch(e) {
            printl("[MaoLib.Mapper] TriggerMegaMob FAILED: " + e)
        }
    }

    /**
     * Check if any survivor is currently in combat.
     */
    function IsAnyoneInCombat() {
        try {
            return Director.IsAnySurvivorInCombat()
        } catch(e) {}
        return false
    }

    /**
     * Register a target entity as forbidden for SI spawns.
     * Prevents special infected from targeting this entity.
     */
    function ForbidTarget(entity) {
        if (!entity || !entity.IsValid()) return
        try { Director.RegisterForbiddenTarget(entity) } catch(e) {}
    }

    /**
     * Unregister a previously forbidden target.
     */
    function AllowTarget(entity) {
        if (!entity || !entity.IsValid()) return
        try { Director.UnregisterForbiddenTarget(entity) } catch(e) {}
    }


    // -------------------------------------------------------------------------
    // SECTION 5: Player Helpers (wrappers over CTerrorPlayer natives)
    // -------------------------------------------------------------------------

    /**
     * Stagger a player with the stagger system native.
     *
     * @param {entity} player   Target player
     * @param {Vector} fromPos  Origin of stagger (direction vector computed)
     */
    function StaggerPlayer(player, fromPos) {
        if (!player || !player.IsValid()) return
        try {
            player.Stagger(fromPos)
            Dbg("Staggered player from " + fromPos.ToString())
        } catch(e) {}
    }

    /**
     * Give temporary health to a player (via SetHealthBuffer).
     *
     * @param {entity} player  Target player
     * @param {float}  amount  Health buffer amount
     */
    function GiveTempHealth(player, amount) {
        if (!player || !player.IsValid()) return
        try {
            player.SetHealthBuffer(amount)
        } catch(e) {}
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
            if (useDefib)
                player.ReviveByDefib()
            else
                player.ReviveFromIncap()
        } catch(e) {}
    }


    // -------------------------------------------------------------------------
    // SECTION 6: Entity Finders (wrappers over CEntities natives)
    // -------------------------------------------------------------------------

    /**
     * Find the nearest entity by classname to a position.
     *
     * @param {string} classname  Class name to search (e.g. "prop_physics")
     * @param {Vector} pos        Origin to search from
     * @param {float}  radius     Search radius
     * @returns {entity} nearest match, or null
     *
     * Example:
     *   local barrel = MaoLib.Mapper.FindNearest("prop_fuel_barrel", pos, 500)
     */
    function FindNearest(classname, pos, radius) {
        try {
            local ent = Entities.FindByClassnameNearest(classname, pos, radius)
            if (ent && ent.IsValid()) return ent
        } catch(e) {}
        return null
    }

    /**
     * Find the nearest entity by name to a position.
     */
    function FindByNameNearest(name, pos, radius) {
        try {
            local ent = Entities.FindByNameNearest(name, pos, radius)
            if (ent && ent.IsValid()) return ent
        } catch(e) {}
        return null
    }

    /**
     * Iterate entities by classname within a radius.
     *
     * @param {string} classname  Class pattern
     * @param {Vector} pos        Center
     * @param {float}  radius     Radius
     * @param {function} callback Called for each entity found
     *
     * Example:
     *   MaoLib.Mapper.FindByClassnameWithin("weapon_*", pos, 500,
     *       function(ent) { printl("Found: " + ent.GetClassname()) })
     */
    function FindByClassnameWithin(classname, pos, radius, callback = null) {
        local count = 0
        try {
            local ent = null
            while ((ent = Entities.FindByClassnameWithin(ent, classname, pos, radius)) != null) {
                if (ent.IsValid()) {
                    count++
                    if (callback) callback(ent)
                }
            }
        } catch(e) {}
        return count
    }


    // -------------------------------------------------------------------------
    // SECTION 7: Fire Custom Director Events
    // -------------------------------------------------------------------------

    /**
     * Fire one of 4 custom Director user-defined events.
     * Other scripts can listen for these via game events.
     *
     * @param {int} id  Event ID (1-4)
     */
    function FireCustomEvent(id) {
        if (id < 1 || id > 4) return
        try {
            switch (id) {
                case 1: Director.UserDefinedEvent1(); break
                case 2: Director.UserDefinedEvent2(); break
                case 3: Director.UserDefinedEvent3(); break
                case 4: Director.UserDefinedEvent4(); break
            }
            Dbg("Fired UserDefinedEvent" + id)
        } catch(e) {}
    }


    // -------------------------------------------------------------------------
    // Initialization
    // -------------------------------------------------------------------------
    function Init() {
        Dbg("MaoLib_Mapper initialized")
    }
}

// Auto-init
::MaoLib.Mapper.Init()
