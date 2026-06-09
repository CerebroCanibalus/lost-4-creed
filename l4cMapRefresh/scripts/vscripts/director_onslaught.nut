Msg("Initiating Director Onslaught\n");

DirectorOptions <-
{
	// This turns off tanks and witches.
	ProhibitBosses = true
	
	//LockTempo = true
	WanderingZombieDensityModifier = 0.20
	MobSpawnMinTime = 3
	MobSpawnMaxTime = 3
	MobMinSize = 30
	MobMaxSize = 40
	MobMaxPending = 40
	SustainPeakMinTime = 15
	SustainPeakMaxTime = 30
	IntensityRelaxThreshold = 0.99
	RelaxMinInterval = 5
	RelaxMaxInterval = 10
	RelaxMaxFlowTravel = 50
	ShouldAllowSpecialsWithTank = true
	SpecialRespawnInterval = 30
        SmokerLimit = 1
        JockeyLimit = 1
        BoomerLimit = 1
        HunterLimit = 1
        ChargerLimit = 1
		SpitterLimit = 2
	ZombieSpawnRange = 1600
	PreferredMobDirection = SPAWN_BEHIND_SURVIVORS
}

Director.ResetMobTimer()

if ( Director.GetGameMode() == "versus" )
{
    DirectorOptions.IntensityRelaxThreshold <- 0.8;
}