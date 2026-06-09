Msg("Initiating Finale Onslaught\n");

DirectorOptions <-
{
	// This turns off tanks and witches (when true).
	ProhibitBosses = true
	
	//LockTempo = false

	// Sets the time between mob spawns. Mobs can only spawn when the pacing is in the BUILD_UP state.
	MobSpawnMinTime = 1
	MobSpawnMaxTime = 1

	// How many zombies are in each mob.
	CommonLimit = 60
	MobMinSize = 60
	MobMaxSize = 70
	MobMaxPending = 60

	// Modifies the length of the SUSTAIN_PEAK and RELAX states to shorten the time between mob spawns.
	SustainPeakMinTime = 5
	SustainPeakMaxTime = 10
	IntensityRelaxThreshold = 0.99
	RelaxMinInterval = 1
	RelaxMaxInterval = 5
	RelaxMaxFlowTravel = 50

	//Special infected options
	SpecialRespawnInterval = 30
	    MaxSpecials = 1
        SmokerLimit = 0
        JockeyLimit = 0
        BoomerLimit = 1
        HunterLimit = 1
        ChargerLimit = 0
		SpitterLimit = 0

	// Valid spawn locations
	PreferredMobDirection = SPAWN_NO_PREFERENCE
	ZombieSpawnRange = 3000
}

Director.ResetMobTimer()
 
if ( Director.GetGameMode() == "versus" )
{
    DirectorOptions.IntensityRelaxThreshold <- 0.8;
}