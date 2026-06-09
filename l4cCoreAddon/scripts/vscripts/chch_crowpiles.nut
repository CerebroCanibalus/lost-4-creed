printl("[ChCh_CrowPiles] MaoLib refactor loaded")

::ChCh_CrowPiles <-
{
    UsedNavs = []
    TriggeredCrows = []
    SpawnedEntities = []
    DirectorEnt = null

    Settings =
    {
        CrowNumberMin = 1
        CrowNumberMax = 3
        Allowed_Gamemodes = ["coop", "realism", "versus"]
    }

    // ─── SETTINGS I/O ───
    function ParseSettings()
    {
        local defaults = {
            CrowNumberMin = 1
            CrowNumberMax = 3
            Allowed_Gamemodes = ["coop", "realism", "versus"]
        }
        local keys = ["CrowNumberMin", "CrowNumberMax", "Allowed_Gamemodes"]
        local opts = MaoLib.InitOptions(defaults, "crowpiles/Settings.cfg", keys)

        Settings.CrowNumberMin = MaoLib.max(0, opts.CrowNumberMin)
        Settings.CrowNumberMax = MaoLib.max(Settings.CrowNumberMin, opts.CrowNumberMax)
        Settings.Allowed_Gamemodes = opts.Allowed_Gamemodes
    }

    // ─── ENTITY TRACKING ───
    function TrackEntity(ent)
    {
        if (MaoLib.IsReal(ent) && SpawnedEntities.find(ent) == null)
        {
            SpawnedEntities.append(ent)
        }
    }

    function Cleanup()
    {
        foreach (ent in SpawnedEntities)
        {
            if (MaoLib.IsReal(ent))
            {
                ent.Kill()
            }
        }
        SpawnedEntities.clear()
        UsedNavs.clear()
        TriggeredCrows.clear()
        DirectorEnt = null
    }

    // ─── CEILING CHECK ───
    function HasCeilingAbove(pos)
    {
        if (!MaoLib_VFX.IsValidPosition(pos))
            return false

        local trace =
        {
            start = pos + Vector(0, 0, 32),
            end = pos + Vector(0, 0, 512),
            mask = 0x200400B // MASK_SOLID
        }
        TraceLine(trace)
        return trace.fraction < 1.0
    }

    // ─── ROUTE SPOT SELECTION (con fallback integrado) ───
    function GetRandomRouteSpot()
    {
        local navtable = {}
        NavMesh.GetAllAreas(navtable)
        
        // PASO 1: Filtro primario (áreas con 131072, sin 128 ni 2048)
        local spot = PickSpotFromFilter(navtable, "primary")
        if (spot != null)
            return spot
        
        // PASO 2: Fallback (cualquier área que permita spawn)
        printl("[ChCh_CrowPiles] Primary filter found no areas, trying fallback...")
        spot = PickSpotFromFilter(navtable, "fallback")
        if (spot != null)
            return spot
        
        // PASO 3: Último recurso (cualquier área navegable no bajo agua)
        printl("[ChCh_CrowPiles] Fallback found no spawn areas, using last resort...")
        spot = PickSpotFromFilter(navtable, "lastresort")
        return spot
    }

    function PickSpotFromFilter(navtable, mode)
    {
        local selectednavs = []
        
        foreach (nav in navtable)
        {
            if (UsedNavs.find(nav) != null)
                continue
            
            if (mode == "primary")
            {
                if ((nav.HasSpawnAttributes(131072) || nav.HasAttributes(131072)) &&
                    !nav.HasSpawnAttributes(128) && !nav.HasAttributes(128) &&
                    !nav.HasSpawnAttributes(2048) && !nav.HasAttributes(2048))
                    selectednavs.append(nav)
            }
            else if (mode == "fallback")
            {
                if (nav.IsSpawningAllowed() && !nav.IsUnderwater() &&
                    !nav.HasSpawnAttributes(2) && !nav.HasSpawnAttributes(8192))
                    selectednavs.append(nav)
            }
            else // lastresort
            {
                if (!nav.IsUnderwater() && !nav.IsDegenerate())
                    selectednavs.append(nav)
            }
        }

        if (selectednavs.len() == 0)
            return null

        for (local attempts = 0; attempts < 15; attempts++)
        {
            local realnav = selectednavs[RandomInt(0, selectednavs.len() - 1)]

            if (RandomInt(1, 100) <= 50)
            {
                local adj = realnav.GetRandomAdjacentArea(RandomInt(1, 15))
                if (adj != null)
                    realnav = adj
            }

            local spot = realnav.FindRandomSpot()
            if (!HasCeilingAbove(spot))
            {
                UsedNavs.append(realnav)
                return spot
            }
        }

        // Aceptar cualquier spot tras agotar intentos
        local realnav = selectednavs[RandomInt(0, selectednavs.len() - 1)]
        UsedNavs.append(realnav)
        return realnav.FindRandomSpot()
    }

    // ─── CROW ALERTER ───
    function GetCrowAlerter()
    {
        foreach (player in MaoLib.YieldPlayers())
        {
            if (MaoLib.IsAlivePlayer(player))
            {
                if (ResponseCriteria.GetValue(player, "ChCh_AlertedCrows") == "1")
                {
                    return player
                }
            }
        }
        return null
    }

    // ─── IDLE CROW SPAWNING ───
    function SpawnIdleCrows(where, crownum)
    {
        local offsets = [
            Vector(0, 0, 0),
            Vector(24, 36, 0),
            Vector(32, -36, 0),
            Vector(-22, 45, 0),
            Vector(-45, -22, 0),
            Vector(64, -36, 0),
            Vector(-72, 32, 0)
        ]
        local anims = ["Eat_A", "Eat_B", "Idle01", "Eat_A", "Idle01", "Eat_B", "Idle01"]

        for (local i = 0; i < offsets.len(); i++)
        {
            local crow = SpawnEntityFromTable("prop_dynamic",
            {
                targetname = "chch_crowpile_" + crownum + "_fakecrow" + (i + 1),
                origin = where + offsets[i],
                angles = Vector(0, RandomInt(0, 360), 0),
                model = "models/chimcham/crow.mdl",
                fademindist = -1,
                fademaxdist = 0,
                solid = 0,
                disableshadows = 0,
                defaultanim = anims[i]
            })
            if (MaoLib.IsReal(crow))
            {
                TrackEntity(crow)
            }
        }
    }

    function AlertIdleCrows(crownum)
    {
        local crow = null
        while (crow = Entities.FindByName(crow, "chch_crowpile_" + crownum + "_fakecrow*"))
        {
            if (MaoLib.IsReal(crow))
            {
                EntFire(crow.GetName(), "SetAnimation", "flyaway", 0, null)
                EntFire(crow.GetName(), "SetDefaultAnimation", "flyaway", 0, null)
                if (crow.ValidateScriptScope()) {
                    crow.GetScriptScope()["ChCh_AnimDone"] <- function(act, caller, out) {
                        if (caller && caller.IsValid()) caller.Kill()
                    }
                    crow.ConnectOutput("OnAnimationDone", "ChCh_AnimDone")
                }
            }
        }
    }

    // ─── MAIN SPAWNING ───
    function SpawnCrowPile(where, crownum)
    {
        if (!where || !MaoLib_VFX.IsValidPosition(where))
            return

        SpawnIdleCrows(where, crownum)

        local crowmodel = SpawnEntityFromTable("prop_dynamic",
        {
            targetname = "chch_crowpile_" + crownum + "_model",
            origin = where - Vector(0, 0, 3),
            angles = Vector(0, RandomInt(0, 360), 0),
            model = "models/props_swamp/boardwalk_128.mdl",
            rendermode = 10,
            damagefilter = "chch_crowfilter",
            fademindist = -1,
            fademaxdist = 0,
            solid = 2,
            disableshadows = 1
        })

        if (MaoLib.IsReal(crowmodel))
        {
            TrackEntity(crowmodel)

            if (crowmodel.ValidateScriptScope()) {
                local s = crowmodel.GetScriptScope()
                s["ChCh_OnDamage"] <- function(activator, caller, output) {
                    if (!activator || !activator.IsValid()) return
                    activator.SetContext("ChCh_AlertedCrows", "1", 0.0)
                    MaoLib.DelayCall(function() {
                        if (activator && activator.IsValid())
                            activator.SetContext("ChCh_AlertedCrows", "0", 0.0)
                    }, 1.0)
                    ::ChCh_CrowPiles.TriggerCrowPile(crownum)
                }
                crowmodel.ConnectOutput("OnTakeDamage", "ChCh_OnDamage")
            }
        }

        local crowtrigger = SpawnEntityFromTable("script_trigger_once",
        {
            targetname = "chch_crowpile_" + crownum + "_trigger",
            origin = where,
            allowghost = 0,
            allowincap = 1,
            startdisabled = 0,
            spawnflags = 1,
            filtername = "chch_crowfilter",
            extent = Vector(64, 64, 48)
        })

        if (MaoLib.IsReal(crowtrigger))
        {
            TrackEntity(crowtrigger)

            if (crowtrigger.ValidateScriptScope()) {
                local s = crowtrigger.GetScriptScope()
                s["ChCh_OnTouch"] <- function(activator, caller, output) {
                    if (!activator || !activator.IsValid()) return
                    activator.SetContext("ChCh_AlertedCrows", "1", 0.0)
                    MaoLib.DelayCall(function() {
                        if (activator && activator.IsValid())
                            activator.SetContext("ChCh_AlertedCrows", "0", 0.0)
                    }, 1.0)
                    ::ChCh_CrowPiles.CheckTriggerCrowPile(crownum, caller)
                }
                crowtrigger.ConnectOutput("OnStartTouch", "ChCh_OnTouch")
            }
        }
    }

    // ─── TRIGGER LOGIC ───
    function TriggerCrowPile(crownum)
    {
        if (TriggeredCrows.find(crownum) != null)
            return

        TriggeredCrows.append(crownum)

        local crowmodel = Entities.FindByName(null, "chch_crowpile_" + crownum + "_model")
        if (!MaoLib.IsReal(crowmodel))
            return

        // VFX + SFX via MaoLib
        MaoLib_VFX.SpawnParticle(crowmodel.GetOrigin() + Vector(0, 0, 128), "crows_flyaway", 6.0)
        MaoLib_VFX.EmitSound(crowmodel, "animation/crow_flock_farm_05.wav", 1.0, RandomInt(95, 105))

        // Panic event via director entity
        if (MaoLib.IsReal(DirectorEnt))
        {
            MaoLib.DelayCallOpt(function() { EntFire("chch_crowpile_director", "ForcePanicEvent", "", 0, null) }, 1.5)
        }

        AlertIdleCrows(crownum)
        crowmodel.Kill()

        local alerter = GetCrowAlerter()
        local alerterName = (alerter != null) ? GetCharacterDisplayName(alerter) : "Someone"

        // Instructor hint with unique targetname
        local hintname = "chch_crowhint_" + crownum
        local hint = SpawnEntityFromTable("env_instructor_hint",
        {
            hint_allow_nodraw_target = 1,
            hint_auto_start = 0,
            hint_color = "255 255 255",
            hint_icon_offscreen = "icon_alert_red",
            hint_icon_onscreen = "icon_alert_red",
            hint_instance_type = 2,
            targetname = hintname,
            hint_alphaoption = 0,
            hint_caption = alerterName + " has doomed you all...",
            hint_display_limit = 0,
            hint_static = 1,
            hint_forcecaption = 1,
            hint_nooffscreen = 1,
            hint_timeout = 4,
            hint_range = 0
        })

        if (MaoLib.IsReal(hint))
        {
            TrackEntity(hint)
            foreach (s in MaoLib.YieldSurvivors())
            {
                if (MaoLib.IsAlivePlayer(s))
                {
                    DoEntFire(hintname, "ShowHint", "", 0.0, null, s)
                }
            }
            MaoLib.DelayCallOpt(function() { local h = Entities.FindByName(null, hintname); if (h != null && h.IsValid()) h.Kill() }, 4.5)
        }

        if (alerter != null)
        {
            QueueSpeak(alerter, "ChCh_AlertedCrows", 0.0, "")
        }
    }

    function CheckTriggerCrowPile(crownum, activator)
    {
        if (!MaoLib.IsReal(activator) || !activator.IsSurvivor())
        {
            TriggerCrowPile(crownum)
            return
        }

        // FL_DUCKING = 2 (1 << 1) - crouching bypasses trigger
        if (NetProps.GetPropInt(activator, "m_fFlags") & 2)
        {
            DoEntFire("!self", "AddContext", "ChCh_AlertedCrows:0", 0.0, activator, activator)
            return
        }

        TriggerCrowPile(crownum)
    }

    // ─── ROUND EVENTS ───
    function OnGameEvent_round_start(params)
    {
        Cleanup()

        if (Settings.Allowed_Gamemodes.find(Director.GetGameModeBase()) == null)
            return

        PrecacheSound("animation/crow_flock_farm_05.wav")
        ParseSettings()

        // Team filter for survivors
        SpawnEntityFromTable("filter_activator_team",
        {
            targetname = "chch_crowfilter",
            filterteam = 2,
            Negated = "Allow entities that match criteria"
        })

        // Director entity for panic events
        DirectorEnt = SpawnEntityFromTable("info_director",
        {
            targetname = "chch_crowpile_director"
        })
        if (MaoLib.IsReal(DirectorEnt))
        {
            TrackEntity(DirectorEnt)
        }

        local howmanycrows = RandomInt(Settings.CrowNumberMin, Settings.CrowNumberMax)

        for (local i = 0; i < howmanycrows; i++)
        {
            local place = GetRandomRouteSpot()  // fallback integrado
            if (place != null)
            {
                SpawnCrowPile(place - Vector(0, 0, 8), (i + 1).tostring())
            }
        }
    }

    function OnGameEvent_round_end(params)
    {
        Cleanup()
    }
}

__CollectGameEventCallbacks(::ChCh_CrowPiles)

// ─── RESPONSE RULES ───
IncludeScript("response_testbed", this)

local newrules =
[
    {
        name = "ChCh_AlertedCrowsGambler",
        criteria =
        [
            [ "concept", "ChCh_AlertedCrows" ],
            [ "who", "Gambler" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
        ],
        responses =
        [
            { scenename = "scenes/Gambler/WorldC5M4B06.vcd" },
            { scenename = "scenes/Gambler/WorldC5M4B07.vcd" },
            { scenename = "scenes/Gambler/ReactionNegative03.vcd" },
            { scenename = "scenes/Gambler/ReactionNegative04.vcd" },
        ],
        group_params = g_rr.RGroupParams({})
    },
    {
        name = "ChCh_AlertedCrowsProducer",
        criteria =
        [
            [ "concept", "ChCh_AlertedCrows" ],
            [ "who", "Producer" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
        ],
        responses =
        [
            { scenename = "scenes/Producer/ReactionNegative13.vcd" },
            { scenename = "scenes/Producer/ReactionNegative04.vcd" },
            { scenename = "scenes/Producer/ReactionNegative18.vcd" },
            { scenename = "scenes/Producer/Taunt08.vcd" },
            { scenename = "scenes/Producer/WorldC5M3B07.vcd" },
        ],
        group_params = g_rr.RGroupParams({})
    },
    {
        name = "ChCh_AlertedCrowsCoach",
        criteria =
        [
            [ "concept", "ChCh_AlertedCrows" ],
            [ "who", "Coach" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
        ],
        responses =
        [
            { scenename = "scenes/Coach/WorldC5M4B03.vcd" },
            { scenename = "scenes/Coach/Exclamation01.vcd" },
            { scenename = "scenes/Coach/WorldC5M3B28.vcd" },
            { scenename = "scenes/Coach/ReactionNegative03.vcd" },
        ],
        group_params = g_rr.RGroupParams({})
    },
    {
        name = "ChCh_AlertedCrowsMechanic",
        criteria =
        [
            [ "concept", "ChCh_AlertedCrows" ],
            [ "who", "Mechanic" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
        ],
        responses =
        [
            { scenename = "scenes/Mechanic/WorldC5M4B01.vcd" },
            { scenename = "scenes/Mechanic/ReactionNegative07.vcd" },
            { scenename = "scenes/Mechanic/World213.vcd" },
        ],
        group_params = g_rr.RGroupParams({})
    },
    {
        name = "ChCh_AlertedCrowsNamVet",
        criteria =
        [
            [ "concept", "ChCh_AlertedCrows" ],
            [ "who", "NamVet" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
        ],
        responses =
        [
            { scenename = "scenes/NamVet/C6DLC3GRAVELHILL03.vcd" },
            { scenename = "scenes/NamVet/C6DLC3GRAVELHILL04.vcd" },
            { scenename = "scenes/NamVet/C6DLC3GRAVELHILL05.vcd" },
            { scenename = "scenes/NamVet/Swears04.vcd" },
            { scenename = "scenes/NamVet/Swears09.vcd" },
        ],
        group_params = g_rr.RGroupParams({})
    },
    {
        name = "ChCh_AlertedCrowsTeenGirl",
        criteria =
        [
            [ "concept", "ChCh_AlertedCrows" ],
            [ "who", "TeenGirl" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
        ],
        responses =
        [
            { scenename = "scenes/TeenGirl/C6DLC3GRAVELHILL01.vcd" },
            { scenename = "scenes/TeenGirl/C6DLC3GRAVELHILL03.vcd" },
            { scenename = "scenes/TeenGirl/C6DLC3GRAVELHILL04.vcd" },
            { scenename = "scenes/TeenGirl/ReactionNegative01.vcd" },
        ],
        group_params = g_rr.RGroupParams({})
    },
    {
        name = "ChCh_AlertedCrowsManager",
        criteria =
        [
            [ "concept", "ChCh_AlertedCrows" ],
            [ "who", "Manager" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
        ],
        responses =
        [
            { scenename = "scenes/Manager/C6DLC3GRAVELHILL03.vcd" },
            { scenename = "scenes/Manager/C6DLC3GRAVELHILL04.vcd" },
            { scenename = "scenes/Manager/C6DLC3GRAVELHILL05.vcd" },
            { scenename = "scenes/Manager/Swears07.vcd" },
        ],
        group_params = g_rr.RGroupParams({})
    },
    {
        name = "ChCh_AlertedCrowsBiker",
        criteria =
        [
            [ "concept", "ChCh_AlertedCrows" ],
            [ "who", "Biker" ],
            [ "Coughing", 0 ],
            [ "Incapacitated", 0 ],
        ],
        responses =
        [
            { scenename = "scenes/Biker/DLC2BirdHate01.vcd" },
            { scenename = "scenes/Biker/C6DLC3GRAVELHILL01.vcd" },
            { scenename = "scenes/Biker/Swear01.vcd" },
        ],
        group_params = g_rr.RGroupParams({})
    }
]
g_rr.rr_ProcessRules(newrules)
