// ============================================================================
// l4cMapRefresh - Dark Carnival: Highway (c2m1_highway)
// ============================================================================
// Source: CyberZoio Stripper - Heli Hotel + Tank Spawn
//         jeremyvillanuevar/vscripts_custom (props ref)
// 
// Events:
// - Heli Hotel: Helicopter takes off from hotel, explodes mid-air,
//   drops Tank + debris + fire zone. Cinematic sequence ~38s.
// ============================================================================

::MapRefresh.c2m1_highway <- {
    Debug = 1

    function Dbg(msg) { if (Debug) printl("[MapRefresh][c2m1] " + msg) }
    function DbgWarn(msg) { printl("[MapRefresh][WARN][c2m1] " + msg) }

    _initialized = false
    HELI_ACTIVE = false
    HELI_DONE = false

    // -------------------------------------------------------------------------
    // Configuration
    // -------------------------------------------------------------------------
    TRIGGER_POS = Vector(3811, 7422, -828)
    TRIGGER_EXTENT = Vector(5, 212, 64)

    HELI_POS = Vector(2315, 4030, -500)
    TANK_POS = Vector(2106, 4298, -760)
    EXPLOSION_POS = Vector(2468, 4297, -1032)
    FIRE_POS = Vector(2468, 4297, -1032)
    BOX_POS = Vector(2106, 4298, -727)
    DAMAGE_POS = Vector(2400, 4286, -985)

    NAV_BLOCK_POS = Vector(3376, 6978, -912)
    PHYS_BLOCK_POS = Vector(4590, 7342, -626)

    // -------------------------------------------------------------------------
    // Map Initialization
    // -------------------------------------------------------------------------
    function Init() {
        if (_initialized) return
        _initialized = true

        MaoLib.Mapper.SpawnReducedProps(::MapRefresh.c2m1_Props, 0.6,
            function(data, name) { return ::MapRefresh.Utils.SpawnProp(data, name) })

        InitHeliHotel()

        Dbg("initialized")
    }

    // -------------------------------------------------------------------------
    // HELI HOTEL EVENT
    // -------------------------------------------------------------------------
    _heli = null
    _ambientHeli = null

    function InitHeliHotel() {
        // Check trigger zone periodically
        MaoLib.AddTimer("heli_hotel_check", 1.0, function() {
            ::MapRefresh.c2m1_highway._CheckHeliTrigger()
        })
    }

    function _CheckHeliTrigger() {
        if (HELI_ACTIVE || HELI_DONE) return

        foreach (s in MaoLib.YieldSurvivors()) {
            if (!MaoLib.IsAlivePlayer(s)) continue

            local pos = s.GetOrigin()
            local dx = abs(pos.x - TRIGGER_POS.x)
            local dy = abs(pos.y - TRIGGER_POS.y)
            local dz = abs(pos.z - TRIGGER_POS.z)

            if (dx <= TRIGGER_EXTENT.x && dy <= TRIGGER_EXTENT.y && dz <= TRIGGER_EXTENT.z) {
                _StartHeliEvent()
                return
            }
        }
    }

    function _StartHeliEvent() {
        HELI_ACTIVE = true
        Dbg("HELI HOTEL event started")

        MaoLib.RemoveTimer("heli_hotel_check")

        // --- Spawn helicopter ---
        _heli = SpawnEntityFromTable("prop_dynamic", {
            model = "models/hybridphysx/news_helicoptor_hoveranim.mdl"
            origin = HELI_POS
            angles = Vector(0, 90, 0)
            targetname = "heli_hotel_prop_" + UniqueString()
            disableshadows = 1
            DefaultAnim = "landed"
            solid = 6
        })

        if (!_heli) {
            DbgWarn("Failed to spawn helicopter")
            HELI_ACTIVE = false
            return
        }

        // --- Spawn pilot parented to heli ---
        local pilot = SpawnEntityFromTable("prop_dynamic", {
            model = "models/npcs/rescue_pilot_01.mdl"
            origin = HELI_POS
            angles = Vector(0, 180, 0)
            targetname = "heli_hotel_pilot_" + UniqueString()
            disableshadows = 1
            parentname = _heli.GetName()
            DefaultAnim = "Sit_Helicopter"
            solid = 6
        })

        // --- Spawn breakable box ---
        local box = SpawnEntityFromTable("prop_physics", {
            model = "models/props_junk/wood_crate002a.mdl"
            origin = BOX_POS
            angles = Vector(0, 180, 90)
            targetname = "heli_hotel_box_" + UniqueString()
            disableshadows = 1
            spawnflags = 256
            BreakableType = 2
            solid = 6
        })

        MaoLib_VFX.ScreenShake(HELI_POS, 2, 8, 1.0, 1000)  // Initial rumble

        // --- Timeline (timer chain) ---

        // t=0: Heli loop + war sounds
        _PlayHeliLoop()
        MaoLib_VFX.EmitSoundAt(HELI_POS, "ambient/levels/streetwar/city_battle3.wav")

        // t=5: War 2
        MaoLib.AddTimer("heli_war2", 5.0, @() MaoLib_VFX.EmitSoundAt(::MapRefresh.c2m1_highway.HELI_POS, "ambient/levels/streetwar/city_battle3.wav"))

        // t=9: Radio chatter 1
        MaoLib.AddTimer("heli_talk1", 9.0, @() MaoLib_VFX.EmitSoundAt(::MapRefresh.c2m1_highway.HELI_POS, "npc/planepilot/radiobutton105.wav"))

        // t=10: Heli takes off
        MaoLib.AddTimer("heli_takeoff", 10.0, function() {
            if (::MapRefresh.c2m1_highway._heli && ::MapRefresh.c2m1_highway._heli.IsValid())
                DoEntFire("!self", "SetAnimation", "Takeoff", 0, null, ::MapRefresh.c2m1_highway._heli)
        })

        // t=15: Beeps
        MaoLib.AddTimer("heli_beep", 15.0, @() MaoLib_VFX.EmitSoundAt(::MapRefresh.c2m1_highway.HELI_POS, "animation/10_sec_half_beeps.wav"))

        // t=25: EXPLOSION + TANK
        MaoLib.AddTimer("heli_explosion", 25.0, function() {
            ::MapRefresh.c2m1_highway._TriggerExplosion()
        })

        // t=28: Panic event
        MaoLib.AddTimer("heli_panic", 28.0, function() {
            try { Director.ForcePanicEvent() } catch(e) { }
        })

        // t=32: Radio chatter 2
        MaoLib.AddTimer("heli_talk2", 32.0, @() MaoLib_VFX.EmitSoundAt(::MapRefresh.c2m1_highway.HELI_POS, "npc/chopper_pilot/hospital_intro_heli_15.wav"))

        // t=38: Kill heli
        MaoLib.AddTimer("heli_kill", 38.0, function() {
            ::MapRefresh.c2m1_highway._CleanupHeli()
        })

        Dbg("Heli event timeline started")
    }

    function _PlayHeliLoop() {
        // Spawn ambient_generic pointing to helicopter for positional sound
        _ambientHeli = SpawnEntityFromTable("ambient_generic", {
            message = "Hospital.HelicopterLoop"
            SourceEntityName = _heli.GetName()
            spawnflags = 48  // looping + start silent
            radius = 10000
            health = 10
        })
        if (_ambientHeli) {
            DoEntFire("!self", "PlaySound", "", 0, null, _ambientHeli)
            // Fade out and kill heli sound at t=33
            MaoLib.AddTimer("heli_ambient_fade", 33.0, function() {
                if (::MapRefresh.c2m1_highway._ambientHeli &&
                    ::MapRefresh.c2m1_highway._ambientHeli.IsValid()) {
                    DoEntFire("!self", "FadeOut", "5", 0, null,
                        ::MapRefresh.c2m1_highway._ambientHeli)
                    DoEntFire("!self", "Kill", "", 6, null,
                        ::MapRefresh.c2m1_highway._ambientHeli)
                }
            })
        }
    }

    function _TriggerExplosion() {
        Dbg("HELI EXPLOSION triggered")

        // Visual explosion
        MaoLib_VFX.SpawnExplosion(EXPLOSION_POS, "large")
        MaoLib_VFX.SpawnParticle(EXPLOSION_POS, "gas_explosion_main", 8.0)
        MaoLib_VFX.SpawnParticle(EXPLOSION_POS, "gas_explosion_pump", 8.0)

        // Shake
        MaoLib_VFX.ScreenShake(EXPLOSION_POS, 4, 250, 2.0, 3000)

        // Slow-motion
        try { Director.SetTimescale(0.2) } catch(e) { }

        // Restore time after 1.5s
        MaoLib.AddTimer("heli_timerestore", 1.5, function() {
            try { Director.SetTimescale(1.0) } catch(e) { }
        })

        // Sounds
        MaoLib_VFX.EmitSoundAt(EXPLOSION_POS, "weapons/grenade_launcher/grenadefire/grenade_launcher_explode_2.wav")
        MaoLib_VFX.EmitSoundAt(EXPLOSION_POS, "player/heartbeatloop.wav")
        MaoLib_VFX.EmitSoundAt(EXPLOSION_POS, "ambient/nature/fire/fire_small1.wav")

        // Fade heart after 1.5s
        MaoLib.AddTimer("heli_heartfade", 1.5, function() {
            // Heartbeat naturally fades
        })

        // Spawn Tank
        _SpawnTank()

        // Box breaks via physics from explosion impulse

        // Nav blocker + physics blocker for crash zone
        _SpawnBlockers()

        Dbg("Heli explosion sequence complete")
    }

    function _SpawnTank() {
        local tankSpawn = SpawnEntityFromTable("info_zombie_spawn", {
            origin = TANK_POS
            angles = Vector(0, 90, 0)
            population = "river_docks_trap"
            offer_tank = 1
            AttackOnSpawn = 1
            targetname = "heli_tank_spawn_" + UniqueString()
        })
        if (tankSpawn) {
            DoEntFire("!self", "SpawnZombie", "", 0, null, tankSpawn)
            DoEntFire("!self", "Kill", "", 0.1, null, tankSpawn)
            try { Director.DisableTankFrustration() } catch(e) { }
            Dbg("Tank spawned at " + TANK_POS.ToString())
        } else {
            DbgWarn("Failed to spawn tank")
        }
    }

    function _SpawnBlockers() {
        // Nav blocker
        local navBlock = SpawnEntityFromTable("script_nav_blocker", {
            origin = NAV_BLOCK_POS
            extent = "431 10 96"
            teamToBlock = -1
            affectsFlow = 1
        })
        if (navBlock) {
            DoEntFire("!self", "BlockNav", "", 1, null, navBlock)
        }

        // Physics blocker
        local physBlock = SpawnEntityFromTable("env_physics_blocker", {
            origin = PHYS_BLOCK_POS
            mins = Vector(-5, -200, -128)
            maxs = Vector(5, 200, 128)
            initialstate = 1
            BlockType = 1
        })
    }

    function _CleanupHeli() {
        if (_heli && _heli.IsValid()) {
            _heli.Kill()
            Dbg("Heli killed")
        }
        HELI_ACTIVE = false
        HELI_DONE = true
        Dbg("Heli hotel event completed")
    }

    // ======================================================================
    // CLEANUP — called by maprefresh_main on round_end
    // ======================================================================
    function _Cleanup() {
        Dbg("_Cleanup — removing all timers + restoring timescale")
        MaoLib.RemoveTimer("heli_hotel_check")
        MaoLib.RemoveTimer("heli_war2")
        MaoLib.RemoveTimer("heli_talk1")
        MaoLib.RemoveTimer("heli_takeoff")
        MaoLib.RemoveTimer("heli_beep")
        MaoLib.RemoveTimer("heli_explosion")
        MaoLib.RemoveTimer("heli_panic")
        MaoLib.RemoveTimer("heli_talk2")
        MaoLib.RemoveTimer("heli_kill")
        MaoLib.RemoveTimer("heli_ambient_fade")
        MaoLib.RemoveTimer("heli_timerestore")
        MaoLib.RemoveTimer("heli_heartfade")
        // Restore normal timescale (safety: if round ended during slow-mo)
        Director.SetTimescale(1.0)
        // Kill helicopter entity if still alive
        _CleanupHeli()
    }
}

::MapRefresh_c2m1_Cleanup <- {
    function OnGameEvent_round_end(params) {
        ::MapRefresh.c2m1_highway._Cleanup()
    }
}
__CollectGameEventCallbacks(::MapRefresh_c2m1_Cleanup)

// Event registration handled by maprefresh_main.Init() → LoadMapScript()
