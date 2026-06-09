Msg("Initiating Church Minifinale\n");

const ERROR = -1
const PANIC = 0
const TANK = 1
const DELAY = 2
const SCRIPTED = 3

DirectorOptions <-
{
	//-----------------------------------------------------
	A_CustomFinale_StageCount = 2 // Number of stages. Used for calculating the Versus score.
	
	A_CustomFinale1 = PANIC
	A_CustomFinaleValue1 = 2
	
	A_CustomFinale2 = PANIC
	A_CustomFinaleValue2 = 1
	
	//-----------------------------------------------------

	CommonLimit = 60
	SpecialRespawnInterval = 15
	MaxSpecials = 3
	MobSpawnMinTime = 1
	MobSpawnMaxTime = 2
	ProhibitBosses = false
	MobMinSize = 50
	MobMaxSize = 70
	
	PreferredMobDirection = SPAWN_ABOVE_SURVIVORS
	PreferredSpecialDirection = SPAWN_ABOVE_SURVIVORS

	MusicDynamicMobSpawnSize = 3			
	MusicDynamicMobStopSize = 2			
	MusicDynamicMobScanStopSize = 1			
}
