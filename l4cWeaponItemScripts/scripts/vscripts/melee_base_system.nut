// ============================================================
// L4CWI — Melee Base System v1.0
// Mecánicas base de melee
// Fusión de: chch_realreload, chch_breakablemelees
// ============================================================

::L4CWI_MeleeBase <- {
    CONFIG_PATH = "l4cwi_config/melee_base.cfg"
    
    // === REAL RELOAD ===
    // Weapons that DON'T lose ammo on reload (shotguns + chainsaw)
    REALRELOAD_EXCLUDE = {
        weapon_autoshotgun = true,
        weapon_chainsaw = true,
        weapon_pumpshotgun = true,
        weapon_shotgun_chrome = true,
        weapon_shotgun_spas = true,
    }
    
    // === BREAKABLE MELEES ===
    MELEE_DURABILITY = {
        ["models/weapons/melee/v_fireaxe.mdl"] = 30,
        ["models/weapons/melee/v_frying_pan.mdl"] = 45,
        ["models/weapons/melee/v_machete.mdl"] = 40,
        ["models/weapons/melee/v_bat.mdl"] = 35,
        ["models/weapons/melee/v_crowbar.mdl"] = 20,
        ["models/weapons/melee/v_cricket_bat.mdl"] = 35,
        ["models/weapons/melee/v_tonfa.mdl"] = 30,
        ["models/weapons/melee/v_katana.mdl"] = 75,
        ["models/weapons/melee/v_electric_guitar.mdl"] = 50,
        ["models/v_models/v_knife_t.mdl"] = 20,
        ["models/weapons/melee/v_golfclub.mdl"] = 40,
        ["models/weapons/melee/v_pitchfork.mdl"] = 100,
        ["models/weapons/melee/v_shovel.mdl"] = 60,
    }
    MELEE_DEFAULT_DUR = 50
    
    // Settings
    BREAK_GIVE_PISTOL = true
    BREAK_TEXT_LINES = true
    
    // Tracked melees (entity -> durability)
    TrackedMelees = {}
    
    // Clip cache for real reload (weapon -> clip before fire)
    ClipCache = {}
    
    // Precached sounds
    BreakSounds = {
        axe = "weapons/axe/axe_break.wav",
        pan = "weapons/pan/pan_break.wav",
    }
    
    function Init() {
        this._Dbg("Initializing melee base system")
        
        local defaults = {
            break_give_pistol = true,
            break_text_lines = true,
        }
        
        local cfg = ::L4CWI_Core.ParseConfig(CONFIG_PATH, defaults)
        BREAK_GIVE_PISTOL = cfg.break_give_pistol
        BREAK_TEXT_LINES = cfg.break_text_lines
        
        PrecacheSound(BreakSounds.axe)
        PrecacheSound(BreakSounds.pan)
        
        this._Dbg("Config loaded")
    }
    
    // ============================================================
    // REAL RELOAD — weapon_reload / weapon_fire
    // ============================================================
    function OnGameEvent_weapon_reload(params) {
        if (!("userid" in params) || !params.userid) return
        
        local player = GetPlayerFromUserID(params.userid)
        if (!player || !player.IsValid() || !player.IsSurvivor()) return
        
        local wep = player.GetActiveWeapon()
        if (!wep || !wep.IsValid()) return
        
        local classname = wep.GetClassname()
        if (classname in REALRELOAD_EXCLUDE) return
        
        // Get current clip from cache (set by weapon_fire)
        if (!(wep in ClipCache)) return
        
        local clipLost = ClipCache[wep]
        if (clipLost <= 0) return
        
        local ammoType = NetProps.GetPropInt(wep, "m_iPrimaryAmmoType")
        local ammoLeft = NetProps.GetPropIntArray(player, "m_iAmmo", ammoType)
        
        if (ammoLeft - clipLost > 0) {
            NetProps.SetPropIntArray(player, "m_iAmmo", ammoLeft - clipLost, ammoType)
            this._Dbg("RealReload: " + classname + " lost " + clipLost + " ammo (" + (ammoLeft - clipLost) + " left)")
        }
    }
    
    function OnGameEvent_weapon_fire(params) {
        if (!("userid" in params) || !params.userid) return
        
        local player = GetPlayerFromUserID(params.userid)
        if (!player || !player.IsValid() || !player.IsSurvivor()) return
        
        local wep = player.GetActiveWeapon()
        if (!wep || !wep.IsValid()) return
        
        // Store current clip before firing (will be used on reload)
        ClipCache[wep] <- (wep.Clip1() - 1)
    }
    
    // ============================================================
    // BREAKABLE MELEES — item_pickup / infected_hurt / player_hurt
    // ============================================================
    function OnGameEvent_item_pickup(params) {
        if (!("userid" in params) || !("item" in params)) return
        if (params.item != "melee") return
        
        local player = GetPlayerFromUserID(params.userid)
        if (!player || !player.IsValid() || !player.IsSurvivor()) return
        
        // Get melee from slot 1
        local melee = NetProps.GetPropEntityArray(player, "m_hWeaponSlots", 1)
        if (!melee || !melee.IsValid()) return
        if (melee.GetClassname() == "weapon_chainsaw") return
        
        // Already tracked?
        if (melee in TrackedMelees) return
        
        // Initialize durability
        local model = melee.GetModelName()
        local durability = MELEE_DURABILITY.rawin(model) ? MELEE_DURABILITY[model] : MELEE_DEFAULT_DUR
        
        melee.SetClip1(durability)
        TrackedMelees[melee] <- durability
        
        this._Dbg("Tracked melee: " + model + " with durability " + durability)
    }
    
    function OnGameEvent_infected_hurt(params) {
        if (!("attacker" in params) || !("type" in params) || !("amount" in params)) return
        if (!params.attacker || params.amount < 1) return
        
        local player = GetPlayerFromUserID(params.attacker)
        if (!player || !player.IsValid() || !player.IsSurvivor()) return
        
        local wep = player.GetActiveWeapon()
        if (!wep || !wep.IsValid() || wep.GetClassname() != "weapon_melee") return
        
        // Check if it's melee damage type
        // Melee damage types in L4D2: -2145386492 (slash) or 2097280 (bludgeon)
        local dmgType = params.type
        if (dmgType != -2145386492 && dmgType != 2097280) return
        
        if (wep in TrackedMelees) {
            TakeDurability(wep, 1, player)
        }
    }
    
    function OnGameEvent_player_hurt(params) {
        if (!("attackerentid" in params) || !("userid" in params) || !("weapon" in params)) return
        if (!params.attackerentid) return
        
        local attacker = EntIndexToHScript(params.attackerentid)
        if (!attacker || !attacker.IsValid() || attacker.GetClassname() != "player") return
        if (!attacker.IsSurvivor()) return
        
        local victim = GetPlayerFromUserID(params.userid)
        if (!victim || !victim.IsValid() || victim.IsSurvivor()) return
        if (params.weapon != "melee" || params.dmg_health < 2 || params.dmg_health >= 3000) return
        
        // Get melee from slot 1
        local melee = NetProps.GetPropEntityArray(attacker, "m_hWeaponSlots", 1)
        if (!melee || !melee.IsValid()) return
        if (melee.GetClassname() != "weapon_melee") return
        
        if (!(melee in TrackedMelees)) return
        
        // SI take 1-2 durability
        local dmg = 1
        if (victim.GetZombieType() > 7) dmg = RandomInt(1, 2) // Tank/witch
        
        TakeDurability(melee, dmg, attacker)
    }
    
    function TakeDurability(wep, amount, owner) {
        if (!(wep in TrackedMelees)) return
        
        local current = wep.Clip1()
        local newDur = current - amount
        
        if (newDur <= -1) {
            BreakMelee(owner, wep)
            delete TrackedMelees[wep]
        } else {
            wep.SetClip1(newDur)
            TrackedMelees[wep] = newDur
            
            // Warning messages at 1/7 and 1/16 durability
            local maxDur = MELEE_DURABILITY.rawin(wep.GetModelName()) ? MELEE_DURABILITY[wep.GetModelName()] : MELEE_DEFAULT_DUR
            if (newDur == abs(maxDur / 7) && BREAK_TEXT_LINES) {
                ClientPrint(owner, 3, "\x01You feel your melee getting quite flimsy...")
            }
            if (newDur == abs(maxDur / 16) && BREAK_TEXT_LINES) {
                ClientPrint(owner, 3, "\x01You feel your melee about to break...")
            }
        }
    }
    
    function BreakMelee(owner, wep) {
        wep.Kill()
        
        if (BREAK_GIVE_PISTOL) {
            owner.GiveItem("weapon_pistol")
        }
        
        // Play break sound
        local model = wep.GetModelName()
        local sound = BreakSounds.axe
        if (model == "models/weapons/melee/v_frying_pan.mdl" || 
            model == "models/weapons/melee/v_crowbar.mdl" ||
            model == "models/weapons/melee/v_katana.mdl" ||
            model == "models/weapons/melee/v_electric_guitar.mdl" ||
            model == "models/weapons/melee/v_golfclub.mdl" ||
            model == "models/weapons/melee/v_shovel.mdl") {
            sound = BreakSounds.pan
        }
        
        EmitAmbientSoundOn(sound, 1.0, 65, 100, owner)
        this._Dbg("Melee broke: " + model)
    }
    
    function OnRoundEnd(params) {
        TrackedMelees = {}
        ClipCache = {}
    }
}

__CollectGameEventCallbacks(::L4CWI_MeleeBase)
::L4CWI_Core.RegisterSystem("MeleeBase", ::L4CWI_MeleeBase)
printl("[L4CWI] Melee Base System loaded")
