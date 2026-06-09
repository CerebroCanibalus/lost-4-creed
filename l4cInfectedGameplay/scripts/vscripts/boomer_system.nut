IncludeScript("maolib", getroottable())
IncludeScript("maolib_vfx", getroottable())

/*
 * ================================================================
 * BOOMER SYSTEM - Consolidated Boomer Mechanics
 * ================================================================
 * Replaces: boomer_mechanics.nut, boomer_exp.nut
 * Removes: boomer_fall.nut (mechanic removed by design)
 * 
 * Features:
 * - Burning Explosion: If boomer dies while burning, spreads fire
 * - Witch Alert: Boomer explosions alert nearby witches
 * - Car Alarm Trigger: Boomer explosions trigger car alarms
 * - Vomit Chain: Vomiting already-vomited survivors expands area
 * - Vomit Damage: Bonus damage to survivors when vomited
 * ================================================================
 */

::BoomerSystem <-
{
	// ============================================================
	// CONFIGURATION
	// ============================================================
	Settings =
	{
		// Fire spread
		FireSpreadRadius = 225.0,
		FireDamage = 25.0,
		
		// Witch alert
		WitchAlertRadius = 500.0,
		WitchAngerAmount = 0.3,
		
		// Car alarms
		CarAlarmRadius = 250.0,
		
		// Vomit chain
		VomitChainEnabled = true,
		VomitChainRadius = 400.0,      // Expanded radius for chain vomit
		VomitChainDuration = 8.0,      // Extended duration for chain vomit
		
		// Vomit damage
		VomitDamage = 10,
	}
	
	// Track vomited survivors for chain mechanic
	VomitedSurvivors = {},
	
	// ============================================================
	// EVENT HANDLERS
	// ============================================================
	function OnGameEvent_boomer_exploded(params)
	{
		if (!("attacker" in params) || !("userid" in params))
			return
		
		local killer = GetPlayerFromUserID(params.attacker)
		if (!killer || !killer.IsValid() || NetProps.GetPropInt(killer, "m_iTeamNum") != 2)
			return
		
		local boomer = GetPlayerFromUserID(params.userid)
		if (!boomer || !boomer.IsValid())
			return
		
		local origin = boomer.GetOrigin()
		
		// Check if was burning
		local wasBurning = false
		try
		{
			local flame = NetProps.GetPropEntity(boomer, "m_hEffectEntity")
			if (flame && flame.IsValid() && flame.GetClassname() == "entityflame")
				wasBurning = true
		}
		catch(e) {}
		
		// Spread fire if burning
		if (wasBurning)
			SpreadFireExplosion(origin, killer, boomer, Settings.FireSpreadRadius)
		
		// Alert witches
		ProcessWitches(origin, killer, boomer, wasBurning)
		
		// Trigger car alarms
		TriggerCarAlarms(origin, killer, Settings.CarAlarmRadius)
		
		// Visual feedback
		MaoLib_VFX.SpawnExplosion(origin, "small")
	}
	
	// ============================================================
	// FIRE SPREAD
	// ============================================================
	function SpreadFireExplosion(origin, killer, boomer, radius)
	{
		// Damage common infected
		local ent = null
		while ((ent = Entities.FindByClassnameWithin(ent, "infected", origin, radius)) != null)
		{
			if (!ent.IsValid())
				continue
			ent.TakeDamageEx(boomer, killer, null, origin, origin, Settings.FireDamage, 8  /* DMG_BURN */)
		}
		
		// Damage witches (and enrage them)
		ent = null
		while ((ent = Entities.FindByClassnameWithin(ent, "witch", origin, radius)) != null)
		{
			if (!ent.IsValid())
				continue
			local health = NetProps.GetPropInt(ent, "m_iHealth")
			NetProps.SetPropInt(ent, "m_iHealth", health + 1)
			ent.TakeDamageEx(boomer, killer, null, origin, origin, 1.0, 8  /* DMG_BURN */)
		}
		
		// Damage survivors
		ent = null
		while ((ent = Entities.FindByClassnameWithin(ent, "player", origin, radius)) != null)
		{
			if (!ent.IsValid() || !ent.IsSurvivor())
				continue
			ent.TakeDamageEx(boomer, killer, null, origin, origin, Settings.FireDamage * 0.5, 8  /* DMG_BURN */)
			MaoLib_VFX.SpawnParticleOnEntity(ent, "env_fire_large", "", 1.0)
		}
		
		// Ignite props
		ent = null
		while ((ent = Entities.FindByClassnameWithin(ent, "prop_physics", origin, radius)) != null)
		{
			if (!ent.IsValid())
				continue
			DoEntFire("!self", "Ignite", "", 0, boomer, ent)
		}
	}
	
	// ============================================================
	// WITCH ALERT
	// ============================================================
	function ProcessWitches(origin, killer, boomer, wasBurning)
	{
		local witch = null
		while ((witch = Entities.FindByClassnameWithin(witch, "witch", origin, Settings.WitchAlertRadius)) != null)
		{
			if (!witch.IsValid())
				continue
			
			// Make witch angry at the killer
			MaoLib.ForceTarget(witch, killer)
			
			// Increase anger
			local currentAnger = MaoLib.GetWitchAnger(witch)
			MaoLib.SetWitchAnger(witch, currentAnger + Settings.WitchAngerAmount)
			
			// If burning, witch gets REALLY angry
			if (wasBurning)
			{
				MaoLib.SetWitchAnger(witch, 1.0)
				CommandABot({ bot = witch, cmd = 0  /* BOT_CMD_ATTACK */, target = killer })
			}
			else
			{
				CommandABot({ bot = witch, cmd = 1  /* BOT_CMD_MOVE */, target = witch.GetOrigin() })
			}
		}
	}
	
	// ============================================================
	// CAR ALARM TRIGGER
	// ============================================================
	function TriggerCarAlarms(origin, killer, radius)
	{
		local ent = null
		while ((ent = Entities.FindByClassnameWithin(ent, "prop_car_alarm", origin, radius)) != null)
		{
			if (!ent.IsValid())
				continue
			DoEntFire("!self", "Enable", "", 0, killer, ent)
			DoEntFire("!self", "Trigger", "", 0.1, killer, ent)
		}
		
		// Also check for alarm-enabled cars
		ent = null
		while ((ent = Entities.FindByClassnameWithin(ent, "prop_physics", origin, radius)) != null)
		{
			if (!ent.IsValid())
				continue
			local alarm = NetProps.GetPropInt(ent, "m_bAlarm")
			if (alarm == 1)
			{
				DoEntFire("!self", "Enable", "", 0, killer, ent)
				DoEntFire("!self", "Trigger", "", 0.1, killer, ent)
			}
		}
	}
	
	// ============================================================
	// VOMIT CHAIN SYSTEM
	// ============================================================
	function OnGameEvent_player_now_it(params)
	{
		if (!("userid" in params))
			return
		
		local victim = GetPlayerFromUserID(params.userid)
		if (!victim || !victim.IsSurvivor())
			return
		
		local victimKey = victim.GetEntityIndex().tostring()
		
		// Check if already vomited (chain vomit)
		if (Settings.VomitChainEnabled && (victimKey in VomitedSurvivors))
		{
			// Chain vomit! Expand effect
			ApplyChainVomitEffect(victim)
		}
		else
		{
			// First vomit - track it
			VomitedSurvivors[victimKey] <- Time()
		}
		
		// Apply vomit damage
		if ("attacker" in params)
		{
			local boomer = GetPlayerFromUserID(params.attacker)
			if (boomer && boomer.IsValid())
			{
				victim.TakeDamage(Settings.VomitDamage, 5, boomer)
			}
		}
	}
	
	function ApplyChainVomitEffect(victim)
	{
		local origin = victim.GetOrigin()
		
		// Visual feedback
		MaoLib_VFX.SpawnExplosion(origin, "small")
		MaoLib_VFX.ScreenShake(origin, 2, 5, 0.5, 300)
		
		// Apply extended vomit to nearby survivors
		local nearby = null
		while ((nearby = Entities.FindByClassnameWithin(nearby, "player", origin, Settings.VomitChainRadius)) != null)
		{
			if (!nearby.IsValid() || !nearby.IsSurvivor() || nearby == victim)
				continue
			
			// Extend their vomit duration
			local nearbyKey = nearby.GetEntityIndex().tostring()
			VomitedSurvivors[nearbyKey] <- Time()
			
			// Visual
			MaoLib_VFX.SpawnParticleOnEntity(nearby, "vomit_bullets", "", 1.0)
		}
		
		// Sound
		EmitSoundOn("Player.Boomer.Vomit", victim)
	}
	
	// ============================================================
	// CLEANUP
	// ============================================================
	function OnGameEvent_round_start(params)
	{
		VomitedSurvivors.clear()
	}
	
	function OnGameEvent_round_end(params)
	{
		VomitedSurvivors.clear()
		MaoLib.RemoveTimer("boomer_vomit_cleanup")
	}
	
	// Periodic cleanup of old vomit tracking
	function CleanupOldVomit()
	{
		local currentTime = Time()
		local toRemove = []
		
		foreach (key, vomitTime in VomitedSurvivors)
		{
			if (currentTime - vomitTime > Settings.VomitChainDuration)
				toRemove.append(key)
		}
		
		foreach (key in toRemove)
			if (key in VomitedSurvivors)
				delete VomitedSurvivors[key]
	}
}

// ================================================================
// REGISTER
// ================================================================
::__CollectGameEventCallbacks(BoomerSystem)

// Start cleanup timer
MaoLib.AddTimer("boomer_vomit_cleanup", 5.0, function() { BoomerSystem.CleanupOldVomit(); })

printl("[BoomerSystem] Loaded - Fire Spread, Witch Alert, Car Alarms, Vomit Chain")
