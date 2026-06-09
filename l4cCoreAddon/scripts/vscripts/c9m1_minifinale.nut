Msg("Initiating c9m1 minifinale\n");

//-----------------------------------------------------
local PANIC = 0
local TANK = 1
local DELAY = 2
local SCRIPTED = 3
//-----------------------------------------------------


DirectorOptions <-
{

	A_CustomFinale_StageCount = 1

 	A_CustomFinale1 = PANIC
	A_CustomFinaleValue1 = 2

	MaxSpecials = 2
	
	SpecialRespawnInterval = 30
	
	CommonLimit = 60
	
	PreferredMobDirection = SPAWN_ANYWHERE
	//PreferredSpecialDirection = SPAWN_IN_FRONT_OF_SURVIVORS
}

//-----------------------------------------------------


/*
*/