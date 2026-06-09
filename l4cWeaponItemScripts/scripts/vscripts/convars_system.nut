// ============================================================
// L4CWI — Convars System v1.0
// Aplica convars de balance de armas y mecánicas
// Fusión de: glauncher, pain_pills, smg_headshot_wound, turnrate_shove
// ============================================================

::L4CWI_Convars <- {
    CONFIG_PATH = "l4cwi_config/convars.cfg"
    
    // Configurable features
    Settings = {
        grenade_launcher_damage = 1500,
        grenade_launcher_radius_kill = 140,
        pain_pills_decay_rate = 0.24,
        smg_headshot_wounds = true,
        shove_penalty_coop = 999999999,
        shove_penalty_vs = 999999999,
    }
    
    function Init() {
        this._Dbg("Initializing convars system")
        
        // Cargar config si existe (crea default si no)
        Settings = ::L4CWI_Core.ParseConfig(CONFIG_PATH, Settings)
        
        // === Grenade Launcher ===
        Convars.SetValue("grenadelauncher_velocity", 900)
        Convars.SetValue("grenadelauncher_radius_kill", Settings.grenade_launcher_radius_kill)
        Convars.SetValue("grenadelauncher_radius_stumble", 200)
        Convars.SetValue("grenadelauncher_damage", Settings.grenade_launcher_damage)
        Convars.SetValue("grenadelauncher_ff_scale", 0.06)
        Convars.SetValue("grenadelauncher_ff_scale_self", 0.18)
        this._Dbg("Grenade launcher convars applied")
        
        // === Pain Pills ===
        Convars.SetValue("pain_pills_decay_rate", Settings.pain_pills_decay_rate)
        this._Dbg("Pain pills decay rate: " + Settings.pain_pills_decay_rate)
        
        // === SMG Headshot Wounds ===
        if (Settings.smg_headshot_wounds) {
            Convars.SetValue("z_head_damage_causes_wounds", 1)
            this._Dbg("SMG headshot wounds enabled")
        }
        
        // === Turnrate / Shove penalties ===
        Convars.SetValue("mp_facefronttime", "3")
        Convars.SetValue("mp_feetmaxyawrate", "500")
        Convars.SetValue("mp_feetyawrate", "800")
        Convars.SetValue("mp_feetyawrate_max", "1000")
        Convars.SetValue("z_gun_swing_coop_max_penalty", Settings.shove_penalty_coop)
        Convars.SetValue("z_gun_swing_coop_min_penalty", Settings.shove_penalty_coop)
        Convars.SetValue("z_gun_swing_vs_max_penalty", Settings.shove_penalty_vs)
        Convars.SetValue("z_gun_swing_vs_min_penalty", Settings.shove_penalty_vs)
        this._Dbg("Turnrate and shove penalties applied")
    }
    
    function OnRoundStart(params) {
        // Re-aplicar convars cada round (algunos mods los resetean)
        Init()
    }
}

__CollectGameEventCallbacks(::L4CWI_Convars)
::L4CWI_Core.RegisterSystem("Convars", ::L4CWI_Convars)
printl("[L4CWI] Convars System loaded")
