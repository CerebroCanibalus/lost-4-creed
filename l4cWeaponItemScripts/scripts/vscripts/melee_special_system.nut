// ============================================================
// L4CWI — Melee Special System v1.1
// Efectos especiales de melee
// Migrado a MaoLib.StatusEffects.DoT Subsystem (4 Jun 2026)
// NOTA: electric_axe.nut se mantiene como script independiente
// ============================================================

::L4CWI_MeleeSpecial <- {
    CONFIG_PATH = "l4cwi_config/melee_special.cfg"
    
    // === BLEED MELEE ===
    // Weapons that cause bleeding (model -> extra damage)
    BLEED_WEAPONS = {
        ["models/weapons/melee/v_fireaxe.mdl"] = 500,
        ["models/weapons/melee/w_fireaxe.mdl"] = 500,
        ["models/weapons/melee/v_crowbar.mdl"] = 500,
        ["models/weapons/melee/w_crowbar.mdl"] = 500,
        ["models/weapons/melee/v_machete.mdl"] = 500,
        ["models/weapons/melee/w_machete.mdl"] = 500,
        ["models/v_models/v_knife_t.mdl"] = 500,
        ["models/w_models/weapons/w_knife_t.mdl"] = 500,
        ["models/weapons/melee/v_pitchfork.mdl"] = 500,
        ["models/weapons/melee/w_pitchfork.mdl"] = 500,
        // Katana: bleed only, no extra damage
        ["models/weapons/melee/v_katana.mdl"] = 0,
        ["models/weapons/melee/w_katana.mdl"] = 0,
    }
    
    // DoT via MaoLib.StatusEffects — DPS + duración
    BleedDPS = 10.0        // 5 dmg/tick at 0.5s interval = 10 DPS
    BleedDuration = 10.0   // segundos
    
    function Init() {
        this._Dbg("Initializing melee special system")
        
        local defaults = {
            bleed_dps = 10.0,
            bleed_duration = 10.0,
        }
        
        local cfg = ::L4CWI_Core.ParseConfig(CONFIG_PATH, defaults)
        BleedDPS = cfg.bleed_dps
        BleedDuration = cfg.bleed_duration
        
        this._Dbg("Config loaded — bleed: " + BleedDPS + " DPS x " + BleedDuration + "s")
    }
    
    // ============================================================
    // BLEED — player_hurt / infected_hurt
    // ============================================================
    function OnGameEvent_player_hurt(params) {
        if (!("userid" in params) || !("attacker" in params) || !("dmg_health" in params) || !("type" in params)) return
        if (!params.userid || !params.attacker) return
        
        local special = GetPlayerFromUserID(params.userid)
        local surv = GetPlayerFromUserID(params.attacker)
        if (!special || !surv || special.IsSurvivor() || !surv.IsSurvivor()) return
        
        // Skip explosion/fire damage types
        local type = params.type
        if (type == 131072 || (type & 8) || (type & 64)) return
        
        local wep = surv.GetActiveWeapon()
        if (!wep || !wep.IsValid()) return
        
        local model = wep.GetModelName()
        if (!(model in BLEED_WEAPONS)) return
        
        // Apply extra damage
        local extraDmg = BLEED_WEAPONS[model]
        if (extraDmg > 0) {
            special.TakeDamage(extraDmg - params.dmg_health, 131072, surv)
        }
        
        // Apply bleed via DoT Subsystem — afecta SI (players no survivors) y bosses
        _ApplyMeleeBleed(special, surv)
    }
    
    function OnGameEvent_infected_hurt(params) {
        if (!("entityid" in params) || !("attacker" in params) || !("amount" in params) || !("type" in params)) return
        if (!params.entityid || !params.attacker) return
        
        local zambie = EntIndexToHScript(params.entityid)
        local surv = GetPlayerFromUserID(params.attacker)
        if (!zambie || !surv || !surv.IsSurvivor()) return
        
        // Skip explosion/fire damage types
        local type = params.type
        if (type == 131072 || (type & 8) || (type & 64)) return
        
        local wep = surv.GetActiveWeapon()
        if (!wep || !wep.IsValid()) return
        
        local model = wep.GetModelName()
        if (!(model in BLEED_WEAPONS)) return
        
        // Apply extra damage
        local extraDmg = BLEED_WEAPONS[model]
        if (extraDmg > 0) {
            zambie.TakeDamage(extraDmg - params.amount, 131072, surv)
        }
        
        // Apply bleed via DoT Subsystem — afecta commons + SI + bosses
        _ApplyMeleeBleed(zambie, surv)
    }
    
    // ============================================================
    // _ApplyMeleeBleed — Delega al DoT Subsystem de MaoLib
    // ============================================================
    // Target flags: SI + COMMON + BOSS (el melee sangra a todo bicho)
    function _ApplyMeleeBleed(victim, attacker) {
        if (!victim || !victim.IsValid()) return
        if (NetProps.GetPropInt(victim, "m_lifeState") != 0) return
        
        // Partícula de sangre inmediata
        local origin = victim.GetOrigin() + Vector(0, 0, 40)
        local angles = victim.GetAngles()
        local angleStr = angles.x + " " + angles.y + " " + angles.z
        
        local particle = SpawnEntityFromTable("info_particle_system", {
            origin = origin,
            angles = angleStr,
            effect_name = "blood_impact_headshot_01g",
            start_active = 1,
        })
        if (particle && particle.IsValid())
            DoEntFire("!self", "Kill", "", 0.5, null, particle)
        
        // Delegar al DoT Subsystem — sangra SI, commons y bosses
        local SE = ::MaoLib.StatusEffects
        SE.ApplyDoT(victim, "dot_bleed", BleedDPS, BleedDuration, attacker)
    }
    
    // ============================================================
    // CLEANUP — El DoT Subsystem maneja timers y expiración
    // ============================================================
    function OnRoundEnd(params) {
        // No es necesario limpiar ActiveBleeds — DoT Subsystem lo auto-gestiona
        this._Dbg("Round end — DoT cleanup handled by MaoLib")
    }
}

__CollectGameEventCallbacks(::L4CWI_MeleeSpecial)
::L4CWI_Core.RegisterSystem("MeleeSpecial", ::L4CWI_MeleeSpecial)
printl("[L4CWI] Melee Special System loaded")
