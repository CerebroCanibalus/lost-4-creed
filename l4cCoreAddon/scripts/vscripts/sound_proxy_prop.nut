prop_break_awareness <-
{
	prop_range = 1000

	function CfgFileCheck(filename)
	{
		local files = FileToString(filename);
		if(!files)
		{
			return false;
		}
		return true;
	}

	function GeneratePropCustomiserFile()
	{
		local DefaultToggleFile = "";
		
		local CfgToggleFile =
		[
			"//The range at which breaking a prop will attract an infected",
			"prop_range 1000",	
		]
		
		foreach (line in CfgToggleFile)
		{
			DefaultToggleFile = DefaultToggleFile + line + "\n";
		}
		if(!CfgFileCheck("prop_break/volume.txt"))
		{
			
			StringToFile("prop_break/volume.txt", DefaultToggleFile);
			printl("No config file found, generating new file");
			
		}
		
	}

	function OnGameEvent_round_start_post_nav(event)
	{
		printl("Starting prop break");
		GeneratePropCustomiserFile();
		LoadSpecificConfigFile("prop_break/volume.txt");
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
					if(togglecommand == "prop_range")
					{
						::prop_break_awareness.prop_range = togglevalue.tointeger();
						
					}
				}
			}
		}
	}

	function OnGameEvent_break_prop(event)
	{	
		local player = GetPlayerFromUserID(event.userid);
		if(player.IsInCombat() == false)
		{						
			RushVictim(player, prop_range)
		}
	}
}

__CollectGameEventCallbacks(prop_break_awareness);