// ============================================================================
// c3m3_shantytown.nut — Tank Spawn Event
// Survivors enter trigger corridor (warehouse area) → explosion + Tank + panic
// Source: CyberZoio Stripper (c3m3_shantytown-TANK-SPAWN.cfg)
// ============================================================================

// ============================================================================
// Event Configuration
// ============================================================================

::MapRefresh.c3m3_shantytown <- {
    Debug = 1,

    // === Event positions (from CyberZoio Stripper data) ===
    TRIGGER_POS = Vector(-3450, 414, 119),      // Long corridor trigger
    TANK_POS    = Vector(-2773, -229, 6),        // Tank spawn + fire + explosion

    TRIGGER_RADIUS = 275,    // Half of extent 550
    TANK_HURT_POS  = Vector(-2773, -229, 70),   // Damage zone position
    HURT_RADIUS    = 128,    // Extent 128

    // === State ===
    _triggered = false,
    _timerName = null,
    _filterEnt = null,
    _slowmoEnt = null,
    _hurtEnt   = null,

    // ================================================================
    // Debug
    // ================================================================

    function Dbg(msg) {
        if (Debug) printl("[MapRefresh][c3m3] " + msg)
    }
    function DbgWarn(msg) {
        printl("[MapRefresh][WARN][c3m3] " + msg)
    }

    // ================================================================
    // Init — called by maprefresh_main after 2s delay
    // ================================================================

    function Init()
    {
        Dbg("Init — setting up Tank Spawn trigger")

        // Create survivor filter for damage zone
        _filterEnt = SpawnEntityFromTable("filter_activator_team", {
            targetname = "c3m3_filter_" + UniqueString(),
            filterteam = 2,
            Negated = 0
        })

        if (_filterEnt) Dbg("Filter created: " + _filterEnt.tostring())

        // Create slow-motion entity
        _slowmoEnt = SpawnEntityFromTable("func_timescale", {
            targetname = "c3m3_slowmo",
            minBlendRate = 2,
            desiredTimescale = "0.2",
            blendDeltaMultiplier = "3.0",
            acceleration = "0.05"
        })

        // Create damage zone (disabled initially)
        _hurtEnt = SpawnEntityFromTable("script_trigger_hurt", {
            targetname = "c3m3_hurt",
            origin = TANK_HURT_POS,
            filtername = _filterEnt ? _filterEnt.GetName() : "",
            spawnflags = 1,
            damagetype = 8,        // Burn
            damagecap = 20,
            damage = 2,
            StartDisabled = 1,
            extent = "128 128 64"
        })

        // Start trigger checker
        _timerName = "c3m3_check_" + UniqueString()
        MaoLib.AddTimerAuto(_timerName, 1.0, function() {
            ::MapRefresh.c3m3_shantytown._CheckTrigger()
        })

        Dbg("Init complete")
    }

    // ================================================================
    // Check Trigger — polling survivors in zone
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
                _OnTrigger()
                return
            }
        }
    }

    // ================================================================
    // On Trigger — Tank spawn sequence
    // ================================================================

    function _OnTrigger()
    {
        _triggered = true
        MaoLib.RemoveTimer(_timerName)
        Dbg("TRIGGERED — Tank Spawn!")

        // --- Step 1: Hint to players ---
        MaoLib.HUD.NotifyAll("Something's coming...", {
            mode = "center",
            typeKey = "c3m3_tank",
            throttle = 0,
            priority = "high"
        })

        // --- Step 2: Screen shake ---
        MaoLib_VFX.ScreenShake(TANK_POS, 4, 250, 2.0, 3000)

        // --- Step 3: Explosion ---
        MaoLib_VFX.SpawnExplosion(TANK_POS, "large")

        // --- Step 4: Fire particle ---
        MaoLib_VFX.SpawnParticle(TANK_POS, "gas_explosion_main", 5.0)

        // --- Step 5: Slow motion (0.2x for 1.5s) ---
        if (_slowmoEnt && _slowmoEnt.IsValid())
        {
            DoEntFire("!self", "Start", "", 0, null, _slowmoEnt)
            MaoLib.AddTimer("c3m3_slowmo_stop_" + UniqueString(), 1.5, function() {
                if (::MapRefresh.c3m3_shantytown._slowmoEnt &&
                    ::MapRefresh.c3m3_shantytown._slowmoEnt.IsValid())
                {
                    DoEntFire("!self", "Stop", "", 0, null,
                        ::MapRefresh.c3m3_shantytown._slowmoEnt)
                }
            })
        }

        // --- Step 6: Sound effects ---
        MaoLib_VFX.EmitSoundAt(TANK_POS,
            "weapons/grenade_launcher/grenadefire/grenade_launcher_explode_2.wav")
        MaoLib_VFX.EmitSoundAt(TANK_POS, "player/heartbeatloop.wav")
        // Fade heart sound after 1.5s
        MaoLib.AddTimerAuto("c3m3_heart_fade_" + UniqueString(), 1.5, function() {
            StopAmbientSoundOn("player/heartbeatloop.wav", null)
        })

        // --- Step 7: Damage zone (60s of fire) ---
        if (_hurtEnt && _hurtEnt.IsValid())
        {
            DoEntFire("!self", "Enable", "", 0, null, _hurtEnt)
            MaoLib.AddTimer("c3m3_kill_hurt_" + UniqueString(), 60.0, function() {
                if (::MapRefresh.c3m3_shantytown._hurtEnt &&
                    ::MapRefresh.c3m3_shantytown._hurtEnt.IsValid())
                {
                    ::MapRefresh.c3m3_shantytown._hurtEnt.Kill()
                }
            })
        }

        // --- Step 8: Tank spawn (delay to let explosion settle) ---
        MaoLib.DelayCall(function() {
            ::MapRefresh.c3m3_shantytown._SpawnTank()
        }, 0.5)
    }

    // ================================================================
    // Spawn Tank
    // ================================================================

    function _SpawnTank()
    {
        Dbg("Spawning Tank")

        local tankSpawn = SpawnEntityFromTable("info_zombie_spawn", {
            origin = TANK_POS,
            targetname = "c3m3_tank_" + UniqueString(),
            population = "river_docks_trap",
            offer_tank = 1,
            AttackOnSpawn = 1,
            angles = "0 135 0"
        })

        if (tankSpawn)
        {
            // Connect OnSpawnTank to auto-kill the spawn point
            tankSpawn.ConnectOutput("OnSpawnTank",
                "MapRefresh_c3m3_OnSpawnTank")
            MaoLib_VFX.EmitSoundAt(TANK_POS, "player/heartbeatloop.wav")
            Dbg("Tank spawn entity created")
        }
        else
        {
            DbgWarn("FAILED to create info_zombie_spawn!")
        }
    }
}

// ============================================================================
// Global callbacks for entity outputs
// ============================================================================

::MapRefresh_c3m3_OnSpawnTank <- function()
{
    printl("[MapRefresh][c3m3] Tank spawned, cleaning up spawn point")

    // Find and kill the tank spawn entity
    local ent = null
    while (ent = Entities.FindByClassname(ent, "info_zombie_spawn"))
    {
        if (ent.GetName().find("c3m3") != null)
        {
            ent.Kill()
        }
    }
}

// ============================================================================
// Event Registration
// ============================================================================

::MapRefresh.c3m3_shantytown_Events <- {
    function OnGameEvent_round_end(params)
    {
        if (!("c3m3_shantytown" in ::MapRefresh)) return

        local s = ::MapRefresh.c3m3_shantytown
        s._triggered = false
        if (s._timerName) MaoLib.RemoveTimer(s._timerName)
    }
}

__CollectGameEventCallbacks(::MapRefresh.c3m3_shantytown_Events)

printl("[MapRefresh][c3m3] Script loaded")
