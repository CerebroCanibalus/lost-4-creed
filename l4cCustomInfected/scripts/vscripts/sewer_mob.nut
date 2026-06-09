nanas_sewer_worker <- 
{
    Debug = 1

    function Dbg(msg) {
        if (Debug) printl("[SewerWorker][DEBUG] " + msg)
    }

    function DbgWarn(msg) {
        printl("[SewerWorker][WARN] " + msg)
    }

    settings =
    {
        sewer_chance = 30,        // 1 in X commons become sewer workers
        bile_chance  = 3          // 1 in X hits apply bile
    }

    //------------------------------------------------------------
    // SETTINGS
    //------------------------------------------------------------
    function LoadSettings()
    {
        local file = FileToString("sewer_worker/settings.cfg");
        if (!file)
        {
            SaveSettings();
            return;
        }

        foreach (line in split(file, "\n"))
        {
            line = strip(line);
            if (line == "" || line.find("//") == 0) continue;

            local p = split(line, "=");
            if (p.len() != 2) continue;

            local k = strip(p[0]);
            local v = strip(p[1]);

            if (k in settings)
                settings[k] = v.tointeger();
        }
    }

    function SaveSettings()
    {
        local out = "";
        foreach (k,v in settings)
            out += k + " = " + v + "\n";

        StringToFile("sewer_worker/settings.cfg", out);
    }

    //------------------------------------------------------------
    function OnGameEvent_round_start(params)
    {
        Dbg("round_start: loading settings + precaching")
        LoadSettings();

        if (!IsModelPrecached("models/infected/sewer_worker.mdl"))
            PrecacheModel("models/infected/sewer_worker.mdl");

        if (::MaoLib.IsTimerActive("sewer_scan"))
            ::MaoLib.RemoveTimer("sewer_scan")

        ::MaoLib.AddTimer("sewer_scan", 0.5, function() {
            ::nanas_sewer_worker.Think()
        })
        Dbg("Timer sewer_scan started")
    }

    function OnGameEvent_round_end(params)      { Cleanup() }
    function OnGameEvent_mission_lost(params)  { Cleanup() }
    function OnGameEvent_map_transition(params){ Cleanup() }

    function Cleanup()
    {
        ::MaoLib.RemoveTimer("sewer_scan")
    }

    //------------------------------------------------------------
    // THINK LOOP
    //------------------------------------------------------------
    function Think()
    {
        local ent = null;
        while (ent = Entities.FindByClassname(ent, "infected"))
        {
            if (!ent || ent.GetHealth() <= 0) continue;

            ent.ValidateScriptScope();
            local s = ent.GetScriptScope();

            // Flag único para evitar colisiones con kamikaze
            if ("nsw_checked" in s) continue;
            s.nsw_checked <- true;

            if (RandomInt(1, settings.sewer_chance) == 1)
            {
                Dbg("ROLL SUCCESS: converting entIdx=" + ent.GetEntityIndex())
                ::nanas_sewer_worker.ConvertDelayed(ent.GetEntityIndex())
            }
        }
    }

    //------------------------------------------------------------
    // DELAYED CONVERSION (ALL CHECKS HERE)
    //------------------------------------------------------------
    function ConvertDelayed(idx)
    {
        local ent = EntIndexToHScript(idx);
        if (!ent || ent.GetHealth() <= 0) {
            Dbg("ConvertDelayed: ent invalid or dead (idx=" + idx + ")")
            return
        }

        local mdl = ent.GetModelName();
        if (!mdl) {
            Dbg("ConvertDelayed: GetModelName() returned null (idx=" + idx + ")")
            return
        }

        mdl = mdl.tolower();

        // compatibility with other mods
        if (mdl.find("corpseeater") != null) return;
        if (mdl.find("prisoner") != null) return;
        if (mdl.find("rat") != null) return;
        if (mdl.find("blood") != null) return;
        if (mdl.find("kamikaze") != null) return;
        if (mdl.find("fireman") != null) return;
        if (mdl.find("park_ranger") != null) return;
        if (mdl.find("common_male_police_l4d2") != null) return;
        if (mdl.find("paramedic") != null) return;
        if (mdl.find("riot") != null) return;
        if (mdl.find("hazmat") != null) return;
        if (mdl.find("ceda") != null) return;
        if (mdl.find("clown") != null) return;
        if (mdl.find("mud") != null) return;
        if (mdl.find("fallen") != null) return;
        if (mdl.find("roadcrew") != null) return;
        if (mdl.find("jimmy") != null) return;

        ent.ValidateScriptScope();
        local s = ent.GetScriptScope();

        if ("IsSewerWorker" in s) return;

        s.IsSewerWorker <- true;

        ent.SetModel("models/infected/sewer_worker.mdl");
        NetProps.SetPropInt(ent, "m_iHealth", 60);
        NetProps.SetPropInt(ent, "m_iMaxHealth", 60);

        // Verificar modelo aplicado
        local newMdl = ent.GetModelName();
        if (newMdl && newMdl.tolower().find("sewer_worker") != null) {
            Dbg("CONVERSION OK: entIdx=" + idx + " model=infected/sewer_worker.mdl HP=60")
        } else {
            DbgWarn("CONVERSION FAILED: SetModel no cambió el modelo. old=" + mdl + " new=" + (newMdl || "null"))
        }
    }

    //------------------------------------------------------------
    // BILE ON HIT
    //------------------------------------------------------------
	function HandlePlayerHurt(params)
	{
		// player_hurt: userid=víctima survivor, attackerentid=entindex del CI atacante
		if (!("userid" in params)) return;

		local victim = GetPlayerFromUserID(params.userid);
		if (!victim || !victim.IsValid() || !victim.IsSurvivor())
			return;

		if (!("attackerentid" in params) || !params.attackerentid) return;

		local atk = EntIndexToHScript(params.attackerentid);
		if (!atk || !atk.IsValid()) return;
		if (atk.GetClassname() != "infected") return;

		atk.ValidateScriptScope();
		local s = atk.GetScriptScope();

		if (!("IsSewerWorker" in s)) return;

		if (RandomInt(1, settings.bile_chance) != 1)
			return;

		victim.HitWithVomit();
	}

	function OnGameEvent_player_hurt(params) { HandlePlayerHurt(params); }
}

//------------------------------------------------------------
::nanas_sewer_worker <- nanas_sewer_worker;
__CollectGameEventCallbacks(nanas_sewer_worker)
IncludeScript("sewer_worker/common_anim_fix5.nut", getroottable());
try { nanas_sewer_worker.LoadSettings(); } catch (e) { printl("[SewerWorker][ERR] LoadSettings: " + e); }