Convars.SetValue("sv_consistency", "0");
Convars.SetValue("sv_pure_kick_clients", "0");

RevisedMobRules <-
{
	// player_connect_full event does NOT exist in L4D2.
	// Difficulty setup now handled solely by OnGameEvent_difficulty_changed.
	
	function OnGameEvent_difficulty_changed(params)
	{
		if(params.newDifficulty == 0)
		{
			Convars.SetValue("music_dynamic_attack_CI_num", "22");
			printl("Revised Mob Rules: easy difficulty loaded");
		}
		if(params.newDifficulty == 1)
		{
			Convars.SetValue("music_dynamic_attack_CI_num", "15");
			printl("Revised Mob Rules: normal difficulty loaded");
		}
		if(params.newDifficulty == 2)
		{
			Convars.SetValue("music_dynamic_attack_CI_num", "12");
			printl("Revised Mob Rules: advanced difficulty loaded");
		}
		if(params.newDifficulty == 3)
		{
			Convars.SetValue("music_dynamic_attack_CI_num", "8");
			printl("Revised Mob Rules: expert difficulty loaded");
		}
	}
}

__CollectGameEventCallbacks(RevisedMobRules);