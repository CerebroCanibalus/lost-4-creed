IncludeScript( "maolib", getroottable() )

::Poltergeists <-
{
	Options =
	{
		team = 7
		objects = 1
		usedist = false
		usemass = false
		force = 64
		distance = 128
		mass = 0
		dangerous = false
		offsetdist = 128
		items = true
		ragdolls = true
	}

	OptionsFile =
	[
		"// bitfield to control which teams' spectators are allowed to be poltergeists (1 = spectators, 2 = survivors, 4 = infected)"
		"team"
		"\n"
		"// bitfield of what poltergeists are allowed to interact with (1 = anything with physics, 2 = incapped survivorsss, 3 = both)"
		"objects"
		"\n"
		"// how much force to use on an object"
		"force"
		"\n"
		"// adjust the force of pulling/pushing things based on it's distance to the cursor?"
		"usedist"
		"\n"
		"// adjust the force of grabbing/pushing things based on it's mass? (currently doesnt do anything)"
		"usemass"
		"\n"
		"// distance between object and poltergeist crosshairs before they start getting manipulated"
		"distance"
		"\n"
		"// poltergeists can only grab props under this mass (0 means any mass) (currently doesnt do anything)"
		"mass"
		"\n"
		"// allow poltergeists to interact with props that are potentially dangerous and can kill?"
		"dangerous"
		"\n"
		"// distance offset to the camera when grabbing physics props and incapped survivors"
		"offsetdist"
		"\n"
		"// allow interacting with actual items when allowed to interact with props? (i.e. dropped medkits/guns)"
		"items"
		"\n"
		"// allow interacting with server side ragdolls?"
		"ragdolls"
	]

	function IsTeamAllowed( team )
	{
		return Options.team & ( 1 << ( team - 1 ) )
	}

	function GetTeam( player )
	{
		return NetProps.GetPropInt( player, "m_iTeamNum" )
	}

	function IsPhysicsEnabled( ent )
	{
		return NetProps.GetPropInt( ent, "movetype" ) == 6
	}

	function IsMassAcceptable( obj )
	{
		if ( Options.mass <= 0 )
			return true

		return true
	}

	function IsIdle( player )
	{
		local spec_target = NetProps.GetPropEntity( player, "m_hObserverTarget" )

		if ( !spec_target || !spec_target.IsValid() || !spec_target.IsSurvivor() )
			return false

		return ( NetProps.GetPropInt( spec_target, "m_humanSpectatorUserID" ) == player.GetPlayerUserId() )
	}

	// would prefer having some sort of mass system, which i could use to manipulate the force used and whether or not you can grab objects, but hey, i couldnt find any way of getting object mass
	function IsDangerous( prop )
	{
		// if ( prop.GetClassname() == "prop_car_alarm" )
			// return true

		local modelname = prop.GetModelName()

		if ( modelname.find( "props_vehicles/" ) && !modelname.find( "tire001" ) )
			return true

		switch( modelname )
		{
			case "models/props/cs_assault/forklift.mdl":
			case "models/props_junk/dumpster_2.mdl":
				return true
			break
		}

		return false
	}

	function IsItem( prop )
	{
		local classname = prop.GetClassname()

		return !( classname.find( "prop" ) || classname.find( "phys" ) )
	}

	function IsAllowed( obj )
	{
		// if ( !IsMassAcceptable( obj ) )
			// return false

		if ( !Options.dangerous && IsDangerous( obj ) )
			return false

		if ( !Options.items && IsItem( obj ) )
			return false

		if ( !Options.ragdolls && obj.GetClassname() == "prop_ragdoll" )
			return false

		return true
	}

	function PhysMonitor(timerName, player, scope)
	{
		if ( !MaoLib.IsReal( player ) || MaoLib.IsAlive( player ) || IsPlayerABot( player ) )
		{
			MaoLib.RemoveTimer(timerName)
			return
		}

		if ( Poltergeists.IsIdle( player ) )
			return

		if ( !( player.GetButtonMask() & 32  /* IN_USE */ ) && !( player.GetButtonMask() & 8192  /* IN_RELOAD */ ) )
			return

		local dest = player.EyePosition() + ( player.GetForwardVector() * Poltergeists.Options.offsetdist )

		local offsetdest = ( player.GetButtonMask() & 32  /* IN_USE */ ) ? dest : player.EyePosition()

		local multiplier = ( player.GetButtonMask() & 32  /* IN_USE */ ) ? Poltergeists.Options.force : -Poltergeists.Options.force

		if ( !scope.poltergeists_poltertype )
		{
			for ( local prop = null; prop = Entities.FindByClassnameWithin( prop, "*", dest, Poltergeists.Options.distance ); )
			{
				if ( !prop || !prop.IsValid() || !Poltergeists.IsPhysicsEnabled( prop ) || !Poltergeists.IsAllowed( prop ) )
					continue

				local offset = MaoLib.VectorAngle( offsetdest - prop.GetCenter() )

				local dist = ( Poltergeists.Options.usedist ) ? MaoLib.DistanceBetween( offsetdest, prop.GetCenter() ) / Poltergeists.Options.distance : 1

				prop.ApplyAbsVelocityImpulse( ( AnglesToForward(offset) * multiplier ) * dist )
			}
		}
		else
		{
			for ( local survivor = null; survivor = Entities.FindByClassnameWithin( survivor, "player", dest, Poltergeists.Options.distance ); )
			{
				if ( !survivor || !survivor.IsValid() || !survivor.IsSurvivor() || !survivor.IsIncapacitated() || !MaoLib.IsAlive( survivor ) )
					continue

				if ( NetProps.GetPropInt( survivor, "m_fFlags" ) & 1 )
					survivor.SetOrigin( survivor.GetOrigin() + Vector( 0, 0, 16 ) )

				local offset = MaoLib.VectorAngle( dest - survivor.GetCenter() )

				local dist = MaoLib.DistanceBetween( dest, survivor.GetCenter() )

				if ( dist > 24 )
					survivor.SetVelocity( AnglesToForward(offset) * ( multiplier * 3.5 ) )
			}
		}
	}

	function TypeMonitor(timerName, player, scope, key_pressed)
	{
		if ( !MaoLib.IsReal( player ) || MaoLib.IsAlive( player ) || IsPlayerABot( player ) )
		{
			MaoLib.RemoveTimer(timerName)
			return
		}

		if ( !( player.GetButtonMask() & 131072 ) )
		{
			key_pressed = false
			return
		}

		// scope = 524288

		if ( key_pressed )
			return

		key_pressed = true

		local poltertype = scope.poltergeists_poltertype

		poltertype = !poltertype

		scope.poltergeists_poltertype <- poltertype
	}

	function Ghostify( player )
	{
		player.ValidateScriptScope()

		local scope = player.GetScriptScope()

		if ( Poltergeists.Options.objects > 0 )
		{
			local props_allowed = Poltergeists.Options.objects & 1
			local incap_allowed = Poltergeists.Options.objects & 2

			if ( incap_allowed && !props_allowed )
				scope.poltergeists_poltertype <- 1
			else
				scope.poltergeists_poltertype <- 0

			local physTimer = "poltergeists_phys_" + player.GetEntityIndex()
			MaoLib.AddTimerForce(physTimer, 0.15, function() { ::Poltergeists.PhysMonitor(physTimer, player, scope); })

			if ( props_allowed && incap_allowed )
			{
				local typeTimer = "poltergeists_type_" + player.GetEntityIndex()
				local keyPressed = false
				MaoLib.AddTimerForce(typeTimer, 0.1, function() { ::Poltergeists.TypeMonitor(typeTimer, player, scope, keyPressed); })
			}
		}
	}

	function OnGameEvent_player_death( opts )
	{
		if ( !MaoLib.AllPresent( opts, "userid" ) )
			return

		local player = GetPlayerFromUserID( opts.userid )

		if ( !MaoLib.IsReal( player ) )
			return

		if ( IsPlayerABot( player ) )
			return

		if ( !IsTeamAllowed( GetTeam( player ) ) )
			return

		Ghostify( player )
	}

	function OnGameEvent_player_team( opts )
	{
		if ( !MaoLib.AllPresent( opts, "userid", "team" ) )
			return

		if ( !IsTeamAllowed( opts.team.tointeger() ) )
			return

		local player = GetPlayerFromUserID( opts.userid )

		if ( !MaoLib.IsReal( player ) )
			return

		if ( IsPlayerABot( player ) )
			return

		Ghostify( player )
	}

	function OnGameEvent_round_start( opts )
	{
		Options = MaoLib.InitOptionsFmt( Options, "poltergeists/options.cfg", OptionsFile )
	}
}

function AnglesToForward(angles)
{
	local yaw = angles.y * (3.14159265 / 180.0)
	local pitch = angles.x * (3.14159265 / 180.0)
	local cp = cos(pitch)
	return Vector(cos(yaw) * cp, sin(yaw) * cp, -sin(pitch))
}

__CollectGameEventCallbacks( Poltergeists )
