// weird_ai.nut - Bot coordination on SI ability use
// Migrated to MaoLib.Events.Register()
// Hace que survivor bots ataquen SI que usan habilidades (jockey ride, etc.)

::g_WeirdAI <- {
	function HandleRoundStartPostNav(params) {
		Convars.SetValue("sv_consistency", 0);
	}

	function HandleAbilityUse(params) {
		local specialinfected = GetPlayerFromUserID(params.userid);
		if (!specialinfected) return;
		
		local survivorteam = null;
		while (survivorteam = Entities.FindByClassname(survivorteam, "player")) {
			if (survivorteam.IsSurvivor() && IsPlayerABot(survivorteam)) {
				CommandABot({ cmd = 0  /* BOT_CMD_ATTACK */, bot = survivorteam, target = specialinfected });
			}
		}
	}

	function HandleJockeyRide(params) {
		local jockey = GetPlayerFromUserID(params.userid);
		if (!jockey) return;
		
		local survivorteam = null;
		while (survivorteam = Entities.FindByClassname(survivorteam, "player")) {
			if (survivorteam.IsSurvivor() && IsPlayerABot(survivorteam)) {
				CommandABot({ cmd = 0  /* BOT_CMD_ATTACK */, bot = survivorteam, target = jockey });
			}
		}
	}
	
	function OnGameEvent_round_start_post_nav(params) {
		HandleRoundStartPostNav(params);
	}

	function OnGameEvent_ability_use(params) {
		HandleAbilityUse(params);
	}

	function OnGameEvent_jockey_ride(params) {
		HandleJockeyRide(params);
	}
}

__CollectGameEventCallbacks(::g_WeirdAI);
