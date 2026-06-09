::LASC <-
{
	function OnGameEvent_weapon_fire(params)
	{
		local player = GetPlayerFromUserID(params.userid);

		if(player.IsSurvivor() && NetProps.GetPropInt(player, "m_lifeState") != 1)
		{		
			if(params.weaponid == 54) return; //if mounted machine gun
			
			local weapon = player.GetActiveWeapon();
			
			if(!weapon || weapon == null) return;
			if(weapon.GetMaxClip1() == -1 || weapon.GetClassname() == "weapon_chainsaw" || weapon.GetClassname() == "weapon_grenade_launcher") return;
			
			local thres = weapon.GetClassname().find("shotgun") != null ? 0.3 : 0.2;
			
			if(weapon.Clip1() - 1 <= ceil(weapon.GetMaxClip1() * thres))
			{
				// doubling it because playing it once is a bit too quiet at times
				for(local i = 1; i <= 2; i++)
				{
					local p_o = player.GetOrigin();
					local click_origin = Vector(p_o.x, p_o.y, p_o.z + 4) + player.GetVelocity() * 0.15 // offset z upwards a little bit because for some reason the sound might be muffled in some cases. as for GetVelocity(), when the ambient_generic is spawned and the player is running, it may sound like it's coming from behind/somewhere else so we're compensating by doing this
					local click_sound = SpawnEntityFromTable("ambient_generic", { origin = click_origin, message = "lasc/click.mp3", radius = 384, spawnflags = 48, health = 10 });
					
					//i would like to play this sound with EmitSoundOnClient but that doesn't work with mp3s for whatever reason
					DoEntFire("!self", "PlaySound", "", 0, null, click_sound);
					DoEntFire("!self", "Kill", "", 0, null, click_sound);
				}
			}
		}
	}
	
	function PrecacheClickSound()
	{
		if(!IsSoundPrecached("lasc/click.mp3")) PrecacheSound("lasc/click.mp3");
	}
}

::LASC.PrecacheClickSound();

__CollectGameEventCallbacks(::LASC);