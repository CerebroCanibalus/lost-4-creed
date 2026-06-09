Msg("Initiating Fairgrounds Onslaught\n");

DirectorOptions <-
{
	// This turns off tanks and witches.
	ProhibitBosses = true

	// PreferredMobDirection = SPAWN_NEAR_POSITION     
	MobSpawnMinTime = 1
	MobSpawnMaxTime = 1
	MobMaxPending = 70
	MobMinSize = 55
	MobMaxSize = 65
	ZombieSpawnRange = 750
	SustainPeakMinTime = 5
	SustainPeakMaxTime = 7
	IntensityRelaxThreshold = 0.90
	RelaxMinInterval = 1
	RelaxMaxInterval = 1
	RelaxMaxFlowTravel = 50
	
	SpecialRespawnInterval = 10
	BoomerLimit = 2
}

Director.ResetMobTimer()
Director.PlayMegaMobWarningSounds()
