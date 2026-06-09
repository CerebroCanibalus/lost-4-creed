catbor_hellhound <-
{
	// This is a surprise tool that'll help us later
	globals =
	{
		hellhound_destined_to_spawn = false, // turning true results in all jockeys being replaced by hellhounds until this value is turned false.
		hellhound_enabled = true, // turning to false results in hellhounds not spawning at all.
	},

	settings =
	{
		hellhound_chance = 42,
		hellhound_health = 400,
		hellhound_speed = 1.75,
		hellhound_speed_ignited = 2.0,
		hellhounds_faster_ignited = true,
		hellhounds_drop_fire = false,
		
		// Lunge → Stun + Bleed
		hellhound_push_distance = 300,      // Unidades que retrocede al lanzarse
		bleed_duration = 5.0,               // Segundos de sangrado
		bleed_damage_per_tick = 6,          // Daño por tick
		bleed_tick_interval = 1.0,          // 1 tick por segundo
		
		// Explosión muerte
		death_explosion_radius = 150,       // Radio partículas
	},

	last_hound_report = 0  // Para throttling de print

	function HellhoundThink()
	{
		local now = Time()
		local houndCount = 0
		
		// === BLEED DOT: manejado por MaoLib.StatusEffects.DoT Subsystem ===
		// Ya no hay lógica de bleed aquí — ApplyBleed() delega al DoT Subsystem
		
		// === VELOCIDAD HELLHOUNDS (existente) ===
		if (!settings.hellhounds_faster_ignited) return
		for (local hound; hound = Entities.FindByClassname(hound, "player"); )
		{
			if (!hound || !hound.IsValid())
				continue
			
			hound.ValidateScriptScope()
			local sc = hound.GetScriptScope()
			if (sc && "IsHellhound" in sc)
			{
				houndCount++
				if (hound.IsOnFire())
					MaoLib.Modifiers.RegisterSpeed(hound, settings.hellhound_speed_ignited, -1, "hellhound_speed")
				else
					MaoLib.Modifiers.RegisterSpeed(hound, settings.hellhound_speed, -1, "hellhound_speed")
			}
		}
		// Reportar solo si cambió el conteo (evita spam)
		if (houndCount != last_hound_report)
		{
			last_hound_report = houndCount
			if (houndCount > 0)
				printl("[HELLHOUND] Active hellhounds: " + houndCount)
		}
	}

	function OnGameEvent_round_start( params )
	{
		printl("[HELLHOUND] === round_start FIRED ===")
		
		local hellhound_sounds = [
			"nz_zombie/hellhound_spawn.wav",
			"nz_zombie/exp0.wav",
			"nz_zombie/death1.wav"
		]
		foreach (file in hellhound_sounds)
		{
			if (!IsSoundPrecached(file))
			{
				PrecacheSound(file)
				printl("[HELLHOUND] Precaching sound: " + file)
			}
		}

		if (!IsModelPrecached("models/nz_zombie/zombie_hellhound.mdl"))
		{
			PrecacheModel("models/nz_zombie/zombie_hellhound.mdl")
			printl("[HELLHOUND] Precaching model...")
		}
		else
		{
			printl("[HELLHOUND] Model already precached")
		}
		SpawnEntityFromTable("info_target", {targetname = "catbor_hellhound_soundtarget"})
		
		// Thinker via MaoLib (SIEMPRE disponible — cargado por l4cCoreAddon)
		// ⚠️ NUNCA usar if("MaoLib" in getroottable()) — es dependencia dura, no opcional
		if (MaoLib.IsTimerActive("hellhound_think"))
		{
			printl("[HELLHOUND] Removing old timer")
			MaoLib.RemoveTimer("hellhound_think")
		}
		
		MaoLib.AddTimer("hellhound_think", 1.0, function() {
			::catbor_hellhound.HellhoundThink()
		})
		printl("[HELLHOUND] Timer 'hellhound_think' set to 1.0s interval")
	}

	function OnGameEvent_player_spawn( params )
	{
		if (!("userid" in params) || !params.userid) 
		{
			printl("[HELLHOUND] player_spawn: no userid")
			return
		}
		
		local player = GetPlayerFromUserID(params.userid)
		if (!player || !player.IsValid())
		{
			printl("[HELLHOUND] player_spawn: invalid player")
			return
		}
		
		local ztype = player.GetZombieType()
		local isBot = IsPlayerABot(player)
		printl("[HELLHOUND] player_spawn: userid=" + params.userid + " ztype=" + ztype + " isBot=" + isBot)
		
		if (ztype == 5 && isBot && globals.hellhound_enabled)
		{
			local shouldConvert = false
			
			// Debug force: override random chance
			if ("debug_force_next" in this && this.debug_force_next)
			{
				if (Time() < this.debug_force_timeout)
				{
					shouldConvert = true
					this.debug_force_next = false
					printl("[HELLHOUND] DEBUG FORCE: Converting this jockey!")
				}
				else
				{
					this.debug_force_next = false
					printl("[HELLHOUND] DEBUG FORCE expired")
				}
			}
			
			if (!shouldConvert)
			{
				local roll = RandomInt(1, 100)
				shouldConvert = (roll <= settings.hellhound_chance || globals.hellhound_destined_to_spawn)
				printl("[HELLHOUND] Jockey bot spawned! Roll=" + roll + "% chance=" + settings.hellhound_chance + "% destined=" + globals.hellhound_destined_to_spawn + " convert=" + shouldConvert)
			}
			
			if (shouldConvert)
			{
				printl("[HELLHOUND] CONVERTING! entidx=" + player.GetEntityIndex())
				this.ConvertHellhound(player)
			}
		}
	}

	function HandlePlayerSpawn( params ) { OnGameEvent_player_spawn(params); }
	
	function HandlePlayerDeath( params ) { OnGameEvent_player_death(params); }
	
	// ============================================================
	// CONVERSIÓN: Jockey → Hellhound
	// ============================================================
	
	function ConvertHellhound(player)
	{
		printl("[HELLHOUND] === CONVERTING TO HELLHOUND ===")
		
		player.SetMaxHealth(settings.hellhound_health)
		player.SetHealth(settings.hellhound_health)
		printl("[HELLHOUND] HP set to " + settings.hellhound_health)
		
		MaoLib.Modifiers.RegisterSpeed(player, settings.hellhound_speed, -1, "hellhound_speed")
		printl("[HELLHOUND] Speed set to " + settings.hellhound_speed)
		
		// Tag
		player.ValidateScriptScope()
		local sc = player.GetScriptScope()
		sc["IsHellhound"] <- 1
		printl("[HELLHOUND] Tagged as Hellhound")
		
		// Modelo
		printl("[HELLHOUND] Setting model to hellhound.mdl...")
		player.SetModel("models/nz_zombie/zombie_hellhound.mdl")
		printl("[HELLHOUND] Model set")
		
		// Nombre
		SetFakeClientConVarValue(player, "name", "Hellhound")
		printl("[HELLHOUND] Name set to 'Hellhound'")
		
		// Sonido de spawn
		MaoLib_VFX.EmitSound(player, "nz_zombie/hellhound_spawn.wav", 1.0, 100)
		
		// Animaciones base
		NetProps.SetPropInt(player, "m_fFlags", NetProps.GetPropInt(player, "m_fFlags") & ~256)
		NetProps.SetPropIntArray(player, "m_NetGestureSequence", player.LookupSequence("ACT_RUN"), 6)
		NetProps.SetPropIntArray(player, "m_NetGestureActivity", player.LookupActivity("ACT_RUN"), 6)
		NetProps.SetPropFloatArray(player, "m_NetGestureStartTime", Time(), 6)
		printl("[HELLHOUND] Animations set (ACT_RUN)")
		
		printl("[HELLHOUND] === CONVERSION COMPLETE ===")
	}
	
	// ============================================================
	// HELPERS
	// ============================================================
	
	function IsHellhound(player)
	{
		if (!player || !player.IsValid()) return false
		try { player.ValidateScriptScope() } catch (e) { return false }
		return ("IsHellhound" in player.GetScriptScope())
	}
	
	function ApplyBleed(survivor)
	{
		if (!survivor || !survivor.IsValid()) return
		// Delegar al DoT Subsystem de MaoLib
		local SE = ::MaoLib.StatusEffects
		SE.ApplyDoT(survivor, "dot_bleed",
			settings.bleed_damage_per_tick.tofloat(),   // DPS = dmg/tick (tick_interval=1.0)
			settings.bleed_duration,                     // duración
			null)                                         // sin attacker
		printl("[HELLHOUND] Bleed applied to survivor " + survivor.GetEntityIndex() +
			" for " + settings.bleed_duration + "s (DoT Subsystem)")
	}
	
	// ============================================================
	// INTERCEPTAR LUNGE: En vez de montar → Stun + Bleed + Push
	// ============================================================
	
	function OnGameEvent_jockey_ride(params)
	{
		if (!("userid" in params) || !("victim" in params)) return
		
		local hound = GetPlayerFromUserID(params.userid)
		if (!hound || !IsHellhound(hound)) return
		
		local survivor = GetPlayerFromUserID(params.victim)
		if (!survivor || !survivor.IsValid()) return
		
		local houndPos = hound.GetOrigin()
		local survPos = survivor.GetOrigin()
		
		// 1. Stagger survivor — rompe el ride nativamente
		survivor.Stagger(houndPos)
		
		// Sonido de lunge/ataque
		MaoLib_VFX.EmitSound(hound, "nz_zombie/exp0.wav", 1.0, 100)
		
		// 2. Push hound hacia atrás vía NetProps (Teleport no existe en players)
		local dir = houndPos - survPos
		dir.Norm()
		local pushPos = houndPos + dir * settings.hellhound_push_distance
		NetProps.SetPropVector(hound, "m_vecOrigin", pushPos)
		// Velocidad extra para el impulso visual
		NetProps.SetPropVector(hound, "m_vecVelocity", dir * 400)
		
		// 3. Limpiar netprops del ride por seguridad
		NetProps.SetPropEntity(survivor, "m_jockeyAttacker", null)
		
		// 4. Sangrado
		ApplyBleed(survivor)
		
		printl("[HELLHOUND] Ride intercepted — jockey pushed + survivor staggered + bleed")
	}
	
	function OnGameEvent_player_death(params)
	{
		if (!("userid" in params))
		{
			printl("[HELLHOUND] player_death: no userid")
			return
		}
		
		local player = GetPlayerFromUserID(params.userid)
		if (!player || !player.IsValid())
		{
			printl("[HELLHOUND] player_death: invalid player (userid=" + params.userid + ")")
			return
		}
		
		// Detectar script scope
		try { player.ValidateScriptScope() } catch (e) {}
		local sc = player.GetScriptScope()
		if (!sc || !("IsHellhound" in sc))
		{
			// No era un hellhound, ignorar silenciosamente
			return
		}
		
		local attacker = "unknown"
		if ("attacker" in params && params.attacker)
		{
			local atkPlayer = GetPlayerFromUserID(params.attacker)
			if (atkPlayer && atkPlayer.IsValid()) attacker = NetProps.GetPropString(atkPlayer, "m_szName")
		}
		printl("[HELLHOUND] Hellhound DIED! userid=" + params.userid + " attacker=" + attacker + " ztype=" + player.GetZombieType())
		
		// === EXPLOSIÓN DE GORE + DAÑO EN ÁREA ===
		local pos = player.GetOrigin()
		local now = Time()
		local death_idx = player.GetEntityIndex()
		
		// Daño en área a survivors cercanos (15 daño, radio 150)
		local explosion_damage = 15
		local explosion_radius = 150
		local affected = 0
		for (local surv; surv = Entities.FindByClassnameWithin(surv, "player", pos, explosion_radius); )
		{
			if (surv.IsValid() && surv.IsSurvivor() && NetProps.GetPropInt(surv, "m_lifeState") == 0)
			{
				surv.TakeDamage(explosion_damage, (1 << 2), player)
				affected++
			}
		}
		if (affected > 0)
			printl("[HELLHOUND] Gore explosion hit " + affected + " survivors for " + explosion_damage + " damage")
		
		// Partícula: explosión de spitter
		local exp_name = "hh_exp_" + death_idx + "_" + now
		local exp = SpawnEntityFromTable("info_particle_system", {
			targetname = exp_name,
			origin = pos + Vector(0, 0, 16),
			effect_name = "spitter_projectile_explode",
			start_active = 1
		})
		if (exp && exp.IsValid()) {
			EntFire(exp_name, "Stop", "", 0.8)
			EntFire(exp_name, "Kill", "", 1.0)
		}
		
		// Partícula: nube eléctrica ("moscas")
		local bug_name = "hh_bug_" + death_idx + "_" + now
		local bugged = SpawnEntityFromTable("info_particle_system", {
			targetname = bug_name,
			origin = pos + Vector(0, 0, 8),
			effect_name = "bug_zapper_cloud",
			start_active = 1
		})
		if (bugged && bugged.IsValid()) {
			EntFire(bug_name, "Stop", "", 1.3)
			EntFire(bug_name, "Kill", "", 1.5)
		}
		
		// Partícula: sangre amarilla residual
		local blood_name = "hh_blood_" + death_idx + "_" + now
		local blood = SpawnEntityFromTable("info_particle_system", {
			targetname = blood_name,
			origin = pos + Vector(0, 0, 8),
			effect_name = "blood_impact_yellow_01",
			start_active = 1
		})
		if (blood && blood.IsValid()) {
			EntFire(blood_name, "Stop", "", 1.3)
			EntFire(blood_name, "Kill", "", 1.5)
		}
		
		// Screen shake pequeño
		local shake_name = "hh_shake_" + death_idx + "_" + now
		local shake = SpawnEntityFromTable("env_shake", {
			targetname = shake_name,
			amplitude = 6,
			duration = 0.4,
			frequency = 25,
			radius = explosion_radius,
			origin = pos
		})
		if (shake && shake.IsValid())
		{
			EntFire(shake_name, "StartShake", "", 0)
			EntFire(shake_name, "Kill", "", 0.6)
		}
		
		// Sonido
		MaoLib_VFX.EmitSound(player, "nz_zombie/death1.wav", 1.0, RandomInt(90, 110))
		
		// Eliminar cuerpo inmediatamente — patrón probado de referencia original
		// SetOrigin fuera del mapa + Kill() fuerza eliminación del player entity
		// antes de que el engine cree el ragdoll (modelo _sphys_test sin físicas)
		player.SetOrigin(Vector(-10000, -10000, -10000))
		player.Kill()
	}
	
	// ============================================================
	// DEBUG SPAWN
	// Uso: script ::catbor_hellhound.DebugSpawn()
	// Convierte un jockey bot existente en Hellhound
	// ============================================================
	
	function DebugSpawn()
	{
		printl("[HELLHOUND] === DEBUG SPAWN ===")
		
		// Buscar jockey bot existente y convertirlo
		for (local p; p = Entities.FindByClassname(p, "player"); )
		{
			if (!p.IsValid() || !IsPlayerABot(p)) continue
			if (p.GetZombieType() != 5) continue
			
			local idx = p.GetEntityIndex()
			if (idx > 0)
			{
				printl("[HELLHOUND] DebugSpawn: Converting jockey " + idx)
				this.ConvertHellhound(p)
				return "[HELLHOUND] Spawned Hellhound on jockey " + idx
			}
		}
		
		// No hay jockey vivo, armar flag para el próximo spawn
		if (!("debug_force_next" in this))
			this.debug_force_next <- false
		this.debug_force_next = true
		this.debug_force_timeout <- Time() + 30.0
		printl("[HELLHOUND] DebugSpawn armed: next jockey bot spawn will convert")
		return "[HELLHOUND] Armed. Next jockey bot will be a Hellhound"
	}
	
	function OnGameEvent_round_end( params )
	{
		MaoLib.RemoveTimer("hellhound_think")
		// Cleanup DoTs de hellhound
		if ("StatusEffects" in ::MaoLib && "ClearAllDoTs" in ::MaoLib.StatusEffects)
			::MaoLib.StatusEffects.ClearAllDoTs()
	}

	function ParseSettings()
    {
        local SettingsFileName = "hellhounds/config.cfg"
        local file = FileToString(SettingsFileName)
		printl("[HELLHOUND] ParseSettings: reading " + SettingsFileName + " (found=" + (file != null) + ")")

        local tData;
        local function SerializeSettings() {
			printl("[HELLHOUND] ParseSettings: Serializing settings file")
            local sData = "{"
            foreach (key, val in settings) {
                if (typeof(val) == "string") {
                    val = "\"" + val + "\""
                } else if (typeof(val) == "array") {
                    local newValue = "["
                    for (local i = 0; i < val.len(); i++) {
                        if (typeof(val[i]) == "string") {
                            newValue += "\"" + val[i] + "\""
                        } else {
                            newValue += val[i].tostring()
                        }
                        if (i < val.len() - 1) {
                            newValue += ", "
                        }
                    }
                    newValue += "]"
                    val = newValue
                }
                sData += "\n\t" + key + " = " + val
            }
            sData += "\n}"
            StringToFile(SettingsFileName, sData)
			printl("[HELLHOUND] ParseSettings: File saved to " + SettingsFileName)
        }
        if (tData = file){
            try {
                tData = MaoLib.ParseConfigString(tData)
                local hasMissingKey = false
                foreach (key, val in settings){
                    if (key in tData){
                        settings[key] = tData[key]
						printl("[HELLHOUND] ParseSettings: Loaded " + key + " = " + tData[key])
                    }
                    else if (!hasMissingKey){
                        hasMissingKey = true
                    }
                }
                if (hasMissingKey)
                {
					printl("[HELLHOUND] ParseSettings: Missing keys found, rewriting")
					SerializeSettings()
				}
            }
            catch (error) {
				printl("[HELLHOUND] ParseSettings ERROR: " + error)
                SerializeSettings()
            }
        }
        else{
			printl("[HELLHOUND] ParseSettings: No file found, creating defaults")
            SerializeSettings();
        }
    }

}
__CollectGameEventCallbacks(catbor_hellhound)
printl("[HELLHOUND] About to parse settings...")
catbor_hellhound.ParseSettings()
printl("[HELLHOUND] Settings loaded: health=" + catbor_hellhound.settings.hellhound_health + " chance=" + catbor_hellhound.settings.hellhound_chance + " speed=" + catbor_hellhound.settings.hellhound_speed)
printl("[HELLHOUND] Script loaded successfully — Lost 4 Creed")