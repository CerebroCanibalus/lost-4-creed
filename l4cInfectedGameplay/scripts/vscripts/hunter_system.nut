// ================================================================
// HUNTER SYSTEM - L4D2 Hunter Mechanics
// ================================================================
// Replaces: hunter_lead.nut, hunter_jump.nut, hunter_pounce.nut
//
// Features:
// - Lead Prediction: Bot hunters predict survivor movement
// - Pounce Damage: Bonus damage on successful pounce
// - Critical Pounce: Extra damage from high-altitude pounces
// - Air Melee Bonus: Swipe damage when hunter is airborne
// - Flee Speed: Speed boost after successful pounce
// ================================================================

::HunterSystem <-
{
	// ============================================================
	// CONFIGURATION
	// ============================================================
	Debug = 1

	Settings =
	{
		// Lead prediction
		LeadUpdateInterval = 0.1,

		// Pounce damage
		PounceBonusDamage = 10,

		// Critical pounce (high altitude)
		CriticalPounceMinHeight = 300,    // Minimum drop height for crit
		CriticalPounceDamage = 20,        // Bonus damage on crit

		// Air melee bonus
		AirSwipeDamage = 8,
		AirSwipeStagger = true,

		// Flee speed after pounce
		FleeSpeedMult = 1.4,
		FleeDuration = 2.0,
	}

	// State tracking
	ActiveMonitors = {},          // hunter -> monitor name for lead

	// Constants
	ZOMBIE_HUNTER = 3,

	// ============================================================
	// DEBUG
	// ============================================================
	function Dbg(msg)
	{
		if (Debug) printl("[HunterSystem][DEBUG] " + msg)
	}

	function DbgWarn(msg)
	{
		printl("[HunterSystem][WARN] " + msg)
	}

	// ============================================================
	// INITIALIZATION
	// ============================================================
	function Init()
	{
		ActiveMonitors.clear()
		Dbg("Init() called — monitors cleared")
	}

	// ============================================================
	// EVENT HANDLERS
	// ============================================================
	function OnGameEvent_round_start(params)
	{
		Dbg("ENTER round_start")
		Init()
		Dbg("EXIT round_start")
	}

	function OnGameEvent_round_end(params)
	{
		Dbg("ENTER round_end")
		Init()
		Dbg("EXIT round_end")
	}

	function OnGameEvent_mission_lost(params)
	{
		Dbg("ENTER mission_lost")
		Init()
		Dbg("EXIT mission_lost")
	}

	function OnGameEvent_player_spawn(params)
	{
		if (!("userid" in params))
			return

		local player = GetPlayerFromUserID(params.userid)
		if (!player || !player.IsValid())
			return

		// Only for bot hunters — add lead monitor
		if (player.GetZombieType() == ZOMBIE_HUNTER && IsPlayerABot(player))
		{
			Dbg("Bot hunter spawned, adding lead monitor — userid=" + params.userid)
			AddLeadMonitor(player)
		}
	}

	function OnGameEvent_player_death(params)
	{
		if (!("userid" in params))
			return

		local player = GetPlayerFromUserID(params.userid)
		if (!player || !player.IsValid())
			return

		local key = player.GetEntityIndex().tostring()

		// Remove lead timer if exists
		if (key in ActiveMonitors)
		{
			Dbg("Removing lead monitor for dead hunter — entidx=" + key)
			MaoLib.RemoveTimer(ActiveMonitors[key])
			delete ActiveMonitors[key]
		}
	}

	function OnGameEvent_ability_use(params)
	{
		if (!("ability" in params) || params.ability != "ability_lunge")
			return
		if (!("userid" in params))
			return

		local hunter = GetPlayerFromUserID(params.userid)
		if (!hunter || !hunter.IsValid())
			return

		// Store starting Z position for critical pounce calculation
		local startZ = hunter.GetOrigin().z
		MaoLib.PlayerState.Set(params.userid, "hunter_pounce_start_z", startZ)
		Dbg("Ability lunge — startZ=" + startZ + " userid=" + params.userid)
	}

	// ============================================================
	// LEAD PREDICTION (for bot hunters)
	// ============================================================
	function AddLeadMonitor(hunter)
	{
		local key = hunter.GetEntityIndex().tostring()
		if (key in ActiveMonitors)
			return

		local timerName = "hunter_lead_" + key
		MaoLib.AddTimer(timerName, Settings.LeadUpdateInterval, function() { ::HunterSystem.LeadUpdate(hunter); })
		ActiveMonitors[key] <- timerName
		Dbg("Lead monitor added — entidx=" + key + " timer=" + timerName)
	}

	function LeadUpdate(hunter)
	{
		if (!MaoLib.IsReal(hunter) || !MaoLib.IsAlive(hunter) || hunter.IsSurvivor())
			return Settings.LeadUpdateInterval

		local target = MaoLib.GetTarget(hunter)
		if (!MaoLib.IsReal(target))
			return Settings.LeadUpdateInterval

		// Distance and time calculation
		local dist = MaoLib.DistanceBetween(target.EyePosition(), hunter.EyePosition())
		local time = dist / 600.0

		// Predict target position
		local dest = target.EyePosition() + (target.GetVelocity() * time)

		// Calculate aim angles
		local angles = CalculateAngles(dest - hunter.EyePosition())
		hunter.SnapEyeAngles(angles)

		return Settings.LeadUpdateInterval
	}

	function CalculateAngles(dest)
	{
		local yaw = 0
		local pitch = 0

		if (dest.y == 0 && dest.x == 0)
		{
			yaw = 0
			pitch = (dest.z > 0) ? 270 : 90
		}
		else
		{
			yaw = atan2(dest.y, dest.x) * 180 / PI
			if (yaw < 0)
				yaw += 360

			local tmp = sqrt(dest.x * dest.x + dest.y * dest.y)
			pitch = atan2(-dest.z, tmp) * 180 / PI
			if (pitch < 0)
				pitch += 360
		}

		return QAngle(pitch, yaw, 0)
	}

	// ============================================================
	// POUNCE DAMAGE + CRITICAL POUNCE + FLEE SPEED
	// ============================================================
	function OnGameEvent_lunge_pounce(params)
	{
		if (!("userid" in params) || !("victim" in params))
			return

		local hunter = GetPlayerFromUserID(params.userid)
		local prey = GetPlayerFromUserID(params.victim)

		if (!prey || !prey.IsSurvivor() || !hunter)
			return

		// 1. Base pounce bonus damage
		prey.TakeDamage(Settings.PounceBonusDamage, 129, hunter)
		Dbg("Pounce bonus damage — victim=" + params.victim + " dmg=" + Settings.PounceBonusDamage)

		// 2. Critical pounce (high altitude)
		local startZ = MaoLib.PlayerState.Get(params.userid, "hunter_pounce_start_z", 0)
		local endZ = hunter.GetOrigin().z
		local dropHeight = startZ - endZ

		if (dropHeight >= Settings.CriticalPounceMinHeight)
		{
			prey.TakeDamage(Settings.CriticalPounceDamage, 129, hunter)
			MaoLib.HUD.Notify(prey, "CRITICAL POUNCE!", { mode = "center", duration = 1.5, priority = "high" })
			MaoLib_VFX.ScreenShake(prey.GetOrigin(), 8, 15, 0.5, 300)
			Dbg("CRITICAL POUNCE — drop=" + dropHeight + " bonus=" + Settings.CriticalPounceDamage)
		}
		else
		{
			Dbg("Normal pounce — drop=" + dropHeight + " (crit min=" + Settings.CriticalPounceMinHeight + ")")
		}

		// 3. Mark as just pounced (prevents air-melee double-damage)
		MaoLib.PlayerState.Set(params.userid, "hunter_just_pounced", Time())

		// 4. Flee speed boost
		MaoLib.Modifiers.RegisterSpeed(hunter, Settings.FleeSpeedMult, Settings.FleeDuration, "hunter_flee")
		Dbg("Flee speed applied — mult=" + Settings.FleeSpeedMult + " dur=" + Settings.FleeDuration)

		// 5. Sound effects
		EmitSoundOn("HunterZombie.Pounce.Hit", hunter)
		if (!IsPlayerABot(prey))
		{
			EmitSoundOnClient("HunterZombie.Pounce.Hit", prey)
		}
	}

	// ============================================================
	// AIR MELEE BONUS
	// ============================================================
	function OnGameEvent_player_hurt(params)
	{
		if (!("userid" in params) || !("attacker" in params))
			return

		local victim = GetPlayerFromUserID(params.userid)
		local hunter = GetPlayerFromUserID(params.attacker)

		if (!victim || !victim.IsSurvivor() || !hunter)
			return
		if (hunter.GetZombieType() != ZOMBIE_HUNTER)
			return

		// Skip if this is immediate pounce damage (avoid double-dipping)
		local lastPounce = MaoLib.PlayerState.Get(params.attacker, "hunter_just_pounced", 0)
		if (Time() - lastPounce < 0.5)
			return

		// Must be airborne
		if (IsEntityOnGround(hunter))
			return

		// Air melee bonus: stagger + extra damage
		if (Settings.AirSwipeStagger)
			victim.Stagger(hunter.GetOrigin())

		victim.TakeDamage(Settings.AirSwipeDamage, 4, hunter)
		Dbg("Air melee bonus — victim=" + params.userid + " dmg=" + Settings.AirSwipeDamage)

		// Sound
		EmitSoundOn("HunterZombie.Pounce.Hit", hunter)
	}

	// ============================================================
	// UTILITY
	// ============================================================
	function IsEntityOnGround(who)
	{
		return NetProps.GetPropInt(who, "m_hGroundEntity") != -1
	}
}

// ================================================================
// REGISTER AND START
// ================================================================
::__CollectGameEventCallbacks(::HunterSystem)
::HunterSystem.Init()

printl("[HunterSystem] Loaded — Lead Prediction, Pounce Damage, Critical Pounce, Air Melee, Flee Speed")
