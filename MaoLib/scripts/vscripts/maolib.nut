// ============================================================================
// MaoLib — Central VScript Framework for Left 4 Dead 2
// Version 2.2 — Standalone Release
// ============================================================================
// Originally part of the Lost 4 Creed modpack, extracted as a standalone
// library for the modding community. Fully native VScript — no VSLib, no Lua.
//
// LICENSE: Free to use, modify, and redistribute. Attribution appreciated.
// DISCORD: https://discord.gg/NWPYT7MEEa
// ============================================================================
// 
// ⚠️ CRITICAL — ENTITY METHODS vs GLOBAL FUNCTIONS:
// Many CBaseEntity methods are entity-level (entity.Method()), NOT globals:
//   ✅ entity.IsPlayer(), entity.IsValid(), entity.GetHealth()
//   ✅ entity.Kill(), entity.GetOrigin(), entity.EyePosition()
//   ❌ IsPlayer(entity) ← crash at runtime
//
// Confirmed entity methods: IsPlayer, IsValid, GetHealth, GetOrigin,
// GetAngles, GetClassname, Kill, SetHealth, GetName, IsSurvivor,
// GetVelocity, SetVelocity, EyePosition, EyeAngles, GetForwardVector,
// GetEntityIndex, ApplyAbsVelocityImpulse, DispatchSpawn,
// ConnectOutput, DisconnectOutput, ValidateScriptScope, GetScriptScope,
// GetModelName, GetCenter, GetActiveWeapon, Stagger, SetParent,
// PrecacheModel, TakeDamage
//
// Confirmed GLOBAL functions: IsPlayerABot(player), EntIndexToHScript(index),
// GetPlayerFromUserID(userid), Time(), UniqueString(), PrecacheModel(mdl),
// PrecacheSound(sound), EmitSoundOn(sound, ent), StopSoundOn(sound, ent),
// TraceLine(table), ZSpawn(table), DoEntFire, EntFire, EntFireByHandle,
// DispatchSpawn, NetProps.*, Director.*, Convars.*, NavMesh.*
//
// ============================================================================

// ============================================================
// SAFETY: Prevent double-load or accidental overwrite
// ============================================================
if ( "MaoLib" in getroottable() )
{
	printl( "[MaoLib] Already loaded, skipping double-load." )
	return
}

::MaoLib <-
{
	// ============================================================
	// NAVIGATION MESH CONSTANTS
	// ============================================================
	// These are needed by NavUtils and other modules.
	// Two attribute types exist in L4D2:
	//   1. SPAWN ATTRIBUTES (HasSpawnAttributes) — TERROR_NAV_* constants
	//      Used for: spawn rules, checkpoints, escape routes
	//   2. MESH ATTRIBUTES (HasAttributes) — NAV_MESH_* constants
	//      Used for: movement rules (crouch, jump, avoid)
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
	
	// TERROR_NAV attributes (Terror-specific spawn attributes)
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
	// DEBUG — set to 1 for debug prints
	// ============================================================
	Debug = 0
	
	function Dbg(msg) {
		if (Debug) printl("[MaoLib][DBG] " + msg)
	}
	
	function DbgWarn(msg) {
		printl("[MaoLib][WARN] " + msg)
	}

	// ============================================================
	// DEVELOPER MODE CHECK
	// ============================================================
	// Returns true if "developer" convar is set to non-zero.
	// Many MaoLib functions respect this to reduce console spam.
	function IsDeveloperMode()
	{
		return Convars.GetStr( "developer" ) != "0"
	}
	
	// ============================================================
	// ENTITY ITERATORS
	// ============================================================
	// Usage:
	//   foreach (survivor in MaoLib.YieldSurvivors()) { DoSomething(survivor) }
	//   foreach (si in MaoLib.YieldSpecials()) { DoSomething(si) }
	//   foreach (witch in MaoLib.YieldWitches()) { DoSomething(witch) }
	//   foreach (player in MaoLib.YieldPlayers()) { DoSomething(player) }
	// ============================================================
	
	// Iterate all survivors
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

	// Iterate all special infected
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

	// Iterate all witches
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

	// Iterate all players (survivors + special infected)
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

	// ============================================================
	// ENTITY UTILITIES
	// ============================================================

	// Safe scope accessor — creates scope if needed
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

	// m_lifeState check: 0 = alive, 1 = dying, 2 = dead
	function IsAlivePlayer( player )
	{
		local lifeState = NetProps.GetPropInt( player, "m_lifeState" )
		return lifeState == 0
	}

	// Alive check for any entity (player or NPC)
	function IsAlive( what )
	{
		return ( what.IsPlayer() ) ? IsAlivePlayer( what ) : what.GetHealth() > 0
	}

	// ============================================================
	// WITCH UTILITIES
	// ============================================================

	// Set witch anger level (0.0 to 1.0)
	function SetWitchAnger( witch, val )
	{
		val = clamp( 0.0, val, 1.0 )
		NetProps.SetPropFloat( witch, "m_rage", val )
		return true
	}

	// Get current witch anger level
	function GetWitchAnger( witch )
	{
		return NetProps.GetPropFloat( witch, "m_rage" )
	}

	// ============================================================
	// TARGETING (LookAt)
	// ============================================================

	// Get what a player is looking at
	function GetTarget( what )
	{
		return ( what.IsPlayer() ) ? NetProps.GetPropEntity( what, "m_lookatPlayer" ) : GetTargetMisc( what )
	}

	// Force a player to look at a target
	function ForceTarget( what, target )
	{
		return ( what.IsPlayer() ) ? NetProps.SetPropEntity( what, "m_lookatPlayer", target ) : ForceTargetMisc( what, target )
	}

	// Get look-at target for non-player infected
	function GetTargetMisc( infected )
	{
		return NetProps.GetPropEntity( infected, "m_clientLookatTarget" )
	}

	// Set look-at target for non-player infected
	function ForceTargetMisc( infected, target )
	{
		return NetProps.SetPropEntity( infected, "m_clientLookatTarget", target )
	}

	// ============================================================
	// FILE & CONFIG UTILITIES
	// ============================================================

	// Check if a file exists
	function FileExists( path )
	{
		local file = FileToString( path )
		return ( file )
	}

	// Return true with val% probability (1-100)
	function Probability( val )
	{
		return RandomInt( 1, 100 ) <= val
	}

	// Get player's ability entity (m_customAbility)
	function GetAbility( player )
	{
		return NetProps.GetPropEntity( player, "m_customAbility" )
	}

	// ============================================================
	// MATH & VECTOR UTILITIES
	// ============================================================

	// Validate that a Vector is non-null and non-zero
	function IsValidPosition( pos )
	{
		if ( pos == null ) return false
		return pos.x != 0 || pos.y != 0 || pos.z != 0
	}

	// Euclidean distance between two vectors
	function DistanceBetween( spot1, spot2 )
	{
		return ( spot1 - spot2 ).Length()
	}

	// String starts-with check (regex-based)
	function startswith( str, pattern )
	{
		local pattern_match = regexp( "^" + pattern )
		local result = pattern_match.search( str )
		return result != null && ( "begin" in result )
	}

	// ============================================================
	// CONFIG FILE PARSING (safe compilestring wrapper)
	// ============================================================
	// These functions allow reading/writing Squirrel-format config
	// files safely. Great for mod configs saved to disk.
	//
	// Usage:
	//   local cfg = MaoLib.ParseConfigString("{ hp = 100, name = \"test\" }")
	//   MaoLib.GetOptions("path/to/config.txt")  — reads file
	//   MaoLib.WriteOptions(table, path, keys)   — writes file
	// ============================================================

	// Character allowlist for config parsing security
	_ConfigAllowedChars = null
	
	function _GetConfigAllowedChars()
	{
		if (_ConfigAllowedChars) return _ConfigAllowedChars
		
		local chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_.{}[]\\\"'`=,;+-*/\r\n\t :!?()<>@#$%^&|~"
		_ConfigAllowedChars = {}
		foreach (ch in chars)
			_ConfigAllowedChars[ch] <- true
		
		return _ConfigAllowedChars
	}
	
	// Parse a config string safely (no arbitrary code execution)
	function ParseConfigString(raw)
	{
		if (!raw || raw.len() == 0) return {}
		
		local allowed = _GetConfigAllowedChars()
		foreach (ch in raw)
		{
			if (!(ch in allowed))
			{
				printl("[MaoLib.ParseConfigString] SECURITY: Unauthorized character '" + ch + "' (code " + ch + ")")
				return null
			}
		}
		
		try
		{
			return compilestring("return " + raw)()
		}
		catch (e)
		{
			printl("[MaoLib.ParseConfigString] ERROR parsing config: " + e)
			return null
		}
	}
	
	// Read and parse a config file safely
	function GetOptions( path )
	{
		local file = FileToString( path )
		if (!file || file.len() == 0) return null

		local allowed = _GetConfigAllowedChars()
		local len = file.len()
		for (local i = 0; i < len; i++)
		{
			local ch = file[i].tochar()
			if (!(ch in allowed))
			{
				printl("[MaoLib.GetOptions] SECURITY: Unauthorized character '" + ch + "' (code " + file[i] + ") in " + path)
				return null
			}
		}

		try
		{
			return compilestring( "return " + file )()
		}
		catch (e)
		{
			printl("[MaoLib.GetOptions] ERROR parsing config: " + e)
			return null
		}
	}

	// Write options to a file with formatting
	function WriteOptions( opts, path, arr )
	{
		StringToFile( path, CompileOptions( opts, path, arr ) )
	}

	// Init options with defaults, then read back
	function InitOptions( opts, path, arr )
	{
		WriteOptions( opts, path, arr )
		return GetOptions( path )
	}

	// ============================================================
	// MONITOR SYSTEM (per-entity think)
	// ============================================================
	// Attach think functions to specific entities.
	// ⚠️ Note: AddThinkToEnt can be fragile — prefer MaoLib.AddTimer()
	// for most cases. Monitors are useful when you need think that
	// follows a specific entity through the frame.
	//
	// Usage:
	//   MaoLib.AddMonitor(entity, "myThink", MyThinkFunc, { delay = 0.5 })
	//   MaoLib.RemoveMonitor(entity, "myThink")
	//   MaoLib.HasMonitor(entity, "myThink")
	// ============================================================

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

	function HasMonitor( what, name )
	{
		if ( !what || !what.IsValid() )
			return false
		
		local scope = GetScope( what )
		return ( name in scope ) && IsReal( scope[ name ] )
	}

	function RemoveMonitorDirectly( monitor, whatever = null )
	{
		if ( monitor && monitor.IsValid() )
			monitor.Kill()
	}

	// ============================================================
	// VALIDATION
	// ============================================================

	// Check entity is valid and alive
	function IsReal( what )
	{
		return what != null && what.IsValid()
	}

	// ============================================================
	// MATH HELPERS
	// ============================================================

	function min( a, b ) { return ( a < b ) ? a : b }
	function max( a, b ) { return ( a > b ) ? a : b }
	function clamp( minVal, value, maxVal )
	{
		if ( value < minVal ) return minVal
		if ( value > maxVal ) return maxVal
		return value
	}

	// ============================================================
	// STRING UTILITIES
	// ============================================================

	// Replace all regex matches in string
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

	// ============================================================
	// PRINTF — Safe formatted print
	// ============================================================
	// Uses native Squirrel format() — no compilestring needed.
	// Usage: MaoLib.printf("Player %s has %d HP", name, hp)
	
	function printf( str, ... )
	{
		local args = [str]
		foreach( value in vargv )
			args.append( value )
		
		try
		{
			local result = format.acall( args )
			print( result + "\n" )
		}
		catch( e )
		{
			if ( MaoLib.IsDeveloperMode() )
				printl( "[MaoLib.printf] ERROR: " + e )
		}
	}

	// ============================================================
	// ENTITY STATE HELPERS
	// ============================================================

	// Check if entity is enabled (m_bDisabled)
	function IsEnabled( whatever )
	{
		return !( NetProps.GetPropInt( whatever, "m_bDisabled" ) )
	}

	// ============================================================
	// BUTTON DISABLE/FORCE (for AI infected control)
	// ============================================================
	// These manipulate m_afButtonDisabled / m_afButtonForced
	// to control what buttons SI players can press.
	//
	// Key constants (from Source SDK):
	//   IN_ATTACK  = 1 << 0   = 1
	//   IN_JUMP    = 1 << 1   = 2
	//   IN_DUCK    = 1 << 2   = 4
	//   IN_FORWARD = 1 << 3   = 8
	//   IN_BACK    = 1 << 4   = 16
	//   IN_USE     = 1 << 5   = 32
	//   IN_ATTACK2 = 1 << 11  = 2048
	// ============================================================

	// Disable a key for a special infected
	function DisableKey( special, key )
	{
		NetProps.SetPropInt( special, "m_afButtonDisabled", NetProps.GetPropInt( special, "m_afButtonDisabled" ) | key )
	}

	// Enable a previously disabled key
	function EnableKey( special, key )
	{
		NetProps.SetPropInt( special, "m_afButtonDisabled", NetProps.GetPropInt( special, "m_afButtonDisabled" ) & ~key )
	}

	// Check if a key is enabled
	function IsKeyEnabled( special, key )
	{
		return !( NetProps.GetPropInt( special, "m_afButtonDisabled" ) & key )
	}

	// Force a key as pressed (auto-hold)
	function StartKey( special, key )
	{
		NetProps.SetPropInt( special, "m_afButtonForced", NetProps.GetPropInt( special, "m_afButtonForced" ) | key )
	}

	// Release a forced key
	function EndKey( special, key )
	{
		NetProps.SetPropInt( special, "m_afButtonForced", NetProps.GetPropInt( special, "m_afButtonForced" ) & ~key )
	}

	// Check if a key is being force-pressed
	function IsPressingKey( special, key )
	{
		return NetProps.GetPropInt( special, "m_afButtonForced" ) & key
	}

	// ============================================================
	// VECTOR → ANGLE CONVERSION
	// ============================================================
	// Convert a direction vector to QAngle (pitch, yaw, roll).
	// Useful for entity facing/aiming calculations.

	function VectorAngle( dest )
	{
		local tmp, yaw, pitch = 0
		
		if ( dest.y == 0 && dest.x == 0 )
		{
			yaw = 0
			if ( dest.z > 0 ) pitch = 270
			else pitch = 90
		}
		else
		{
			yaw = ( atan2( dest.y, dest.x ) * 180 / PI )
			if ( yaw < 0 ) yaw += 360
			
			tmp = sqrt( dest.x * dest.x + dest.y * dest.y )
			pitch = ( atan2( -dest.z, tmp ) * 180 / PI )
			if ( pitch < 0 ) pitch += 360
		}
		
		return QAngle( pitch, yaw, 0 )
	}

	// ============================================================
	// CONFIG FILE SERIALIZATION
	// ============================================================

	function CalculateTabs( id )
	{
		local tabs = ""
		for ( local i = id; i > 0; i-- )
			tabs += "\t"
		return tabs
	}

	function Stringify( value )
	{
		return ( typeof value == "string" ? "\"" + value + "\"" : value )
	}

	function ShouldScan( value )
	{
		return typeof value == "array" || typeof value == "table"
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
			if ( line == "" ) { file += "\n"; continue }
			if ( !( line in opts ) ) { file += "\t" + line + "\n"; continue }
			file += ScanThis( line, opts[ line ], 1 )
		}
		file += "}\n"
		return file
	}

	// ============================================================
	// TANK SPEED COORDINATION SYSTEM
	// ============================================================
	// Shared system for multi-script tank speed modifications.
	// Scripts set their multiplier, then call ApplyTankSpeed(tank).
	//
	// Usage:
	//   MaoLib.TankSpeed_FireMult[idx] <- 1.25
	//   MaoLib.ApplyTankSpeed(tank)
	// ============================================================

	TankSpeed_BerserkerMult = {}
	TankSpeed_FireMult = {}
	
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
			printl( "[MaoLib.ApplyTankSpeed] Tank " + idx + " speed set to " + finalSpeed )
	}

	// ============================================================
	// ⏱️ GLOBAL TIMER MANAGER
	// ============================================================
	// ** THE ONLY TIMER SYSTEM YOU SHOULD USE **
	//
	// WHY: L4D2's AddThinkToEnt and logic_timer are fragile.
	//   - AddThinkToEnt: only ONE think function per entity; easy to overwrite
	//   - logic_timer: creates map entities that persist across rounds
	//
	// MaoLib's timer manager uses a SINGLE logic_timer entity that
	// dispatches to registered callbacks. Cleanup is automatic.
	//
	// Usage:
	//   MaoLib.AddTimer("name", interval_seconds, callback_fn)
	//   MaoLib.AddTimerForce("name", interval_seconds, callback_fn)  // overwrite
	//   MaoLib.AddTimerSafe("name", interval, fn)  // skip if exists
	//   MaoLib.AddTimerAuto("name", interval, fn)  // auto-rename duplicates
	//   MaoLib.RemoveTimer("name")
	//   MaoLib.PauseTimer("name")
	//   MaoLib.ResumeTimer("name")
	//   MaoLib.IsTimerActive("name")
	//   MaoLib.ClearAllTimers()            // cleanup on round_end
	//   MaoLib.PrintTimerStats()
	//   MaoLib.GetTimerDebugInfo()          // returns formatted string
	//
	// ⚠️ AddTimer = RECURRING. For one-shot, use:
	//   MaoLib.DelayCall(function() { ... }, delay_seconds)
	//
	// ⚠️ NUNCA uses logic_timer or AddThinkToEnt directly in your scripts.
	// ============================================================
	
	Timers = {}
	TimerThinkEnt = null
	TimersActive = false
	TimerFrameCount = 0
	
	function InitTimers()
	{
		if ( TimersActive && TimerThinkEnt && TimerThinkEnt.IsValid() )
			return
		
		if ( TimerThinkEnt && !TimerThinkEnt.IsValid() )
		{
			TimerThinkEnt = null
			TimersActive = false
		}
		
		// Use logic_timer (engine-managed, immune to think overwrites)
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
		
		// Global wrapper avoids :: in AddOutput (colon delimiter conflict)
		if ( "__maolib_timer_think" in getroottable() )
			delete getroottable()["__maolib_timer_think"]
		getroottable()["__maolib_timer_think"] <- @() ::MaoLib.TimerThink()
		
		EntFire( "maolib_timer_manager", "AddOutput", "OnTimer !self:RunScriptCode:__maolib_timer_think():0:-1", 0, null )
		EntFire( "maolib_timer_manager", "Enable", "", 0.01, null )
		
		TimersActive = true
		
		if ( IsDeveloperMode() )
			printl( "[MaoLib.InitTimers] Timer manager initialized" )
	}
	
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
				try { timer.callback() }
				catch ( e )
				{
					if ( IsDeveloperMode() )
						printl( "[MaoLib.TimerThink] ERROR in timer '" + name + "': " + e )
				}
				timer.totalTime += Time() - startTime
			}
		}
		
		return 0.01  // 100Hz max resolution
	}
	
	function AddTimer( name, interval, callback )
	{
		if ( !TimersActive ) InitTimers()
		
		if ( name in Timers )
		{
			if ( IsDeveloperMode() )
				printl( "[MaoLib.AddTimer] WARNING: Timer '" + name + "' exists. Use AddTimerForce() to overwrite." )
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
			printl( "[MaoLib.AddTimer] Registered '" + name + "' (interval=" + interval + ")" )
		
		return true
	}
	
	function AddTimerForce( name, interval, callback )
	{
		if ( !TimersActive ) InitTimers()
		
		Timers[ name ] <- {
			callback = callback
			interval = interval
			nextRun = Time() + interval
			active = true
			execCount = 0
			totalTime = 0.0
		}
		
		if ( IsDeveloperMode() )
			printl( "[MaoLib.AddTimerForce] Overwrote '" + name + "' (interval=" + interval + ")" )
		
		return true
	}
	
	function AddTimerSafe( name, interval, callback )
	{
		if ( name in Timers ) return false
		return AddTimer( name, interval, callback )
	}
	
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
	
	function RemoveTimer( name )
	{
		if ( name in Timers )
		{
			delete Timers[ name ]
			if ( IsDeveloperMode() )
				printl( "[MaoLib.RemoveTimer] Removed timer '" + name + "'" )
		}
	}
	
	function PauseTimer( name )
	{
		if ( name in Timers )
			Timers[ name ].active = false
	}
	
	function ResumeTimer( name )
	{
		if ( name in Timers )
		{
			Timers[ name ].active = true
			Timers[ name ].nextRun = Time() + Timers[ name ].interval
		}
	}
	
	function IsTimerActive( name )
	{
		return ( name in Timers ) && Timers[ name ].active
	}
	
	function GetTimerCount() { return Timers.len() }
	
	function ClearAllTimers()
	{
		Timers.clear()
		
		if ( TimerThinkEnt && TimerThinkEnt.IsValid() )
		{
			EntFireByHandle( TimerThinkEnt, "Disable", "", 0, null, null )
			TimerThinkEnt.Kill()
			TimerThinkEnt = null
		}
		
		TimersActive = false
		TimerFrameCount = 0
		
		if ( IsDeveloperMode() )
			printl( "[MaoLib.ClearAllTimers] All timers cleared" )
	}

	function GetTimerTable() { return Timers }
	function GetTimerDelta( prevCount ) { return Timers.len() - prevCount }
	
	function PrintTimerStats()
	{
		printl( "=== MaoLib Timer Stats ===" )
		printl( "Active timers: " + Timers.len() )
		printl( "Think frames: " + TimerFrameCount )
		foreach ( name, timer in Timers )
		{
			local avgTime = ( timer.execCount > 0 ) ? ( timer.totalTime / timer.execCount ) : 0
			printl( "  " + name + ": exec=" + timer.execCount + " avg=" + format( "%.4f", avgTime ) + "s active=" + timer.active )
		}
		printl( "==========================" )
	}
	
	function GetTimerDebugInfo()
	{
		local now = Time()
		local info = ""
		info += "=== MaoLib Timer Debug ===\n"
		info += "Total timers: " + Timers.len() + "\n"
		info += "System active: " + ( TimersActive ? "YES" : "NO" ) + "\n"
		info += "Think entity valid: " + ( TimerThinkEnt && TimerThinkEnt.IsValid() ? "YES" : "NO" ) + "\n"
		info += "Think frames: " + TimerFrameCount + "\n"
		
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
		return info
	}
}

// ============================================================
// AUTO-LOAD SUBMODULES
// ============================================================
// These submodules provide extended functionality.
// They are loaded automatically for convenience but can be
// controlled individually if you include maolib.nut manually.
// ============================================================

// Timer monitoring and leak detection
if ( !("MaoLib_TimersCleanup" in getroottable()) )
{
	IncludeScript( "maolib_timers_cleanup", getroottable() )
}

// Visual effects system
if ( !("MaoLib_VFX" in getroottable()) )
{
	IncludeScript( "maolib_vfx", getroottable() )
}

// Navigation utilities
if ( !("MaoLib_NavUtils" in getroottable()) )
{
	IncludeScript( "maolib_navutils", getroottable() )
}

printl( "[MaoLib] Core + Submodules loaded (Timers, VFX, NavUtils)" )
