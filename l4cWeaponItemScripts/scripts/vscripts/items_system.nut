// ============================================================
// L4CWI — Items System v1.0
// Consumibles, upgrades y objetos del mundo
// Fusión de: auto_upgrade, heldcans, difficultylimitedammo, fasterreload_syr
// (overdose_pills, item_buffs, savelogicpills se migrarán en v2)
// ============================================================

::L4CWI_Items <- {
    CONFIG_PATH = "l4cwi_config/items.cfg"
    
    // === AUTO UPGRADE ===
    AUTO_UPGRADE_ENABLED = true
    
    // === HELD CANS ===
    HELD_CANS_ENABLED = true
    
    // === DIFFICULTY LIMITED AMMO ===
    AMMO_LIMIT_ENABLED = true
    AmmoUses = 0
    
    // Difficulty -> max uses before despawn
    AMMO_LIMITS = { [0] = 999, [1] = 3, [2] = 2, [3] = 1 }
    
    // === FASTER RELOAD (Adrenaline) ===
    ADRENALINE_RELOAD_ENABLED = true
    ADRENALINE_RELOAD_MULT = 1.5
    
    // === ITEM BUFFS (DESACTIVADO — merged a system_perks_unified.nut) ===
    ITEM_BUFFS_ENABLED = false
    ITEM_BUFFS = {
        // Medkit: +1 HP cada 10s, radio 110
        medkit = { radius = 110, interval = 10.0, heal = 1, temp = false },
        // Gnome: ammo cada 10s + adrenaline AoE cada 60s, radio 100
        gnome = { radius = 100, interval = 10.0, ammoMin = 1, ammoMax = 20, adrenInterval = 60.0, adrenDuration = 5 },
        // Pills: +5 temp HP cada 15s, radio 88
        pain_pills = { radius = 88, interval = 15.0, heal = 5, temp = true },
        // Adrenaline: +3 HP cada 35s, radio 121
        adrenaline = { radius = 121, interval = 35.0, heal = 3, temp = false }
    }
    // Track active item timers by owner entity index
    ActiveItemTimers = {}
    
    // === MEDKIT DEGRADE + STACK SYSTEM ===
    MEDKIT_DEGRADE_ENABLED = true
    MEDKIT_DEGRADE_RATE = 0.15        // 15% less healing per tick
    MEDKIT_DEGRADE_MIN_MULT = 0.25    // Never heal less than 25% of base
    MEDKIT_STACK_ENABLED = true
    MEDKIT_STACK_MULT = 0.40          // +40% per additional medkit owner
    MEDKIT_MAX_STACK_MULT = 2.2       // Cap at 2.2x (4 players)
    MEDKIT_FULLSTACK_VFX = "adrenaline_light"  // Particle for full squad buff
    
    // [entityIndex] = { ticks, owner }
    MedkitOwners = {}
    // [entityIndex] = particleHandle (for cleanup)
    MedkitEffects = {}
    
    // === OVERDOSE PILLS ===
    OVERDOSE_ENABLED = true
    OVERDOSE_MAX_PILLS = 5
    OVERDOSE_HEALTH_PENALTY = 10
    OverdoseData = {}
    
    // === INFECTED DISARM ===
    DISARM_ENABLED = true
    DISARM_LOW_HEALTH = 30
    DISARM_DEFAULT_CHANCE = 20
    DISARM_LOW_CHANCE = 40
    
    function Init() {
        this._Dbg("Initializing items system")
        
        local defaults = {
            auto_upgrade_enabled = true,
            held_cans_enabled = true,
            ammo_limit_enabled = true,
            adrenaline_reload_enabled = true,
            adrenaline_reload_mult = 1.5,
            item_buffs_enabled = false,  // DESACTIVADO — merged a system_perks_unified.nut
            medkit_degrade_enabled = true,
            medkit_degrade_rate = 0.15,
            medkit_degrade_min_mult = 0.25,
            medkit_stack_enabled = true,
            medkit_stack_mult = 0.40,
            medkit_max_stack_mult = 2.2,
            overdose_enabled = true,
            overdose_max_pills = 5,
            overdose_health_penalty = 10,
            disarm_enabled = true,
            disarm_low_health = 30,
            disarm_default_chance = 20,
            disarm_low_chance = 40,
        }
        
        local cfg = ::L4CWI_Core.ParseConfig(CONFIG_PATH, defaults)
        AUTO_UPGRADE_ENABLED = cfg.auto_upgrade_enabled
        HELD_CANS_ENABLED = cfg.held_cans_enabled
        AMMO_LIMIT_ENABLED = cfg.ammo_limit_enabled
        ADRENALINE_RELOAD_ENABLED = cfg.adrenaline_reload_enabled
        ADRENALINE_RELOAD_MULT = cfg.adrenaline_reload_mult
        ITEM_BUFFS_ENABLED = cfg.item_buffs_enabled
        MEDKIT_DEGRADE_ENABLED = cfg.medkit_degrade_enabled
        MEDKIT_DEGRADE_RATE = cfg.medkit_degrade_rate
        MEDKIT_DEGRADE_MIN_MULT = cfg.medkit_degrade_min_mult
        MEDKIT_STACK_ENABLED = cfg.medkit_stack_enabled
        MEDKIT_STACK_MULT = cfg.medkit_stack_mult
        MEDKIT_MAX_STACK_MULT = cfg.medkit_max_stack_mult
        OVERDOSE_ENABLED = cfg.overdose_enabled
        OVERDOSE_MAX_PILLS = cfg.overdose_max_pills
        OVERDOSE_HEALTH_PENALTY = cfg.overdose_health_penalty
        DISARM_ENABLED = cfg.disarm_enabled
        DISARM_LOW_HEALTH = cfg.disarm_low_health
        DISARM_DEFAULT_CHANCE = cfg.disarm_default_chance
        DISARM_LOW_CHANCE = cfg.disarm_low_chance
        
        this._Dbg("Config loaded — AutoUpgrade: " + AUTO_UPGRADE_ENABLED + 
                  ", HeldCans: " + HELD_CANS_ENABLED + 
                  ", AmmoLimit: " + AMMO_LIMIT_ENABLED +
                  ", ItemBuffs: " + ITEM_BUFFS_ENABLED +
                  ", MedkitDegrade: " + MEDKIT_DEGRADE_ENABLED +
                  ", MedkitStack: " + MEDKIT_STACK_ENABLED)
    }
    
    // ============================================================
    // AUTO UPGRADE — Comparte upgrades con todo el equipo
    // ============================================================
    function OnGameEvent_upgrade_pack_used(params) {
        if (!AUTO_UPGRADE_ENABLED) return
        if (!("upgradeid" in params)) return
        
        local upgradeID = params.upgradeid.tointeger()
        local upgradeEnt = EntIndexToHScript(upgradeID)
        if (!upgradeEnt || !upgradeEnt.IsValid()) return
        
        local upgradeClass = upgradeEnt.GetClassname()
        local upgradeType = -1
        
        if (upgradeClass == "upgrade_ammo_explosive") upgradeType = 1
        else if (upgradeClass == "upgrade_ammo_incendiary") upgradeType = 0
        
        if (upgradeType == -1) return
        
        // Give upgrade to all alive survivors
        local ent = null
        while (ent = Entities.FindByClassname(ent, "player")) {
            if (ent.IsValid() && ent.IsSurvivor() && 
                !ent.IsIncapacitated() && 
                NetProps.GetPropInt(ent, "m_lifeState") == 0) {
                ent.GiveUpgrade(upgradeType)
            }
        }
        
        upgradeEnt.Kill()
        this._Dbg("Auto-upgrade shared: " + upgradeClass)
    }
    
    // ============================================================
    // FASTER RELOAD — Recarga rápida bajo adrenalina
    // ============================================================
    function OnGameEvent_weapon_reload(params) {
        if (!ADRENALINE_RELOAD_ENABLED) return
        if (!("userid" in params) || !params.userid) return
        
        local player = GetPlayerFromUserID(params.userid)
        if (!player) return
        
        local wep = player.GetActiveWeapon()
        if (!wep || !player.IsAdrenalineActive()) return
        
        local newReloadTime = ((NetProps.GetPropFloat(wep, "m_flNextPrimaryAttack") - Time()) / ADRENALINE_RELOAD_MULT) + Time()
        
        NetProps.SetPropFloat(wep, "m_flPlaybackRate", ADRENALINE_RELOAD_MULT)
        NetProps.SetPropFloat(wep, "m_flNextPrimaryAttack", newReloadTime)
        NetProps.SetPropFloat(player, "m_flNextAttack", newReloadTime)
        
        this._Dbg("Adrenaline reload boost for " + player.GetEntityIndex())
    }
    
    // ============================================================
    // HELD CANS — Objetos held explotan con friendly fire
    // ============================================================
    function OnGameEvent_friendly_fire(params) {
        if (!HELD_CANS_ENABLED) return
        if (!("victim" in params)) return
        
        local victim = GetPlayerFromUserID(params.victim)
        if (!victim) return
        
        local heldItem = GetHeldSlot(victim)
        if (!heldItem) return
        
        local activeWeapon = ::L4CWI_Core.GetActiveWeaponClass(victim)
        if (activeWeapon != heldItem) return
        
        // Don't drop gnome or cola
        if (heldItem == "weapon_gnome" || heldItem == "weapon_cola_bottles") return
        
        // Drop item using DoEntFire (more reliable than method call)
        DoEntFire("!self", "DropItem", "", 0, victim, victim)
        
        // Kill the weapon entity
        local wepEnt = victim.GetActiveWeapon()
        if (wepEnt && wepEnt.IsValid()) wepEnt.Kill()
        
        switch (heldItem) {
            case "weapon_gascan":
                DropFireNative(victim.GetOrigin())
                break
                
            case "weapon_propanetank":
                victim.TakeDamage(21, 6, victim)
                victim.Stagger(Vector(0, 0, 0))
                DamageInRadius(victim.GetOrigin(), 250, "infected", 25, 33554432, victim, 0)
                DamageInRadius(victim.GetOrigin(), 250, "player", 10, 33554432, victim, 1)
                break
                
            case "weapon_fireworkcrate":
                DropFireNative(victim.GetOrigin())
                break
                
            case "weapon_oxygentank":
                victim.Stagger(Vector(0, 0, 0))
                victim.SetVelocity(victim.GetVelocity() + Vector(0, 0, 300))
                victim.TakeDamage(15, 6, victim)
                DamageInRadius(victim.GetOrigin(), 200, "infected", 20, 33554432, victim, 0)
                DamageInRadius(victim.GetOrigin(), 200, "player", 5, 33554432, victim, 1)
                break
        }
        
        this._Dbg("Held item detonated: " + heldItem)
    }
    
    function GetHeldSlot(player) {
        // slot5 = index 4 in m_hWeaponSlots array
        local wep = NetProps.GetPropEntityArray(player, "m_hWeaponSlots", 4)
        return wep ? wep.GetClassname() : null
    }
    
    function DropFireNative(origin) {
        local fire = SpawnEntityFromTable("env_inferno", {
            origin = origin,
            lifetime = 8.0,
            firesizestart = 64.0,
            firesizeend = 32.0,
        })
        if (fire) DoEntFire("!self", "StartFire", "", 0, null, fire)
    }
    
    function DamageInRadius(origin, radius, classname, damage, dmgType, attacker, doStagger) {
        local ent = null
        while (ent = Entities.FindByClassnameWithin(ent, classname, origin, radius)) {
            ent.TakeDamage(damage, dmgType, attacker)
            if (doStagger) ent.Stagger(Vector(0, 0, 0))
        }
    }
    
    // ============================================================
    // DIFFICULTY LIMITED AMMO — Piles desaparecen tras N usos
    // ============================================================
    function OnGameEvent_ammo_pickup(params) {
        if (!AMMO_LIMIT_ENABLED) return
        if (!("userid" in params)) return
        
        local player = GetPlayerFromUserID(params.userid)
        if (!player) return
        
        local ammo = Entities.FindByClassnameNearest("weapon_ammo_spawn", player.GetOrigin(), 150)
        if (!ammo) return
        
        local diffStr = Convars.GetStr("z_difficulty").tolower()
        local diff = 1 // Normal default
        if (diffStr == "easy") diff = 0
        else if (diffStr == "hard") diff = 2
        else if (diffStr == "impossible") diff = 3
        if (!(diff in AMMO_LIMITS)) return
        
        local limit = AMMO_LIMITS[diff]
        if (limit >= 999) return // Easy / unlimited
        
        AmmoUses++
        if (AmmoUses >= limit) {
            ammo.Kill()
            AmmoUses = 0
            this._Dbg("Ammo pile despawned (diff " + diff + ", limit " + limit + ")")
        }
    }
    
    // ============================================================
    // ITEM BUFFS — Passive effects from carried items
    // ============================================================
    function OnGameEvent_item_pickup(params) {
        if (!ITEM_BUFFS_ENABLED) return
        if (!("item" in params) || !("userid" in params)) return
        
        local itemName = params.item
        if (!(itemName in ITEM_BUFFS)) return
        
        local player = GetPlayerFromUserID(params.userid)
        if (!player || !player.IsSurvivor()) return
        
        // Find the actual weapon entity owned by player
        local wep = null
        while (wep = Entities.FindByClassname(wep, "weapon_" + itemName)) {
            if (wep.GetOwnerEntity() == player) {
                StartItemBuffTimer(player, itemName)
                break
            }
        }
    }
    
    function StartItemBuffTimer(player, itemName) {
        local uid = player.GetPlayerUserId()
        if (uid in ActiveItemTimers) return // Already active
        
        local cfg = ITEM_BUFFS[itemName]
        local timerName = "itembuff_" + itemName + "_" + uid
        
        ActiveItemTimers[uid] <- timerName
        
        // Schedule recurring timer
        local interval = cfg.interval
        if (itemName == "gnome") interval = cfg.interval // Gnome uses same interval for ammo
        
        ScheduleItemBuffTick(player, itemName, timerName, interval)
        
        // Gnome also needs adrenaline timer
        if (itemName == "gnome" && "adrenInterval" in cfg) {
            local adrenTimer = "itembuff_gnome_adren_" + uid
            ScheduleItemBuffTick(player, "gnome_adren", adrenTimer, cfg.adrenInterval)
        }
        
        this._Dbg("Started item buff: " + itemName + " for " + uid)
    }
    
    function ScheduleItemBuffTick(player, itemName, timerName, interval) {
        MaoLib.AddTimer(timerName, interval, function() {
            if (!player.IsValid() || NetProps.GetPropInt(player, "m_lifeState") != 0) {
                delete ::L4CWI_Items.ActiveItemTimers[player.GetPlayerUserId()]
                return
            }
            
            // Check player still has the item
            local hasItem = false
            local realItemName = itemName
            if (itemName == "gnome_adren") realItemName = "gnome"
            
            local wep = null
            while (wep = Entities.FindByClassname(wep, "weapon_" + realItemName)) {
                if (wep.GetOwnerEntity() == player) {
                    hasItem = true
                    break
                }
            }
            
            if (!hasItem) {
                local puid = player.GetPlayerUserId()
                delete ::L4CWI_Items.ActiveItemTimers[puid]
                // Cleanup medkit tracking if this was a medkit
                if (realItemName == "medkit") {
                    ::L4CWI_Items.RemoveMedkitOwner(player.GetEntityIndex())
                }
                return
            }
            
            ::L4CWI_Items.ApplyItemBuff(player, itemName)
            
            // Reschedule
            ::L4CWI_Items.ScheduleItemBuffTick(player, itemName, timerName, interval)
        })
    }
    
    function ApplyItemBuff(player, itemName) {
        if (!player.IsValid() || player.IsIncapacitated()) return
        if (NetProps.GetPropInt(player, "m_lifeState") != 0) return
        
        local origin = player.GetOrigin()
        
        switch (itemName) {
            case "medkit":
                local cfg = ITEM_BUFFS.medkit
                local entIdx = player.GetEntityIndex()
                
                // Register as medkit owner
                RegisterMedkitOwner(entIdx, player)
                
                // Calculate stack multiplier
                local medkitCount = CountMedkitOwners()
                local stackMult = 1.0
                if (MEDKIT_STACK_ENABLED && medkitCount > 1) {
                    stackMult = 1.0 + (medkitCount - 1) * MEDKIT_STACK_MULT
                    if (stackMult > MEDKIT_MAX_STACK_MULT) stackMult = MEDKIT_MAX_STACK_MULT
                }
                
                // Calculate degradation multiplier
                local degradeMult = 1.0
                if (MEDKIT_DEGRADE_ENABLED) {
                    degradeMult = GetMedkitDegradeMult(entIdx)
                    IncrementMedkitTick(entIdx)
                }
                
                local finalHeal = (cfg.heal * stackMult * degradeMult).tointeger()
                if (finalHeal < 1) finalHeal = 1
                
                HealNearbySurvivors(origin, cfg.radius, finalHeal, cfg.temp)
                
                // Full squad effect: 4+ medkits + 4+ survivors in range
                if (MEDKIT_STACK_ENABLED && medkitCount >= 4) {
                    local survivorsInRange = CountSurvivorsInRange(origin, cfg.radius)
                    if (survivorsInRange >= 4) {
                        SpawnFullStackEffect(player)
                    }
                }
                
                this._Dbg("Medkit tick — owner: " + entIdx + 
                          " stacks: " + medkitCount + 
                          " stackMult: " + stackMult +
                          " degradeMult: " + degradeMult +
                          " finalHeal: " + finalHeal)
                break
                
            case "gnome":
                local cfg = ITEM_BUFFS.gnome
                player.GiveAmmo(RandomInt(cfg.ammoMin, cfg.ammoMax))
                break
                
            case "gnome_adren":
                local cfg = ITEM_BUFFS.gnome
                ApplyAdrenalineNearby(origin, cfg.radius, cfg.adrenDuration)
                break
                
            case "pain_pills":
                local cfg = ITEM_BUFFS.pain_pills
                HealNearbySurvivors(origin, cfg.radius, cfg.heal, cfg.temp)
                break
                
            case "adrenaline":
                local cfg = ITEM_BUFFS.adrenaline
                HealNearbySurvivors(origin, cfg.radius, cfg.heal, cfg.temp)
                break
        }
    }
    
    // ============================================================
    // MEDKIT DEGRADE + STACK HELPERS
    // ============================================================
    function RegisterMedkitOwner(entIdx, player) {
        if (!(entIdx in MedkitOwners)) {
            MedkitOwners[entIdx] <- { ticks = 0, owner = player }
        }
    }
    
    function RemoveMedkitOwner(entIdx) {
        if (entIdx in MedkitOwners) {
            delete MedkitOwners[entIdx]
        }
        if (entIdx in MedkitEffects) {
            local p = MedkitEffects[entIdx]
            if (p && p.IsValid()) {
                ::MaoLib_VFX.SafeKill(p, 0.1)
            }
            delete MedkitEffects[entIdx]
        }
    }
    
    function CountMedkitOwners() {
        local count = 0
        local toRemove = []
        foreach (entIdx, data in MedkitOwners) {
            local p = data.owner
            if (!p || !p.IsValid() || NetProps.GetPropInt(p, "m_lifeState") != 0) {
                toRemove.append(entIdx)
                continue
            }
            count++
        }
        foreach (entIdx in toRemove) {
            RemoveMedkitOwner(entIdx)
        }
        return count
    }
    
    function GetMedkitDegradeMult(entIdx) {
        if (!(entIdx in MedkitOwners)) return 1.0
        local ticks = MedkitOwners[entIdx].ticks
        local mult = 1.0 - (ticks * MEDKIT_DEGRADE_RATE)
        if (mult < MEDKIT_DEGRADE_MIN_MULT) mult = MEDKIT_DEGRADE_MIN_MULT
        return mult
    }
    
    function IncrementMedkitTick(entIdx) {
        if (entIdx in MedkitOwners) {
            MedkitOwners[entIdx].ticks += 1
        }
    }
    
    function CountSurvivorsInRange(origin, radius) {
        local count = 0
        local ent = null
        while (ent = Entities.FindByClassname(ent, "player")) {
            if (!ent.IsValid() || !ent.IsSurvivor()) continue
            if (NetProps.GetPropInt(ent, "m_lifeState") != 0) continue
            if (ent.IsIncapacitated()) continue
            if ((origin - ent.GetOrigin()).Length() <= radius) {
                count++
            }
        }
        return count
    }
    
    function SpawnFullStackEffect(player) {
        if (!player || !player.IsValid()) return
        
        local entIdx = player.GetEntityIndex()
        
        // Only spawn if no active effect for this player
        if (entIdx in MedkitEffects) {
            local p = MedkitEffects[entIdx]
            if (p && p.IsValid()) return // Still active
        }
        
        // Spawn subtle particle on player
        local particle = ::MaoLib_VFX.SpawnParticleOnEntity(
            player,
            MEDKIT_FULLSTACK_VFX,
            "",
            3.0
        )
        
        if (particle && particle.IsValid()) {
            MedkitEffects[entIdx] <- particle
        }
    }
    
    function CleanupAllMedkitEffects() {
        foreach (entIdx, particle in MedkitEffects) {
            if (particle && particle.IsValid()) {
                ::MaoLib_VFX.SafeKill(particle, 0.1)
            }
        }
        MedkitEffects = {}
    }
    
    function HealNearbySurvivors(origin, radius, amount, isTemp) {
        local ent = null
        while (ent = Entities.FindByClassname(ent, "player")) {
            if (!ent.IsValid() || !ent.IsSurvivor()) continue
            if (NetProps.GetPropInt(ent, "m_lifeState") != 0) continue
            if (ent.IsIncapacitated()) continue
            
            if ((origin - ent.GetOrigin()).Length() <= radius) {
                if (isTemp) {
                    local maxHP = NetProps.GetPropInt(ent, "m_iMaxHealth")
                    local currentBuffer = NetProps.GetPropFloat(ent, "m_healthBuffer")
                    if ((ent.GetHealth() + currentBuffer) < maxHP) {
                        NetProps.SetPropFloat(ent, "m_healthBuffer", currentBuffer + amount)
                    }
                } else {
                    local maxHP = NetProps.GetPropInt(ent, "m_iMaxHealth")
                    if (ent.GetHealth() < maxHP) {
                        ent.SetHealth(ent.GetHealth() + amount)
                    }
                }
            }
        }
    }
    
    function ApplyAdrenalineNearby(origin, radius, duration) {
        local ent = null
        while (ent = Entities.FindByClassname(ent, "player")) {
            if (!ent.IsValid() || !ent.IsSurvivor()) continue
            if (NetProps.GetPropInt(ent, "m_lifeState") != 0) continue
            if (ent.IsIncapacitated()) continue
            
            if ((origin - ent.GetOrigin()).Length() <= radius) {
                ent.UseAdrenaline(duration)
            }
        }
    }
    
    // ============================================================
    // OVERDOSE PILLS — Reduce max health per use
    // ============================================================
    function OnGameEvent_pills_used(params) {
        if (!OVERDOSE_ENABLED) return
        if (!("userid" in params)) return
        
        local userid = params.userid
        local player = GetPlayerFromUserID(userid)
        if (!player || !player.IsValid() || !player.IsSurvivor()) return
        
        if (!(userid in OverdoseData)) {
            OverdoseData[userid] <- { count = 0, lastMaxHP = player.GetMaxHealth() }
        }
        
        local data = OverdoseData[userid]
        data.count += 1
        
        local newMax = data.lastMaxHP - OVERDOSE_HEALTH_PENALTY
        if (newMax < 1) newMax = 1
        NetProps.SetPropInt(player, "m_iMaxHealth", newMax)
        
        if (player.GetHealth() > newMax) {
            player.SetHealth(newMax)
        }
        
        if (data.count >= OVERDOSE_MAX_PILLS) {
            player.SetHealth(0)
            data.count = 0
            data.lastMaxHP = player.GetMaxHealth()
            this._Dbg("Overdose killed player " + userid)
        } else {
            data.lastMaxHP = player.GetMaxHealth()
            this._Dbg("Overdose count for " + userid + ": " + data.count + ", maxHP: " + newMax)
        }
    }
    
    function OnGameEvent_player_death(params) {
        if (!("userid" in params)) return
        if (params.userid in OverdoseData) {
            delete OverdoseData[params.userid]
        }
    }
    
    // ============================================================
    // INFECTED DISARM — Chance to drop primary weapon when hit
    // ============================================================
    function OnGameEvent_player_hurt(params) {
        if (!DISARM_ENABLED) return
        if (!("userid" in params) || !("type" in params)) return
        
        // Only common infected melee damage
        if (params.type != 128) return
        
        local victim = GetPlayerFromUserID(params.userid)
        if (!victim || !victim.IsValid() || !victim.IsSurvivor()) return
        if (victim.IsIncapacitated()) return
        
        local totalHealth = victim.GetHealth() + NetProps.GetPropFloat(victim, "m_healthBuffer")
        local chance = 0
        
        if (totalHealth > DISARM_LOW_HEALTH) {
            chance = DISARM_DEFAULT_CHANCE
        } else {
            chance = DISARM_LOW_CHANCE
        }
        
        if (RandomInt(0, 99) < chance) {
            // Drop primary weapon if currently holding it
            local primary = NetProps.GetPropEntityArray(victim, "m_hWeaponSlots", 0)
            if (primary && primary.IsValid()) {
                local active = victim.GetActiveWeapon()
                if (active && active.IsValid() && active == primary) {
                    DoEntFire("!self", "DropItem", "", 0, victim, victim)
                    this._Dbg("Player disarmed: " + victim.GetEntityIndex())
                }
            }
        }
    }
    
    function OnGameEvent_round_start(params) {
        AmmoUses = 0
        ActiveItemTimers = {}
        OverdoseData = {}
        MedkitOwners = {}
        CleanupAllMedkitEffects()
    }
    
    function OnGameEvent_round_end(params) {
        AmmoUses = 0
        // Stop all active item timers before clearing tracking
        foreach (uid, timerName in ActiveItemTimers) {
            MaoLib.RemoveTimer(timerName)
        }
        ActiveItemTimers = {}
        MedkitOwners = {}
        CleanupAllMedkitEffects()
    }
}

__CollectGameEventCallbacks(::L4CWI_Items)
::L4CWI_Core.RegisterSystem("Items", ::L4CWI_Items)
printl("[L4CWI] Items System loaded")
