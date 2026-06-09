IncludeScript("maolib", getroottable())
IncludeScript("maolib_vfx", getroottable())

/*
 * ================================================================
 * SMOKER SYSTEM - Consolidated Smoker Mechanics
 * ================================================================
 * Replaces: smoker_momentum_tongue.nut, smoker_fly_bomb.nut, smokerpoison.nut
 * Removes: smoker_last_breath.nut (mechanic removed by design)
 * 
 * Features:
 * - Momentum Tongue: Drag acceleration based on distance + time
 * - Fly Bomb: Hold R to charge and launch poison projectile
 * - Poison DoT: Damage over time on choke based on grab distance
 * ================================================================
 */

::SmokerSystem <-
{
	// ============================================================
	// CONFIGURATION
	// ============================================================
	Settings =
	{
		// Tongue momentum
		TongueBaseImpulse = 2.0,
		TongueTimeMult = 1.2,
		TongueDistDiv = 250.0,
		TongueMaxImpulse = 25.0,
		TongueMinDist = 100.0,
		TongueChokeRange = 80.0,
		TongueTickRate = 0.1,
		
		// Tongue health (100 = vanilla, 200 = harder to cut)
		TongueHealth = 200,
		
		// Drag delay (1.15 = brief pause between grab and pull)
		DragStartDelay = 1.15,
		
		// Smoker drag speed (cvar survivor_drag_speed_multiplier)
		// Vanilla: 0 = engine default slow.  1.0 = normal sin slow
		// Progresivo: 15% → 100% más rápido (~8.5s para llegar al max)
		DragSpeedMultMin = 1.15,
		DragSpeedMultMax = 2.0,
		DragSpeedMultRate = 0.1,
		
		// Fly bomb
		BombChargeTime = 1.25,
		BombCooldown = 20.0,
		BombSpeed = 700.0,
		BombGravity = 40.0,
		BombRadius = 300.0,
		CloudDuration = 10.0,
		BombDamageInterval = 1.0,
		BombDamageAmount = 2,
		BombHealInterval = 2.0,
		BombHealCommon = 5,
		BombHealSpecial = 2,
		BombHealSelf = 3,
		BombBotInterval = 15.0,
		BombBotChance = 0.25,
		
		// Poison DoT
		PoisonDuration = 5.0,
		PoisonTickInterval = 1.0,
		PoisonBaseDamage = 2,
		PoisonDistMult = 0.1,
		
		// Notifications
		ChatNotification = 0,
	}
	
	SettingsFile = "smoker_system/Settings.cfg"
	
	// ============================================================
	// STATE TRACKING
	// ============================================================
	ActiveDrags = {},
	PlayerChargeStart = {},
	PlayerCooldownEnd = {},
	PreviousButtons = {},
	ActiveClouds = [],
	ActiveBombs = [],
	PoisonedVictims = {},
	
	// Constants
	IN_RELOAD = 8192,
	HUD_PRINTCENTER = 4,
	SND_CHARGE = "Player.Smoker.Warn",
	SND_SHOOT = "Player.Smoker.Alert",
	SND_EXPLODE = "Player.Boomer.Explode",
	SND_FLIES = "farm.flies_loop",
	SND_COUGH = "Player.Cough",
	PARTICLE_FLIES = "Spitter_Bugged",
	
	// ============================================================
	// INITIALIZATION
	// ============================================================
	function Init()
	{
		ActiveDrags.clear()
		PlayerChargeStart.clear()
		PlayerCooldownEnd.clear()
		PreviousButtons.clear()
		ActiveClouds.clear()
		ActiveBombs.clear()
		PoisonedVictims.clear()
		
		// Set tongue health (durability + harder to cut)
		Convars.SetValue("tongue_health", Settings.TongueHealth.tostring())
		
		// Restore drag speed to default (no drags active)
		Convars.SetValue("survivor_drag_speed_multiplier", "0")
	}
	
	// ============================================================
	// EVENT HANDLERS
	// ============================================================
	function OnGameEvent_round_start_post_nav(params)
	{
		Init()
		ParseSettings()
	}
	
	function OnGameEvent_round_end(params)
	{
		MaoLib.RemoveTimer("smoker_tongue_drag")
		MaoLib.RemoveTimer("smoker_poison")
		MaoLib.RemoveTimer("smoker_bomb")
		Init()
	}
	
	function OnGameEvent_mission_lost(params)
	{
		MaoLib.RemoveTimer("smoker_tongue_drag")
		MaoLib.RemoveTimer("smoker_poison")
		MaoLib.RemoveTimer("smoker_bomb")
		Init()
	}
	
	function OnGameEvent_player_spawn(params)
	{
		if (!("userid" in params))
			return
		
		local player = GetPlayerFromUserID(params.userid)
		if (!player || !player.IsValid())
			return
		
		local key = player.GetEntityIndex().tostring()
		if (key in PlayerChargeStart)
			delete PlayerChargeStart[key]
		if (key in PlayerCooldownEnd)
			delete PlayerCooldownEnd[key]
		if (key in PreviousButtons)
			delete PreviousButtons[key]
	}
	
	function OnGameEvent_player_death(params)
	{
		if (!("userid" in params))
			return
		
		local player = GetPlayerFromUserID(params.userid)
		if (!player || !player.IsValid())
			return
		
		local key = player.GetEntityIndex().tostring()
		
		// Clean up smoker drag
		if (key in ActiveDrags)
			delete ActiveDrags[key]
		
		// Clean up other smokers' drags where this player was victim
		local toRemove = []
		foreach (dragKey, drag in ActiveDrags)
		{
			if (drag.victim == player)
				toRemove.append(dragKey)
		}
		foreach (remKey in toRemove)
			if (remKey in ActiveDrags)
				delete ActiveDrags[remKey]
		
		// Clean up bomb state
		if (key in PlayerChargeStart)
			delete PlayerChargeStart[key]
		if (key in PlayerCooldownEnd)
			delete PlayerCooldownEnd[key]
		if (key in PreviousButtons)
			delete PreviousButtons[key]
		
		// Clean up poison — if player is the victim OR if player is a smoker whose victims still have active poison
		if (key in PoisonedVictims)
			delete PoisonedVictims[key]
		
		// 🔧 FIX: If the player who died is a smoker, clean up poison on all their victims
		local poisonToRemove = []
		foreach (victimKey, poison in PoisonedVictims)
		{
			if (poison.smoker == player)
				poisonToRemove.append(victimKey)
		}
		foreach (victimKey in poisonToRemove)
			delete PoisonedVictims[victimKey]
	}
	
	// 🔧 FIX: Clean up poison if smoker disconnects without dying/releasing
	function OnGameEvent_player_disconnect(params)
	{
		if (!("userid" in params)) return
		local player = GetPlayerFromUserID(params.userid)
		if (!player) return
		
		local poisonToRemove = []
		foreach (victimKey, poison in PoisonedVictims)
		{
			if (poison.smoker == player)
				poisonToRemove.append(victimKey)
		}
		foreach (victimKey in poisonToRemove)
			delete PoisonedVictims[victimKey]
	}

	// ============================================================
	// TONGUE GRAB - Momentum System
	// ============================================================
	function OnGameEvent_tongue_grab(params)
	{
		if (!("userid" in params) || !("victim" in params))
			return
		
		local smoker = GetPlayerFromUserID(params.userid)
		local victim = GetPlayerFromUserID(params.victim)
		
		if (!smoker || !victim)
			return
		
		// Calculate initial distance
		local dist = (smoker.GetOrigin() - victim.GetOrigin()).Length()
		
		// Ignore if too close
		if (dist < Settings.TongueMinDist)
			return
		
		local key = smoker.GetEntityIndex().tostring()
		ActiveDrags[key] <-
		{
			smoker = smoker,
			victim = victim,
			startTime = Time(),
			dragStartTime = Time() + Settings.DragStartDelay,
			initialDistance = dist
		}
	}
	
	function OnGameEvent_tongue_release(params)
	{
		if (!("userid" in params))
			return
		
		local smoker = GetPlayerFromUserID(params.userid)
		if (!smoker)
			return
		
		local key = smoker.GetEntityIndex().tostring()
		if (key in ActiveDrags)
			delete ActiveDrags[key]

		// 🔧 FIX: Clean up poison DoT on ALL victims of this smoker when tongue releases
		local toRemove = []
		foreach (victimKey, poison in PoisonedVictims)
		{
			if (poison.smoker == smoker)
				toRemove.append(victimKey)
		}
		foreach (victimKey in toRemove)
			delete PoisonedVictims[victimKey]
	}
	
	function UpdateDrags()
	{
		if (ActiveDrags.len() == 0)
		{
			// No drags — restaurar cvar a vanilla (engine default slow)
			Convars.SetValue("survivor_drag_speed_multiplier", "0")
			return
		}
		
		local currentTime = Time()
		local toRemove = []
		local highestMult = 0
		
		foreach (key, drag in ActiveDrags)
		{
			if (!drag.smoker || !drag.smoker.IsValid() || !drag.victim || !drag.victim.IsValid())
			{
				toRemove.append(key)
				continue
			}
			
			// Verify still smoker
			if (drag.smoker.GetZombieType() != 1)
			{
				toRemove.append(key)
				continue
			}
			
			local elapsed = currentTime - drag.startTime
			
			// ============================================================
			// SMOKER SPEED BOOST — cvar survivor_drag_speed_multiplier
			// Progresivo: 1.15 (15%+) → 2.0 (100%+) según tiempo de arrastre
			// Comienza inmediatamente (no espera DragStartDelay)
			// ============================================================
			local mult = Settings.DragSpeedMultMin + (elapsed * Settings.DragSpeedMultRate)
			if (mult > Settings.DragSpeedMultMax)
				mult = Settings.DragSpeedMultMax
			if (mult > highestMult)
				highestMult = mult
			
			// ============================================================
			// DRAG START DELAY — esperar antes de empezar a jalar
			// ============================================================
			if (currentTime < drag.dragStartTime)
				continue
			
			// ============================================================
			// VICTIM PULL — jalar víctima hacia el smoker
			// ============================================================
			local distBonus = drag.initialDistance / Settings.TongueDistDiv
			local timeBonus = elapsed * Settings.TongueTimeMult
			local impulse = Settings.TongueBaseImpulse + timeBonus + distBonus
			
			if (impulse > Settings.TongueMaxImpulse)
				impulse = Settings.TongueMaxImpulse
			
			local dir = drag.smoker.GetOrigin() - drag.victim.GetOrigin()
			local currentDist = dir.Length()
			
			// Stop if in choke range
			if (currentDist < Settings.TongueChokeRange)
			{
				toRemove.append(key)
				continue
			}
			
			dir.Norm()
			drag.victim.ApplyAbsVelocityImpulse(dir * impulse)
		}
		
		// Aplicar cvar con el multiplier más alto entre todos los drags
		if (highestMult > 0)
			Convars.SetValue("survivor_drag_speed_multiplier", highestMult.tostring())
		
		foreach (key in toRemove)
			if (key in ActiveDrags)
				delete ActiveDrags[key]
	}
	
	// ============================================================
	// POISON DoT SYSTEM
	// ============================================================
	function OnGameEvent_choke_start(params)
	{
		if (!("userid" in params) || !("victim" in params))
			return
		if (!params.userid || !params.victim)
			return
		
		local smoker = GetPlayerFromUserID(params.userid)
		local victim = GetPlayerFromUserID(params.victim)
		
		if (!smoker || !victim)
			return
		if (smoker.GetZombieType() != 1)
			return
		if (!victim.IsSurvivor())
			return
		
		// Get distance from context
		local distStr = ResponseCriteria.GetValue(smoker, "SmokerVictimDistance")
		local dist = 0
		if (distStr != null && distStr != "")
			dist = distStr.tointeger()
		
		local bonusDamage = sqrt(dist).tointeger()
		
		if (Settings.ChatNotification > 0)
		{
			ClientPrint(null, 3  /* HUD_PRINTTALK */, "\x04" + smoker.GetPlayerName() + 
				" poisoned " + victim.GetPlayerName() + " for " + bonusDamage + " damage over time")
		}
		
		// Apply poison DoT instead of instant temp health
		ApplyPoisonDoT(victim, smoker, bonusDamage, dist)
	}
	
	function ApplyPoisonDoT(victim, smoker, totalDamage, distance)
	{
		local victimKey = victim.GetEntityIndex().tostring()
		local tickDamage = Settings.PoisonBaseDamage + (distance * Settings.PoisonDistMult).tointeger()
		local totalTicks = Settings.PoisonDuration / Settings.PoisonTickInterval
		
		// Cap total damage
		if (tickDamage * totalTicks > totalDamage && totalDamage > 0)
			tickDamage = (totalDamage / totalTicks).tointeger()
		
		if (tickDamage < 1)
			tickDamage = 1
		
		PoisonedVictims[victimKey] <-
		{
			victim = victim,
			smoker = smoker,
			tickDamage = tickDamage,
			ticksRemaining = totalTicks.tointeger(),
			nextTick = Time() + Settings.PoisonTickInterval
		}
		
		// Visual feedback
		MaoLib_VFX.SpawnParticleOnEntity(victim, "Spitter_slime_trail", "", 2.0)
	}
	
	function UpdatePoison()
	{
		if (PoisonedVictims.len() == 0)
			return
		
		local toRemove = []
		foreach (key, poison in PoisonedVictims)
		{
			if (!poison.victim || !poison.victim.IsValid() || !poison.victim.IsSurvivor())
			{
				toRemove.append(key)
				continue
			}
			
			if (poison.victim.GetHealth() <= 0)
			{
				toRemove.append(key)
				continue
			}
			
			if (Time() >= poison.nextTick)
			{
				poison.nextTick = Time() + Settings.PoisonTickInterval
				poison.ticksRemaining--
				
				// Apply DoT damage
				if (poison.smoker && poison.smoker.IsValid())
				{
					poison.victim.TakeDamage(poison.tickDamage, 262144, poison.smoker) // DMG_POISON
				}
				else
				{
					poison.victim.TakeDamage(poison.tickDamage, 262144, null)
				}
				
				// Visual
				MaoLib_VFX.SpawnParticleOnEntity(poison.victim, "blood_impact_red_01", "", 0.5)
				
				if (poison.ticksRemaining <= 0)
					toRemove.append(key)
			}
		}
		
		foreach (key in toRemove)
			if (key in PoisonedVictims)
				delete PoisonedVictims[key]
	}
	
	// ============================================================
	// FLY BOMB SYSTEM
	// ============================================================
	// StartBombTimer ELIMINADO — ahora es timer permanente via MaoLib.AddTimer
	// Ver registro al final del archivo
	
	function UpdateBombSystem()
	{
		local currentTime = Time()
		local player = null
		
		while (player = Entities.FindByClassname(player, "player"))
		{
			if (!player.IsValid())
				continue
			if (player.GetZombieType() != 1)
				continue
			if (player.GetHealth() <= 0)
				continue
			
			local key = player.GetEntityIndex().tostring()
			local buttons = 0
			if ("GetPlayerButtons" in player)
				buttons = player.GetPlayerButtons()
			
			local oldButtons = (key in PreviousButtons) ? PreviousButtons[key] : 0
			
			// Human players
			if (!IsPlayerABot(player))
			{
				local pressedReload = (buttons & IN_RELOAD) && !(oldButtons & IN_RELOAD)
				local releasedReload = !(buttons & IN_RELOAD) && (oldButtons & IN_RELOAD)
				local holdingReload = (buttons & IN_RELOAD) && (oldButtons & IN_RELOAD)
				
				if (pressedReload)
				{
					if (!(key in PlayerCooldownEnd) || currentTime >= PlayerCooldownEnd[key])
					{
						StartCharge(player)
					}
					else
					{
						local remaining = (PlayerCooldownEnd[key] - currentTime).tointeger()
						ClientPrint(player, HUD_PRINTCENTER, "FLY BOMB COOLDOWN: " + remaining + "s")
					}
				}
				else if (releasedReload)
				{
					if (key in PlayerChargeStart)
					{
						if (currentTime - PlayerChargeStart[key] < Settings.BombChargeTime)
							CancelCharge(player)
					}
				}
				else if (holdingReload && (key in PlayerChargeStart))
				{
					local elapsed = currentTime - PlayerChargeStart[key]
					
					// Visual feedback during charge
					local chargePercent = elapsed / Settings.BombChargeTime
					if (chargePercent < 1.0)
					{
						ShowChargeProgress(player, chargePercent)
					}
					else
					{
						LaunchBomb(player)
						delete PlayerChargeStart[key]
					}
				}
			}
			
			PreviousButtons[key] <- buttons
		}
		
		// Bot AI
		if (currentTime % Settings.BombBotInterval < 0.1)
			CheckBotAI()
		
		UpdateBombs()
		UpdateClouds()
	}
	
	// Visual charge indicator using sprite
	function ShowChargeProgress(player, percent)
	{
		// Create or update charge sprite
		local spriteName = "smoker_charge_" + player.GetEntityIndex()
		local existing = Entities.FindByName(null, spriteName)
		
		if (!existing || !existing.IsValid())
		{
			existing = SpawnEntityFromTable("env_sprite", {
				targetname = spriteName,
				origin = player.EyePosition() + Vector(0, 0, 20),
				model = "sprites/glow01.vmt",
				rendercolor = percent < 0.5 ? "255 255 0" : "255 100 0",
				renderamt = (percent * 200).tointeger(),
				scale = 0.2 + (percent * 0.3),
				spawnflags = 1
			})
			
			if (existing && existing.IsValid())
			{
				// Parent to player so it follows
				DoEntFire("!self", "SetParent", "!activator", 0, player, existing)
			}
		}
		else
		{
			// Update existing sprite color and scale
			existing.__KeyValueFromString("rendercolor", percent < 0.5 ? "255 255 0" : "255 100 0")
			existing.__KeyValueFromFloat("scale", 0.2 + (percent * 0.3))
		}
		
		// Clean up sprite after charge completes or cancels
		local pIdx = player.GetEntityIndex()
		MaoLib.DelayCall(function() { SmokerSystem.CleanupChargeSprite(pIdx) }, 0.5)
	}
	
	function CleanupChargeSprite(playerIndex)
	{
		local spriteName = "smoker_charge_" + playerIndex
		local existing = Entities.FindByName(null, spriteName)
		if (existing && existing.IsValid())
			existing.Kill()
	}
	
	function StartCharge(player)
	{
		local key = player.GetEntityIndex().tostring()
		PlayerChargeStart[key] <- Time()
		player.EmitSound(SND_CHARGE)
		ClientPrint(player, HUD_PRINTCENTER, "FLY BOMB CHARGING...")
	}
	
	function CancelCharge(player)
	{
		local key = player.GetEntityIndex().tostring()
		if (key in PlayerChargeStart)
			delete PlayerChargeStart[key]
		
		StopSoundOn(SND_CHARGE, player)
		ClientPrint(player, HUD_PRINTCENTER, "FLY BOMB CANCELLED")
		CleanupChargeSprite(player.GetEntityIndex())
	}
	
	function LaunchBomb(player)
	{
		local key = player.GetEntityIndex().tostring()
		
		StopSoundOn(SND_CHARGE, player)
		player.EmitSound(SND_SHOOT)
		ClientPrint(player, HUD_PRINTCENTER, "FLY BOMB READY!")
		
		PlayerCooldownEnd[key] <- Time() + Settings.BombCooldown
		CleanupChargeSprite(player.GetEntityIndex())
		
		local startPos = player.EyePosition()
		local forward = player.GetForwardVector()
		
		local sprite = SpawnEntityFromTable("env_sprite", {
			model = "sprites/glow01.vmt",
			origin = startPos,
			rendercolor = "100 255 50",
			renderamt = 200,
			scale = 0.4,
			spawnflags = 1
		})
		
		ActiveBombs.append({
			sprite = sprite,
			velocity = forward * Settings.BombSpeed,
			owner = player,
			startTime = Time()
		})
	}
	
	function CheckBotAI()
	{
		local player = null
		while (player = Entities.FindByClassname(player, "player"))
		{
			if (!player.IsValid() || player.GetZombieType() != 1 || player.GetHealth() <= 0)
				continue
			if (!IsPlayerABot(player))
				continue
			
			local key = player.GetEntityIndex().tostring()
			if ((key in PlayerCooldownEnd) && Time() < PlayerCooldownEnd[key])
				continue
			
			if (RandomFloat(0.0, 1.0) > Settings.BombBotChance)
				continue
			
			local target = FindBestBotTarget(player)
			if (!target)
				continue
			
			BotLaunchBomb(player, target)
		}
	}
	
	function FindBestBotTarget(smoker)
	{
		local smokerPos = smoker.GetOrigin()
		local bestTarget = null
		local bestScore = -1
		
		local survivor = null
		while (survivor = Entities.FindByClassname(survivor, "player"))
		{
			if (!survivor.IsValid() || !survivor.IsSurvivor() || survivor.GetHealth() <= 0)
				continue
			
			local dist = (survivor.GetOrigin() - smokerPos).Length()
			if (dist < 300 || dist > 1500)
				continue
			
			// Check LOS
			local trace = {
				start = smoker.EyePosition(),
				end = survivor.EyePosition(),
				ignore = smoker,
				mask = 0x200400B
			}
			TraceLine(trace)
			
			if (!trace.hit || !trace.enthit || !trace.enthit.IsValid())
				continue
			if (trace.enthit.GetClassname() == "worldspawn")
				continue
			
			local score = 1000 - fabs(dist - 800)
			score += CountNearbySurvivors(survivor.GetOrigin(), 300) * 200
			
			if (score > bestScore)
			{
				bestScore = score
				bestTarget = survivor
			}
		}
		
		return bestTarget
	}
	
	function CountNearbySurvivors(pos, radius)
	{
		local count = 0
		local survivor = null
		while (survivor = Entities.FindByClassname(survivor, "player"))
		{
			if (!survivor.IsValid() || !survivor.IsSurvivor() || survivor.GetHealth() <= 0)
				continue
			if ((survivor.GetOrigin() - pos).Length() <= radius)
				count++
		}
		return count
	}
	
	function BotLaunchBomb(smoker, target)
	{
		local key = smoker.GetEntityIndex().tostring()
		PlayerCooldownEnd[key] <- Time() + Settings.BombCooldown
		smoker.EmitSound(SND_SHOOT)
		
		local startPos = smoker.EyePosition()
		local dir = target.GetOrigin() - startPos
		dir.Norm()
		
		local sprite = SpawnEntityFromTable("env_sprite", {
			model = "sprites/glow01.vmt",
			origin = startPos,
			rendercolor = "100 255 50",
			renderamt = 200,
			scale = 0.4,
			spawnflags = 1
		})
		
		ActiveBombs.append({
			sprite = sprite,
			velocity = dir * Settings.BombSpeed,
			owner = smoker,
			startTime = Time()
		})
	}
	
	function UpdateBombs()
	{
		local toRemove = []
		
		for (local i = 0; i < ActiveBombs.len(); i++)
		{
			local bomb = ActiveBombs[i]
			
			if (!bomb.sprite || !bomb.sprite.IsValid())
			{
				toRemove.append(i)
				continue
			}
			
			bomb.velocity.z -= Settings.BombGravity * 0.1
			
			local currentPos = bomb.sprite.GetOrigin()
			local newPos = currentPos + bomb.velocity * 0.1
			
			local trace = {
				start = currentPos,
				end = newPos,
				ignore = bomb.owner,
				mask = 0x200400B
			}
			TraceLine(trace)
			
			if (trace.hit && trace.enthit && trace.enthit.IsValid())
			{
				ExplodeBomb(trace.pos, bomb.owner)
				bomb.sprite.Kill()
				toRemove.append(i)
				continue
			}
			
			if (newPos.z < -5000)
			{
				bomb.sprite.Kill()
				toRemove.append(i)
				continue
			}
			
			bomb.sprite.SetOrigin(newPos)
		}
		
		for (local i = toRemove.len() - 1; i >= 0; i--)
			ActiveBombs.remove(toRemove[i])
	}
	
	function ExplodeBomb(pos, owner)
	{
		if (owner && owner.IsValid())
			owner.EmitSound(SND_EXPLODE)
		
		CreateFlyCloud(pos, owner)
	}
	
	function CreateFlyCloud(pos, owner, duration = null)
	{
		if (duration == null)
			duration = Settings.CloudDuration
		
		local endTime = Time() + duration
		
		local smoke = SpawnEntityFromTable("env_smokestack", {
			origin = pos,
			BaseSpread = 30,
			SpreadSpeed = 20,
			Speed = 40,
			StartSize = 30,
			EndSize = 100,
			Rate = 50,
			JetLength = 150,
			WindAngle = 0,
			WindSpeed = 0,
			SmokeMaterial = "particle/particle_smokegrenade",
			twist = 10,
			rendercolor = "80 140 40",
			renderamt = 180,
			InitialState = 1
		})
		
		local flies = SpawnEntityFromTable("info_particle_system", {
			origin = pos + Vector(0, 0, 50),
			effect_name = PARTICLE_FLIES,
			start_active = 1
		})
		
		local soundEnt = SpawnEntityFromTable("ambient_generic", {
			origin = pos,
			message = SND_FLIES,
			health = 10,
			spawnflags = 17,
			radius = 800
		})
		
		if (soundEnt && soundEnt.IsValid())
			DoEntFire("!self", "PlaySound", "", 0.1, null, soundEnt)
		
		// Schedule cleanup
		if (smoke && smoke.IsValid())
			DoEntFire("!self", "Kill", "", duration, null, smoke)
		if (flies && flies.IsValid())
			DoEntFire("!self", "Kill", "", duration, null, flies)
		if (soundEnt && soundEnt.IsValid())
		{
			DoEntFire("!self", "StopSound", "", duration - 0.5, null, soundEnt)
			DoEntFire("!self", "Kill", "", duration, null, soundEnt)
		}
		
		ActiveClouds.append({
			pos = Vector(pos.x, pos.y, pos.z),
			owner = owner,
			endTime = endTime,
			radius = Settings.BombRadius,
			lastDamageTime = Time(),
			lastHealTime = Time(),
			lastShakeTime = Time(),
			lastCommonTime = Time()
		})
	}
	
	function UpdateClouds()
	{
		local currentTime = Time()
		local toRemove = []
		
		for (local i = 0; i < ActiveClouds.len(); i++)
		{
			local cloud = ActiveClouds[i]
			
			if (currentTime >= cloud.endTime)
			{
				toRemove.append(i)
				continue
			}
			
			if (currentTime - cloud.lastDamageTime >= Settings.BombDamageInterval)
			{
				cloud.lastDamageTime = currentTime
				DamageSurvivorsInCloud(cloud)
			}
			
			if (currentTime - cloud.lastHealTime >= Settings.BombHealInterval)
			{
				cloud.lastHealTime = currentTime
				HealInfectedInCloud(cloud)
			}
			
			if (currentTime - cloud.lastShakeTime >= Settings.BombDamageInterval * 2)
			{
				cloud.lastShakeTime = currentTime
				ShakeSurvivorsInCloud(cloud)
			}
			
			if (currentTime - cloud.lastCommonTime >= 3.0)
			{
				cloud.lastCommonTime = currentTime
				SpawnCommonInCloud(cloud)
			}
		}
		
		for (local i = toRemove.len() - 1; i >= 0; i--)
			ActiveClouds.remove(toRemove[i])
	}
	
	function DamageSurvivorsInCloud(cloud)
	{
		local survivor = null
		while (survivor = Entities.FindByClassname(survivor, "player"))
		{
			if (!survivor.IsValid() || !survivor.IsSurvivor() || survivor.GetHealth() <= 0)
				continue
			if ((survivor.GetOrigin() - cloud.pos).Length() > cloud.radius)
				continue
			
			if (cloud.owner && cloud.owner.IsValid())
				survivor.TakeDamage(Settings.BombDamageAmount, 262144, cloud.owner)
			else
				survivor.TakeDamage(Settings.BombDamageAmount, 262144, null)
			
			survivor.EmitSound(SND_COUGH)
		}
	}
	
	function HealInfectedInCloud(cloud)
	{
		// Heal commons
		local infected = null
		while (infected = Entities.FindByClassname(infected, "infected"))
		{
			if (!infected.IsValid())
				continue
			if ((infected.GetOrigin() - cloud.pos).Length() > cloud.radius)
				continue
			
			local newHealth = infected.GetHealth() + Settings.BombHealCommon
			if (newHealth > 50) newHealth = 50
			infected.SetHealth(newHealth)
		}
		
		// Heal specials
		local player = null
		while (player = Entities.FindByClassname(player, "player"))
		{
			if (!player.IsValid() || player.IsSurvivor() || player.GetHealth() <= 0)
				continue
			if ((player.GetOrigin() - cloud.pos).Length() > cloud.radius)
				continue
			
			local healAmount = Settings.BombHealSpecial
			if (cloud.owner && player == cloud.owner)
				healAmount = Settings.BombHealSelf
			
			local newHealth = player.GetHealth() + healAmount
			if (newHealth > 700) newHealth = 700
			player.SetHealth(newHealth)
		}
	}
	
	function ShakeSurvivorsInCloud(cloud)
	{
		local survivor = null
		while (survivor = Entities.FindByClassname(survivor, "player"))
		{
			if (!survivor.IsValid() || !survivor.IsSurvivor() || survivor.GetHealth() <= 0)
				continue
			if ((survivor.GetOrigin() - cloud.pos).Length() > cloud.radius)
				continue
			
			MaoLib_VFX.ScreenShake(survivor.GetOrigin(), 4, 2.0, 0.8, 50)
			
			// Attach fly particles
			local effect = SpawnEntityFromTable("info_particle_system", {
				origin = survivor.GetOrigin(),
				effect_name = PARTICLE_FLIES
			})
			if (effect && effect.IsValid())
			{
				DoEntFire("!self", "SetParent", "#" + survivor.GetEntityIndex(), 0, null, effect)
				DoEntFire("!self", "Start", "", 0.1, null, effect)
				DoEntFire("!self", "Kill", "", 2, null, effect)
			}
		}
	}
	
	function SpawnCommonInCloud(cloud)
	{
		local count = RandomInt(1, 2)
		for (local i = 0; i < count; i++)
		{
			local angle = RandomFloat(0, 6.28318)
			local dist = RandomFloat(100, cloud.radius * 0.8)
			local offset = Vector(cos(angle) * dist, sin(angle) * dist, 0)
			local spawnPos = cloud.pos + offset
			spawnPos.z = cloud.pos.z + 10
			
			SpawnEntityFromTable("infected", { origin = spawnPos })
		}
	}
	
	// ============================================================
	// SETTINGS PARSER
	// ============================================================
	function ParseSettings()
	{
		local file = FileToString(SettingsFile)
		
		local function SerializeSettings()
		{
			local sData = "{"
			foreach (key, val in Settings)
			{
				if (typeof(val) == "string")
					val = "\"" + val + "\""
				else if (typeof(val) == "array")
				{
					local newValue = "["
					for (local i = 0; i < val.len(); i++)
					{
						if (typeof(val[i]) == "string")
							newValue += "\"" + val[i] + "\""
						else
							newValue += val[i].tostring()
						if (i < val.len() - 1)
							newValue += ", "
					}
					newValue += "]"
					val = newValue
				}
				sData += "\n\t" + key + " = " + val
			}
			sData += "\n}"
			StringToFile(SettingsFile, sData)
		}
		
		if (file)
		{
			try
			{
				local tData = MaoLib.ParseConfigString(file)
				local hasMissingKey = false
				foreach (key, val in Settings)
				{
					if (key in tData)
						Settings[key] = tData[key]
					else
						hasMissingKey = true
				}
				if (hasMissingKey)
					SerializeSettings()
			}
			catch (error)
			{
				SerializeSettings()
			}
		}
		else
		{
			SerializeSettings()
		}
	}
}

// ================================================================
// REGISTER AND START
// ================================================================
::__CollectGameEventCallbacks(SmokerSystem)
::SmokerSystem.Init()
::SmokerSystem.ParseSettings()

// Timers permanentes via MaoLib (NO logic_timer — ver AGENTS.md regla crítica)
MaoLib.AddTimer("smoker_tongue_drag", 0.1, @() ::SmokerSystem.UpdateDrags())
MaoLib.AddTimer("smoker_poison", 1.0, @() ::SmokerSystem.UpdatePoison())
MaoLib.AddTimer("smoker_bomb", 0.1, @() ::SmokerSystem.UpdateBombSystem())

printl("[SmokerSystem] Loaded - Momentum Tongue, Poison DoT, Fly Bomb")
