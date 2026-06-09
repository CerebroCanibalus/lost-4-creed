// ============================================================
// L4CWI — Explosives System v1.0
// Explosivos, área de efecto y heavy weapons
// Fusión de: nescius_pipe_damage_de, bile_slow, gl_screenshake
// (atomic_pipe se migrará en v2 — es más complejo)
// ============================================================

::L4CWI_Explosives <- {
    CONFIG_PATH = "l4cwi_config/explosives.cfg"

    // 🛡️ CRITICAL: Damage recursion guard. Pipe nuke applies TakeDamage() inside
    // OnGameEvent_player_hurt. While the weapon/type filters normally prevent loops,
    // a guard prevents cross-script cascades if another system generates matching damage.
    _processingPipeDamage = false
    
    // === PIPE BOMB CONVARS (Atomic) ===
    PIPE_SHAKE_AMPLITUDE = 100
    PIPE_SHAKE_RADIUS = 2000
    PIPE_TIMER_DURATION = 2
    PIPE_BEEP_DELTA = 0.015
    PIPE_BEEP_MIN = 0.08
    PIPE_BEEP_INITIAL = 0.35
    
    // === ATOMIC PIPE BOMB ===
    ATOMIC_PIPE_ENABLED = true
    ATOMIC_PIPE_DAMAGE = 350
    ATOMIC_PIPE_RADIUS = 500
    ATOMIC_PIPE_DAMAGE_SURVIVORS = true
    ATOMIC_PIPE_TIMED = false // false = explode on bounce, true = timer-based
    
    // === NESCIUS PIPE DAMAGE (legacy extra damage) ===
    PIPE_NUKE_ENABLED = true
    PIPE_NUKE_DAMAGE_MIN = 10
    PIPE_NUKE_DAMAGE_MULT = 50
    PIPE_NUKE_FLAT_DAMAGE = 1500
    
    // === BILE SLOW ===
    BILE_SLOW_ENABLED = true
    BILE_SLOW_AMOUNT = 0.75
    BILE_SLOW_MODE = 1 // 0=force walk button, 1=SetFriction
    
    // === GL SCREENSHAKE ===
    GL_SHAKE_ENABLED = true
    GL_SHAKE_AMPLITUDE = 10
    GL_SHAKE_FREQUENCY = 40
    GL_SHAKE_DURATION = 1.2
    GL_SHAKE_RADIUS = 1250
    
    // === GL LAUNCHER CONVARS ===
    GL_VELOCITY = 900
    GL_RADIUS_KILL = 140
    GL_RADIUS_STUMBLE = 200
    GL_DAMAGE = 1500
    GL_FF_SCALE = 0.06
    GL_FF_SCALE_SELF = 0.18
    
    // === AOE INCENDIARY ===
    AOE_INCENDIARY_ENABLED = true
    AOE_INCENDIARY_CHANCE = 0
    
    // GL projectile tracking
    GL_PROJECTILES = {}
    
    function Init() {
        this._Dbg("Initializing explosives system")
        
        local defaults = {
            atomic_pipe_enabled = true,
            atomic_pipe_damage = 350,
            atomic_pipe_radius = 500,
            atomic_pipe_damage_survivors = true,
            atomic_pipe_timed = false,
            pipe_nuke_enabled = true,
            pipe_nuke_flat_damage = 1500,
            bile_slow_enabled = true,
            bile_slow_amount = 0.75,
            bile_slow_mode = 1,
            gl_shake_enabled = true,
            gl_shake_amplitude = 10,
            gl_shake_frequency = 40,
            gl_shake_duration = 1.2,
            gl_shake_radius = 1250,
            gl_velocity = 900,
            gl_radius_kill = 140,
            gl_radius_stumble = 200,
            gl_damage = 1500,
            gl_ff_scale = 0.06,
            gl_ff_scale_self = 0.18,
            aoe_incendiary_enabled = true,
            aoe_incendiary_chance = 0,
        }
        
        local cfg = ::L4CWI_Core.ParseConfig(CONFIG_PATH, defaults)
        ATOMIC_PIPE_ENABLED = cfg.atomic_pipe_enabled
        ATOMIC_PIPE_DAMAGE = cfg.atomic_pipe_damage
        ATOMIC_PIPE_RADIUS = cfg.atomic_pipe_radius
        ATOMIC_PIPE_DAMAGE_SURVIVORS = cfg.atomic_pipe_damage_survivors
        ATOMIC_PIPE_TIMED = cfg.atomic_pipe_timed
        PIPE_NUKE_ENABLED = cfg.pipe_nuke_enabled
        PIPE_NUKE_FLAT_DAMAGE = cfg.pipe_nuke_flat_damage
        BILE_SLOW_ENABLED = cfg.bile_slow_enabled
        BILE_SLOW_AMOUNT = cfg.bile_slow_amount
        BILE_SLOW_MODE = cfg.bile_slow_mode
        GL_SHAKE_ENABLED = cfg.gl_shake_enabled
        GL_SHAKE_AMPLITUDE = cfg.gl_shake_amplitude
        GL_SHAKE_FREQUENCY = cfg.gl_shake_frequency
        GL_SHAKE_DURATION = cfg.gl_shake_duration
        GL_SHAKE_RADIUS = cfg.gl_shake_radius
        GL_VELOCITY = cfg.gl_velocity
        GL_RADIUS_KILL = cfg.gl_radius_kill
        GL_RADIUS_STUMBLE = cfg.gl_radius_stumble
        GL_DAMAGE = cfg.gl_damage
        GL_FF_SCALE = cfg.gl_ff_scale
        GL_FF_SCALE_SELF = cfg.gl_ff_scale_self
        AOE_INCENDIARY_ENABLED = cfg.aoe_incendiary_enabled
        AOE_INCENDIARY_CHANCE = cfg.aoe_incendiary_chance
        
        // Apply pipe bomb convars
        Convars.SetValue("pipe_bomb_shake_amplitude", PIPE_SHAKE_AMPLITUDE)
        Convars.SetValue("pipe_bomb_shake_radius", PIPE_SHAKE_RADIUS)
        Convars.SetValue("pipe_bomb_timer_duration", PIPE_TIMER_DURATION)
        Convars.SetValue("pipe_bomb_beep_interval_delta", PIPE_BEEP_DELTA)
        Convars.SetValue("pipe_bomb_beep_min_interval", PIPE_BEEP_MIN)
        Convars.SetValue("pipe_bomb_initial_beep_interval", PIPE_BEEP_INITIAL)
        
        // Apply GL convars
        Convars.SetValue("grenadelauncher_velocity", GL_VELOCITY)
        Convars.SetValue("grenadelauncher_radius_kill", GL_RADIUS_KILL)
        Convars.SetValue("grenadelauncher_radius_stumble", GL_RADIUS_STUMBLE)
        Convars.SetValue("grenadelauncher_damage", GL_DAMAGE)
        Convars.SetValue("grenadelauncher_ff_scale", GL_FF_SCALE)
        Convars.SetValue("grenadelauncher_ff_scale_self", GL_FF_SCALE_SELF)
        
        this._Dbg("Config loaded — Atomic pipe: " + ATOMIC_PIPE_ENABLED + 
                  ", Pipe nuke: " + PIPE_NUKE_ENABLED + 
                  ", Bile slow: " + BILE_SLOW_ENABLED +
                  ", AoE incendiary: " + AOE_INCENDIARY_ENABLED)
    }
    
    // ============================================================
    // NESCIUS PIPE DAMAGE — Daño masivo a especiales con pipes
    // ============================================================
    function OnGameEvent_player_hurt(params) {
        // 🛡️ CRITICAL: prevent recursive damage loops from pipe nuke bonus damage
        if (this._processingPipeDamage) return
        if (!PIPE_NUKE_ENABLED) return
        if (!("weapon" in params) || params.weapon != "pipe_bomb") return
        if (!("type" in params) || !(params.type & 134217792)) return
        
        local victim = GetPlayerFromUserID(params.userid)
        if (!victim || victim.IsSurvivor()) return
        
        local attacker = null
        if ("attacker" in params) attacker = GetPlayerFromUserID(params.attacker)
        local dmg = params.dmg_health >= PIPE_NUKE_DAMAGE_MIN 
            ? PIPE_NUKE_FLAT_DAMAGE 
            : params.dmg_health * PIPE_NUKE_DAMAGE_MULT
        
        this._processingPipeDamage = true
        
        if (attacker && attacker.IsValid()) {
            attacker.ValidateScriptScope()
            DoEntFire("!self", "RunScriptCode", 
                format("activator.TakeDamage(%d,0,self)", dmg), 
                0, victim, attacker)
        } else {
            // 🛡️ FIX: usar null como attacker (no self-reference)
            victim.TakeDamage(dmg, 0, null)
        }
        
        this._processingPipeDamage = false
        this._Dbg("Pipe nuke damage: " + dmg + " to " + victim.GetEntityIndex())
    }
    
    // ============================================================
    // BILE SLOW — Ralentiza especiales cubiertos de bile
    // ============================================================
    function OnGameEvent_player_now_it(params) {
        if (!BILE_SLOW_ENABLED) return
        if (!("userid" in params)) return
        
        local player = GetPlayerFromUserID(params.userid)
        if (!player || player.IsSurvivor()) return
        
        if (BILE_SLOW_MODE == 0) {
            NetProps.SetPropInt(player, "m_afButtonForced", 
                NetProps.GetPropInt(player, "m_afButtonForced") | 131072)
        } else {
            player.SetFriction(1 / BILE_SLOW_AMOUNT)
        }
        
        this._Dbg("Bile slow applied to " + player.GetEntityIndex())
    }
    
    function OnGameEvent_player_no_longer_it(params) {
        if (!BILE_SLOW_ENABLED) return
        if (!("userid" in params)) return
        
        local player = GetPlayerFromUserID(params.userid)
        if (!player || player.IsSurvivor()) return
        
        if (BILE_SLOW_MODE == 0) {
            NetProps.SetPropInt(player, "m_afButtonForced", 
                NetProps.GetPropInt(player, "m_afButtonForced") & ~131072)
        } else {
            player.SetFriction(1)
        }
    }
    
    // ============================================================
    // GL SCREENSHAKE — Seguimiento de proyectiles de GL
    // ============================================================
    function OnGameEvent_weapon_fire(params) {
        if (!("userid" in params)) return
        local userid = params.userid
        local player = GetPlayerFromUserID(userid)
        if (!player || !player.IsSurvivor()) return
        
        // === GL Tracking ===
        if (GL_SHAKE_ENABLED && "weaponid" in params && params.weaponid == 21) {
            local nade = null
            while (nade = Entities.FindByClassname(nade, "grenade_launcher_projectile")) {
                local thrower = NetProps.GetPropEntity(nade, "m_hThrower")
                if (nade && thrower == player) {
                    GL_PROJECTILES[userid] <- { ent = nade, pos = null }
                    this._Dbg("GL projectile tracked for userid " + userid)
                    break
                }
            }
        }
        
        // === Atomic Pipe Bomb (timed mode) ===
        if (ATOMIC_PIPE_ENABLED && ATOMIC_PIPE_TIMED) {
            local weapon = ::L4CWI_Core.GetActiveWeaponClass(player)
            if (weapon == "weapon_pipe_bomb") {
                local timer = Convars.GetFloat("pipe_bomb_timer_duration") - 0.5
                if (timer > 0) {
                    MaoLib.DelayCall(function() {
                        ::L4CWI_Explosives.ExplodePlayerPipe(userid)
                    }, timer)
                }
            }
        }
    }
    
    function OnGameEvent_grenade_bounce(params) {
        if (!("userid" in params)) return
        local userid = params.userid
        
        // === Atomic Pipe Bomb (instant mode) ===
        if (ATOMIC_PIPE_ENABLED && !ATOMIC_PIPE_TIMED) {
            local player = GetPlayerFromUserID(userid)
            if (player && player.IsSurvivor()) {
                local pipe = null
                while (pipe = Entities.FindByClassname(pipe, "pipe_bomb_projectile")) {
                    if (NetProps.GetPropEntity(pipe, "m_hThrower") == player) {
                        DoAtomicExplosion(pipe.GetOrigin(), player)
                        pipe.Kill()
                        this._Dbg("Atomic pipe exploded on bounce")
                        break
                    }
                }
            }
        }
        
        // === GL Screenshake ===
        if (!GL_SHAKE_ENABLED) return
        
        local userid = params.userid
        if (!(userid in GL_PROJECTILES)) return
        
        local nade = GL_PROJECTILES[userid].ent
        if (!nade || !nade.IsValid()) {
            delete GL_PROJECTILES[userid]
            return
        }
        
        GL_PROJECTILES[userid].pos <- nade.GetOrigin()
        
        // Delayed shake for better feel — DelayCall one-shot, auto-remove
        MaoLib.DelayCall(function() {
            ::L4CWI_Explosives.DoGLShake(userid)
        }, 0.1)
    }
    
    function DoGLShake(userid) {
        if (!(userid in GL_PROJECTILES)) return
        
        local data = GL_PROJECTILES[userid]
        if (!data.pos) {
            delete GL_PROJECTILES[userid]
            return
        }
        
        local shakePos = Vector(data.pos.x, data.pos.y, data.pos.z + 4)
        ScreenShake(shakePos, GL_SHAKE_AMPLITUDE, GL_SHAKE_FREQUENCY, 
            GL_SHAKE_DURATION, GL_SHAKE_RADIUS, 0, true)
        
        delete GL_PROJECTILES[userid]
        this._Dbg("GL screenshake at " + shakePos)
    }
    
    function OnGameEvent_player_bot_replace(params) {
        if ("player" in params && params.player in GL_PROJECTILES)
            delete GL_PROJECTILES[params.player]
    }
    
    function OnGameEvent_bot_player_replace(params) {
        if ("bot" in params && params.bot in GL_PROJECTILES)
            delete GL_PROJECTILES[params.bot]
    }
    
    function OnGameEvent_player_disconnect(params) {
        if ("userid" in params && params.userid in GL_PROJECTILES)
            delete GL_PROJECTILES[params.userid]
    }
    
    function OnRoundEnd(params) {
        GL_PROJECTILES = {}
    }
    
    // ============================================================
    // ATOMIC PIPE BOMB — Explosion nuclear
    // ============================================================
    function ExplodePlayerPipe(userid) {
        local player = GetPlayerFromUserID(userid)
        if (!player || !player.IsValid()) return
        
        local pipe = null
        while (pipe = Entities.FindByClassname(pipe, "pipe_bomb_projectile")) {
            if (NetProps.GetPropEntity(pipe, "m_hThrower") == player) {
                DoAtomicExplosion(pipe.GetOrigin(), player)
                pipe.Kill()
                this._Dbg("Atomic pipe exploded (timed)")
                break
            }
        }
    }
    
    function DoAtomicExplosion(pos, thrower) {
        // Visual FX via MaoLib_VFX
        MaoLib_VFX.SpawnExplosion(pos, "large")
        MaoLib_VFX.SpawnParticle(pos, "gas_explosion_main_fallback", 2.0)
        MaoLib_VFX.ScreenShake(pos, 8, 25, 1.0, ATOMIC_PIPE_RADIUS * 2)
        MaoLib_VFX.EmitSoundAt(pos, "weapons/hegrenade/explode5.wav")
        
        // env_explosion for physics
        local envExp = SpawnEntityFromTable("env_explosion", {
            iRadiusOverride = ATOMIC_PIPE_RADIUS,
            iMagnitude = ATOMIC_PIPE_DAMAGE,
            spawnflags = 6 | 256,
            iIgnoreClass = 1,
            origin = pos
        })
        NetProps.SetPropEntity(envExp, "m_hOwnerEntity", thrower)
        DoEntFire("!self", "Explode", "", 0, null, envExp)
        DoEntFire("!self", "Kill", "", 0.75, null, envExp)
        
        // Damage all entities in radius
        local ent = null
        while (ent = Entities.FindByClassname(ent, "player")) {
            if (NetProps.GetPropInt(ent, "m_lifeState") != 0) continue
            
            local dist = (pos - ent.GetOrigin()).Length()
            if (dist > ATOMIC_PIPE_RADIUS) continue
            
            local inRadius = ATOMIC_PIPE_RADIUS - dist
            local radiusDmg = ATOMIC_PIPE_DAMAGE * (inRadius / ATOMIC_PIPE_RADIUS)
            
            if (ent.IsSurvivor()) {
                // Survivor: stagger + scaled FF damage
                ent.Stagger(pos)
                if (ATOMIC_PIPE_DAMAGE_SURVIVORS) {
                    local diff = Convars.GetStr("z_difficulty").tolower()
                    local mult = 0.1
                    if (diff == "hard") mult = 0.25
                    else if (diff == "impossible") mult = 0.5
                    ent.TakeDamage(radiusDmg * mult, 6, thrower)
                }
            } else {
                // Special infected: massive knockback + full damage
                local dir = pos - ent.GetOrigin()
                local distFactor = 1 + dir.Length() / 500
                dir.Norm()
                
                ent.SetOrigin(ent.GetOrigin() + Vector(0, 0, 1))
                ent.SetVelocity((ent.GetVelocity() + Vector(0, 0, 666)) + (dir * -966 * distFactor))
                ent.TakeDamage(radiusDmg, 6, thrower)
            }
        }
        
        // Damage commons and witches
        ent = null
        while (ent = Entities.FindByClassnameWithin(ent, "infected", pos, ATOMIC_PIPE_RADIUS)) {
            if (NetProps.GetPropInt(ent, "m_lifeState") == 0)
                ent.TakeDamage(ATOMIC_PIPE_DAMAGE, 6, thrower)
        }
        ent = null
        while (ent = Entities.FindByClassnameWithin(ent, "witch", pos, ATOMIC_PIPE_RADIUS)) {
            if (NetProps.GetPropInt(ent, "m_lifeState") == 0)
                ent.TakeDamage(ATOMIC_PIPE_DAMAGE * 0.5, 6, thrower)
        }
        
        this._Dbg("Atomic explosion at " + pos + " | radius=" + ATOMIC_PIPE_RADIUS + " | dmg=" + ATOMIC_PIPE_DAMAGE)
    }
    
    // ============================================================
    // AOE INCENDIARY — Fire on ground with incendiary ammo
    // ============================================================
    function OnGameEvent_bullet_impact(params) {
        if (!AOE_INCENDIARY_ENABLED) return
        if (!("userid" in params)) return
        
        local player = GetPlayerFromUserID(params.userid)
        if (!player || !player.IsValid() || !player.IsSurvivor()) return
        
        local weapon = player.GetActiveWeapon()
        if (!weapon || !weapon.IsValid()) return
        
        local upgradeVec = NetProps.GetPropInt(weapon, "m_upgradeBitVec")
        // 1 = incendiary, 5 = incendiary + explosive
        if (upgradeVec != 1 && upgradeVec != 5) return
        
        local origin = Vector(params.x, params.y, params.z)
        local origin2 = origin + Vector(0, 0, 25)
        
        // Damage nearby infected
        local ent = null
        while (ent = Entities.FindByClassnameWithin(ent, "infected", origin, 40)) {
            ent.TakeDamage(5, 8, player)
        }
        ent = null
        while (ent = Entities.FindByClassnameWithin(ent, "player", origin, 40)) {
            if (!ent.IsSurvivor()) {
                ent.TakeDamage(5, 8, player)
            }
        }
        ent = null
        while (ent = Entities.FindByClassnameWithin(ent, "witch", origin, 40)) {
            ent.TakeDamage(5, 8, player)
        }
        
        // Chance to drop fire
        if (AOE_INCENDIARY_CHANCE > 0 && RandomInt(1, 100) <= AOE_INCENDIARY_CHANCE) {
            local fire = SpawnEntityFromTable("env_inferno", {
                origin = origin2,
                damage = 5,
                firesize = 64,
                fireattack = 1,
                fireduration = 8,
                spawnflags = 0,
            })
            if (fire && fire.IsValid()) {
                DoEntFire("!self", "StartFire", "", 0, null, fire)
            }
        }
    }
}

__CollectGameEventCallbacks(::L4CWI_Explosives)
::L4CWI_Core.RegisterSystem("Explosives", ::L4CWI_Explosives)
printl("[L4CWI] Explosives System loaded")
