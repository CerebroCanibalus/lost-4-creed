Msg("Beginning Lighthouse Scavenge.\n")

DirectorOptions <-
{
	CommonLimit = 60
	MobSpawnMinTime = 10
	MobSpawnMaxTime = 20
	MobMinSize = 50
	MobMaxSize = 80
	MobMaxPending = 45
	IntensityRelaxThreshold = 0.99
	RelaxMinInterval = 15
	RelaxMaxInterval = 20
	RelaxMaxFlowTravel = 100
	SpecialRespawnInterval = 60
	LockTempo = true
	PreferredMobDirection = SPAWN_ANYWHERE
	PanicForever = true
}

Director.ResetMobTimer();