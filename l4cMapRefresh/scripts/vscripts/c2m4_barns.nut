// ============================================================================
// l4cMapRefresh - Dark Carnival: Barns (c2m4_barns)
// ============================================================================
// Source: CyberZoio Stripper - Barn Tank Spawn
//         jeremyvillanuevar/vscripts_custom (props ref)
// 
// Events:
// - Barn Tank: Survivors enter barn area, get door-use prompt.
//   Hold position at door (10s) to open it and spawn Tank.
//   Back door requires 5s hold to continue.
// - Random Tank ambiance sounds play while approaching.
// ============================================================================

::MapRefresh.c2m4_barns <- {
    Debug = 1

    function Dbg(msg) { if (Debug) printl("[MapRefresh][c2m4] " + msg) }
    function DbgWarn(msg) { printl("[MapRefresh][WARN][c2m4] " + msg) }

    _initialized = false
    BARN_TRIGGERED = false
    TANK_SPAWNED = false
    BACKDOOR_OPEN = false

    // -------------------------------------------------------------------------
    // Configuration
    // -------------------------------------------------------------------------
    TRIGGER_POS = Vector(624, 1993, -127)
    TRIGGER_EXTENT = Vector(5, 64, 64)

    DOOR_BUTTON_POS = Vector(-2015, 276, -126)
    DOOR_HOLD_TIME = 10.0
    DOOR_POS = Vector(-2015, 266, -126)

    BACKDOOR_BUTTON_POS = Vector(-273, -32, -126)
    BACKDOOR_HOLD_TIME = 5.0
    BACKDOOR_POS = Vector(-259, -32, -136)

    TANK_SPAWN_POS = Vector(-2063, 249, -190)

    NAV_BLOCK_DOOR = Vector(-2015, 260, -128)
    NAV_BLOCK_BACKDOOR = Vector(-260, -31, -128)

    // Hold progress trackers
    _doorHoldStart = 0.0
    _backdoorHoldStart = 0.0
    _playerInDoorZone = null
    _playerInBackdoorZone = null

    // Sound timer handle
    _ambientTimerActive = false

    // -------------------------------------------------------------------------
    // Map Initialization
    // -------------------------------------------------------------------------
    function Init() {
        if (_initialized) return
        _initialized = true

        MaoLib.Mapper.SpawnReducedProps(::MapRefresh.c2m4_Props, 0.6,
            function(data, name) { return ::MapRefresh.Utils.SpawnProp(data, name) })

        InitBarnTank()

        Dbg("initialized")
    }

    // ========================================================================
    // EVENT: BARN TANK
    // ========================================================================

    function InitBarnTank() {
        // Nav blockers (block doors until triggered)
        _SpawnNavBlocker(NAV_BLOCK_DOOR, "5 64 64", "barn_nav_door")
        _SpawnNavBlocker(NAV_BLOCK_BACKDOOR, "5 32 64", "barn_nav_backdoor")

        // Start trigger check
        MaoLib.AddTimer("barn_trigger_check", 1.0, function() {
            ::MapRefresh.c2m4_barns._CheckBarnTrigger()
        })

        Dbg("Barn Tank initialized")
    }

    // -------------------------------------------------------------------------
    // Phase 1: Enter barn area
    // -------------------------------------------------------------------------
    function _CheckBarnTrigger() {
        if (BARN_TRIGGERED) return

        foreach (s in MaoLib.YieldSurvivors()) {
            if (!MaoLib.IsAlivePlayer(s)) continue

            local pos = s.GetOrigin()
            local dx = abs(pos.x - TRIGGER_POS.x)
            local dy = abs(pos.y - TRIGGER_POS.y)
            local dz = abs(pos.z - TRIGGER_POS.z)

            if (dx <= TRIGGER_EXTENT.x && dy <= TRIGGER_EXTENT.y && dz <= TRIGGER_EXTENT.z) {
                _OnBarnEntered()
                return
            }
        }
    }

    function _OnBarnEntered() {
        BARN_TRIGGERED = true
        Dbg("Barn area entered - Tank approach begins")

        MaoLib.RemoveTimer("barn_trigger_check")

        // Show hint: open the door
        // (VScript doesn't have native ShowHint, so we use a game_text approach)
        MaoLib.HUD.NotifyAll("OPEN THE BARN DOOR AND FIGHT THE TANK", {
            mode = "center"
            duration = 4.0
            priority = "high"
        })

        // Start ambient Tank sounds (random timer)
        _StartAmbientSounds()

        // Start door hold check timer
        MaoLib.AddTimer("barn_door_check", 0.5, function() {
            ::MapRefresh.c2m4_barns._CheckDoorHold()
        })
    }

    // -------------------------------------------------------------------------
    // Phase 2: Ambient Tank sounds (build tension)
    // -------------------------------------------------------------------------

    function _StartAmbientSounds() {
        _ambientTimerActive = true
        _ScheduleRandomSound()
    }

    function _ScheduleRandomSound() {
        if (!_ambientTimerActive) return

        local delay = RandomFloat(1.0, 5.0)
        MaoLib.AddTimer("barn_ambient_sound", delay, function() {
            if (!::MapRefresh.c2m4_barns._ambientTimerActive) return
            if (::MapRefresh.c2m4_barns.TANK_SPAWNED) return

            // Play random Tank sound
            local sounds = ::MapRefresh_c2m4_TankSounds
            local idx = RandomInt(0, sounds.len() - 1)
            MaoLib_VFX.EmitSoundAt(::MapRefresh.c2m4_barns.TANK_SPAWN_POS,
                sounds[idx])

            // Extra shake on certain sounds
            if (idx == 4 || idx == 8 || idx == 9) {  // Thud sounds
                MaoLib_VFX.ScreenShake(::MapRefresh.c2m4_barns.TANK_SPAWN_POS, 4, 100, 1.0, 2000)
            }

            // Schedule next
            ::MapRefresh.c2m4_barns._ScheduleRandomSound()
        })
    }

    // -------------------------------------------------------------------------
    // Phase 3: Hold position at door (10s timed button)
    // -------------------------------------------------------------------------
    function _CheckDoorHold() {
        if (TANK_SPAWNED) {
            MaoLib.RemoveTimer("barn_door_check")
            return
        }

        local playerInZone = null
        foreach (s in MaoLib.YieldSurvivors()) {
            if (!MaoLib.IsAlivePlayer(s)) continue

            local pos = s.GetOrigin()
            local dist = MaoLib.DistanceBetween(pos, DOOR_BUTTON_POS)
            if (dist < 100) {
                playerInZone = s
                break
            }
        }

        if (playerInZone) {
            if (_playerInDoorZone == null) {
                // Player just entered zone
                _playerInDoorZone = playerInZone
                _doorHoldStart = Time()
                MaoLib.HUD.Notify(playerInZone, "Hold position to open door...", {
                    mode = "hint"
                    priority = "high"
                })
                Dbg("Player entered door zone")
            } else {
                // Check hold duration
                local elapsed = Time() - _doorHoldStart
                if (elapsed >= DOOR_HOLD_TIME) {
                    _TriggerTank()
                    return
                }
                // Show progress
                if (elapsed.tointeger() % 2 == 0) {
                    local remaining = (DOOR_HOLD_TIME - elapsed).tointeger()
                    MaoLib.HUD.Notify(_playerInDoorZone, "Door opening... " + remaining + "s", {
                        mode = "hint"
                        throttle = 1.5
                        priority = "normal"
                    })
                }
            }
        } else {
            if (_playerInDoorZone != null) {
                _playerInDoorZone = null
                _doorHoldStart = 0.0
                MaoLib.HUD.NotifyAll("Door hold cancelled - moved away", {
                    mode = "hint"
                    priority = "normal"
                })
                Dbg("Player left door zone - hold cancelled")
            }
        }
    }

    // -------------------------------------------------------------------------
    // Phase 4: TANK SPAWN
    // -------------------------------------------------------------------------
    function _TriggerTank() {
        TANK_SPAWNED = true
        _ambientTimerActive = false
        Dbg("BARN TANK triggered!")

        MaoLib.RemoveTimer("barn_door_check")

        // Kill ambient sound timer
        MaoLib.RemoveTimer("barn_ambient_sound")

        // FX: slow-motion + shake
        try { Director.SetTimescale(0.2) } catch(e) { }
        MaoLib.AddTimer("barn_timerestore", 1.5, function() {
            try { Director.SetTimescale(1.0) } catch(e) { }
        })

        MaoLib_VFX.ScreenShake(TANK_SPAWN_POS, 4, 250, 2.0, 3000)

        // Sound: heart + explosion
        MaoLib_VFX.EmitSoundAt(TANK_SPAWN_POS, "player/heartbeatloop.wav")
        MaoLib_VFX.EmitSoundAt(TANK_SPAWN_POS,
            "weapons/grenade_launcher/grenadefire/grenade_launcher_explode_2.wav")

        // Spawn Tank
        local tankSpawn = SpawnEntityFromTable("info_zombie_spawn", {
            origin = TANK_SPAWN_POS
            angles = Vector(0, 90, 0)
            population = "river_docks_trap"
            offer_tank = 1
            AttackOnSpawn = 1
            targetname = "barn_tank_spawn_" + UniqueString()
        })
        if (tankSpawn) {
            DoEntFire("!self", "SpawnZombie", "", 0, null, tankSpawn)
            DoEntFire("!self", "Kill", "", 0.1, null, tankSpawn)
            try { Director.DisableTankFrustration() } catch(e) { }
            Dbg("Tank spawned at " + TANK_SPAWN_POS.ToString())
        }

        // Unblock main door nav
        _UnblockNav("barn_nav_door")

        // Show backdoor hint
        MaoLib.HUD.NotifyAll("UNLOCK THE BACK DOOR TO ESCAPE", {
            mode = "center"
            duration = 3.0
            priority = "high"
        })

        // Start backdoor check
        MaoLib.AddTimer("barn_backdoor_check", 0.5, function() {
            ::MapRefresh.c2m4_barns._CheckBackdoorHold()
        })

        // Panic event after 3s
        MaoLib.AddTimer("barn_panic", 3.0, function() {
            try { Director.ForcePanicEvent() } catch(e) { }
        })
    }

    // -------------------------------------------------------------------------
    // Phase 5: Back door (5s hold)
    // -------------------------------------------------------------------------
    function _CheckBackdoorHold() {
        if (BACKDOOR_OPEN) {
            MaoLib.RemoveTimer("barn_backdoor_check")
            return
        }

        local playerInZone = null
        foreach (s in MaoLib.YieldSurvivors()) {
            if (!MaoLib.IsAlivePlayer(s)) continue

            local pos = s.GetOrigin()
            local dist = MaoLib.DistanceBetween(pos, BACKDOOR_BUTTON_POS)
            if (dist < 100) {
                playerInZone = s
                break
            }
        }

        if (playerInZone) {
            if (_playerInBackdoorZone == null) {
                _playerInBackdoorZone = playerInZone
                _backdoorHoldStart = Time()
                MaoLib.HUD.Notify(playerInZone, "Hold to unlock back door...", {
                    mode = "hint"
                    priority = "high"
                })
                Dbg("Player entered backdoor zone")
            } else {
                local elapsed = Time() - _backdoorHoldStart
                if (elapsed >= BACKDOOR_HOLD_TIME) {
                    _OpenBackDoor()
                    return
                }
                if (elapsed.tointeger() % 2 == 0) {
                    local remaining = (BACKDOOR_HOLD_TIME - elapsed).tointeger()
                    MaoLib.HUD.Notify(_playerInBackdoorZone, "Unlocking... " + remaining + "s", {
                        mode = "hint"
                        throttle = 1.5
                        priority = "normal"
                    })
                }
            }
        } else {
            if (_playerInBackdoorZone != null) {
                _playerInBackdoorZone = null
                _backdoorHoldStart = 0.0
                MaoLib.HUD.NotifyAll("Back door unlock cancelled", {
                    mode = "hint"
                    priority = "normal"
                })
                Dbg("Player left backdoor zone")
            }
        }
    }

    function _OpenBackDoor() {
        BACKDOOR_OPEN = true
        Dbg("Back door opened")

        MaoLib.RemoveTimer("barn_backdoor_check")

        // Unblock back door nav
        _UnblockNav("barn_nav_backdoor")

        // Panic event
        try { Director.ForcePanicEvent() } catch(e) { }

        MaoLib.HUD.NotifyAll("Back door unlocked - MOVE!", {
            mode = "center"
            duration = 2.0
            priority = "high"
        })

        Dbg("Barn Tank event fully complete")
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------
    function _SpawnNavBlocker(origin, extent, prefix) {
        local block = SpawnEntityFromTable("script_nav_blocker", {
            origin = origin
            extent = extent
            teamToBlock = -1
            affectsFlow = 0
            targetname = prefix + "_" + UniqueString()
        })
        if (block) {
            DoEntFire("!self", "BlockNav", "", 1, null, block)
            Dbg("Nav blocker spawned at " + origin.ToString())
        }
    }

    function _UnblockNav(prefix) {
        local ent = null
        while (ent = Entities.FindByClassname(ent, "script_nav_blocker")) {
            local name = ent.GetName()
            if (name.find(prefix) == 0) {
                DoEntFire("!self", "UnblockNav", "", 0, null, ent)
                MaoLib_VFX.SafeKill(ent, 1)
                Dbg("Nav unblocked: " + name)
            }
        }
    }

    // ======================================================================
    // CLEANUP — called by maprefresh_main on round_end
    // ======================================================================
    function _Cleanup() {
        if (Debug) printl("[c2m4] _Cleanup — removing all timers + restoring timescale")
        MaoLib.RemoveTimer("barn_trigger_check")
        MaoLib.RemoveTimer("barn_door_check")
        MaoLib.RemoveTimer("barn_ambient_sound")
        MaoLib.RemoveTimer("barn_timerestore")
        MaoLib.RemoveTimer("barn_backdoor_check")
        MaoLib.RemoveTimer("barn_panic")
        // Restore normal timescale (safety: if round ended during slow-mo)
        Director.SetTimescale(1.0)
        // Stop ambient sound looping
        _ambientTimerActive = false
    }
}

// ============================================================================
// Module-level constants
// ============================================================================

::MapRefresh_c2m4_TankSounds <- [
    "HulkZombie.Breathe",
    "HulkZombie.Growl",
    "HulkZombie.StartLedgeClimb",
    "HulkZombie.Alert",
    "HulkZombie.Thud",
    "HulkZombie.Voice",
    "HulkZombie.Yell",
    "HulkZombie.Attack",
    "HulkZombie.Thud",
    "HulkZombie.Thud"
]

// Event registration handled by maprefresh_main.Init() → LoadMapScript()
