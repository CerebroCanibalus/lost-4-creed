// ============================================================
// L4CWI — Special Firearms System v1.0
// Efectos especiales para armas de fuego
// Fusión de: awp_explosive, automatic_stuff, rip_and_tear, shotgungib
// ============================================================

::L4CWI_SpecialFirearms <- {
    CONFIG_PATH = "l4cwi_config/special_firearms.cfg"
    
    // === AWP EXPLOSIVE ===
    AWP_ENABLED = true
    AWP_RADIUS = 140
    AWP_DAMAGE_SPECIAL = 75
    AWP_DAMAGE_COMMON = 250
    AWP_DMGBLAST = 64 | 512 // DMG_BLAST | DMG_ALWAYSGIB
    AWP_PENDING = {}
    
    // === AUTOMATIC STUFF ===
    AUTO_PISTOL = true
    AUTO_SNIPER = true
    
    // === RIP AND TEAR ===
    RIP_ENABLED = true
    RIFLE_CLASSES = {
        weapon_rifle_ak47 = true,
        weapon_rifle_sg552 = true,
        weapon_rifle = true,
        weapon_rifle_desert = true,
    }
    DeadInfected = {}
    HitCount = {}
    
    // === SHOTGUN GIB ===
    SG_GIB_ENABLED = true
    
    // === CHROME SHOTGUN KNOCKBACK ===
    CHROME_KNOCKBACK_ENABLED = true
    CHROME_KNOCKBACK_FORCE = 250
    CHROME_SHAKE_AMPLITUDE = 5
    CHROME_SHAKE_FREQUENCY = 40
    CHROME_SHAKE_DURATION = 0.25
    
    function Init() {
        this._Dbg("Initializing special firearms system")
        
        local defaults = {
            awp_enabled = true,
            awp_radius = 140,
            awp_damage_special = 75,
            awp_damage_common = 250,
            auto_pistol = true,
            auto_sniper = true,
            rip_enabled = true,
            sg_gib_enabled = true,
            chrome_knockback_enabled = true,
            chrome_knockback_force = 250,
            chrome_shake_amplitude = 5,
            chrome_shake_frequency = 40,
            chrome_shake_duration = 0.25,
        }
        
        local cfg = ::L4CWI_Core.ParseConfig(CONFIG_PATH, defaults)
        AWP_ENABLED = cfg.awp_enabled
        AWP_RADIUS = cfg.awp_radius
        AWP_DAMAGE_SPECIAL = cfg.awp_damage_special
        AWP_DAMAGE_COMMON = cfg.awp_damage_common
        AUTO_PISTOL = cfg.auto_pistol
        AUTO_SNIPER = cfg.auto_sniper
        RIP_ENABLED = cfg.rip_enabled
        SG_GIB_ENABLED = cfg.sg_gib_enabled
        CHROME_KNOCKBACK_ENABLED = cfg.chrome_knockback_enabled
        CHROME_KNOCKBACK_FORCE = cfg.chrome_knockback_force
        CHROME_SHAKE_AMPLITUDE = cfg.chrome_shake_amplitude
        CHROME_SHAKE_FREQUENCY = cfg.chrome_shake_frequency
        CHROME_SHAKE_DURATION = cfg.chrome_shake_duration
        
        this._Dbg("Config loaded")
        
        // Start rip and tear check loop
        if (RIP_ENABLED) {
            ScheduleRipCheck()
        }
    }
    
    // ============================================================
    // AWP EXPLOSIVE + AUTOMATIC STUFF — weapon_fire merged
    // ============================================================
    // AWP: explota SIEMPRE al disparar, incluso al aire.
    //      TraceLine desde el ojo estima el punto de impacto.
    // Auto: pistola / sniper_military en modo automático.
    // ============================================================
    function OnGameEvent_weapon_fire(params) {
        if (!("weapon" in params) || !("userid" in params)) return
        
        local weaponName = params.weapon
        local player = GetPlayerFromUserID(params.userid)
        if (!player || !player.IsValid() || !player.IsSurvivor()) return
        
        // --- AWP EXPLOSIVE ---
        // weapon_fire puede reportar nombre corto ("sniper_awp") o completo
        // ("weapon_sniper_awp") según el arma — aceptamos ambos
        if (AWP_ENABLED && (weaponName == "sniper_awp" || weaponName == "weapon_sniper_awp")) {
            local eyePos = player.EyePosition()
            local eyeAngles = player.EyeAngles()
            local trace = {
                start = eyePos,
                end = eyePos + VectorFromQAngle(eyeAngles, 10000.0),
                ignore = player,
            }
            TraceLine(trace)
            
            local hitPos = trace.pos
            this._Dbg("AWP fire — trace hit: " + trace.hit + " pos: " + hitPos)
            
            // VFX
            ::MaoLib_VFX.ScreenShake(hitPos, 6, 20, 0.4, 500)
            ::MaoLib_VFX.SpawnExplosion(hitPos, "medium")
            ::MaoLib_VFX.SpawnParticle(hitPos, "impact_spark_spray", 0.5)
            ::MaoLib_VFX.SpawnParticle(hitPos, "impact_ricochet_sparks", 0.4)
            ::MaoLib_VFX.EmitSoundAt(hitPos, "weapons/hegrenade/explode5.wav")
            
            local count = 0
            
            // Commons
            local commons = MaoLib.AoE.Select.Circle(hitPos, AWP_RADIUS, {
                className = "infected",
                aliveOnly = true
            })
            if (commons.len() > 0) {
                local hits = MaoLib.AoE.Apply.Damage(commons, AWP_DAMAGE_COMMON, player, AWP_DMGBLAST, {
                    onHit = function(ent, dmg) {
                        ::MaoLib_VFX.SpawnParticle(ent.GetOrigin(), "blood_impact_red_01_chunk_shotgun", 0.8)
                    }
                })
                count += hits
                this._Dbg("AWP commons hit: " + hits)
            }
            
            // Witches
            local witches = MaoLib.AoE.Select.Circle(hitPos, AWP_RADIUS, {
                className = "witch",
                aliveOnly = true
            })
            if (witches.len() > 0) {
                local hits = MaoLib.AoE.Apply.Damage(witches, AWP_DAMAGE_SPECIAL, player, 64)
                count += hits
                this._Dbg("AWP witches hit: " + hits)
            }
            
            // Special Infected (players, not survivors)
            local specials = MaoLib.AoE.Select.Circle(hitPos, AWP_RADIUS, {
                className = "player",
                filter = function(ent) { return !ent.IsSurvivor() },
                aliveOnly = true
            })
            if (specials.len() > 0) {
                local hits = MaoLib.AoE.Apply.Damage(specials, AWP_DAMAGE_SPECIAL, player, 64)
                count += hits
                this._Dbg("AWP specials hit: " + hits)
            }
            
            this._Dbg("AWP total affected: " + count)
        }
        
        // --- CHROME SHOTGUN KNOCKBACK ---
        // La chrome shotgun empuja al jugador hacia atrás al disparar
        // + screen shake (nativo, no MaoLib_VFX wrapper — env_shake no funciona sin DispatchSpawn)
        if (CHROME_KNOCKBACK_ENABLED && (weaponName == "shotgun_chrome" || weaponName == "weapon_shotgun_chrome")) {
            local playerPos = player.EyePosition()
            
            // Screen shake nativo — (pos, amp, freq, dur, radius, cmd=0, air)
            ScreenShake(playerPos, CHROME_SHAKE_AMPLITUDE, CHROME_SHAKE_FREQUENCY,
                CHROME_SHAKE_DURATION, 100, 0, true)
            
            // Knockback: dirección contraria a donde apunta (incluye componente vertical)
            local forward = VectorFromQAngle(player.EyeAngles(), 1.0)
            local backward = Vector(
                -forward.x * CHROME_KNOCKBACK_FORCE,
                -forward.y * CHROME_KNOCKBACK_FORCE,
                -forward.z * CHROME_KNOCKBACK_FORCE
            )
            
            try {
                player.ApplyAbsVelocityImpulse(backward)
                this._Dbg("Chrome knockback applied — force: " + CHROME_KNOCKBACK_FORCE)
            } catch (e) {
                this._DbgWarn("Chrome knockback ApplyAbsVelocityImpulse failed: " + e)
            }
        }
        
        // --- AUTOMATIC STUFF (human players only) ---
        if (!IsPlayerABot(player)) {
            if ((weaponName == "pistol" && AUTO_PISTOL) || (weaponName == "sniper_military" && AUTO_SNIPER)) {
                local wep = player.GetActiveWeapon()
                if (wep) NetProps.SetPropInt(wep, "m_isHoldingFireButton", 0)
            }
        }
    }
    
    // ============================================================
    // RIP AND TEAR + SHOTGUN GIB — infected_hurt (merged)
    // ============================================================
    function OnGameEvent_infected_hurt(params) {
        if (!("entityid" in params) || !("attacker" in params)) return
        if (!params.attacker) return
        
        local common = EntIndexToHScript(params.entityid)
        local surv = GetPlayerFromUserID(params.attacker)
        if (!common || !surv || !surv.IsSurvivor()) return
        
        // --- RIP AND TEAR (rifle overkill = wound reset + mag dump tracking) ---
        if (RIP_ENABLED && ("amount" in params)) {
            local health = common.GetHealth()
            if (health > 0 && (health - params.amount) <= 0) {
                local wep = surv.GetActiveWeapon()
                if (wep && wep.IsValid()) {
                    local classname = wep.GetClassname()
                    if (classname in RIFLE_CLASSES) {
                        ResetWounds(common)
                        DeadInfected[params.entityid] <- Time()
                        HitCount[params.entityid] <- 0
                    }
                }
            }
        }
        
        // --- SHOTGUN GIB (buckshot kill < 100u = random gib wound) ---
        if (SG_GIB_ENABLED && ("type" in params) && ("amount" in params)) {
            if ((surv.GetOrigin() - common.GetOrigin()).Length() < 100
                && (common.GetHealth() - params.amount) <= 0
                && (params.type & 536870912))    // DMG_BUCKSHOT
            {
                local gender = NetProps.GetPropInt(common, "m_Gender")
                local badgenders = [14, 15, 17]
                if (badgenders.find(gender) == null) {
                    local wound = null
                    if (gender == 11) {
                        local gibs = [1, 2, 3, 4, 5, 6, 7, 8, 9]
                        wound = gibs[RandomInt(0, gibs.len() - 1)]
                    } else if (gender == 15) {
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
            }
        }
    }
    
    function ResetWounds(who) {
        NetProps.SetPropInt(who, "m_iRequestedWound1", -1)
        NetProps.SetPropInt(who, "m_iRequestedWound2", -1)
    }
    
    function ApplyGib(what, who) {
        if (NetProps.GetPropInt(who, "m_iRequestedWound1") == -1) {
            NetProps.SetPropInt(who, "m_iRequestedWound1", what)
        } else if (NetProps.GetPropInt(who, "m_iRequestedWound2") == -1 && NetProps.GetPropInt(who, "m_iRequestedWound1") != what) {
            NetProps.SetPropInt(who, "m_iRequestedWound2", what)
        }
    }
    
    function ScheduleRipCheck() {
        MaoLib.AddTimer("rip_check", 0.1, function() {
            ::L4CWI_SpecialFirearms.CheckMagDump()
        })
    }
    
    function CheckMagDump() {
        if (!RIP_ENABLED) return
        
        // Find survivors with rifles firing
        local ent = null
        while (ent = Entities.FindByClassname(ent, "player")) {
            if (!ent.IsValid() || !ent.IsSurvivor()) continue
            
            local weapon = ent.GetActiveWeapon()
            if (!weapon || !weapon.IsValid()) continue
            if (!(weapon.GetClassname() in RIFLE_CLASSES)) continue
            
            // Check if firing
            if ((NetProps.GetPropInt(ent, "m_nButtons") & 1) == 0) continue
            
            // Trace
            local eyePos = ent.EyePosition()
            local eyeAngles = ent.EyeAngles()
            local trace = {
                start = eyePos,
                end = eyePos + VectorFromQAngle(eyeAngles, 1000.0),
                ignore = ent,
            }
            TraceLine(trace)
            
            if (!trace.hit || !trace.enthit || trace.enthit.GetClassname() != "infected") continue
            
            local hitEnt = trace.enthit
            local entityID = hitEnt.GetEntityIndex()
            
            if (!(entityID in DeadInfected)) continue
            
            local deathTime = DeadInfected[entityID]
            local timeSince = Time() - deathTime
            
            if (timeSince <= 0.1 || timeSince > 3.0) {
                delete DeadInfected[entityID]
                delete HitCount[entityID]
                continue
            }
            
            HitCount[entityID] = HitCount[entityID] + 1
            local gender = NetProps.GetPropInt(hitEnt, "m_Gender")
            local badgenders = [14, 15, 17]
            
            if (badgenders.find(gender) != null) continue
            
            if (HitCount[entityID] == 2) {
                if (gender == 11 || gender == 15)
                    ApplyGib(3, hitEnt)
                else
                    ApplyGib(22, hitEnt)
            } else if (HitCount[entityID] >= 13) {
                if (RandomFloat(0.0, 1.0) <= 0.5) {
                    if (gender == 11) {
                        local gibs = [1, 2, 4, 5, 6, 7, 8, 9]
                        ApplyGib(gibs[RandomInt(0, gibs.len() - 1)], hitEnt)
                    } else if (gender == 15) {
                        local gibs = [4, 5]
                        ApplyGib(gibs[RandomInt(0, gibs.len() - 1)], hitEnt)
                    } else {
                        local gibs = [23, 24, 25]
                        ApplyGib(gibs[RandomInt(0, gibs.len() - 1)], hitEnt)
                    }
                    delete DeadInfected[entityID]
                    delete HitCount[entityID]
                }
            }
        }
        
        // Cleanup expired
        foreach (entityID, deathTime in DeadInfected) {
            if (Time() - deathTime > 3.0) {
                delete DeadInfected[entityID]
                delete HitCount[entityID]
            }
        }
    }
    
    function OnGameEvent_round_end(params) {
        ::L4CWI_Core.Dbg("SpecialFirearms", "Cleanup on round_end")
        MaoLib.RemoveTimer("rip_check")
        AWP_PENDING = {}
        DeadInfected = {}
        HitCount = {}
    }
}

function VectorFromQAngle(angles, radius)
{
    local pitch = angles.x * -1 * (3.14159 / 180)
    local yaw = angles.y * (3.14159 / 180)
    local tmp = radius * cos(pitch)
    return Vector(tmp * cos(yaw), tmp * sin(yaw), radius * sin(pitch))
}

__CollectGameEventCallbacks(::L4CWI_SpecialFirearms)
::L4CWI_Core.RegisterSystem("SpecialFirearms", ::L4CWI_SpecialFirearms)
printl("[L4CWI] Special Firearms System loaded")
