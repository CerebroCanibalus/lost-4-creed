eatpeople <-
{
	function OnGameEvent_entity_shoved(event)
	{
		local player = GetPlayerFromUserID(event.attacker);
		if (!player) return;
		local origin = player.GetOrigin();
		local ent = null;
		while(ent = Entities.FindByClassnameWithin(ent, "player", origin, 30))
		{
			if(ent.IsSurvivor() && ent.IsIncapacitated())
			{
				local flags = player.GetButtonMask();
				if(flags & (1 << 13))
				{
					ent.TakeDamage(30, 4, player)
					local hp = player.GetHealth()
					local newhp = hp + 10
					player.SetHealth(newhp)
					healthcheck(player)
				}
			}
		}
	}

	function healthcheck(player)
	{
		local permhealth = player.GetHealth()
		local temphealth = player.GetHealthBuffer()
		local totalhealth = permhealth + temphealth
		if(totalhealth > 100)
		{
			if(temphealth > 0)
			{
				temphealth = 100 - permhealth
				player.SetHealthBuffer(temphealth)
				healthcheck(player)
			}
			if(permhealth > 100)
			{
				player.SetHealth(100)
			}
		}
	}
}

__CollectGameEventCallbacks(eatpeople);