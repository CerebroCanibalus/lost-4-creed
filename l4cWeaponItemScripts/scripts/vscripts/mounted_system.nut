// ============================================================
// L4CWI — Mounted System v1.0
// Armas montadas (torretas y miniguns)
// Fusión de: mountedgunbulletsexplode, minigungib, minigun_shake
// ============================================================

::L4CWI_Mounted <- {
    CONFIG_PATH = "l4cwi_config/mounted.cfg"
    
    // === MOUNTED GUN BULLET EXPLODE ===
    MOUNTED_CLASSES = {
        prop_minigun = true,
        prop_mounted_machine_gun = true,
    }
    
    MGE_ENABLED = true
    MGE_DAMAGE = 200
    MGE_DAMAGE_HUMAN = 50
    MGE_RADIUS = 300
    MGE_FORCE = 1000
    MGE_STAGGER_HUMAN = 0
    MGE_STAGGER_SPECIAL = 0
    MGE_STAGGER_TANK = 0
    MGE_PARTICLES_FRONT = ["impact_upholstery_child_smoke", "impact_incendiary_generic", "impact_incendiary_fire"]
    MGE_PARTICLES_BACK = ["impact_upholstery_child_smoke", "impact_incendiary_generic", "impact_incendiary_fire"]
    
    explosion_ent = null
    player_using_mounted = {}
    
    // === MINIGUN GIB ===
    MINIGUN_GIB_ENABLED = true
    
    // === MINIGUN SHAKE ===
    SHAKE_ENABLED = true
    SHAKE_AMPLITUDE = 2
    SHAKE_FREQUENCY = 40
    SHAKE_DURATION = 0.3
    SHAKE_RADIUS = 100
    
    function Init() {
        this._Dbg("Initializing mounted system")
        
        local defaults = {
            mge_enabled = true,
            mge_damage = 200,
            mge_damage_human = 50,
            mge_radius = 300,
            mge_force = 1000,
            mge_stagger_human = 0,
            mge_stagger_special = 0,
            mge_stagger_tank = 0,
            minigun_gib_enabled = true,
            shake_enabled = true,
            shake_amplitude = 2,
            shake_frequency = 40,
            shake_duration = 0.3,
            shake_radius = 100,
        }
        
        local cfg = ::L4CWI_Core.ParseConfig(CONFIG_PATH, defaults)
        MGE_ENABLED = cfg.mge_enabled
        MGE_DAMAGE = cfg.mge_damage
        MGE_DAMAGE_HUMAN = cfg.mge_damage_human
        MGE_RADIUS = cfg.mge_radius
        MGE_FORCE = cfg.mge_force
        MGE_STAGGER_HUMAN = cfg.mge_stagger_human
        MGE_STAGGER_SPECIAL = cfg.mge_stagger_special
        MGE_STAGGER_TANK = cfg.mge_stagger_tank
        MINIGUN_GIB_ENABLED = cfg.minigun_gib_enabled
        SHAKE_ENABLED = cfg.shake_enabled
        SHAKE_AMPLITUDE = cfg.shake_amplitude
        SHAKE_FREQUENCY = cfg.shake_frequency
        SHAKE_DURATION = cfg.shake_duration
        SHAKE_RADIUS = cfg.shake_radius
        
        this._Dbg("Config loaded")
    }
    
    // ============================================================
    // MOUNTED GUN START
    // ============================================================
    function OnGameEvent_mounted_gun_start(params) {
        local player = GetPlayerFromUserID(params.userid)
        local mounted = EntIndexToHScript(params.subject)
        if (!mounted || !mounted.IsValid()) return
        
        local classname = mounted.GetClassname()
        if (classname in MOUNTED_CLASSES) {
            player_using_mounted[player] <- mounted
            this._Dbg("Player mounted: " + classname)
        }
    }
    
    // ============================================================
    // BULLET IMPACT — explosions + gib + shake
    // ============================================================
    function OnGameEvent_bullet_impact(params) {
        if (!("userid" in params)) return
        
        local player = GetPlayerFromUserID(params.userid)
        if (!player || !player.IsValid()) return
        
        // Check if using mounted weapon
        local usingMounted = NetProps.GetPropInt(player, "m_usingMountedWeapon")
        if (usingMounted != 1) return
        
        local hitPos = Vector(params.x, params.y, params.z)
        local mounted = (player in player_using_mounted) ? player_using_mounted[player] : null
        if (!mounted || !mounted.IsValid()) return
        if (!(mounted.GetClassname() in MOUNTED_CLASSES)) return
        
        // === MOUNTED GUN EXPLOSIONS ===
        if (MGE_ENABLED) {
            SpawnExplosion(hitPos, player, mounted)
        }
        
        // === SCREEN SHAKE ===
        if (SHAKE_ENABLED) {
            ::MaoLib_VFX.ScreenShake(hitPos, SHAKE_AMPLITUDE, SHAKE_FREQUENCY, SHAKE_DURATION, SHAKE_RADIUS)
        }
    }
    
    function SpawnExplosion(hitPos, player, mounted) {
        this._Dbg("ENTER SpawnExplosion at " + hitPos)
        
        // Reuse or create explosion entity
        if (explosion_ent == null || !explosion_ent.IsValid()) {
            explosion_ent = SpawnEntityFromTable("env_explosion", {
                targetname = "l4cwi_mge_explosion",
                iMagnitude = MGE_DAMAGE,
                iRadiusOverride = MGE_RADIUS,
                DamageForce = MGE_FORCE,
                spawnflags = 1604,
                iIgnoreClass = 1,
                origin = Vector(0, 0, -9999),
            })
        }
        
        explosion_ent.SetOrigin(hitPos)
        NetProps.SetPropEntity(explosion_ent, "m_hInflictor", player)
        NetProps.SetPropEntity(explosion_ent, "m_hOwnerEntity", player)
        
        DoEntFire("!self", "Explode", "", 0.01, null, explosion_ent)
        ::MaoLib_VFX.EmitSoundAt(hitPos, "weapons/hegrenade/explode5.wav")
        
        // --- Select targets using MaoLib.AoE (players + commons + witches) ---
        local allTargets = []
        
        local players = MaoLib.AoE.Select.Circle(hitPos, MGE_RADIUS, {
            className = "player",
            aliveOnly = true
        })
        foreach (p in players) allTargets.append(p)
        
        local commons = MaoLib.AoE.Select.Circle(hitPos, MGE_RADIUS, {
            className = "infected",
            aliveOnly = true
        })
        foreach (c in commons) allTargets.append(c)
        
        local witches = MaoLib.AoE.Select.Circle(hitPos, MGE_RADIUS, {
            className = "witch",
            aliveOnly = true
        })
        foreach (w in witches) allTargets.append(w)
        
        this._Dbg("Mountgun targets selected: " + allTargets.len() + " (P:" + players.len() + " C:" + commons.len() + " W:" + witches.len() + ")")
        
        // Apply damage with custom logic (falloff, stagger, friendly fire)
        local ffFactor = Convars.GetFloat("survivor_friendly_fire_factor_normal")
        local hitCount = 0
        
        foreach (ent in allTargets) {
            if (!ent || !ent.IsValid()) continue
            if (!::MaoLib.IsAlive(ent)) continue
            
            local dOrigin = (ent.GetOrigin() + ent.EyePosition()) * 0.5
            local dDistance = (dOrigin - hitPos).Length()
            local dDirection = dOrigin - hitPos
            dDirection.Norm()
            local dFactor = 1.0 - (dDistance / MGE_RADIUS)
            if (dFactor < 0) dFactor = 0
            
            try {
                if (ent.IsSurvivor()) {
                    // Friendly fire for survivors
                    ent.TakeDamageEx(explosion_ent, player, mounted, dDirection, dOrigin - dDirection * 10, dFactor * MGE_DAMAGE_HUMAN * ffFactor, 0)
                } else if (ent.GetClassname() == "infected") {
                    // Commons: full damage, no stagger
                    ent.TakeDamageEx(explosion_ent, player, mounted, dDirection, dOrigin - dDirection * 10, dFactor * MGE_DAMAGE, 0)
                } else if (ent.GetClassname() == "witch") {
                    // Witch: full damage, no stagger
                    ent.TakeDamageEx(explosion_ent, player, mounted, dDirection, dOrigin - dDirection * 10, dFactor * MGE_DAMAGE, 0)
                } else {
                    // Special Infected (player, not survivor): damage + possible stagger
                    local staggerChance = (ent.GetZombieType() == 8) ? MGE_STAGGER_TANK : MGE_STAGGER_SPECIAL
                    local dmgType = (RandomInt(1, 100) <= staggerChance) ? 64 : 0
                    ent.TakeDamageEx(explosion_ent, player, mounted, dDirection, dOrigin - dDirection * 10, dFactor * MGE_DAMAGE, dmgType)
                }
                hitCount++
            } catch (e) {
                this._DbgWarn("SpawnExplosion damage failed for " + ent.GetClassname() + ": " + e)
            }
        }
        
        this._Dbg("Mountgun explosion damaged " + hitCount + " entities")
        
        // Particles
        foreach (p in MGE_PARTICLES_FRONT) {
            ::MaoLib_VFX.SpawnParticle(hitPos, p, 1.0)
        }
        foreach (p in MGE_PARTICLES_BACK) {
            ::MaoLib_VFX.SpawnParticle(hitPos, p, 1.0)
        }
        
        this._Dbg("EXIT SpawnExplosion")
    }
    
    // ============================================================
    // MINIGUN GIB — infected_hurt
    // ============================================================
    function OnGameEvent_infected_hurt(params) {
        if (!MINIGUN_GIB_ENABLED) return
        if (!("entityid" in params) || !("attacker" in params) || !("type" in params)) return
        if (!params.entityid || !params.attacker) return
        
        local common = EntIndexToHScript(params.entityid)
        local surv = GetPlayerFromUserID(params.attacker)
        if (!common || !surv || !surv.IsValid() || !surv.IsSurvivor()) return
        
        // Check if using mounted weapon and correct damage type
        if (NetProps.GetPropInt(surv, "m_usingMountedWeapon") != 1) return
        local dmgType = params.type
        if (dmgType != -2147483646) return // mounted gun damage type
        
        local gender = NetProps.GetPropInt(common, "m_Gender")
        local badgenders = [14, 15, 17] // fallen, riot, jimmy
        if (badgenders.find(gender) != null) return
        
        if ((common.GetHealth() - params.amount) <= 0) {
            ApplyGib(common, gender)
        }
    }
    
    function ApplyGib(common, gender) {
        local wound = null
        if (gender == 11) { // ceda
            local gibs = [1, 2, 3, 4, 5, 6, 7, 8, 9]
            wound = gibs[RandomInt(0, gibs.len() - 1)]
        } else if (gender == 15) { // riot
            local gibs = [3, 4, 5]
            wound = gibs[RandomInt(0, gibs.len() - 1)]
        } else {
            local gibs = [22, 23, 24, 25]
            wound = gibs[RandomInt(0, gibs.len() - 1)]
        }
        
        if (wound != null) {
            if (NetProps.GetPropInt(common, "m_iRequestedWound1") == -1) {
                NetProps.SetPropInt(common, "m_iRequestedWound1", wound)
            } else if (NetProps.GetPropInt(common, "m_iRequestedWound2") == -1 && NetProps.GetPropInt(common, "m_iRequestedWound1") != wound) {
                NetProps.SetPropInt(common, "m_iRequestedWound2", wound)
            }
        }
    }
    
    function OnRoundEnd(params) {
        if (explosion_ent && explosion_ent.IsValid()) {
            explosion_ent.Kill()
            explosion_ent = null
        }
        player_using_mounted = {}
    }
}

__CollectGameEventCallbacks(::L4CWI_Mounted)
::L4CWI_Core.RegisterSystem("Mounted", ::L4CWI_Mounted)
printl("[L4CWI] Mounted System loaded")
