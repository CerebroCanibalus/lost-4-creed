IncludeScript( "maolib", getroottable() )

function AnglesToForward(angles)
{
	local yaw = angles.y * (3.14159265 / 180.0)
	local pitch = angles.x * (3.14159265 / 180.0)
	local cp = cos(pitch)
	return Vector(cos(yaw) * cp, sin(yaw) * cp, -sin(pitch))
}

::SpecialDoors <-
{
	Options =
	{
		open_doors = true
		close_doors = true
		check = 0.25
		allow_tanks = true
		rescue_doors = false
		saferoom_doors = true
		who = 3
		specials = -1
	}

	OptionsFile =
	[
		"// allows specials to open doors"
		"open_doors"
		"\n"
		"// allows specials to close doors (sadly only for players as of now)"
		"close_doors"
		"\n"
		"// how often (in seconds) specials check for doors to open"
		"check"
		"\n"
		"// whether or not tanks should be allowed to open/close doors"
		"allow_tanks"
		"\n"
		"// allow opening doors that can rescue survivors?"
		"rescue_doors"
		"\n"
		"// allow opening saferoom doors?"
		"saferoom_doors"
		"\n"
		"// bitfield of who open doors (1 = bots, 2 = players)"
		"who"
		"\n"
		"// bitfield to allow different specials to open doors (not including tanks)"
		"// (-1 = all, 1 = smoker, 2 = boomer, 4 = hunter, 8 = spitter, 16 = jockey, 32 = charger, 64 = witch )"
		"specials"
	]

	function GetSpecialField( special )
	{
		if ( special.GetClassname() == "witch" )
			return 64

		if ( special.GetZombieType() == 1  /* ZOMBIE_SMOKER */ )
			return 1

		return pow( 2, special.GetZombieType() - 1 )
	}

	function IsSpecialAllowed( special )
	{
		if ( Options.specials == -1 )
			return true

		return Options.specials & GetSpecialField( special ).tointeger()
	}

	function OpenDoor( door, special = null )
	{
		DoEntFire( "!self", "OpenAwayFrom", "!activator", 0, special, door )
	}

	function IsOpen( door )
	{
		// 0 = closed
		// 1 = opening
		// 2 = opened
		// 3 = closing

		local state = NetProps.GetPropInt( door, "m_eDoorState" )

		return state == 1 || state == 2
	}

	function CloseDoor( door, special = null )
	{
		DoEntFire( "!self", "Close", "", 0, special, door )
	}

	function IsLookingAt( door, special )
	{
		local whatever = door.GetCenter() - GetEyePosition( special )
		local forward = AnglesToForward(GetEyeAngles(special))

		local cosine = whatever.Dot( forward ) / ( whatever.Length() * forward.Length() )

		return cosine >= 0.75
	}

	function IsRescueDoor( door )
	{
		return ( NetProps.GetPropInt( door, "m_isRescueDoor" ) )
	}

	function IsRescueEnabled()
	{
		return !( Convars.GetFloat( "sv_rescue_disabled" ) )
	}

	function IsWitch( special )
	{
		return special.GetClassname() == "witch"
	}

	function GetEyePosition( special )
	{
		return !IsWitch( special ) ? special.EyePosition() : special.GetCenter() + Vector( 0, 0, 16 )
	}

	function GetEyeAngles( special )
	{
		return !IsWitch( special ) ? special.EyeAngles() : special.GetAngles()
	}

	function Monitor(timerName, special)
	{
		if ( !MaoLib.IsReal( special ) || !MaoLib.IsAlive( special ) || ( !SpecialDoors.IsWitch( special ) && !IsPlayerABot( special ) ) )
		{
			MaoLib.RemoveTimer(timerName)
			return
		}

		for ( local door = null; door = Entities.FindByClassnameWithin( door, "prop_door_rotating*", SpecialDoors.GetEyePosition( special ), 80.0 ); )
		{
			if ( !MaoLib.IsReal( door ) )
				continue

			// avoid opening rescue doors to avoid accidentally rescuing survivors... or preventing them from being rescued ;)
			if ( SpecialDoors.IsRescueEnabled() && SpecialDoors.IsRescueDoor( door ) && !SpecialDoors.Options.rescue_doors )
				continue

			// the user is scared and disabled opening saferoom doors
			if ( door.GetClassname() == "prop_door_rotating_checkpoint" && !SpecialDoors.Options.saferoom_doors )
				continue

			if ( !SpecialDoors.IsLookingAt( door, special ) )
				continue

			if ( !SpecialDoors.Options.open_doors )
				continue

			SpecialDoors.OpenDoor( door, special )
		}
	}

	function PlayerMonitor(timerName, special, key_pressed)
	{
		if ( !MaoLib.IsReal( special ) || !MaoLib.IsAlive( special ) || special.IsSurvivor() || IsPlayerABot( special ) )
		{
			MaoLib.RemoveTimer(timerName)
			return
		}

		if ( !( special.GetButtonMask() & 32  /* IN_USE */ ) )
		{
			key_pressed = false
			return
		}

		if ( key_pressed )
			return

		key_pressed = true

		local line =
		{
			start = special.EyePosition()
			end = special.EyePosition() + special.GetForwardVector() * 120
			ignore = special
			enthit = null
		}

		TraceLine( line )

		if ( !line.hit || !MaoLib.IsReal( line.enthit ) || !MaoLib.startswith( line.enthit.GetClassname(), "prop_door_rotating" ) )
			return

		local door = line.enthit

		if ( SpecialDoors.IsRescueEnabled() && SpecialDoors.IsRescueDoor( door ) && !SpecialDoors.Options.rescue_doors )
			return

		if ( door.GetClassname() == "prop_door_rotating_checkpoint" && !SpecialDoors.Options.saferoom_doors )
			return

		local door_state = NetProps.GetPropInt( door, "m_eDoorState" )

		if ( door_state == 0 && SpecialDoors.Options.open_doors )
			SpecialDoors.OpenDoor( door, special )
		else if ( door_state == 2 && SpecialDoors.Options.close_doors )
			SpecialDoors.CloseDoor( door, special )
	}

	function OnGameEvent_player_spawn( opts )
	{
		if ( !MaoLib.AllPresent( opts, "userid" ) )
			return

		local special = GetPlayerFromUserID( opts.userid )

		if ( !MaoLib.IsReal( special ) || special.IsSurvivor() )
			return

		if ( special.GetZombieType() == 8  /* ZOMBIE_TANK */ && !Options.allow_tanks )
			return

		if ( !IsSpecialAllowed( special ) )
			return

		if ( IsPlayerABot( special ) && Options.who & 1 )
		{
			local timerName = "specialdoors_" + special.GetEntityIndex()
			MaoLib.AddTimerForce(timerName, Options.check, function() { ::SpecialDoors.Monitor(timerName, special); })
		}
		else if ( !IsPlayerABot( special ) && Options.who & 2 )
		{
			local timerName = "specialdoors_player_" + special.GetEntityIndex()
			local keyPressed = false
			MaoLib.AddTimerForce(timerName, 0.1, function() { ::SpecialDoors.PlayerMonitor(timerName, special, keyPressed); })
		}
	}

	function OnGameEvent_witch_spawn( opts )
	{
		if ( !MaoLib.AllPresent( opts, "witchid" ) )
			return

		local witch = EntIndexToHScript( opts.witchid )

		if ( !MaoLib.IsReal( witch ) )
			return

		if ( !IsSpecialAllowed( witch ) )
			return

		local timerName = "specialdoors_witch_" + witch.GetEntityIndex()
		MaoLib.AddTimerForce(timerName, Options.check, function() { ::SpecialDoors.Monitor(timerName, witch); })
	}

	function OnGameEvent_round_start( opts )
	{
		Options = MaoLib.InitOptionsFmt( Options, "specialdoors/options.cfg", OptionsFile )
	}
}

__CollectGameEventCallbacks( SpecialDoors )
