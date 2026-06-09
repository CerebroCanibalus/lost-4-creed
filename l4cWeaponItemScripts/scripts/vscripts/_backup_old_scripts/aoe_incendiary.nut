aoe_incendiary_geeb <-
{
	overheat_chance = 0

	function CfgFileCheck(filename)
	{
		local files = FileToString(filename);
		if(!files)
		{
			return false;
		}
		return true;
	}

	function GenerateAOEICustomiserFile()
	{
		local DefaultToggleFile = "";
		
		local CfgToggleFile =
		[

			"//The % chance that shooting the ground with incendiary ammo will start a fire on the floor",
			"overheat_chance 0",
		]
		
		foreach (line in CfgToggleFile)
		{
			DefaultToggleFile = DefaultToggleFile + line + "\n";
		}
		if(!CfgFileCheck("aoe_incendiary/config.txt"))
		{
			
			StringToFile("aoe_incendiary/config.txt", DefaultToggleFile);
			printl("No config file found, generating new file");
			
		}
	}

	function HandleRoundStart(event)
	{
		printl("Starting AoE Incendiary");
		GenerateAOEICustomiserFile();
		LoadSpecificConfigFile("aoe_incendiary/config.txt");
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
					if(togglecommand == "overheat_chance")
					{
						::aoe_incendiary_geeb.overheat_chance = togglevalue.tointeger();
						
					}
				}
			}
		}
	}

	function OnGameEvent_round_start_post_nav(params) { HandleRoundStart(params); }
	function OnGameEvent_bullet_impact(params) { HandleBulletImpact(params); }

	function HandleBulletImpact(event)
	{
		local player = GetPlayerFromUserID(event.userid);
		if (!player) return;
		local weapon = player.GetActiveWeapon();
		local upgrade_vec = NetProps.GetPropInt(weapon, "m_upgradeBitVec");
		if(upgrade_vec == 1 || upgrade_vec == 5)
		{	
			local x = (event.x)
			local y = (event.y)
			local z = (event.z)
			local origin = Vector(x,y,z)
			local origin2 = origin + Vector(0,0,25)
			local ent = null
			while( ent = Entities.FindByClassnameWithin(ent, "infected", origin, 40))
			{
				ent.TakeDamage(5, 8, player)
			}
			local ent = null
			while( ent = Entities.FindByClassnameWithin(ent, "player", origin, 40))
			{
				if(!ent.IsSurvivor())
				{
					ent.TakeDamage(5, 8, player)
				}
			}
			local ent = null
			while( ent = Entities.FindByClassnameWithin(ent, "witch", origin, 40))
			{
				ent.TakeDamage(5, 8, player)
			}
			local gamble = RandomInt(1,100)
			if(gamble < overheat_chance)
			{
				DropFire(origin2)		
			}
		}
	}
}

__CollectGameEventCallbacks(aoe_incendiary_geeb);