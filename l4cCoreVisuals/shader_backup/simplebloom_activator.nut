SimpleBloom_Activator <-
{
	function OnGameEvent_player_spawn(params)
	{
		local simplebloom_activator = null;
		while (simplebloom_activator = Entities.FindByName(simplebloom_activator, "simplebloom_entity"))
		{
			simplebloom_activator.Kill();
		}
		
		SpawnEntityFromTable("env_screenoverlay",
		{
			targetname      = "simplebloom_entity",
			OverlayName1    = "effects/shaders/simple_bloom",
			OverlayTime1    = -1,
		});
		EntFire("simplebloom_entity", "StartOverlays");
	}
}

__CollectEventCallbacks(SimpleBloom_Activator, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);