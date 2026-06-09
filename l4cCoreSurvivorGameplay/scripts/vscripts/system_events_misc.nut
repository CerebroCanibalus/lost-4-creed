::SystemEventsMisc <- { Config = {}, State = {} }

::SystemEventsMisc.Jumpscare <-
{
	jumpscare_chance = 15
	jumpscare_extremity = 2
	
	FireButton = 1
	JumpButton = 2
	DuckButton = 4
	ForwardButton = 8
	BackButton = 16
	UseButton = 32
	LeftButton = 512
	RightButton = 1024
	ShoveButton = 2048
	ReloadButton = 8192
	ScoreButton = 65536
	ZoomButton = 524288
	WalkButton = 131072
	
	NickModel = "models/survivors/survivor_gambler.mdl"
	CoachModel = "models/survivors/survivor_coach.mdl"
	EllisModel = "models/survivors/survivor_mechanic.mdl"
	RochelleModel = "models/survivors/survivor_producer.mdl"
	BillModel = "models/survivors/survivor_namvet.mdl"
	LouisModel = "models/survivors/survivor_manager.mdl"
	FrancisModel = "models/survivors/survivor_biker.mdl"
	ZoeyModel = "models/survivors/survivor_teenangst.mdl"
	
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
	
	function YouAreAlreadyDead(playerid)
	{
		local attackerplayer = GetPlayerFromUserID(playerid);
		local MaxReviveCount = Convars.GetFloat("survivor_max_incapacitated_count");
		
		for(local victim; victim = Entities.FindByClassname(victim, "player"); )
		{
			if(victim.IsSurvivor())
			{
				if(IsPlayerABot(victim))
				{
					if(!victim.IsDead())
					{
						victim.SetHealth(1);
						victim.SetHealthBuffer(1);
						victim.SetReviveCount(MaxReviveCount);
						victim.TakeDamage(666, 6, Entities.First());
						Say(victim, "NANIIII......?!!", false);
					}
				}
			}
		}
	}
	
	function IsAvailableEntity(kent)
	{
		if(kent)
		{
			return true;
		}
		return false;
	}
	
	function IsCapturedByHunter(player)
	{
		local infected = null;
		while(infected = Entities.FindByClassname(infected, "player"))
		{
			if(infected.GetZombieType() != 9)
			{
				if(NetProps.GetPropEntity(infected, "m_pounceVictim") == player)
				{
					return true;
				}
			}
		}
		return false;
	}
	
	function IsSurvivorInGeneral(kent)
	{
		local player = null
		while(player = Entities.FindByClassname(player, "player"))
		{
			if(player.IsSurvivor())
			{
				if(kent == player)
				{
					return true;
				}
			}
		}
		return false;
	}

	function GetButtonPressed(kent, keyvalue)
	{
		if(kent.GetButtonMask() & keyvalue)
		{
			return true;
		}
		return false;
	}
	
	function GetPrimarySlot(player)
	{
		local invTable = {};
		GetInvTable(player, invTable);

		if(!("slot0" in invTable))
			return null;
			
		local weapon = invTable.slot0;
		
		if(weapon)
			return weapon.GetClassname();
			
		return null;
	}
	
	function GetSecondarySlot(player)
	{
		local invTable = {};
		GetInvTable(player, invTable);

		if(!("slot1" in invTable))
			return null;
			
		local weapon = invTable.slot1;
		
		if(weapon)
			return weapon.GetClassname();
			
		return null;
	}
	
	function GetActiveMainWeapon(player)
	{
		local weapon = player.GetActiveWeapon();
		
		if(weapon)
			return weapon.GetClassname();
			
		return null;
	}
	
	function PlayerChat(kent, chat)
	{
		local argv = ::split( chat.slice(1), " " )
	}
	
	function DisableGodModeOnAll(kent)
	{
		local traceEndpoint = kent.EyePosition() + VectorFromQAngle(kent.EyeAngles(), 666666);
		local traceTable =
		{
			start = kent.EyePosition()
			end = traceEndpoint
			ignore = kent
		}
		TraceLine(traceTable)
		if("enthit" in traceTable)
		{
			local survteam = null;
			while(survteam = Entities.FindByClassname(survteam, "player"))
			{
				if(survteam.IsSurvivor())
				{
					NetProps.SetPropInt(survteam, "m_takedamage", 2);
				}
			}
		}
	}
	
	function SpawnJumpScare(kent, zombietype)
	{
		local spawnloc = kent.GetOrigin() + Vector(0,0,1) + (kent.GetAngles().Forward() * 136);
		
		if(zombietype == "witch")
		{
			ZSpawn( { type = 7, pos = spawnloc } );
			
			for(local victim; victim = Entities.FindByClassnameWithin(victim, "witch", spawnloc, 300); )
			{
				DoEntFire("!self", "kill", "", 0.60, null, victim);
				if(IsPlayerABot(kent))
				{
					CommandABot({ cmd = 0  /* BOT_CMD_ATTACK */, bot = victim, target = kent });
					NetProps.SetPropFloat(victim, "m_wanderrage", 1.0);
					NetProps.SetPropFloat(victim, "m_rage", 1.0);
				}
				else
				{
					NetProps.SetPropFloat(victim, "m_wanderrage", 1.0);
					NetProps.SetPropFloat(victim, "m_rage", 1.0);
					victim.TakeDamage(1,1,kent);
				}
			}
		}
		else
		{
			ZSpawn( { type = zombietype, pos = spawnloc } );
			
			for(local victim; victim = Entities.FindByClassnameWithin(victim, "player", spawnloc, 300); )
			{
				if(victim.GetZombieType() == zombietype)
				{
					if(zombietype == 8)
					{
						local index = victim.GetEntityIndex();
						if(Entities.FindByClassname(null, "trigger_finale"))
						{
							EntFire("worldspawn", "RunScriptCode", "::SystemEventsMisc.Jumpscare.DelayedKill(" + index + ")", 0.60);
						}
						else
						{
							DoEntFire("!self", "kill", "", 0.60, null, victim);
						}
					}
					else
					{
						DoEntFire("!self", "kill", "", 0.60, null, victim);
					}
				}
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
			"jumpscare_chance = 50",
			"jumpscare_extremity = 1",
			"."
			"."
			"."
			"// ====== TOGGLE SETTING INFO ======",
			"//jumpscare_chance= Jumpscare chance when opening a door.",
			"0= Off",
			"1 or above= Jumpscare chance is (value * 1%). Max is 100.",
			".",
			"//jumpscare_extremity= Which zombie will show up as the jumpscare.",
			"1 or below= Random special infected",
			"2= Same as no. 1 + witch.",
			"3= Same as no. 2 + tank.",
			"4= Only tank & witch.",
			".",
			".",
			"// =================================",
			"//Notes: This file is generated automatically when using this mod for the first time. To make the changes in the cfg file take effect, press RELOAD when reloading your gun. To reset the this toggle back to the default, delete the file & reload your gun.",
			"."
		]
		
		foreach (line in CfgToggleFile)
		{
			DefaultToggleFile = DefaultToggleFile + line + "\n";
		}
		if(!MercilessToggleFileCheck("jumpscare doors cfg/jumpscare doors.txt"))
		{
			StringToFile("jumpscare doors cfg/jumpscare doors.txt", DefaultToggleFile);
			printl("The 'jumpscare doors.txt' file can't be found. Generating a new 'jumpscare doors.txt' file...");
		}
	}
	
	function LoadSpecificConfigFile()
	{
		local dir = ::SystemEventsMisc.Jumpscare;
		if(!(FileToString("jumpscare doors cfg/jumpscare doors.txt")))
		{
			GenerateCfgFile();
		}
		else
		{
			local files = FileToString("jumpscare doors cfg/jumpscare doors.txt");
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
						
						if(togglecommand == "jumpscare_extremity")
						{
							dir.jumpscare_extremity = togglevalue.tointeger();
						}
						if(togglecommand == "jumpscare_chance")
						{
							dir.jumpscare_chance = togglevalue.tointeger();
						}
					}
				}
			}
		}
	}
	
	function DelayedKill(index)
	{
		for(local victim; victim = Entities.FindByClassname(victim, "player"); )
		{
			if(victim.GetEntityIndex() == index)
			{
				victim.SetOrigin(victim.GetOrigin() + Vector(0,0,-6666));
				victim.TakeDamage(6 + (victim.GetHealth() * 2), 6, Entities.First());
			}
		}
	}
}

::SystemEventsMisc.EventSnd <-
{
	Options =
	{
		sound = "mods/eventsnd/vineboom.wav"

		sound_friendlyfire_death = -1
		sound_friendlyfire_incap = -1
		sound_bungee = -1
		sound_caralarm = -1
		sound_tankheal = -1
		sound_healthwasted = -1
		sound_ledgehang = -1
		sound_witchcrown = -1
		sound_gascan = -1
	}

	// cool vanilla sounds:
	// ui/critical_event_1.wav
	// ui/beep22.wav
	// level/lowscore.wav
	// level/gnomeftw.wav
	// level/loud/adrenaline_impact.wav
	// music/bacteria/boomerbacteria.wav
	// music/bacteria/hunterbacteria.wav
	// music/zombat/gatesofhell.wav

	OptionsFile =
	[
		"// the default sound to play"
		"sound"
		"\n"
		"// everything below here controls specific events and can be set to null to not play the sound, -1 to play the default sound, or a file path to play a custom sound"
		"\n"
		"// friendly fire events"
		"sound_friendlyfire_incap"
		"sound_friendlyfire_death"
		"\n"
		"// when somebody jumps off the map"
		"sound_bungee"
		"\n"
		"// when somebody triggers a car alarm"
		"sound_caralarm"
		"\n"
		"// when somebody heals somebody else in front of a tank or a witch"
		"sound_tankheal"
		"\n"
		"// when somebody wastes a kit or pills"
		"sound_healthwasted"
		"\n"
		"// when somebody hangs off a ledge"
		"sound_ledgehang"
		"\n"
		"// when somebody gives pills/adrenaline to somebody who was probably going to crown the witch"
		"sound_witchcrown"
		"\n"
		"// when somebody destroys a gascan in a scavenge finale"
		"sound_gascan"
	]

	function GetAlarm( alarmType = "" )
	{
		if ( alarmType == "" )
			return Options.sound

		local index = "sound_" + alarmType

		if ( !( index in Options ) || Options[ index ] == null )
			return null

		local sound = Options[ index ]

		if ( sound == -1 )
			return Options.sound

		return sound
	}

	function SoundTheAlarm( alarmType = "" )
	{
		local alarm = GetAlarm( alarmType )

		if ( !alarm )
			return

		foreach( player in MaoLib.YieldPlayers() )
		{
			EmitSoundOn( "@#" + alarm, player )
		}
	}

	function IsTankNearby( player )
	{
		local playerArea = NavMesh.GetNavArea( player.GetCenter(), 1024.0 )

		if ( !playerArea )
			return false

		foreach( special in MaoLib.YieldSpecials() )
		{
			if ( special.GetZombieType() != 8  /* ZOMBIE_TANK */ )
				continue

			local tankArea = NavMesh.GetNavArea( special.GetCenter(), 1024.0 )

			local distance = NavMesh.NavAreaTravelDistance( playerArea, tankArea, 16384.0 )

			if ( !tankArea || distance > 500 )
				continue

			return true
		}

		return false
	}

	function IsWitchNearby( player )
	{
		return ( Entities.FindByClassnameWithin( null, "witch", player.GetCenter(), 250.0 ) )
	}
}

::SystemEventsMisc.Events <-
{
	function OnGameEvent_door_open(event)
	{
		local dir = ::SystemEventsMisc.Jumpscare;
		
		local kent = GetPlayerFromUserID(event.userid);
		local checkpointdoor = null;
		if("checkpoint" in event)
		{
			checkpointdoor = event["checkpoint"];
		}
		local closeddoor = null;
		if("closed" in event)
		{
			closeddoor = event["closed"];
		}
		if(!kent) return;
		if(kent.IsSurvivor())
		{
			if(!checkpointdoor)
			{
				if(dir.jumpscare_chance > 0)
				{
					if(RandomInt(1,100) <= dir.jumpscare_chance)
					{
						if(dir.jumpscare_extremity <= 1)
						{
							switch(RandomInt(0, 5))
							{
								case 0:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 1);
									break;
									
								case 1:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 2);
									break;
								
								case 2:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 3);
									break;
								
								case 3:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 4);
									break;
								
								case 4:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 5);
									break;
								
								case 5:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 6);
									break;
							}
						}
						else if(dir.jumpscare_extremity == 2)
						{
							switch(RandomInt(0, 6))
							{
								case 0:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 1);
									break;
									
								case 1:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 2);
									break;
								
								case 2:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 3);
									break;
								
								case 3:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 4);
									break;
								
								case 4:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 5);
									break;
								
								case 5:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 6);
									break;
								
								case 6:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, "witch");
									break;
							}
						}
						else if(dir.jumpscare_extremity == 3)
						{
							switch(RandomInt(0, 7))
							{
								case 0:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 1);
									break;
									
								case 1:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 2);
									break;
								
								case 2:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 3);
									break;
								
								case 3:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 4);
									break;
								
								case 4:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 5);
									break;
								
								case 5:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 6);
									break;
								
								case 6:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 8);
									break;
								
								case 7:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, "witch");
									break;
							}
						}
						else
						{
							switch(RandomInt(0, 1))
							{
								case 0:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, 8);
									break;
								
								case 1:
									::SystemEventsMisc.Jumpscare.SpawnJumpScare(kent, "witch");
									break;
							}
						}
					}
				}
			}
		}
	}
	
	function OnGameEvent_player_say(event)
	{
		local entDamage = {}
		local kent = GetPlayerFromUserID(event.userid);
		if(!kent) return;
		
		local chat = null;
		if("text" in event)
		{
			chat = event["text"];
			
			if(chat == "you're dead")
			{
				if(!kent.IsDead())
				{
					if(kent.GetPlayerName() == "kurochama" || kent.GetPlayerName() == "<<Kuromaki>>")
					{
						EntFire("worldspawn", "RunScriptCode", "::SystemEventsMisc.Jumpscare.YouAreAlreadyDead(" + event.userid + ")", 6);
						EmitSoundOn("Hint.LittleReward", kent);
					}
				}
			}
		}
		::SystemEventsMisc.Jumpscare.PlayerChat( kent, chat );
	}
	
	function OnGameEvent_weapon_reload(event)
	{
		local dir = ::SystemEventsMisc.Jumpscare;
		local kent = GetPlayerFromUserID(event.userid);
		if(!kent) return;
		if(kent.IsSurvivor())
		{
			if(!IsPlayerABot(kent))
			{
				if(!kent.IsDead())
				{
					::SystemEventsMisc.Jumpscare.LoadSpecificConfigFile();
				}
			}
			if(dir.jumpscare_chance > 100) dir.jumpscare_chance = 100;
		}
	}
	
	function OnGameEvent_round_start_post_nav(event)
	{
		::SystemEventsMisc.Jumpscare.LoadSpecificConfigFile();
	}
	
	function OnGameEvent_player_incapacitated( opts )
	{
		if ( !( "userid" in opts ))
			return

		if ( "type" in opts && opts.type == 32 )
			return ::SystemEventsMisc.EventSnd.SoundTheAlarm( "bungee" )

		if ( !( "attacker" in opts ) )
			return

		local victim = GetPlayerFromUserID( opts.userid )

		if ( !victim || !victim.IsSurvivor() )
			return

		local attacker = GetPlayerFromUserID( opts.attacker)

		if ( !attacker || !attacker.IsSurvivor() )
			return

		::SystemEventsMisc.EventSnd.SoundTheAlarm( "friendlyfire_incap" )
	}

	function OnGameEvent_player_death( opts )
	{
		if ( !( "userid" in opts ))
			return

		if ( "type" in opts && ( opts.type == 32 || opts.type == 16384 ) )
			return ::SystemEventsMisc.EventSnd.SoundTheAlarm( "bungee" )

		if ( !( "attacker" in opts ) )
			return

		local victim = GetPlayerFromUserID( opts.userid )

		if ( !victim || !victim.IsSurvivor() )
			return

		local attacker = GetPlayerFromUserID( opts.attacker)

		if ( !attacker || !attacker.IsSurvivor() )
			return

		::SystemEventsMisc.EventSnd.SoundTheAlarm( "friendlyfire_death" )
	}

	function OnGameEvent_player_ledge_grab( opts )
	{
		if ( !( "userid" in opts ) )
			return

		if ( "causer" in opts && GetPlayerFromUserID( opts.causer ) )
			return

		::SystemEventsMisc.EventSnd.SoundTheAlarm( "ledgehang" )
	}

	function OnGameEvent_scavenge_gas_can_destroyed( opts )
	{
		if ( !( "userid" in opts ) )
			return

		local player = GetPlayerFromUserID( opts.userid )

		if ( !player || !player.IsSurvivor() )
			return

		if ( !Director.IsFinale() )
			return

		::SystemEventsMisc.EventSnd.SoundTheAlarm( "gascan" )
	}

	function OnGameEvent_heal_success( opts )
	{
		if ( !( "userid" in opts ) || !( "subject" in opts ) || !( "health_restored" in opts ) )
			return

		local healer = GetPlayerFromUserID( opts.userid )

		if ( !healer )
			return

		local healed = GetPlayerFromUserID( opts.subject )

		if ( !healed )
			return

		if ( opts.health_restored >= 50 )
			return

		::SystemEventsMisc.EventSnd.SoundTheAlarm( "healthwasted" )
	}

	function OnGameEvent_pills_used( opts )
	{
		if ( !( "subject" in opts ) )
			return

		local healed = GetPlayerFromUserID( opts.subject )

		if ( !healed )
			return

		if ( healed.GetHealth() + healed.GetHealthBuffer() <= 90 )
			return

		::SystemEventsMisc.EventSnd.SoundTheAlarm( "healthwasted" )
	}

	function OnGameEvent_heal_begin( opts )
	{
		if ( !( "userid" in opts ) || !( "subject" in opts ) )
			return

		local healer = GetPlayerFromUserID( opts.userid )

		if ( !healer )
			return

		local healed = GetPlayerFromUserID( opts.subject )

		if ( !healed || healed == healer )
			return

		if ( !::SystemEventsMisc.EventSnd.IsTankNearby( healed ) && !::SystemEventsMisc.EventSnd.IsWitchNearby( healed ) )
			return

		::SystemEventsMisc.EventSnd.SoundTheAlarm( "tankheal" )
	}

	function OnGameEvent_triggered_car_alarm( opts )
	{
		if ( !( "userid" in opts ) )
			return

		::SystemEventsMisc.EventSnd.SoundTheAlarm( "caralarm" )
	}

	function OnGameEvent_weapon_given( opts )
	{
		if ( !( "userid" in opts ) || !( "giver" in opts ) )
			return

		local attacker = GetPlayerFromUserID( opts.giver )

		if ( !attacker )
			return

		local victim = GetPlayerFromUserID( opts.userid )

		if ( !victim )
			return

		if ( !::SystemEventsMisc.EventSnd.IsWitchNearby( victim ) )
			return

		::SystemEventsMisc.EventSnd.SoundTheAlarm( "witchcrown" )
	}

	function OnGameEvent_round_start( opts )
	{
		::SystemEventsMisc.EventSnd.Options = MaoLib.InitOptionsFmt( ::SystemEventsMisc.EventSnd.Options, "eventsnd/options.cfg", ::SystemEventsMisc.EventSnd.OptionsFile )

		foreach( name, value in ::SystemEventsMisc.EventSnd.Options )
		{
			if ( value == -1 || value == "" )
				continue

			if ( !IsSoundPrecached( "@#" + value ) )
				PrecacheSound( "@#" + value )
		}
	}
}

::SystemEventsMisc.Init <- function()
{
	__CollectGameEventCallbacks(::SystemEventsMisc.Events)
}

::SystemEventsMisc.Init()
printl("SystemEventsMisc initialized")
