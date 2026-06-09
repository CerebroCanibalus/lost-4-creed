
//-----------------------------------------------------
local PANIC = 0
local TANK = 1
local DELAY = 2
//-----------------------------------------------------

// default finale patten - for reference only

/*
CustomFinale1 <- PANIC
CustomFinaleValue1 <- 2

CustomFinale2 <- DELAY
CustomFinaleValue2 <- 10

CustomFinale3 <- PANIC
CustomFinaleValue3 <- 1

CustomFinale4 <- DELAY
CustomFinaleValue4 <- 10

CustomFinale5 <- PANIC
CustomFinaleValue5 <- 2

CustomFinale6 <- DELAY
CustomFinaleValue6 <- 10

CustomFinale7 <- PANIC
CustomFinaleValue7 <- 1

CustomFinale8 <- DELAY
CustomFinaleValue8 <- 2
*/

DirectorOptions <-
{
	//-----------------------------------------------------

	// 3 waves of mobs in between tanks

	 A_CustomFinale_StageCount = 8
	 
	 A_CustomFinale1 = PANIC
	 A_CustomFinaleValue1 = 3
	 
	 A_CustomFinale2 = DELAY
	 A_CustomFinaleValue2 = 15
	 
	 A_CustomFinale3 = TANK
	 A_CustomFinaleValue3 = 1
	 
	 A_CustomFinale4 = DELAY
	 A_CustomFinaleValue4 = 20
	 A_CustomFinaleMusic4 = "Event.FinaleWave4"
	 
	 A_CustomFinale5 = PANIC
	 A_CustomFinaleValue5 = 4
	 
	 A_CustomFinale6 = DELAY
	 A_CustomFinaleValue6 = 20
	 
	 A_CustomFinale7 = TANK
	 A_CustomFinaleValue7 = 1
	 
	 A_CustomFinale8 = DELAY
	 A_CustomFinaleValue8 = 15
	 
	 
	HordeEscapeCommonLimit = 55
	CommonLimit = 60
	SpecialRespawnInterval = 80	
	MobSpawnMinTime = 4
	MobSpawnMaxTime = 8
	MobMinSize = 50
	MobMaxSize = 60
	ProhibitBosses = false
	ZombieSpawnRange = 3000
	MobRechargeRate = 0.5
	BileMobSize = 50
	EscapeSpawnTanks = false


}


if ( "DirectorOptions" in LocalScript && "ProhibitBosses" in LocalScript.DirectorOptions )
{
	delete LocalScript.DirectorOptions.ProhibitBosses
}

/*
*/