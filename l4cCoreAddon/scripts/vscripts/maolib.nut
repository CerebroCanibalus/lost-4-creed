// MaoLib - Central compatibility library for L4C Modpack
// Based on HeavyUtils, renamed in honor of Mao Zedong
// Focus: Native VScript compatibility, stability, no external dependencies
//
// ⚠️ CRITICAL VSCRIPT PATTERN - DO NOT BREAK:
// Many CBaseEntity methods are METHODS (entity.Method()), NOT global functions.
// Examples: entity.IsPlayer(), entity.IsValid(), entity.GetHealth(), entity.Kill()
// Using them as globals (IsPlayer(entity)) will FAIL at runtime.
// When in doubt, check the original HeavyUtils or TF2 VScript dumps.
//
// Confirmed methods (NOT globals): IsPlayer, IsValid, GetHealth, GetOrigin,
// GetAngles, GetClassname, Kill, EmitSound, SetHealth, GetName, GetTeam,
// IsSurvivor, GetVelocity, SetVelocity, EyePosition, EyeAngles, GetForwardVector,
// GetEntityIndex, AddFlag, ClearFlags, ApplyAbsVelocityImpulse, DispatchSpawn,
// EnableDraw, DisableDraw, GetFriction, GetGravity, GetBaseVelocity,
// GetCollisionGroup, GetEFlags, GetFlags, SetKeyValue, ConnectOutput,
// DisconnectOutput, ValidateScriptScope, GetScriptScope, GetModelName
//
// Confirmed GLOBAL functions: IsPlayerABot(player), GetCharacterDisplayName(player),
// EntIndexToHScript(index), GetPlayerFromUserID(userid), Time(), UniqueString()

// Protection against double-load or accidental overwrite
if ( "MaoLib" in getroottable() )
{
	printl( "[MaoLib] Already loaded, skipping double-load." )
	return
}

::MaoLib <-
{
	// ============================================================
	// CONSTANTS - Navigation Mesh Attributes (copied from passivetank_consts.nut for autonomy)
	// These are needed by NavUtils and other modules without external dependencies
	// ============================================================
	
	// NAV_MESH attributes (spawn attributes)
	NAV_MESH_INVALID        = 0
	NAV_MESH_CROUCH         = 1
	NAV_MESH_JUMP           = 2
	NAV_MESH_PRECISE        = 4
	NAV_MESH_NO_JUMP        = 8
	NAV_MESH_STOP           = 16
	NAV_MESH_RUN            = 32
	NAV_MESH_WALK           = 64
	NAV_MESH_AVOID          = 128
	NAV_MESH_TRANSIENT      = 256
	NAV_MESH_DONT_HIDE      = 512
	NAV_MESH_STAND          = 1024
	NAV_MESH_NO_HOSTAGES    = 2048
	NAV_MESH_STAIRS         = 4096
	NAV_MESH_NO_MERGE       = 8192
	NAV_MESH_OBSTACLE_TOP   = 16384
	NAV_MESH_CLIFF          = 32768
	NAV_MESH_TANK_ONLY      = 65536
	NAV_MESH_MOB_ONLY       = 131072
	NAV_MESH_PLAYERCLIP     = 262144
	NAV_MESH_BREAKABLEWALL  = 524288
	NAV_MESH_MOSTLY_FLAT    = 536870912
	NAV_MESH_HAS_ELEVATOR   = 1073741824
	
	// TERROR_NAV attributes (Terror-specific)
	TERROR_NAV_EMPTY                = 2
	TERROR_NAV_STOP_SCAN            = 4
	TERROR_NAV_BATTLESTATION        = 32
	TERROR_NAV_FINALE               = 64
	TERROR_NAV_PLAYER_START         = 128
	TERROR_NAV_BATTLEFIELD          = 256
	TERROR_NAV_IGNORE_VISIBILITY    = 512
	TERROR_NAV_NOT_CLEARABLE        = 1024
	TERROR_NAV_CHECKPOINT           = 2048
	TERROR_NAV_OBSCURED             = 4096
	TERROR_NAV_NO_MOBS              = 8192
	TERROR_NAV_THREAT               = 16384
	TERROR_NAV_RESCUE_VEHICLE       = 32768
	TERROR_NAV_RESCUE_CLOSET        = 65536
	TERROR_NAV_ESCAPE_ROUTE         = 131072
	TERROR_NAV_DOOR                 = 262144
	TERROR_NAV_NOTHREAT             = 524288
	TERROR_NAV_LYINGDOWN            = 1048576
	
	// ============================================================
	// UTILITY: Check if running in developer mode for debug prints
	// ============================================================
	function IsDeveloperMode()
	{
		return Convars.GetStr( "developer" ) != "0"
	}
	
	// ============================================================
	// ENTITY ITERATORS
	// ============================================================
	
	// Iterate over all valid survivors in the game
	// Usage: foreach( survivor in MaoLib.YieldSurvivors() ) { ... }
	function YieldSurvivors()
	{
		local count = 0
		foreach( player in YieldPlayers() )
		{
			if ( !player.IsSurvivor() )
				continue
			
			count++
			yield player
		}
		
		if ( IsDeveloperMode() && count > 0 )
			printl( "[MaoLib] YieldSurvivors: " + count + " survivors found" )
	}

	// Iterate over all valid special infected in the game
	// Usage: foreach( si in MaoLib.YieldSpecials() ) { ... }
	function YieldSpecials()
	{
		local count = 0
		foreach( player in YieldPlayers() )
		{
			if ( player.IsSurvivor() )
				continue
			
			count++
			yield player
		}
		
		if ( IsDeveloperMode() && count > 0 )
			printl( "[MaoLib] YieldSpecials: " + count + " specials found" )
	}

	// Iterate over all valid witches in the game
	// Usage: foreach( witch in MaoLib.YieldWitches() ) { ... }
	function YieldWitches()
	{
		local count = 0
		for( local witch = null; witch = Entities.FindByClassname( witch, "witch" ); )
		{
			if ( !witch || !witch.IsValid() )
				continue
			
			count++
			yield witch
		}
		
		if ( IsDeveloperMode() && count > 0 )
			printl( "[MaoLib] YieldWitches: " + count + " witches found" )
	}

	// Iterate over all valid players in the game (survivors + specials)
	// Usage: foreach( player in MaoLib.YieldPlayers() ) { ... }
	function YieldPlayers()
	{
		local count = 0
		for ( local player = null; player = Entities.FindByClassname( player, "player" ); )
		{
			if ( !player || !player.IsValid() )
					continue
			
			count++
			yield player
		}
		
		if ( IsDeveloperMode() && count > 0 )
			printl( "[MaoLib] YieldPlayers: " + count + " players found" )
	}

	// Get or create script scope for an entity
	// Automatically validates and initializes if needed
	function GetScope( obj )
	{
		if ( !obj || !obj.IsValid() )
		{
			if ( IsDeveloperMode() )
				printl( "[MaoLib.GetScope] WARNING: Invalid entity passed" )
			return null
		}
		
		obj.ValidateScriptScope()
		return obj.GetScriptScope()
	}

	// Check if a player is alive using m_lifeState netprop
	// 0 = alive, 1 = dying, 2 = dead
	function IsAlivePlayer( player )
	{
		local lifeState = NetProps.GetPropInt( player, "m_lifeState" )
		return lifeState == 0
	}

	// Check if an entity is alive (player or non-player)
	// For players: uses m_lifeState, for others: uses GetHealth()
	function IsAlive( what )
	{
		return ( what.IsPlayer() ) ? IsAlivePlayer( what ) : what.GetHealth() > 0
	}

	// backwards compatibility only - sets witch rage level (0.0 to 1.0)
	function SetWitchAnger( witch, val )
	{
		val = clamp( 0.0, val, 1.0 )
		NetProps.SetPropFloat( witch, "m_rage", val )
		return true
	}

	// backwards compat only
	function GetWitchAnger( witch )
	{
		return NetProps.GetPropFloat( witch, "m_rage" )
	}

	function GetTarget( what )
	{
		// IsPlayer() is a METHOD of CBaseEntity, confirmed in Source engine VScript
		return ( what.IsPlayer() ) ? NetProps.GetPropEntity( what, "m_lookatPlayer" ) : GetTargetMisc( what )
	}

	function ForceTarget( what, target )
	{
		// IsPlayer() is a METHOD of CBaseEntity, confirmed in Source engine VScript
		return ( what.IsPlayer() ) ? NetProps.SetPropEntity( what, "m_lookatPlayer", target ) : ForceTargetMisc( what, target )
	}

	function GetTargetMisc( infected )
	{
		return NetProps.GetPropEntity( infected, "m_clientLookatTarget" )
	}

	function ForceTargetMisc( infected, target )
	{
		return NetProps.SetPropEntity( infected, "m_clientLookatTarget", target )
	}

	function FileExists( path )
	{
		local file = FileToString( path )

		return ( file )
	}

	function Probability( val )
	{
		return RandomInt( 1, 100 ) <= val
	}

	function GetAbility( player )
	{
		return NetProps.GetPropEntity( player, "m_customAbility" )
	}

	// Calculate Euclidean distance between two Vector positions
	function DistanceBetween( spot1, spot2 )
	{
		return ( spot1 - spot2 ).Length()
	}

	// Check if string starts with given pattern (regex-based)
	function startswith( str, pattern )
	{
		local pattern_match = regexp( "^" + pattern )
		local result = pattern_match.search( str )
		return result != null && ( "begin" in result )
	}

	function SaveOptionsFmt( table, path, list )
	{
		local str = "{\n"

		local file = FileToString( path )

		local filetable = null

		if ( file )
			filetable = GetOptions( path )

		foreach( name in list )
		{
			// newline
			if ( name == "\n" || name == "" )
			{
				str += "\n"

				continue
			}

			// if its not present in the table then just add it as raw text; useful for comments
			if ( !( name in table ) )
			{
				str += "	" + name + "\n"

				continue
			}

			local value = table[ name ]

			if ( file && file.find( name + " =" ) != null )
			{
				// safe to read because the file should exist

				// if theres already a value there then keep the existing one
				if ( name in filetable )
					value = filetable[ name ]
			}

			local quotes = ""

			if ( typeof( value ) == "string" )
				value = "\"" + value + "\""
			else
				value = "" + value

			str += "	" + name + " = " + value + "\n"
		}

		str += "}\n"

		StringToFile( path, str )
	}

	function InitOptionsFmt( table, path, list )
	{
		SaveOptionsFmt( table, path, list )

		return GetOptions( path )
	}

	function AllPresent( table, ... )
	{
		foreach( name in vargv )
		{
			if ( !( name in table ) )
				return false
		}

		return true
	}

	// Add a think monitor to an entity
	// Creates an info_target relay that runs a think function
	// Usage: MaoLib.AddMonitor( entity, "myMonitor", MyThinkFunc, { delay = 1.0 } )
	function AddMonitor( what, name, func, opts = { }, env = null )
	{
		if ( !what || !what.IsValid() )
		{
			if ( IsDeveloperMode() )
				printl( "[MaoLib.AddMonitor] ERROR: Invalid target entity" )
			return false
		}
		
		local scope = GetScope( what )
		
		if ( name in scope )
			RemoveMonitor( what, name )
		
		local relay = SpawnEntityFromTable( "info_target", { } )
		if ( !relay )
		{
			if ( IsDeveloperMode() )
				printl( "[MaoLib.AddMonitor] ERROR: Failed to spawn info_target relay" )
			return false
		}
		
		scope[ name ] <- relay
		scope = GetScope( relay )
		scope[ name ] <- func
		
		foreach( opts_name, value in opts )
		{
			scope[ opts_name ] <- value
		}
		
		scope[ "monitor" ] <- relay
		
		AddThinkToEnt( relay, name )
		
		if ( IsDeveloperMode() )
			printl( "[MaoLib.AddMonitor] Added monitor '" + name + "' to entity " + what.GetName() )
		
		return true
	}

	// Remove a monitor from an entity by name
	function RemoveMonitor( what, name )
	{
		if ( !what || !what.IsValid() )
			return false
		
		local scope = GetScope( what )
		
		if ( !( name in scope ) )
			return false
		
		if ( !IsReal( scope[ name ] ) )
			return false
		
		scope[ name ].Kill()
		
		if ( IsDeveloperMode() )
			printl( "[MaoLib.RemoveMonitor] Removed monitor '" + name + "'" )
		
		return true
	}

	// Check if an entity has an active monitor with given name
	function HasMonitor( what, name )
	{
		if ( !what || !what.IsValid() )
			return false
		
		local scope = GetScope( what )
		return ( name in scope ) && IsReal( scope[ name ] )
	}

	// Directly kill a monitor entity
	function RemoveMonitorDirectly( monitor, whatever = null )
	{
		if ( monitor && monitor.IsValid() )
			monitor.Kill()
	}

	function IsReal( what )
	{
		return what != null && what.IsValid()
	}

	function min( a, b )
	{
		return ( a < b ) ? a : b
	}

	function max( a, b )
	{
		return ( a > b ) ? a : b
	}

	function clamp( min, value, max )
	{
		if ( value < min )
			return min
		else if ( value > max )
			return max

		return value
	}

	// Replace all occurrences of pattern in string with replacement
	function Replace( str, pattern, replacement )
	{
		for ( ; true; )
		{
			local pattern_match = regexp( pattern )
			local result = pattern_match.search( str )
			
			if ( result == null || !( "begin" in result ) )
				break
			
			str = str.slice( 0, result.begin ) + replacement + str.slice( result.end, str.len() )
		}
		
		return str
	}

	// Safe printf using native Squirrel format() - no compilestring needed
	// Usage: MaoLib.printf( "Player %s has %d health", name, health )
	// Note: format() is a native Squirrel function, much safer than compilestring
	function printf( str, ... )
	{
		// Build argument array for format()
		local args = [str]
		foreach( value in vargv )
			args.append( value )
		
		try
		{
			// Use native format() directly - no compilestring needed
			local result = format.acall( args )
			print( result + "\n" )
		}
				catch( e )
				{
					if ( MaoLib.IsDeveloperMode() )
						printl( "[MaoLib.printf] ERROR: " + e )
				}
	}

	function IsEnabled( whatever )
	{
		return !( NetProps.GetPropInt( whatever, "m_bDisabled" ) )
	}

	function DisableKey( special, key )
	{
		NetProps.SetPropInt( special, "m_afButtonDisabled", NetProps.GetPropInt( special, "m_afButtonDisabled" ) | key )
	}

	function EnableKey( special, key )
	{
		NetProps.SetPropInt( special, "m_afButtonDisabled", NetProps.GetPropInt( special, "m_afButtonDisabled" ) & ~key )
	}

	function IsKeyEnabled( special, key )
	{
		return !( NetProps.GetPropInt( special, "m_afButtonDisabled" ) & key )
	}

	function StartKey( special, key )
	{
		NetProps.SetPropInt( special, "m_afButtonForced", NetProps.GetPropInt( special, "m_afButtonForced" ) | key )
	}

	function EndKey( special, key )
	{
		NetProps.SetPropInt( special, "m_afButtonForced", NetProps.GetPropInt( special, "m_afButtonForced" ) & ~key )
	}

	function IsPressingKey( special, key )
	{
		return NetProps.GetPropInt( special, "m_afButtonForced" ) & key
	}

	// Convert a direction vector to QAngle (pitch, yaw, roll)
	// Useful for calculating facing direction from velocity or direction vectors
	function VectorAngle( dest )
	{
		local tmp, yaw, pitch = 0
		
		if ( dest.y == 0 && dest.x == 0 )
		{
			yaw = 0
			
			if ( dest.z > 0 )
				pitch = 270
			else
				pitch = 90
		}
		else
		{
			yaw = ( atan2( dest.y, dest.x ) * 180 / PI )
			
			if ( yaw < 0 )
				yaw += 360
			
			tmp = sqrt( dest.x * dest.x + dest.y * dest.y )
			pitch = ( atan2( -dest.z, tmp ) * 180 / PI )
			
			if ( pitch < 0 )
				pitch += 360
		}
		
		return QAngle( pitch, yaw, 0 )
	}

	function CalculateTabs( id )
	{
		local tabs = ""

		for ( local i = id; i > 0; i-- )
		{
			tabs += "\t"
		}

		return tabs
	}

	function Stringify( value )
	{
		return ( typeof value == "string" ? "\"" + value + "\"" : value )
	}

	function ShouldScan( value )
	{
		switch( typeof value )
		{
			case "array":
			case "table":
				return true
			break

			default:
				return false
		}
	}

	function ScanThis( name, value, tabs = 0 )
	{
		local str = CalculateTabs( tabs )

		if ( typeof value == "array" )
		{
			str += name + " =\n" + CalculateTabs( tabs ) + "[\n"

			foreach( element in value )
			{
				if ( !ShouldScan( element ) )
					str += CalculateTabs( tabs + 1 ) + Stringify( element ) + "\n"
					else
						str += CalculateTabs( tabs ) + ScanThis( name, element, tabs + 1 ) + "\n"
			}

			str += CalculateTabs( tabs ) + "]"
		}
		else if ( typeof value == "table" )
		{
			str += name + " =\n" + CalculateTabs( tabs ) + "{\n"

			foreach( vname, vvalue in value )
			{
				if ( !ShouldScan( vvalue ) )
					str += CalculateTabs( tabs + 1 ) + vname + " = " + Stringify( vvalue ) + "\n"
					else
						str += CalculateTabs( tabs - 1 ) + ScanThis( vname, vvalue, tabs + 1 ) + "\n"
			}

			str += CalculateTabs( tabs ) + "}"
		}
		else
			str += name + " = " + Stringify( value )

			str += "\n"

			return str
	}

	function CompileOptions( opts, path, arr )
	{
		local file = "{\n"

		local file2 = FileToString( path )

		if ( file2 )
			file2 = GetOptions( path )

			foreach( line in arr )
			{
				if ( file2 && line in file2 )
				{
					file += ScanThis( line, file2[ line ], 1 )

					continue
				}

				if ( line == "" )
				{
					file += "\n"

					continue
				}

				if ( !( line in opts ) )
				{
					file += "\t" + line + "\n"

					continue
				}

				file += ScanThis( line, opts[ line ], 1 )
			}

			file += "}\n"

			return file
	}

	function WriteOptions( opts, path, arr )
	{
		StringToFile( path, CompileOptions( opts, path, arr ) )
	}

	function GetOptions( path )
	{
		local file = FileToString( path )
		if (!file || file.len() == 0) return null

		// Validación de seguridad: solo permitir caracteres seguros
		// Formato esperado: tablas Squirrel literales con números, strings, bools
		local allowedChars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_.{}[]\\\"=,;+-*/ \t\r\n"
		foreach (ch in file)
		{
			local found = false
			foreach (allowed in allowedChars)
			{
				if (ch == allowed) { found = true; break }
			}
			if (!found)
			{
				printl("[MaoLib.GetOptions] SECURITY: Caracter no permitido en config: '" + ch + "'")
				return null
			}
		}

		return compilestring( "return " + file )();
	}

	function InitOptions( opts, path, arr )
	{
		WriteOptions( opts, path, arr )

		return GetOptions( path )
	}

	// DelayMonitor - think function for delayed callbacks
	// Accesses variables from the monitor entity's script scope (set by AddMonitor)
	function DelayMonitor()
	{
		// Get the entity's script scope where opts were stored
		local selfScope = MaoLib.GetScope( self )
		
		// Check if required variables exist
		if ( !( "time" in selfScope ) || !( "delay" in selfScope ) || !( "func" in selfScope ) )
		{
			if ( MaoLib.IsDeveloperMode() )
				printl( "[MaoLib.DelayMonitor] ERROR: Missing required variables in scope" )
			return -1 // Stop thinking
		}
		
		if ( selfScope.time + selfScope.delay > Time() )
			return selfScope.delay
		
		// Execute the delayed function
		try
		{
			compilestring( "return " + selfScope.func )()
		}
		catch( e )
		{
			if ( MaoLib.IsDeveloperMode() )
				printl( "[MaoLib.DelayMonitor] ERROR executing function: " + e )
		}
		
		// Clean up the monitor entity
		if ( "monitor" in selfScope && MaoLib.IsReal( selfScope.monitor ) )
			selfScope.monitor.Kill()
		
		return -1 // Stop thinking
	}

	// Schedule a function call after a delay using monitor system
	// Usage: MaoLib.DelayCall( "SomeFunction()", 5.0 )
	function DelayCall( func, delay, opts = { } )
	{
		local director = Entities.FindByClassname( null, "info_director" )
		
		if ( !director || !director.IsValid() )
		{
			if ( IsDeveloperMode() )
				printl( "[MaoLib.DelayCall] ERROR: No info_director found" )
			return false
		}
		
		opts.time <- Time()
		opts.delay <- delay
		opts.func <- func
		
		local result = AddMonitor( director, "delaycall_" + UniqueString(), MaoLib.DelayMonitor, opts )
		
		if ( IsDeveloperMode() )
			printl( "[MaoLib.DelayCall] Scheduled '" + func + "' in " + delay + " seconds" )
		
		return result
	}

	// Lightweight delayed call using DoEntFire (no monitor entity created)
	// Less overhead than DelayCall but cannot be cancelled
	// Usage: MaoLib.DelayCallOpt( "SomeFunction()", 5.0 )
	function DelayCallOpt( func, delay )
	{
		local director = Entities.FindByClassname( null, "info_director" )
		
		if ( !director || !director.IsValid() )
		{
			if ( IsDeveloperMode() )
				printl( "[MaoLib.DelayCallOpt] ERROR: No info_director found" )
			return
		}
		
		DoEntFire( "!self", "RunScriptCode", func, delay, director, director )
		
		if ( IsDeveloperMode() )
			printl( "[MaoLib.DelayCallOpt] Scheduled '" + func + "' in " + delay + " seconds" )
	}
	
	// ------------------------------------------------------------------
	// TANK SPEED COORDINATION (shared system for multi-script speed mods)
	// ------------------------------------------------------------------
	// Usage: Scripts set their multiplier via TankSpeed_* tables,
	// then call ApplyTankSpeed(tank) to apply the combined value.
	//
	// Example:
	//   ::TankSpeed_FireMult[idx] <- 1.25
	//   MaoLib.ApplyTankSpeed(tank)
	//
	TankSpeed_BerserkerMult = {}
	TankSpeed_FireMult = {}
	
	// Apply combined speed multipliers to a tank
	// FireMult: slowdown from fire (default 1.0 = no change)
	// BerserkerMult: speed boost when enraged (default 1.0 = no change)
	function ApplyTankSpeed( tank )
	{
		if ( !tank || !tank.IsValid() )
		{
			if ( IsDeveloperMode() )
				printl( "[MaoLib.ApplyTankSpeed] ERROR: Invalid tank entity" )
			return
		}
		
		local idx = "" + tank.GetEntityIndex()
		local baseSpeed = 1.0
		
		local fire = 1.0
		if ( idx in TankSpeed_FireMult )
			fire = TankSpeed_FireMult[ idx ]
		
		local berserk = 1.0
		if ( idx in TankSpeed_BerserkerMult )
			berserk = TankSpeed_BerserkerMult[ idx ]
		
		local finalSpeed = baseSpeed * fire * berserk
		NetProps.SetPropFloat( tank, "m_flLaggedMovementValue", finalSpeed )
		
		if ( IsDeveloperMode() )
			printl( "[MaoLib.ApplyTankSpeed] Tank " + idx + " speed set to " + finalSpeed + " (fire=" + fire + ", berserk=" + berserk + ")" )
	}
	
	// ============================================================
	// GLOBAL TIMER MANAGER
	// Unified timer system: single entity, all callbacks centralized
	// Replaces scattered AddThinkToEnt / logic_timer / info_target per script
	// ============================================================
	
	// Active timers table: name -> { callback, interval, nextRun, active, execCount, totalTime }
	Timers = {}
	
	// Single think entity for all timers
	TimerThinkEnt = null
	
	// Is the timer manager running?
	TimersActive = false
	
	// Timer debug stats
	TimerFrameCount = 0
	
	// Initialize the global timer manager (called automatically by AddTimer)
	function InitTimers()
	{
		// Already initialized and valid
		if ( TimersActive && TimerThinkEnt && TimerThinkEnt.IsValid() )
			return
		
		// If entity exists but is invalid, clean up reference
		if ( TimerThinkEnt && !TimerThinkEnt.IsValid() )
		{
			TimerThinkEnt = null
			TimersActive = false
		}
		
		// Use logic_timer instead of AddThinkToEnt for robustness
		// logic_timer is engine-managed and immune to think overwrites
		TimerThinkEnt = SpawnEntityFromTable( "logic_timer", {
			targetname = "maolib_timer_manager",
			RefireTime = 0.01,
			StartDisabled = 1
		} )
		
		if ( !TimerThinkEnt )
		{
			if ( IsDeveloperMode() )
				printl( "[MaoLib.InitTimers] ERROR: Failed to spawn timer entity" )
			return
		}
		
		// Use a global wrapper to avoid :: in AddOutput (colon delimiter conflict)
		// Siempre recrear para prevenir que un overwrite externo la rompa
		if ( "__maolib_timer_think" in getroottable() )
			delete getroottable()["__maolib_timer_think"]
		getroottable()["__maolib_timer_think"] <- @() ::MaoLib.TimerThink()
		
		// Add output: OnTimer -> RunScriptCode -> __maolib_timer_think()
		// Using AddOutput format: "OnTimer !self:RunScriptCode:code:delay:times"
		// CRITICAL: NO usar :: (global scope) dentro del AddOutput string porque los
		// : del formato AddOutput se confunden con el :: de Squirrel, rompiendo el parseo.
		EntFire( "maolib_timer_manager", "AddOutput", "OnTimer !self:RunScriptCode:__maolib_timer_think():0:-1", 0, null )
		EntFire( "maolib_timer_manager", "Enable", "", 0.01, null )
		
		TimersActive = true
		
		if ( IsDeveloperMode() )
			printl( "[MaoLib.InitTimers] Timer manager initialized (logic_timer mode)" )
	}
	
	// Internal think function - executes all registered callbacks
	function TimerThink()
	{
		if ( !TimersActive )
			return -1
		
		local now = Time()
		
		TimerFrameCount++
		
		foreach ( name, timer in Timers )
		{
			if ( !timer.active )
				continue
			
			if ( now >= timer.nextRun )
			{
				timer.nextRun = now + timer.interval
				timer.execCount++
				
				local startTime = Time()
				try
				{
					timer.callback()
				}
				catch ( e )
				{
					if ( IsDeveloperMode() )
						printl( "[MaoLib.TimerThink] ERROR in timer '" + name + "': " + e )
				}
				timer.totalTime += Time() - startTime
			}
		}
		
		return 0.01 // Think at 100Hz max resolution
	}
	
	// Register a named timer with interval (seconds) and callback function
	// If name already exists, logs warning but DOES NOT overwrite (safety)
	function AddTimer( name, interval, callback )
	{
		if ( !TimersActive )
			InitTimers()
		
		if ( name in Timers )
		{
			if ( IsDeveloperMode() )
				printl( "[MaoLib.AddTimer] WARNING: Timer '" + name + "' already exists. Use AddTimerForce() to overwrite." )
			return false
		}
		
		Timers[ name ] <- {
			callback = callback
			interval = interval
			nextRun = Time() + interval
			active = true
			execCount = 0
			totalTime = 0.0
		}
		
		if ( IsDeveloperMode() )
			printl( "[MaoLib.AddTimer] Registered timer '" + name + "' (interval=" + interval + ")" )
		
		return true
	}
	
	// Force overwrite an existing timer (use with caution)
	function AddTimerForce( name, interval, callback )
	{
		if ( !TimersActive )
			InitTimers()
		
		Timers[ name ] <- {
			callback = callback
			interval = interval
			nextRun = Time() + interval
			active = true
			execCount = 0
			totalTime = 0.0
		}
		
		if ( IsDeveloperMode() )
			printl( "[MaoLib.AddTimerForce] Overwrote timer '" + name + "' (interval=" + interval + ")" )
		
		return true
	}
	
	// Register timer only if name doesn't exist. Returns false if duplicate.
	function AddTimerSafe( name, interval, callback )
	{
		if ( name in Timers )
			return false
		
		return AddTimer( name, interval, callback )
	}
	
	// Auto-rename if duplicate: "name", "name_2", "name_3", etc.
	function AddTimerAuto( name, interval, callback )
	{
		local finalName = name
		local counter = 2
		
		while ( finalName in Timers )
		{
			finalName = name + "_" + counter
			counter++
		}
		
		AddTimer( finalName, interval, callback )
		return finalName
	}
	
	// Remove a timer by name
	function RemoveTimer( name )
	{
		if ( name in Timers )
		{
			delete Timers[ name ]
			
			if ( IsDeveloperMode() )
				printl( "[MaoLib.RemoveTimer] Removed timer '" + name + "'" )
		}
	}
	
	// Pause a timer without removing it
	function PauseTimer( name )
	{
		if ( name in Timers )
			Timers[ name ].active = false
	}
	
	// Resume a paused timer
	function ResumeTimer( name )
	{
		if ( name in Timers )
		{
			Timers[ name ].active = true
			Timers[ name ].nextRun = Time() + Timers[ name ].interval
		}
	}
	
	// Check if a timer exists and is active
	function IsTimerActive( name )
	{
		return ( name in Timers ) && Timers[ name ].active
	}
	
	// Get count of registered timers
	function GetTimerCount()
	{
		return Timers.len()
	}
	
	// Clear all timers and kill think entity
	// Call this in OnGameEvent_round_end / mission_lost
	function ClearAllTimers()
	{
		Timers.clear()
		
		if ( TimerThinkEnt && TimerThinkEnt.IsValid() )
		{
			// Disable first, then kill (cleaner shutdown for logic_timer)
			EntFireByHandle( TimerThinkEnt, "Disable", "", 0, null, null )
			TimerThinkEnt.Kill()
			TimerThinkEnt = null
		}
		
		TimersActive = false
		TimerFrameCount = 0
		
		if ( IsDeveloperMode() )
			printl( "[MaoLib.ClearAllTimers] All timers cleared" )
	}
	
	// Print simple timer stats for debugging
	// Usage: MaoLib.PrintTimerStats()
	function PrintTimerStats()
	{
		printl( "=== MaoLib Timer Stats ===" )
		printl( "Active timers: " + Timers.len() )
		printl( "Think frames: " + TimerFrameCount )
		printl( "Timer details:" )
		foreach ( name, timer in Timers )
		{
			local avgTime = ( timer.execCount > 0 ) ? ( timer.totalTime / timer.execCount ) : 0
			printl( "  " + name + ": exec=" + timer.execCount + " avg=" + format( "%.4f", avgTime ) + "s active=" + timer.active )
		}
		printl( "==========================" )
	}
	
	// Detailed timer debug info — returns a formatted string
	// Usage: printl( MaoLib.GetTimerDebugInfo() )
	function GetTimerDebugInfo()
	{
		local now = Time()
		local info = ""
		info += "=== MaoLib Timer Debug ===\n"
		info += "Total timers: " + Timers.len() + "\n"
		info += "System active: " + ( TimersActive ? "YES" : "NO" ) + "\n"
		info += "Think entity valid: " + ( TimerThinkEnt && TimerThinkEnt.IsValid() ? "YES" : "NO" ) + "\n"
		info += "Think frames: " + TimerFrameCount + "\n"
		info += "\n"
		
		if ( Timers.len() == 0 )
		{
			info += "No active timers.\n"
		}
		else
		{
			info += format( "%-28s %-7s %-8s %-6s %-7s %-10s\n", "NAME", "INT(s)", "NEXT(s)", "ACTIVE", "EXEC#", "AVG(ms)" )
			info += "----------------------------------------------------------------\n"
			foreach ( name, timer in Timers )
			{
				local avgMs = timer.execCount > 0 ? format( "%.3f", ( timer.totalTime / timer.execCount ) * 1000 ) : "N/A"
				local nextIn = format( "%.1f", timer.nextRun - now )
				info += format( "%-28s %-7.3f %-8s %-6s %-7d %-10s\n",
					name, timer.interval, nextIn, timer.active ? "ON" : "OFF",
					timer.execCount, avgMs )
			}
		}
		info += "=============================="
		return info
	}
	
	// Utility: get raw timer table for external inspection
	// Usage: local t = MaoLib.GetTimerTable()
	function GetTimerTable()
	{
		return Timers
	}
	
	// Utility: get timer count delta since last check (for leak detection)
	// Pass the previous count, returns the delta
	function GetTimerDelta( prevCount )
	{
		return Timers.len() - prevCount
	}
}

// ============================================================
// AUTO-LOAD MAOLIB SUBMODULES
// ============================================================
// Carga automática de módulos dependientes para garantizar
// que siempre estén disponibles en getroottable()
//
// Orden crítico: timers_cleanup → vfx
// ============================================================

if ( !("MaoLib_TimersCleanup" in getroottable()) )
{
	IncludeScript( "maolib_timers_cleanup", getroottable() )
}

if ( !("MaoLib_VFX" in getroottable()) )
{
	IncludeScript( "maolib_vfx", getroottable() )
}

if ( !("MaoLib_NavUtils" in getroottable()) )
{
	IncludeScript( "maolib_navutils", getroottable() )
}

// maolib_events.nut ELIMINADO - cada script usa __CollectGameEventCallbacks directamente
// IncludeScript( "maolib_events", getroottable() ) - DEPRECATED

printl( "[MaoLib] Core + Submodules loaded successfully (Timers, VFX, NavUtils)" )
