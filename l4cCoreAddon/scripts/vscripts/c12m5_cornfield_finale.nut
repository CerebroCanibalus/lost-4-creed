//-----------------------------------------------------
//
//
//-----------------------------------------------------
Msg("Initiating c12m5_cornfield_finale script\n");

//-----------------------------------------------------
ERROR		<- -1
PANIC 		<- 0
TANK 		<- 1
DELAY 		<- 2
SCRIPTED 	<- 3
//-----------------------------------------------------

StageDelay <- 0
if ( Director.GetGameMode() == "coop" )
{
	StageDelay <- 15
}
else if ( Director.GetGameMode() == "versus" )
{
	StageDelay <- 15
}

PreEscapeDelay <- 0
if ( Director.GetGameMode() == "coop" )
{
	PreEscapeDelay <- 15
}
else if ( Director.GetGameMode() == "versus" )
{
	PreEscapeDelay <- 15
}

DirectorOptions <-
{	
	 
	A_CustomFinale_StageCount = 11
	 
	A_CustomFinale1 		= PANIC
	A_CustomFinaleValue1 	= 1
	A_CustomFinale2 		= PANIC
	A_CustomFinaleValue2 	= 2
	A_CustomFinale3 		= DELAY
	A_CustomFinaleValue3 	= StageDelay	
	A_CustomFinale4 		= TANK
	A_CustomFinaleValue4 	= 1
	A_CustomFinale5 		= DELAY
	A_CustomFinaleValue5 	= StageDelay	
	A_CustomFinaleMusic5 	= "Event.FinaleWave4"
	A_CustomFinale6 		= PANIC
	A_CustomFinaleValue6 	= 2
	A_CustomFinale7 		= DELAY
	A_CustomFinaleValue7 	= StageDelay
	A_CustomFinale8 		= PANIC
	A_CustomFinaleValue8 	= 2	
	A_CustomFinale9 		= DELAY
	A_CustomFinaleValue9	= StageDelay
	A_CustomFinale10 		= TANK
	A_CustomFinaleValue10 	= 1
	A_CustomFinale11 		= DELAY
	A_CustomFinaleValue11 	= PreEscapeDelay
	 
	 
	TankLimit = 1
	WitchLimit = 1
	CommonLimit = 60	
	ProhibitBosses = false
	ZombieSpawnRange = 3000
	MobRechargeRate = 0.5
	HordeEscapeCommonLimit = 60
	BileMobSize = 50
	MobSpawnMinTime = 4
	MobSpawnMaxTime = 8
	MobMinSize = 40
	MobMaxSize = 60
	EscapeSpawnTanks = true
	//SpecialRespawnInterval = 80

}


function EnableEscapeTanks()
{
	printl( "Chase Tanks Enabled!" );
	
	MapScript.DirectorOptions.EscapeSpawnTanks <- true
}