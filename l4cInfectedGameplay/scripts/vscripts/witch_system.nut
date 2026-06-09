IncludeScript("maolib", getroottable())

/*
 * ================================================================
 * WITCH SYSTEM v3.0 - Consolidated Witch Behavior Module
 * ================================================================
 * Replaces: witchspawn.nut, witchprops.nut, flashlight_witch.nut, 
 *           witch_horde.nut, sensible_witch.nut, xenorvya_witch_turn_behavior.nut
 * 
 * Integrates:
 * - Spawn relocation (away from main path)
 * - Prop-based anger (gascans, props thrown near her)
 * - Flashlight sensitivity with per-witch NetProps rage
 * - Walking noise detection
 * - Weapon fire sensitivity per weapon type
 * - Alert/turning system (witch physically rotates toward threats)
 * - Turn animations (SetSequence for turn left/right/180)
 * - Focus/stress system with retargeting
 * - Retreat system when no target found
 * - Horde trigger (witch scream spawns panic event)
 * ================================================================
 */

::WitchSystem <-
{
	// ============================================================
	// DEBUG
	// ============================================================
	Debug = 1

	function Dbg(msg) {
		if (Debug) printl("[WitchSystem] " + msg)
	}

	function DbgWarn(msg) {
		printl("[WitchSystem][WARN] " + msg)
	}

	// ============================================================
	// STATE & TURN ANIM CONSTANTS
	// ============================================================
	STATE_IDLE        = "idle"
	STATE_ALERT       = "alert"       // Detectó amenaza, girando hacia ella
	STATE_ENRAGED     = "enraged"     // Rage >= 1.0, atacando
	STATE_PRERETREAT  = "pre_retreat" // Perdió foco, buscando nuevo target
	STATE_RETREAT     = "retreat"     // No encontró target, volviendo a calma

	// Turn animations (xenorvya ref)
	TURN_180  = 33
	TURN_RIGHT = 34
	TURN_LEFT  = 35
	TURN_ANIMS = [33, 34, 35]
	WANDER_ANIMS = [2, 10, 11, 30]
	CRYING_ANIM  = 4

	// Yaw offset when turn animation finishes
	TurnYawOffset = {
		["33"] = 200.0,
		["34"] = -47.5,
		["35"] = 47.5
	}

	// For 180-turn interrupt (rage during turn)
	Turn180InterruptStages = [
		[3.0,  200.0],  // full turn
		[2.5, -150.0],  // past right
		[2.0, -100.0],  // full right
		[1.0,  -50.0],  // bit right
		[0.0,    0.0],  // forward
	]

	// ============================================================
	// SETTINGS
	// ============================================================
	SpawnSettings =
	{
		TooCloseRadius = 150,
		PotentialNewSpotRadius = 750,
		PotentialNewFarSpotRadius = 1500,
		RelocateChance = 1,
		AllowWanderingRelocation = 0,
		AllowBrideRelocation = 0,
	}

	PropSettings =
	{
		distance = 192,
		multiplier = 0.1,
		time = 5.0,
		velocity = 20,
		check_timer = 0.125,
		max_anger = 0.5,
		brush_distance = 24,
		brush_bonus = 0.04,
	}

	PropOptionsFile =
	[
		"// Distance between witch and prop before she starts getting angry",
		"distance",
		"\n",
		"// Multiplies how angry the witch will get (relative to check_timer)",
		"multiplier",
		"\n",
		"// How long the prop will anger witches after being thrown",
		"time",
		"\n",
		"// Minimum velocity for the witch to get angry from the prop",
		"velocity",
		"\n",
		"// How often to track the prop and anger any witches",
		"check_timer",
		"\n",
		"// Max anger (0-1) from props. -1 or 1 means she starts chasing",
		"max_anger",
		"\n",
		"// Distance before prop starts getting witch really angry",
		"brush_distance",
		"\n",
		"// Extra anger added from brush distance",
		"brush_bonus",
	]

	// Range per weapon type: [minRadius, maxRadius, angerPerShot]
	WeaponRanges = {
		smg_silenced     = [600, 750,  0.0200]
		pistol           = [800, 1000, 0.0200]
		smg              = [800, 1000, 0.0200]
		smg_mp5          = [800, 1000, 0.0200]
		pumpshotgun      = [900, 1200, 0.0175]
		shotgun_chrome   = [900, 1200, 0.0175]
		autoshotgun      = [900, 1200, 0.0175]
		shotgun_spas     = [900, 1200, 0.0175]
		rifle            = [1000, 1350, 0.0235]
		rifle_ak47       = [1000, 1350, 0.0235]
		rifle_sg552      = [1000, 1350, 0.0235]
		rifle_desert     = [1000, 1350, 0.0235]
		pistol_magnum    = [1200, 1500, 0.0450]
		rifle_m60        = [1200, 1500, 0.0450]
		hunting_rifle    = [1200, 1500, 0.0450]
		sniper_military  = [1200, 1500, 0.0450]
		sniper_scout     = [1400, 1700, 0.0950]
		sniper_awp       = [1700, 2000, 0.2150]
		grenade_launcher = [1700, 2000, 0.2150]
	}

	// ============================================================
	// FLASHLIGHT SETTINGS
	// ============================================================
	FlashlightSettings =
	{
		alert_anger_per_tick = 0.05,    // Rage added per tick (~10s to full rage at 0.5s ticks)
		sight_range = 800,               // Max distance for flashlight detection
		forward_tolerance = 0.90,        // How directly player must face witch (1.0 = perfect)
		walk_noise_range = 350,          // Distance for walk noise detection (reduced from 500)
		walk_anger = 0.05,               // Rage added per tick from walk noise (halved)
		walk_velocity_threshold = 88,    // Min velocity to count as "walking"
		weapon_cooldown_alert = 18,      // Seconds between weapon-fire alerts
		alert_turns = 30,                // How many ticks witch turns toward threat
		alert_turn_angle = 5.0,          // Degrees per turn tick
		alert_turn_threshold = 60.0,     // Min angle diff to trigger a turn
		stress_visual = 15,              // Stress threshold when target visible
		stress_occluded = 30,            // Stress threshold when target blocked
		focus_max = 10,                  // Max focus ticks before losing target
		retreat_wait = 4,                // Ticks to wait in pre-retreat before retreating
		too_far_distance = 500,          // Distance before witch gives up
	}

	// ============================================================
	// EVENT: Round Start - Load configurations
	// ============================================================
	function OnGameEvent_round_start(opts)
	{
		Dbg("ENTER round_start")
		PropSettings = MaoLib.InitOptionsFmt(PropSettings, "witchprops/options.cfg", PropOptionsFile)
		ParseSpawnSettings()
		Dbg("EXIT round_start")
	}

	function OnGameEvent_round_start_post_nav(event)
	{
		Dbg("ENTER round_start_post_nav")
		// Generate and load flashlight config (legacy support)
		GenerateFlashlightConfig()
		LoadFlashlightConfig("flashlight_witches_v2/settings.txt")
		Dbg("EXIT round_start_post_nav")
	}

	function OnGameEvent_round_end(params)
	{
		Dbg("ENTER round_end — clearing all witch timers")
		
		// 🛡️ Per-witch cleanup: remove all timers this script owns.
		// NEVER call MaoLib.ClearAllTimers() — it kills the shared timer manager
		// and can cause duplicate logic_timer entities between rounds.
		foreach (witch in MaoLib.YieldWitches())
		{
			if (!witch || !witch.IsValid()) continue
			local idx = witch.entindex()
			MaoLib.RemoveTimer("witch_turn_" + idx)
			MaoLib.RemoveTimer("witch_turn_finish_" + idx)
			MaoLib.RemoveTimer("witch_turn_poll_" + idx)
			MaoLib.RemoveTimer("witch_behavior_" + idx)
		}
		
		// Also remove any orphaned prop-monitor timers
		local ent = null
		while (ent = Entities.FindByClassname(ent, "prop_physics"))
		{
			if (ent && ent.IsValid())
			{
				local timerName = "witchprops_" + ent.entindex()
				MaoLib.RemoveTimer(timerName)
			}
		}
		
		Dbg("EXIT round_end")
	}

	// ============================================================
	// WITCH STATE INITIALIZATION
	// ============================================================
	function InitWitchScope(witch)
	{
		witch.ValidateScriptScope()
		local scope = witch.GetScriptScope()

		// State machine
		scope.ws_state          <- STATE_IDLE

		// Turning state (xenorvya)
		scope.ws_turnActive     <- false
		scope.ws_turnLoopRunning <- false
		scope.ws_lastTurnAnim   <- -1
		scope.ws_turnStartTime  <- -1.0

		// Alert state (sensible_witch)
		scope.ws_alertAng       <- null     // Angle to turn toward
		scope.ws_alertZone      <- null     // Origin of alert
		scope.ws_alertTurns     <- null     // Remaining turn ticks
		scope.ws_alertTime      <- 0        // Last alert timestamp
		scope.ws_stress         <- 0        // Accumulated stress
		scope.ws_focus          <- 0        // Focus on current target
		scope.ws_wait           <- 0        // Wait counter (pre-retreat)

		// Target tracking
		scope.ws_target         <- null     // Current target player

		// Monitor handles
		scope.ws_monitorActive  <- true

		return scope
	}

	function GetWitchScope(witch)
	{
		if (!witch || !witch.IsValid())
			return null
		witch.ValidateScriptScope()
		return witch.GetScriptScope()
	}

	// ============================================================
	// FLASHLIGHT DETECTION HELPERS
	// ============================================================
	function IsFlashlightOn(player)
	{
		return (NetProps.GetPropInt(player, "m_fEffects") & 4) != 0
	}

	function IsForward(player, witch)
	{
		local playerPos = player.EyePosition()
		local witchPos = Vector(witch.GetOrigin().x, witch.GetOrigin().y,
		                       (witch.GetOrigin().z + witch.GetCenter().z) / 2)
		local eyesForward = player.EyeAngles().Forward()
		local posForward = witchPos - playerPos
		local cosine = posForward.Dot(eyesForward) / (posForward.Length() * eyesForward.Length())
		return cosine > FlashlightSettings.forward_tolerance
	}

	function HasLineOfSight(startEnt, endEnt)
	{
		local startPos = Vector(startEnt.GetOrigin().x, startEnt.GetOrigin().y,
		                        (startEnt.GetOrigin().z + startEnt.GetCenter().z) / 2)
		local endPos = endEnt.EyePosition()

		local trace =
		{
			start = startPos
			end = endPos
			mask = 33579073   // Vision mask
			ignore = startEnt
			enthit = null
		}
		TraceLine(trace)

		if (trace.hit && trace.enthit)
		{
			if (trace.enthit.GetClassname() == "player" && trace.enthit == endEnt)
				return true
			return false
		}
		return true
	}

	function IsVisionObstructed(witch, player)
	{
		return !HasLineOfSight(witch, player)
	}

	function IsTooFar(survivor, witch)
	{
		local distance = (survivor.GetOrigin() - witch.GetOrigin()).Length()
		return distance >= FlashlightSettings.too_far_distance
	}

	function CalculateAngleToTarget(witch, survivor)
	{
		local witchPos = witch.GetOrigin()
		local targetPos = survivor.GetOrigin()
		local direction = targetPos - witchPos
		local angleR = atan2(direction.y, direction.x)
		local angleD = angleR * (180.0 / PI)
		local angleN = angleD % 360.0
		if (angleN < 0)
			angleN = angleN + 360.0
		return angleN
	}

	function IsWalkNoise(survivor, witch)
	{
		local dist = (witch.GetOrigin() - survivor.GetOrigin()).Length()
		if (dist > FlashlightSettings.walk_noise_range)
			return false

		local vel = survivor.GetLocalVelocity()
		local threshold = FlashlightSettings.walk_velocity_threshold

		if (vel.x > threshold || vel.x < -threshold ||
		    vel.y > threshold || vel.y < -threshold ||
		    vel.z > (threshold * 1.875) || vel.z < -(threshold * 1.875))
		{
			return true
		}
		return false
	}

	// ============================================================
	// TURN ANIMATIONS (from xenorvya_witch_turn_behavior.nut)
	// ============================================================
	function StartTurnLoop(witch)
	{
		local scope = GetWitchScope(witch)
		if (!scope) return

		if (scope.ws_turnLoopRunning)
			return

		scope.ws_turnLoopRunning <- true

		local delay = 3.0 + RandomFloat(0.0, 27.0)  // 3-30 seconds
		MaoLib.AddTimer("witch_turn_" + witch.entindex(), delay, function() {
			::WitchSystem.TryTurnAnim(witch)
		})
	}

	function TryTurnAnim(witch)
	{
		if (!witch || !witch.IsValid() || witch.GetHealth() <= 0)
			return

		local scope = GetWitchScope(witch)
		if (!scope) return

		// Don't turn while in active states
		if (scope.ws_state != STATE_IDLE)
			return

		// Don't turn if already turning
		if (scope.ws_turnActive)
			return

		// Don't turn if enraged
		if (NetProps.GetPropFloat(witch, "m_rage") > 0.0)
		{
			ScheduleNextTurn(witch)
			return
		}

		// Only turn while in crying animation
		local seq = witch.GetSequence()
		if (seq != CRYING_ANIM)
		{
			ScheduleNextTurn(witch)
			return
		}

		// Pick random turn animation
		local turnAnim = TURN_ANIMS[RandomInt(0, TURN_ANIMS.len() - 1)]

		scope.ws_turnActive    <- true
		scope.ws_lastTurnAnim  <- turnAnim
		scope.ws_turnStartTime <- Time()

		witch.SetSequence(turnAnim)

		local animDuration = witch.GetSequenceDuration(turnAnim)
		if (animDuration <= 0.0)
			animDuration = 1.5

		// Schedule finish
		MaoLib.AddTimer("witch_turn_finish_" + witch.entindex(), animDuration, function() {
			::WitchSystem.FinishTurnAnim(witch)
		})

		// Poll for rage interrupt during turn
		MaoLib.AddTimer("witch_turn_poll_" + witch.entindex(), 0.1, function() {
			::WitchSystem.PollTurnInterrupt(witch)
		})
	}

	function PollTurnInterrupt(witch)
	{
		if (!witch || !witch.IsValid() || witch.GetHealth() <= 0)
			return

		local scope = GetWitchScope(witch)
		if (!scope || !scope.ws_turnActive || scope.ws_state != STATE_IDLE)
			return

		local rage = NetProps.GetPropFloat(witch, "m_rage")
		if (rage <= 0.0)
		{
			// Keep polling
			MaoLib.AddTimer("witch_turn_poll_" + witch.entindex(), 0.1, function() {
				::WitchSystem.PollTurnInterrupt(witch)
			})
			return
		}

		// Rage interrupted the turn! Apply partial yaw offset
		local lastAnim = scope.ws_lastTurnAnim
		local elapsed  = Time() - scope.ws_turnStartTime

		if (lastAnim == TURN_180)
		{
			local yawOffset = 0.0
			foreach (stage in Turn180InterruptStages)
			{
				if (elapsed >= stage[0])
				{
					yawOffset = stage[1]
					break
				}
			}
			if (yawOffset != 0.0)
			{
				local currentAngles = witch.GetAngles()
				local newYaw = (currentAngles.y + yawOffset) % 360.0
				if (newYaw > 180.0)  newYaw -= 360.0
				if (newYaw < -180.0) newYaw += 360.0
				witch.SetAngles(QAngle(currentAngles.x, newYaw, currentAngles.z))
			}
		}
		else
		{
			local threshold = 0.75
			if (elapsed >= threshold)
			{
				local animKey = "" + lastAnim
				if (animKey in TurnYawOffset)
				{
					local halfOffset = TurnYawOffset[animKey] * 0.5
					local currentAngles = witch.GetAngles()
					local newYaw = (currentAngles.y + halfOffset) % 360.0
					if (newYaw > 180.0)  newYaw -= 360.0
					if (newYaw < -180.0) newYaw += 360.0
					witch.SetAngles(QAngle(currentAngles.x, newYaw, currentAngles.z))
				}
			}
		}

		// Mark handled
		scope.ws_turnActive    <- false
		scope.ws_lastTurnAnim  <- -1
		scope.ws_turnStartTime <- -1.0
	}

	function FinishTurnAnim(witch)
	{
		if (!witch || !witch.IsValid() || witch.GetHealth() <= 0)
			return

		local scope = GetWitchScope(witch)
		if (!scope || !scope.ws_turnActive)
			return

		// Apply full yaw offset based on animation
		local lastAnim = scope.ws_lastTurnAnim
		local animKey = "" + lastAnim

		if (lastAnim != -1 && animKey in TurnYawOffset)
		{
			local currentAngles = witch.GetAngles()
			local yawOffset = TurnYawOffset[animKey]
			local newYaw = (currentAngles.y + yawOffset) % 360.0
			if (newYaw > 180.0)  newYaw -= 360.0
			if (newYaw < -180.0) newYaw += 360.0
			witch.SetAngles(QAngle(currentAngles.x, newYaw, currentAngles.z))
		}

		scope.ws_turnActive   <- false
		scope.ws_lastTurnAnim <- -1

		// Return to crying anim
		local seq = witch.GetSequence()
		local isTurnAnim = false
		foreach (a in TURN_ANIMS)
		{
			if (seq == a) { isTurnAnim = true; break }
		}
		if (seq == CRYING_ANIM || isTurnAnim)
			witch.SetSequence(CRYING_ANIM)

		// Schedule next turn
		ScheduleNextTurn(witch)
	}

	function ScheduleNextTurn(witch)
	{
		if (!witch || !witch.IsValid() || witch.GetHealth() <= 0)
			return

		local scope = GetWitchScope(witch)
		if (!scope) return

		local delay = 3.0 + RandomFloat(0.0, 27.0)
		MaoLib.AddTimer("witch_turn_" + witch.entindex(), delay, function() {
			::WitchSystem.TryTurnAnim(witch)
		})
	}

	// ============================================================
	// ALERT TURNING (sensible_witch - gradual turn toward threat)
	// ============================================================
	function AlertTurnTick(witch, scope)
	{
		if (scope.ws_alertAng == null || scope.ws_alertTurns == null)
			return

		if (scope.ws_alertTurns > 0)
		{
			scope.ws_alertTurns -= 1

			local localAng = witch.GetAngles()
			local desiredAngle = scope.ws_alertAng
			local diffAngle = desiredAngle - localAng.y

			if (diffAngle > 180)  diffAngle -= 360
			if (diffAngle < -180) diffAngle += 360

			if (diffAngle > FlashlightSettings.alert_turn_threshold)
			{
				local newAngle = localAng.y + FlashlightSettings.alert_turn_angle
				witch.SetAngles(QAngle(localAng.x, newAngle, localAng.z))
				Dbg("Alert turn LEFT toward threat")
			}
			else if (diffAngle < -FlashlightSettings.alert_turn_threshold)
			{
				local newAngle = localAng.y - FlashlightSettings.alert_turn_angle
				witch.SetAngles(QAngle(localAng.x, newAngle, localAng.z))
				Dbg("Alert turn RIGHT toward threat")
			}
		}
		else if (scope.ws_alertTurns < 1 && (Time() - scope.ws_alertTime) >= 30 && NetProps.GetPropFloat(witch, "m_rage") == 0)
		{
			// Calm down after 30 seconds without rage
			NetProps.SetPropEntity(witch, "m_clientLookatTarget", null)
			scope.ws_alertTurns <- null
			scope.ws_stress <- 0
			Dbg("Witch calming down - no rage accumulated")
		}
	}

	// ============================================================
	// WITCH AGGRESSION STATE MACHINE
	// ============================================================
	function ProcessWitchTick(witch)
	{
		// Self-reschedule: si witch muere, no se reschedulea más
		if (!witch || !witch.IsValid() || witch.GetHealth() <= 0)
			return

		local scope = GetWitchScope(witch)
		if (!scope || !scope.ws_monitorActive)
			return

		local rage = NetProps.GetPropFloat(witch, "m_rage")
		local target = NetProps.GetPropEntity(witch, "m_clientLookatTarget")
		local witchpos = witch.GetOrigin()
		local radius = FlashlightSettings.sight_range

		// ============================================================
		// FLASHLIGHT + NOISE DETECTION (always active)
		// ============================================================
		for (local survivor = null; survivor = Entities.FindByClassnameWithin(survivor, "player", witchpos, radius);)
		{
			if (!survivor.IsSurvivor() || survivor.IsDead())
				continue

			local isFlashing = IsFlashlightOn(survivor) && IsForward(survivor, witch)
			local isWalking = IsWalkNoise(survivor, witch)

			if (isFlashing || isWalking)
			{
				// OPTIMIZED: Calculate LOS once and reuse
				local hasLOS = HasLineOfSight(witch, survivor)
				
				// Flashlight must have LOS; walk noise also requires LOS (fix: no wall-hearing)
				if (!hasLOS)
					continue

				if (scope.ws_state == STATE_IDLE)
				{
					// Enter alert state
					scope.ws_state <- STATE_ALERT

					// Set alert angle for turning
					if (scope.ws_alertTime == 0 || scope.ws_alertTime <= (Time() - FlashlightSettings.weapon_cooldown_alert))
					{
						scope.ws_alertTime  <- Time()
						scope.ws_alertTurns <- FlashlightSettings.alert_turns
					}
					scope.ws_alertAng <- CalculateAngleToTarget(witch, survivor)
					scope.ws_alertZone <- survivor.GetOrigin()

					// Add rage directly via NetProps
					local addRage = isFlashing ? FlashlightSettings.alert_anger_per_tick : FlashlightSettings.walk_anger
					NetProps.SetPropFloat(witch, "m_rage", MaoLib.min(rage + addRage, 1.0))

					// Set lookat target
					NetProps.SetPropEntity(witch, "m_clientLookatTarget", survivor)

					Dbg("Witch alerted by " + (isFlashing ? "FLASHLIGHT" : "WALK NOISE") + " from " + survivor + " (rage=" + NetProps.GetPropFloat(witch, "m_rage") + ")")
				}
				else if (scope.ws_state == STATE_ALERT || scope.ws_state == STATE_IDLE)
				{
					// Add rage while being watched
					local addRage = isFlashing ? FlashlightSettings.alert_anger_per_tick : FlashlightSettings.walk_anger
					NetProps.SetPropFloat(witch, "m_rage", MaoLib.min(rage + addRage, 1.0))

					if (target != survivor)
						NetProps.SetPropEntity(witch, "m_clientLookatTarget", survivor)
				}
			}
		}

		// ============================================================
		// STATE MACHINE
		// ============================================================
		if (scope.ws_state == STATE_IDLE)
		{
			// Check if rage from other sources (props, weapons) triggered alert
			if (rage > 0 && target != null)
			{
				scope.ws_state <- STATE_ALERT
				scope.ws_alertAng <- CalculateAngleToTarget(witch, target)
				scope.ws_alertTurns <- FlashlightSettings.alert_turns
				scope.ws_alertTime <- Time()
			}
		}
		else if (scope.ws_state == STATE_ALERT)
		{
			// Gradual turn toward threat
			AlertTurnTick(witch, scope)

			// Check if enraged enough to attack
			if (rage >= 1.0 && target != null)
			{
				scope.ws_state  <- STATE_ENRAGED
				scope.ws_target <- target
				scope.ws_focus  <- FlashlightSettings.focus_max
				scope.ws_stress <- 0

				// Trigger attack
				DoEntFire("!self", "RunScriptCode", "self.TakeDamage(0, 0, " + target.entindex() + ")", 0, null, witch)
				Dbg("Witch ENRAGED by " + target)
			}

			// Check alert cooldown - calm down if no rage
			if (rage == 0 && target == null && scope.ws_alertTurns != null && scope.ws_alertTurns <= 0)
			{
				if (Time() - scope.ws_alertTime >= 30)
				{
					scope.ws_state <- STATE_IDLE
					scope.ws_alertTurns <- null
					Dbg("Witch returning to idle (alert expired)")
				}
			}
		}
		else if (scope.ws_state == STATE_ENRAGED)
		{
			local currentTarget = scope.ws_target
			if (currentTarget == null || !currentTarget.IsValid() || currentTarget.IsDead())
			{
				// Target is dead/invalid - find new target or retreat
				scope.ws_state <- STATE_PRERETREAT
				scope.ws_target <- null
				scope.ws_focus  <- -1
				scope.ws_wait   <- 0
				Dbg("Witch lost target - entering pre-retreat")
			}
			else if (!HasLineOfSight(witch, currentTarget) || IsTooFar(currentTarget, witch))
			{
				// Can't see target - lose focus gradually
				if (scope.ws_focus > 0)
				{
					scope.ws_focus -= 1
					if (HasLineOfSight(witch, currentTarget))
						scope.ws_focus = MaoLib.min(scope.ws_focus + 1, FlashlightSettings.focus_max)
				}
				else
				{
					// Try to find a new target nearby
					local newTarget = null
					for (local t = null; t = Entities.FindByClassnameWithin(t, "player", witchpos, radius);)
					{
						if (t.IsSurvivor() && !t.IsDead() && HasLineOfSight(witch, t))
						{
							newTarget = t
							break
						}
					}
					if (newTarget != null)
					{
						scope.ws_target <- newTarget
						scope.ws_focus  <- FlashlightSettings.focus_max
						NetProps.SetPropEntity(witch, "m_clientLookatTarget", newTarget)
						DoEntFire("!self", "RunScriptCode", "self.TakeDamage(0, 0, " + newTarget.entindex() + ")", 0, null, witch)
						Dbg("Witch retargeted to " + newTarget)
					}
					else
					{
						scope.ws_state <- STATE_PRERETREAT
						scope.ws_focus <- -1
						scope.ws_wait  <- 0
						Dbg("Witch found no new target - pre-retreat")
					}
				}
			}
			else
			{
				// Has LOS - maintain focus
				scope.ws_focus = MaoLib.min(scope.ws_focus + 1, FlashlightSettings.focus_max)
			}
		}
		else if (scope.ws_state == STATE_PRERETREAT)
		{
			if (scope.ws_wait < FlashlightSettings.retreat_wait)
			{
				scope.ws_wait += 1

				// Check if original target came back
				if (scope.ws_target != null && scope.ws_target.IsValid() && !scope.ws_target.IsDead())
				{
					local dist = (scope.ws_target.GetOrigin() - witchpos).Length()
					if (dist <= radius && HasLineOfSight(witch, scope.ws_target))
					{
						scope.ws_state <- STATE_ENRAGED
						scope.ws_focus <- FlashlightSettings.focus_max
						NetProps.SetPropEntity(witch, "m_clientLookatTarget", scope.ws_target)
						DoEntFire("!self", "RunScriptCode", "self.TakeDamage(0, 0, " + scope.ws_target.entindex() + ")", 0, null, witch)
						Dbg("Witch re-acquired original target")
						return
					}
				}

				// Scan for any new target
				for (local t = null; t = Entities.FindByClassnameWithin(t, "player", witchpos, radius);)
				{
					if (t.IsSurvivor() && !t.IsDead() && HasLineOfSight(witch, t))
					{
						scope.ws_state <- STATE_ENRAGED
						scope.ws_target <- t
						scope.ws_focus  <- FlashlightSettings.focus_max
						NetProps.SetPropEntity(witch, "m_clientLookatTarget", t)
						DoEntFire("!self", "RunScriptCode", "self.TakeDamage(0, 0, " + t.entindex() + ")", 0, null, witch)
						Dbg("Witch found new target in pre-retreat: " + t)
						return
					}
				}
			}
			else
			{
				// Retreat - clear target and go back to idle
				NetProps.SetPropEntity(witch, "m_clientLookatTarget", null)
				NetProps.SetPropFloat(witch, "m_rage", 0.0)
				scope.ws_target    <- null
				scope.ws_state     <- STATE_IDLE
				scope.ws_alertAng  <- null
				scope.ws_alertTurns <- null
				scope.ws_stress    <- 0
				Dbg("Witch retreating - returning to idle")
			}
		}
		else if (scope.ws_state == STATE_RETREAT)
		{
			// Check for intruders during retreat
			for (local t = null; t = Entities.FindByClassnameWithin(t, "player", witchpos, 400);)
			{
				if (t.IsSurvivor() && !t.IsDead() && HasLineOfSight(witch, t))
				{
					scope.ws_state <- STATE_ENRAGED
					scope.ws_target <- t
					scope.ws_focus  <- FlashlightSettings.focus_max
					NetProps.SetPropEntity(witch, "m_clientLookatTarget", t)
					DoEntFire("!self", "RunScriptCode", "self.TakeDamage(0, 0, " + t.entindex() + ")", 0, null, witch)
					Dbg("Witch found obstructer during retreat: " + t)
					return
				}
			}
		}

		// Reschedule next tick (witch still alive)
		if (scope.ws_monitorActive)
		{
			MaoLib.AddTimer("witch_behavior_" + witch.entindex(), 0.5, function() {
				::WitchSystem.ProcessWitchTick(witch)
			})
		}
	}

	// ============================================================
	// WITCH SPAWN
	// ============================================================
	function OnGameEvent_witch_spawn(params)
	{
		if (!("witchid" in params) || !params.witchid)
			return

		Dbg("ENTER witch_spawn")

		local witch = EntIndexToHScript(params.witchid)
		if (!witch || !witch.IsValid())
			return

		local witch_origin = witch.GetOrigin()

		// Initialize witch scope with state machine
		InitWitchScope(witch)

		// Spawn relocation
		if (IsTooCloseToMainPath(witch, witch_origin) && RandomInt(1, SpawnSettings.RelocateChance) == 1)
		{
			local new_spawn = FindNewSpawn(witch_origin, SpawnSettings.PotentialNewSpotRadius)
			if (new_spawn != 0)
			{
				witch.SetOrigin(new_spawn)
				Dbg("Witch relocated (nearby)")
			}
			else
			{
				Dbg("No nearby spot found, trying far...")
				new_spawn = FindNewSpawn(witch_origin, SpawnSettings.PotentialNewFarSpotRadius)
				if (new_spawn != 0)
				{
					witch.SetOrigin(new_spawn)
					Dbg("Witch relocated (far)")
				}
				else
					DbgWarn("Failed to find any valid spawn")
			}
		}

		// Start the witch behavior monitor
		StartWitchMonitor(witch)

		// Start turn animations
		StartTurnLoop(witch)

		Dbg("EXIT witch_spawn - witch initialized with full AI")
	}

	function StartWitchMonitor(witch)
	{
		if (!witch || !witch.IsValid())
			return

		local idx = witch.entindex()

		// Use MaoLib.AddTimer with closure wrapper to avoid method detachment
		MaoLib.AddTimer("witch_behavior_" + idx, 0.5, function() {
			::WitchSystem.ProcessWitchTick(witch)
		})
	}

	// ============================================================
	// WEAPON FIRE SENSITIVITY (sensible_witch)
	// ============================================================
	function OnGameEvent_weapon_fire(params)
	{
		if (!("weapon" in params) || !("userid" in params))
			return

		local player = GetPlayerFromUserID(params.userid)
		if (!player || !player.IsSurvivor() || player.IsDead())
			return

		local usedWeapon = params.weapon
		local bulletCount = "count" in params ? params.count : 1

		// Check if weapon is in our sensitivity table
		if (!(usedWeapon in WeaponRanges))
			return

		local weaponData = WeaponRanges[usedWeapon]
		local searchRadius = weaponData[1]  // Max radius
		local angerValue  = weaponData[2]   // Anger per shot

		// Apply bullet count multiplier for shotguns
		local angerMult = 1.0
		if (usedWeapon == "pumpshotgun" || usedWeapon == "shotgun_chrome" ||
		    usedWeapon == "autoshotgun" || usedWeapon == "shotgun_spas")
		{
			angerMult = bulletCount.tofloat()
		}

		for (local witch = null; witch = Entities.FindByClassnameWithin(witch, "witch", player.GetOrigin(), searchRadius);)
		{
			if (!witch.IsValid() || witch.GetHealth() <= 0)
				continue

			local scope = GetWitchScope(witch)
			if (!scope) continue

			// Add rage based on distance
			local dist = (player.GetOrigin() - witch.GetOrigin()).Length()
			local rageAdd = angerValue * angerMult
			local currentRage = NetProps.GetPropFloat(witch, "m_rage")
			NetProps.SetPropFloat(witch, "m_rage", MaoLib.min(currentRage + rageAdd, 1.0))

			// Alert if not already
			if (scope.ws_state == STATE_IDLE)
			{
				if (HasLineOfSight(witch, player))
				{
					if (scope.ws_alertTime <= (Time() - FlashlightSettings.weapon_cooldown_alert))
					{
						scope.ws_alertTime  <- Time()
						scope.ws_alertTurns <- FlashlightSettings.alert_turns
					}
					scope.ws_alertAng <- CalculateAngleToTarget(witch, player)
					scope.ws_alertZone <- player.GetOrigin()
					scope.ws_state <- STATE_ALERT

					if (NetProps.GetPropEntity(witch, "m_clientLookatTarget") != player)
						NetProps.SetPropEntity(witch, "m_clientLookatTarget", player)
				}
			}

			Dbg("Weapon fire " + usedWeapon + " -> witch rage +" + rageAdd + " (total=" + NetProps.GetPropFloat(witch, "m_rage") + ")")
		}
	}

	// ============================================================
	// WITCH HARASSER SET (horde trigger + state sync)
	// ============================================================
	function OnGameEvent_witch_harasser_set(event)
	{
		local witch = EntIndexToHScript(event.witchid)
		local player = GetPlayerFromUserID(event.userid)

		if (!witch || !player)
			return

		Dbg("Witch harasser set: " + player)

		// Sync state
		local scope = GetWitchScope(witch)
		if (scope)
		{
			scope.ws_state <- STATE_ENRAGED
			scope.ws_target <- player
			scope.ws_focus  <- FlashlightSettings.focus_max
			NetProps.SetPropEntity(witch, "m_clientLookatTarget", player)
		}

		// Trigger panic event
		local director = Entities.FindByClassname(null, "info_director")
		if (director)
			DoEntFire("!self", "ForcePanicEvent", "", 0, null, director)

		RushVictim(player, 10000)

		Dbg("Horde triggered by witch startle")
	}

	// ============================================================
	// INFECTED HURT - witch retreat interrupted
	// ============================================================
	function OnGameEvent_infected_hurt(params)
	{
		if (!GetPlayerFromUserID(params.attacker))
			return
		if (!EntIndexToHScript(params.entityid))
			return

		local attacker = GetPlayerFromUserID(params.attacker)
		local entityid = EntIndexToHScript(params.entityid)

		if (!entityid.GetModelName())
			return

		local model = entityid.GetModelName()
		if (model != "models/infected/witch.mdl" && model != "models/infected/witch_bride.mdl")
			return

		local witch = entityid
		local scope = GetWitchScope(witch)
		if (!scope) return

		if (scope.ws_state == STATE_RETREAT && (attacker.GetOrigin() - witch.GetOrigin()).Length() <= 900)
		{
			scope.ws_state <- STATE_ENRAGED
			scope.ws_target <- attacker
			scope.ws_focus  <- FlashlightSettings.focus_max
			NetProps.SetPropEntity(witch, "m_clientLookatTarget", attacker)

			if (witch.GetHealth() > 0)
			{
				CommandABot({ bot = witch, cmd = 3 })
				DoEntFire("!self", "RunScriptCode", "self.TakeDamage(0, 0, " + attacker.entindex() + ")", 0, null, witch)
				Dbg("Witch attacked during retreat - re-engaging " + attacker)
			}
		}
	}

	// ============================================================
	// PLAYER DEATH - clean up witch target
	// ============================================================
	function OnGameEvent_player_death(params)
	{
		if (!("userid" in params) || params.userid == null)
			return

		local body = GetPlayerFromUserID(params.userid)
		if (!body || !body.IsSurvivor())
			return

		for (local witch = null; witch = Entities.FindByClassname(witch, "witch");)
		{
			if (!witch || !witch.IsValid())
				continue

			local scope = GetWitchScope(witch)
			if (!scope) continue

			if (scope.ws_state == STATE_ENRAGED && scope.ws_target == body)
			{
				Dbg("Witch target died: " + body)
				scope.ws_target <- null
				scope.ws_focus  <- -1
				scope.ws_state  <- STATE_PRERETREAT
				scope.ws_wait   <- 0
			}
		}
	}

	// ============================================================
	// SPAWN RELOCATION HELPERS
	// ============================================================
	function FindNewSpawn(witch_origin, radius)
	{
		local potential_spots = []
		local extendedRadius = radius + SpawnSettings.TooCloseRadius
		local all_areas = {}
		NavMesh.GetNavAreasInRadius(witch_origin, extendedRadius, all_areas)

		local candidates = []
		local blockers = []

		foreach (key, area in all_areas)
		{
			if (area.HasSpawnAttributes(131072))
				blockers.append(area)
			else if (area.IsSpawningAllowed() && !area.IsUnderwater() &&
			         !area.HasSpawnAttributes(2) && !area.HasSpawnAttributes(8192))
				candidates.append(area)
		}

		if (blockers.len() == 0)
		{
			candidates = candidates
		}
		else
		{
			local tooClose = SpawnSettings.TooCloseRadius
			local valid = []
			foreach (candidate in candidates)
			{
				local cPos = candidate.GetCenter()
				local isBlocked = false
				foreach (blocker in blockers)
				{
					local bPos = blocker.GetCenter()
					local dist = (cPos - bPos).Length()
					if (dist <= tooClose)
					{
						isBlocked = true
						break
					}
				}
				if (!isBlocked)
					valid.append(candidate)
			}
			candidates = valid
		}

		foreach (candidate in candidates)
		{
			local cPos = candidate.GetCenter()
			if ((cPos - witch_origin).Length() <= radius)
				potential_spots.append(candidate)
		}

		if (potential_spots.len() > 0)
		{
			local spawn_spot = potential_spots[RandomInt(0, potential_spots.len() - 1)]
			return spawn_spot.FindRandomSpot()
		}
		return 0
	}

	function IsTooCloseToMainPath(witch, witch_origin)
	{
		local witch_model = witch.GetModelName()

		if (witch_model == "models/infected/witch_bride.mdl" && SpawnSettings.AllowBrideRelocation == 0)
			return false

		if (SpawnSettings.AllowWanderingRelocation == 0)
		{
			try {
				local isWandering = NetProps.GetPropInt(witch, "m_bIsWandering")
				if (isWandering)
					return false
			} catch(e) { }
		}

		local witch_table = {}
		NavMesh.GetNavAreasInRadius(witch_origin, SpawnSettings.TooCloseRadius, witch_table)

		foreach (key, area in witch_table)
		{
			if (area.HasSpawnAttributes(131072))
				return true
		}

		return false
	}

	function ParseSpawnSettings()
	{
		local SettingsFileName = "witches_spawn_off_path/Settings.cfg"
		local file = FileToString(SettingsFileName)

		local function SerializeSettings()
		{
			local sData = "{"
			foreach (key, val in SpawnSettings)
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
			StringToFile(SettingsFileName, sData)
		}

		if (file)
		{
			try
			{
				local tData = MaoLib.ParseConfigString(file)
				local hasMissingKey = false
				foreach (key, val in SpawnSettings)
				{
					if (key in tData)
						SpawnSettings[key] = tData[key]
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

	// ============================================================
	// PROP ANGER (from witchprops.nut, original)
	// ============================================================
	function OnGameEvent_weapon_drop(opts)
	{
		if (!("item" in opts) || opts.item != "gascan")
			return
		StartPropMonitor(opts)
	}

	function OnGameEvent_weapon_drop_to_prop(opts)
	{
		StartPropMonitor(opts)
	}

	function StartPropMonitor(opts)
	{
		if (!MaoLib.AllPresent(opts, "userid", "propid"))
			return

		local player = GetPlayerFromUserID(opts.userid)
		if (!MaoLib.IsReal(player))
			return

		local prop = EntIndexToHScript(opts.propid)
		if (!MaoLib.IsReal(prop))
			return

		local timerName = "witchprops_" + prop.GetEntityIndex()
		local throwTime = Time()
		MaoLib.AddTimer(timerName, PropSettings.check_timer, function() {
			::WitchSystem.MonitorProp(timerName, prop, player, throwTime);
		})
	}

	function MonitorProp(timerName, witchprops_prop, witchprops_thrower, witchprops_throwtime)
	{
		if (!MaoLib.IsReal(witchprops_prop) ||
		    (witchprops_prop.GetClassname() == "weapon_gascan" && witchprops_prop.GetOwnerEntity()) ||
		    !MaoLib.IsReal(witchprops_thrower) ||
		    !MaoLib.IsAlive(witchprops_thrower) ||
		    Time() > witchprops_throwtime + PropSettings.time)
		{
			MaoLib.RemoveTimer(timerName)
			return
		}

		local vel = GetPhysVelocity(witchprops_prop).Length()
		if (vel < PropSettings.velocity)
			return

		foreach (witch in MaoLib.YieldWitches())
		{
			local distance = MaoLib.DistanceBetween(witchprops_prop.GetCenter(), witch.GetCenter())

			if (distance > PropSettings.distance)
				continue

			if (!HasPropLOS(witchprops_prop, witch))
				continue

			if (MaoLib.GetWitchAnger(witch) >= 1.0)
				continue

			if (!MaoLib.GetTargetMisc(witch))
				MaoLib.ForceTarget(witch, witchprops_thrower)

			CommandABot({ bot = witch, cmd = 0  /* BOT_CMD_ATTACK */, target = witchprops_thrower })

			local add = (1.0 - (distance / PropSettings.distance)) * PropSettings.multiplier
			if (distance <= PropSettings.brush_distance)
				add += PropSettings.brush_bonus

			local maxvalue = PropSettings.max_anger
			if (PropSettings.max_anger == -1)
				maxvalue = 1.0

			MaoLib.SetWitchAnger(witch, MaoLib.min(MaoLib.GetWitchAnger(witch) + add, maxvalue))

			if (MaoLib.GetWitchAnger(witch) >= 1.0)
				CommandABot({ bot = witch, cmd = 0  /* BOT_CMD_ATTACK */, target = witchprops_thrower })

			Dbg("Prop angered witch: +" + add + " rage")
		}
	}

	function HasPropLOS(prop, witch)
	{
		local line = {
			start = prop.GetCenter(),
			end = witch.GetCenter(),
			ignore = prop,
			enthit = null,
		}
		TraceLine(line)
		return (line.enthit == witch)
	}

	// ============================================================
	// FLASHLIGHT CONFIG (legacy - CVar based, keep for compatibility)
	// ============================================================
	function GenerateFlashlightConfig()
	{
		local DefaultToggleFile = ""
		local lines = [
			"// How the mod works: Witches have CVars controlling anger.",
			"anger_rate 0.25",
			"personal_space 500",
			"sight_and_sound 950",
			"threat_range 1050",
			"flashlight_range 1250",
		]

		foreach (line in lines)
			DefaultToggleFile += line + "\n"

		if (!FileToString("flashlight_witches_v2/settings.txt"))
		{
			StringToFile("flashlight_witches_v2/settings.txt", DefaultToggleFile)
			Dbg("Generated flashlight config")
		}
	}

	function LoadFlashlightConfig(filename)
	{
		local files = FileToString(filename)
		if (!files)
			return

		local toggles = split(files, "\r\n")
		foreach (toggle in toggles)
		{
			if (!toggle || toggle == "")
				continue

			toggle = strip(toggle)
			local idx = toggle.find(" ")
			if (idx == null)
				continue

			local togglecommand = toggle.slice(0, idx)
			local togglevalue = toggle.slice(idx + 1)

			switch (togglecommand)
			{
				case "anger_rate":
					FlashlightSettings.alert_anger_per_tick = togglevalue.tofloat()
					break
				case "sight_and_sound":
					FlashlightSettings.sight_range = togglevalue.tointeger()
					break
			}
		}
		Dbg("Flashlight config loaded")
	}

	// ============================================================
	// PLAYER/BOT REPLACEMENT - Fix thrower references
	// ============================================================
	function OnGameEvent_bot_player_replace(params)
	{
		local player = GetPlayerFromUserID(params.player)
		local bot = GetPlayerFromUserID(params.bot)
		FixThrower(bot, player)
	}

	function OnGameEvent_player_bot_replace(params)
	{
		local player = GetPlayerFromUserID(params.player)
		local bot = GetPlayerFromUserID(params.bot)
		FixThrower(player, bot)
	}

	function FixThrower(fromPlayer, toPlayer)
	{
		local classnameList = ["molotov_projectile", "pipe_bomb_projectile", "vomitjar_projectile", "inferno", "fire_cracker_blast"]
		local targetpropList = ["m_hThrower", "m_hThrower", "m_hThrower", "m_hOwnerEntity", "m_hOwnerEntity"]

		for (local i = 0; i < 5; i++)
		{
			for (local ent = null; (ent = Entities.FindByClassname(ent, classnameList[i])) != null && ent.IsValid();)
			{
				if (NetProps.GetPropEntity(ent, targetpropList[i]) == fromPlayer)
					NetProps.SetPropEntity(ent, targetpropList[i], toPlayer)
			}
		}
	}
}

// ================================================================
// REGISTER CALLBACKS
// ================================================================
__CollectGameEventCallbacks(WitchSystem)

// Load spawn settings immediately
WitchSystem.ParseSpawnSettings()

printl("[WitchSystem v3.0] Loaded - Full behavior: Spawn | Props | Flashlight | Weapons | TurnAnims | Horde")
