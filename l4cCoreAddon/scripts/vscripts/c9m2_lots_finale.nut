//-----------------------------------------------------
//
//
//-----------------------------------------------------
Msg("Initiating c9m2_lots_finale script\n");

//-----------------------------------------------------
ERROR		<- -1
PANIC 		<- 0
TANK 		<- 1
DELAY 		<- 2
SCRIPTED 	<- 3
//-----------------------------------------------------

StageDelay <- 0
PreEscapeDelay <- 0
if ( Director.GetGameModeBase() == "coop" || Director.GetGameModeBase() == "realism" )
{
	StageDelay <- 15
	PreEscapeDelay <- 15
}
else if ( Director.GetGameModeBase() == "versus" )
{
	StageDelay <- 15
	PreEscapeDelay <- 15
}

DirectorOptions <-
{	
	A_CustomFinale_StageCount = 10
	
	A_CustomFinale1 		= PANIC
	A_CustomFinaleValue1 	= 1
	A_CustomFinale2 		= PANIC
	A_CustomFinaleValue2 	= 2
	A_CustomFinale3 		= DELAY
	A_CustomFinaleValue3 	= StageDelay
	A_CustomFinale4		    = TANK
	A_CustomFinaleValue4 	= 1
	A_CustomFinale5 		= DELAY
	A_CustomFinaleValue5 	= StageDelay
	A_CustomFinaleMusic5 	= "Event.FinaleWave4"
	A_CustomFinale6 		= PANIC
	A_CustomFinaleValue6 	= 2
	A_CustomFinale7 		= DELAY
	A_CustomFinaleValue7 	= StageDelay
	A_CustomFinale8 		= PANIC
	A_CustomFinaleValue8	= 2
	A_CustomFinale9 		= TANK
	A_CustomFinaleValue9 	= 1
	A_CustomFinale10 		= DELAY
	A_CustomFinaleValue10 	= PreEscapeDelay
	
	
	PreferredMobDirection = SPAWN_ANYWHERE
	TankLimit = 1
	WitchLimit = 0
	CommonLimit = 60
	HordeEscapeCommonLimit = 60
	EscapeSpawnTanks = false
	MobSpawnMinTime = 4
	MobSpawnMaxTime = 8
	MobMinSize = 40
	MobMaxSize = 60
	BileMobSize = 50
	//SpecialRespawnInterval = 90

}


function EnableEscapeTanks()
{
	printl( "Chase Tanks Enabled!" );
	
	MapScript.DirectorOptions.EscapeSpawnTanks <- true
}