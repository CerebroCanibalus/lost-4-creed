IncludeScript( "maolib", getroottable() )

::TankAim <-
{
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

				tmp = sqrt ( dest.x * dest.x + dest.y * dest.y )
				pitch = ( atan2( -dest.z, tmp ) * 180 / PI )

				if ( pitch < 0 )
					pitch += 360
		}

		return QAngle( pitch, yaw, 0 )
	}

	function IsThrowingRock( tank )
	{
		for ( local rock = null; rock = Entities.FindByClassname( rock, "tank_rock" ); )
		{
			if ( !MaoLib.IsReal( rock ) )
				continue

			if ( rock.GetOwnerEntity() != tank )
				continue

			if ( NetProps.GetPropInt( rock, "m_bIsLive" ) )
				continue

			return true
		}

		return false
	}

	function GetVictimRunSpeed( victim )
	{
		return ( victim.GetHealth() + victim.GetHealthBuffer() >= 40 ) ? 220 : 150
	}

	function Monitor(timerName, tank)
	{
		if ( !MaoLib.IsReal( tank ) || !MaoLib.IsAlive( tank ) || tank.IsSurvivor() || !IsPlayerABot( tank ) )
		{
			MaoLib.RemoveTimer(timerName)
			return
		}

		local target = MaoLib.GetTarget( tank )

		if ( !MaoLib.IsReal( target ) )
			return

		if ( !TankAim.IsThrowingRock( tank ) )
			return

		// distance between me and my target
		local dist = MaoLib.DistanceBetween( target.EyePosition(), tank.EyePosition() )

		// use the max amt of velocity our target can get instead of their current velocity; this is done to prevent standing still and moving after the rock has been thrown to dodge it
		// local potentialvel = Vector( TankAim.GetVictimRunSpeed( target ), TankAim.GetVictimRunSpeed( target ), target.GetVelocity().z )
		local potentialvel = target.GetVelocity()

		// amt of time it will take the rock to reach my target
		local time = dist / 800

		// get where my target will be in a few seconds accounting for how long it will take for the rock to get there
		local dest = target.EyePosition() + ( potentialvel * time )

		// account for arc when throwing
		if ( dist > 150 )
		{
			// if the tank is doing the patented low throw then aim higher
			local m = ( tank.GetSequenceName( tank.GetSequence() ) == "Throw_03" ) ? 0.0175 : 0.015

			local arc_angle = MaoLib.max( MaoLib.DistanceBetween( tank.EyePosition(), dest ) * m, 45 )
			// local arc_angle = MaoLib.max( dist * m, 45 )

			local si, co

			si = sin( arc_angle * PI / 180.0 )
			co = cos( arc_angle * PI / 180.0 )

			if ( co > 0.0 )
				dest.z += dist * si / co
		}

		local aimspot = dest

		// now hide our aimbot - not only to avoid getting noticed by the admins, but also make our rock unpredictable
		if ( dist > 300 )
		{
			local distbetween = MaoLib.DistanceBetween( target.EyePosition(), dest ) * 1.25

			local veltime = target.GetVelocity() * time

			aimspot.x = target.EyePosition().x + RandomFloat( -distbetween, distbetween ) + ( veltime.x * 0.75 )
			aimspot.y = target.EyePosition().y + RandomFloat( -distbetween, distbetween ) + ( veltime.y * 0.75 )

			// aimspot.x += RandomFloat( -veltime.x, veltime.x )
			// aimspot.y += RandomFloat( -veltime.y, veltime.y )
		}

		// now get where i need to look in order to throw the rock
		local angles = TankAim.VectorAngle( aimspot - tank.EyePosition() )

		// and finally aim
		tank.SnapEyeAngles( angles )
	}

	function HandlePlayerSpawn( opts )
	{
		if ( !MaoLib.AllPresent( opts, "userid" ) )
			return

		local tank = GetPlayerFromUserID( opts.userid )

		if ( !MaoLib.IsReal( tank ) || tank.IsSurvivor() || !IsPlayerABot( tank ) )
			return

		if ( tank.GetZombieType() != 8  /* ZOMBIE_TANK */ )
			return

		local timerName = "tankaim_" + tank.GetEntityIndex()
		MaoLib.AddTimerForce(timerName, 0.1, function() { ::TankAim.Monitor(timerName, tank); })
	}
	function OnGameEvent_player_spawn(params) { TankAim.HandlePlayerSpawn(params); }

	function Test()
	{
		foreach( player in MaoLib.YieldSpecials() )
		{
			if ( player.GetZombieType() != 8  /* ZOMBIE_TANK */ )
				continue

			local timerName = "tankaim_" + player.GetEntityIndex()
			MaoLib.AddTimerForce(timerName, 0.1, function() { ::TankAim.Monitor(timerName, player); })
		}
	}
}

TankAim.Test()

__CollectGameEventCallbacks( TankAim )
