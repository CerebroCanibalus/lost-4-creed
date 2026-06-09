//-----------------------------------------------------
//
//
//-----------------------------------------------------
Msg("Initiating c8m5_rooftop_finale script\n");

//-----------------------------------------------------
ERROR		<- -1
PANIC 		<- 0
TANK 		<- 1
DELAY 		<- 2
SCRIPTED 	<- 3
//-----------------------------------------------------

StageDelay <- 15
PreEscapeDelay <- 15
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
	A_CustomFinaleValue1 	= 3
	A_CustomFinale2 		= DELAY
	A_CustomFinaleValue2 	= StageDelay
	A_CustomFinale3 		= TANK
	A_CustomFinaleValue3 	= 1
	A_CustomFinale4 		= DELAY
	A_CustomFinaleValue4 	= StageDelay
	A_CustomFinaleMusic4    = "Event.FinaleWave4"
	A_CustomFinale5 		= PANIC
	A_CustomFinaleValue5 	= 2
	A_CustomFinale6 		= DELAY
	A_CustomFinaleValue6 	= StageDelay
	A_CustomFinale7 		= PANIC
	A_CustomFinaleValue7 	= 2
	A_CustomFinale8 		= DELAY
	A_CustomFinaleValue8 	= StageDelay
	A_CustomFinale9 		= TANK
	A_CustomFinaleValue9 	= 1
	A_CustomFinale10 		= DELAY
	A_CustomFinaleValue10 	= PreEscapeDelay
	 
	 
	TankLimit = 1
	WitchLimit = 0
	CommonLimit = 60
	ProhibitBosses = false
	ZombieSpawnRange = 3000
	MobRechargeRate = 0.5
	HordeEscapeCommonLimit = 60
	BileMobSize = 50
	EscapeSpawnTanks = false
	MobSpawnMinTime = 1
	MobSpawnMaxTime = 4
	MobMinSize = 40
	MobMaxSize = 60
	PreferredMobDirection = SPAWN_ANYWHERE
	//SpecialRespawnInterval = 80

}

InitialPanicOptions <-
{
	ShouldConstrainLargeVolumeSpawn = true
	MobSpawnMinTime = 4
	MobSpawnMaxTime = 8
	MobMinSize = 60
	MobMaxSize = 70
	CommonLimit = 60
}

PanicOptions <-
{
	CommonLimit = 60
	MegaMobMinSize = 50
	MegaMobMaxSize = 60
    MaxSpecials = 2
    SpecialRespawnInterval = 20
}

TankOptions <-
{
	ShouldAllowSpecialsWithTank = false
	ShouldAllowMobsWithTank = true
	MobSpawnMinTime = 15
	MobSpawnMaxTime = 45
	MobMinSize = 15
	MobMaxSize = 30
	CommonLimit = 50
	MaxSpecials = 0
	SpecialRespawnInterval = 45
}

function EnableEscapeTanks()
{
	printl( "Chase Tanks Enabled!" );
	
	MapScript.DirectorOptions.EscapeSpawnTanks <- true
}

function OnBeginCustomFinaleStage( num, type )
{
	//printl( "Beginning custom finale stage " + num + " of type " + type );
	
	if ( type == 2 )
		EntFire( "pilot", "SpeakResponseConcept", "hospital_radio_intransit" );
}