Msg("Initiating c11m2 Onslaught\n");

DirectorOptions <-
{
	ProhibitBosses = false
	
	MobSpawnMinTime = 1
	MobSpawnMaxTime = 2
	
	MobMaxPending = 70
	MobMinSize = 50
	MobMaxSize = 60
	
	SustainPeakMinTime = 10
	SustainPeakMaxTime = 15
	
	IntensityRelaxThreshold = 0.99
	
	RelaxMinInterval = 2
	RelaxMaxInterval = 4
	
	RelaxMaxFlowTravel = 400

	SpecialRespawnInterval = 15
	
	PreferredMobDirection = SPAWN_ANYWHERE
	PreferredSpecialDirection = SPAWN_ANYWHERE
	
	SpitterLimit = 1
	ChargerLimit = 1
	MaxSpecials = 2
	
	CommonLimit = 60
	
	MusicDynamicMobSpawnSize = 12
	MusicDynamicMobScanStopSize = 2
	MusicDynamicMobStopSize = 4
}

Director.ResetMobTimer()
//Director.PlayMegaMobWarningSounds()
