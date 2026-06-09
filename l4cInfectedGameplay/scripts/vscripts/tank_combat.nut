/**
 * Tank Combat System
 * 
 * Consolidated from: tank_fire_rework.nut + tank_berserker.nut + tank_crowd_control.nut
 * 
 * Features:
 * - Fire Rework: Fire trail, extinguishing, speed boost (+25%)
 * - Berserker States: Wounded/Enraged/Berserker by HP%
 * - Crowd Control: Anti-celebration, AOE knockback, incap splash
 * 
 * Unified timer system (single logic_timer for all combat features)
 */

::TankCombat <-
{
	// ------------------------------------------------------------------
	// CONSTANTS
	// ------------------------------------------------------------------
	
	// Fire system
	DMG_BURN = 268435464
	FIRE_SPEED_BOOST = 1.25
	FIRE_TRAIL_INTERVAL = 0.5
	FIRE_TRAIL_DAMAGE = 2
	FIRE_TRAIL_RADIUS = 60
	FIRE_TRAIL_DURATION = 4.0
	
	// Berserker states
	STATE_WOUNDED_HP = 0.60
	STATE_ENRAGED_HP = 0.35
	STATE_BERSERKER_HP = 0.15
	
	SPEED_WOUNDED = 1.15
	SPEED_ENRAGED = 1.30
	SPEED_BERSERKER = 1.50
	
	DMG_WOUNDED = 0.25
	DMG_ENRAGED = 0.50
	DMG_BERSERKER = 1.00
	
	ROCK_INTERVAL_ENRAGED = 2.5
	ROCK_INTERVAL_BERSERKER = 1.8
	
	// Crowd control
	KNOCKBACK_RADIUS = 150.0
	KNOCKBACK_FORCE_MIN = 200.0
	KNOCKBACK_FORCE_MAX = 400.0
	KNOCKBACK_UPWARD = 100.0
	
	INCAP_SPLASH_RADIUS = 200.0
	INCAP_SPLASH_DAMAGE = 15
	INCAP_SPLASH_FORCE = 250.0
	
	// Sounds
	SND_WOUNDED = "Player.Tank.Pain"
	SND_ENRAGED = "Player.Tank.Attack"
	SND_BERSERKER = "Player.Tank.Yell"
	SND_POUND = "Player.Tank.Pound"
	SND_HIT = "Player.Tank.Hit"
	SND_EXTINGUISH = "Physics.WaterSplash"
	
	// Particles
	PARTICLE_RAGE = "blood_impact_red_01"
	PARTICLE_FIRE = "env_fire_medium"
	PARTICLE_STEAM = "steam_jet_50"
	
	// HUD
	HUD_PRINTCENTER = 4
	HUD_PRINTTALK = 3
	
	// ------------------------------------------------------------------
	// STATE
	// ------------------------------------------------------------------
	
	// Fire system state
	BurningTanks = {}     // ent index -> { startTime, lastTrailTime }
	FireTrails = []       // array of { pos, endTime, owner }
	
	// Berserker state
	TankStates = {}       // ent index -> state string
	TankMaxHP = {}        // ent index -> max HP at spawn
	
	// Crowd control state
	IncappedSurvivors = {} // userid -> true
	
	// Damage recursion guard
	IsApplyingBonusDamage = false
	
	// Timer (MaoLib — NO logic_timer)
	TICK_RATE = 0.5
	
	// ------------------------------------------------------------------
	// INIT
	// ------------------------------------------------------------------
	function Init()
	{
		BurningTanks.clear()
		FireTrails.clear()
		TankStates.clear()
		TankMaxHP.clear()
		IncappedSurvivors.clear()
		IsApplyingBonusDamage = false
		MaoLib.RemoveTimer("tank_combat_update")
	}
	
	// ------------------------------------------------------------------
	// GAME EVENTS
	// ------------------------------------------------------------------
	function OnGameEvent_round_start_post_nav(params)
	{
		Init()
	}
	
	function OnGameEvent_round_end(params)
	{
		MaoLib.RemoveTimer("tank_combat_update")
		Init()
	}
	
	function OnGameEvent_mission_lost(params)
	{
		MaoLib.RemoveTimer("tank_combat_update")
		Init()
	}
	
	function OnGameEvent_tank_spawn(params)
	{
		if (!("userid" in params))
			return;
		
		local tank = GetPlayerFromUserID(params.userid);
		if (!tank || !tank.IsValid())
			return;
		
		local idx = tank.GetEntityIndex().tostring();
		TankStates[idx] <- "normal";
		TankMaxHP[idx] <- tank.GetHealth();
		
		MaoLib.AddTimerForce("tank_combat_update", TICK_RATE, @() ::TankCombat.Update());
	}
	
	function OnGameEvent_player_incapacitated(params)
	{
		if (!("userid" in params))
			return;
		
		IncappedSurvivors[params.userid] <- true;
	}
	
	function OnGameEvent_revive_success(params)
	{
		if (!("subject" in params))
			return;
		
		if (params.subject in IncappedSurvivors)
			delete IncappedSurvivors[params.subject];
	}
	
	function HandlePlayerDeath(params)
	{
		if (!("userid" in params))
			return;
		
		local player = GetPlayerFromUserID(params.userid);
		if (!player || !player.IsValid())
			return;
		
		local idx = player.GetEntityIndex().tostring();
		
		// Clean up tank states
		if (player.GetZombieType() == 8)
		{
			if (idx in TankStates)
				delete TankStates[idx];
			if (idx in TankMaxHP)
				delete TankMaxHP[idx];
			if (idx in BurningTanks)
				delete BurningTanks[idx];
		}
		
		// Clean up incap tracking
		if (params.userid in IncappedSurvivors)
			delete IncappedSurvivors[params.userid];
	}
	function OnGameEvent_player_death(params) { TankCombat.HandlePlayerDeath(params); }
	
	// ------------------------------------------------------------------
	// PLAYER HURT - Handles Fire Detection + Berserker Damage + Crowd Control
	// ------------------------------------------------------------------
	function HandlePlayerHurt(params)
	{
		// 🛡️ CRITICAL: Damage recursion guard. TakeDamage() inside this handler
		// (ApplyAoeKnockback, ApplyIncapSplash, ApplyBerserkerDamage) fires another
		// player_hurt event. This flag must cover the ENTIRE handler, not just
		// ApplyBerserkerDamage, to prevent infinite ping-pong between survivors.
		if (IsApplyingBonusDamage)
			return;
		
		IsApplyingBonusDamage = true;
		
		if (!("userid" in params) || !("attacker" in params) || !("weapon" in params))
		{
			IsApplyingBonusDamage = false;
			return;
		}
		
		local victim = GetPlayerFromUserID(params.userid);
		local attacker = GetPlayerFromUserID(params.attacker);
		
		if (!attacker || !attacker.IsValid())
		{
			IsApplyingBonusDamage = false;
			return;
		}
		
		// --- CASE 1: Tank is the ATTACKER (Crowd Control + Berserker Damage) ---
		if (attacker.GetZombieType() == 8)
		{
			HandleTankAttack(attacker, victim, params);
			IsApplyingBonusDamage = false;
			return;
		}
		
		// --- CASE 2: Tank is the VICTIM (Fire Detection) ---
		if (victim && victim.IsValid() && victim.GetZombieType() == 8)
		{
			HandleTankDamage(victim, params);
		}
		
		IsApplyingBonusDamage = false;
	}
	function OnGameEvent_player_hurt(params) { TankCombat.HandlePlayerHurt(params); }
	
	// ------------------------------------------------------------------
	// TANK ATTACK HANDLER (Crowd Control + Berserker)
	// ------------------------------------------------------------------
	function HandleTankAttack(tank, victim, params)
	{
		if (!victim || !victim.IsValid() || !victim.IsSurvivor())
			return;
		
		local weapon = params.weapon;
		
		// --- CROWD CONTROL: tank_claw only ---
		if (weapon == "tank_claw")
		{
			// 1. Anti-celebration
			CancelCelebration(tank);
			
			// 2. AOE Knockback
			ApplyAoeKnockback(tank, victim);
			
			// 3. Incap Splash
			if (params.userid in IncappedSurvivors)
			{
				ApplyIncapSplash(tank, victim);
			}
			
			// 4. Berserker Bonus Damage
			ApplyBerserkerDamage(tank, victim, params);
		}
	}
	
	// ------------------------------------------------------------------
	// TANK DAMAGE HANDLER (Fire Detection)
	// ------------------------------------------------------------------
	function HandleTankDamage(tank, params)
	{
		if (!("type" in params) || !("dmg_health" in params))
			return;
		
		local damageType = params.type;
		
		// Fire damage detection
		if (damageType == DMG_BURN)
		{
			local idx = tank.GetEntityIndex().tostring();
			
			if (!(idx in BurningTanks))
			{
				BurningTanks[idx] <- {
					startTime = Time(),
					lastTrailTime = Time()
				};
				
				SetFireSpeedMultiplier(tank, FIRE_SPEED_BOOST);
				MaoLib.AddTimerForce("tank_combat_update", TICK_RATE, @() ::TankCombat.Update());
			}
			
			BurningTanks[idx].lastTrailTime = Time();
		}
	}
	
	// ------------------------------------------------------------------
	// CROWD CONTROL FUNCTIONS
	// ------------------------------------------------------------------
	function CancelCelebration(tank)
	{
		NetProps.SetPropIntArray(tank, "m_NetGestureSequence", 0, 0);
		NetProps.SetPropIntArray(tank, "m_NetGestureActivity", 0, 0);
		NetProps.SetPropFloatArray(tank, "m_NetGestureStartTime", -1, 0);
		NetProps.SetPropIntArray(tank, "m_NetGestureSequence", 0, 1);
		NetProps.SetPropIntArray(tank, "m_NetGestureActivity", 0, 1);
		NetProps.SetPropFloatArray(tank, "m_NetGestureStartTime", -1, 1);
	}
	
	function ApplyAoeKnockback(tank, primaryVictim)
	{
		local tankPos = tank.GetOrigin();
		
		local survivor = null;
		while (survivor = Entities.FindByClassname(survivor, "player"))
		{
			if (!survivor.IsValid()) continue;
			if (!survivor.IsSurvivor()) continue;
			if (survivor.GetHealth() <= 0) continue;
			// 🛡️ GUARD: incapacitados tienen health > 0 pero no deben recibir
			// TakeDamage ni ApplyAbsVelocityImpulse — crashea el engine
			if (survivor.IsIncapacitated()) continue;
			if (survivor == primaryVictim) continue;
			
			local dist = (survivor.GetOrigin() - tankPos).Length();
			if (dist > KNOCKBACK_RADIUS) continue;
			
			local dir = survivor.GetOrigin() - tankPos;
			dir.Norm();
			dir.z = 0.2;
			dir.Norm();
			
			local force = KNOCKBACK_FORCE_MAX - ((dist / KNOCKBACK_RADIUS) * (KNOCKBACK_FORCE_MAX - KNOCKBACK_FORCE_MIN));
			local impulse = dir * force;
			impulse.z = KNOCKBACK_UPWARD;
			
			survivor.ApplyAbsVelocityImpulse(impulse);
			survivor.TakeDamage(5, 0, tank);
		}
	}
	
	function ApplyIncapSplash(tank, incapVictim)
	{
		local incapPos = incapVictim.GetOrigin();
		
		local survivor = null;
		while (survivor = Entities.FindByClassname(survivor, "player"))
		{
			if (!survivor.IsValid()) continue;
			if (!survivor.IsSurvivor()) continue;
			if (survivor.GetHealth() <= 0) continue;
			if (survivor == incapVictim) continue;
			
			local dist = (survivor.GetOrigin() - incapPos).Length();
			if (dist > INCAP_SPLASH_RADIUS) continue;
			
			survivor.TakeDamage(INCAP_SPLASH_DAMAGE, 0, tank);
			
			local dir = survivor.GetOrigin() - incapPos;
			dir.Norm();
			dir.z = 0.3;
			dir.Norm();
			
			local impulse = dir * INCAP_SPLASH_FORCE;
			impulse.z = 100;
			survivor.ApplyAbsVelocityImpulse(impulse);
		}
		
		// Visual effect
		local effect = SpawnEntityFromTable("info_particle_system", {
			origin = incapPos + Vector(0, 0, 20),
			effect_name = "impact_dust"
		});
		
		if (effect && effect.IsValid())
		{
			DoEntFire("!self", "Start", "", 0, null, effect);
			DoEntFire("!self", "Kill", "", 1, null, effect);
		}
		
		tank.EmitSound(SND_POUND);
	}
	
	// ------------------------------------------------------------------
	// BERSERKER DAMAGE
	// ------------------------------------------------------------------
	function ApplyBerserkerDamage(tank, victim, params)
	{
		if (!victim || !victim.IsValid()) return
		// 🛡️ GUARD: No TakeDamage/impulse en incapacitados — el engine crashea
		// al procesar la transición incap→dead durante un callback player_hurt
		if (victim.IsPlayer() && victim.IsIncapacitated()) return
		
		local idx = tank.GetEntityIndex().tostring();
		if (!(idx in TankStates))
			return;
		
		local state = TankStates[idx];
		local dmgBonus = 0;
		local knockbackForce = 0;
		
		switch (state)
		{
			case "wounded":
				dmgBonus = DMG_WOUNDED;
				break;
			case "enraged":
				dmgBonus = DMG_ENRAGED;
				knockbackForce = 1.5;
				break;
			case "berserker":
				dmgBonus = DMG_BERSERKER;
				knockbackForce = 3.0;
				break;
		}
		
		if (dmgBonus > 0)
		{
			local baseDmg = params.dmg_health;
			local bonusDmg = (baseDmg * dmgBonus).tointeger();
			if (bonusDmg > 0)
			{
				// Guard already active at HandlePlayerHurt level
				victim.TakeDamage(bonusDmg, 0, tank);
			}
		}
		
		if (knockbackForce > 0)
		{
			local dir = victim.GetOrigin() - tank.GetOrigin();
			dir.Norm();
			dir.z = 0.3;
			dir.Norm();
			
			local impulse = dir * (300 * knockbackForce);
			impulse.z = 150 * knockbackForce;
			victim.ApplyAbsVelocityImpulse(impulse);
		}
	}
	
	// ------------------------------------------------------------------
	// TIMER SYSTEM (MaoLib — NO logic_timer)
	// Timer permanente registrado al cargar el script
	// "tank_combat_update" cada TICK_RATE segundos → ::TankCombat.Update()
	// Start: MaoLib.AddTimerForce (auto-sobrescribe si existe)
	// Stop: MaoLib.RemoveTimer
	// ------------------------------------------------------------------
	/* ELIMINADO: StartUpdateTimer() y KillUpdateTimer()
	   Antes usaban Entities.CreateByClassname("logic_timer") + 3 EntFires
	   Ahora: MaoLib.AddTimerForce("tank_combat_update", TICK_RATE, @() ::TankCombat.Update())
	   Migrado por regla AGENTS.md: NO logic_timer
	*/
	
	// ------------------------------------------------------------------
	// MAIN UPDATE LOOP
	// ------------------------------------------------------------------
	function Update()
	{
		local currentTime = Time();
		local hasActiveTank = false;
		
		// Process all tanks
		local player = null;
		while (player = Entities.FindByClassname(player, "player"))
		{
			if (!player.IsValid()) continue;
			if (player.GetZombieType() != 8) continue; // Not tank
			if (player.GetHealth() <= 0) continue;
			
			hasActiveTank = true;
			local idx = player.GetEntityIndex().tostring();
			
			// Initialize if new
			if (!(idx in TankMaxHP))
			{
				TankMaxHP[idx] <- player.GetHealth();
				TankStates[idx] <- "normal";
			}
			
			// --- BERSERKER STATE UPDATE ---
			local maxHP = TankMaxHP[idx];
			local currentHP = player.GetHealth();
			local hpPercent = currentHP.tofloat() / maxHP.tofloat();
			
			local newState = "normal";
			if (hpPercent <= STATE_BERSERKER_HP)
				newState = "berserker";
			else if (hpPercent <= STATE_ENRAGED_HP)
				newState = "enraged";
			else if (hpPercent <= STATE_WOUNDED_HP)
				newState = "wounded";
			
			local oldState = (idx in TankStates) ? TankStates[idx] : "normal";
			
			if (newState != oldState)
			{
				TankStates[idx] = newState;
				OnStateChanged(player, oldState, newState);
			}
			
			// Apply continuous berserker effects
			ApplyStateEffects(player, newState);
			
			// --- FIRE TRAIL UPDATE ---
			if (idx in BurningTanks)
			{
				local fireData = BurningTanks[idx];
				
				// Check if still on fire
				local isOnFire = false;
				if ("IsOnFire" in player)
				{
					try { isOnFire = player.IsOnFire(); } catch(e) { isOnFire = false; }
				}
				else
				{
					isOnFire = (currentTime - fireData.lastTrailTime < 2.0);
				}
				
				if (!isOnFire)
				{
					// Extinguished
					SetFireSpeedMultiplier(player, 1.0);
					delete BurningTanks[idx];
					CreateSteamEffect(player.GetOrigin());
				}
				else if (currentTime - fireData.lastTrailTime >= FIRE_TRAIL_INTERVAL)
				{
					fireData.lastTrailTime = currentTime;
					CreateFireTrail(player.GetOrigin(), player);
				}
			}
		}
		
		// Update fire trails (damage survivors)
		UpdateFireTrails();
		
		// Kill timer if no active tanks and no fire trails
		if (!hasActiveTank && FireTrails.len() == 0)
			MaoLib.RemoveTimer("tank_combat_update");
	}
	
	// ------------------------------------------------------------------
	// BERSERKER STATE CHANGE
	// ------------------------------------------------------------------
	function OnStateChanged(tank, oldState, newState)
	{
		switch (newState)
		{
			case "wounded":
				ClientPrint(null, HUD_PRINTTALK, "[TANK] WOUNDED - The Tank is bleeding!");
				tank.EmitSound(SND_WOUNDED);
				AttachParticle(tank, PARTICLE_RAGE, 3.0);
				break;
				
			case "enraged":
				ClientPrint(null, HUD_PRINTTALK, "[TANK] ENRAGED - Run!");
				tank.EmitSound(SND_ENRAGED);
				AttachParticle(tank, PARTICLE_RAGE, 5.0);
				ScreenShakeAll(4, 1.0, 2.0);
				Convars.SetValue("tank_throw_interval", ROCK_INTERVAL_ENRAGED.tostring());
				break;
				
			case "berserker":
				ClientPrint(null, HUD_PRINTCENTER, "THE TANK HAS GONE BERSERKER!");
				ClientPrint(null, HUD_PRINTTALK, "[TANK] BERSERKER - It's unstoppable!");
				tank.EmitSound(SND_BERSERKER);
				AttachParticle(tank, PARTICLE_RAGE, 8.0);
				ScreenShakeAll(8, 2.0, 3.0);
				Convars.SetValue("tank_throw_interval", ROCK_INTERVAL_BERSERKER.tostring());
				break;
		}
	}
	
	// ------------------------------------------------------------------
	// BERSERKER CONTINUOUS EFFECTS
	// ------------------------------------------------------------------
	function ApplyStateEffects(tank, state)
	{
		local speedMult = 1.0;
		
		switch (state)
		{
			case "wounded":
				speedMult = SPEED_WOUNDED;
				break;
			case "enraged":
				speedMult = SPEED_ENRAGED;
				if (RandomInt(0, 100) < 10)
					ShakeNearbySurvivors(tank, 3, 0.5);
				break;
			case "berserker":
				speedMult = SPEED_BERSERKER;
				ShakeNearbySurvivors(tank, 5, 0.8);
				TryExtinguish(tank);
				break;
		}
		
		SetBerserkerSpeedMultiplier(tank, speedMult);
	}
	
	// ------------------------------------------------------------------
	// FIRE TRAIL SYSTEM
	// ------------------------------------------------------------------
	function CreateFireTrail(pos, owner)
	{
		local fire = SpawnEntityFromTable("env_fire", {
			origin = pos,
			health = 30,
			firesize = 64,
			fireattack = 4,
			firetype = 0,
			ignitionpoint = 0,
			damagescale = 0,
			spawnflags = 25
		});
		
		if (fire && fire.IsValid())
		{
			DoEntFire("!self", "StartFire", "", 0, null, fire);
			DoEntFire("!self", "Kill", "", FIRE_TRAIL_DURATION, null, fire);
		}
		
		FireTrails.append({
			pos = Vector(pos.x, pos.y, pos.z),
			owner = owner,
			endTime = Time() + FIRE_TRAIL_DURATION,
			lastDamageTime = Time()
		});
	}
	
	function UpdateFireTrails()
	{
		local currentTime = Time();
		local toRemove = [];
		
		for (local i = 0; i < FireTrails.len(); i++)
		{
			local trail = FireTrails[i];
			
			if (currentTime >= trail.endTime)
			{
				toRemove.append(i);
				continue;
			}
			
			if (currentTime - trail.lastDamageTime >= 1.0)
			{
				trail.lastDamageTime = currentTime;
				
				local survivor = null;
				while (survivor = Entities.FindByClassname(survivor, "player"))
				{
					if (!survivor.IsValid()) continue;
					if (!survivor.IsSurvivor()) continue;
					if (survivor.GetHealth() <= 0) continue;
					
					if ((survivor.GetOrigin() - trail.pos).Length() <= FIRE_TRAIL_RADIUS)
					{
						survivor.TakeDamage(FIRE_TRAIL_DAMAGE, DMG_BURN, trail.owner);
					}
				}
			}
		}
		
		for (local i = toRemove.len() - 1; i >= 0; i--)
			FireTrails.remove(toRemove[i]);
	}
	
	// ------------------------------------------------------------------
	// STEAM EFFECT (Extinguish)
	// ------------------------------------------------------------------
	function CreateSteamEffect(pos)
	{
		local steam = SpawnEntityFromTable("info_particle_system", {
			origin = pos + Vector(0, 0, 50),
			effect_name = PARTICLE_STEAM
		});
		
		if (steam && steam.IsValid())
		{
			DoEntFire("!self", "Start", "", 0, null, steam);
			DoEntFire("!self", "Kill", "", 2, null, steam);
		}
		
		local soundEnt = SpawnEntityFromTable("ambient_generic", {
			origin = pos,
			message = SND_EXTINGUISH,
			health = 8,
			spawnflags = 1,
			radius = 600
		});
		
		if (soundEnt && soundEnt.IsValid())
		{
			DoEntFire("!self", "PlaySound", "", 0, null, soundEnt);
			DoEntFire("!self", "Kill", "", 2, null, soundEnt);
		}
	}
	
	// ------------------------------------------------------------------
	// SPEED COORDINATION (Shared with MaoLib)
	// ------------------------------------------------------------------
	function SetFireSpeedMultiplier(tank, mult)
	{
		local idx = tank.GetEntityIndex().tostring();
		MaoLib.TankSpeed_FireMult[idx] <- mult;
		MaoLib.ApplyTankSpeed(tank);
	}
	
	function SetBerserkerSpeedMultiplier(tank, mult)
	{
		local idx = tank.GetEntityIndex().tostring();
		MaoLib.TankSpeed_BerserkerMult[idx] <- mult;
		MaoLib.ApplyTankSpeed(tank);
	}
	
	function TryExtinguish(tank)
	{
		if ("Extinguish" in tank)
		{
			try { tank.Extinguish(); } catch(e) {}
		}
		
		local idx = tank.GetEntityIndex().tostring();
		if (idx in MaoLib.TankSpeed_FireMult)
		{
			MaoLib.TankSpeed_FireMult[idx] <- 1.0;
			MaoLib.ApplyTankSpeed(tank);
		}
	}
	
	// ------------------------------------------------------------------
	// VISUAL EFFECTS
	// ------------------------------------------------------------------
	function AttachParticle(ent, particleName, duration)
	{
		local effect = SpawnEntityFromTable("info_particle_system", {
			origin = ent.GetOrigin(),
			effect_name = particleName
		});
		
		if (effect && effect.IsValid())
		{
			DoEntFire("!self", "SetParent", "#" + ent.GetEntityIndex(), 0, null, effect);
			DoEntFire("!self", "Start", "", 0.1, null, effect);
			DoEntFire("!self", "Kill", "", duration, null, effect);
		}
	}
	
	function ScreenShakeAll(amplitude, duration, frequency)
	{
		local shake = SpawnEntityFromTable("env_shake", {
			origin = Vector(0, 0, 0),
			amplitude = amplitude,
			duration = duration,
			frequency = frequency,
			radius = 99999
		});
		
		if (shake && shake.IsValid())
		{
			DoEntFire("!self", "StartShake", "", 0, null, shake);
			DoEntFire("!self", "Kill", "", duration + 0.5, null, shake);
		}
	}
	
	function ShakeNearbySurvivors(tank, amplitude, duration)
	{
		local tankPos = tank.GetOrigin();
		local survivor = null;
		
		while (survivor = Entities.FindByClassname(survivor, "player"))
		{
			if (!survivor.IsValid()) continue;
			if (!survivor.IsSurvivor()) continue;
			if (survivor.GetHealth() <= 0) continue;
			
			if ((survivor.GetOrigin() - tankPos).Length() <= 800)
			{
				local shake = SpawnEntityFromTable("env_shake", {
					origin = survivor.GetOrigin(),
					amplitude = amplitude,
					duration = duration,
					frequency = 2.0,
					radius = 50
				});
				
				if (shake && shake.IsValid())
				{
					DoEntFire("!self", "StartShake", "", 0, null, shake);
					DoEntFire("!self", "Kill", "", duration + 0.5, null, shake);
				}
			}
		}
	}
}

// ------------------------------------------------------------------
// INIT & REGISTER
// ------------------------------------------------------------------
TankCombat.Init();

__CollectGameEventCallbacks(TankCombat);

printl("=================================");
printl("Tank Combat System Loaded");
printl("Fire + Berserker + Crowd Control");
printl("=================================");