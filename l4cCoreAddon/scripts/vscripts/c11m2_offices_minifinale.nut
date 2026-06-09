Msg("Initiating c11m2 minifinale\n");

const ERROR = -1
const PANIC = 0
const TANK = 1
const DELAY = 2
const SCRIPTED = 3 

DirectorOptions <-
{
	//-----------------------------------------------------
	A_CustomFinale_StageCount = 1 // Number of stages. Used for calculating the Versus score.
	
	A_CustomFinale1 = PANIC
	A_CustomFinaleValue1 = 1
	
	//-----------------------------------------------------

	CommonLimit = 60
	SpecialRespawnInterval = 15
	MaxSpecials = 3
	MobSpawnMinTime = 1
	MobSpawnMaxTime = 2
	ProhibitBosses = false
	MobMinSize = 50
	MobMaxSize = 60
	
	PreferredMobDirection = SPAWN_ANYWHERE
	PreferredSpecialDirection = SPAWN_ANYWHERE
}