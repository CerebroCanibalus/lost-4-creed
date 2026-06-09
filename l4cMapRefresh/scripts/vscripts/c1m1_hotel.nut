// ============================================================================
// l4cMapRefresh — Dead Center: Hotel (c1m1_hotel)
// ============================================================================
// Events ported from CyberZoio Stripper cfgs (original coordinates preserved)
//
// 1) LOBBY EXPLOSION + TANK — trigger zone near lobby exit → explosive + Tank
// 2) ELEVATOR CRASH — proximity at button pos → sparks + shake + panic
//
// Stripper data analyzed: c1m1_extras.cfg, c1m1_lobby_tank.cfg
// ============================================================================
// REWRITE NOTES (3 Jun 2026):
//  - REMOVED Sky Elevator: depended on Stripper-only entities (relay_top_button)
//  - REMOVED func_button spawn: brush entities can't be spawned via VScript
//  - BOTH events now use timer proximity (Stripper-compatible coordinates)
//  - NO ConnectOutput with "::" prefix (engine doesn't resolve scope operators)
//  - NO per-map __CollectGameEventCallbacks (Init() called from maprefresh_main)
// ============================================================================

::MapRefresh.c1m1_hotel <- {

    Debug = 1,

    // State flags
    _initialized = false,
    LOBBY_TANK_DONE = false,
    ELEVATOR_CRASH_DONE = false,

    // Constants (Stripper coordinates)
    LOBBY_TRIGGER_POS   = Vector(450, 4520, 1247),
    LOBBY_TRIGGER_RADIUS = 300.0,
    LOBBY_EXPLOSION_POS  = Vector(1219, 5000, 1184),
    LOBBY_TANK_SPAWN_POS = Vector(1219, 5000, 1185),
    ELEVATOR_BUTTON_POS   = Vector(2048, 5685.9, 2708.1),
    ELEVATOR_CRASH_RADIUS = 150.0,

    // --------------------------------------------------------------------------
    function Dbg(msg) {
        if (Debug) printl("[c1m1_hotel][DEBUG] " + msg)
    }

    // --------------------------------------------------------------------------
    // INIT — called from maprefresh_main.LoadMapScript after 2s delay
    // --------------------------------------------------------------------------
    function Init() {
        if (_initialized) return
        _initialized = true
        Dbg("ENTER Init")

        // Props (reduced 50% — skip if no refdata)
        SpawnProps()

        // Ambiance particles
        SpawnAmbiance()

        // Event 1: Lobby Explosion + Tank (CyberZoio)
        SetupLobbyTank()

        // Event 2: Elevator Crash (CyberZoio)
        SetupElevatorCrash()

        Dbg("Init complete")
    }

    // ======================================================================
    // PROPS (optional — skip if no refdata available)
    // ======================================================================

    function SpawnProps() {
        if (!("c1m1_Props" in ::MapRefresh)) {
            Dbg("No c1m1_Props in refdata — skipping props")
            return
        }
        local count = MaoLib.Mapper.SpawnReducedProps(::MapRefresh.c1m1_Props, 0.5,
            function(data, name) {
                return ::MapRefresh.Utils.SpawnProp(data, name)
            })
        Dbg("Spawned " + count + " props")
    }

    function SpawnAmbiance() {
        Dbg("Spawning ambiance particles")

        // Bugs in lobby/attic area (persistent)
        MaoLib_VFX.SpawnParticle(Vector(1483, 4249, 1198), "bugs_swamp", 300.0)

        // Fire particles near lobby (persistent)
        MaoLib_VFX.SpawnParticle(Vector(442.46, 5854.66, 1179.97), "c1m1_fire_particles_2", 300.0)

        // Burning building in skybox (persistent)
        MaoLib_VFX.SpawnParticle(Vector(6978, 12963, -963), "skybox_burning_building_4", 300.0)

        // Smoke from ceiling (persistent)
        MaoLib_VFX.SpawnParticle(Vector(1286.49, 4578.81, 1363.94), "subwaysmoke_ceiling", 300.0)

        Dbg("Ambiance spawned (4 particles)")
    }

    // ======================================================================
    // EVENT 1: LOBBY EXPLOSION + TANK SPAWN (CyberZoio)
    // ======================================================================
    // Stripper trigger: script_trigger_once at 450 4520 1247, extent 5 64 64
    //   → 6s delay → slow-motion + explosion + fire + shake + Tank
    //
    // VScript version: timer proximity, radius 300, same sequence
    //
    // Original Coords:
    //   Trigger center: 450  4520  1247  (extent 5 64 64)
    //   Explosion:      1219 5000  1184
    //   Tank spawn:     1219 5000  1185
    //   Barricades at 4 corners around explosion center
    // ======================================================================

    function SetupLobbyTank() {
        Dbg("Setting up Lobby Tank Event")

        // Spawn decorative debris
        SpawnLobbyDebris()

        // Start proximity check
        MaoLib.AddTimer("c1m1_lobby_check", 1.0, function() {
            ::MapRefresh.c1m1_hotel.CheckLobbyZone()
        })

        Dbg("Lobby Tank timer active at " + LOBBY_TRIGGER_POS + " radius " + LOBBY_TRIGGER_RADIUS)
    }

    // --------------------------------------------------------------------------
    function SpawnLobbyDebris() {
        // Barricades — wooden_barricade (solid 0, dynamic)
        local barricadePositions = [
            { pos = Vector(1151, 4907, 1184), ang = QAngle(0, 0, 0) },
            { pos = Vector(1277, 4907, 1184), ang = QAngle(0, 0, 0) },
            { pos = Vector(1151, 5152, 1184), ang = QAngle(0, 180, 0) },
            { pos = Vector(1277, 5152, 1184), ang = QAngle(0, 180, 0) },
        ]
        foreach (b in barricadePositions) {
            SpawnEntityFromTable("prop_dynamic", {
                model = "models/props_unique/wooden_barricade.mdl"
                origin = b.pos
                angles = b.ang
                solid = 0
                disableshadows = 1
            })
        }

        // Brick pallets — prop_physics
        local brickPositions = [
            { pos = Vector(1296, 4831, 1220), ang = QAngle(0, 2, 0) },
            { pos = Vector(1216, 4831, 1220), ang = QAngle(0, 266, 0) },
            { pos = Vector(1296, 4831, 1284), ang = QAngle(0, 2, 0) },
            { pos = Vector(1216, 4831, 1284), ang = QAngle(0, 266, 0) },
        ]
        foreach (b in brickPositions) {
            SpawnEntityFromTable("prop_physics", {
                model = "models/props_industrial/brickpallets.mdl"
                origin = b.pos
                angles = b.ang
                solid = 6
                spawnflags = 1
                disableshadows = 1
            })
        }

        // Oil drums
        SpawnEntityFromTable("prop_physics", {
            model = "models/props_urban/oil_drum001.mdl"
            origin = Vector(1109, 4839, 1184)
            angles = QAngle(0, 152, 0)
            solid = 6
            spawnflags = 1
            disableshadows = 1
        })
        SpawnEntityFromTable("prop_physics", {
            model = "models/props_urban/oil_drum001.mdl"
            origin = Vector(1120, 4835, 1232)
            angles = QAngle(0, 3, 0)
            solid = 6
            spawnflags = 1
            disableshadows = 1
        })
        SpawnEntityFromTable("prop_physics", {
            model = "models/props_urban/oil_drum001.mdl"
            origin = Vector(1143, 4830, 1184)
            angles = QAngle(0, 147, 0)
            solid = 6
            spawnflags = 1
            disableshadows = 1
        })

        // Scaffolding
        SpawnEntityFromTable("prop_dynamic", {
            model = "models/props_equipment/scaffolding_norails.mdl"
            origin = Vector(764, 4712, 1184)
            angles = QAngle(0, 91, 0)
            solid = 6
            disableshadows = 1
        })

        // Mall ramp bundle
        SpawnEntityFromTable("prop_dynamic", {
            model = "models/c1_chargerexit/mall_rampbundle.mdl"
            origin = Vector(1007, 4688, 1184)
            angles = QAngle(0, 55, 0)
            solid = 6
            disableshadows = 1
        })

        // Extra: handtruck, sawhorses, pallets
        SpawnEntityFromTable("prop_physics", {
            model = "models/props/cs_assault/handtruck.mdl"
            origin = Vector(1341, 4679, 1183)
            angles = QAngle(0, -65, 0)
            solid = 6
            spawnflags = 1
            disableshadows = 1
        })
        SpawnEntityFromTable("prop_physics", {
            model = "models/props_interiors/sawhorse.mdl"
            origin = Vector(1259, 4665, 1184)
            angles = QAngle(0, -80, 0)
            solid = 6
            spawnflags = 1
            disableshadows = 1
        })
        SpawnEntityFromTable("prop_physics", {
            model = "models/props_interiors/sawhorse.mdl"
            origin = Vector(1106, 4779, 1184)
            angles = QAngle(0, 68, 0)
            solid = 6
            spawnflags = 1
            disableshadows = 1
        })
        SpawnEntityFromTable("prop_physics", {
            model = "models/props_junk/wood_pallet001a.mdl"
            origin = Vector(1158, 4659, 1195)
            angles = QAngle(0, 8, 0)
            solid = 6
            spawnflags = 1
            disableshadows = 1
        })
        SpawnEntityFromTable("prop_physics", {
            model = "models/props_junk/wood_pallet001a.mdl"
            origin = Vector(1158, 4664, 1188)
            angles = QAngle(0, 89, 0)
            solid = 6
            spawnflags = 1
            disableshadows = 1
        })

        Dbg("Lobby debris spawned (~20 entities)")
    }

    // --------------------------------------------------------------------------
    function CheckLobbyZone() {
        if (LOBBY_TANK_DONE) return

        foreach (s in MaoLib.YieldSurvivors()) {
            if (!MaoLib.IsAlivePlayer(s)) continue

            local dist = MaoLib.DistanceBetween(s.GetOrigin(), LOBBY_TRIGGER_POS)
            if (dist <= LOBBY_TRIGGER_RADIUS) {
                Dbg("Survivor entered lobby zone (dist=" + dist + ") — triggering!")
                TriggerLobbyExplosion()
                return
            }
        }
    }

    // --------------------------------------------------------------------------
    function TriggerLobbyExplosion() {
        if (LOBBY_TANK_DONE) return
        LOBBY_TANK_DONE = true
        Dbg("LOBBY EXPLOSION TRIGGERED!")

        // Stop the check timer
        MaoLib.RemoveTimer("c1m1_lobby_check")

        // Warning to all survivors
        MaoLib.HUD.NotifyAll("CUIDADO!!!", {
            mode = "center"
            duration = 3.0
            priority = "high"
        })

        // 6s delay before explosion (original Stripper relay chain)
        MaoLib.AddTimer("c1m1_lobby_explosion", 6.0, @() ::MapRefresh.c1m1_hotel.DoLobbyExplosion())
        Dbg("Explosion scheduled in 6 seconds")
    }

    // --------------------------------------------------------------------------
    function DoLobbyExplosion() {
        Dbg("EXPLOSION NOW!")

        local center = LOBBY_EXPLOSION_POS

        // 1. Main explosion particle + explosive effect
        MaoLib_VFX.SpawnParticle(center, "gas_explosion_main", 5.0)
        MaoLib_VFX.SpawnExplosion(center, "large")

        // 2. Screen shake (strong)
        MaoLib_VFX.ScreenShake(center, 4, 250, 2.0, 3000)

        // 3. Fire at barricade corners + center
        local firePositions = [
            Vector(1151, 4907, 1184),
            Vector(1277, 4907, 1184),
            Vector(1151, 5152, 1184),
            Vector(1277, 5152, 1184),
            center,
        ]
        foreach (fp in firePositions) {
            MaoLib_VFX.SpawnParticle(fp, "env_fire_large_smoke", 8.0)
        }

        // 4. Explosion sounds
        MaoLib_VFX.EmitSoundAt(center, "weapons/grenade_launcher/grenadefire/grenade_launcher_explode_2.wav")
        MaoLib_VFX.EmitSoundAt(center, "ambient/nature/fire/fire_small1.wav")

        // 5. Heartbeat on all survivors
        foreach (s in MaoLib.YieldSurvivors()) {
            if (MaoLib.IsAlivePlayer(s)) {
                MaoLib_VFX.EmitSoundOnClient(s, "player/heartbeatloop.wav")
            }
        }
        // ⚠️ Schedule StopSoundOn after 20s — heartbeatloop es LOOPING, requiere parada explícita
        MaoLib.DelayCall(function() {
            foreach (s in MaoLib.YieldSurvivors()) {
                if (s.IsValid() && s.IsSurvivor())
                    StopSoundOn("player/heartbeatloop.wav", s)
            }
        }, 20.0)

        // 6. Force horde
        try { MaoLib.Mapper.TriggerMegaMob() } catch(e) {
            Dbg("TriggerMegaMob failed: " + e)
        }

        // 7. Spawn Tank after 3s
        MaoLib.AddTimer("c1m1_lobby_tank_spawn", 3.0, @() ::MapRefresh.c1m1_hotel.SpawnLobbyTank())
        Dbg("Lobby explosion complete — Tank in 3s")
    }

    // --------------------------------------------------------------------------
    function SpawnLobbyTank() {
        // Tank via info_zombie_spawn at Stripper coords
        local tankSpawner = SpawnEntityFromTable("info_zombie_spawn", {
            origin = LOBBY_TANK_SPAWN_POS
            angles = QAngle(0, -90, 0)
            population = "river_docks_trap"
            offer_tank = 1
            AttackOnSpawn = 1
        })

        if (tankSpawner && tankSpawner.IsValid()) {
            DoEntFire("!self", "SpawnZombie", "", 0, null, tankSpawner)
            DoEntFire("!self", "Kill", "", 0.5, null, tankSpawner)
            Dbg("Tank spawned at " + LOBBY_TANK_SPAWN_POS)

            // Aggressive Tank — disable frustration
            try { Director.DisableTankFrustration() } catch(e) {}
        } else {
            Dbg("ERROR: tankSpawner is null or invalid")
        }
    }

    // ======================================================================
    // EVENT 2: ELEVATOR CRASH (CyberZoio)
    // ======================================================================
    // Stripper: func_button at 2048 5685.9 2708.1 → spark + shake + crash + panic
    //   Button model: prop_dynamic at 2048 5695.9 2708.1
    //
    // VScript version: timer proximity + MaoLib_VFX effects
    //   No func_button (brush entity — not spawnable via VScript)
    //   When survivor walks near button position → auto-trigger crash
    //
    // Original Coords:
    //   Button:    2048  5685.9  2708.1
    //   Button mdl:2048  5695.9  2708.1
    // ======================================================================

    function SetupElevatorCrash() {
        Dbg("Setting up Elevator Crash Event")

        // Attempt to spawn button model (decorative only)
        try {
            SpawnEntityFromTable("prop_dynamic", {
                targetname = "c1m1_elev_btn_decor"
                origin = Vector(2048, 5695.9, 2708.1)
                angles = QAngle(0, 270, 0)
                model = "models/props_equipment/elevator_buttons.mdl"
                solid = 0
                disableshadows = 1
            })
            Dbg("Spawned elevator button model")
        } catch(e) {
            Dbg("Button model spawn failed (non-critical): " + e)
        }

        // Start proximity check
        MaoLib.AddTimer("c1m1_elevator_check", 1.0, function() {
            ::MapRefresh.c1m1_hotel.CheckElevatorZone()
        })

        Dbg("Elevator Crash timer active at " + ELEVATOR_BUTTON_POS + " radius " + ELEVATOR_CRASH_RADIUS)
    }

    // --------------------------------------------------------------------------
    function CheckElevatorZone() {
        if (ELEVATOR_CRASH_DONE) return

        foreach (s in MaoLib.YieldSurvivors()) {
            if (!MaoLib.IsAlivePlayer(s)) continue

            local dist = MaoLib.DistanceBetween(s.GetOrigin(), ELEVATOR_BUTTON_POS)
            if (dist <= ELEVATOR_CRASH_RADIUS) {
                Dbg("Survivor near elevator button (dist=" + dist + ") — crash!")
                TriggerElevatorCrash()
                return
            }
        }
    }

    // --------------------------------------------------------------------------
    function TriggerElevatorCrash() {
        if (ELEVATOR_CRASH_DONE) return
        ELEVATOR_CRASH_DONE = true
        Dbg("ELEVATOR CRASH TRIGGERED!")

        // Stop check timer
        MaoLib.RemoveTimer("c1m1_elevator_check")

        local pos = Vector(2048, 5695.9, 2708.1)

        // 1. Sparks
        MaoLib_VFX.SpawnParticle(pos, "sparks_steady_small", 4.0)
        MaoLib_VFX.SpawnParticle(pos, "sparks_elevator_start", 3.0)

        // 2. Screen shake (medium)
        MaoLib_VFX.ScreenShake(pos, 4, 250, 2.0, 1000)

        // 3. Crash sound
        MaoLib_VFX.EmitSoundAt(pos, "plats/elevator_emergency_power_off_01.wav")
        MaoLib_VFX.EmitSoundAt(pos, "ambient/alarms/klaxon1.wav")

        // 4. Force horde after 3s (panic event)
        MaoLib.AddTimer("c1m1_elevator_horde", 3.0, function() {
            try { MaoLib.Mapper.TriggerMegaMob() } catch(e) {
                ::MapRefresh.c1m1_hotel.Dbg("TriggerMegaMob failed: " + e)
            }
        })

        Dbg("Elevator crash complete — horde in 3s")
    }

    // ======================================================================
    // CLEANUP — called by maprefresh_main on round_end
    // ======================================================================
    function _Cleanup() {
        Dbg("_Cleanup — removing all timers + stopping sounds")
        MaoLib.RemoveTimer("c1m1_lobby_check")
        MaoLib.RemoveTimer("c1m1_lobby_explosion")
        MaoLib.RemoveTimer("c1m1_lobby_tank_spawn")
        MaoLib.RemoveTimer("c1m1_elevator_check")
        MaoLib.RemoveTimer("c1m1_elevator_horde")
        // Stop heartbeatloop on all survivors
        foreach (s in MaoLib.YieldSurvivors()) {
            if (s.IsValid() && s.IsSurvivor())
                StopSoundOn("player/heartbeatloop.wav", s)
        }
    }
}

::MapRefresh_c1m1_Cleanup <- {
    function OnGameEvent_round_end(params) {
        ::MapRefresh.c1m1_hotel._Cleanup()
    }
}
__CollectGameEventCallbacks(::MapRefresh_c1m1_Cleanup)
