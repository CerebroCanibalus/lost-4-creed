// ============================================================
// L4CWI — Firearms System v1.1
// Modificaciones a armas de fuego
// Fusión de: m60_stagger, sg_extradamage
// NOTA: awp_explosive migrado a special_firearms_system.nut
// ============================================================

::L4CWI_Firearms <- {
    CONFIG_PATH = "l4cwi_config/firearms.cfg"
    
    // === M60 STAGGER ===
    M60_STAGGER_CHANCE = 15
    M60_STAGGER_TARGETS = { [6] = true, [8] = true } // Charger=6, Tank=8
    
    // === SG552 ZOOM DAMAGE ===
    SG552_ZOOM_MULTIPLIER = 0.66
    
    function Init() {
        this._Dbg("Initializing firearms system")
        
        local defaults = {
            m60_stagger_chance = 15,
            sg552_zoom_multiplier = 0.66,
        }
        
        local cfg = ::L4CWI_Core.ParseConfig(CONFIG_PATH, defaults)
        M60_STAGGER_CHANCE = cfg.m60_stagger_chance
        SG552_ZOOM_MULTIPLIER = cfg.sg552_zoom_multiplier
        
        this._Dbg("Config loaded — M60 chance: " + M60_STAGGER_CHANCE + 
                  "%, SG552 mult: " + SG552_ZOOM_MULTIPLIER)
    }
    
    // ============================================================
    // M60 STAGGER + SG552 ZOOM DAMAGE (player_hurt)
    // ============================================================
    function OnGameEvent_player_hurt(params) {
        if (!("userid" in params) || !("attacker" in params)) return
        
        local special = GetPlayerFromUserID(params.userid)
        local surv = GetPlayerFromUserID(params.attacker)
        
        if (!special || !surv) return
        if (special.IsSurvivor() || !surv.IsSurvivor()) return
        
        // ——— M60 Stagger ———
        if ("weapon" in params && params.weapon == "rifle_m60") {
            local zType = special.GetZombieType()
            if (zType in M60_STAGGER_TARGETS) {
                if (RandomInt(1, 100) <= M60_STAGGER_CHANCE) {
                    special.Stagger(surv.GetOrigin())
                    this._Dbg("M60 stagger on zombie type " + zType)
                }
            }
        }
        
        // ——— SG552 Zoom Bonus ———
        if (!("dmg_health" in params) || !("type" in params)) return
        
        local dmgType = params.type
        if (dmgType == 131072 || (dmgType & 8) || (dmgType & 64)) return
        
        local activewep = surv.GetActiveWeapon()
        if (!activewep || activewep.GetClassname() != "weapon_rifle_sg552") return
        if (NetProps.GetPropInt(surv, "m_hZoomOwner") == -1) return
        
        special.TakeDamage(params.dmg_health * SG552_ZOOM_MULTIPLIER, 131072, surv)
        this._Dbg("SG552 zoom bonus damage applied")
    }
    
    // ============================================================
    // SG552 ZOOM DAMAGE (infected_hurt)
    // ============================================================
    function OnGameEvent_infected_hurt(params) {
        if (!("entityid" in params)) return
        if (!("amount" in params) || !("type" in params)) return
        
        local zambie = EntIndexToHScript(params.entityid)
        local surv = null
        if ("attacker" in params) surv = GetPlayerFromUserID(params.attacker)
        else if ("attackerentid" in params) surv = EntIndexToHScript(params.attackerentid)
        
        if (!zambie || !surv || !surv.IsSurvivor()) return
        
        local dmgType = params.type
        if (dmgType == 131072 || (dmgType & 8) || (dmgType & 64)) return
        
        local activewep = surv.GetActiveWeapon()
        if (!activewep || activewep.GetClassname() != "weapon_rifle_sg552") return
        if (NetProps.GetPropInt(surv, "m_hZoomOwner") == -1) return
        
        zambie.TakeDamage(params.amount * SG552_ZOOM_MULTIPLIER, 131072, surv)
    }
}

__CollectGameEventCallbacks(::L4CWI_Firearms)
::L4CWI_Core.RegisterSystem("Firearms", ::L4CWI_Firearms)
printl("[L4CWI] Firearms System v1.1 loaded")
