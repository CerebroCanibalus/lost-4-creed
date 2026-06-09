// ============================================================================
// l4cMapRefresh — Dead Center: Streets (c1m2_streets)
// ============================================================================
// Events ported from CyberZoio Stripper cfgs (original coordinates preserved)
//
// 1) GAS TANKER EXPLOSION + TANK — trigger zone along street → explosion + Tank
//
// Stripper data analyzed: c1m2_gas_tanker.cfg, c1m2_slowmotion.cfg
// ============================================================================
// REWRITE NOTES (3 Jun 2026):
//  - REMOVED Gunshop Ambush: depended on fake event (OnGameEvent_explain_gun_shop_tanker)
//  - REMOVED Streets Ambush: depended on global ::closeARRange hooking Stripper-only entities
//  - REMOVED F18 Bomber: General decision (excessive, skip)
//  - REMOVED separate Tanker Slow-mo: integrated into Gas Tanker explosion sequence
//  - Tanker explosion includes heartbeat + shake (no time scale — dangerous in VScript)
//  - NO ConnectOutput with "::" prefix (engine doesn't resolve scope operators)
//  - NO per-map __CollectGameEventCallbacks (Init() called from maprefresh_main)
// ============================================================================

::MapRefresh.c1m2_streets <- {

    Debug = 1,

    // State flags
    _initialized = false,
    TANKER_EVENT_DONE = false,

    // Constants (Stripper coordinates)
    TANKER_TRIGGER_POS   = Vector(-8386, -3322, 511),
    TANKER_TRIGGER_RADIUS = 500.0,
    TANKER_EXPLOSION_POS  = Vector(-9056, -4372, 384),
    TANKER_TANK_SPAWN_POS = Vector(-9056, -4372, 385),
    TANKER_FIRE_JET_POS   = Vector(-9041, -4275, 540),

    // --------------------------------------------------------------------------
    function Dbg(msg) {
        if (Debug) printl("[c1m2_streets][DEBUG] " + msg)
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

        // Event 1: Gas Tanker Explosion + Tank
        SetupGasTanker()

        Dbg("Init complete")
    }

    // ======================================================================
    // PROPS (optional — skip if no refdata available)
    // ======================================================================

    function SpawnProps() {
        if (!("c1m2_Props" in ::MapRefresh)) {
            Dbg("No c1m2_Props in refdata — skipping props")
            return
        }
        local count = MaoLib.Mapper.SpawnReducedProps(::MapRefresh.c1m2_Props, 0.5,
            function(data, name) {
                return ::MapRefresh.Utils.SpawnProp(data, name)
            })
        Dbg("Spawned " + count + " props")
    }

    function SpawnAmbiance() {
        Dbg("Spawning ambiance particles")

        // Paper blowing on streets (persistent)
        MaoLib_VFX.SpawnParticle(Vector(-2166.9, 3002.4, 1.2), "paper_streets", 300.0)

        // Leaves falling near tree areas (persistent)
        MaoLib_VFX.SpawnParticle(Vector(1632, 4355, 664), "leaves_green", 300.0)

        // Embers from burning areas (persistent)
        MaoLib_VFX.SpawnParticle(Vector(-746.8, 3063.5, 590.4), "embers_large_02", 300.0)

        // Smoke exhaust (persistent)
        MaoLib_VFX.SpawnParticle(Vector(1538, 2560, 644), "smoke_exhaust_01", 300.0)

        // Riverboat smoke in distance (persistent)
        MaoLib_VFX.SpawnParticle(Vector(902.7, 3836.9, 727.5), "fire_riverboat_smoke", 300.0)

        Dbg("Ambiance spawned (5 particles)")
    }

    // ======================================================================
    // EVENT 1: GAS TANKER EXPLOSION + TANK (CyberZoio)
    // ======================================================================
    // Stripper: script_trigger_once at -8386 -3322 511, extent 832 5 128
    //   → gas hiss + 5s delay → explosion + fire + shake + slow-mo + Tank
    //
    // VScript version: timer proximity (radius 500), same sequence
    //   Slow-motion effects = heartbeat + shake (no time scale)
    //
    // Original Coords:
    //   Trigger:     -8386  -3322   511  (extent 832 5 128 — wall across street)
    //   Fire jet:    -9041  -4275   540  (angles -90 20 0)
    //   Tanker:      -9056  -4372   444
    //   Explosion:   -9056  -4372   384
    //   Tank spawn:  -9056  -4372   385
    // ======================================================================

    function SetupGasTanker() {
        Dbg("Setting up Gas Tanker Event")

        // 1. Start gas leak fire jet (originally from logic_auto on map spawn)
        try {
            local jet = SpawnEntityFromTable("info_particle_system", {
                targetname = "c1m2_gastanker_jet"
                effect_name = "fire_jet_01"
                origin = TANKER_FIRE_JET_POS
                angles = QAngle(-90, 20, 0)
            })
            if (jet && jet.IsValid()) {
                DoEntFire("!self", "Start", "", 0, null, jet)
                Dbg("Gas leak fire jet started")
            }
        } catch(e) {
            Dbg("Fire jet spawn failed (non-critical): " + e)
        }

        // 2. Spawn tanker model (prop_dynamic, solid 0)
        try {
            SpawnEntityFromTable("prop_dynamic", {
                targetname = "c1m2_gastanker_prop"
                origin = Vector(-9056, -4372, 444)
                angles = QAngle(0, -90, 0)
                model = "models/props/de_train/de_train_horizontalcoolingtank.mdl"
                solid = 0
                disableshadows = 1
            })
        } catch(e) {
            Dbg("Tanker model spawn failed (non-critical): " + e)
        }

        // 3. Spawn debris model (hidden until explosion)
        try {
            SpawnEntityFromTable("prop_dynamic", {
                targetname = "c1m2_gastanker_debris"
                origin = Vector(-9031, -4435, 387)
                angles = QAngle(-10, 0, 0)
                model = "models/props_debris/concrete_debris256pile001a.mdl"
                solid = 0
                disableshadows = 1
                StartDisabled = 1
            })
        } catch(e) {
            Dbg("Debris model spawn failed (non-critical): " + e)
        }

        // 4. Props around tanker: pallet, oil drums, forklift
        SpawnTankerProps()

        // 5. Start proximity check
        MaoLib.AddTimer("c1m2_tanker_check", 1.0, function() {
            ::MapRefresh.c1m2_streets.CheckTankerZone()
        })

        Dbg("Gas Tanker ready — fire jet active, trigger radius " + TANKER_TRIGGER_RADIUS)
    }

    // --------------------------------------------------------------------------
    function SpawnTankerProps() {
        local props = [
            { mdl = "models/props/de_prodigy/wood_pallet_01.mdl",
              pos = Vector(-8941, -4192, 385), ang = QAngle(0, -138, 0) },
            { mdl = "models/props_urban/oil_drum001.mdl",
              pos = Vector(-8931, -4208, 392), ang = QAngle(0, -146, 0) },
            { mdl = "models/props_urban/oil_drum001.mdl",
              pos = Vector(-8945, -4174, 392), ang = QAngle(0, 179, 0) },
            { mdl = "models/props_urban/oil_drum001.mdl",
              pos = Vector(-8935, -4195, 441), ang = QAngle(0, -160, 0) },
            { mdl = "models/props/cs_assault/forklift.mdl",
              pos = Vector(-8871, -4301, 385), ang = QAngle(0, -48, 0) },
        ]
        foreach (p in props) {
            try {
                SpawnEntityFromTable("prop_physics", {
                    model = p.mdl
                    origin = p.pos
                    angles = p.ang
                    spawnflags = 256
                    disableshadows = 1
                })
            } catch(e) {
                Dbg("Prop spawn failed for " + p.mdl + ": " + e)
            }
        }
        Dbg("Tanker props spawned (" + props.len() + " entities)")
    }

    // --------------------------------------------------------------------------
    function CheckTankerZone() {
        if (TANKER_EVENT_DONE) return

        foreach (s in MaoLib.YieldSurvivors()) {
            if (!MaoLib.IsAlivePlayer(s)) continue

            local dist = MaoLib.DistanceBetween(s.GetOrigin(), TANKER_TRIGGER_POS)
            if (dist <= TANKER_TRIGGER_RADIUS) {
                Dbg("Survivor entered tanker zone (dist=" + dist + ") — triggering!")
                TriggerGasTanker()
                return
            }
        }
    }

    // --------------------------------------------------------------------------
    function TriggerGasTanker() {
        if (TANKER_EVENT_DONE) return
        TANKER_EVENT_DONE = true
        Dbg("GAS TANKER TRIGGERED!")

        // Stop the check timer
        MaoLib.RemoveTimer("c1m2_tanker_check")

        // 1. Gas hiss sound starts immediately
        MaoLib_VFX.EmitSoundAt(TANKER_EXPLOSION_POS, "ambient/gas/steam_loop1.wav")

        // 2. Show warning
        MaoLib.HUD.NotifyAll("ATENCION!!!", {
            mode = "center"
            duration = 3.0
            priority = "high"
        })

        // 3. Explosion after 5s delay (original Stripper relay chain)
        MaoLib.AddTimer("c1m2_tanker_explode", 5.0, @() ::MapRefresh.c1m2_streets.DoGasTankerExplosion())
        Dbg("Tanker will explode in 5 seconds")
    }

    // --------------------------------------------------------------------------
    function DoGasTankerExplosion() {
        Dbg("TANKER EXPLOSION NOW!")

        local center = TANKER_EXPLOSION_POS

        // Kill the fire jet (gas leak stops when exploding)
        try {
            local jet = Entities.FindByName(null, "c1m2_gastanker_jet")
            if (jet && jet.IsValid()) DoEntFire("!self", "Kill", "", 0, null, jet)
        } catch(e) {}

        // 1. Main explosion particle
        MaoLib_VFX.SpawnParticle(center, "gas_explosion_main", 5.0)
        MaoLib_VFX.SpawnExplosion(center, "medium")

        // 2. Screen shake (strong)
        MaoLib_VFX.ScreenShake(center, 4, 250, 2.0, 3000)

        // 3. Hide tanker, show debris
        try { DoEntFire("c1m2_gastanker_prop", "Disable", "", 0, null, null) } catch(e) {}
        try { DoEntFire("c1m2_gastanker_debris", "Enable", "", 0, null, null) } catch(e) {}

        // 4. Sounds — explosion + fire + gas leak
        MaoLib_VFX.EmitSoundAt(center, "weapons/grenade_launcher/grenadefire/grenade_launcher_explode_2.wav")
        MaoLib_VFX.EmitSoundAt(center, "physics/destruction/explosivegasleak.wav")
        MaoLib_VFX.EmitSoundAt(center, "ambient/nature/fire/fire_small1.wav")

        // 5. Heartbeat on all survivors (slow-motion effect)
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

        // 6. Impact effects at prop positions
        local impactPositions = [
            Vector(-8941, -4192, 385),
            Vector(-8931, -4208, 392),
            Vector(-8945, -4174, 392),
            Vector(-8935, -4195, 441),
            Vector(-8871, -4301, 385),
        ]
        foreach (ip in impactPositions) {
            MaoLib_VFX.SpawnImpact(ip, Vector(0, 20, 0), "concrete")
        }

        // 7. Force horde
        try { MaoLib.Mapper.TriggerMegaMob() } catch(e) {
            Dbg("TriggerMegaMob failed: " + e)
        }

        // 8. Spawn Tank after 3s dramatic delay
        MaoLib.AddTimer("c1m2_tanker_tank", 3.0, @() ::MapRefresh.c1m2_streets.SpawnTankerTank())
        Dbg("Tanker explosion complete — Tank in 3s")
    }

    // --------------------------------------------------------------------------
    function SpawnTankerTank() {
        local tankSpawner = SpawnEntityFromTable("info_zombie_spawn", {
            origin = TANKER_TANK_SPAWN_POS
            angles = QAngle(0, 0, 0)
            population = "river_docks_trap"
            offer_tank = 1
            AttackOnSpawn = 1
        })
        if (tankSpawner && tankSpawner.IsValid()) {
            DoEntFire("!self", "SpawnZombie", "", 0, null, tankSpawner)
            DoEntFire("!self", "Kill", "", 0.5, null, tankSpawner)
            Dbg("Tank spawned at " + TANKER_TANK_SPAWN_POS)
            try { Director.DisableTankFrustration() } catch(e) {}
        } else {
            Dbg("ERROR: Tank spawner is null or invalid")
        }
    }

    // ======================================================================
    // CLEANUP — called by maprefresh_main on round_end
    // ======================================================================
    function _Cleanup() {
        if (Debug) printl("[c1m2] _Cleanup — removing all timers + stopping sounds")
        MaoLib.RemoveTimer("c1m2_tanker_check")
        MaoLib.RemoveTimer("c1m2_tanker_explode")
        MaoLib.RemoveTimer("c1m2_tanker_tank")
        // Stop heartbeatloop on all survivors
        foreach (s in MaoLib.YieldSurvivors()) {
            if (s.IsValid() && s.IsSurvivor())
                StopSoundOn("player/heartbeatloop.wav", s)
        }
    }
}

::MapRefresh_c1m2_Cleanup <- {
    function OnGameEvent_round_end(params) {
        ::MapRefresh.c1m2_streets._Cleanup()
    }
}
__CollectGameEventCallbacks(::MapRefresh_c1m2_Cleanup)
