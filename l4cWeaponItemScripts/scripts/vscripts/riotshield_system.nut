// ============================================================
// L4CWI — Riot Shield System v1.0
// Escudo antidisturbios
// Fusión de: RiotShield_Henrietta_, okkg_riotshieldbuff
// ============================================================

::L4CWI_RiotShield <- {
    CONFIG_PATH = "l4cwi_config/riotshield.cfg"
    
    // === HENRIETTA DAMAGE REDUCTION ===
    REDUCTION_FRONT = 0.60
    REDUCTION_BEHIND = 1.3
    REDUCTION_DMG_TYPES = [8, 263168]
    
    // Incap damage by attacker type [easy, normal, hard, expert]
    INCAP_DAMAGE = {
        tank_claw = [24, 24, 33, 300],
        tank_rock = [24, 24, 33, 33],
        charger_claw = [5, 10, 15, 20],
        hunter_claw = [10, 10, 20, 40],
        jockey_claw = [5, 10, 15, 20],
        smoker_claw = [1, 10, 5, 20],
        spitter_claw = [1, 2, 5, 20],
        boomer_claw = [5, 10, 5, 20],
        zombie = [1, 2, 5, 20],
    }
    
    // === OKKG BLOCKING ===
    BLOCK_SOUNDS = [
        "weapons/riotshield/RiotShield_Block1.mp3",
        "weapons/riotshield/RiotShield_Block2.mp3",
        "weapons/riotshield/RiotShield_Block3.mp3",
        "weapons/riotshield/RiotShield_Block4.mp3",
        "weapons/riotshield/RiotShield_Block5.mp3",
    ]
    
    BLOCK_CHANCE = 15
    BLOCK_DAMAGE = 14
    BLOCK_SMOKER = true
    BLOCK_HUNTER = true
    BLOCK_JOCKEY = false
    BLOCK_CHARGER = false
    BLOCK_BOOMER = true
    BLOCK_TANK_ROCK = true
    BLOCK_ATTACKS = true
    BLOCK_ONLY_COMMONS = true
    BLOCK_COMPLEX = true
    BLOCK_SOUND = true
    
    RIOTSHIELD_MODEL = "models/weapons/melee/v_riotshield.mdl"
    
    function Init() {
        this._Dbg("Initializing riot shield system")
        
        local defaults = {
            reduction_front = 0.60,
            reduction_behind = 1.3,
            block_chance = 15,
            block_damage = 14,
            block_smoker = true,
            block_hunter = true,
            block_jockey = false,
            block_charger = false,
            block_boomer = true,
            block_tank_rock = true,
            block_attacks = true,
            block_only_commons = true,
            block_complex = true,
            block_sound = true,
        }
        
        local cfg = ::L4CWI_Core.ParseConfig(CONFIG_PATH, defaults)
        REDUCTION_FRONT = cfg.reduction_front
        REDUCTION_BEHIND = cfg.reduction_behind
        BLOCK_CHANCE = cfg.block_chance
        BLOCK_DAMAGE = cfg.block_damage
        BLOCK_SMOKER = cfg.block_smoker
        BLOCK_HUNTER = cfg.block_hunter
        BLOCK_JOCKEY = cfg.block_jockey
        BLOCK_CHARGER = cfg.block_charger
        BLOCK_BOOMER = cfg.block_boomer
        BLOCK_TANK_ROCK = cfg.block_tank_rock
        BLOCK_ATTACKS = cfg.block_attacks
        BLOCK_ONLY_COMMONS = cfg.block_only_commons
        BLOCK_COMPLEX = cfg.block_complex
        BLOCK_SOUND = cfg.block_sound
        
        foreach (snd in BLOCK_SOUNDS) {
            PrecacheSound(snd)
        }
        
        this._Dbg("Config loaded")
    }
    
    // ============================================================
    // HELPERS
    // ============================================================
    function HasRiotShield(player) {
        if (!player || !player.IsValid()) return false
        local wep = player.GetActiveWeapon()
        if (!wep || !wep.IsValid()) return false
        return wep.GetModelName() == RIOTSHIELD_MODEL
    }
    
    function IsFacingAttacker(victim, attacker) {
        if (!BLOCK_COMPLEX) return true
        if (!attacker || !attacker.IsValid()) return true
        
        local look = attacker.GetForwardVector()
        local vOrigin = victim.GetOrigin()
        local aOrigin = attacker.GetOrigin()
        return (vOrigin - aOrigin).Dot(look) >= 0.7
    }
    
    function PlayBlockSound(player) {
        if (!BLOCK_SOUND) return
        EmitAmbientSoundOn(BLOCK_SOUNDS[RandomInt(0, BLOCK_SOUNDS.len() - 1)], 1, 80, 100, player)
    }
    
    function GetDifficultyIndex() {
        local diff = Convars.GetStr("z_difficulty").tolower()
        if (diff == "easy") return 0
        if (diff == "hard") return 2
        if (diff == "impossible" || diff == "expert") return 3
        return 1 // normal
    }
    
    // ============================================================
    // HENRIETTA — Damage Reduction (player_hurt)
    // ============================================================
    function OnGameEvent_player_hurt(params) {
        if (!("userid" in params) || !("dmg_health" in params) || !("type" in params) || !("weapon" in params)) return
        
        local victim = GetPlayerFromUserID(params.userid)
        if (!victim || !victim.IsValid() || !victim.IsSurvivor()) return
        if (victim.IsIncapacitated() || victim.IsDominatedBySpecialInfected() || victim.IsImmobilized()) return
        if (!HasRiotShield(victim)) return
        
        local dmgType = params.type
        if (REDUCTION_DMG_TYPES.find(dmgType) != null) return
        
        local attacker = null
        if ("attackerentid" in params) {
            attacker = EntIndexToHScript(params.attackerentid)
        } else if ("attacker" in params) {
            attacker = GetPlayerFromUserID(params.attacker)
        }
        
        ApplyReduction(victim, attacker, params.dmg_health, params.weapon)
    }
    
    function ApplyReduction(victim, attacker, totalDmg, weapon) {
        local fov = Convars.GetClientConvarValue("fov_desired", victim.GetEntityIndex()).tointeger()
        local inFront = IsInFOV(victim, attacker, fov)
        
        local redFront = REDUCTION_FRONT > 1.0 ? 1.0 : (REDUCTION_FRONT < 0 ? 0 : REDUCTION_FRONT)
        local redBehind = REDUCTION_BEHIND > 2.0 ? 2.0 : (REDUCTION_BEHIND < 1.0 ? 1.0 : REDUCTION_BEHIND)
        
        local dmgFront = totalDmg * (1 - redFront)
        local dmgBehind = totalDmg * (1 - redBehind)
        
        local earlyHealth = victim.GetHealth()
        local earlyBuffer = NetProps.GetPropFloat(victim, "m_healthBuffer")
        
        local addHealth = 0
        local addBuffer = 0
        
        if (inFront) {
            addHealth = earlyHealth + dmgFront
            addBuffer = earlyBuffer + dmgFront
        } else {
            addHealth = earlyHealth + dmgBehind
            addBuffer = earlyBuffer + dmgBehind
        }
        
        local realHealth = earlyHealth - totalDmg
        local tempHealth = earlyBuffer - totalDmg
        
        if (realHealth >= 0 && tempHealth >= 0) {
            victim.SetHealth(addHealth.tointeger())
        } else if (realHealth <= 0 && tempHealth >= 0) {
            NetProps.SetPropFloat(victim, "m_healthBuffer", addBuffer)
        } else if (realHealth >= 0 && tempHealth <= 0) {
            victim.SetHealth(addHealth.tointeger())
        } else {
            if (tempHealth > 0) {
                NetProps.SetPropFloat(victim, "m_healthBuffer", addBuffer)
            } else {
                victim.SetHealth(addHealth.tointeger())
            }
        }
    }
    
    function IsInFOV(ent, target, fov) {
        if (!target || !target.IsValid()) return true
        
        local origin = ent.GetOrigin()
        local localVector = target.GetOrigin() - origin
        local forward = ent.GetForwardVector()
        forward.Norm()
        localVector.Norm()
        
        local dot = forward.Dot(localVector)
        return acos(dot) * 180 / 3.14159265 <= fov / 2
    }
    
    // ============================================================
    // HENRIETTA — Incap damage reduction
    // ============================================================
    function OnGameEvent_player_incapacitated_start(params) {
        if (!("userid" in params) || !("type" in params)) return
        
        local victim = GetPlayerFromUserID(params.userid)
        if (!victim || !victim.IsValid() || !victim.IsSurvivor()) return
        if (victim.IsDominatedBySpecialInfected() || victim.IsImmobilized()) return
        if (!HasRiotShield(victim)) return
        
        local dmgType = params.type
        if (REDUCTION_DMG_TYPES.find(dmgType) != null) return
        
        local attacker = null
        if ("attackerentid" in params) {
            attacker = EntIndexToHScript(params.attackerentid)
        } else if ("attacker" in params) {
            attacker = GetPlayerFromUserID(params.attacker)
        }
        
        local weapon = ("weapon" in params) ? params.weapon : ""
        local diffIdx = GetDifficultyIndex()
        
        local damage = 0
        if (attacker && attacker.GetClassname() == "infected") {
            damage = INCAP_DAMAGE.zombie[diffIdx]
        } else if (attacker && attacker.GetClassname() == "player") {
            if (weapon in INCAP_DAMAGE) {
                damage = INCAP_DAMAGE[weapon][diffIdx]
            }
        }
        
        if (damage > 0) {
            ApplyReduction(victim, attacker, damage, weapon)
        }
    }
    
    // ============================================================
    // OKKG — Attack Blocking (player_hurt)
    // ============================================================
    function OnGameEvent_player_hurt(params) {
        if (!BLOCK_ATTACKS) return
        if (RandomInt(1, 100) > BLOCK_CHANCE) return
        if (!("attackerentid" in params) || !("userid" in params) || !("type" in params)) return
        
        local attacker = EntIndexToHScript(params.attackerentid)
        local player = GetPlayerFromUserID(params.userid)
        if (!player || !player.IsValid() || !player.IsSurvivor()) return
        if (!attacker || !attacker.IsValid()) return
        if (!HasRiotShield(player)) return
        if (player.IsStaggering()) return
        if (params.type != 128) return // melee damage only
        
        local isCommon = (attacker.GetClassname() != "player")
        if (!isCommon && BLOCK_ONLY_COMMONS) return
        
        if (IsFacingAttacker(player, attacker)) {
            PlayBlockSound(player)
            player.SetHealth(player.GetHealth() + params.dmg_health)
            this._Dbg("Blocked attack from front")
        } else if (!isCommon && !BLOCK_COMPLEX) {
            PlayBlockSound(player)
            player.SetHealth(player.GetHealth() + (params.dmg_health / 2))
            this._Dbg("Blocked attack from back")
        }
    }
    
    // ============================================================
    // OKKG — Special Infected Blocking
    // ============================================================
    function OnGameEvent_tongue_grab(params) {
        if (!BLOCK_SMOKER) return
        local player = GetPlayerFromUserID(params.victim)
        local attacker = GetPlayerFromUserID(params.userid)
        if (!player || !attacker) return
        if (!HasRiotShield(player) || player.IsStaggering()) return
        if (!IsFacingAttacker(player, attacker)) return
        
        player.TakeDamage(BLOCK_DAMAGE, 0, attacker)
        PlayBlockSound(player)
        player.Stagger(attacker.GetOrigin())
        attacker.Stagger(player.GetOrigin())
        this._Dbg("Blocked smoker grab")
    }
    
    function OnGameEvent_jockey_ride(params) {
        if (!BLOCK_JOCKEY) return
        local player = GetPlayerFromUserID(params.victim)
        local attacker = GetPlayerFromUserID(params.userid)
        if (!player || !attacker) return
        if (!HasRiotShield(player) || player.IsStaggering()) return
        
        player.TakeDamage(BLOCK_DAMAGE, 0, attacker)
        PlayBlockSound(player)
        player.Stagger(attacker.GetOrigin())
        attacker.Stagger(player.GetOrigin())
        this._Dbg("Blocked jockey ride")
    }
    
    function OnGameEvent_lunge_pounce(params) {
        if (!BLOCK_HUNTER) return
        local player = GetPlayerFromUserID(params.victim)
        local attacker = GetPlayerFromUserID(params.userid)
        if (!player || !attacker) return
        if (!HasRiotShield(player) || player.IsStaggering()) return
        
        player.TakeDamage(BLOCK_DAMAGE, 0, attacker)
        PlayBlockSound(player)
        player.Stagger(attacker.GetOrigin())
        // 🔧 FIX: Removed attacker.Stagger() — staggering the hunter on pounce
        // caused it to immediately release the victim. The survivor stagger
        // alone is sufficient to break the pounce cinematic.
        this._Dbg("Blocked hunter pounce")
    }
    
    function OnGameEvent_charger_carry_start(params) {
        if (!BLOCK_CHARGER) return
        local player = GetPlayerFromUserID(params.victim)
        local attacker = GetPlayerFromUserID(params.userid)
        if (!player || !attacker) return
        if (!HasRiotShield(player) || player.IsStaggering()) return
        
        player.Stagger(attacker.GetOrigin())
        player.TakeDamage(15, 0, attacker)
        attacker.Stagger(player.GetOrigin())
        this._Dbg("Blocked charger carry")
    }
    
    function OnGameEvent_charger_impact(params) {
        if (!BLOCK_CHARGER) return
        local player = GetPlayerFromUserID(params.victim)
        local attacker = GetPlayerFromUserID(params.userid)
        if (!player || !attacker) return
        if (!HasRiotShield(player) || player.IsStaggering()) return
        
        player.Stagger(attacker.GetOrigin())
        player.TakeDamage(15, 0, attacker)
        attacker.Stagger(player.GetOrigin())
        this._Dbg("Blocked charger impact")
    }
}

__CollectGameEventCallbacks(::L4CWI_RiotShield)
::L4CWI_Core.RegisterSystem("RiotShield", ::L4CWI_RiotShield)
printl("[L4CWI] Riot Shield System loaded")
