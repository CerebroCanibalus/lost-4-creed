Msg("Initiating Barns Onslaught\n");

DirectorOptions <-
{
	// This turns off tanks and witches.
	ProhibitBosses = true
	
	//LockTempo = true
	MobSpawnMinTime = 3
	MobSpawnMaxTime = 7
	MobMinSize = 50
	MobMaxSize = 60
	MobMaxPending = 60
	SustainPeakMinTime = 5
	SustainPeakMaxTime = 10
	IntensityRelaxThreshold = 0.99
	RelaxMinInterval = 1
	RelaxMaxInterval = 5
	RelaxMaxFlowTravel = 50
	SpecialRespawnInterval = 180
        SmokerLimit = 0
        JockeyLimit = 0
        BoomerLimit = 1
        HunterLimit = 0
        ChargerLimit = 0
		SpitterLimit = 0
	PreferredMobDirection = SPAWN_IN_FRONT_OF_SURVIVORS
	ZombieSpawnRange = 2000
}

Director.ResetMobTimer()

if ( Director.GetGameMode() == "versus" )
{
    DirectorOptions.IntensityRelaxThreshold <- 0.8;
}