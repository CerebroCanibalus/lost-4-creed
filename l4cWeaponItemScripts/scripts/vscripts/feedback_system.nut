// ============================================================
// L4CWI — Feedback System v1.1 (Keith-verified fixes)
// Feedback visual y sonoro al jugador
// Fusión de: killsound, killeffect, hitmarker, lasc, clipempty
// ============================================================

::L4CWI_Feedback <- {
    CONFIG_PATH = "l4cwi_config/feedback.cfg"
    PI_CONST = 3.14159265
    
    // === KILLSOUND ===
    KILLSOUND_ENABLED = true
    SoundCount = {}
    
    // === KILLEFFECT ===
    KILLEFFECT_ENABLED = true
    LastImpactPos = Vector(0, 0, 0)
    
    // === HITMARKER ===
    HITMARKER_ENABLED = true
    HITMARKER_BOT = false
    FiredPlayers = []
    
    // === LASC (Low Ammo Sound Cue) ===
    LASC_ENABLED = true
    LASC_THRESHOLD_SHOTGUN = 0.3
    LASC_THRESHOLD_OTHER = 0.2
    
    // === CLIPEMPTY ===
    CLIPEMPTY_ENABLED = true
    CLIPEMPTY_COOLDOWN = 0.3
    RifleEmptyState = {}
    PistolEmptyState = {}
    LastEmptySound = {}
    
    // === WOUND FEEDBACK ===
    WOUND_ENABLED = true
    WoundTime = {}
    Ent_BuckShot = null
    
    RIFLE_WEAPONS = {
        weapon_smg = true, weapon_smg_mp5 = true, weapon_smg_silenced = true,
        weapon_rifle = true, weapon_rifle_ak47 = true, weapon_rifle_desert = true,
        weapon_rifle_sg552 = true, weapon_rifle_m60 = true,
        weapon_sniper_awp = true, weapon_sniper_military = true,
        weapon_sniper_scout = true, weapon_hunting_rifle = true
    }
    
    PISTOL_WEAPONS = {
        weapon_pistol = true, weapon_pistol_magnum = true
    }
    
    function Init() {
        this._Dbg("Initializing feedback system")
        
        local defaults = {
            killsound_enabled = true,
            killeffect_enabled = true,
            hitmarker_enabled = true,
            hitmarker_bot = false,
            lasc_enabled = true,
            clipempty_enabled = true,
            clipempty_cooldown = 0.3,
            wound_enabled = true,
        }
        
        local cfg = ::L4CWI_Core.ParseConfig(CONFIG_PATH, defaults)
        KILLSOUND_ENABLED = cfg.killsound_enabled
        KILLEFFECT_ENABLED = cfg.killeffect_enabled
        HITMARKER_ENABLED = cfg.hitmarker_enabled
        HITMARKER_BOT = cfg.hitmarker_bot
        LASC_ENABLED = cfg.lasc_enabled
        CLIPEMPTY_ENABLED = cfg.clipempty_enabled
        CLIPEMPTY_COOLDOWN = cfg.clipempty_cooldown
        WOUND_ENABLED = cfg.wound_enabled
        
        if (LASC_ENABLED && !IsSoundPrecached("lasc/click.mp3"))
            PrecacheSound("lasc/click.mp3")
        
        this._Dbg("Config loaded — KillSound: " + KILLSOUND_ENABLED + 
                  ", KillEffect: " + KILLEFFECT_ENABLED + 
                  ", Hitmarker: " + HITMARKER_ENABLED)
    }
    
    // ============================================================
    // FUSION: player_death (killsound + killeffect)
    // ============================================================
    function OnGameEvent_player_death(params) {
        // ——— KILLSOUND ———
        if (KILLSOUND_ENABLED && "attacker" in params) {
            local attacker = GetPlayerFromUserID(params.attacker)
            if (attacker && attacker.IsSurvivor()) {
                local victim = null
                if (params.victimname == "Infected" || params.victimname == "Witch")
                    victim = EntIndexToHScript(params.entityid)
                else {
                    victim = GetPlayerFromUserID(params.userid)
                    if (!victim || victim.GetZombieType() > 6) victim = null
                }
                
                if (victim) {
                    local t = Time().tointeger()
                    local vol = 0.6
                    if (t in SoundCount) {
                        SoundCount[t] += 1
                        if (SoundCount[t] > 4) vol = 0
                        else vol *= 1.0 / SoundCount[t]
                    } else {
                        SoundCount[t] <- 1
                    }
                    
                    if (vol > 0) {
                        EmitAmbientSoundOn("Zombie.BulletImpact", vol, 75, RandomInt(95, 105), attacker)
                        EmitAmbientSoundOn("Zombie.BulletImpact", vol, 75, RandomInt(95, 105), victim)
                        
                        if (params.headshot || (params.type & (1 << 29) && 
                            NetProps.GetPropInt(victim, "m_LastHitGroup") == 1)) {
                            EmitAmbientSoundOn("Player.FallDamage", vol, 75, RandomInt(95, 105), attacker)
                            EmitAmbientSoundOn("Player.FallDamage", vol, 75, RandomInt(95, 105), victim)
                            EmitAmbientSoundOn("Flesh.Break", vol, 75, RandomInt(95, 105), attacker)
                            EmitAmbientSoundOn("Flesh.Break", vol, 75, RandomInt(95, 105), victim)
                        }
                    }
                }
            }
        }
        
        // ——— KILLEFFECT ———
        if (KILLEFFECT_ENABLED && "attacker" in params) {
            if ("userid" in params) {
                local victim = GetPlayerFromUserID(params.userid)
                if (victim && victim.GetZombieType() > 7) return
            }
            
            local killer = GetPlayerFromUserID(params.attacker)
            if (!killer || params.type == 128) return
            
            local weapon = params.weapon
            switch (weapon) {
                case "pistol": case "dual_pistols": case "smg": case "smg_silenced": case "smg_mp5":
                    SpawnKillParticle("blood_impact_hunter_01", killer, 0, 0)
                    SpawnKillParticle("blood_impact_hunter_01", killer, 0, 0)
                    break
                    
                case "rifle": case "rifle_ak47": case "rifle_desert": case "rifle_sg552":
                case "pistol_magnum": case "hunting_rifle": case "sniper_military":
                case "sniper_scout": case "sniper_awp":
                    SpawnKillParticle("blood_impact_hunter_01", killer, 0, 0)
                    SpawnKillParticle("blood_impact_hunter_01", killer, 0, 0)
                    SpawnKillParticle("blood_impact_headshot_01", killer, 135, 0)
                    break
                    
                case "pumpshotgun": case "shotgun_chrome": case "autoshotgun": case "shotgun_spas":
                    local victimPos = Vector(params.victim_x, params.victim_y, params.victim_z)
                    local range = (victimPos - killer.EyePosition()).Length()
                    if (range <= 300) {
                        SpawnKillParticle("blood_impact_hunter_01", killer, 0, 0)
                        SpawnKillParticle("blood_impact_hunter_01", killer, 0, 0)
                        SpawnKillParticle("blood_impact_headshot_01", killer, 123.75, 11.25)
                        SpawnKillParticle("blood_impact_headshot_01", killer, 123.75, -11.25)
                    } else if (range <= 500) {
                        SpawnKillParticle("blood_impact_hunter_01", killer, 0, 0)
                        SpawnKillParticle("blood_impact_hunter_01", killer, 0, 0)
                        SpawnKillParticle("blood_impact_headshot_01", killer, 135, 0)
                    } else {
                        SpawnKillParticle("blood_impact_hunter_01", killer, 0, 0)
                        SpawnKillParticle("blood_impact_hunter_01", killer, 0, 0)
                    }
                    break
                    
                case "prop_minigun": case "prop_minigun_l4d1": case "rifle_m60": 
                case "melee": case "chainsaw":
                    local pos = killer.EyePosition()
                    local victimOrigin = Vector(params.victim_x, params.victim_y, params.victim_z)
                    local dy = (pos - Vector(params.victim_x, params.victim_y, pos.z)).Length()
                    victimOrigin.z = pos.z + dy * -tan(killer.EyeAngles().x * PI_CONST / 180)
                    SpawnKillParticleAt("blood_impact_headshot_01", victimOrigin, 
                        killer.EyeAngles().x + 123.75, killer.EyeAngles().y + 11.25)
                    SpawnKillParticleAt("blood_impact_headshot_01", victimOrigin, 
                        killer.EyeAngles().x + 123.75, killer.EyeAngles().y - 11.25)
                    break
            }
        }
    }
    
    // ============================================================
    // KILLSOUND — tank incapacitated (separate event)
    // ============================================================
    function OnGameEvent_player_incapacitated(params) {
        if (!KILLSOUND_ENABLED) return
        if (!("attacker" in params)) return
        
        local surv = GetPlayerFromUserID(params.attacker)
        local tank = GetPlayerFromUserID(params.userid)
        
        if (surv && tank && tank.GetZombieType() == 8 && surv.IsSurvivor()) {
            EmitAmbientSoundOn("Zombie.BulletImpact", 0.7, 75, RandomInt(95, 105), surv)
            EmitAmbientSoundOn("Zombie.BulletImpact", 0.7, 75, RandomInt(95, 105), tank)
        }
    }
    
    function SpawnKillParticle(effect, killer, pitchOffset, yawOffset) {
        local ang = killer.EyeAngles()
        SpawnKillParticleAt(effect, LastImpactPos, ang.x + pitchOffset, ang.y + yawOffset)
    }
    
    function SpawnKillParticleAt(effect, pos, pitch, yaw) {
        local p = SpawnEntityFromTable("info_particle_system", {
            effect_name = effect,
            angles = pitch + " " + yaw + " 0",
            origin = pos,
            start_active = "0"
        })
        DoEntFire("!self", "Start", "", 0, null, p)
        DoEntFire("!self", "Kill", "", 0.25, null, p)
    }
    
    // ============================================================
    // HITMARKER
    // ============================================================
    function OnGameEvent_weapon_fire(params) {
        // ——— Hitmarker tracking ———
        if (HITMARKER_ENABLED && "userid" in params) {
            local player = GetPlayerFromUserID(params.userid)
            if (player && player.IsSurvivor() && !IsPlayerABot(player))
                if (FiredPlayers.find(player) == null)
                    FiredPlayers.append(player)
        }
        
        // ——— LASC ———
        if (LASC_ENABLED && "userid" in params) {
            if ("weaponid" in params && params.weaponid == 54) return // Mounted gun
            
            local player = GetPlayerFromUserID(params.userid)
            if (!player || !player.IsSurvivor()) return
            if (NetProps.GetPropInt(player, "m_lifeState") == 1) return
            
            local weapon = player.GetActiveWeapon()
            if (!weapon || weapon.GetMaxClip1() == -1) return
            if (weapon.GetClassname() == "weapon_chainsaw") return
            if (weapon.GetClassname() == "weapon_grenade_launcher") return
            
            local thres = weapon.GetClassname().find("shotgun") != null 
                ? LASC_THRESHOLD_SHOTGUN : LASC_THRESHOLD_OTHER
            
            local clipAfter = weapon.Clip1() - 1
            local threshold = L4CWI_Feedback_Ceil(weapon.GetMaxClip1() * thres)
            
            if (clipAfter <= threshold) {
                for (local i = 1; i <= 2; i++) {
                    local p_o = player.GetOrigin()
                    local clickOrigin = Vector(p_o.x, p_o.y, p_o.z + 4) + player.GetVelocity() * 0.15
                    local snd = SpawnEntityFromTable("ambient_generic", {
                        origin = clickOrigin,
                        message = "lasc/click.mp3",
                        spawnflags = 48,
                        health = 10
                    })
                    DoEntFire("!self", "PlaySound", "", 0, null, snd)
                    DoEntFire("!self", "Kill", "", 0, null, snd)
                }
            }
        }
    }
    
    function OnGameEvent_player_hurt(params) {
        if (!HITMARKER_ENABLED) return
        
        local attacker = GetPlayerFromUserID(params.attacker)
        if (!attacker) return
        if (!HITMARKER_BOT && attacker.GetClassname() == "player" && IsPlayerABot(attacker)) return
        
        local victim = GetPlayerFromUserID(params.userid)
        if (NetProps.GetPropInt(victim, "m_iTeamNum") != 2)
            PlayHitmarkerSound(attacker)
    }
    
    function PlayHitmarkerSound(player) {
        if (!player || !player.IsSurvivor() || IsPlayerABot(player)) return
        
        local idx = FiredPlayers.find(player)
        if (idx == null) return
        FiredPlayers.remove(idx)
        
        EmitSoundOnClient("Coach_Blank", player)
    }
    
    // ============================================================
    // CLIPEMPTY
    // ============================================================
    function OnGameEvent_round_start(params) {
        if (!CLIPEMPTY_ENABLED) return
        RifleEmptyState = {}
        PistolEmptyState = {}
        LastEmptySound = {}
    }
    
    function CheckEmptyClips() {
        if (!CLIPEMPTY_ENABLED) return
        
        local ent = null
        while (ent = Entities.FindByClassname(ent, "player")) {
            if (NetProps.GetPropInt(ent, "m_lifeState") != 0 || !ent.IsSurvivor()) continue
            
            local uid = ent.GetPlayerUserId()
            local weapon = ent.GetActiveWeapon()
            if (!weapon) continue
            
            local wpc = weapon.GetClassname()
            local clip = weapon.Clip1()
            local maxClip = weapon.GetMaxClip1()
            local isAttacking = NetProps.GetPropInt(ent, "m_nButtons") & 1
            
            if (wpc in RIFLE_WEAPONS) {
                local wasEmpty = (uid in RifleEmptyState) ? RifleEmptyState[uid] : false
                
                if (clip == 0 && !wasEmpty) {
                    RifleEmptyState[uid] <- true
                    if (isAttacking) PlayEmptySound(ent, false)
                } else if (clip > 0 && wasEmpty) {
                    RifleEmptyState[uid] <- false
                }
            }
            else if (wpc in PISTOL_WEAPONS) {
                local wasEmpty = (uid in PistolEmptyState) ? PistolEmptyState[uid] : false
                local threshold = (maxClip == 30) ? 1 : 0
                
                if (clip <= threshold && !wasEmpty) {
                    PistolEmptyState[uid] <- true
                    if (isAttacking) PlayEmptySound(ent, true)
                } else if (clip > threshold && wasEmpty) {
                    PistolEmptyState[uid] <- false
                }
            }
        }
        
        if (CLIPEMPTY_ENABLED)
            MaoLib.AddTimer("clipempty_check", 0.1, function() { ::L4CWI_Feedback.CheckEmptyClips() })
    }
    
    function PlayEmptySound(player, isPistol) {
        local uid = player.GetPlayerUserId()
        local now = Time()
        
        if (uid in LastEmptySound) {
            if (now - LastEmptySound[uid] < CLIPEMPTY_COOLDOWN) return
        }
        LastEmptySound[uid] <- now
        
        local sound = isPistol ? "weapons/clipempty_pistol.wav" : "weapons/clipempty_rifle.wav"
        EmitSoundOn(sound, player)
    }
    
    // ============================================================
    // WOUND FEEDBACK — Dynamic wounds on commons
    // ============================================================
    function OnGameEvent_round_start_post_nav(params) {
        if (CLIPEMPTY_ENABLED)
            CheckEmptyClips()
        
        if (WOUND_ENABLED && !Ent_BuckShot) {
            Ent_BuckShot = SpawnEntityFromTable("func_timescale", {
                origin = Vector(0, 0, 0),
                angles = Vector(0, 0, 0),
                desiredTimescale = 1.0,
                acceleration = 1.0,
                minBlendRate = 1.0,
                blendDeltaMultiplier = 1.0,
            })
        }
    }
    
    function OnGameEvent_bullet_impact(params) {
        // Existing killeffect + hitmarker code
        if (KILLEFFECT_ENABLED && "x" in params)
            LastImpactPos = Vector(params.x, params.y, params.z)
        
        if (HITMARKER_ENABLED && "userid" in params) {
            local player = GetPlayerFromUserID(params.userid)
            if (player && player.IsSurvivor() && !IsPlayerABot(player))
                if (FiredPlayers.find(player) == null)
                    FiredPlayers.append(player)
        }
        
        // Wound feedback: force alive infected
        if (WOUND_ENABLED) {
            local infected = Entities.FindByClassnameNearest("infected", Vector(params.x, params.y, params.z), 0.0)
            if (infected && NetProps.GetPropInt(infected, "m_lifeState") != 0) {
                infected.TakeDamage(0, (1 << 25), infected)
            }
        }
    }
    
    function OnGameEvent_infected_hurt(params) {
        // Existing killeffect + hitmarker code
        if (KILLEFFECT_ENABLED && "hitgroup" in params && params.hitgroup == 1 && "entityid" in params) {
            local infected = EntIndexToHScript(params.entityid)
            if (infected && infected.GetClassname() != "witch") {
                local gender = NetProps.GetPropInt(infected, "m_Gender")
                if (gender != 14 && gender != 17)
                    infected.SetHealth(1)
            }
        }
        
        if (HITMARKER_ENABLED && "entityid" in params && "attacker" in params) {
            local victim = EntIndexToHScript(params.entityid)
            local attacker = GetPlayerFromUserID(params.attacker)
            if (!HITMARKER_BOT && IsPlayerABot(attacker)) return
            if (victim.GetClassname() == "witch")
                PlayHitmarkerSound(attacker)
        }
        
        // Wound feedback logic
        if (!WOUND_ENABLED) return
        if (!("entityid" in params)) return
        
        local infected = EntIndexToHScript(params.entityid)
        if (!infected || infected.GetClassname() == "witch") return
        if ("amount" in params && params.amount == 0) return
        if (!("attacker" in params)) return
        
        local attacker = GetPlayerFromUserID(params.attacker)
        if (!attacker || !attacker.IsSurvivor()) return
        
        local gender = NetProps.GetPropInt(infected, "m_Gender")
        if (gender == 17) return
        
        local damage = ("amount" in params) ? params.amount : 0
        local health = infected.GetHealth()
        local remaining = health - damage
        local halfHealth = infected.GetMaxHealth() * 0.5 + 1
        local dmgType = ("type" in params) ? params.type : 0
        local hitGroup = ("hitgroup" in params) ? params.hitgroup : 0
        
        if (remaining > 1 && !(dmgType & (1 << 3)) && !(dmgType & (1 << 6)) && hitGroup != 1) {
            if (NetProps.GetPropInt(infected, "m_iRequestedWound2") != -1)
                NetProps.SetPropInt(infected, "m_iRequestedWound2", -1)
            
            if (remaining > halfHealth) {
                if (NetProps.GetPropInt(infected, "m_iRequestedWound1") != -1)
                    NetProps.SetPropInt(infected, "m_iRequestedWound1", -1)
            } else if (!(infected in WoundTime)) {
                ApplyWound(infected, attacker, gender, hitGroup, dmgType, remaining <= 1)
            }
        } else if (remaining <= 1) {
            // Near death wounds
            if (remaining == 1)
                infected.SetHealth(damage)
            
            if (!(infected in WoundTime)) {
                ApplyWound(infected, attacker, gender, hitGroup, dmgType, true)
            }
        }
    }
    
    function ApplyWound(infected, attacker, gender, hitGroup, dmgType, isNearDeath) {
        local wound1 = NetProps.GetPropInt(infected, "m_iRequestedWound1")
        local newWound = wound1
        
        // Simplified wound logic by gender and hitgroup
        switch (gender) {
            case 0: case 1: case 12: case 13: case 14: case 16: case 20: case 21:
                if (wound1 == -1) {
                    switch (hitGroup) {
                        case 2:
                            if (dmgType == -2147483646 || dmgType == -1610612734)
                                newWound = 7
                            break
                        case 3:
                            if (dmgType == -2147483646 || dmgType == -1610612734)
                                newWound = 26
                            break
                        case 4: newWound = 19; break
                        case 5: newWound = 13; break
                        case 6: newWound = 21; break
                        case 7: newWound = 17; break
                    }
                }
                break
            case 2: case 22:
                if (wound1 == -1) {
                    switch (hitGroup) {
                        case 2:
                            if (dmgType == -2147483646 || dmgType == -1610612734)
                                newWound = 7
                            break
                        case 3:
                            if (dmgType == -2147483646 || dmgType == -1610612734)
                                newWound = 25
                            break
                        case 4: newWound = 18; break
                        case 5: newWound = 12; break
                        case 6: newWound = 20; break
                        case 7: newWound = 16; break
                    }
                }
                break
            case 11:
                if (wound1 == -1) {
                    switch (hitGroup) {
                        case 1: newWound = 0; break
                        case 4: newWound = 7; break
                        case 5: newWound = 3; break
                        case 6: newWound = 9; break
                        case 7: newWound = 5; break
                    }
                }
                break
        }
        
        if (newWound != wound1 && newWound != -1) {
            NetProps.SetPropInt(infected, "m_iRequestedWound1", newWound)
            WoundTime[infected] <- Time()
            
            // Apply force feedback
            if (Ent_BuckShot && Ent_BuckShot.IsValid()) {
                local aOri = attacker.EyePosition()
                local iOri = infected.GetOrigin()
                local loc = iOri + (aOri - iOri) * (200 / (aOri - iOri).Length())
                Ent_BuckShot.SetOrigin(loc)
                infected.TakeDamage(0, (1 << 29), Ent_BuckShot)
            }
        }
    }
    
    function OnGameEvent_round_end(params) {
        MaoLib.RemoveTimer("clipempty_check")
        RifleEmptyState = {}
        PistolEmptyState = {}
        LastEmptySound = {}
        FiredPlayers = []
        SoundCount = {}
        WoundTime = {}
        if (Ent_BuckShot && Ent_BuckShot.IsValid()) {
            Ent_BuckShot.Kill()
            Ent_BuckShot = null
        }
    }

}

// Helper: ceil() replacement
function L4CWI_Feedback_Ceil(v) {
    local f = v.tointeger()
    return f < v ? f + 1 : f
}

__CollectGameEventCallbacks(::L4CWI_Feedback)
::L4CWI_Core.RegisterSystem("Feedback", ::L4CWI_Feedback)
printl("[L4CWI] Feedback System loaded")
