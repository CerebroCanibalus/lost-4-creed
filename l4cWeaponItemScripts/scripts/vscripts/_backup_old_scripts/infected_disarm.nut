infecteddisarm <-
{
	low_health = 30
	default_chance = 20
	low_health_chance = 40

	function CfgFileCheck(filename)
	{
		local files = FileToString(filename);
		if(!files)
		{
			return false;
		}
		return true;
	}

	function GenerateInfectedDisarmCustomiserFile()
	{
		local DefaultToggleFile = "";
		
		local CfgToggleFile =
		[
			"//This CFG lets you control the chances of an infected disarming a survivor in 2 situations: when the survivor is healthy, and when they have low health. You can change what health value is considered low health by editing the number next to low_health. By default, it is 40, meaning any health value equal to or less than 40 is considered low health",
			"low_health 20",
			"//The script works by generating a random number from 1 to X when a survivor is hit by an infected, with X being a number of your choice. If it generates a 1, the survivor is disarmed. default_chance controls how likely a survivor is to be disarmed when they are healthy. By default it is 20, meaning the survivors have a 1 in 20 (or 5%) chance of being disarmed when hit. low_health_chance controls how likely a survivor is to be disarmed when their health is below the value set by low_health. By default it is 10, meaning the survivors have a 1 in 10 (or 10%) chance of being disarmed when hit.",
			"default_chance 15",
			"low_health_chance 45",
		]
		
		foreach (line in CfgToggleFile)
		{
			DefaultToggleFile = DefaultToggleFile + line + "\n";
		}
		if(!CfgFileCheck("infected_disarm/disarm.txt"))
		{
			
			StringToFile("infected_disarm/disarm.txt", DefaultToggleFile);
			printl("No config file found, generating new file");
			
		}
		
	}

	function OnGameEvent_round_start_post_nav(event)
	{
		printl("Starting Infected disarm Survivors");
		GenerateInfectedDisarmCustomiserFile();
		LoadSpecificConfigFile("infected_disarm/disarm.txt");
	}

	function LoadSpecificConfigFile(filename)
	{
		local trigger = 0;
		local files = FileToString(filename);
		if(!files)
		{
			return trigger;
		}
		local toggles = split(files, "\r\n");
		foreach(toggle in toggles)
		{
			if(toggle && toggle != "")
			{
				toggle = strip(toggle);
				local idx = toggle.find(" ");
				if (idx != null)
				{
					local togglecommand = toggle.slice(0, idx);
					local togglevalue = toggle.slice(idx + 1);
					if(togglecommand == "low_health")
					{
						::infecteddisarm.low_health = togglevalue.tointeger();
						
					}
					if(togglecommand == "default_chance")
					{
						::infecteddisarm.default_chance = togglevalue.tointeger();
						
					}
					if(togglecommand == "low_health_chance")
					{
						::infecteddisarm.low_health_chance = togglevalue.tointeger();
						
					}				
				}
			}
		}
	}


	function GetActiveMainWeapon(player)
	{
		local weapon = player.GetActiveWeapon();
		if(weapon)
		{
			return weapon.GetClassname();
		}
		return null;
	}

	function GetPrimarySlot(player)
	{
		local invTable = {};
		GetInvTable(player, invTable);
		if(!("slot0" in invTable))
		{
			return null;
		}
		local weapon = invTable.slot0;
		if(weapon)
		{
			return weapon.GetClassname();
		}
		return null;
	}

	function 	OnGameEvent_player_hurt(event)
	{
		HandlePlayerHurt(event);
	}

	function HandlePlayerHurt(event)
	{
		local victim = GetPlayerFromUserID(event.userid);
		local damagetype = event.type;
		if(damagetype == 128)
		{						
			if(victim.IsSurvivor())
			{
				if(!victim.IsIncapacitated())
				{	
					local totalhealth = victim.GetHealth() + victim.GetHealthBuffer();
					if(totalhealth > ::infecteddisarm.low_health)
					{
						local chance = RandomInt(1,::infecteddisarm.default_chance);
						if(chance == 1)
						{
							if(GetActiveMainWeapon(victim) == GetPrimarySlot(victim))
							{
								victim.DropItem(GetPrimarySlot(victim));
							}
						}
					}
					if(totalhealth + victim.GetHealthBuffer() <= ::infecteddisarm.low_health)
					{
						local chance = RandomInt(1,::infecteddisarm.low_health_chance);
						if(chance == 1)
						{
							if(GetActiveMainWeapon(victim) == GetPrimarySlot(victim))
							{
								victim.DropItem(GetPrimarySlot(victim));
							}
						}
					}
				}
			}
		}
	}
}

__CollectGameEventCallbacks(infecteddisarm);