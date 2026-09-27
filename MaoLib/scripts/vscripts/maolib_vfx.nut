// ============================================================================
// MaoLib_VFX — Visual & Audio Effects System v2.2
// ============================================================================
// Particle spawning, explosions, impact effects, screenshake, screen effects,
// and audio utilities. Designed for L4D2's Source engine.
//
// FEATURES:
//   - Fresh spawn of info_particle_system (effect_name set at spawn — required!)
//   - Priority budget system: critical/gameplay/ambient with independent limits
//   - Reusable env_explosion entity for explosion effects
//   - Auto-precache, SafeKill, GetEffectPosition
//   - Screen effects: blood, adrenaline, bashed overlay particles
//
// USAGE:
//   MaoLib_VFX.SpawnParticle(pos, "effect_name", lifetime, priority)
//   MaoLib_VFX.SpawnParticleOnEntity(entity, "effect_name", "attachment", lifetime, priority)
//   MaoLib_VFX.SpawnExplosion(pos, "small"|"medium"|"large")
//   MaoLib_VFX.SpawnImpact(pos, normal, "blood"|"concrete"|"metal"|"wood"|"dirt")
//   MaoLib_VFX.ScreenShake(pos, amplitude, frequency, duration, radius)
//   MaoLib_VFX.ScreenEffect(player, "blood"|"adrenaline"|"bashed", duration)
//   MaoLib_VFX.GetEffectPosition(entity)    // Bone-safe position
//   MaoLib_VFX.SafeKill(entity, delay)
//
// DEPENDENCIES: ::MaoLib (for IsValidPosition, timers)
//
// ⚠️ CRITICAL: info_particle_system requires effect_name at spawn time.
// Setting it via __KeyValueFromString after spawn DOES NOT WORK.
// Always pass effect_name in the SpawnEntityFromTable keyvalues.
// ============================================================================

if ("MaoLib_VFX" in getroottable()) return;

::MaoLib_VFX <- {
    // ============================================================
    // CONFIGURATION
    // ============================================================
    DEFAULT_PARTICLE_LIFETIME = 3.0,
    
    // Budget per priority (particles per second)
    BUDGET = {
        critical = { max = 8,  decay = 0.5 },  // Explosions, gameplay-critical
        gameplay = { max = 12, decay = 0.3 },  // Blood, trails, debris
        ambient  = { max = 4,  decay = 0.2 }   // Smoke, ambient particles
    },
    
    // Internal state
    _particles_this_frame = 0,
    _last_frame_time      = 0,
    _spawn_counts    = { critical = 0, gameplay = 0, ambient = 0 },
    _last_budget_reset = 0,
    
    // Reusable explosion entity (env_explosion CAN be reused via input)
    _explosion_entity = null,
    _explosion_template = {
        classname = "env_explosion",
        targetname = "maolib_vfx_explosion",
        iRadiusOverride = 120,
        iMagnitude = 0,
        spawnflags = 6 | 256,
        rendermode = 5,
        ignoredClass = 1,
        origin = Vector(0, 0, 0)
    },
    
    _precached_sounds = {},
    
    // ============================================================
    // BUDGET / THROTTLE
    // ============================================================
    
    function CanSpawnParticle(priority = "gameplay") {
        local now = Time()
        
        if (now >= _last_budget_reset + 1.0) {
            _spawn_counts = { critical = 0, gameplay = 0, ambient = 0 }
            _last_budget_reset = now
        }
        
        // Frame throttle (preventive)
        if (now > _last_frame_time) {
            _particles_this_frame = 0
            _last_frame_time = now
        }
        if (_particles_this_frame >= 8) return false  // hard cap per frame
        
        local budget = BUDGET[priority]
        if (!budget) budget = BUDGET.gameplay
        
        return _spawn_counts[priority] < budget.max
    },
    
    function _TrackSpawn(priority) {
        _spawn_counts[priority]++
        _particles_this_frame++
    },
    
    // ============================================================
    // PARTICLE SPAWNING
    // ============================================================
    // Spawns a fresh info_particle_system with effect_name at spawn.
    // Critical: effect_name MUST be set in SpawnEntityFromTable keyvalues.
    
    function SpawnParticle(pos, effect, lifetime = 3.0, priority = "gameplay") {
        if (!CanSpawnParticle(priority)) return null
        if (!::MaoLib.IsValidPosition(pos)) { printl("[MaoLib_VFX] ERROR: invalid position"); return null }
        if (effect == null || effect == "") { printl("[MaoLib_VFX] ERROR: empty effect name"); return null }
        
        local particle = SpawnEntityFromTable("info_particle_system", {
            effect_name = effect,
            origin = pos
        })
        
        if (!particle || !particle.IsValid()) {
            printl("[MaoLib_VFX] ERROR: failed to spawn info_particle_system for '" + effect + "'")
            return null
        }
        
        DoEntFire("!self", "Start", "", 0.0, null, particle)
        _TrackSpawn(priority)
        
        if (lifetime > 0) SafeKill(particle, lifetime)
        
        return particle
    },
    
    function SpawnParticleOnEntity(entity, effect, attachment = "", lifetime = 3.0, priority = "gameplay") {
        if (!entity || !entity.IsValid()) { printl("[MaoLib_VFX] ERROR: invalid entity"); return null }
        if (!CanSpawnParticle(priority)) return null
        
        local pos = GetEffectPosition(entity)
        
        local particle = SpawnEntityFromTable("info_particle_system", {
            effect_name = effect,
            origin = pos
        })
        
        if (!particle || !particle.IsValid()) return null
        
        if (attachment != "") particle.SetParent(entity, attachment)
        else particle.SetParent(entity)
        
        DoEntFire("!self", "Start", "", 0.0, null, particle)
        _TrackSpawn(priority)
        
        if (lifetime > 0) SafeKill(particle, lifetime)
        
        return particle
    },
    
    // ============================================================
    // EXPLOSIONS
    // ============================================================
    
    function SpawnExplosion(pos, size = "medium") {
        if (!_explosion_entity || !_explosion_entity.IsValid()) {
            _explosion_entity = SpawnEntityFromTable("env_explosion", _explosion_template)
            if (!_explosion_entity || !_explosion_entity.IsValid()) {
                printl("[MaoLib_VFX] ERROR: Could not create env_explosion")
                return
            }
        }
        
        if (!::MaoLib.IsValidPosition(pos)) return
        
        _explosion_entity.SetOrigin(pos)
        DoEntFire("!self", "Explode", "", 0.0, null, _explosion_entity)
        
        switch(size) {
            case "small":
                SpawnParticle(pos, "weapon_pipebomb_child_explosion", 1.0, "critical")
                SpawnParticle(pos, "smoke_small_01", 2.0, "ambient")
                break
            case "medium":
                SpawnParticle(pos, "weapon_grenade_explosion", 1.5, "critical")
                SpawnParticle(pos, "smoke_medium_01", 3.0, "ambient")
                SpawnParticle(pos, "impact_spark_spray", 0.5, "gameplay")
                break
            case "large":
                SpawnParticle(pos, "explosion_huge_b", 2.5, "critical")
                SpawnParticle(pos, "smoke_large_01", 5.0, "ambient")
                SpawnParticle(pos, "impact_spark_spray_large", 1.0, "gameplay")
                break
            default:
                SpawnParticle(pos, "weapon_grenade_explosion", 1.5, "critical")
                break
        }
    },
    
    // ============================================================
    // IMPACTS (surface-aware effects)
    // ============================================================
    
    function SpawnImpact(pos, normal, type = "generic", scale = 1.0) {
        if (!::MaoLib.IsValidPosition(pos)) return
        
        local effect = null
        switch(type) {
            case "blood":    effect = "blood_impact_red_01"; break
            case "concrete": effect = "impact_concrete"; break
            case "metal":    effect = "impact_metal"; break
            case "wood":     effect = "impact_wood"; break
            case "dirt":     effect = "impact_dirt"; break
            case "water":    effect = "impact_water"; break
            default:         effect = "impact_generic_burst"; break
        }
        
        if (effect) SpawnParticle(pos, effect, 1.0, "gameplay")
        
        if (type == "metal" || type == "concrete")
            SpawnParticle(pos, "impact_spark_spray", 0.3, "gameplay")
    },
    
    // ============================================================
    // AUDIO
    // ============================================================
    // ⚠️ These are deprecated in favor of native functions:
    //   EmitSoundOn("sound", ent)       — attach to entity
    //   EmitAmbientSoundOn("sound", vol, pitch, ent)  — positional
    //   EmitSoundOnClient("sound", player)  — client-only
    //
    // Kept for backwards compatibility.
    
    function EmitSound(entity, sound, volume = 1.0, pitch = 100) {
        printl("[MaoLib_VFX] DEPRECATED EmitSound — use EmitSoundOn() or EmitAmbientSoundOn()")
        if (!entity || !entity.IsValid()) return
        if (pitch == 100 && volume == 1.0) { EmitSoundOn(sound, entity); return }
        local d = SpawnEntityFromTable("info_target", { origin = entity.GetOrigin() })
        if (d && d.IsValid()) { EmitAmbientSoundOn(sound, volume, 0, pitch, d); d.Kill() }
    },
    
    function EmitSoundAt(pos, sound, volume = 1.0, pitch = 100) {
        printl("[MaoLib_VFX] DEPRECATED EmitSoundAt — use EmitAmbientSoundOn() with info_target")
        local d = SpawnEntityFromTable("info_target", { origin = pos })
        if (d && d.IsValid()) { EmitAmbientSoundOn(sound, volume, 0, pitch, d); d.Kill() }
    },
    
    function EmitSoundOnClient(player, sound) {
        printl("[MaoLib_VFX] DEPRECATED EmitSoundOnClient — use native EmitSoundOnClient()")
        if (player && player.IsValid() && player.IsPlayer()) EmitSoundOnClient(sound, player)
    },
    
    // ============================================================
    // SCREEN EFFECTS
    // ============================================================
    
    function ScreenShake(pos, amplitude = 4, frequency = 10, duration = 1.0, radius = 0) {
        if (!::MaoLib.IsValidPosition(pos)) return
        
        local shaker = SpawnEntityFromTable("env_shake", {
            origin = pos,
            amplitude = amplitude,
            frequency = frequency,
            duration = duration,
            radius = radius
        })
        
        if (!shaker || !shaker.IsValid()) return
        
        DoEntFire("!self", "StartShake", "", 0.0, null, shaker)
        SafeKill(shaker, duration + 0.5)
    },
    
    function ScreenEffect(players, effect, duration = 1.0) {
        local targets = []
        
        if (players == null) {
            local player = null
            while (player = Entities.FindByClassname(player, "player")) {
                if (player.IsSurvivor() && player.IsValid())
                    targets.append(player)
            }
        } else if (typeof players == "array") {
            targets = players
        } else {
            targets = [players]
        }
        
        local particle_name = null
        switch(effect) {
            case "blood":       particle_name = "screen_blood_splatter"; break
            case "bashed":      particle_name = "screen_bashed"; break
            case "adrenaline":  particle_name = "screen_adrenaline"; break
            case "mud":         particle_name = "screen_mud_splatter"; break
            default:
                printl("[MaoLib_VFX] ERROR: unknown screen effect: " + effect)
                return
        }
        
        foreach (player in targets) {
            if (!player || !player.IsValid()) continue
            local pos = player.EyePosition()
            local particle = SpawnParticle(pos, particle_name, duration, "gameplay")
            if (particle && particle.IsValid()) particle.SetParent(player)
        }
    },
    
    // ============================================================
    // UTILITIES
    // ============================================================
    
    // Get a safe effect position for any entity
    // ⚠️ NEVER use LookupBone on "infected" class — it crashes the engine!
    // GetEffectPosition avoids this by using position offsets instead.
    function GetEffectPosition(entity) {
        if (!entity || !entity.IsValid()) return Vector(0, 0, 0)
        
        local classname = entity.GetClassname()
        if (classname == "infected") return entity.GetOrigin() + Vector(0, 0, 32)
        if (entity.IsPlayer()) return entity.EyePosition()
        return entity.GetOrigin()
    },
    
    // Safe kill with optional delay
    function SafeKill(entity, delay = 0.0) {
        if (!entity || !entity.IsValid()) return
        
        if (delay <= 0) {
            entity.Kill()
        } else {
            DoEntFire("!self", "Kill", "", delay, null, entity)
        }
    },
    
    // ============================================================
    // INIT / CLEANUP
    // ============================================================
    
    function Init(cleanup_interval = 0) {
        if (!_explosion_entity || !_explosion_entity.IsValid()) {
            _explosion_entity = SpawnEntityFromTable("env_explosion", _explosion_template)
            if (_explosion_entity && _explosion_entity.IsValid())
                printl("[MaoLib_VFX] env_explosion reusable created")
        }
        
        _precached_sounds = {}
        _spawn_counts = { critical = 0, gameplay = 0, ambient = 0 }
        _last_budget_reset = Time()
        _particles_this_frame = 0
        _last_frame_time = 0
        
        if (cleanup_interval > 0) {
            if (::MaoLib.IsTimerActive("maolib_vfx_cleanup")) ::MaoLib.RemoveTimer("maolib_vfx_cleanup")
            ::MaoLib.AddTimer("maolib_vfx_cleanup", cleanup_interval, function() {
                ::MaoLib_VFX._CleanupOrphans()
            })
        }
    },
    
    function _CleanupOrphans() {
        local ent = null
        while (ent = Entities.FindByClassname(ent, "info_target")) {
            if (ent && ent.IsValid()) {
                local name = ent.GetName()
                if (name.len() >= 15 && name.slice(0, 15) == "maolib_vfx_sd_")
                    ent.Kill()
            }
        }
        
        if (_explosion_entity && !_explosion_entity.IsValid())
            _explosion_entity = null
        
        _spawn_counts = { critical = 0, gameplay = 0, ambient = 0 }
        _particles_this_frame = 0
        _last_frame_time = 0
    },
}

printl("[MaoLib_VFX] v2.2 loaded — fresh spawn + budget system")
