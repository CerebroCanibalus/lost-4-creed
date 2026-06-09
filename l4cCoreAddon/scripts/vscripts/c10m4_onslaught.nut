Msg("Initiating c10m4 Onslaught\n");

DirectorOptions <-
{
	// This turns off tanks and witches.
	ProhibitBosses = true

	PreferredMobDirection = SPAWN_IN_FRONT_OF_SURVIVORS
	MobSpawnMinTime = 1
	MobSpawnMaxTime = 5
	MobMaxPending = 60
	MobMinSize = 60
	MobMaxSize = 65
	SustainPeakMinTime = 1
	SustainPeakMaxTime = 3
	IntensityRelaxThreshold = 0.90
	RelaxMinInterval = 5
	RelaxMaxInterval = 10
	RelaxMaxFlowTravel = 200
	SpecialRespawnInterval = 15
	MaxSpecials = 1
        SmokerLimit = 0
        JockeyLimit = 0
        BoomerLimit = 1
        HunterLimit = 0
        ChargerLimit = 0
		SpitterLimit = 0
}

Director.ResetMobTimer()
Director.PlayMegaMobWarningSounds()
