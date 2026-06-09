::MountedGunBulletExplode <- {
	DEBUG = true, // TODO: desactivar antes del release

	function DebugPrint(msg) {
		if(DEBUG) printl("[MOUNTED_GUN] " + msg);
	}

	// Entidad pre-spawneada (declarada ANTES de cualquier funcion que la use)
	explosion_ent = null,

	player_using_mounted = {},

	// Clases de torretas montadas válidas (L4D2):
	// - prop_mounted_machine_gun: torreta .50 cal (Parish, Swamp Fever, Sacrifice)
	// - prop_minigun: classname después del fixup del engine
	MOUNTED_CLASSES = { prop_minigun = true, prop_mounted_machine_gun = true },

	DefaultSettings = null,
	settings_file = "mounted_gun_bullet_explode/settings.txt",

	Settings = {
		enable = true,
		damage_human = 50,
		damage = 200,
		radius = 300,
		force = 1000,
		stagger_human_chance = 0,
		stagger_special_chance = 0,
		stagger_tank_chance = 0,
		particles_front = ["impact_upholstery_child_smoke", "impact_incendiary_generic", "impact_incendiary_fire"],
		particles_back = ["impact_upholstery_child_smoke", "impact_incendiary_generic", "impact_incendiary_fire"]
	},

	SettingsDefinitions = {
		enable = ["bool", null, null, "!mgbe_e"],
		damage_human = ["integer", 0, null, "!mgbe_dh"],
		damage = ["integer", 0, null, "!mgbe_d"],
		radius = ["integer", 0, null, "!mgbe_r"],
		force = ["integer", 0, null, "!mgbe_f"],
		stagger_human_chance = ["integer", 0, 100, "!mgbe_shc"],
		stagger_special_chance = ["integer", 0, 100, "!mgbe_ssc"],
		stagger_tank_chance = ["integer", 0, 100, "!mgbe_stc"],
		particles_front = ["stringArray", null, null, "!mgbe_pf"],
		particles_back = ["stringArray", null, null, "!mgbe_pb"]
	},

	SettingsOrder = [
		"enable",
		"damage_human",
		"damage",
		"radius",
		"force",
		"stagger_human_chance",
		"stagger_special_chance",
		"stagger_tank_chance",
		"particles_front",
		"particles_back"
	],

	/******************** EVENT HANDLERS ********************/

	function OnGameEvent_round_start_post_nav(params) {
		LoadSettings();
		// Pre-spawnear env_explosion para reutilizar (evita spawneo masivo en cada disparo)
		if(explosion_ent == null || !explosion_ent.IsValid()) {
			explosion_ent = SpawnEntityFromTable("env_explosion", {
				targetname = "mgbe_explosion",
				iMagnitude = Settings.damage,
				iRadiusOverride = Settings.radius,
				DamageForce = Settings.force,
				spawnflags = 1604,
				ignoredClass = 1,
				origin = Vector(0, 0, -9999)
			});
		}
	}

	function OnGameEvent_player_say(params) {
		local player = GetPlayerFromUserID(params.userid);
		if (!player) return;
		local message = strip(params.text).tolower();
		if(message.find("!mgbe_") != 0) return;
		local language = Convars.GetClientConvarValue("cl_language", player.GetEntityIndex());
		local isChinese = language.find("chinese") != null ? true : false;
		local parts = split(message, " ");
		if(parts.len() == 2) {
			local key = strip(parts[0]);
			local value = strip(parts[1]);
			foreach(k, v in SettingsDefinitions) {
				if(v[3] == key) {
					local fixValue = FixSettingsValue(k, value);
					if(fixValue != null) {
						Settings[k] = fixValue;
						SaveSettings();
						if(SettingsDefinitions[k][0].find("Array") != null) fixValue = ArrayToString(fixValue);
						if(isChinese) ClientPrint(player, 5, "[MountedGunBulletExplode] \x03" + k + "\x01 = \x03" + fixValue);
						else ClientPrint(player, 5, "[MountedGunBulletExplode] \x03" + k + "\x01 = \x03" + fixValue);
					} else {
						if(isChinese) ClientPrint(player, 5, "[MountedGunBulletExplode] 修改失败，请确保输入格式正确。");
						else ClientPrint(player, 5, "[MountedGunBulletExplode] Modification failed, please ensure that the input format is correct.");
					}
					break;
				}
			}
			if(key == "!mgbe_pts") {
				Convars.SetValue("r_particle_timescale", value);
				ClientPrint(player, 5, "r_particle_timescale = " + value);
			}
		} else {
			if(message == "!mgbe_reload") {
				LoadSettings();
				if(isChinese) ClientPrint(player, 5, "[MountedGunBulletExplode] 重新读取设置文件");
				else ClientPrint(player, 5, "[MountedGunBulletExplode] Reload settings file");
			}
			else if(message == "!mgbe_default") {
				StringToFile(settings_file, "{}");
				LoadSettings();
				if(isChinese) ClientPrint(player, 5, "[MountedGunBulletExplode] 恢复默认设置");
				else ClientPrint(player, 5, "[MountedGunBulletExplode] Restore default settings");
			}
		}
	}

	function OnGameEvent_mounted_gun_start(params) {
		local player = GetPlayerFromUserID(params.userid);
		local mounted = EntIndexToHScript(params.subject);
		local classname = mounted.GetClassname();
		// Aceptar todas las clases de torretas montadas:
		// prop_minigun, prop_mounted_machine_gun, prop_minigun_l4d1
		if(classname in MOUNTED_CLASSES) {
			player_using_mounted[player] <- mounted;
			DebugPrint("mounted_gun_start - Registered: " + classname);
		} else {
			DebugPrint("mounted_gun_start - Unknown mounted gun: " + classname + ", ignoring");
		}
	}

	function OnGameEvent_bullet_impact(params) {
		if(!Settings.enable) return;  // Sin debug — desactivado

		local player = GetPlayerFromUserID(params.userid);
		if (!player) return;  // Sin debug — normal que no sea torreta

		// Verificar si el jugador esta usando una mounted gun
		local usingMounted = NetProps.GetPropInt(player, "m_usingMountedWeapon");
		if(usingMounted != 1) return;  // Sin debug — mayoría de balas no son de torreta

		local hitPos = Vector(params.x, params.y, params.z);
		local mounted = (player in player_using_mounted) ? player_using_mounted[player] : null;

		// Verificar que sea una torreta montada válida
		if(mounted == null || !mounted.IsValid()) return;
		if(!(mounted.GetClassname() in MOUNTED_CLASSES)) return;

		DebugPrint("bullet_impact - Turret confirmed, spawning explosion at " + hitPos);

		SpawnExplode(hitPos, player, 0.01, mounted);

		// Partículas de impacto via MaoLib_VFX
		DebugPrint("bullet_impact - Spawning " + (Settings.particles_front.len() + Settings.particles_back.len()) + " particles");
		foreach (particle in Settings.particles_front) {
			::MaoLib_VFX.SpawnParticle(hitPos, particle, 1.0);
		}
		foreach (particle in Settings.particles_back) {
			::MaoLib_VFX.SpawnParticle(hitPos, particle, 1.0);
		}
	}

	function OnGameEvent_round_end(params) {
		if(explosion_ent && explosion_ent.IsValid()) {
			explosion_ent.Kill();
			explosion_ent = null;
		}
		player_using_mounted.clear();
	}

	function SpawnExplode(hitPos, player, hitTime, mounted) {
		DebugPrint("SpawnExplode called at " + hitPos + " | explosion_ent valid=" + (explosion_ent != null && explosion_ent.IsValid()));
		if(explosion_ent == null || !explosion_ent.IsValid()) {
			DebugPrint("SpawnExplode - Creating new env_explosion entity");
			// Si no hay explosion pre-spawneada, crear una nueva
			explosion_ent = SpawnEntityFromTable("env_explosion", {
				targetname = "mgbe_explosion",
				iMagnitude = Settings.damage,
				iRadiusOverride = Settings.radius,
				DamageForce = Settings.force,
				spawnflags = 1604,
				ignoredClass = 1,
				origin = Vector(0, 0, -9999)
			});
		}

		// Mover explosion a la posicion de impacto
		explosion_ent.SetOrigin(hitPos);
		NetProps.SetPropEntity(explosion_ent, "m_hInflictor", player);
		NetProps.SetPropEntity(explosion_ent, "m_hOwnerEntity", player);

		// Aplicar daño manualmente a entidades en el radio
		local playerInRadius = null;
		while( playerInRadius = Entities.FindByClassnameWithin(playerInRadius, "player", hitPos, Settings.radius) ) {
			local dOrigin = (playerInRadius.GetOrigin() + playerInRadius.EyePosition()) * 0.5;
			local dDistance = (dOrigin - hitPos).Length();
			local dDirection = dOrigin - hitPos;
			dDirection.Norm();
			local dFactor = 1 - dDistance / Settings.radius;
			if( playerInRadius.IsSurvivor() ) {
				local friendlyFactor = Convars.GetFloat("survivor_friendly_fire_factor_normal");
				if( HasConfigurableDifficultySetting() ){
					switch( GetDifficulty() ) {
						case 0:
							friendlyFactor = Convars.GetFloat("survivor_friendly_fire_factor_easy");
							break;
						case 2:
							friendlyFactor = Convars.GetFloat("survivor_friendly_fire_factor_hard");
							break;
						case 3:
							friendlyFactor = Convars.GetFloat("survivor_friendly_fire_factor_expert");
							break;
					}
				}
				local damageType = RandomInt(1,100) > Settings.stagger_human_chance ? 0 : 64;
				playerInRadius.TakeDamageEx(explosion_ent, player, mounted, dDirection, dOrigin - dDirection * 10, dFactor * Settings.damage_human * friendlyFactor, damageType);
			} else {
				local staggerChance = null;
				if(playerInRadius.GetZombieType() == 8) staggerChance = Settings.stagger_tank_chance;
				else staggerChance = Settings.stagger_special_chance;
				local damageType = RandomInt(1,100) > staggerChance ? 0 : 64;
				playerInRadius.TakeDamageEx(explosion_ent, player, mounted, dDirection, dOrigin - dDirection * 10, dFactor * Settings.damage, damageType);
			}
		}

		// Explosion controlada
		DoEntFire("!self", "Explode", "", hitTime, null, explosion_ent);

		// Sonido de explosion via MaoLib_VFX (auto-precache, auto-cleanup)
		::MaoLib_VFX.EmitSoundAt(hitPos, "weapons/hegrenade/explode5.wav", 1.0, 100);

		// Screen shake opcional
		::MaoLib_VFX.ScreenShake(hitPos, 4, 15, 0.5, Settings.radius);
		DebugPrint("SpawnExplode - Explosion completed successfully");
	}

	/******************** SETTINGS MANAGEMENT ********************/

	function LoadSettings() {
		if(DefaultSettings == null) DefaultSettings = clone Settings;
		local content = FileToString(settings_file);
		if(!content) {
			SaveSettings();
			content = FileToString(settings_file);
		}
		try {
			local settingsTable = compilestring("return " + content)();
			local needRewrite = false;
			foreach (key, value in Settings) {
				if(key in settingsTable) {
					local fixValue = FixSettingsValue(key, settingsTable[key]);
					if(fixValue != null) Settings[key] = fixValue;
					else if(!needRewrite) needRewrite = true;
				} else {
					Settings[key] = DefaultSettings[key];
					if(!needRewrite) needRewrite = true;
				}
			}
			if(needRewrite) SaveSettings();
		}
		catch(error) {
			printl("[MountedGunBulletExplode]LoadSettings ERROR: " + error);
			SaveSettings();
		}
	}

	function SaveSettings() {
		local content = "{\n";
		foreach(key in SettingsOrder) {
			local strValue = null;
			if(SettingsDefinitions[key][0].find("Array") != null) strValue = ArrayToString(Settings[key]);
			else strValue = Settings[key].tostring();
			content += "\t" + key + " = " + strValue + "\n";
		}
		content += "}";
		StringToFile(settings_file, content);
	}

	function ArrayToString(array) {
		local strArray = "[";
		foreach(i, v in array) {
			if(typeof(v) == "string") strArray += "\"" + v + "\"";
			else strArray += v.tostring();
			if(i < array.len() - 1) strArray += ", ";
		}
		strArray += "]";
		return strArray;
	}

	function FixSettingsValue(key, value) {
		try{
			switch(SettingsDefinitions[key][0]) {
				case "integer":
				case "float":
					if(SettingsDefinitions[key][0] == "integer") value = value.tointeger();
					else value = value.tofloat();
					local minValue = SettingsDefinitions[key][1];
					local maxValue = SettingsDefinitions[key][2];
					if(minValue != null && value < minValue) value = minValue;
					else if(maxValue != null && value > maxValue) value = maxValue;
					return value;
				case "bool":
					local valueType = typeof(value);
					if(valueType == "bool") return value;
					if(valueType == "integer" || valueType == "float") return (value > 0) ? true : false;
					if(valueType == "string") {
						if(value == "true" || value == "1") return true;
						else if(value == "false" || value == "0") return false;
					}
					return null;
				case "string":
					return value.tostring();
				case "stringArray":
					local valueType = typeof(value);
					if(valueType == "array") return value;
					if(valueType == "string") {
						local parts = split(value, ",");
						value = [];
						foreach(part in parts) value.append(part);
						return value;
					}
					return null;
				case "integerArray":
					local valueType = typeof(value);
					if(valueType == "array") return value;
					if(valueType == "string") {
						local parts = split(value, ",");
						value = [];
						foreach(part in parts) value.append(part.tointeger());
						return value;
					}
					return null;
				case "floatArray":
					local valueType = typeof(value);
					if(valueType == "array") return value;
					if(valueType == "string") {
						local parts = split(value, ",");
						value = [];
						foreach(part in parts) value.append(part.tofloat());
						return value;
					}
					return null;
			}
		}
		catch(error) {
			printl("[MountedGunBulletExplode]FixSettingsValue ERROR: " + error);
		}
		return null;
	}
}

__CollectGameEventCallbacks(::MountedGunBulletExplode);
printl("[MountedGunBulletExplode] Loaded v2.2 - L4D2 Turret Only (prop_minigun) with MaoLib");
