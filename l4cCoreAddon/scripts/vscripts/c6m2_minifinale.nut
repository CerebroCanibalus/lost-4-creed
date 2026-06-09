Msg("Initiating Onslaught\n");

DirectorOptions <-
{
	// This turns off tanks and witches.
	ProhibitBosses = false

	MobSpawnMinTime = 2
	MobSpawnMaxTime = 4
	MobMinSize = 60
	MobMaxSize = 70
	SustainPeakMinTime = 1
	SustainPeakMaxTime = 3
	IntensityRelaxThreshold = 1.0
	RelaxMinInterval = 5
	RelaxMaxInterval = 5
	RelaxMaxFlowTravel = 600

	MobMaxPending = 50


	//-----------------------------------------------------
	// This is the variable that you have to set in order
	// to influence the direction of mob spawns.
	//-----------------------------------------------------
	PreferredMobDirection = SPAWN_IN_FRONT_OF_SURVIVORS

	ZombieSpawnRange = 3000

}

Director.ResetMobTimer()
