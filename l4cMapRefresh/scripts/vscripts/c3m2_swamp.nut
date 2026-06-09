// ============================================================================
// c3m2_swamp.nut — Aircraft Crash + Tank Spawn Event
// Survivors enter trigger zone → plane flies overhead → crashes → Tank + fire
// Source: CyberZoio Stripper (c3m2_swamp-AIRCRAFT-CRASH+TANK-SPAWN.cfg)
//
// Simplified from Stripper: func_tracktrain replaced by timer-based
// plane interpolation (smooth enough for a flyover). Debris + effects
// via MaoLib_VFX + entity spawning.
// ============================================================================

// ============================================================================
// Aircraft Crash Event
// ============================================================================

::MapRefresh.c3m2_swamp <- {
    Debug = 1,

    // ================================================================
    // Event Positions (from CyberZoio Stripper data)
    // ================================================================

    TRIGGER_POS   = Vector(7289, 2397, 31),      // Survivor trigger zone
    PLANE_START   = Vector(6805, 5009, 933),      // Plane appears high up
    PLANE_MID     = Vector(8188, 1735, 115),      // Mid-air pass (explosion trigger)
    PLANE_CRASH   = Vector(8437, 404, 115),       // Crash impact point
    TANK_POS      = Vector(8448, 333, 185),        // Tank spawn
    DEBRIS_CENTER = Vector(8436, 402, 115),        // Debris cluster center
    HURT_CENTER   = Vector(8438, 304, 185),        // Damage zone center

    TRIGGER_RADIUS = 275,   // Half of extent 550
    FLIGHT_TIME    = 5.0,   // Total flight duration (seconds)
    MID_AIR_TIME   = 3.5,   // Mid-air pass trigger time

    // === State ===
    _triggered   = false,
    _plane       = null,
    _planeAngles = null,
    _slowmoEnt   = null,
    _filterEnt   = null,
    _timerName   = null,
    _planeTimer  = null,
    _flightElapsed = 0,
    _midAirFired = false,

    // ================================================================
    // Debug
    // ================================================================

    function Dbg(msg) {
        if (Debug) printl("[MapRefresh][c3m2] " + msg)
    }
    function DbgWarn(msg) {
        printl("[MapRefresh][WARN][c3m2] " + msg)
    }

    // ================================================================
    // Init — called by maprefresh_main after 2s delay
    // ================================================================

    function Init()
    {
        Dbg("Init — setting up Aircraft Crash trigger")

        // Calculate plane direction angles (start → crash direction)
        local dir = PLANE_CRASH - PLANE_START
        local flatDir = Vector(dir.x, dir.y, 0)
        local yaw = -atan2(flatDir.x, flatDir.y) * (180.0 / 3.14159)
        local horizDist = sqrt(flatDir.x * flatDir.x + flatDir.y * flatDir.y)
        local pitch = -atan2(dir.z, horizDist) * (180.0 / 3.14159)
        _planeAngles = QAngle(pitch, yaw, 0)
        Dbg("Plane angles: pitch=" + pitch + " yaw=" + yaw)

        // Create survivor filter (for damage zone)
        _filterEnt = SpawnEntityFromTable("filter_activator_team", {
            targetname = "c3m2_filter_" + UniqueString(),
            filterteam = 2,
            Negated = 0
        })

        // Create slow-motion entity
        _slowmoEnt = SpawnEntityFromTable("func_timescale", {
            targetname = "c3m2_slowmo",
            minBlendRate = 2,
            desiredTimescale = "0.2",
            blendDeltaMultiplier = "3.0",
            acceleration = "0.05"
        })

        // Start trigger checker
        _timerName = "c3m2_check_" + UniqueString()
        MaoLib.AddTimerAuto(_timerName, 1.0, function() {
            ::MapRefresh.c3m2_swamp._CheckTrigger()
        })

        Dbg("Init complete")
    }

    // ================================================================
    // Check Trigger
    // ================================================================

    function _CheckTrigger()
    {
        if (_triggered) return

        foreach (s in MaoLib.YieldSurvivors())
        {
            if (!MaoLib.IsAlivePlayer(s)) continue

            local dist = MaoLib.DistanceBetween(s.GetOrigin(), TRIGGER_POS)
            if (dist < TRIGGER_RADIUS)
            {
                _StartEvent()
                return
            }
        }
    }

    // ================================================================
    // Start Event — Spawn plane + begin flight
    // ================================================================

    function _StartEvent()
    {
        _triggered = true
        MaoLib.RemoveTimer(_timerName)
        Dbg("TRIGGERED — Aircraft Crash!")

        // Hint
        MaoLib.HUD.NotifyAll("Run!", {
            mode = "center",
            typeKey = "c3m2_crash",
            throttle = 0,
            priority = "high"
        })

        // --- Spawn plane ---
        _plane = SpawnEntityFromTable("prop_dynamic", {
            model = "models/lighthouse/b_airplane01.mdl",
            origin = PLANE_START,
            angles = _planeAngles.x + " " + _planeAngles.y + " " + _planeAngles.z,
            disableshadows = 1,
            solid = 0
        })

        if (!_plane || !_plane.IsValid())
        {
            DbgWarn("Failed to spawn plane model! Falling back to static crash.")
            _OnCrash()
            return
        }

        _plane.SetOrigin(PLANE_START)
        _plane.SetAngles(_planeAngles.x, _planeAngles.y, _planeAngles.z)
        Dbg("Plane spawned at: " + PLANE_START.tostring())

        // --- Start flight timer (0.05s ticks) ---
        _flightElapsed = 0
        _midAirFired = false
        _planeTimer = MaoLib.AddTimerAuto("c3m2_plane_move", 0.05, function() {
            ::MapRefresh.c3m2_swamp._UpdatePlane()
        })

        // --- Flyover sound (looping via timer) ---
        MaoLib_VFX.EmitSoundAt(PLANE_START, "animation/plane_flyover.wav")
    }

    // ================================================================
    // Update Plane — Interpolate position along flight path
    // ================================================================

    function _UpdatePlane()
    {
        if (!_plane || !_plane.IsValid())
        {
            MaoLib.RemoveTimer(_planeTimer)
            _planeTimer = null
            return
        }

        _flightElapsed += 0.05
        local t = _flightElapsed / FLIGHT_TIME

        // --- Mid-air pass trigger (t ~0.7) ---
        if (!_midAirFired && _flightElapsed >= MID_AIR_TIME)
        {
            _midAirFired = true
            _OnMidAir()
        }

        // --- Crash trigger ---
        if (t >= 1.0)
        {
            // Final position
            _plane.SetOrigin(PLANE_CRASH)
            MaoLib.RemoveTimer(_planeTimer)
            _planeTimer = null
            _OnCrash()
            return
        }

        // --- Interpolate position ---
        // Phase 1: Start → Mid (0 to 0.7 of total time)
        // Phase 2: Mid → Crash (0.7 to 1.0)
        local pos
        if (_flightElapsed <= MID_AIR_TIME)
        {
            local lt = _flightElapsed / MID_AIR_TIME
            pos = PLANE_START * (1.0 - lt) + PLANE_MID * lt
        }
        else
        {
            local lt = (_flightElapsed - MID_AIR_TIME) / (FLIGHT_TIME - MID_AIR_TIME)
            pos = PLANE_MID * (1.0 - lt) + PLANE_CRASH * lt
        }

        _plane.SetOrigin(pos)
    }

    // ================================================================
    // Mid-Air Pass — Plane passes overhead, first effects
    // ================================================================

    function _OnMidAir()
    {
        Dbg("MID-AIR PASS — Plane overhead")

        // Crash sound
        MaoLib_VFX.EmitSoundAt(PLANE_MID, "animation/planedoorblast.wav")

        // Screen shake
        MaoLib_VFX.ScreenShake(PLANE_MID, 4, 250, 2.0, 3000)

        // Slow motion
        if (_slowmoEnt && _slowmoEnt.IsValid())
        {
            DoEntFire("!self", "Start", "", 0, null, _slowmoEnt)
        }

        // Fire on plane (attached to plane position)
        if (_plane && _plane.IsValid())
        {
            MaoLib_VFX.SpawnParticleOnEntity(_plane, "gas_explosion_main",
                "", 3.0)
        }

        // Small explosion at mid-air point
        MaoLib_VFX.SpawnExplosion(PLANE_MID, "medium")

        // Plane sound fade (already playing, let it continue)
    }

    // ================================================================
    // Crash — Plane impacts, debris + Tank + fire
    // ================================================================

    function _OnCrash()
    {
        Dbg("CRASH — Plane impact")

        // Hide plane
        if (_plane && _plane.IsValid())
        {
            MaoLib_VFX.SafeKill(_plane)
        }

        // --- Big explosion at crash site ---
        MaoLib_VFX.SpawnExplosion(PLANE_CRASH, "large")

        // --- Screen shake ---
        MaoLib_VFX.ScreenShake(PLANE_CRASH, 4, 250, 2.0, 3000)

        // --- Fire particles at crash site ---
        MaoLib_VFX.SpawnParticle(PLANE_CRASH, "gas_explosion_main", 6.0)

        // --- Debris props ---
        _SpawnDebris()

        // --- Stop slow motion after 1.5s ---
        MaoLib.AddTimer("c3m2_slowmo_stop_" + UniqueString(), 1.5, function() {
            if (::MapRefresh.c3m2_swamp._slowmoEnt &&
                ::MapRefresh.c3m2_swamp._slowmoEnt.IsValid())
            {
                DoEntFire("!self", "Stop", "", 0, null,
                    ::MapRefresh.c3m2_swamp._slowmoEnt)
            }
        })

        // --- Explosion sound ---
        MaoLib_VFX.EmitSoundAt(PLANE_CRASH,
            "animation/gas_station_explosion.wav")
        MaoLib_VFX.EmitSoundAt(PLANE_CRASH,
            "ambient/nature/fire/fire_small1.wav")

        // --- Damage zone after crash ---
        MaoLib.DelayCall(function() {
            ::MapRefresh.c3m2_swamp._CreateDamageZone()
        }, 1.0)

        // --- Tank spawn with delay ---
        MaoLib.DelayCall(function() {
            ::MapRefresh.c3m2_swamp._SpawnTank()
        }, 2.0)
    }

    // ================================================================
    // Spawn Debris — Wreckage props at crash site
    // ================================================================

    function _SpawnDebris()
    {
        Dbg("Spawning debris")

        local debrisData = [
            { model = "models/props_vehicles/airplane_piperwreck.mdl",
              origin = Vector(8436, 402, 115), angles = "0 -80 0" },
            { model = "models/props_vehicles/airplane_piperwreckglass.mdl",
              origin = Vector(8436, 402, 115), angles = "0 0 0" },
            { model = "models/props_vehicles/airplane_piperwing.mdl",
              origin = Vector(8586, 333, 116), angles = "0 -105 0" },
            { model = "models/props_debris/burnt_building_debrispile_01.mdl",
              origin = Vector(8456, 260, 120), angles = "0 -90 0" },
            { model = "models/props_debris/burnt_building_debrispile_01.mdl",
              origin = Vector(8430, 279, 120), angles = "0 0 0" },
            { model = "models/props_debris/burnt_building_debrispile_01.mdl",
              origin = Vector(8461, 281, 157), angles = "0 -80 0" },
            { model = "models/deadbodies/dead_pilot.mdl",
              origin = Vector(8461, 281, 157), angles = "0 -80 0" },
        ]

        foreach (d in debrisData)
        {
            local prop = SpawnEntityFromTable("prop_dynamic", {
                model = d.model,
                origin = d.origin,
                angles = d.angles,
                disableshadows = 1,
                solid = 6
            })
            if (!prop)
                DbgWarn("Failed to spawn debris: " + d.model)
        }

        Dbg("Debris spawned: " + debrisData.len() + " props")
    }

    // ================================================================
    // Create Damage Zone — Fire zone affecting survivors
    // ================================================================

    function _CreateDamageZone()
    {
        Dbg("Creating damage zone")

        local hurt1 = SpawnEntityFromTable("script_trigger_hurt", {
            origin = HURT_CENTER,
            filtername = _filterEnt ? _filterEnt.GetName() : "",
            spawnflags = 1,
            damagetype = 8,     // Burn
            damagecap = 20,
            damage = 2,
            StartDisabled = 0,  // Enabled immediately
            extent = "200 300 64"
        })

        // Kill damage zone after 60s
        if (hurt1 && hurt1.IsValid())
        {
            MaoLib.AddTimer("c3m2_kill_hurt_" + UniqueString(), 60.0, function() {
                if (hurt1 && hurt1.IsValid()) hurt1.Kill()
            })
        }

        // Fire particles at crash site
        MaoLib_VFX.SpawnParticle(HURT_CENTER, "gas_explosion_main", 60.0)
        MaoLib_VFX.SpawnParticle(HURT_CENTER, "env_fire_large_smoke", 60.0)
        MaoLib_VFX.SpawnParticle(HURT_CENTER, "fire_tanker", 60.0)
        MaoLib_VFX.SpawnParticle(Vector(8461, 241, 130), "fire_tanker", 60.0)

        Dbg("Damage zone + fire particles active (60s)")
    }

    // ================================================================
    // Spawn Tank
    // ================================================================

    function _SpawnTank()
    {
        Dbg("Spawning Tank at crash site")

        local tankSpawn = SpawnEntityFromTable("info_zombie_spawn", {
            origin = TANK_POS,
            targetname = "c3m2_tank_" + UniqueString(),
            population = "river_docks_trap",
            offer_tank = 1,
            AttackOnSpawn = 1,
            angles = "0 -90 0"
        })

        if (tankSpawn)
        {
            tankSpawn.ConnectOutput("OnSpawnTank",
                "MapRefresh_c3m2_OnSpawnTank")
            Dbg("Tank spawn entity created")
        }
        else
        {
            DbgWarn("FAILED to create info_zombie_spawn!")
        }

        // Panic event after 3s (to give survivors time to react) — DelayCall one-shot
        MaoLib.DelayCall(function() {
            try { Director.ForcePanicEvent() } catch(e) { DbgWarn("ForcePanicEvent failed: " + e) }
            Dbg("Panic event triggered")
        }, 3.0)

        // Heart sound
        MaoLib_VFX.EmitSoundAt(TANK_POS, "player/heartbeatloop.wav")
    }
}

// ============================================================================
// Global callbacks for entity outputs
// ============================================================================

::MapRefresh_c3m2_OnSpawnTank <- function()
{
    printl("[MapRefresh][c3m2] Tank spawned, cleaning up")
    local ent = null
    while (ent = Entities.FindByClassname(ent, "info_zombie_spawn"))
    {
        if (ent.GetName().find("c3m2_") != null)
            ent.Kill()
    }
}

// ============================================================================
// Event Registration
// ============================================================================

::MapRefresh.c3m2_swamp_Events <- {
    function OnGameEvent_round_end(params)
    {
        if (!("c3m2_swamp" in ::MapRefresh)) return

        local s = ::MapRefresh.c3m2_swamp
        s._triggered = false
        if (s._timerName) MaoLib.RemoveTimer(s._timerName)
        if (s._planeTimer) MaoLib.RemoveTimer(s._planeTimer)

        // Clean up plane if alive
        if (s._plane && s._plane.IsValid())
            s._plane.Kill()
    }
}

__CollectGameEventCallbacks(::MapRefresh.c3m2_swamp_Events)

printl("[MapRefresh][c3m2] Script loaded")
