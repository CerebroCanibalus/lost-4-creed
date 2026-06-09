Convars.SetValue("r_particle_timescale", "0.9375");
local zPos = Vector(0,0,0);
::KillEffect<-
{
	function OnGameEvent_bullet_impact(params)
	{
		zPos = Vector(params.x, params.y, params.z);
	}
	function OnGameEvent_infected_hurt(params)
	{
		HandleInfectedHurt(params);
	}

	function HandleInfectedHurt(params)
	{
		if (params.hitgroup == 1)
		{
			local Infected = EntIndexToHScript(params.entityid);
			if (Infected.GetClassname() == "witch")
				return;
			switch (NetProps.GetPropInt(Infected, "m_Gender"))
			{
				case 14:case 17:
					return;
				break;
				default:
					Infected.SetHealth(1); // Health must be lower than damage, otherwise sometimes the headshot kill effect will not trigger
				break;
			}
		}
	}
	function OnGameEvent_player_death(params)
	{
		HandlePlayerDeath(params);
	}

	function HandlePlayerDeath(params)
	{
/*============================================================================================================================
		if ("attackerentid" in params || !("attacker" in params))
		{
			return;
		}
============================================================================================================================*/
		if ("userid" in params)
		{
			local Victim = GetPlayerFromUserID(params.userid);
			if (Victim.GetZombieType() > 7)
				return;
		}
		local Killer = GetPlayerFromUserID(params.attacker);
		//EmitAmbientSoundOn("Zombie.BulletImpact", 0.675, 100, 100, Killer);
		if (params.type == 128)
			return;
		switch (params.weapon)
		{
			case "pistol":case "dual_pistols":case "smg":case "smg_silenced":case "smg_mp5":
				local Direction = Killer.EyeAngles();
				ParticleSpawn("blood_impact_hunter_01", Vector(Direction.x, Direction.y, 0), zPos);
				ParticleSpawn("blood_impact_hunter_01", Vector(Direction.x, Direction.y, 0), zPos);
			break;
			case "rifle":case "rifle_ak47":case "rifle_desert":case "rifle_sg552":
			case "pistol_magnum":case "hunting_rifle":case "sniper_military":case "sniper_scout":case "sniper_awp":
				local Direction = Killer.EyeAngles();
				ParticleSpawn("blood_impact_hunter_01", Vector(Direction.x, Direction.y, 0), zPos);
				ParticleSpawn("blood_impact_hunter_01", Vector(Direction.x, Direction.y, 0), zPos);
				ParticleSpawn("blood_impact_headshot_01", Vector(Direction.x + 135, Direction.y, 0), zPos);
			break;
			case "pumpshotgun":case "shotgun_chrome":case "autoshotgun":case "shotgun_spas":
				local Direction = Killer.EyeAngles();
				local ShotgunPos = Vector(params.victim_x, params.victim_y, params.victim_z);
				local Range = (ShotgunPos - Killer.EyePosition()).Length();
				if (Range <= 300)
				{
					ParticleSpawn("blood_impact_hunter_01", Vector(Direction.x, Direction.y, 0), zPos);
					ParticleSpawn("blood_impact_hunter_01", Vector(Direction.x, Direction.y, 0), zPos);
					ParticleSpawn("blood_impact_headshot_01", Vector(Direction.x + 123.75, Direction.y + 11.25, 0), zPos);
					ParticleSpawn("blood_impact_headshot_01", Vector(Direction.x + 123.75, Direction.y - 11.25, 0), zPos);
				}
				else if (Range <= 500)
				{
					ParticleSpawn("blood_impact_hunter_01", Vector(Direction.x, Direction.y, 0), zPos);
					ParticleSpawn("blood_impact_hunter_01", Vector(Direction.x, Direction.y, 0), zPos);
					ParticleSpawn("blood_impact_headshot_01", Vector(Direction.x + 135, Direction.y, 0), zPos);
				}
				else
				{
					ParticleSpawn("blood_impact_hunter_01", Vector(Direction.x, Direction.y, 0), zPos);
					ParticleSpawn("blood_impact_hunter_01", Vector(Direction.x, Direction.y, 0), zPos);
				}
			break;
			case "prop_minigun":case "prop_minigun_l4d1":case "rifle_m60":case "melee":case "chainsaw":
				local Direction = Killer.EyeAngles();
				local Pos = Killer.EyePosition();
				local VictimOrigin = Vector(params.victim_x, params.victim_y, params.victim_z);
				VictimOrigin.z = Pos.z + (Pos - Vector(params.victim_x, params.victim_y, Pos.z)).Length() * -tan(Direction.x * PI / 180);
				ParticleSpawn("blood_impact_headshot_01", Vector(Direction.x+123.75, Direction.y+11.25, 0), VictimOrigin);
				ParticleSpawn("blood_impact_headshot_01", Vector(Direction.x+123.75, Direction.y-11.25, 0), VictimOrigin);
			break;
			default:
				return;
			break;
		}
	}
	function ParticleSpawn(EffectName, Direction, Pos)
	{
		local Effect = SpawnEntityFromTable
		(
			"info_particle_system",
			{
				effect_name = EffectName,
				angles = Direction,
				origin = Pos,
				start_active = "1",
			}
		);
		DoEntFire("!self", "Kill", "", 0.25, null, Effect);
	}
}
__CollectGameEventCallbacks(::KillEffect);
/*============================================================================================================================
============================================================================================================================*/