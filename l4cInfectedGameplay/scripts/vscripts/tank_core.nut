/**
 * Tank Core System
 * 
 * Consolidated from: tank_base.nut + tank_expert.nut + tank_model.nut + tank_melee.nut
 * 
 * Features:
 * - Base configuration (convars)
 * - HP Scaling with buff (9000 base + 30/min, max 15000)
 * - Expert damage modifier (60% in Expert coop/realism)
 * - Random model selection (3 variants)
 * - Melee alert visual effect
 */

// ------------------------------------------------------------------
// DIRECTOR OPTIONS
// ------------------------------------------------------------------
DirectorOptions <-
{
	ZombieTankHealth = 12000
}

// ------------------------------------------------------------------
// CONVARS - All tank-related console variables
// ------------------------------------------------------------------
Convars.SetValue("z_tank_attack_interval", "2.5");
Convars.SetValue("z_tank_autoshotgun_dmg_scale", "0.70");
Convars.SetValue("z_tank_damage_slow_max_range", "500");
Convars.SetValue("z_tank_damage_slow_min_range", "200");
Convars.SetValue("z_tank_rock_radius", "150");
Convars.SetValue("z_tank_grenade_damage", "800");
Convars.SetValue("z_tank_grenade_slowdown", "100");
Convars.SetValue("z_tank_grenade_launcher_dmg_scale", "1");
Convars.SetValue("tank_burn_duration", "70");
Convars.SetValue("tank_burn_duration_expert", "60");
Convars.SetValue("tank_burn_duration_hard", "65");
Convars.SetValue("z_tank_max_stagger_duration", "4");
Convars.SetValue("z_tank_speed", "225");
Convars.SetValue("z_tank_speed_vs", "235");
Convars.SetValue("z_tank_walk_speed", "210");
Convars.SetValue("z_tank_throw_force", "1500");
Convars.SetValue("z_tank_throw_health", "80");
Convars.SetValue("z_tank_throw_interval", "3.5");
Convars.SetValue("tank_attack_range", "70");
Convars.SetValue("tank_fist_radius", "25");
Convars.SetValue("tank_rock_overhead_percent", "60");
Convars.SetValue("tank_stasis_time_suicide", "9000");
Convars.SetValue("tank_stuck_failsafe", "1");
Convars.SetValue("tank_stuck_time_choose_new_target", "0.1");
Convars.SetValue("tank_stuck_time_suicide", "9000");
Convars.SetValue("tank_stuck_visibility_tolerance_choose_new_target", "0.1");
Convars.SetValue("tank_stuck_visibility_tolerance_suicide", "9000");
Convars.SetValue("tank_swing_arc", "200");
Convars.SetValue("tank_swing_duration", "0.1");
Convars.SetValue("tank_swing_fast_interval", "2.85");
Convars.SetValue("tank_swing_interval", "1.75");
Convars.SetValue("tank_swing_miss_interval", "1.0");
Convars.SetValue("tank_swing_physics_prop_force", "6.0");
Convars.SetValue("tank_swing_range", "58");
Convars.SetValue("tank_swing_yaw", "90");
Convars.SetValue("tank_throw_lead_time_factor", "0.8");
Convars.SetValue("tank_throw_loft_rate", ".01");
Convars.SetValue("tank_throw_max_loft_angle", "30");
Convars.SetValue("tank_throw_min_interval", "8");
Convars.SetValue("tank_visibility_tolerance_suicide", "9000");
Convars.SetValue("tank_windup_time", ".5");

printl("=================================");
printl("Tank Core Config Loaded");
printl("Base HP: 12000 | Max HP: 25000");
printl("=================================");

// ------------------------------------------------------------------
// HP SCALING SYSTEM (Buffed)
// ------------------------------------------------------------------
::TankCore <-
{
	// HP Scaling config
	BaseHP = 12000
	HPPerSecond = 1.0		// 60 HP per minute
	MaxHP = 25000
	
	// Damage modifier for Expert difficulty
	TankDamageModifier = 0.60

	// Difficulty string → int (nativa de L4D2)
	_DifficultyNames = ["Easy", "Normal", "Advanced", "Expert"]

	function _DifficultyToInt(str)
	{
		foreach (i, name in _DifficultyNames)
		{
			if (name == str)
				return i;
		}
		return 1;  // default: Normal
	}

	function _GetDifficultyInt()
	{
		local diffStr = Convars.GetStr("z_difficulty");
		return _DifficultyToInt(diffStr);
	}
	
	function OnGameEvent_tank_spawn(params)
	{
		if (!("userid" in params))
			return;

		// FIXED BUG: tank_spawn usa userid, NO tankid
		// Ver: https://wiki.alliedmods.net/Left_4_dead_2_events
		local tank = GetPlayerFromUserID(params.userid);
		if (!tank || !tank.IsValid())
			return;
		
		// Calculate scaled HP based on mission time
		local time = Director.GetTotalElapsedMissionTime().tointeger();
		local addedHP = HPPerSecond * time;
		local totalHP = BaseHP + addedHP;
		
		if (totalHP > MaxHP)
			totalHP = MaxHP;
		
		tank.SetHealth(totalHP);
		
		// printl("[TankCore] Tank spawned with " + totalHP + " HP (Time: " + time + "s)");
	}
	
	function OnGameEvent_difficulty_changed(params)
	{
		if (!("newDifficulty" in params)) return;

		// FIXED BUG: newDifficulty es STRING ("Normal", "Advanced"...)
		// Convertimos a int para el switch
		local diff = _DifficultyToInt(params.newDifficulty);
		ApplyDamageModifier(diff);
	}
	
	function ApplyDamageModifier(difficulty = null)
	{
		// Only apply in coop and realism modes
		local gameMode = Director.GetGameMode();
		if (gameMode != "coop" && gameMode != "realism")
			return;
		
		if (difficulty == null)
			difficulty = _GetDifficultyInt();
		
		// 0=Easy, 1=Normal, 2=Advanced, 3=Expert
		switch(difficulty)
		{
			case 0: case 1: case 2:
				// TankHitDamageModifierCoop = daño que el TANK inflige a survivors (NO que recibe)
				// 1.5 = 150% daño en Normal/Advanced (más peligroso, como debe ser)
				// ¡NO cambiar a 1.0 a menos que el tank esté one-shotting!
				DirectorScript.DirectorOptions.TankHitDamageModifierCoop <- 1.5;
				printl("[TankCore] Tank damage modifier: 150% (Normal/Advanced)");
				break;
				
			case 3:
				// Expert: Tank deals less damage (60%) to avoid instakill
				DirectorScript.DirectorOptions.TankHitDamageModifierCoop <- TankDamageModifier;
				printl("[TankCore] Tank damage modifier: 60% (Expert - no instakill)");
				break;
				
			default:
				break;
		}
	}
}

// Apply damage modifier on load
::TankCore.ApplyDamageModifier();

__CollectGameEventCallbacks(::TankCore);

// ------------------------------------------------------------------
// RANDOM MODEL SYSTEM
// ------------------------------------------------------------------
local RNGModels = [
	"models/infected/hulk.mdl",
	"models/infected/hulk_dlc3.mdl",
	"models/infected/hulk_l4d1.mdl"
];

// Precache models
foreach (model in RNGModels)
{
	if (!IsModelPrecached(model))
		PrecacheModel(model);
}

::TankModelRandomizer <-
{
	function OnGameEvent_tank_spawn(params)
	{
		if (!("userid" in params))
			return;
		
		local tank = GetPlayerFromUserID(params.userid);
		if (!tank || !tank.IsValid() || tank.IsSurvivor() || tank.IsDead())
			return;
		
		local currentModel = NetProps.GetPropString(tank, "m_ModelName");
		
		// Only randomize if it's a default tank model
		if (currentModel == RNGModels[0] || currentModel == RNGModels[1] || currentModel == RNGModels[2])
		{
			tank.SetModel(RNGModels[RandomInt(0, 2)]);
		}
	}
}

__CollectGameEventCallbacks(::TankModelRandomizer);

// ------------------------------------------------------------------
// MELEE ALERT SYSTEM
// ------------------------------------------------------------------
::TankMeleeAlert <-
{
	ConfigPath = "tma/tma_config.txt"
	
	function LoadConfig()
	{
		if (FileToString(ConfigPath) == null)
			GenerateDefaultConfig();
		
		local content = FileToString(ConfigPath);
		if (!content)
			return GetDefaultConfig();
		
		local config = {};
		foreach (line in split(content, "\n"))
		{
			line = strip(line);
			if (line.len() == 0) continue;
			
			local colonPos = line.find(":");
			if (colonPos < 0) continue;
			
			local name = strip(line.slice(0, colonPos));
			local rest = strip(line.slice(colonPos + 1));
			
			local tbl = {};
			foreach (field in split(rest, ","))
			{
				local f = strip(field);
				if (f.len() == 0) continue;
				
				local eq = f.find("=");
				if (eq < 0) continue;
				
				local k = strip(f.slice(0, eq));
				local v = strip(f.slice(eq + 1));
				
				if (v.find("\"") != null)
					tbl[k] <- v.slice(1, v.len() - 1);
				else if (v.find(".") >= 0)
					tbl[k] <- v.tofloat();
				else
					tbl[k] <- v.tointeger();
			}
			config[name] <- tbl;
		}
		
		return config;
	}
	
	function GenerateDefaultConfig()
	{
		local cfg = "tank_melee_alert: rendercolor0=\"255 0 0\", renderamt0=160, duration=0.4, holdtime=0, spawnflags=5\n";
		StringToFile(ConfigPath, cfg);
		printl("[TankMeleeAlert] Default config generated at " + ConfigPath);
	}
	
	function GetDefaultConfig()
	{
		return {
			tank_melee_alert = {
				rendercolor0 = "255 0 0",
				renderamt0 = 160,
				duration = 0.4,
				holdtime = 0,
				spawnflags = 5
			}
		};
	}
	
	function OnGameEvent_player_hurt(params)
	{
		if (!("userid" in params) || !("attacker" in params) || !("weapon" in params))
			return;
		
		local victim = GetPlayerFromUserID(params.userid);
		local attacker = GetPlayerFromUserID(params.attacker);
		
		if (!victim || victim.GetZombieType() != 8) // Not tank
			return;
		
		if (!attacker || !attacker.IsSurvivor())
			return;
		
		local weapon = params.weapon.tolower();
		if (weapon.find("melee") == null)
			return;
		
		// Load config
		local config = LoadConfig();
		if (!("tank_melee_alert" in config))
			config = GetDefaultConfig();
		
		local alertParams = config.tank_melee_alert;
		local fadeName = "tank_melee_alert_fade_" + params.userid;
		
		// Create env_fade effect
		SpawnEntityGroupFromTable({
			f = {
				env_fade = {
					targetname = fadeName,
					rendercolor = alertParams.rendercolor0,
					renderamt = alertParams.renderamt0,
					duration = alertParams.duration,
					holdtime = alertParams.holdtime,
					spawnflags = alertParams.spawnflags
				}
			}
		});
		
		// Apply to tank
		EntFire(fadeName, "Fade", "!activator", 0, victim);
		EntFire(fadeName, "Kill", "", alertParams.duration + 0.1, null);
	}
}

__CollectGameEventCallbacks(::TankMeleeAlert);

printl("=================================");
printl("Tank Melee Alert Loaded");
printl("=================================");