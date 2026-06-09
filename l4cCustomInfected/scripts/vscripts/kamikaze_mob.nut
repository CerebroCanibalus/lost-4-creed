nanas_kamikaze <- 
{
    Debug = 1

    // 🛡️ CRITICAL: Damage recursion guard. TakeDamage() inside HandlePlayerHurt
    // fires another player_hurt event. Without this flag, kamikaze explosions
    // trigger infinite recursion when the AoE hits another kamikaze.
    _processingKamikazeHurt = false

    function Dbg(msg) {
        if (Debug) printl("[Kamikaze][DEBUG] " + msg)
    }

    function DbgWarn(msg) {
        printl("[Kamikaze][WARN] " + msg)
    }

    settings =
    {
        kamikaze_chance = 60,
        explosion_damage = 25,
        explosion_radius = 350,
        pipebomb_drop_chance = 45
    }

    //------------------------------------------------------------
    // SETTINGS
    //------------------------------------------------------------
    function LoadSettings()
    {
        local path = "kamikaze/settings.cfg";
        local file = FileToString(path);

        if (file != null)
        {
            foreach (line in split(file, "\n"))
            {
                line = strip(line);
                if (line == "" || line.find("//") == 0) continue;

                local p = split(line, "=");
                if (p.len() != 2) continue;

                local k = strip(p[0]);
                local v = strip(p[1]);

                if (k in settings)
                    settings[k] = (v.find(".") != null) ? v.tofloat() : v.tointeger();
            }
        }
        else SaveSettings();
    }

    function SaveSettings()
    {
        local out = "";
        foreach (k,v in settings)
            out += k + " = " + v + "\n";
        StringToFile("kamikaze/settings.cfg", out);
    }

    //------------------------------------------------------------
    function OnGameEvent_round_start(params)
    {
        Dbg("round_start: loading settings + precaching")
        LoadSettings();

        if (!IsModelPrecached("models/infected/kamikaze.mdl"))
            PrecacheModel("models/infected/kamikaze.mdl");

        if (::MaoLib.IsTimerActive("kamikaze_scan"))
            ::MaoLib.RemoveTimer("kamikaze_scan")

        ::MaoLib.AddTimer("kamikaze_scan", 0.5, function() {
            ::nanas_kamikaze.Think()
        })
        Dbg("Timer kamikaze_scan started")
    }

    function OnGameEvent_round_end(params)      { Cleanup() }
    function OnGameEvent_mission_lost(params)  { Cleanup() }
    function OnGameEvent_map_transition(params){ Cleanup() }

    function Cleanup()
    {
        ::MaoLib.RemoveTimer("kamikaze_scan")
    }

    //------------------------------------------------------------
    // REGULAR COMMON FILTER
    //------------------------------------------------------------
    function IsRegularCommon(ent)
    {
        local m = ent.GetModelName();
        if (!m) return false;

        m = m.tolower();
        // NOTA: usar != null porque string.find() devuelve 0 si encuentra al inicio (falsy)
        if (m.find("riot") != null || m.find("hazmat") != null || m.find("ceda") != null ||
            m.find("mud") != null || m.find("clown") != null || m.find("fallen") != null ||
            m.find("roadcrew") != null || m.find("jimmy") != null)
            return false;

        return true;
    }

    //------------------------------------------------------------
    // THINK LOOP
    //------------------------------------------------------------
    function Think()
    {
        local ent = null;

        while (ent = Entities.FindByClassname(ent, "infected"))
        {
            if (!ent || !ent.IsValid())
                continue;

            ent.ValidateScriptScope();
            local s = ent.GetScriptScope();

            if ("IsKamikaze" in s)
            {
                if (!("WasAlive" in s))
                    s.WasAlive <- true;

                if (s.WasAlive && ent.GetHealth() <= 0)
                {
                    s.WasAlive = false;
                    DropPipeBomb(ent);
                }
                continue;
            }

            if (ent.GetHealth() <= 0)
                continue;

            if (!IsRegularCommon(ent))
                continue;

            // Flag único por script para evitar colisiones con otros sistemas
            if ("nkk_checked" in s)
                continue;

            // Roll único por common
            s.nkk_checked <- true;

            if (RandomInt(1, settings.kamikaze_chance) == 1)
            {
                Dbg("ROLL SUCCESS: converting entIdx=" + ent.GetEntityIndex())
                s.WasAlive <- true; // set flag immediately for pipebombs

                // Conversión directa (sin EntFire — más rápida y evita race conditions)
                ::nanas_kamikaze.ConvertDelayed(ent.GetEntityIndex());
            }
        }
    }

    //------------------------------------------------------------
    // DELAYED CONVERSION WITH MODEL CHECK
    //------------------------------------------------------------
    function ConvertDelayed(idx)
    {
        local ent = EntIndexToHScript(idx);
        if (!ent || ent.GetHealth() <= 0) {
            Dbg("ConvertDelayed: ent invalid or dead (idx=" + idx + ")")
            return
        }

        // Safe: GetModelName() puede devolver null para algunos estados
        local mdl = ent.GetModelName();
        if (!mdl) {
            Dbg("ConvertDelayed: GetModelName() returned null (idx=" + idx + ")")
            return
        }
        mdl = mdl.tolower();
        if (mdl.find("corpseeater") != null || mdl.find("prisoner") != null || mdl.find("blood_man") != null || mdl.find("sewer_worker") != null)
            return;

        ent.ValidateScriptScope();
        local s = ent.GetScriptScope();

        if ("IsKamikaze" in s) return;

        s.IsKamikaze <- true;
        s.WasAlive <- true;

        ent.SetModel("models/infected/kamikaze.mdl");
        NetProps.SetPropInt(ent, "m_iHealth", 50);
        NetProps.SetPropInt(ent, "m_iMaxHealth", 50);

        // Verificar que el modelo se aplicó
        local newMdl = ent.GetModelName();
        if (newMdl && newMdl.tolower().find("kamikaze") != null) {
            Dbg("CONVERSION OK: entIdx=" + idx + " model=infected/kamikaze.mdl HP=50")
        } else {
            DbgWarn("CONVERSION FAILED: SetModel no cambió el modelo. old=" + mdl + " new=" + (newMdl || "null"))
        }
    }

    //------------------------------------------------------------
    // EXPLOSION ON HIT
    //------------------------------------------------------------
	function HandlePlayerHurt(params)
	{
		// 🛡️ CRITICAL: prevent recursive damage loops from kamikaze AoE
		if (this._processingKamikazeHurt) return;
		this._processingKamikazeHurt = true;

		// player_hurt: attackerentid = entindex cuando el atacante es CI (no player)
		if (!("attackerentid" in params) || !params.attackerentid) {
			this._processingKamikazeHurt = false;
			return;
		}

		local infected = EntIndexToHScript(params.attackerentid);
		if (!infected || !infected.IsValid()) {
			this._processingKamikazeHurt = false;
			return;
		}
		if (infected.GetClassname() != "infected") {
			this._processingKamikazeHurt = false;
			return;
		}

		infected.ValidateScriptScope();
		local s = infected.GetScriptScope();
		if (!("IsKamikaze" in s)) {
			this._processingKamikazeHurt = false;
			return;
		}

		Dbg("KAMIKAZE EXPLOSION TRIGGERED by hitting survivor");

		// Explode kamikaze
		local origin = infected.GetOrigin();

		// Damage entities in radius
		local ent = null;
		while (ent = Entities.FindByClassnameWithin(ent, "player", origin, settings.explosion_radius)) {
			if (ent != infected && ent.IsValid()) {
				local dist = (ent.GetOrigin() - origin).Length();
				local dmg = settings.explosion_damage * (1.0 - dist / settings.explosion_radius);
				if (dmg > 0) ent.TakeDamage(dmg, 0, infected);
			}
		}

		// Visual explosion effect — DIRECTA, sin DoEntFire diferido
		try { MaoLib_VFX.SpawnExplosion(origin, "medium"); }
		catch (e) { DbgWarn("SpawnExplosion failed: " + e); }

		// Kill the kamikaze
		this._processingKamikazeHurt = false;
		infected.Kill();
	}

	function OnGameEvent_player_hurt(params) { HandlePlayerHurt(params); }

    //------------------------------------------------------------
    // DROP PIPE BOMB ON DEATH
    //------------------------------------------------------------
    function DropPipeBomb(ent)
    {
        if (!ent || !ent.IsValid()) return;
        if (RandomInt(1, 100) > settings.pipebomb_drop_chance) return;

        local origin = ent.GetOrigin();
        local bomb = SpawnEntityFromTable("prop_physics", {
            origin = origin,
            targetname = "kamikaze_pipebomb",
            model = "models/w_models/weapons/w_eq_pipebomb.mdl",
            spawnflags = 0
        });

        if (bomb && bomb.IsValid())
        {
            // Auto-explode after 3s. Si no hay player cerca, cleanup. — DelayCall one-shot
            ::MaoLib.DelayCall(function() {
                if (!bomb || !bomb.IsValid()) return;

                local bombOrigin = bomb.GetOrigin();
                local p = Entities.FindByClassnameWithin(null, "player", bombOrigin, 150);

                if (p) {
                    try { MaoLib_VFX.SpawnExplosion(bombOrigin, "medium"); }
                    catch (e) { DbgWarn("PipeBomb SpawnExplosion failed: " + e); }
                    DoEntFire("!self", "Break", "", 0, null, bomb);
                } else {
                    // No player nearby — silent cleanup
                    bomb.Kill();
                }
            }, 3.0);
        }
    }
}

//------------------------------------------------------------
::nanas_kamikaze <- nanas_kamikaze;
__CollectGameEventCallbacks(nanas_kamikaze)
IncludeScript("kamikaze/common_anim_fix2.nut", getroottable());
try { nanas_kamikaze.LoadSettings(); } catch (e) { printl("[Kamikaze][ERR] LoadSettings: " + e); }
