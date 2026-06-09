// ============================================================================
// system_combat.nut — Unified Combat System for L4C Core Survivor Gameplay
// ============================================================================
// Fusiona: l4c_combat_fx.nut + l4c_combat_util.nut + survivor_friendly_shove.nut
// Tabla raíz: ::SystemCombat
// Sub-tablas: FX, Util, FriendlyShove, Events
// ============================================================================

::SystemCombat <- { Config = {}, State = {} }

// ============================================================================
// FX — Shove Gib, Stagger Fix, Item Ping, Healing FX
// ============================================================================

::SystemCombat.FX <- {
    Debug = 1
    HUD_PRINTTALK = 3      // ClientPrint chat channel (nativo L4D2)

    function Dbg(msg) {
        if (Debug) printl("[SystemCombat.FX][DEBUG] " + msg)
    }

    function DbgWarn(msg) {
        printl("[SystemCombat.FX][WARN] " + msg)
    }

    // ========================================================================
    // SHOVE GIB — head explosions on goomba stomp
    // ========================================================================

    BadGenders = [14, 15, 17]

    function OnInfectedHurt(params)
    {
        Dbg("ENTER OnInfectedHurt")

        if (!("entityid" in params) || !("attacker" in params) ||
            !("type" in params) || !("amount" in params))
        {
            DbgWarn("ABORT: missing params")
            return
        }

        if (!params.entityid || !params.attacker)
        {
            DbgWarn("ABORT: null entityid or attacker")
            return
        }

        local common = EntIndexToHScript(params.entityid)
        local surv = GetPlayerFromUserID(params.attacker)

        if (!common || !surv || !surv.IsSurvivor())
        {
            DbgWarn("ABORT: invalid common or survivor")
            return
        }

        if (surv.GetButtonMask() == (surv.GetButtonMask() | 4))
        {
            Dbg("SKIP: player is crouching")
            return
        }

        local gender = NetProps.GetPropInt(common, "m_Gender")

        if (params.type == 128 && params.amount == 51 &&
            (common.GetHealth() - 51) <= 0)
        {
            if (BadGenders.find(gender) != null)
            {
                Dbg("SKIP: bad gender " + gender)
                return
            }

            local wound1 = NetProps.GetPropInt(common, "m_iRequestedWound1")
            local wound2 = NetProps.GetPropInt(common, "m_iRequestedWound2")

            if (wound1 == -1)
            {
                local gib = (gender == 11) ? 0 : RandomInt(6, 8)
                NetProps.SetPropInt(common, "m_iRequestedWound1", gib)
                Dbg("Gib wound1 set to " + gib)
            }
            else if (wound2 == -1)
            {
                local gib = (gender == 11) ? 0 : RandomInt(6, 8)
                NetProps.SetPropInt(common, "m_iRequestedWound2", gib)
                Dbg("Gib wound2 set to " + gib)
            }
        }

        Dbg("EXIT OnInfectedHurt")
    }

    // ========================================================================
    // STAGGER CANCEL FIX
    // ========================================================================

    function RFFallStagger(caller_ent, activator_ent)
    {
        if (!caller_ent || !caller_ent.IsValid()) return

        caller_ent.ValidateScriptScope()
        local scoop = caller_ent.GetScriptScope()

        local lifeState = NetProps.GetPropInt(caller_ent, "m_lifeState")
        if (lifeState == 1 || caller_ent.IsHangingFromLedge() || scoop.StagStage == 3)
        {
            scoop.StagStage = 3
        }
        else if (NetProps.GetPropFloatArray(caller_ent, "m_staggerTimer", 1) > -1.0)
        {
            if (scoop.StagStage)
                scoop.StagStage = 0
            DoEntFire("worldspawn", "RunScriptCode",
                "::SystemCombat.FX.RFFallStagger(caller, activator)", 0.03, activator_ent, caller_ent)
        }
        else if (!(NetProps.GetPropInt(caller_ent, "m_fFlags") & (1 << 0)))
        {
            if (!scoop.StagStage)
                scoop.StagStage = 1
            DoEntFire("worldspawn", "RunScriptCode",
                "::SystemCombat.FX.RFFallStagger(caller, activator)", 0.03, activator_ent, caller_ent)
        }
        else if (scoop.StagStage == 1)
        {
            scoop.StagStage = 0
            if (activator_ent != null)
                caller_ent.Stagger(activator_ent.GetOrigin())
            else
            {
                local closest = Director.GetClosestSurvivor(caller_ent.GetOrigin(), true, true)
                if (closest) caller_ent.Stagger(closest.GetOrigin())
            }
            DoEntFire("worldspawn", "RunScriptCode",
                "::SystemCombat.FX.RFFallStagger(caller, activator)", 0.03, activator_ent, caller_ent)
        }
        else
        {
            scoop.StagStage = 3
        }
    }

    function StagLoopFix(caller_ent)
    {
        if (!caller_ent || !caller_ent.IsValid()) return

        caller_ent.ValidateScriptScope()
        local scoop = caller_ent.GetScriptScope()
        scoop.StagCounter2++

        if (scoop.StagCounter2 == scoop.StagCounter)
        {
            scoop.StagStage = 3
            scoop.StagCounter = 0
            scoop.StagCounter2 = 0
        }
    }

    function OnPlayerSpawn(event)
    {
        local p = GetPlayerFromUserID(event.userid)
        if (!p) return
        p.ValidateScriptScope()
        local scoop = p.GetScriptScope()
        scoop.StagStage <- 3
        scoop.StagCounter <- 0
        scoop.StagCounter2 <- 0
    }

    function OnPlayerShoved(event)
    {
        if (!("attacker" in event)) return

        local p = GetPlayerFromUserID(event.userid)
        if (!p) return
        if (p.GetZombieType() < 6)
        {
            p.ValidateScriptScope()
            local scoop = p.GetScriptScope()
            if (scoop.StagStage == 3)
            {
                scoop.StagStage = 0
                scoop.StagCounter++
                DoEntFire("worldspawn", "RunScriptCode",
                    "::SystemCombat.FX.RFFallStagger(caller, activator)", 0.03,
                    GetPlayerFromUserID(event.attacker), p)
                DoEntFire("worldspawn", "RunScriptCode",
                    "::SystemCombat.FX.StagLoopFix(caller)",
                    Convars.GetFloat("z_max_stagger_duration"), p, p)
            }
        }
    }

    function OnPlayerHurt(event)
    {
        local p = GetPlayerFromUserID(event.userid)
        if (!p) return

        // === STAGGER FIX ===
        if (NetProps.GetPropFloatArray(p, "m_staggerTimer", 1) > -1.0)
        {
            p.ValidateScriptScope()
            local scoop = p.GetScriptScope()
            // Lazy init: StagStage/StagCounter may not exist on first stagger
            if (!scoop.rawin("StagStage")) scoop.StagStage <- 0
            if (!scoop.rawin("StagCounter")) scoop.StagCounter <- 0
            if (scoop.StagStage == 3)
            {
                scoop.StagStage = 0
                scoop.StagCounter++
                DoEntFire("worldspawn", "RunScriptCode",
                    "::SystemCombat.FX.StagLoopFix(caller)",
                    Convars.GetFloat("z_max_stagger_duration"), p, p)
                if ("attacker" in event)
                    DoEntFire("worldspawn", "RunScriptCode",
                        "::SystemCombat.FX.RFFallStagger(caller, activator)", 0.03,
                        GetPlayerFromUserID(event.attacker), p)
                else
                    DoEntFire("worldspawn", "RunScriptCode",
                        "::SystemCombat.FX.RFFallStagger(caller, activator)", 0.03, p, p)
            }
        }

        // === LOW HEALTH VISUAL CUE (LHVC) ===
        if (p.IsSurvivor())
        {
            local is_incapped = p.IsIncapacitated()
            // 🔧 FIX: attackerentid does not exist in player_hurt (only in infected_hurt).
            // null != 0 is always true in Squirrel, so the guard was always passing.
            // Just check health directly — attacker type doesn't matter for LHVC.
            local health = (p.GetHealth() + p.GetHealthBuffer()).tointeger()
            local threshold = is_incapped ? 72 : 24

            if (health <= threshold)
                {
                    if (!ResponseCriteria.HasCriterion(p, "lhvc_fading"))
                    {
                        p.SetContext("lhvc_fading", "1", 5)
                        DoRedFade(p)
                    }
                }
        }
    }

    function OnBoomerExploded(event)
    {
        local p = null
        while (p = Entities.FindByClassname(p, "player"))
        {
            if (p != null && NetProps.GetPropFloatArray(p, "m_staggerTimer", 1) > -1.0)
            {
                p.ValidateScriptScope()
                local scoop = p.GetScriptScope()
                if (scoop.StagStage == 3)
                {
                    scoop.StagStage = 0
                    scoop.StagCounter++
                    DoEntFire("worldspawn", "RunScriptCode",
                        "::SystemCombat.FX.RFFallStagger(caller, activator)", 0.03,
                        GetPlayerFromUserID(event.userid), p)
                    DoEntFire("worldspawn", "RunScriptCode",
                        "::SystemCombat.FX.StagLoopFix(caller)",
                        Convars.GetFloat("z_max_stagger_duration"), p, p)
                }
            }
        }
    }

    function OnChargerChargeEnd(event)
    {
        local charga = GetPlayerFromUserID(event.userid)
        if (!charga) return
        if (NetProps.GetPropFloatArray(charga, "m_staggerTimer", 1) > -1.0)
        {
            local p = null
            while (p = Entities.FindByClassnameWithin(p, "player", charga.GetOrigin(), 110.0))
            {
                if (p != null && p != charga)
                {
                    p.ValidateScriptScope()
                    local scoop = p.GetScriptScope()
                    if (scoop.StagStage == 3)
                    {
                        scoop.StagStage = 0
                        scoop.StagCounter++
                        DoEntFire("worldspawn", "RunScriptCode",
                            "::SystemCombat.FX.RFFallStagger(caller, activator)", 0.03, charga, p)
                        DoEntFire("worldspawn", "RunScriptCode",
                            "::SystemCombat.FX.StagLoopFix(caller)",
                            Convars.GetFloat("z_max_stagger_duration"), p, p)
                    }
                }
            }
        }
    }

    // ========================================================================
    // ITEM PING
    // ========================================================================

    GlowColor = 65025

    function ItemHighlight(ent)
    {
        NetProps.SetPropInt(ent, "m_Glow.m_iGlowType", 3)
        NetProps.SetPropInt(ent, "m_Glow.m_glowColorOverride", GlowColor)
        NetProps.SetPropInt(ent, "m_Glow.m_nGlowRange", 2000)
    }

    function ItemLowlight(ent)
    {
        NetProps.SetPropInt(ent, "m_Glow.m_iGlowType", 0)
        NetProps.SetPropInt(ent, "m_Glow.m_glowColorOverride", 0)
        NetProps.SetPropInt(ent, "m_Glow.m_nGlowRange", 0)
    }

    function OnPlayerUse(event)
    {
        local player = GetPlayerFromUserID(event.userid)
        if (!player) return

        local origin = player.GetOrigin()
        local ent1 = EntIndexToHScript(event.targetid)
        if (!ent1) return

        local ent3 = ent1.GetClassname()
        local ent4 = null

        while (ent4 = Entities.FindByClassnameWithin(ent4, ent3, origin, 50))
        {
            if (NetProps.GetPropInt(ent4, "m_Glow.m_glowColorOverride") == GlowColor)
                ItemLowlight(ent4)
        }

        if (NetProps.GetPropInt(ent1, "m_Glow.m_glowColorOverride") == GlowColor)
        {
            ItemLowlight(ent1)
            return
        }
    }

    ItemNames = {
        ["models/props/terror/ammo_stack.mdl"]                  = "Ammo",
        ["models/props_unique/spawn_apartment/coffeeammo.mdl"]  = "Ammo",
        ["models/w_models/weapons/w_pistol_B.mdl"]              = "Pistol",
        ["models/w_models/weapons/w_pistol_A.mdl"]              = "Pistol",
        ["models/w_models/weapons/50cal.mdl"]                   = "Mounted Gun",
        ["models/w_models/weapons/w_minigun.mdl"]               = "Minigun",
        ["models/w_models/weapons/w_sniper_military.mdl"]       = "Military Sniper",
        ["models/w_models/weapons/w_rifle_m16a2.mdl"]           = "Rifle",
        ["models/w_models/weapons/w_autoshot_m4super.mdl"]      = "Autoshotgun",
        ["models/w_models/weapons/w_shotgun_spas.mdl"]          = "Spas Shotgun",
        ["models/w_models/weapons/w_smg_uzi.mdl"]               = "SMG",
        ["models/w_models/weapons/w_smg_a.mdl"]                 = "Silenced SMG",
        ["models/w_models/weapons/w_smg_mp5.mdl"]               = "MP5",
        ["models/w_models/weapons/w_shotgun.mdl"]               = "Pump Shotgun",
        ["models/w_models/weapons/w_pumpshotgun_A.mdl"]         = "Chrome Shotgun",
        ["models/w_models/weapons/w_desert_rifle.mdl"]          = "Desert Rifle",
        ["models/w_models/weapons/w_desert_eagle.mdl"]          = "Magnum",
        ["models/w_models/weapons/w_sniper_mini14.mdl"]         = "Hunting Rifle",
        ["models/w_models/weapons/w_sniper_scout.mdl"]          = "Scout",
        ["models/w_models/weapons/w_sniper_awp.mdl"]            = "AWP",
        ["models/w_models/weapons/w_rifle_sg552.mdl"]           = "SG552",
        ["models/w_models/weapons/w_rifle_ak47.mdl"]            = "AK47",
        ["models/w_models/weapons/w_m60.mdl"]                   = "M60",
        ["models/w_models/weapons/w_grenade_launcher.mdl"]      = "Grenade Launcher",
        ["models/w_models/weapons/w_eq_pipebomb.mdl"]           = "Pipe Bomb",
        ["models/w_models/weapons/w_eq_molotov.mdl"]            = "Molotov",
        ["models/w_models/weapons/w_eq_bile_flask.mdl"]         = "Bile Bomb",
        ["models/w_models/weapons/w_eq_defibrillator.mdl"]      = "Defibrillator",
        ["models/w_models/weapons/w_eq_Medkit.mdl"]             = "Medkit",
        ["models/props_interiors/medicalcabinet02.mdl"]         = "First Aid Cabinet",
        ["models/w_models/weapons/w_eq_adrenaline.mdl"]         = "Adrenaline",
        ["models/w_models/weapons/w_eq_painpills.mdl"]          = "Pills",
        ["models/props_junk/gascan001a.mdl"]                    = "Gas Can",
        ["models/props_junk/explosive_box001.mdl"]              = "Fireworks",
        ["models/props_junk/propanecanister001a.mdl"]           = "Propane Tank",
        ["models/w_models/weapons/w_eq_explosive_ammopack.mdl"] = "Explosive Ammo",
        ["models/props/terror/exploding_ammo.mdl"]              = "Explosive Ammo",
        ["models/w_models/weapons/w_eq_incendiary_ammopack.mdl"]= "Incendiary Ammo",
        ["models/props/terror/incendiary_ammo.mdl"]             = "Incendiary Ammo",
        ["models/w_models/Weapons/w_laser_sights.mdl"]          = "Laser Sights",
        ["models/w_models/weapons/w_knife_t.mdl"]               = "Knife",
        ["models/weapons/melee/w_machete.mdl"]                  = "Machete",
        ["models/weapons/melee/w_fireaxe.mdl"]                  = "Fireaxe",
        ["models/weapons/melee/w_shovel.mdl"]                   = "Shovel",
        ["models/weapons/melee/w_golfclub.mdl"]                 = "Golf Club",
        ["models/weapons/melee/w_bat.mdl"]                      = "Baseball Bat",
        ["models/weapons/melee/w_chainsaw.mdl"]                 = "Chainsaw",
        ["models/weapons/melee/w_cricket_bat.mdl"]              = "Cricket Bat",
        ["models/weapons/melee/w_crowbar.mdl"]                  = "Crowbar",
        ["models/weapons/melee/w_electric_guitar.mdl"]          = "Guitar",
        ["models/weapons/melee/w_frying_pan.mdl"]               = "Frying Pan",
        ["models/weapons/melee/w_katana.mdl"]                   = "Katana",
        ["models/weapons/melee/w_tonfa.mdl"]                    = "Nightstick",
        ["models/weapons/melee/w_pitchfork.mdl"]                = "Pitchfork",
        ["models/props_equipment/oxygentank01.mdl"]             = "Oxygen Tank",
        ["models/w_models/weapons/w_cola.mdl"]                  = "Cola",
        ["models/props_junk/gnome.mdl"]                         = "Gnome",
    }

    function OnEntityShoved(event)
    {
        local player = GetPlayerFromUserID(event.attacker)
        if (!player || IsPlayerABot(player) || !("entityid" in event))
            return

        local flags = player.GetButtonMask()
        if (!(flags & (1 << 17)))
            return

        local ent = EntIndexToHScript(event.entityid)
        if (!ent) return

        local model = ent.GetModelName()

        if (model in ItemNames)
        {
            ClientPrint(null, HUD_PRINTTALK,
                "\x03" + GetCharacterDisplayName(player) + ": " +
                ItemNames[model] + " here!")
        }

        if (NetProps.GetPropInt(ent, "m_Glow.m_glowColorOverride") != GlowColor)
            ItemHighlight(ent)
        else
            ItemLowlight(ent)
    }

    // ========================================================================
    // HEALING FX
    // ========================================================================

    function DoGreenFade(player)
    {
        if (!IsPlayerABot(player))
            ScreenFade(player, 0, 255, 0, 35, 0.5, 0, 1)
    }

    function DoBlueFade(player)
    {
        if (!IsPlayerABot(player))
            ScreenFade(player, 0, 0, 255, 35, 0.5, 0, 1)
    }

    function DoRedFade(player)
    {
        if (IsPlayerABot(player)) return

        local ent_name = "lhvc_fade_" + player.GetEntityIndex()

        SpawnEntityGroupFromTable({
            f = {
                classname = "env_fade",
                targetname = ent_name,
                rendercolor = "255 0 0",
                renderamt = 80,
                duration = 5,
                holdtime = 0,
                spawnflags = 5,
            }
        })

        EntFire(ent_name, "Fade", "!activator", 0, player)
        EntFire(ent_name, "Kill", "", 5, null)
    }

    function OnPillsUsed(params)
    {
        local player = null
        if ("subject" in params)
            player = GetPlayerFromUserID(params.subject)
        else if ("userid" in params)
            player = GetPlayerFromUserID(params.userid)

        if (player)
        {
            DoGreenFade(player)
            DoBlueFade(player)
        }
    }

    function OnAdrenalineUsed(params)
    {
        if (!("userid" in params)) return
        local player = GetPlayerFromUserID(params.userid)
        if (player)
        {
            DoGreenFade(player)
            DoBlueFade(player)
        }
    }

    function OnHealSuccess(params)
    {
        if (!("subject" in params)) return
        local player = GetPlayerFromUserID(params.subject)
        if (player)
        {
            DoGreenFade(player)
            DoBlueFade(player)
        }
    }

    function OnReviveSuccess(params)
    {
        if (!("userid" in params) || !("subject" in params)) return

        if ("QUICK_REVIVE" in getroottable())
        {
            local rescuer = GetPlayerFromUserID(params.userid)
            local subject = GetPlayerFromUserID(params.subject)
            if (rescuer && subject && rescuer.GetContext("QR_context_name") == "true")
            {
                DoGreenFade(subject)
                DoBlueFade(subject)
            }
        }
    }
}

// ============================================================================
// Util — Carry FF Reduction, Grab Warnings, GetSurvivorName
// ============================================================================

::SystemCombat.Util <- {
    Debug = 1

    function Dbg(msg) {
        if (Debug) printl("[SystemCombat.Util][DEBUG] " + msg)
    }

    function DbgWarn(msg) {
        printl("[SystemCombat.Util][WARN] " + msg)
    }

    // ========================================================================
    // SURVIVOR NAME LOOKUP
    // ========================================================================

    function GetSurvivorName(player)
    {
        if (!player || !player.IsValid()) return "Unknown"

        local model = player.GetModelName()
        switch (model)
        {
            case "models/survivors/survivor_gambler.mdl":     return "Nick"
            case "models/survivors/survivor_producer.mdl":    return "Rochelle"
            case "models/survivors/survivor_coach.mdl":       return "Coach"
            case "models/survivors/survivor_mechanic.mdl":    return "Ellis"
            case "models/survivors/survivor_namvet.mdl":      return "Bill"
            case "models/survivors/survivor_teenangst.mdl":   return "Zoey"
            case "models/survivors/survivor_biker.mdl":       return "Francis"
            case "models/survivors/survivor_manager.mdl":     return "Louis"
            default:                                          return "Survivor"
        }
    }

    // ========================================================================
    // CARRY FF
    // ========================================================================

    CarriedSurvivors = {}

    function OnChargerCarryStart(params)
    {
        Dbg("ENTER charger_carry_start")
        if (!("victim" in params)) {
            DbgWarn("ABORT: no victim in params")
            return
        }

        local v = GetPlayerFromUserID(params.victim)
        if (v && v.IsSurvivor()) {
            CarriedSurvivors[v.GetEntityIndex()] <- true
            Dbg("Marked survivor " + v.GetEntityIndex() + " as carried")
        }
        Dbg("EXIT charger_carry_start")
    }

    function OnPlayerHurt(params)
    {
        Dbg("ENTER Util.OnPlayerHurt")

        if (!("userid" in params) || !("attacker" in params) || !("dmg_health" in params)) {
            DbgWarn("ABORT: missing params")
            return
        }

        local v = GetPlayerFromUserID(params.userid)
        local a = GetPlayerFromUserID(params.attacker)

        if (!v || !a) {
            Dbg("ABORT: victim or attacker null")
            return
        }
        if (!v.IsSurvivor() || !a.IsSurvivor()) {
            Dbg("ABORT: not survivor vs survivor")
            return
        }

        local idx = v.GetEntityIndex()
        if (idx in CarriedSurvivors) {
            v.SetHealth(v.GetHealth() + params.dmg_health)
            Dbg("FF nullified on carried survivor " + idx + " — dmg: " + params.dmg_health)
        }

        Dbg("EXIT Util.OnPlayerHurt")
    }

    // ========================================================================
    // GRAB WARNING
    // ========================================================================

    HintEnt = null

    function PrecacheSounds()
    {
        Entities.First().PrecacheScriptSound("Survivor.PlaytestStart")
        Dbg("Precached Survivor.PlaytestStart")
    }

    function SpawnHint(message, hintName)
    {
        local survivor = Director.GetRandomSurvivor()
        if (!survivor) {
            DbgWarn("No survivor found for hint spawn")
            return hintName
        }

        local origin = survivor.GetOrigin()
        ::SystemCombat.Util.HintEnt = SpawnEntityFromTable("env_instructor_hint", {
            targetname          = hintName,
            hint_static         = 1,
            hint_caption        = message,
            hint_color          = "255 255 255",
            hint_forcecaption   = 1,
            hint_icon_onscreen  = "icon_alert_red",
            hint_icon_offscreen = "icon_alert_red",
            hint_nooffscreen    = 0,
            hint_timeout        = 5,
            origin              = origin
        })
        return hintName
    }

    function ShowHintToAll(targetName)
    {
        local ent = null
        while (ent = Entities.FindByClassname(ent, "player")) {
            if (ent.IsValid() && ent.IsSurvivor()) {
                DoEntFire(targetName, "ShowHint", "", 0.0, ent, ent)
                EmitSoundOnClient("Survivor.PlaytestStart", ent)
            }
        }
    }

    function AlertAll(message, hintName)
    {
        local target = SpawnHint(message, hintName)
        ShowHintToAll(target)
        Dbg("Alert: " + message)
    }

    function OnChokeStart(params)
    {
        if (!("victim" in params)) return
        local victim = GetPlayerFromUserID(params.victim)
        if (!victim || !victim.IsSurvivor()) return

        AlertAll(
            "Warning: A Smoker Is Choking " + GetSurvivorName(victim) + "!",
            "TongueGrab_Hint_ent")
    }

    function OnLungePounce(params)
    {
        if (!("victim" in params)) return
        local victim = GetPlayerFromUserID(params.victim)
        if (!victim || !victim.IsSurvivor()) return

        AlertAll(
            "Warning: A Hunter Pounced On " + GetSurvivorName(victim) + "!",
            "HunterPounce_Hint_ent")
    }

    function OnJockeyRide(params)
    {
        if (!("victim" in params)) return
        local victim = GetPlayerFromUserID(params.victim)
        if (!victim || !victim.IsSurvivor()) return

        AlertAll(
            "Warning: A Jockey Is Riding " + GetSurvivorName(victim) + "!",
            "JockeyRide_Hint_ent")
    }

    function OnChargerCarryEnd(params)
    {
        Dbg("ENTER charger_carry_end")

        if (!("victim" in params)) {
            DbgWarn("ABORT: no victim in params")
            return
        }

        local victim = GetPlayerFromUserID(params.victim)
        if (!victim || !victim.IsSurvivor()) {
            DbgWarn("ABORT: victim null or not survivor")
            return
        }

        local idx = victim.GetEntityIndex()
        if (idx in CarriedSurvivors) {
            delete CarriedSurvivors[idx]
            Dbg("Unmarked survivor " + idx)
        }

        AlertAll(
            "Warning: A Charger Is Pummeling " + GetSurvivorName(victim) + "!",
            "ChargerPummel_Hint_ent")

        Dbg("EXIT charger_carry_end")
    }

    function OnPlayerNowIt(params)
    {
        if (!("userid" in params)) return
        local victim = GetPlayerFromUserID(params.userid)
        if (!victim || !victim.IsSurvivor()) return

        AlertAll(
            "Warning: " + GetSurvivorName(victim) + " Is Blinded!",
            "PlayerBlind_Hint_ent")
    }

    function OnRoundEnd(params)
    {
        Dbg("Cleanup on round end")
        CarriedSurvivors = {}
    }
}

// ============================================================================
// FriendlyShove — Survivor→Survivor Shove, Physics Push, Ammo/Item Sharing, Bot Thief
// ============================================================================

::SystemCombat.FriendlyShove <- {
    Enabled = 1
    Debug = 1
    PushForce = 200.0
    UpForce = 120.0
    CooldownSeconds = 1.5
    AmmoConfigPath = "friendly_shove_ammo_types.txt"

    AmmoTypes = {
        weapon_autoshotgun = 6
        weapon_hunting_rifle = 7
        weapon_grenade_launcher = 1
        weapon_pistol_magnum = 0
        weapon_pistol = 0
        weapon_pumpshotgun = 3
        weapon_rifle_ak47 = 5
        weapon_rifle_desert = 5
        weapon_rifle_m60 = 2
        weapon_rifle_sg552 = 5
        weapon_rifle = 5
        weapon_shotgun_chrome = 3
        weapon_shotgun_spas = 6
        weapon_smg_mp5 = 4
        weapon_smg_silenced = 4
        weapon_smg = 4
        weapon_sniper_awp = 8
        weapon_sniper_military = 8
        weapon_sniper_scout = 8
    }

    Cooldowns = {}

    function Dbg(msg)
    {
        if (Debug)
            printl("[SystemCombat.FriendlyShove][DEBUG] " + msg)
    }

    function DbgWarn(msg)
    {
        printl("[SystemCombat.FriendlyShove][WARN] " + msg)
    }

    function Init()
    {
        printl("[SystemCombat.FriendlyShove] ==========================================")
        printl("[SystemCombat.FriendlyShove] Init() called")
        printl("[SystemCombat.FriendlyShove] Enabled=" + Enabled + " Debug=" + Debug)
        printl("[SystemCombat.FriendlyShove] PushForce=" + PushForce + " UpForce=" + UpForce)
        printl("[SystemCombat.FriendlyShove] CooldownSeconds=" + CooldownSeconds)
        printl("[SystemCombat.FriendlyShove] ==========================================")

        GenerateAmmoConfigIfMissing()
        LoadAmmoConfig()
        StartAvoidanceLoop()

        printl("[SystemCombat.FriendlyShove] Init() complete.")
    }

    function StartAvoidanceLoop()
    {
        if (!Enabled)
        {
            Dbg("StartAvoidanceLoop: Enabled=0, skipping")
            return
        }

        if (MaoLib.IsTimerActive("syscombat_avoidance"))
            MaoLib.RemoveTimer("syscombat_avoidance")

        MaoLib.AddTimer("syscombat_avoidance", 10.0, function() {
            ::SystemCombat.FriendlyShove.AvoidanceLoopTick()
        })
    }

    function AvoidanceLoopTick()
    {
        if (!Enabled)
            return

        local flTime = Time()
        local forced = 0

        foreach (survivor in MaoLib.YieldSurvivors())
        {
            if (!MaoLib.IsAlivePlayer(survivor))
                continue

            local flPropTime = NetProps.GetPropFloatArray(survivor, "m_noAvoidanceTimer", 1)

            if (flPropTime < flTime - 2.0)
                continue

            NetProps.SetPropFloatArray(survivor, "m_noAvoidanceTimer", flTime - 2.0, 1)
            forced++
        }

        if (forced > 0)
            Dbg("AvoidanceLoopTick: forced " + forced + " survivor(s)")
    }

    function OnRoundStart(params)
    {
        printl("[SystemCombat.FriendlyShove] OnRoundStart() called")
        Cooldowns = {}
        StartAvoidanceLoop()
    }

    function OnPlayerShoved(params)
    {
        printl("[SystemCombat.FriendlyShove] ==========================================")
        printl("[SystemCombat.FriendlyShove] OnPlayerShoved() FIRED!")

        if (!Enabled)
        {
            printl("[SystemCombat.FriendlyShove] ABORT: Enabled=0")
            return
        }

        Dbg("params keys: userid=" + ("userid" in params ? params.userid : "MISSING")
            + " attacker=" + ("attacker" in params ? params.attacker : "MISSING"))

        if (!("userid" in params) || !("attacker" in params))
        {
            DbgWarn("ABORT: missing userid or attacker in params")
            return
        }

        local victim = GetPlayerFromUserID(params.userid)
        local attacker = GetPlayerFromUserID(params.attacker)

        if (!victim || !attacker || !victim.IsValid() || !attacker.IsValid())
        {
            DbgWarn("ABORT: victim or attacker null/invalid")
            return
        }

        Dbg("victim=" + victim.GetPlayerName() + " attacker=" + attacker.GetPlayerName())

        if (!attacker.IsSurvivor())
        {
            DbgWarn("ABORT: attacker not survivor")
            return
        }
        if (victim.IsImmobilized() || victim.IsDominatedBySpecialInfected())
        {
            DbgWarn("ABORT: victim immobilized")
            return
        }

        local now = Time()
        local attackerIdx = attacker.GetEntityIndex()
        if (attackerIdx in Cooldowns && (now - Cooldowns[attackerIdx]) < CooldownSeconds)
        {
            DbgWarn("ABORT: cooldown active")
            return
        }
        Cooldowns[attackerIdx] <- now

        printl("[SystemCombat.FriendlyShove] → Calling ApplyPushPhysics()")
        ApplyPushPhysics(victim, attacker)

        printl("[SystemCombat.FriendlyShove] → Calling TryShareAmmo()")
        TryShareAmmo(victim, attacker)

        printl("[SystemCombat.FriendlyShove] → Calling TryShareItems()")
        TryShareItems(victim, attacker)

        printl("[SystemCombat.FriendlyShove] → Checking bot thief (attacker bot=" + IsPlayerABot(attacker) + ")")
        if (IsPlayerABot(attacker))
            TryBotThief(victim, attacker)

        printl("[SystemCombat.FriendlyShove] OnPlayerShoved() COMPLETE")
        printl("[SystemCombat.FriendlyShove] ==========================================")
    }

    function ApplyPushPhysics(victim, attacker)
    {
        local angles = attacker.EyeAngles()
        local pitch = angles.x * 0.01745329252
        local yaw   = angles.y * 0.01745329252

        local dir = Vector(cos(pitch) * cos(yaw), cos(pitch) * sin(yaw), -sin(pitch))
        dir.Norm()
        if (dir.z < 1.26)
            dir.z = 1.26

        local impulse = dir * PushForce
        Dbg("Push: impulse=" + impulse + " to " + victim.GetPlayerName())

        local code = "::SystemCombat.FriendlyShove._DoImpulse(" + victim.GetPlayerUserId()
            + ", " + impulse.x + ", " + impulse.y + ", " + impulse.z + ")"
        DoEntFire("worldspawn", "RunScriptCode", code, 0.0, null, null)

        EmitSoundOn("Player.HitInternal", victim)
    }

    function _DoImpulse(userid, ix, iy, iz)
    {
        local victim = GetPlayerFromUserID(userid)
        if (!victim || !victim.IsValid())
            return

        Dbg("_DoImpulse: " + victim.GetPlayerName() + " vel BEFORE=" + victim.GetVelocity())
        try {
            victim.ApplyAbsVelocityImpulse(Vector(ix, iy, iz))
        } catch (e) {
            DbgWarn("_DoImpulse failed: " + e)
            return
        }
        Dbg("_DoImpulse: " + victim.GetPlayerName() + " vel AFTER =" + victim.GetVelocity())
    }

    function TryShareAmmo(victim, attacker)
    {
        Dbg("TryShareAmmo: ENTER")

        local active = attacker.GetActiveWeapon()
        if (!active || !active.IsValid())
        {
            Dbg("  ABORT: no weapon")
            return
        }
        if (active.GetClassname() != GetPrimarySlotClass(attacker))
        {
            Dbg("  ABORT: not holding primary")
            return
        }

        local vAmmo = GetHeldAmmoType(victim)
        local aAmmo = GetHeldAmmoType(attacker)
        if (vAmmo == null || aAmmo == null || vAmmo != aAmmo)
        {
            Dbg("  ABORT: ammo mismatch (v=" + vAmmo + " a=" + aAmmo + ")")
            return
        }
        if (victim.IsIncapacitated())
        {
            Dbg("  ABORT: victim incap")
            return
        }

        local attackerPrimary = GetPrimarySlotWeapon(attacker)
        if (!attackerPrimary || !attackerPrimary.IsValid())
            return

        local ammoToGive = attackerPrimary.Clip1()
        if (ammoToGive <= 0)
        {
            Dbg("  ABORT: empty clip")
            return
        }

        victim.GiveAmmo(ammoToGive)
        attackerPrimary.SetClip1(0)
        printl("[SystemCombat.FriendlyShove] AMMO SHARED: " + ammoToGive + " rounds")

        if ("MaoLib_VFX" in getroottable())
            MaoLib_VFX.EmitSound(victim, "weapons/ammo_pack_pickup.wav", 0.6, 100)

        Dbg("TryShareAmmo: EXIT (shared " + ammoToGive + ")")
    }

    function GetHeldAmmoType(player)
    {
        local invTable = {}
        GetInvTable(player, invTable)
        if (!("slot0" in invTable))
            return null

        local weapon = invTable.slot0
        if (!weapon || !weapon.IsValid())
            return null

        return GetWeaponAmmoType(weapon.GetClassname())
    }

    function GetWeaponAmmoType(classname)
    {
        if (classname in AmmoTypes)
            return AmmoTypes[classname]
        return null
    }

    function GetPrimarySlotWeapon(player)
    {
        local invTable = {}
        GetInvTable(player, invTable)
        if (!("slot0" in invTable))
            return null
        return invTable.slot0
    }

    function GetPrimarySlotClass(player)
    {
        local w = GetPrimarySlotWeapon(player)
        if (!w || !w.IsValid())
            return null
        return w.GetClassname()
    }

    function TryShareItems(victim, attacker)
    {
        Dbg("TryShareItems: ENTER")

        local active = attacker.GetActiveWeapon()
        if (!active || !active.IsValid())
        {
            Dbg("  ABORT: no weapon")
            return
        }

        local weaponClass = active.GetClassname()

        switch (weaponClass)
        {
            case "weapon_molotov":
                if (GetSlot2Class(victim) == null) { victim.GiveItem("molotov"); active.Kill(); printl("[SystemCombat.FriendlyShove] ITEM SHARED: molotov") }
                else Dbg("  molotov: victim has slot2")
                break
            case "weapon_vomitjar":
                if (GetSlot2Class(victim) == null) { victim.GiveItem("vomitjar"); active.Kill(); printl("[SystemCombat.FriendlyShove] ITEM SHARED: vomitjar") }
                else Dbg("  vomitjar: victim has slot2")
                break
            case "weapon_pipe_bomb":
                if (GetSlot2Class(victim) == null) { victim.GiveItem("pipe_bomb"); active.Kill(); printl("[SystemCombat.FriendlyShove] ITEM SHARED: pipe_bomb") }
                else Dbg("  pipe_bomb: victim has slot2")
                break
            case "weapon_upgradepack_explosive":
                if (GetSlot3Class(victim) == null) { victim.GiveItem("upgradepack_explosive"); active.Kill(); printl("[SystemCombat.FriendlyShove] ITEM SHARED: upgradepack_explosive") }
                else Dbg("  explosive: victim has slot3")
                break
            case "weapon_upgradepack_incendiary":
                if (GetSlot3Class(victim) == null) { victim.GiveItem("upgradepack_incendiary"); active.Kill(); printl("[SystemCombat.FriendlyShove] ITEM SHARED: upgradepack_incendiary") }
                else Dbg("  incendiary: victim has slot3")
                break
            case "weapon_defibrillator":
                if (IsHoldingUse(attacker) && GetSlot3Class(victim) == null) { victim.GiveItem("defibrillator"); active.Kill(); printl("[SystemCombat.FriendlyShove] ITEM SHARED: defibrillator") }
                else Dbg("  defib: conditions not met")
                break
            case "weapon_first_aid_kit":
                if (IsHoldingUse(attacker) && GetSlot3Class(victim) == null) { victim.GiveItem("first_aid_kit"); active.Kill(); printl("[SystemCombat.FriendlyShove] ITEM SHARED: first_aid_kit") }
                else Dbg("  medkit: conditions not met")
                break
            case "weapon_adrenaline":
            case "weapon_pain_pills":
                if (GetSlot4Class(victim) == null)
                {
                    local giveName = (weaponClass == "weapon_adrenaline") ? "adrenaline" : "pain_pills"
                    victim.GiveItem(giveName)
                    active.Kill()
                    printl("[SystemCombat.FriendlyShove] ITEM SHARED: " + giveName)
                }
                else Dbg("  pills: victim has slot4")
                break
            default:
                Dbg("  not shareable: " + weaponClass)
                break
        }

        Dbg("TryShareItems: EXIT")
    }

    function TryBotThief(victim, attacker)
    {
        Dbg("TryBotThief: ENTER")

        local stole = false
        if (GetSlot2Class(attacker) == null)
        {
            local v = GetSlot2Class(victim)
            if (v != null) { TransferItem(victim, attacker, v); stole = true; printl("[SystemCombat.FriendlyShove] BOT THIEF: " + v) }
        }
        if (GetSlot3Class(attacker) == null)
        {
            local v = GetSlot3Class(victim)
            if (v != null) { TransferItem(victim, attacker, v); stole = true; printl("[SystemCombat.FriendlyShove] BOT THIEF: " + v) }
        }
        if (GetSlot4Class(attacker) == null)
        {
            local v = GetSlot4Class(victim)
            if (v != null) { TransferItem(victim, attacker, v); stole = true; printl("[SystemCombat.FriendlyShove] BOT THIEF: " + v) }
        }

        if (!stole)
            Dbg("  nothing to steal")
        Dbg("TryBotThief: EXIT")
    }

    function TransferItem(fromPlayer, toPlayer, itemClass)
    {
        local switchName = itemClass
        if (MaoLib.startswith(itemClass, "weapon_"))
            switchName = itemClass.slice(7)

        fromPlayer.SwitchToItem(switchName)
        local active = fromPlayer.GetActiveWeapon()
        if (active && active.IsValid())
            active.Kill()

        toPlayer.GiveItem(switchName)
        Dbg("  transferred " + switchName)
    }

    function GetSlot2Class(player)
    {
        local invTable = {}
        GetInvTable(player, invTable)
        if (!("slot2" in invTable))
            return null
        local w = invTable.slot2
        if (!w || !w.IsValid())
            return null
        return w.GetClassname()
    }

    function GetSlot3Class(player)
    {
        local invTable = {}
        GetInvTable(player, invTable)
        if (!("slot3" in invTable))
            return null
        local w = invTable.slot3
        if (!w || !w.IsValid())
            return null
        return w.GetClassname()
    }

    function GetSlot4Class(player)
    {
        local invTable = {}
        GetInvTable(player, invTable)
        if (!("slot4" in invTable))
            return null
        local w = invTable.slot4
        if (!w || !w.IsValid())
            return null
        return w.GetClassname()
    }

    function IsHoldingUse(player)
    {
        return (NetProps.GetPropInt(player, "m_nButtons") & (1 << 5)) != 0
    }

    function GenerateAmmoConfigIfMissing()
    {
        if (MaoLib.FileExists(AmmoConfigPath))
        {
            Dbg("GenerateAmmoConfigIfMissing: file already exists at " + AmmoConfigPath)
            return
        }

        local lines = [
            "// Friendly Shove — Ammo Type Config",
            "// Weapons sharing the same ammo type number can share ammo via shove.",
            "weapon_autoshotgun 6",
            "weapon_hunting_rifle 7",
            "weapon_grenade_launcher 1",
            "weapon_pistol_magnum 0",
            "weapon_pistol 0",
            "weapon_pumpshotgun 3",
            "weapon_rifle_ak47 5",
            "weapon_rifle_desert 5",
            "weapon_rifle_m60 2",
            "weapon_rifle_sg552 5",
            "weapon_rifle 5",
            "weapon_shotgun_chrome 3",
            "weapon_shotgun_spas 6",
            "weapon_smg_mp5 4",
            "weapon_smg_silenced 4",
            "weapon_smg 4",
            "weapon_sniper_awp 8",
            "weapon_sniper_military 8",
            "weapon_sniper_scout 8"
        ]

        local content = ""
        foreach (line in lines)
            content += line + "\n"

        StringToFile(AmmoConfigPath, content)
        printl("[SystemCombat.FriendlyShove] Generated default ammo config: " + AmmoConfigPath)
    }

    function LoadAmmoConfig()
    {
        local data = FileToString(AmmoConfigPath)
        if (!data)
        {
            DbgWarn("LoadAmmoConfig: no data from " + AmmoConfigPath)
            return
        }

        local lines = split(data, "\r\n")
        local loaded = 0
        foreach (line in lines)
        {
            line = strip(line)
            if (line == "" || MaoLib.startswith(line, "//"))
                continue

            local idx = line.find(" ")
            if (idx == null)
                continue

            local weapon = line.slice(0, idx)
            local valueStr = line.slice(idx + 1)
            local value = null
            try {
                value = valueStr.tointeger()
            } catch (e) {
                continue
            }

            AmmoTypes[weapon] <- value
            loaded++
        }

        printl("[SystemCombat.FriendlyShove] Ammo config loaded from " + AmmoConfigPath + " (" + loaded + " entries)")
    }

    function OnRoundEnd(params)
    {
        printl("[SystemCombat.FriendlyShove] OnRoundEnd() — clearing cooldowns")
        Cooldowns = {}
    }

    function OnMissionLost(params)
    {
        printl("[SystemCombat.FriendlyShove] OnMissionLost() — clearing cooldowns")
        Cooldowns = {}
    }

    function OnMapTransition(params)
    {
        printl("[SystemCombat.FriendlyShove] OnMapTransition() — clearing cooldowns")
        Cooldowns = {}
    }
}

// ============================================================================
// Events — Unified Event Handlers
// ============================================================================

::SystemCombat.Events <- {
    function OnGameEvent_player_hurt(params)
    {
        ::SystemCombat.FX.OnPlayerHurt(params)
        ::SystemCombat.Util.OnPlayerHurt(params)
    }

    function OnGameEvent_player_shoved(params)
    {
        ::SystemCombat.FX.OnPlayerShoved(params)
        ::SystemCombat.FriendlyShove.OnPlayerShoved(params)
    }

    function OnGameEvent_player_spawn(params)
    {
        ::SystemCombat.FX.OnPlayerSpawn(params)
    }

    function OnGameEvent_round_end(params)
    {
        ::SystemCombat.Util.OnRoundEnd(params)
        ::SystemCombat.FriendlyShove.OnRoundEnd(params)
        MaoLib.RemoveTimer("syscombat_avoidance")
    }

    function OnGameEvent_infected_hurt(params)
    {
        ::SystemCombat.FX.OnInfectedHurt(params)
    }

    function OnGameEvent_boomer_exploded(params)
    {
        ::SystemCombat.FX.OnBoomerExploded(params)
    }

    function OnGameEvent_charger_charge_end(params)
    {
        ::SystemCombat.FX.OnChargerChargeEnd(params)
    }

    function OnGameEvent_entity_shoved(params)
    {
        ::SystemCombat.FX.OnEntityShoved(params)
    }

    function OnGameEvent_player_use(params)
    {
        ::SystemCombat.FX.OnPlayerUse(params)
    }

    function OnGameEvent_pills_used(params)
    {
        ::SystemCombat.FX.OnPillsUsed(params)
    }

    function OnGameEvent_adrenaline_used(params)
    {
        ::SystemCombat.FX.OnAdrenalineUsed(params)
    }

    function OnGameEvent_heal_success(params)
    {
        ::SystemCombat.FX.OnHealSuccess(params)
    }

    function OnGameEvent_revive_success(params)
    {
        ::SystemCombat.FX.OnReviveSuccess(params)
    }

    function OnGameEvent_choke_start(params)
    {
        ::SystemCombat.Util.OnChokeStart(params)
    }

    function OnGameEvent_lunge_pounce(params)
    {
        ::SystemCombat.Util.OnLungePounce(params)
    }

    function OnGameEvent_jockey_ride(params)
    {
        ::SystemCombat.Util.OnJockeyRide(params)
    }

    function OnGameEvent_charger_carry_start(params)
    {
        ::SystemCombat.Util.OnChargerCarryStart(params)
    }

    function OnGameEvent_charger_carry_end(params)
    {
        ::SystemCombat.Util.OnChargerCarryEnd(params)
    }

    function OnGameEvent_player_now_it(params)
    {
        ::SystemCombat.Util.OnPlayerNowIt(params)
    }

    function OnGameEvent_mission_lost(params)
    {
        ::SystemCombat.FriendlyShove.OnMissionLost(params)
    }

    function OnGameEvent_map_transition(params)
    {
        ::SystemCombat.FriendlyShove.OnMapTransition(params)
    }

    function OnGameEvent_round_start(params)
    {
        ::SystemCombat.FriendlyShove.OnRoundStart(params)
    }
}

// ============================================================================
// Init
// ============================================================================

::SystemCombat.Init <- function()
{
    if ("_init_done" in ::SystemCombat && ::SystemCombat._init_done)
    {
        printl("[SystemCombat] Init() skipped — already initialized")
        return
    }
    ::SystemCombat._init_done <- true

    printl("[SystemCombat] ==========================================")
    printl("[SystemCombat] Init() called")
    printl("[SystemCombat] ==========================================")

    ::SystemCombat.Util.PrecacheSounds()
    ::SystemCombat.FriendlyShove.Init()

    __CollectGameEventCallbacks(::SystemCombat.Events)

    printl("[SystemCombat] All events registered.")
    printl("[SystemCombat] ==========================================")
}

::SystemCombat.Init()

printl("[SystemCombat] system_combat.nut loaded and active.")
