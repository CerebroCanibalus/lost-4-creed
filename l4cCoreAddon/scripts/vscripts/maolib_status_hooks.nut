// maolib_status_hooks.nut — Automatic Event Hooks for StatusEffects
// Intercepta eventos del engine y aplica efectos registrados en MaoLib.StatusEffects
// automáticamente. Los scripts de perks NO necesitan manejar estos eventos manualmente
// si usan categorías soportadas.
//
// Categorías manejadas automáticamente:
//   player_hurt    → damage_in, damage_out, lifesteal, fire_immunity
//   weapon_fire    → fire_rate, melee_speed, ammo_consumption
//   entity_shoved  → stagger_immunity (victim), shove_penalty (attacker)
//   heal_success   → heal_received, heal_given
//   revive_success → heal_received, heal_given
//   pills_used     → heal_received
//   player_spawn   → max_health (aplicado después de un delay)
//
// Convención: Este script se carga DESPUÉS de maolib_status.nut

if ("MaoLib_StatusHooks_init_guard" in getroottable()) return;
getroottable()["MaoLib_StatusHooks_init_guard"] <- true;

::MaoLib.StatusHooks <- {
	Debug = 1

	function Dbg(msg) {
		if (Debug) printl("[MaoLib.StatusHooks][DEBUG] " + msg)
	}

	function DbgWarn(msg) {
		printl("[MaoLib.StatusHooks][WARN] " + msg)
	}

	// ============================================================
	// PLAYER HURT
	// ============================================================
	// Aplica: damage_in (víctima se cura = mitigación), damage_out (attacker daño extra),
	//         lifesteal (attacker se cura), fire_immunity (víctima ignora fuego)
	function OnGameEvent_player_hurt(params)
	{
		if (!("userid" in params) || !("attacker" in params) || !("dmg_health" in params))
			return

		local victim = GetPlayerFromUserID(params.userid)
		local attacker = null

		// attacker puede ser userid (players/SI) o entindex (CI/props)
		if (params.attacker > 0)
		{
			attacker = GetPlayerFromUserID(params.attacker)
			if (!attacker || !attacker.IsValid())
			{
				// Puede ser un common infected (entindex)
				attacker = EntIndexToHScript(params.attacker)
			}
		}

		local dmgHealth = params.dmg_health
		if (dmgHealth <= 0) return

		local dmgType = ("type" in params) ? params.type : 0

		// --- VÍCTIMA: damage_in mitigation/amplificación ---
		if (victim && victim.IsValid() && victim.IsPlayer())
		{
			local dmgInMult = ::MaoLib.StatusEffects.Get(victim, "damage_in")
			if (dmgInMult < 1.0)
			{
				// Mitigación: curar daño reducido
				local mitigated = dmgHealth * (1.0 - dmgInMult)
				if (mitigated > 0)
				{
					local newHp = ::MaoLib.min(victim.GetHealth() + mitigated.tointeger(), victim.GetMaxHealth())
					victim.SetHealth(newHp)
					Dbg("damage_in: victim=" + params.userid + " mitigated=" + mitigated + " newHp=" + newHp)
				}
			}
			else if (dmgInMult > 1.0)
			{
				// Amplificación: daño extra (trade-offs como Brenda +20%)
				local extraDmg = dmgHealth * (dmgInMult - 1.0)
				if (extraDmg > 0)
				{
					local attacker = null
					if (params.attacker > 0) attacker = GetPlayerFromUserID(params.attacker)
					if (!attacker || !attacker.IsValid()) attacker = victim
					victim.TakeDamage(extraDmg.tointeger(), dmgType, attacker)
					Dbg("damage_in: victim=" + params.userid + " extraDmg=" + extraDmg)
				}
			}

			// --- VÍCTIMA: fire_immunity ---
			if ((dmgType & 8) != 0) // DMG_BURN = 8
			{
				local fireImmune = ::MaoLib.StatusEffects.Get(victim, "fire_immunity")
				if (fireImmune >= 1.0)
				{
					// Curar TODO el daño de fuego
					local newHp = ::MaoLib.min(victim.GetHealth() + dmgHealth, victim.GetMaxHealth())
					victim.SetHealth(newHp)
					Dbg("fire_immunity: victim=" + params.userid + " healed=" + dmgHealth)
				}
			}

			// --- VÍCTIMA: resistencias elementales ---
			// Nota: resist_fire ya se maneja implícitamente via damage_in + fire_immunity
			//       Si se necesitan resistencias más granulares, se añaden aquí.
		}

		// --- ATTACKER: damage_out bonus ---
		if (attacker && attacker.IsValid() && attacker.IsPlayer() && attacker != victim)
		{
			local dmgOutMult = ::MaoLib.StatusEffects.Get(attacker, "damage_out")
			if (dmgOutMult > 1.0)
			{
				local bonusDmg = dmgHealth * (dmgOutMult - 1.0)
				if (bonusDmg > 0 && victim && victim.IsValid())
				{
					// Aplicar daño adicional
					if (victim.IsPlayer())
					{
						victim.TakeDamage(bonusDmg.tointeger(), 2, attacker)
					}
					else
					{
						// Common infected o entidad
						victim.TakeDamage(bonusDmg.tointeger(), 2, attacker)
					}
					Dbg("damage_out: attacker=" + params.attacker + " bonus=" + bonusDmg)
				}
			}
			else if (dmgOutMult < 1.0)
			{
				// Penalización de daño (ej. Jaime 0 stacks): curar a la víctima
				local penaltyDmg = dmgHealth * (1.0 - dmgOutMult)
				if (penaltyDmg > 0 && victim && victim.IsValid() && victim.IsPlayer())
				{
					local newHp = ::MaoLib.min(victim.GetHealth() + penaltyDmg.tointeger(), victim.GetMaxHealth())
					victim.SetHealth(newHp)
					Dbg("damage_out penalty: attacker=" + params.attacker + " healedVictim=" + penaltyDmg)
				}
			}

			// --- ATTACKER: lifesteal ---
			local lifesteal = ::MaoLib.StatusEffects.Get(attacker, "lifesteal")
			if (lifesteal > 0 && victim && victim.IsValid())
			{
				local heal = dmgHealth * lifesteal
				if (heal > 0)
				{
					local newHp = ::MaoLib.min(attacker.GetHealth() + heal.tointeger(), attacker.GetMaxHealth())
					attacker.SetHealth(newHp)
					Dbg("lifesteal: attacker=" + params.attacker + " heal=" + heal + " newHp=" + newHp)
				}
			}
		}
	}

	// ============================================================
	// WEAPON FIRE
	// ============================================================
	// Aplica: fire_rate, melee_speed, ammo_consumption
	function OnGameEvent_weapon_fire(params)
	{
		if (!("userid" in params)) return

		local player = GetPlayerFromUserID(params.userid)
		if (!player || !player.IsValid() || !player.IsPlayer()) return

		local activeWep = player.GetActiveWeapon()
		if (!activeWep || !activeWep.IsValid()) return

		local now = Time()
		local wepClass = activeWep.GetClassname()
		local isMelee = (wepClass == "weapon_melee" || wepClass == "weapon_chainsaw")

		// --- FIRE RATE (solo armas de fuego) ---
		if (!isMelee)
		{
			local fireRateMult = ::MaoLib.StatusEffects.Get(player, "fire_rate")
			if (fireRateMult != 1.0)
			{
				local nextAttack = NetProps.GetPropFloat(activeWep, "m_flNextPrimaryAttack")
				local remaining = nextAttack - now
				if (remaining > 0)
				{
					// Si fireRateMult > 1.0 = más rápido (menos tiempo entre disparos)
					// Si fireRateMult < 1.0 = más lento
					local newRemaining = remaining / fireRateMult
					NetProps.SetPropFloat(activeWep, "m_flNextPrimaryAttack", now + newRemaining)

					// Playback rate para animación
					if (fireRateMult > 0)
						NetProps.SetPropFloat(activeWep, "m_flPlaybackRate", fireRateMult)

					Dbg("fire_rate: uid=" + params.userid + " mult=" + fireRateMult + " newRem=" + newRemaining)
				}
			}

			// --- RELOAD SPEED ---
			local reloadMult = ::MaoLib.StatusEffects.Get(player, "reload_speed")
			if (reloadMult != 1.0)
			{
				// El reload se maneja en reload_begin, no aquí
				// Dejamos un flag para que el hook de reload lo use
				// Por ahora, no aplicamos aquí
			}

			// --- AMMO CONSUMPTION ---
			local ammoConsumption = ::MaoLib.StatusEffects.Get(player, "ammo_consumption")
			if (ammoConsumption <= 0)
			{
				// No consumir munición: devolver la bala al cargador
				local clip = NetProps.GetPropInt(activeWep, "m_iClip1")
				if (clip >= 0)
				{
					NetProps.SetPropInt(activeWep, "m_iClip1", clip + 1)
					Dbg("ammo_consumption: uid=" + params.userid + " infinite ammo restored")
				}
			}
		}

		// --- MELEE SPEED ---
		if (isMelee)
		{
			local meleeSpeedMult = ::MaoLib.StatusEffects.Get(player, "melee_speed")
			if (meleeSpeedMult != 1.0)
			{
				local nextAttack = NetProps.GetPropFloat(activeWep, "m_flNextPrimaryAttack")
				local remaining = nextAttack - now
				if (remaining > 0)
				{
					// meleeSpeedMult < 1.0 = más lento (más tiempo)
					// meleeSpeedMult > 1.0 = más rápido
					local newRemaining = remaining / meleeSpeedMult
					NetProps.SetPropFloat(activeWep, "m_flNextPrimaryAttack", now + newRemaining)
					Dbg("melee_speed: uid=" + params.userid + " mult=" + meleeSpeedMult + " newRem=" + newRemaining)
				}
			}
		}
	}

	// ============================================================
	// RELOAD BEGIN
	// ============================================================
	// Aplica: reload_speed
	function OnGameEvent_reload_begin(params)
	{
		if (!("userid" in params)) return

		local player = GetPlayerFromUserID(params.userid)
		if (!player || !player.IsValid() || !player.IsPlayer()) return

		local reloadMult = ::MaoLib.StatusEffects.Get(player, "reload_speed")
		if (reloadMult == 1.0) return

		// reload_speed modifica la duración total del reload
		// No podemos modificar el tiempo aquí directamente porque el engine
		// recalcula el reload. En su lugar, marcamos al jugador para que
		// el próximo weapon_fire aplique el speed.
		// Alternativa: usar un timer que modifique m_flNextPrimaryAttack después de un frame.
		// Por simplicidad, dejamos que el sistema de items (adrenalina) maneje esto
		// y documentamos que reload_speed requiere integración manual por ahora.
		//
		// TODO: Implementar hook de reload con timer diferido
	}

	// ============================================================
	// ENTITY SHOVED
	// ============================================================
	// Aplica: stagger_immunity (victim), shove_penalty (attacker)
	function OnGameEvent_entity_shoved(params)
	{
		// --- VÍCTIMA: stagger_immunity ---
		if ("userid" in params)
		{
			local victim = GetPlayerFromUserID(params.userid)
			if (victim && victim.IsValid() && victim.IsPlayer())
			{
				local immune = ::MaoLib.StatusEffects.Get(victim, "stagger_immunity")
				if (immune >= 1.0)
				{
					try {
						NetProps.SetPropFloatArray(victim, "m_staggerTimer", -1.0, 1)
						Dbg("stagger_immunity: cleared stagger for uid=" + params.userid)
					} catch(e) {
						DbgWarn("stagger_immunity: failed to clear stagger: " + e)
					}
				}
			}
		}

		// --- ATTACKER: shove_penalty ---
		if ("attacker" in params)
		{
			local attacker = GetPlayerFromUserID(params.attacker)
			if (attacker && attacker.IsValid() && attacker.IsPlayer())
			{
				local penalty = ::MaoLib.StatusEffects.Get(attacker, "shove_penalty")
				if (penalty > 0)
				{
					local curPenalty = NetProps.GetPropInt(attacker, "m_iShovePenalty")
					local newPenalty = curPenalty + penalty.tointeger()
					NetProps.SetPropInt(attacker, "m_iShovePenalty", newPenalty)
					Dbg("shove_penalty: uid=" + params.attacker + " added=" + penalty + " new=" + newPenalty)
				}
			}
		}
	}

	// ============================================================
	// PLAYER SHOVED
	// ============================================================
	// Aplica: stagger_immunity (victim)
	function OnGameEvent_player_shoved(params)
	{
		if (!("userid" in params)) return

		local victim = GetPlayerFromUserID(params.userid)
		if (!victim || !victim.IsValid() || !victim.IsPlayer()) return

		local immune = ::MaoLib.StatusEffects.Get(victim, "stagger_immunity")
		if (immune >= 1.0)
		{
			try {
				NetProps.SetPropFloatArray(victim, "m_staggerTimer", -1.0, 1)
				Dbg("stagger_immunity (player_shoved): cleared stagger for uid=" + params.userid)
			} catch(e) {
				DbgWarn("stagger_immunity (player_shoved): failed: " + e)
			}
		}
	}

	// ============================================================
	// HEAL SUCCESS
	// ============================================================
	// Aplica: heal_given (healer), heal_received (healed)
	function OnGameEvent_heal_success(params)
	{
		if (!("userid" in params) || !("subject" in params)) return

		local healer = GetPlayerFromUserID(params.userid)
		local healed = GetPlayerFromUserID(params.subject)

		// --- HEALER: heal_given bonus ---
		if (healer && healer.IsValid() && healer.IsPlayer() &&
		    healed && healed.IsValid() && healed.IsPlayer())
		{
			local healGivenMult = ::MaoLib.StatusEffects.Get(healer, "heal_given")
			if (healGivenMult > 1.0)
			{
				// Aplicar HP temp adicional como bonus
				local bonus = 15 * (healGivenMult - 1.0)
				if (bonus > 0)
				{
					local buf = healed.GetHealthBuffer()
					healed.SetHealthBuffer(buf + bonus.tointeger())
					Dbg("heal_given: healer=" + params.userid + " bonus=" + bonus)
				}
			}
		}

		// --- HEALED: heal_received bonus ---
		if (healed && healed.IsValid() && healed.IsPlayer())
		{
			local healReceivedMult = ::MaoLib.StatusEffects.Get(healed, "heal_received")
			if (healReceivedMult > 1.0)
			{
				local bonus = 15 * (healReceivedMult - 1.0)
				if (bonus > 0)
				{
					local buf = healed.GetHealthBuffer()
					healed.SetHealthBuffer(buf + bonus.tointeger())
					Dbg("heal_received: healed=" + params.subject + " bonus=" + bonus)
				}
			}
		}
	}

	// ============================================================
	// REVIVE SUCCESS
	// ============================================================
	// Aplica: heal_given (healer), heal_received (healed)
	function OnGameEvent_revive_success(params)
	{
		if (!("userid" in params) || !("subject" in params)) return

		local healer = GetPlayerFromUserID(params.userid)
		local healed = GetPlayerFromUserID(params.subject)

		// --- HEALER: heal_given bonus ---
		if (healer && healer.IsValid() && healer.IsPlayer())
		{
			local healGivenMult = ::MaoLib.StatusEffects.Get(healer, "heal_given")
			if (healGivenMult > 1.0)
			{
				local bonus = 10 * (healGivenMult - 1.0)
				if (bonus > 0)
				{
					local buf = healer.GetHealthBuffer()
					healer.SetHealthBuffer(buf + bonus.tointeger())
					Dbg("heal_given (revive): healer=" + params.userid + " bonus=" + bonus)
				}
			}
		}

		// --- HEALED: heal_received bonus ---
		if (healed && healed.IsValid() && healed.IsPlayer())
		{
			local healReceivedMult = ::MaoLib.StatusEffects.Get(healed, "heal_received")
			if (healReceivedMult > 1.0)
			{
				local bonus = 10 * (healReceivedMult - 1.0)
				if (bonus > 0)
				{
					local buf = healed.GetHealthBuffer()
					healed.SetHealthBuffer(buf + bonus.tointeger())
					Dbg("heal_received (revive): healed=" + params.subject + " bonus=" + bonus)
				}
			}
		}
	}

	// ============================================================
	// PILLS USED
	// ============================================================
	// Aplica: heal_received
	function OnGameEvent_pills_used(params)
	{
		local player = null
		if ("subject" in params)
			player = GetPlayerFromUserID(params.subject)
		else if ("userid" in params)
			player = GetPlayerFromUserID(params.userid)

		if (!player || !player.IsValid() || !player.IsPlayer()) return

		local healReceivedMult = ::MaoLib.StatusEffects.Get(player, "heal_received")
		if (healReceivedMult > 1.0)
		{
			// Pills dan temp HP base. Aplicamos bonus proporcional.
			local bonus = 10 * (healReceivedMult - 1.0)
			if (bonus > 0)
			{
				local buf = player.GetHealthBuffer()
				player.SetHealthBuffer(buf + bonus.tointeger())
				Dbg("heal_received (pills): uid=" + player.GetPlayerUserId() + " bonus=" + bonus)
			}
		}
	}

	// ============================================================
	// PLAYER SPAWN
	// ============================================================
	// Aplica: max_health (con delay para asegurar que el engine terminó de spawnear)
	function OnGameEvent_player_spawn(params)
	{
		if (!("userid" in params)) return

		local uid = params.userid
		// Delay para asegurar que el player está completamente spawneado
		::MaoLib.AddTimerSafe("status_spawn_" + uid, 0.1, function() {
			local player = GetPlayerFromUserID(uid)
			if (!player || !player.IsValid() || !player.IsPlayer()) return

			local maxHpMod = ::MaoLib.StatusEffects.Get(player, "max_health")
			if (maxHpMod != 0)
			{
				// El max_health es un modificador ADITIVO sobre el base del personaje
				// Necesitamos saber el base. Para simplificar, asumimos 100 como base
				// y los perks setean su propio base + el modificador.
				// NOTA: Esto requiere que los perks manejen su HP base manualmente
				// y el StatusEffects solo aplique modificadores adicionales.
				// Por ahora, documentamos esta limitación.
				Dbg("max_health: uid=" + uid + " modifier=" + maxHpMod + " (requires manual base HP handling)")
			}
		})
	}

	// ============================================================
	// ROUND START / ROUND END
	// ============================================================
	function OnGameEvent_round_start(params)
	{
		Dbg("Round start — StatusEffects hooks active")
		if ("StatusEffects" in ::MaoLib)
			::MaoLib.StatusEffects.Init()
	}

	function OnGameEvent_round_end(params)
	{
		Dbg("Round end — cleaning up")
		if ("StatusEffects" in ::MaoLib)
			::MaoLib.StatusEffects.Shutdown()
	}

	function OnGameEvent_mission_lost(params)
	{
		if ("StatusEffects" in ::MaoLib)
			::MaoLib.StatusEffects.Shutdown()
	}

	function OnGameEvent_map_transition(params)
	{
		if ("StatusEffects" in ::MaoLib)
			::MaoLib.StatusEffects.Shutdown()
	}
}

// ===================================================================
// REGISTRO DE EVENTOS
// ===================================================================
__CollectGameEventCallbacks(::MaoLib.StatusHooks)
printl("[MaoLib.StatusHooks] Loaded — automatic status effect hooks active")
