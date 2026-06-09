IncludeScript("maolib", getroottable())
IncludeScript("maolib_vfx", getroottable())

/*
 * ================================================================
 * SPITTER SYSTEM - Consolidated Spitter Mechanics
 * ================================================================
 * Replaces: spitter_destroy.nut, spitterslow.nut
 * 
 * Features:
 * - Acid Destruction: Spit destroys/ignites explosive props over time
 * - Survivor Slow: Players in spit are slowed with visual effects
 * ================================================================
 */

::SpitterSystem <-
{
	// ============================================================
	// CONFIGURATION
	// ============================================================
	Settings =
	{
		// Destruction timing (seconds in spit before destruction)
		GasCanDestroyTime = 3.0,
		PropaneDestroyTime = 2.0,
		OxygenDestroyTime = 2.5,
		ExplosiveBoxTime = 3.5,
		FuelBarrelTime = 4.0,
		
		// Slow effect
		SlowFriction = 2.5,       // 🔧 Aumentado de 1.85 → 2.5 (más penalizante)
		NormalFriction = 1.0,
		SlowDuration = 5.0,
		
		// Check interval
		CheckInterval = 1.0,
	}
	
	// Track props in spit
	PropsInSpit = {},
	
	// Track pending fly sound stop timers (uid → timerName)
	_FlySoundTimers = {},
	
	/** 0 = silencioso, 1 = verboso */
	Debug = 1
	
	function Dbg(msg) {
		if (Debug) printl("[SpitterSystem][DEBUG] " + msg)
	}
	
	// ============================================================
	// INITIALIZATION
	// ============================================================
	function OnGameEvent_round_start(params)
	{
		Dbg("round_start — clearing state")
		PropsInSpit.clear()
		// Cancel any pending fly sound stops
		_CancelAllFlySoundTimers()
		// Start checker timer
		MaoLib.AddTimer("spitter_check", Settings.CheckInterval, function() { SpitterSystem.CheckPropsInSpit(); })
	}
	
	function OnGameEvent_round_end(params)
	{
		Dbg("round_end — clearing state")
		MaoLib.RemoveTimer("spitter_check")
		PropsInSpit.clear()
		_CancelAllFlySoundTimers()
		// Stop flies sound on all survivors
		foreach (s in MaoLib.YieldSurvivors())
			StopSoundOn("farm.flies_loop", s)
	}
	
	// ============================================================
	// PROP DESTRUCTION (migrated from ScriptedMode_AddUpdate)
	// ============================================================
	function CheckPropsInSpit()
	{
		// Check all explosive props
		CheckModel("models/props_junk/gascan001a.mdl", Settings.GasCanDestroyTime, false)
		CheckModel("models/props_unique/wooden_barricade_gascans.mdl", Settings.GasCanDestroyTime, false)
		CheckModel("models/props_junk/propanecanister001a.mdl", Settings.PropaneDestroyTime, false)
		CheckModel("models/props_equipment/oxygentank01.mdl", Settings.OxygenDestroyTime, false)
		CheckModel("models/props_junk/explosive_box001.mdl", Settings.ExplosiveBoxTime, false)
		CheckModel("models/props_industrial/barrel_fuel.mdl", Settings.FuelBarrelTime, true)
		
		return Settings.CheckInterval
	}
	
	function CheckModel(modelPath, destroyTime, ignite)
	{
		local prop = null
		while ((prop = Entities.FindByModel(prop, modelPath)) != null)
		{
			if (!prop.IsValid())
				continue
			
			local propKey = prop.GetEntityIndex().tostring()
			local isInSpit = IsInSpit(prop)
			
			if (isInSpit)
			{
				if (!(propKey in PropsInSpit))
				{
					// Just entered spit
					PropsInSpit[propKey] <- {
						prop = prop,
						enterTime = Time(),
						destroyTime = destroyTime,
						ignite = ignite
					}
				}
				else
				{
					// Already in spit - check if time to destroy
					local data = PropsInSpit[propKey]
					if (Time() - data.enterTime >= data.destroyTime)
					{
						DestroyProp(prop, data.ignite)
						delete PropsInSpit[propKey]
					}
				}
			}
			else
			{
				// Left spit - remove tracking
				if (propKey in PropsInSpit)
					delete PropsInSpit[propKey]
			}
		}
	}
	
	function IsInSpit(prop)
	{
		// Check if near any insect_swarm (spit entity)
		local spit = Entities.FindByClassnameWithin(null, "insect_swarm", prop.GetOrigin(), 170)
		return (spit != null && spit.IsValid())
	}
	
	function DestroyProp(prop, ignite)
	{
		if (!prop || !prop.IsValid())
			return
		
		if (ignite)
		{
			// Ignite the prop
			DoEntFire("!self", "Ignite", "", 0, null, prop)
		}
		else
		{
			// Break the prop
			DoEntFire("!self", "Break", "", 0, null, prop)
		}
		
		// Visual feedback
		MaoLib_VFX.SpawnExplosion(prop.GetOrigin(), "small")
	}
	
	// ============================================================
	// SURVIVOR SLOW EFFECT
	// ============================================================
	function OnGameEvent_entered_spit(params)
	{
		if (!("userid" in params))
			return
		
		local survivor = GetPlayerFromUserID(params.userid)
		if (!survivor || !survivor.IsValid() || !survivor.IsSurvivor())
			return
		if (survivor.IsIncapacitated())
			return
		
		ApplySlowEffect(survivor)
	}
	
	function ApplySlowEffect(survivor)
	{
		local uid = survivor.GetEntityIndex().tostring()
		Dbg("ApplySlowEffect to survivor #" + uid)
		
		// MaoLib.Modifiers (auto-cleanup) — fricción aumentada a 2.5
		MaoLib.Modifiers.RegisterFriction(survivor, Settings.SlowFriction, Settings.SlowDuration, "spitter_spit")
		
		// Cancel any pending sound stop from previous entry
		CancelFlySoundTimer(uid)
		
		// Stop any existing flies sound before restarting
		StopSoundOn("farm.flies_loop", survivor)
		
		// Sound — looping flies
		EmitSoundOn("farm.flies_loop", survivor)
		
		// Schedule sound stop when slow expires
		// ⚠️ Guard: StopSoundOn requiere entidad viva
		local capturedUid = uid
		_FlySoundTimers[capturedUid] <- MaoLib.DelayCall(function() {
			Dbg("Fly sound timer expired for survivor #" + capturedUid)
			local s = EntIndexToHScript(capturedUid.tointeger())
			if (s && s.IsValid() && s.IsSurvivor())
				StopSoundOn("farm.flies_loop", s)
			if (capturedUid in SpitterSystem._FlySoundTimers)
				delete SpitterSystem._FlySoundTimers[capturedUid]
		}, Settings.SlowDuration)
		Dbg("  scheduled StopSoundOn in " + Settings.SlowDuration + "s")
		
		// Visual particles
		local boneIndex = survivor.LookupBone("ValveBiped.Bip01_Spine2")
		if (boneIndex >= 0)
		{
			local target = SpawnEntityFromTable("info_particle_target", {
				origin = survivor.GetBoneOrigin(boneIndex)
			})
			
			local effect = SpawnEntityFromTable("info_particle_system", {
				effect_name = "Spitter_Bugged",
				cpoint1 = "#" + target.GetEntityIndex()
			})
			
			DoEntFire("!self", "SetParent", "#" + survivor.GetEntityIndex(), 0, null, target)
			DoEntFire("!self", "Start", "", 0, null, effect)
			DoEntFire("!self", "Kill", "", 5, null, effect)
			DoEntFire("!self", "Kill", "", 5, null, target)
		}
		
		// Instructor hint
		ShowSpitHint(survivor)
	}
	
	function ClearSlow(survivorIndex)
	{
		local survivor = EntIndexToHScript(survivorIndex)
		if (!survivor || !survivor.IsValid())
			return
		
		Dbg("ClearSlow for survivor #" + survivorIndex)
		StopSoundOn("farm.flies_loop", survivor)
		CancelFlySoundTimer(survivorIndex.tostring())
		// Friction auto-cleanup handled by MaoLib.Modifiers
	}
	
	// Cancel pending fly sound stop timer for a survivor
	function CancelFlySoundTimer(uid)
	{
		if (uid in _FlySoundTimers)
		{
			Dbg("CancelFlySoundTimer for survivor #" + uid)
			MaoLib.RemoveTimer(_FlySoundTimers[uid])
			delete _FlySoundTimers[uid]
		}
	}
	
	// Cancel ALL pending fly sound stop timers (used on round end)
	function _CancelAllFlySoundTimers()
	{
		foreach (uid, timerName in _FlySoundTimers)
			MaoLib.RemoveTimer(timerName)
		_FlySoundTimers.clear()
	}
	
	function ShowSpitHint(survivor)
	{
		local hint = SpawnEntityFromTable("env_instructor_hint", {
			hint_name = "explain_bug_slow",
			hint_static = "1",
			hint_nooffscreen = "0",
			hint_pulseoption = "1",
			hint_shakeoption = "1",
			hint_caption = "Standing in goo will slow you down!",
			hint_instance_type = "2",
			hint_icon_onscreen = "icon_alert",
			hint_color = "255 255 255",
			hint_timeout = "5",
			hint_display_limit = "3",
			hint_auto_start = "0",
			hint_forcecaption = "1",
			hint_allow_nodraw_target = "1",
			origin = survivor.GetCenter()
		})
		
		if (hint && hint.IsValid())
		{
			DoEntFire("!self", "ShowHint", "", 0, survivor, hint)
			DoEntFire("!self", "Kill", "", 6, null, hint)
		}
	}
	
	// ============================================================
	// BOT REPLACEMENT CLEANUP
	// ============================================================
	function OnGameEvent_player_bot_replace(params)
	{
		if (!("player" in params))
			return
		
		local survivor = GetPlayerFromUserID(params.player)
		if (!survivor || !survivor.IsValid())
			return
		
		ClearSlow(survivor.GetEntityIndex())
	}
}

// ================================================================
// REGISTER
// ================================================================
::__CollectGameEventCallbacks(SpitterSystem)

printl("[SpitterSystem] Loaded - Acid Destruction, Survivor Slow")
