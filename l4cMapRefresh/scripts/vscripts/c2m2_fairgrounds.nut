// ============================================================================
// l4cMapRefresh - Dark Carnival: Fairgrounds (c2m2_fairgrounds)
// ============================================================================
// Source: CyberZoio Stripper - Wood Barricade + Tank Spawn
//         jeremyvillanuevar/vscripts_custom (props ref)
// 
// Events:
// - Wood Barricade: Gas can barricade explodes in stages when shot.
//   Fire burns for 60s with damage zone, nav eventually unblocks.
// - Tank Spawn: Door breaks open, Tank emerges in slow-motion.
// ============================================================================

::MapRefresh.c2m2_fairgrounds <- {
    Debug = 1

    function Dbg(msg) { if (Debug) printl("[MapRefresh][c2m2] " + msg) }
    function DbgWarn(msg) { printl("[MapRefresh][WARN][c2m2] " + msg) }

    _initialized = false
    BARRICADE_DONE = false
    TANK_DONE = false

    // -------------------------------------------------------------------------
    // Configuration - Wood Barricade
    // -------------------------------------------------------------------------
    BARRICADE_POS = Vector(-2826, -1985, -128)
    GASCAN_POS = Vector(-2795, -1994, -128)
    BARRICADE_NAV_POS = Vector(-2821, -1984, -65)

    // -------------------------------------------------------------------------
    // Configuration - Tank Spawn
    // -------------------------------------------------------------------------
    TANK_TRIGGER_POS = Vector(3065, -1632, 64)
    TANK_TRIGGER_EXTENT = Vector(5, 96, 64)
    TANK_DOOR_POS = Vector(2792, -1535, 0)
    TANK_SPAWN_POS = Vector(2715, -1495, 1)
    TANK_FIRE_POS = Vector(2752, -1518, 0)

    // -------------------------------------------------------------------------
    // Map Initialization
    // -------------------------------------------------------------------------
    function Init() {
        if (_initialized) return
        _initialized = true

        MaoLib.Mapper.SpawnReducedProps(::MapRefresh.c2m2_Props, 0.6,
            function(data, name) { return ::MapRefresh.Utils.SpawnProp(data, name) })

        InitWoodBarricade()
        InitTankSpawn()

        Dbg("initialized")
    }

    // ========================================================================
    // EVENT 1: WOOD BARRICADE
    // ========================================================================

    function InitWoodBarricade() {
        // Spawn gascan barricade prop_physics (shootable/ignitable)
        local gascan = SpawnEntityFromTable("prop_physics", {
            model = "models/props_unique/wooden_barricade_gascans.mdl"
            origin = GASCAN_POS
            angles = Vector(0, 125, 0)
            targetname = "barricade_gascan_" + UniqueString()
            spawnflags = 8  // debris
            disableshadows = 1
        })

        if (!gascan) {
            DbgWarn("Failed to spawn barricade gascan")
            return
        }

        // Hook OnBreak to trigger barricade event
        gascan.ConnectOutput("OnBreak", "MapRefresh_c2m2_OnBarricadeBroken")

        // Spawn nav blocker (barricade blocks path)
        local navBlock = SpawnEntityFromTable("script_nav_blocker", {
            origin = BARRICADE_NAV_POS
            extent = "5 64 64"
            teamToBlock = -1
            affectsFlow = 0
        })
        if (navBlock) {
            DoEntFire("!self", "BlockNav", "", 1, null, navBlock)
        }

        // Spawn initial barricade model
        SpawnEntityFromTable("prop_dynamic", {
            model = "models/props_unique/wooden_barricade.mdl"
            origin = BARRICADE_POS
            angles = Vector(0, 90, 0)
            targetname = "barricade_stage1_" + UniqueString()
            disableshadows = 1
            StartDisabled = 0
            solid = 6
        })

        Dbg("Wood Barricade initialized - shoot the gas cans!")
    }

    function _TriggerBarricade() {
        if (BARRICADE_DONE) return
        BARRICADE_DONE = true
        Dbg("Wood Barricade destroyed!")

        // Find and kill barricade stage 1, enable stage 2
        local ent = null
        while (ent = Entities.FindByClassname(ent, "prop_dynamic")) {
            local name = ent.GetName()
            if (name.find("barricade_stage1_") == 0) {
                MaoLib_VFX.SafeKill(ent, 0)
            }
        }

        // Spawn barricade stages 2-4 (progressively destroyed)
        _SpawnBarricadeStage("models/props_unique/wooden_barricade_break1.mdl", 0)
        _SpawnBarricadeStage("models/props_unique/wooden_barricade_break2.mdl", 30)
        _SpawnBarricadeStage("models/props_unique/wooden_barricade_break3.mdl", 60)

        // FX: explosion
        MaoLib_VFX.SpawnExplosion(BARRICADE_POS, "medium")
        MaoLib_VFX.SpawnParticle(BARRICADE_POS, "gas_explosion_main", 3.0)
        MaoLib_VFX.SpawnParticle(BARRICADE_POS, "env_fire_large_smoke", 65.0)

        // Shake
        MaoLib_VFX.ScreenShake(BARRICADE_POS, 4, 250, 2.0, 3000)

        // Slow-motion 1.5s
        try { Director.SetTimescale(0.2) } catch(e) { }
        MaoLib.AddTimer("barricade_timerestore", 1.5, function() {
            try { Director.SetTimescale(1.0) } catch(e) { }
        })

        // Sounds
        MaoLib_VFX.EmitSoundAt(BARRICADE_POS, "weapons/grenade_launcher/grenadefire/grenade_launcher_explode_2.wav")
        MaoLib_VFX.EmitSoundAt(BARRICADE_POS, "player/heartbeatloop.wav")
        MaoLib_VFX.EmitSoundAt(BARRICADE_POS, "ambient/nature/fire/fire_small1.wav")

        // Damage zone (60s)
        _SpawnDamageZone()

        // Unblock nav after 60s
        MaoLib.AddTimer("barricade_nav_unblock", 60.0, function() {
            ::MapRefresh.c2m2_fairgrounds._UnblockBarricadeNav()
        })

        // Panic event at 3s
        MaoLib.AddTimer("barricade_panic", 3.0, function() {
            try { Director.ForcePanicEvent() } catch(e) { }
        })

        Dbg("Barricade sequence fully triggered")
    }

    function _SpawnBarricadeStage(model, delay) {
        MaoLib.AddTimer("barricade_stage_" + delay, delay.tofloat(), function() {
            local stage = SpawnEntityFromTable("prop_dynamic", {
                model = model
                origin = ::MapRefresh.c2m2_fairgrounds.BARRICADE_POS
                angles = Vector(0, 90, 0)
                disableshadows = 1
                StartDisabled = 1
                solid = 0
            })
            if (stage) {
                stage.EnableDraw()
                // Kill stage after its display window
                if (model == "models/props_unique/wooden_barricade_break1.mdl") {
                    MaoLib_VFX.SafeKill(stage, 30)
                } else if (model == "models/props_unique/wooden_barricade_break2.mdl") {
                    MaoLib_VFX.SafeKill(stage, 30)
                }
            }
        })
    }

    function _SpawnDamageZone() {
        local hurt = SpawnEntityFromTable("script_trigger_hurt", {
            origin = BARRICADE_POS
            extent = "128 64 64"
            spawnflags = 1
            StartDisabled = 0
            damagetype = 8
            damagecap = 20
            damage = 2
        })
        if (hurt) {
            MaoLib_VFX.SafeKill(hurt, 60)
            Dbg("Damage zone active for 60s")
        }
    }

    function _UnblockBarricadeNav() {
        local ent = null
        while (ent = Entities.FindByClassname(ent, "script_nav_blocker")) {
            local name = ent.GetName()
            if (name.find("barricade_") == 0) {
                DoEntFire("!self", "UnblockNav", "", 0, null, ent)
                MaoLib_VFX.SafeKill(ent, 1)
            }
        }
        Dbg("Barricade nav unblocked")
    }

    // ========================================================================
    // EVENT 2: TANK SPAWN
    // ========================================================================

    function InitTankSpawn() {
        MaoLib.AddTimer("tank_spawn_check", 1.0, function() {
            ::MapRefresh.c2m2_fairgrounds._CheckTankTrigger()
        })
    }

    function _CheckTankTrigger() {
        if (TANK_DONE) return

        foreach (s in MaoLib.YieldSurvivors()) {
            if (!MaoLib.IsAlivePlayer(s)) continue

            local pos = s.GetOrigin()
            local dx = abs(pos.x - TANK_TRIGGER_POS.x)
            local dy = abs(pos.y - TANK_TRIGGER_POS.y)
            local dz = abs(pos.z - TANK_TRIGGER_POS.z)

            if (dx <= TANK_TRIGGER_EXTENT.x && dy <= TANK_TRIGGER_EXTENT.y && dz <= TANK_TRIGGER_EXTENT.z) {
                _TriggerTankSpawn()
                return
            }
        }
    }

    function _TriggerTankSpawn() {
        if (TANK_DONE) return
        TANK_DONE = true
        Dbg("Tank Spawn triggered")

        MaoLib.RemoveTimer("tank_spawn_check")

        // Break door props
        local ent = null
        while (ent = Entities.FindByClassname(ent, "prop_dynamic")) {
            local name = ent.GetName()
            if (name.find("tank_door_") == 0) {
                ent.Break()
            }
        }

        // Spawn breakable doors
        ::MapRefresh.c2m2_fairgrounds._SpawnDoors()

        // FX
        MaoLib_VFX.SpawnParticle(TANK_FIRE_POS, "gas_explosion_pump", 5.0)
        MaoLib_VFX.ScreenShake(TANK_SPAWN_POS, 4, 250, 2.0, 3000)

        // Slow-motion
        try { Director.SetTimescale(0.2) } catch(e) { }
        MaoLib.AddTimer("tank_timerestore", 1.5, function() {
            try { Director.SetTimescale(1.0) } catch(e) { }
        })

        // Sounds
        MaoLib_VFX.EmitSoundAt(TANK_SPAWN_POS, "weapons/grenade_launcher/grenadefire/grenade_launcher_explode_2.wav")
        MaoLib_VFX.EmitSoundAt(TANK_SPAWN_POS, "player/heartbeatloop.wav")

        // Spawn Tank
        local tankSpawn = SpawnEntityFromTable("info_zombie_spawn", {
            origin = TANK_SPAWN_POS
            angles = Vector(0, -90, 0)
            population = "river_docks_trap"
            offer_tank = 1
            AttackOnSpawn = 1
            targetname = "fair_tank_spawn_" + UniqueString()
        })
        if (tankSpawn) {
            DoEntFire("!self", "SpawnZombie", "", 0, null, tankSpawn)
            DoEntFire("!self", "Kill", "", 0.1, null, tankSpawn)
            try { Director.DisableTankFrustration() } catch(e) { }
        }

        // Panic event at 3s
        MaoLib.AddTimer("tank_panic", 3.0, function() {
            try { Director.ForcePanicEvent() } catch(e) { }
        })

        Dbg("Tank spawned at " + TANK_SPAWN_POS.ToString())
    }

    function _SpawnDoors() {
        foreach (x in [2792, 2712]) {
            local door = SpawnEntityFromTable("prop_dynamic", {
                model = "models/props_interiors/door_sliding_breakable01.mdl"
                origin = Vector(x, -1535, 0)
                angles = Vector(0, x == 2792 ? 90 : -90, 0)
                targetname = "tank_door_" + UniqueString()
                disableshadows = 1
                BreakableType = 2
                solid = 6
            })
            if (door) {
                DoEntFire("!self", "Break", "", 0.1, null, door)
            }
        }
    }

    // ======================================================================
    // CLEANUP — called by maprefresh_main on round_end
    // ======================================================================
    function _Cleanup() {
        if (Debug) printl("[c2m2] _Cleanup — removing all timers + restoring timescale")
        MaoLib.RemoveTimer("barricade_timerestore")
        MaoLib.RemoveTimer("barricade_nav_unblock")
        MaoLib.RemoveTimer("barricade_panic")
        MaoLib.RemoveTimer("tank_spawn_check")
        MaoLib.RemoveTimer("tank_timerestore")
        MaoLib.RemoveTimer("tank_panic")
        // Dynamic stage timers (barricade_stage_0, barricade_stage_30, barricade_stage_60)
        MaoLib.RemoveTimer("barricade_stage_0")
        MaoLib.RemoveTimer("barricade_stage_30")
        MaoLib.RemoveTimer("barricade_stage_60")
        // Restore normal timescale (safety: if round ended during slow-mo)
        Director.SetTimescale(1.0)
    }
}

::MapRefresh_c2m2_Cleanup <- {
    function OnGameEvent_round_end(params) {
        ::MapRefresh.c2m2_fairgrounds._Cleanup()
    }
}
__CollectGameEventCallbacks(::MapRefresh_c2m2_Cleanup)

// ============================================================================
// Global Callbacks for Entity Outputs
// ============================================================================

// ============================================================================
// Global Callbacks for Entity Outputs
// ============================================================================

::MapRefresh_c2m2_OnBarricadeBroken <- function() {
    if ("c2m2_fairgrounds" in ::MapRefresh) {
        ::MapRefresh.c2m2_fairgrounds._TriggerBarricade()
    }
}

// Event registration handled by maprefresh_main.Init() → LoadMapScript()
