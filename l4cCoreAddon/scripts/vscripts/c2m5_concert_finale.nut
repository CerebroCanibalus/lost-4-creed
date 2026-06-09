//-----------------------------------------------------------------------------

PANIC <- 0
TANK <- 1
DELAY <- 2
ONSLAUGHT <- 3

//-----------------------------------------------------------------------------

SharedOptions <-
{
	A_CustomFinale_StageCount = 9
	
 	A_CustomFinale1 = PANIC
	A_CustomFinaleValue1 = 1
	
 	A_CustomFinale2 = PANIC
	A_CustomFinaleValue2 = 2

	A_CustomFinale3 = DELAY
	A_CustomFinaleValue3 = 15

	A_CustomFinale4 = TANK
	A_CustomFinaleValue4 = 1
	A_CustomFinaleMusic4 = ""

	A_CustomFinale5 = DELAY
	A_CustomFinaleValue5 = 15

	A_CustomFinale6 = PANIC
	A_CustomFinaleValue6 = 4

	A_CustomFinale7 = DELAY
	A_CustomFinaleValue7 = 15

	A_CustomFinale8 = TANK
	A_CustomFinaleValue8 = 2
	A_CustomFinaleMusic8 = ""

	A_CustomFinale9 = DELAY
	A_CustomFinaleValue9 = RandomInt( 5, 10 )
	
	PreferredMobDirection = SPAWN_ANYWHERE
	PreferredSpecialDirection = SPAWN_ANYWHERE
	ShouldConstrainLargeVolumeSpawn = false

	MobSpawnMinTime = 4
	MobSpawnMaxTime = 8
	MobMinSize = 50
	MobMaxSize = 60
	CommonLimit = 60
    EscapeSpawnTanks = false
	
	BileMobSize = 50

	ZombieSpawnRange = 3000
	
	SpecialRespawnInterval = 20
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
	MobMinSize = 60
	MobMaxSize = 70
    MaxSpecials = 1
    SpecialRespawnInterval = 60
}

TankOptions <-
{
	ShouldAllowSpecialsWithTank = false
	ShouldAllowMobsWithTank = true
	MobSpawnMinTime = 60
	MobSpawnMaxTime = 120
	MobMinSize = 45
	MobMaxSize = 50
	CommonLimit = 50
	MaxSpecials = 0
	TankRunSpawnDelay = 30
	SpecialRespawnInterval = 30
}


DirectorOptions <- clone SharedOptions
{
}

//-----------------------------------------------------------------------------

function AddTableToTable( dest, src )
{
	foreach( key, val in src )
	{
		dest[key] <- val
	}
}

//-----------------------------------------------------------------------------
