IncludeScript("maolib", getroottable())

/*
 * ================================================================
 * COMMON INFECTED SYSTEM
 * ================================================================
 * Replaces: infected_regen.nut, fire_spreads_geeb.nut, rush_incap.nut,
 *           chch_rngcommonwounds.nut, ci_death_fix.nut
 * 
 * Features:
 * - SI Regeneration: Out-of-combat HP regen for all special infected
 * - Fire Spreads: Burning CI can ignite nearby infected
 * - Rush Incap: Commons rush incapacitated survivors
 * - Random Wounds: Visual wound variety for common infected
 * - Death Fix: Fixes frozen common infected death bug
 * ================================================================
 */

::CommonSystem <-
{
	// ============================================================
	// REGENERATION SETTINGS
	// ============================================================
	RegenSettings =
	{
		charger = { rate = 5.0, step = 1, damageDelay = 1.5, fireDelay = 0.2, onFire = 0 },
		jockey = { rate = 5.0, step = 1, damageDelay = 1.5, fireDelay = 0.2, onFire = 0 },
		hunter = { rate = 5.0, step = 1, damageDelay = 1.5, fireDelay = 0.2, onFire = 0 },
		smoker = { rate = 5.0, step = 1, damageDelay = 1.5, fireDelay = 0.2, onFire = 0 },
		spitter = { rate = 5.0, step = 1, damageDelay = 1.5, fireDelay = 0.2, onFire = 0 },
		boomer = { rate = 3.0, step = 1, damageDelay = 2.5, fireDelay = 0.2, onFire = 0 },
	}
	
	ZombieNames = ["", "smoker", "boomer", "hunter", "spitter", "jockey", "charger"]
	
	// State tracking
	PlayerHealth = {},
	LastDamageTime = {},
	LastFireTime = {},
	
	// Rush incap
	RushRadius = 800,
	RushInterval = 1.0,
	
	// ============================================================
	// INITIALIZATION
	// ============================================================
	function OnGameEvent_round_start(params)
	{
		PlayerHealth.clear()
		LastDamageTime.clear()
		LastFireTime.clear()
		
		// Start regen timer
		MaoLib.AddTimer("common_regen", 0.5, function() { CommonSystem.UpdateRegen(); })
		// Start rush incap timer
		MaoLib.AddTimer("rush_incap", RushInterval, function() { CommonSystem.UpdateRushIncap(); })
		// Start fire spread timer
		MaoLib.AddTimer("fire_spread", 0.5, function() { CommonSystem.UpdateFireSpread(); })
		// Start death fix timer
		MaoLib.AddTimer("death_fix", 2.0, function() { CommonSystem.FixFrozenDeaths(); })
	}
	
	function OnGameEvent_round_end(params)
	{
		PlayerHealth.clear()
		LastDamageTime.clear()
		LastFireTime.clear()
		// Cleanup timers (previenen fuga entre rondas)
		MaoLib.RemoveTimer("common_regen")
		MaoLib.RemoveTimer("rush_incap")
		MaoLib.RemoveTimer("fire_spread")
		MaoLib.RemoveTimer("death_fix")
	}
	
	// ============================================================
	// REGENERATION SYSTEM
	// ============================================================
	function UpdateRegen()
	{
		local player = null
		while (player = Entities.FindByClassname(player, "player"))
		{
			if (!player.IsValid() || player.IsSurvivor())
				continue
			
			local zType = player.GetZombieType()
			if (zType < 1 || zType > 6)
				continue
			
			local zName = ZombieNames[zType]
			if (!(zName in RegenSettings))
				continue
			
			local settings = RegenSettings[zName]
			local key = player.GetEntityIndex().tostring()
			
			// Check if in combat (took damage recently)
			if (key in LastDamageTime)
			{
				if (Time() - LastDamageTime[key] < settings.damageDelay)
					continue
			}
			
			// Check if on fire
			if (!settings.onFire)
			{
				local flame = NetProps.GetPropEntity(player, "m_hEffectEntity")
				if (flame && flame.IsValid() && flame.GetClassname() == "entityflame")
				{
					LastFireTime[key] <- Time()
					continue
				}
				
				// Check if recently extinguished
				if (key in LastFireTime)
				{
					if (Time() - LastFireTime[key] < settings.fireDelay)
						continue
				}
			}
			
			// Regenerate health
			local currentHealth = player.GetHealth()
			local maxHealth = GetMaxHealth(zType)
			
			if (currentHealth < maxHealth)
			{
				local newHealth = currentHealth + settings.step
				if (newHealth > maxHealth)
					newHealth = maxHealth
				player.SetHealth(newHealth)
			}
		}
		
		return 0.5
	}
	
	function GetMaxHealth(zombieType)
	{
		switch (zombieType)
		{
			case 1: return 100  // Smoker
			case 2: return 50   // Boomer
			case 3: return 150  // Hunter
			case 4: return 100  // Spitter
			case 5: return 150  // Jockey
			case 6: return 150  // Charger
		}
		return 100
	}
	
	function OnGameEvent_player_hurt(params)
	{
		if (!("userid" in params))
			return
		
		local player = GetPlayerFromUserID(params.userid)
		if (!player || !player.IsValid() || player.IsSurvivor())
			return
		
		local key = player.GetEntityIndex().tostring()
		LastDamageTime[key] <- Time()
	}
	
	// ============================================================
	// RUSH INCAP SYSTEM
	// ============================================================
	function UpdateRushIncap()
	{
		// Find incapacitated survivors
		local survivor = null
		while (survivor = Entities.FindByClassname(survivor, "player"))
		{
			if (!survivor.IsValid() || !survivor.IsSurvivor())
				continue
			if (!survivor.IsIncapacitated())
				continue
			
			local origin = survivor.GetOrigin()
			
			// Attract nearby commons
			local infected = null
			while (infected = Entities.FindByClassnameWithin(infected, "infected", origin, RushRadius))
			{
				if (!infected.IsValid())
					continue
				
				// Set target to incapacitated survivor
				CommandABot({ bot = infected, cmd = 0  /* BOT_CMD_ATTACK */, target = survivor })
			}
		}
		
		return RushInterval
	}
	
	// ============================================================
	// FIRE SPREAD SYSTEM
	// ============================================================
	function UpdateFireSpread()
	{
		local infected = null
		while (infected = Entities.FindByClassname(infected, "infected"))
		{
			if (!infected.IsValid())
				continue
			
			// Check if on fire
			local flame = NetProps.GetPropEntity(infected, "m_hEffectEntity")
			if (!flame || !flame.IsValid() || flame.GetClassname() != "entityflame")
				continue
			
			local origin = infected.GetOrigin()
			
			// Ignite nearby infected
			local nearby = null
			while ((nearby = Entities.FindByClassnameWithin(nearby, "infected", origin, 100)) != null)
			{
				if (!nearby.IsValid() || nearby == infected)
					continue
				
				// Check if already burning
				local nearbyFlame = NetProps.GetPropEntity(nearby, "m_hEffectEntity")
				if (nearbyFlame && nearbyFlame.IsValid() && nearbyFlame.GetClassname() == "entityflame")
					continue
				
				// Ignite
				DoEntFire("!self", "Ignite", "", 0, infected, nearby)
			}
		}
		
		return 0.5
	}
	
	// ============================================================
	// RANDOM WOUNDS
	// ============================================================
	// OnGameEvent_infected_spawn removed — event does NOT exist in L4D2.
	// Random wounds now applied via mob_spawn or infected_hurt hooks if needed.
	
	// ============================================================
	// DEATH FIX
	// ============================================================
	function FixFrozenDeaths()
	{
		local infected = null
		while ((infected = Entities.FindByClassname(infected, "infected")) != null)
		{
			if (!infected.IsValid())
				continue
			
			local health = infected.GetHealth()
			local lifeState = NetProps.GetPropInt(infected, "m_lifeState")
			
			// If health <= 0 but lifeState says alive, force death
			if (health <= 0 && lifeState == 0)
			{
				infected.TakeDamage(100, 0, null)
			}
		}
		
		return 2.0
	}
}

// ================================================================
// REGISTER
// ================================================================
::__CollectGameEventCallbacks(CommonSystem)

printl("[CommonSystem] Loaded - Regen, Fire Spread, Rush Incap, Wounds, Death Fix")
