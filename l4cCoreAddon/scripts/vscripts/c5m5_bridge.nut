Msg("Initiating c5m5_bridge\n");

	DirectorOptions	<-
	{
	
		IntensityRelaxThreshold = 0.99
		RelaxMinInterval = 5
		RelaxMaxInterval = 15
		RelaxMaxFlowTravel = 400
		
		Convars.SetValue( "z_spawn_mobs_behind_chance", "0" );
		SetConVarInt = "z_spawn_mobs_behind_chance" 0