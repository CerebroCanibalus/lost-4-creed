// HEgrenade
printl("Credits to CHAUS");
Convars.SetValue("pipe_bomb_shake_amplitude" 100)
Convars.SetValue("pipe_bomb_shake_radius" 2000)
Convars.SetValue("pipe_bomb_timer_duration" 2)
Convars.SetValue("pipe_bomb_beep_interval_delta" 0.015)
Convars.SetValue("pipe_bomb_beep_min_interval" 0.08)
Convars.SetValue("pipe_bomb_initial_beep_interval" 0.35)

if ( Director.GetGameModeBase() == "holdout" || Director.GetGameModeBase() == "scavenge" || Director.GetGameModeBase() == "survival" || Director.GetGameModeBase() == "versus" )
{
Convars.SetValue("pipe_bomb_shake_amplitude" 100)
Convars.SetValue("pipe_bomb_shake_radius" 2000)
Convars.SetValue("pipe_bomb_timer_duration" 2)
Convars.SetValue("pipe_bomb_beep_interval_delta" 0.015)
Convars.SetValue("pipe_bomb_beep_min_interval" 0.08)
Convars.SetValue("pipe_bomb_initial_beep_interval" 0.35)
	printl("HEgrenade");
}

if ( Director.GetGameModeBase() == "mutation2" || Director.GetGameModeBase() == "realism" )
{
Convars.SetValue("pipe_bomb_shake_amplitude" 100)
Convars.SetValue("pipe_bomb_shake_radius" 2000)
Convars.SetValue("pipe_bomb_timer_duration" 2)
Convars.SetValue("pipe_bomb_beep_interval_delta" 0.015)
Convars.SetValue("pipe_bomb_beep_min_interval" 0.08)
Convars.SetValue("pipe_bomb_initial_beep_interval" 0.35)
	printl("HEgrenade");
}

if ( Director.GetGameModeBase() == "mutation3" || Director.GetGameModeBase() == "mutation4" || Director.GetGameModeBase() == "mutation11" || Director.GetGameModeBase() == "mutation12" || Director.GetGameModeBase() == "mutation14" || Director.GetGameModeBase() == "mutation16" || Director.GetGameModeBase() == "mutation18" || Director.GetGameModeBase() == "community1" || Director.GetGameModeBase() == "community4" || Director.GetGameModeBase() == "mutation5" || Director.GetGameModeBase() == "mutation6" )
{
Convars.SetValue("pipe_bomb_shake_amplitude" 100)
Convars.SetValue("pipe_bomb_shake_radius" 2000)
Convars.SetValue("pipe_bomb_timer_duration" 2)
Convars.SetValue("pipe_bomb_beep_interval_delta" 0.015)
Convars.SetValue("pipe_bomb_beep_min_interval" 0.08)
Convars.SetValue("pipe_bomb_initial_beep_interval" 0.35)
	printl("HEgrenade");
}

if ( Director.GetGameModeBase() == "mutation5" || Director.GetGameModeBase() == "mutation6" || Director.GetGameModeBase() == "mutation7" || Director.GetGameModeBase() == "mutation8" || Director.GetGameModeBase() == "mutation9" )
{
Convars.SetValue("pipe_bomb_shake_amplitude" 100)
Convars.SetValue("pipe_bomb_shake_radius" 2000)
Convars.SetValue("pipe_bomb_timer_duration" 2)
Convars.SetValue("pipe_bomb_beep_interval_delta" 0.015)
Convars.SetValue("pipe_bomb_beep_min_interval" 0.08)
Convars.SetValue("pipe_bomb_initial_beep_interval" 0.35)
	printl("HEgrenade");
}

printl("Thanks Kuro, amazing addons!");
kuro_atomic_pipe_bomb <-
{
    atomic_pipe_bomb_user = 3
    atomic_pipe_bomb_damage = 1000
    atomic_pipe_bomb_radius = 400
    allow_damage_on_survivor = 1
    allow_timed_explosion = 1

	function VectorFromQAngle(angles, radius = 1.0)
	{
		local function ToRad(angle)
		{
			return (angle * PI) / 180;
		}
		local yaw = ToRad(angles.Yaw());
		local pitch = ToRad(-angles.Pitch());
		local x = radius * cos(yaw) * cos(pitch);
		local y = radius * sin(yaw) * cos(pitch);
		local z = radius * sin(pitch);
		return Vector(x, y, z);
	}
	
	function IsAvailableEntity(kent)
	{
		if(kent)
		{
			return true;
		}
		return false;
		
	}
	
	function GetActiveMainWeapon(player)
	{
		local weapon = player.GetActiveWeapon();
		
		if(weapon)
			return weapon.GetClassname();
			
		return null;
	}
	
	function AtomicExplosion(kent, explotarget)
	{
		local dir = ::kuro_atomic_pipe_bomb;
		
		local gltarget = SpawnEntityFromTable("env_explosion", {
			targetname = "atomic_pipebomb_" + GetCharacterDisplayName(kent),
			iRadiusOverride = dir.atomic_pipe_bomb_radius,
			fireballsprite = "sprites/zerogxplode.spr",
			ignoredClass = 1,
			iMagnitude = dir.atomic_pipe_bomb_damage,
			rendermode = 5,
			spawnflags = 6 | 256 // No effects,
			origin = Vector(0, 0, 0)
		});
		gltarget.SetOrigin(explotarget.GetOrigin() + Vector(0,0,0));
		NetProps.SetPropEntity(gltarget, "m_hOwnerEntity", kent);
		
		local particle = SpawnEntityFromTable("info_particle_system", {
			effect_name = "gas_explosion_main_fallback",
			cpoint1 = "#" + gltarget.GetEntityIndex()
			
		});
		particle.SetOrigin(gltarget.GetOrigin() + Vector(0,0,6));
		DoEntFire("!self", "Start", "", 0, null, particle);
		EmitSoundOn("GrenadeLauncher.Explode", gltarget);
		for(local victim; victim = Entities.FindByClassname(victim, "player"); )
		{
			if(NetProps.GetPropInt(victim, "m_lifeState") == 0)
			{
				if((gltarget.GetOrigin() - victim.GetOrigin()).Length() <= dir.atomic_pipe_bomb_radius)
				{
					local inexploradius = dir.atomic_pipe_bomb_radius - ((gltarget.GetOrigin() - victim.GetOrigin()).Length());
					local radiusdamage = (dir.atomic_pipe_bomb_damage * (inexploradius /dir.atomic_pipe_bomb_radius));
					
					if(victim.GetZombieType() == 9)
					{
						victim.Stagger(gltarget.GetOrigin());
						if(dir.allow_damage_on_survivor != 0)
						{
							if(Convars.GetStr("z_difficulty") == "Normal")
							{
								victim.TakeDamage((radiusdamage * 0.1), 6, kent);
							}
							else if(Convars.GetStr("z_difficulty") == "Hard")
							{
								victim.TakeDamage((radiusdamage * 0.25), 6, kent);
							}
							else if(Convars.GetStr("z_difficulty") == "Impossible")
							{
								victim.TakeDamage((radiusdamage * 0.5), 6, kent);
							}
							else
							{
								victim.TakeDamage((radiusdamage * 0.1), 6, kent);
							}
							
						}
					}
					else
					{
						local direction = (gltarget.GetOrigin() - victim.GetOrigin());
						local distanceFactor = (1 + direction.Length() / 500);
						
						victim.SetOrigin(victim.GetOrigin() + Vector(0,0,1));
						victim.SetVelocity((victim.GetVelocity() + Vector(0,0,666)) + (direction * (1 / direction.Length()) * (1 - 966) * distanceFactor));
						
						victim.TakeDamage((dir.atomic_pipe_bomb_damage * 1), 6, kent);
					}
				}
				
			}
			
		}
		DoEntFire("!self", "Explode", "", 0, kent, gltarget);
		DoEntFire("!self", "Kill", "", 0.5, kent, particle);
		DoEntFire("!self", "Kill", "", 0.75, kent, gltarget);
		
	}
	function AtomicExplosion2(userid)
	{
		local dir = ::kuro_atomic_pipe_bomb;
		local kent = GetPlayerFromUserID(userid);
		
		
		for(local victim; victim = Entities.FindByClassname(victim, "pipe_bomb_projectile"); )
		{
			if(NetProps.GetPropEntity(victim, "m_hThrower") == kent)
			{
				AtomicExplosion(kent, victim);
				victim.Kill();
			}
			
		}
		
	}
	function MercilessToggleFileCheck(filename)
	{
		local files = FileToString(filename);
		if(!files)
		{
			return false;
		}
		return true;
	}
	
	function GenerateCfgFile()
	{
		local DefaultToggleFile = "";
		
		local CfgToggleFile =
		[
			"atomic_pipe_bomb_user = 3",
			"atomic_pipe_bomb_damage = 350",
			"atomic_pipe_bomb_radius = 500",
			"allow_damage_on_survivor = 0",
			"allow_timed_explosion = 0",
			"."
			"."
			"."
			"// ====== TOGGLE SETTING INFO ======",
			"//atomic_pipe_bomb_user= Which type of survivor can use this.",
			"0= Off.",
			"1= On, bots only.",
			"2= On, players only.",
			"3= On, all.",
			".",
			"//atomic_pipe_bomb_damage= The damage of atomic pipebomb. (NOTES: The farther from the center of explosion, the less damage)",
			"0= Damage is 1.",
			"1 or above= Damage is (1 * value).",
			".",
			"//atomic_pipe_bomb_radius= The explosion radius.",
			"0= Radius is 1.",
			"1 or above= Radius is (1 * value).",
			".",
			"//allow_damage_on_survivor= When enabled, survivor can take damage from the atomic pipebomb.",
			"0= Off, no damage.",
			"1= On. Damage reduction is based on difficulty level. Easy/ Normal= 10%, Advanced= 25%, Expert= 50%",
			".",
			"//allow_timed_explosion= When enabled, the explosion time follow the pipebomb tick timer. Use this if you want to combine with 'Saiyan Pipebomb' or maintain the main function of pipebomb to gather zombies.",
			"0= Off.",
			"1= On.",
			".",
			".",
			"// =================================",
			"//Notes: The damage & the radius coexist, as the radius affects the damage increase/ decrease (damage formula= radius / damage). For example, if the damage is 50 & the radius is 400, if you're in radius of 360 away from the center of explosion, you take 5 damage.",
			"//Notes 2: This file is generated automatically when using this mod for the first time. To make the changes in the cfg file take effect, press RELOAD when reloading your gun. To reset the this toggle back to the default, delete the file & then hold TAB + reload your gun.",
			"."
			
		]
		
		foreach (line in CfgToggleFile)
		{
			DefaultToggleFile = DefaultToggleFile + line + "\n";
		}
		if(!MercilessToggleFileCheck("atomic pipe bomb cfg/atomic pipe bomb.txt"))
		{
			
			StringToFile("atomic pipe bomb cfg/atomic pipe bomb.txt", DefaultToggleFile);
			printl("The 'atomic pipe bomb.txt' file can't be found. Generating a new 'atomic pipe bomb.txt' file...");
			
		}
		
	}
	function LoadSpecificConfigFile(filename)
	{
		local dir = ::kuro_atomic_pipe_bomb;
		if(!(FileToString(filename)))
		{
			GenerateCfgFile();
		}
		else
		{
			local files = FileToString(filename);
			local toggles = split(files, "\r\n");
			foreach(toggle in toggles)
			{
				if(toggle && toggle != "")
				{
					toggle = strip(toggle);
					local idx = toggle.find(" = ");
					if(idx != null)
					{
						local togglecommand = toggle.slice(0, idx);
						local togglevalue = toggle.slice(idx + 3);
						
						if(togglecommand == "atomic_pipe_bomb_user")
						{
							dir.atomic_pipe_bomb_user = togglevalue.tointeger();
							
						}
						if(togglecommand == "atomic_pipe_bomb_damage")
						{
							dir.atomic_pipe_bomb_damage = togglevalue.tointeger();
							
						}
						if(togglecommand == "atomic_pipe_bomb_radius")
						{
							dir.atomic_pipe_bomb_radius = togglevalue.tointeger();
							
						}
						if(togglecommand == "allow_damage_on_survivor")
						{
							dir.allow_damage_on_survivor = togglevalue.tointeger();
							
						}
						if(togglecommand == "allow_timed_explosion")
						{
							dir.allow_timed_explosion = togglevalue.tointeger();
							
						}
						
					}
					
				}
			}
		}
		
	}
	
	function OnGameEvent_grenade_bounce(event)
	{
		local dir = ::kuro_atomic_pipe_bomb;
		
		local kent = GetPlayerFromUserID(event.userid);
		
		if(kent.IsSurvivor())
		{
			if(dir.allow_timed_explosion == 0)
			{
				if(Entities.FindByClassname(null, "pipe_bomb_projectile"))
				{
					for(local homing_projectile; homing_projectile = Entities.FindByClassname(homing_projectile, "pipe_bomb_projectile"); )
					{
						if(NetProps.GetPropEntity(homing_projectile, "m_hThrower") == kent)
						{
							if(dir.atomic_pipe_bomb_user == 1 || dir.atomic_pipe_bomb_user >= 3)
							{
								if(IsPlayerABot(kent))
								{
									if(!Entities.FindByNameWithin(null, "atomic_pipebomb_*", homing_projectile.GetOrigin(), 150))
									{
										AtomicExplosion(kent, homing_projectile);
									}
									if (homing_projectile && homing_projectile.IsValid()) homing_projectile.Kill();
								}
							}
							if(dir.atomic_pipe_bomb_user >= 2)
							{
								if(!IsPlayerABot(kent))
								{
									if(!Entities.FindByNameWithin(null, "atomic_pipebomb_*", homing_projectile.GetOrigin(), 150))
									{
										AtomicExplosion(kent, homing_projectile);
									}
									if (homing_projectile && homing_projectile.IsValid()) homing_projectile.Kill();
								}
							}
							
						}
						
					}
					
				}
				
			}
			
		}
		
	}
	
	function OnGameEvent_weapon_fire(event)
	{
		local dir = ::kuro_atomic_pipe_bomb;
		local kent = GetPlayerFromUserID(event.userid);
		
		if(kent.IsSurvivor())
		{
			if(dir.allow_timed_explosion != 0)
			{
				if(dir.atomic_pipe_bomb_user == 1 || dir.atomic_pipe_bomb_user >= 3)
				{
					if(IsPlayerABot(kent))
					{
						if(GetActiveMainWeapon(kent) == "weapon_pipe_bomb")
						{
							EntFire("worldspawn", "RunScriptCode", "::kuro_atomic_pipe_bomb.AtomicExplosion2(" + event.userid + ")", (Convars.GetFloat("pipe_bomb_timer_duration") - 0.5));
						}
					}
				}
				if(dir.atomic_pipe_bomb_user >= 2)
				{
					if(!IsPlayerABot(kent))
					{
						if(GetActiveMainWeapon(kent) == "weapon_pipe_bomb")
						{
							EntFire("worldspawn", "RunScriptCode", "::kuro_atomic_pipe_bomb.AtomicExplosion2(" + event.userid + ")", (Convars.GetFloat("pipe_bomb_timer_duration") - 0.5));
						}
					}
				}
				
			}
			
		}
	}
	function OnGameEvent_weapon_reload(event)
	{
		local dir = ::kuro_atomic_pipe_bomb;
		local kent = GetPlayerFromUserID(event.userid);
		
		if(kent.IsSurvivor())
		{
			if(!IsPlayerABot(kent))
			{
				LoadSpecificConfigFile("atomic pipe bomb cfg/atomic pipe bomb.txt");
			}
			
			if(dir.atomic_pipe_bomb_damage < 1) dir.atomic_pipe_bomb_damage = 1;
			if(dir.atomic_pipe_bomb_radius < 1) dir.atomic_pipe_bomb_radius = 1;
		}
	}
	function OnGameEvent_round_start_post_nav(event)
	{
		LoadSpecificConfigFile("atomic pipe bomb cfg/atomic pipe bomb.txt");
	}
	
}
printl("The 'ATOMIC PIPE BOMB' mod is launched.");
__CollectGameEventCallbacks(kuro_atomic_pipe_bomb);