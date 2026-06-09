loudwindow <-
{
	door_range = 300
	window_range = 900

	function CfgFileCheck(filename)
	{
		local files = FileToString(filename);
		if(!files)
		{
			return false;
		}
		return true;
	}

	function GenerateWindowCustomiserFile()
	{
		local DefaultToggleFile = "";
		
		local CfgToggleFile =
		[
			"//The range at which opening or closing a door will attract an infected",
			"door_range 500",
			"//The range at which breaking a window will attract an infected",
			"window_range 1000",	
		]
		
		foreach (line in CfgToggleFile)
		{
			DefaultToggleFile = DefaultToggleFile + line + "\n";
		}
		if(!CfgFileCheck("doors_and_windows/volumes.txt"))
		{
			
			StringToFile("doors_and_windows/volumes.txt", DefaultToggleFile);
			printl("No config file found, generating new file");
			
		}
		
	}

	function OnGameEvent_round_start_post_nav(event)
	{
		printl("Starting Doors and windows");
		GenerateWindowCustomiserFile();
		LoadSpecificConfigFile("doors_and_windows/volumes.txt");
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
					if(togglecommand == "door_range")
					{
						::loudwindow.door_range = togglevalue.tointeger();
						
					}
					if(togglecommand == "window_range")
					{
						::loudwindow.window_range = togglevalue.tointeger();
						
					}
				}
			}
		}
	}

	function OnGameEvent_break_breakable(event)
	{	
		local material = (event.material)
		local player = GetPlayerFromUserID(event.userid);
		if(material == 1)
		{
			if(player.IsInCombat() == false)
			{						
				RushVictim(player, window_range)
			}
		}
	}

	function OnGameEvent_door_open(event)
	{	
		local player = GetPlayerFromUserID(event.userid);
		if(player.IsInCombat() == false)
		{						
			RushVictim(player, door_range)
		}
	}

	function OnGameEvent_door_close(event)
	{	
		local player = GetPlayerFromUserID(event.userid);
		if(player.IsInCombat() == false)
		{						
			RushVictim(player, door_range)
		}
	}


}

__CollectGameEventCallbacks(loudwindow);