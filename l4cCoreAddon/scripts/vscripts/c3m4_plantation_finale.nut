
//-----------------------------------------------------
local PANIC = 0
local TANK = 1
local DELAY = 2
//-----------------------------------------------------

DirectorOptions <-
{
	//-----------------------------------------------------

	 D_CustomFinale_StageCount = 10
	 
	 D_CustomFinale1 = PANIC
	 D_CustomFinaleValue1 = 3
	 
	 D_CustomFinale2 = DELAY
	 D_CustomFinaleValue2 = 5
	 
	 D_CustomFinale3 = TANK
	 D_CustomFinaleValue3 = 1
	 
	 D_CustomFinale4 = DELAY
	 D_CustomFinaleValue4 = 20
	 D_CustomFinaleMusic4 = "Event.FinaleWave4"
	 
	 D_CustomFinale5 = PANIC
	 D_CustomFinaleValue5 = 2
	 
	 D_CustomFinale6 = DELAY
	 D_CustomFinaleValue6 = 15

	 D_CustomFinale7 = PANIC
	 D_CustomFinaleValue7 = 2

	 D_CustomFinale8 = DELAY
	 D_CustomFinaleValue8 = 20

	 D_CustomFinale9 = TANK
	 D_CustomFinaleValue9 = 2

	 D_CustomFinale10 = DELAY
	 D_CustomFinaleValue10 = 10
	 
SpecialRespawnInterval = 60

	//-----------------------------------------------------
	ProhibitBosses = false
	ZombieSpawnRange = 3000
	MobRechargeRate = 0.5
	HordeEscapeCommonLimit = 60
	BileMobSize = 50
	
	MobSpawnMinTime = 2
	MobSpawnMaxTime = 4
	MobMinSize = 50
	MobMaxSize = 60
	CommonLimit = 60
}

