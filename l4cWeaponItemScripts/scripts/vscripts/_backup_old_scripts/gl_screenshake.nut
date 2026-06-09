printl("-> GRENADE LAUNCHER EXPLOSION SHAKE by tomaz");

GL_SCREENSHAKE <-
{
	worldspawn = Entities.First(),
	// shake_amplitude = Convars.GetFloat("pipe_bomb_shake_amplitude"), // meh...

	function OnGameEvent_weapon_fire(params)
	{
		if("weaponid" in params && "userid" in params)
		{
			// if not gl
			if(params.weaponid != 21) return;
			
			local userid = params.userid;
			local grenadier = GetPlayerFromUserID(userid);
			if(!grenadier) return;
			
			local worldspawn = GL_SCREENSHAKE.worldspawn;
			
			local nade = null;
			while(nade = Entities.FindByClassname(nade, "grenade_launcher_projectile")) // this is not good. preferably only do this as little as possible. actually just, stop. don't make scripts. don't make mods. go outside. pick up a football. turn back while you still can.
			{
				local thrower = NetProps.GetPropEntity(nade, "m_hThrower");
			
				if(nade && thrower == grenadier)
				{
					worldspawn.ValidateScriptScope();
					local scope = worldspawn.GetScriptScope();
					
					if(!("GL_SCREENSHAKE" in scope))
					{
						scope["GL_SCREENSHAKE"] <- {};
					}
					
					scope["GL_SCREENSHAKE"][userid] <- { "ent": nade, "pos": null };
					
					break;
				}
			}
			
			if(!nade) return;
		}
	}
	
	// pipebombs trigger this as you can imagine, but so does the gl projectile it seems
	function OnGameEvent_grenade_bounce(params)
	{
		if("userid" in params)
		{
			local userid = params.userid;
		
			local worldspawn = GL_SCREENSHAKE.worldspawn;
			
			local scope = worldspawn.GetScriptScope();
			if(!scope) return;
			
			if(!("GL_SCREENSHAKE" in scope)) return;
			if(!(userid in scope["GL_SCREENSHAKE"])) return;
			
			local nade = scope["GL_SCREENSHAKE"][userid]["ent"];
			
			scope["GL_SCREENSHAKE"][userid]["pos"] <- nade.GetOrigin();
			
			DoEntFire("!self", "RunScriptCode", "::GL_SCREENSHAKE.ShakeItBaby(" + userid  + ")", 0.1, null, worldspawn); // tiny delay. without it, it feels off. idk how to explain it
		}
	}
	
	function ShakeItBaby(userid)
	{
		local worldspawn = GL_SCREENSHAKE.worldspawn;
		local scope =  worldspawn.GetScriptScope();
		
		local nade_pos = scope["GL_SCREENSHAKE"][userid]["pos"];
		
		local shake_pos = Vector(nade_pos.x, nade_pos.y, nade_pos.z + 4);
		local shake_amplitude = 10;
		local shake_frequency = 40;
		local shake_duration = 1.2;
		local shake_radius = 1250;
		
		delete scope["GL_SCREENSHAKE"][userid];
		
		ScreenShake(shake_pos, shake_amplitude, shake_frequency, shake_duration, shake_radius, 0, true);
	}
	
	function RemoveFromScope(userid)
	{
		local scope = GL_SCREENSHAKE.worldspawn.GetScriptScope();
		if(!scope) return;
		
		if(!("GL_SCREENSHAKE" in scope)) return;
		
		if(userid in scope["GL_SCREENSHAKE"])
		{
			delete scope["GL_SCREENSHAKE"][userid];
		}
	}
	
	// manage old leftover userids
	function OnGameEvent_player_bot_replace(params)
	{
		if("player" in params)
		{
			GL_SCREENSHAKE.RemoveFromScope(params.player);
		}
	}
	
	function OnGameEvent_bot_player_replace(params)
	{
		if("bot" in params)
		{
			GL_SCREENSHAKE.RemoveFromScope(params.bot);
		}
	}
	
	function OnGameEvent_player_disconnect(params)
	{
		if("userid" in params)
		{
			GL_SCREENSHAKE.RemoveFromScope(params.userid);
		}
	}
}

__CollectGameEventCallbacks(GL_SCREENSHAKE);