KillSound <-
{
	SoundCount = {}
}

KillSound.OnGameEvent_player_incapacitated <- function(params)
{
	if (!("attacker" in params))
		return;
	local Survivor = GetPlayerFromUserID(params.attacker);
	local Tank = GetPlayerFromUserID(params.userid);
	if (!Survivor || !Tank)
		return;
	if (Tank.GetZombieType() == 8 && Survivor.IsSurvivor())
	{
		//EmitSoundOnClient("Zombie.BulletImpact", Survivor);
		EmitAmbientSoundOn("Zombie.BulletImpact", 0.7, 75, RandomInt(95,105), Survivor);
		EmitAmbientSoundOn("Zombie.BulletImpact", 0.7, 75, RandomInt(95,105), Tank);
	}
}

KillSound.OnGameEvent_player_death <- function(params)
{
	KillSound.HandlePlayerDeath(params);
}

KillSound.HandlePlayerDeath <- function(params)
{
	if ("attacker" in params)
	{
		local Attacker = GetPlayerFromUserID(params.attacker);
		if (!Attacker)
			return;
		if (Attacker.IsSurvivor())
		{
			local Victim;
			if (params.victimname == "Infected" || params.victimname == "Witch")
			{
				Victim = EntIndexToHScript(params.entityid);
			}
			else
			{
				Victim = GetPlayerFromUserID(params.userid);
				if (Victim.GetZombieType() > 6)
					return;
			}
		local Time = Time();
		local Volume = 0.6;
		if (Time in KillSound.SoundCount)
		{
			KillSound.SoundCount[Time] += 1;
			if (KillSound.SoundCount[Time] > 4)
				return;
			else
				Volume *= 1/KillSound.SoundCount[Time];
		}
		else
		{
			KillSound.SoundCount[Time] <- 1;
		}
			//EmitSoundOnClient("Zombie.BulletImpact", Attacker);
			EmitAmbientSoundOn("Zombie.BulletImpact", Volume, 75, RandomInt(95,105), Attacker);
			EmitAmbientSoundOn("Zombie.BulletImpact", Volume, 75, RandomInt(95,105), Victim);
			//if (NetProps.GetPropInt(Victim, "m_LastHitGroup") == 1 && (params.type & (1 << 1) || params.type & (1 << 21)))
			if (params.headshot || (params.type & (1 << 29) && NetProps.GetPropInt(Victim, "m_LastHitGroup") == 1))
			{
				//printl("Test; ");
				//EmitSoundOnClient("Player.FallDamage", Attacker);
				EmitAmbientSoundOn("Player.FallDamage", Volume, 75, RandomInt(95,105), Attacker);
				EmitAmbientSoundOn("Player.FallDamage", Volume, 75, RandomInt(95,105), Victim);
				//EmitSoundOnClient("Flesh.Break", Attacker);
				EmitAmbientSoundOn("Flesh.Break", Volume, 75, RandomInt(95,105), Attacker);
				EmitAmbientSoundOn("Flesh.Break", Volume, 75, RandomInt(95,105), Victim);
			}
		}
	}
}

__CollectGameEventCallbacks(KillSound);
/*============================================================================================================================
KillSound.OnGameEvent_round_start <- function(params)
{
	for(local Index = 1 ; Index < 9 ; Index += 1) // Please forgive me, ChimiChamo
	{
		local Sound = "npc/infected/gore/bullets/bullet_impact_0" + Index + ".wav";
		if(!IsSoundPrecached(Sound))
		{
			PrecacheSound(Sound);
		}
	}
}
============================================================================================================================*/