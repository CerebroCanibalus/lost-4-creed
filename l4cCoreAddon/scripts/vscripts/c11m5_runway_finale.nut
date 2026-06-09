//-----------------------------------------------------
//
//
//-----------------------------------------------------
Msg("Initiating c11m5_runway_finale script\n");

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
	StageDelay <- 10
	PreEscapeDelay <- 10
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
	A_CustomFinaleMusic4 	= "Event.FinaleWave4"
	A_CustomFinale5 		= PANIC
	A_CustomFinaleValue5 	= 2
	A_CustomFinale6 		= DELAY
	A_CustomFinaleValue6 	= StageDelay
	A_CustomFinale7 		= PANIC
	A_CustomFinaleValue7 	= 2
	A_CustomFinale8 		= DELAY
	A_CustomFinaleValue8 	= StageDelay
	A_CustomFinale9 		= TANK
	A_CustomFinaleValue9 	= 2
	A_CustomFinale10 		= DELAY
	A_CustomFinaleValue10 	= PreEscapeDelay
	
	TankLimit = 3
	WitchLimit = 0
	CommonLimit = 60
	HordeEscapeCommonLimit = 60
	EscapeSpawnTanks = true
	//SpecialRespawnInterval = 80
	BileMobSize = 50
	
	MusicDynamicMobSpawnSize = 8
	MusicDynamicMobStopSize = 2
	MusicDynamicMobScanStopSize = 1
}

InitialPanicOptions <-
{
	ShouldConstrainLargeVolumeSpawn = true
	MobSpawnMinTime = 4
	MobSpawnMaxTime = 8
	MobMinSize = 50
	MobMaxSize = 60
	CommonLimit = 60
}

PanicOptions <-
{
	CommonLimit = 100
	MegaMobMinSize = 20
	MegaMobMaxSize = 60
    MaxSpecials = 2
    SpecialRespawnInterval = 40
}

TankOptions <-
{
	ShouldAllowSpecialsWithTank = true
	MobSpawnMinTime = 15
	MobSpawnMaxTime = 30
	MobMinSize = 30
	MobMaxSize = 50
	CommonLimit = 50
	MaxSpecials = 1
	TankRunSpawnDelay = 30
	SpecialRespawnInterval = 60
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
		EntFire( "orator_plane_radio", "SpeakResponseConcept", "plane_radio_intransit" );
}