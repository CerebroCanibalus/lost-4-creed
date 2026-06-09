nanas_corpse_eater <-
{
	Debug = 1

	// 🛡️ CRITICAL: Damage recursion guard. TakeDamage() inside HandlePlayerHurt
	// fires another player_hurt event. Without this flag, corpse-eater bleed deaths
	// can cascade into infinite recursion across nearby infected.
	_processingCorpseHurt = false

	function Dbg(msg) {
		if (Debug) printl("[CorpseEater][DEBUG] " + msg)
	}

	function DbgWarn(msg) {
		printl("[CorpseEater][WARN] " + msg)
	}

	settings =
	{
		corpse_eater_chance = 35, 
		bleed_amount = 10
	}

	//------------------------------------------------------------
	// SETTINGS
	//------------------------------------------------------------
	function LoadSettings()
	{
		local path = "corpse_eater/settings.cfg";
		local file = FileToString(path);

		if (file != null)
		{
			local lines = split(file, "\n");
			foreach (line in lines)
			{
				line = strip(line);
				if (line == "" || line.find("//") == 0) continue;

				local parts = split(line, "=");
				if (parts.len() == 2)
				{
					local key = strip(parts[0]);
					local val = strip(parts[1]);

					if (key in settings)
					{
						if (val.find(".") != null)
							settings[key] = val.tofloat();
						else
							settings[key] = val.tointeger();
					}
				}
			}
			printl("[corpse_eater] Settings loaded");
		}
		else
		{
			SaveSettings();
		}
	}

	function SaveSettings()
	{
		local path = "corpse_eater/settings.cfg";
		local content = "";
		foreach (key, val in settings)
			content += key + " = " + val.tostring() + "\n";
		StringToFile(path, content);
	}

	//------------------------------------------------------------
	// ROUND START
	//------------------------------------------------------------
	function OnGameEvent_round_start(params)
	{
		Dbg("round_start: loading settings + precaching")
		LoadSettings();

		if (!IsModelPrecached("models/infected/corpseeater.mdl"))
			PrecacheModel("models/infected/corpseeater.mdl");

		if (::MaoLib.IsTimerActive("corpse_scan"))
			::MaoLib.RemoveTimer("corpse_scan")

		// thinker via MaoLib (evita entity leak)
		::MaoLib.AddTimer("corpse_scan", 0.5, function() {
			::nanas_corpse_eater.ScanCommons()
		})
		Dbg("Timer corpse_scan started")
	}

	function OnGameEvent_round_end(params)      { Cleanup() }
	function OnGameEvent_mission_lost(params)  { Cleanup() }
	function OnGameEvent_map_transition(params){ Cleanup() }

	function Cleanup()
	{
 		::MaoLib.RemoveTimer("corpse_scan")
	}

	//------------------------------------------------------------
	// REGULAR COMMON CHECK (EXCLUDES UNCOMMONS)
	//------------------------------------------------------------
	function IsRegularCommon(common)
	{
		local mdl = common.GetModelName();
		if (!mdl) return false;

		mdl = mdl.tolower();

		if (mdl.find("riot")   != null) return false;
		if (mdl.find("hazmat") != null) return false;
		if (mdl.find("mud")    != null) return false;
		if (mdl.find("clown")  != null) return false;
		if (mdl.find("ceda")   != null) return false;
		if (mdl.find("roadcrew") != null) return false;
	    if (mdl.find("fallen")   != null) return false;
		if (mdl.find("jimmy")   != null) return false;

		return true;
	}

	//------------------------------------------------------------
	// MAIN SCAN (CALLED BY logic_timer)
	//------------------------------------------------------------
	function ScanCommons()
	{
		local common = null;

		while (common = Entities.FindByClassname(common, "infected"))
		{
			if (!common || common.GetHealth() <= 0)
				continue;

			if (!IsRegularCommon(common))
				continue;

			if (!common.ValidateScriptScope())
				continue;

			local scope = common.GetScriptScope();

			// one roll per common
			if ("CorpseEaterChecked" in scope)
				continue;

			scope.CorpseEaterChecked <- 1;

			if (RandomInt(1, settings.corpse_eater_chance) == 1)
			{
				DelayedConvertCorpse_Eater(common.GetEntityIndex());
			}
		}
	}

	//------------------------------------------------------------
	// CONVERSION
	//------------------------------------------------------------
	function DelayedConvertCorpse_Eater(ent_idx)
	{
		local common = EntIndexToHScript(ent_idx);
		if (!common || common.GetClassname() != "infected" || common.GetHealth() <= 0) {
			Dbg("Convert: ent invalid or dead (idx=" + ent_idx + ")")
			return
		}

		// Defensive model check — avoid overwriting other custom types
		local mdl = common.GetModelName();
		if (mdl) {
			mdl = mdl.tolower();
			if (mdl.find("kamikaze") != null) return;
			if (mdl.find("sewer_worker") != null) return;
			if (mdl.find("prisoner") != null) return;
			if (mdl.find("blood") != null) return;
		}

		common.ValidateScriptScope();
		local scope = common.GetScriptScope();

		if ("IsCorpse_Eater" in scope)
			return;

		scope.IsCorpse_Eater <- 1;

		// model
		common.SetModel("models/infected/corpseeater.mdl");

		// health (netprops so it sticks)
		local hp = 100;
		NetProps.SetPropInt(common, "m_iMaxHealth", hp);
		NetProps.SetPropInt(common, "m_iHealth", hp);

		NetProps.SetPropInt(
			common,
			"m_fFlags",
			NetProps.GetPropInt(common, "m_fFlags") & ~256
		);

		NetProps.SetPropIntArray(common,
			"m_NetGestureSequence",
			common.LookupSequence("ACT_RUN"), 6);
		NetProps.SetPropIntArray(common,
			"m_NetGestureActivity",
			common.LookupActivity("ACT_RUN"), 6);
		NetProps.SetPropFloatArray(common,
			"m_NetGestureStartTime",
			Time(), 6);

		// Verificar modelo aplicado
		local newMdl = common.GetModelName();
		if (newMdl && newMdl.tolower().find("corpseeater") != null) {
			Dbg("CONVERSION OK: entIdx=" + ent_idx + " model=infected/corpseeater.mdl HP=100")
		} else {
			DbgWarn("CONVERSION FAILED: SetModel no cambió el modelo. old=" + (common.GetModelName() || "null") + " new=" + (newMdl || "null"))
		}
	}

	//------------------------------------------------------------
	// BLEED MECHANIC
	//------------------------------------------------------------
	function HandlePlayerHurt(params)
	{
		// 🛡️ CRITICAL: prevent recursive damage loops from corpse-eater lethal bleed
		if (this._processingCorpseHurt) return;
		this._processingCorpseHurt = true;

		// player_hurt: userid=víctima survivor, attackerentid=entindex del CI atacante
		if (!("userid" in params)) {
			this._processingCorpseHurt = false;
			return;
		}

		local victim = GetPlayerFromUserID(params.userid);
		if (!victim || !victim.IsValid() || !victim.IsSurvivor()) {
			this._processingCorpseHurt = false;
			return;
		}

		if (!("attackerentid" in params) || !params.attackerentid) {
			this._processingCorpseHurt = false;
			return;
		}

		local attacker = EntIndexToHScript(params.attackerentid);
		if (!attacker || !attacker.IsValid() || attacker.GetClassname() != "infected") {
			this._processingCorpseHurt = false;
			return;
		}

		try { attacker.ValidateScriptScope(); } catch (e) { DbgWarn("ValidateScriptScope failed: " + e); }
		local scope = attacker.GetScriptScope();

		if (!scope || !("IsCorpse_Eater" in scope)) {
			this._processingCorpseHurt = false;
			return;
		}

		local bleed = settings.bleed_amount;
		local curHealth = victim.GetHealth();

		if (curHealth > bleed)
		{
			victim.SetHealth(curHealth - bleed);

			local curBuf = 0;
			try { curBuf = victim.GetHealthBuffer(); }
			catch (e) { curBuf = NetProps.GetPropFloat(victim, "m_healthBuffer"); }

			try { victim.SetHealthBuffer(curBuf + bleed); }
			catch (e) { NetProps.SetPropFloat(victim, "m_healthBuffer", curBuf + bleed); }
		}
		else
		{
			victim.TakeDamage(curHealth, 0, attacker);
		}

		this._processingCorpseHurt = false;
	}

	function OnGameEvent_player_hurt(params) { HandlePlayerHurt(params); }
}

//------------------------------------------------------------
// REGISTER
//------------------------------------------------------------
::nanas_corpse_eater <- nanas_corpse_eater;
__CollectGameEventCallbacks(nanas_corpse_eater)
IncludeScript("corpse_eater/common_anim_fix4.nut", getroottable());
try { nanas_corpse_eater.LoadSettings(); } catch (e) { printl("[CorpseEater][ERR] LoadSettings: " + e); }