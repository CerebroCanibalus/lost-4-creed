/*
 * ================================================================
 * INFECTED BALANCE & CONFIGURATION
 * ================================================================
 * Replaces: infected_convars.nut, custom_ml.nut, nocrowning.nut, boss_warning.nut
 * 
 * This module handles:
 * - All infected-related convars and balance settings
 * - Mob size limits based on difficulty
 * - No crowning mechanic (shotgun bonus damage removed)
 * - Boss spawn warnings (Tank/Witch alerts)
 * ================================================================
 */

::InfectedBalance <-
{
	// ============================================================
	// DIFFICULTY SCALING
	// ============================================================
	function OnGameEvent_round_start_post_nav(params)
	{
		ApplyConvars()
		ApplyDifficultyScaling()
	}
	
	function OnGameEvent_difficulty_changed(params)
	{
		ApplyDifficultyScaling()
	}
	
	// ============================================================
	// CONVARS CONFIGURATION
	// ============================================================
	function ApplyConvars()
	{
		// General infected settings
		Convars.SetValue("z_tank_has_special_blood", "1")
		Convars.SetValue("claw_swing_interval", "1.75")
		Convars.SetValue("claw_swing_miss_interval", "1.0")
		Convars.SetValue("claw_force", "400")
		Convars.SetValue("claw_range", "70")
		Convars.SetValue("claw_range_down", "82")
		
		// Boomer
		Convars.SetValue("z_exploding_inner_radius", "150")
		Convars.SetValue("z_exploding_outer_radius", "200")
		Convars.SetValue("z_exploding_splat_radius", "200")
		Convars.SetValue("z_exploding_speed", "170")
		Convars.SetValue("boomer_vomit_delay", "0")
		Convars.SetValue("z_female_boomer_spawn_chance", "50")
		Convars.SetValue("z_vomit", "1")
		Convars.SetValue("z_vomit_boxsize", "1.20")
		Convars.SetValue("z_vomit_drag", "1.15")
		Convars.SetValue("z_vomit_duration", "2.23")
		Convars.SetValue("z_vomit_fade_duration", "5")
		Convars.SetValue("z_vomit_fade_start", "5")
		Convars.SetValue("z_vomit_fatigue", "100")
		Convars.SetValue("z_vomit_float", "-180.0")
		Convars.SetValue("z_vomit_hit_pitch_max", "20")
		Convars.SetValue("z_vomit_hit_pitch_min", "-20")
		Convars.SetValue("z_vomit_hit_yaw_max", "20")
		Convars.SetValue("z_vomit_hit_yaw_min", "-20")
		Convars.SetValue("z_vomit_interval", "35")
		Convars.SetValue("z_vomit_lifetime", "0.3")
		Convars.SetValue("z_vomit_maxdamagedist", "300.0")
		Convars.SetValue("z_vomit_range", "300")
		
		// Smoker
		Convars.SetValue("smoker_pz_claw_dmg", "4")
		Convars.SetValue("tongue_allow_voluntary_release", "1")
		Convars.SetValue("tongue_break_from_damage_amount", "25")
		Convars.SetValue("tongue_choke_damage_amount", "5")
		Convars.SetValue("tongue_drag_damage_amount", "3")
		Convars.SetValue("tongue_fly_speed", "1500")
		Convars.SetValue("tongue_health", "100")
		Convars.SetValue("tongue_hit_delay", "0.1")
		Convars.SetValue("tongue_los_forgiveness_time", "1.5")
		Convars.SetValue("tongue_miss_delay", "2")
		Convars.SetValue("tongue_player_dropping_to_ground_time", "0.5")
		Convars.SetValue("tongue_range", "1250")
		Convars.SetValue("tongue_victim_accuracy_penalty", "0.5")
		Convars.SetValue("tongue_victim_max_speed", "150")
		
		// Hunter — restored vanilla pounce ranges (were nerfed to 350/450 causing permacrouch)
		Convars.SetValue("hunter_leap_away_give_up_range", "2000")
		Convars.SetValue("hunter_pz_claw_dmg", "6")
		Convars.SetValue("hunter_pounce_air_speed", "600")
		Convars.SetValue("hunter_pounce_loft_rate", "0.015")
		Convars.SetValue("hunter_pounce_max_loft_angle", "13")
		Convars.SetValue("hunter_pounce_ready_range", "500")
		Convars.SetValue("z_hunter_lunge_distance", "600")
		Convars.SetValue("z_hunter_lunge_stagger_time", "2.5")
		Convars.SetValue("z_hunter_max_pounce_bonus_damage", "24")
		Convars.SetValue("z_hunter_speed", "250")
		
		// Charger
		Convars.SetValue("charger_pz_claw_dmg", "8")
		Convars.SetValue("z_charge_duration", "2.5")
		Convars.SetValue("z_charge_max_force", "800")
		Convars.SetValue("z_charge_min_force", "550")
		Convars.SetValue("z_charge_max_speed", "500")
		Convars.SetValue("z_charge_start_speed", "250")
		Convars.SetValue("z_charger_allow_shove", "0")
		Convars.SetValue("z_charger_health", "150")
		Convars.SetValue("z_charger_pound_dmg", "10")
		Convars.SetValue("z_charger_probe_attack", "0")
		
		// Spitter
		Convars.SetValue("spitter_pz_claw_dmg", "4")
		Convars.SetValue("z_spitter_health", "100")
		Convars.SetValue("z_spitter_limit", "1")
		Convars.SetValue("z_spitter_max_wait_time", "2")
		Convars.SetValue("z_spitter_range", "850")
		Convars.SetValue("z_spitter_speed", "210")
		
		// Jockey
		Convars.SetValue("jockey_pz_claw_dmg", "3")
		Convars.SetValue("z_jockey_health", "150")
		Convars.SetValue("z_jockey_leap_again_timer", "2")
		Convars.SetValue("z_jockey_leap_range", "200")
		Convars.SetValue("z_jockey_ride_damage", "4")
		Convars.SetValue("z_jockey_ride_damage_interval", "1")
		Convars.SetValue("z_jockey_speed", "210")
		
		// Common infected
		Convars.SetValue("z_health", "50")
		Convars.SetValue("z_speed", "210")
		Convars.SetValue("z_walk_speed", "45")
		
		// No crowning - remove shotgun bonus damage to witches
		// z_shotgun_bonus_damage_multiplier → l4c_settings.nut
	}
	
	// ============================================================
	// DIFFICULTY SCALING
	// ============================================================
	function ApplyDifficultyScaling()
	{
		local difficulty = Convars.GetStr("z_difficulty")
		if (!difficulty)
			difficulty = "normal"
		
		difficulty = difficulty.tolower()
		
		switch (difficulty)
		{
			case "easy":
				Convars.SetValue("z_common_limit", "20")
				Convars.SetValue("z_mega_mob_size", "30")
				Convars.SetValue("z_mob_spawn_min_size", "8")
				Convars.SetValue("z_mob_spawn_max_size", "12")
				break
			
			case "normal":
				Convars.SetValue("z_common_limit", "25")
				Convars.SetValue("z_mega_mob_size", "45")
				Convars.SetValue("z_mob_spawn_min_size", "10")
				Convars.SetValue("z_mob_spawn_max_size", "15")
				break
			
			case "hard":
			case "advanced":
				Convars.SetValue("z_common_limit", "30")
				Convars.SetValue("z_mega_mob_size", "60")
				Convars.SetValue("z_mob_spawn_min_size", "15")
				Convars.SetValue("z_mob_spawn_max_size", "25")
				break
			
			case "impossible":
			case "expert":
			case "realism":
				Convars.SetValue("z_common_limit", "35")
				Convars.SetValue("z_mega_mob_size", "75")
				Convars.SetValue("z_mob_spawn_min_size", "20")
				Convars.SetValue("z_mob_spawn_max_size", "35")
				break
		}
	}
	
	// ============================================================
	// BOSS WARNING SYSTEM
	// ============================================================
	function OnGameEvent_tank_spawn(params)
	{
		ShowBossWarning("tank")
	}
	
	function OnGameEvent_witch_spawn(params)
	{
		ShowBossWarning("witch")
	}
	
	function ShowBossWarning(bossType)
	{
		local message = ""
		local sound = ""
		local color = ""
		
		if (bossType == "tank")
		{
			message = "⚠️ TANK DETECTED - Start Praying..."
			sound = "npc/tank/tank_yell.wav"
			color = "255 50 50"
		}
		else if (bossType == "witch")
		{
			message = "⚠️ WITCH NEARBY - Lights out..."
			sound = "npc/witch/voice/attack/Female_DistantScream.wav"
			color = "255 200 50"
		}
		else
		{
			return
		}
		
		// Show hint to all players
		local hint = SpawnEntityFromTable("env_instructor_hint", {
			hint_name = "boss_warning_" + bossType,
			hint_static = "0",
			hint_nooffscreen = "0",
			hint_pulseoption = "1",
			hint_shakeoption = "1",
			hint_caption = message,
			hint_instance_type = "2",
			hint_icon_onscreen = "icon_alert_red",
			hint_color = color,
			hint_timeout = "5",
			hint_display_limit = "1",
			hint_auto_start = "0",
			hint_forcecaption = "1",
			origin = Vector(0, 0, 0)
		})
		
		if (hint && hint.IsValid())
		{
			// Show to all players
			local player = null
			while (player = Entities.FindByClassname(player, "player"))
			{
				if (player.IsValid() && player.IsSurvivor())
				{
					DoEntFire("!self", "ShowHint", "", 0, player, hint)
					EmitSoundOnClient(sound, player)
				}
			}
			
			// Clean up hint entity
			DoEntFire("!self", "Kill", "", 6, null, hint)
		}
	}
}

// ================================================================
// REGISTER
// ================================================================
::__CollectGameEventCallbacks(InfectedBalance)

printl("[InfectedBalance] Loaded - Convars, Difficulty Scaling, No Crowning, Boss Warnings")
