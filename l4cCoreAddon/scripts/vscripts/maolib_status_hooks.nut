// maolib_status_hooks.nut — Automatic Event Hooks v2.0 (Minimalist)
// Intercepta eventos del engine y aplica efectos registrados en MaoLib.StatusEffects
//
// Maneja: player_hurt, weapon_fire, entity_shoved, player_shoved, heal_success, pills_used
// ⚠️ CRÍTICO: Usa _processingDamageEvent para evitar recursión infinita en player_hurt

if ("MaoLib_StatusHooks_init_guard" in getroottable()) return;
getroottable()["MaoLib_StatusHooks_init_guard"] <- true;

::MaoLib.StatusHooks <- {
	Debug = 1

	function Dbg(msg) {
		if (Debug) printl("[StatusHooks][DBG] " + msg)
	}

	// ============================================================
	// GUARDA GLOBAL: Previene recursión infinita de daño
	// Una sola flag para AMBOS eventos (player_hurt + infected_hurt)
	// porque AoE de uno puede disparar el otro.
	// ============================================================
	_processingDamageEvent = false

	// ============================================================
	// PLAYER HURT
	// ============================================================
	function OnGameEvent_player_hurt(params)
	{
		if (this._processingDamageEvent) return
		if (!("userid" in params) || !("attacker" in params) || !("dmg_health" in params)) return

		local victim = GetPlayerFromUserID(params.userid)
		if (!victim || !victim.IsValid()) return

		local attacker = null
		if (params.attacker > 0) {
			attacker = GetPlayerFromUserID(params.attacker)
			if (!attacker || !attacker.IsValid()) {
				attacker = EntIndexToHScript(params.attacker)
			}
		}

		local dmgHealth = params.dmg_health
		if (dmgHealth <= 0) return

		local dmgType = ("type" in params) ? params.type : 0

		this._processingDamageEvent = true

		// --- VÍCTIMA: damage_in mitigation ---
		if (victim.IsPlayer()) {
			local dmgInMult = ::MaoLib.StatusEffects.Get(victim, "damage_in")
			if (dmgInMult < 1.0) {
				local mitigated = dmgHealth * (1.0 - dmgInMult)
				if (mitigated > 0) {
					local newHp = victim.GetHealth() + mitigated.tointeger()
					if (newHp > victim.GetMaxHealth()) newHp = victim.GetMaxHealth()
					victim.SetHealth(newHp)
					this.Dbg("damage_in mitigated: " + mitigated + " newHp=" + newHp)
				}
			} else if (dmgInMult > 1.0) {
				// Amplificación: daño extra
				local extraDmg = dmgHealth * (dmgInMult - 1.0)
				if (extraDmg > 0) {
					local atk = (attacker && attacker.IsValid()) ? attacker : victim
					victim.TakeDamage(extraDmg.tointeger(), dmgType, atk)
					this.Dbg("damage_in amplified: +" + extraDmg)
				}
			}

			// --- VÍCTIMA: fire_immunity ---
			if ((dmgType & 8) != 0) { // DMG_BURN = 8
				local fireImmune = ::MaoLib.StatusEffects.Get(victim, "fire_immunity")
				if (fireImmune >= 1.0) {
					local newHp = victim.GetHealth() + dmgHealth
					if (newHp > victim.GetMaxHealth()) newHp = victim.GetMaxHealth()
					victim.SetHealth(newHp)
					this.Dbg("fire_immunity: healed " + dmgHealth)
				}
			}
		}

		// --- ATTACKER: damage_out bonus ---
		if (attacker && attacker.IsValid() && attacker.IsPlayer() && attacker != victim) {
			local dmgOutMult = ::MaoLib.StatusEffects.Get(attacker, "damage_out")
			if (dmgOutMult > 1.0) {
				local bonusDmg = dmgHealth * (dmgOutMult - 1.0)
				if (bonusDmg > 0 && victim.IsValid()) {
					victim.TakeDamage(bonusDmg.tointeger(), 2, attacker)
					this.Dbg("damage_out bonus: +" + bonusDmg)
				}
			}

			// --- ATTACKER: lifesteal ---
			local lifesteal = ::MaoLib.StatusEffects.Get(attacker, "lifesteal")
			if (lifesteal > 0) {
				local heal = dmgHealth * lifesteal
				if (heal > 0) {
					local newHp = attacker.GetHealth() + heal.tointeger()
					if (newHp > attacker.GetMaxHealth()) newHp = attacker.GetMaxHealth()
					attacker.SetHealth(newHp)
					this.Dbg("lifesteal: heal=" + heal)
				}
			}
		}

		this._processingDamageEvent = false
	}

	// ============================================================
	// INFECTED HURT (para damage_out en CI también)
	// ============================================================
	function OnGameEvent_infected_hurt(params)
	{
		if (this._processingDamageEvent) return
		if (!("entityid" in params) || !("attacker" in params) || !("amount" in params)) return
		if (!params.attacker) return

		local attacker = GetPlayerFromUserID(params.attacker)
		if (!attacker || !attacker.IsValid() || !attacker.IsPlayer()) return

		local infected = EntIndexToHScript(params.entityid)
		if (!infected || !infected.IsValid()) return

		local amount = params.amount
		if (amount <= 0) return

		this._processingDamageEvent = true

		// --- ATTACKER: damage_out bonus ---
		local dmgOutMult = ::MaoLib.StatusEffects.Get(attacker, "damage_out")
		if (dmgOutMult > 1.0) {
			local bonusDmg = amount * (dmgOutMult - 1.0)
			if (bonusDmg > 0) {
				infected.TakeDamage(bonusDmg.tointeger(), 2, attacker)
				this.Dbg("damage_out (CI): +" + bonusDmg)
			}
		}

		// --- ATTACKER: lifesteal ---
		local lifesteal = ::MaoLib.StatusEffects.Get(attacker, "lifesteal")
		if (lifesteal > 0) {
			local heal = amount * lifesteal
			if (heal > 0) {
				local newHp = attacker.GetHealth() + heal.tointeger()
				if (newHp > attacker.GetMaxHealth()) newHp = attacker.GetMaxHealth()
				attacker.SetHealth(newHp)
				this.Dbg("lifesteal (CI): heal=" + heal)
			}
		}

		this._processingDamageEvent = false
	}

	// ============================================================
	// WEAPON FIRE
	// ============================================================
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

		// --- FIRE RATE ---
		if (!isMelee) {
			local fireRateMult = ::MaoLib.StatusEffects.Get(player, "fire_rate")
			if (fireRateMult != 1.0) {
				local nextAttack = NetProps.GetPropFloat(activeWep, "m_flNextPrimaryAttack")
				local remaining = nextAttack - now
				if (remaining > 0) {
					local newRemaining = remaining / fireRateMult
					NetProps.SetPropFloat(activeWep, "m_flNextPrimaryAttack", now + newRemaining)
					if (fireRateMult > 0)
						NetProps.SetPropFloat(activeWep, "m_flPlaybackRate", fireRateMult)
					this.Dbg("fire_rate: mult=" + fireRateMult)
				}
			}
		}

		// --- MELEE SPEED ---
		if (isMelee) {
			local meleeSpeedMult = ::MaoLib.StatusEffects.Get(player, "melee_speed")
			if (meleeSpeedMult != 1.0) {
				local nextAttack = NetProps.GetPropFloat(activeWep, "m_flNextPrimaryAttack")
				local remaining = nextAttack - now
				if (remaining > 0) {
					local newRemaining = remaining / meleeSpeedMult
					NetProps.SetPropFloat(activeWep, "m_flNextPrimaryAttack", now + newRemaining)
					this.Dbg("melee_speed: mult=" + meleeSpeedMult)
				}
			}
		}
	}

	// ============================================================
	// ENTITY SHOVED
	// ============================================================
	function OnGameEvent_entity_shoved(params)
	{
		if ("userid" in params) {
			local victim = GetPlayerFromUserID(params.userid)
			if (victim && victim.IsValid() && victim.IsPlayer()) {
				local immune = ::MaoLib.StatusEffects.Get(victim, "stagger_immunity")
				if (immune >= 1.0) {
					try {
						NetProps.SetPropFloatArray(victim, "m_staggerTimer", -1.0, 1)
						this.Dbg("stagger_immunity cleared")
					} catch(e) {}
				}
			}
		}
	}

	// ============================================================
	// PLAYER SHOVED
	// ============================================================
	function OnGameEvent_player_shoved(params)
	{
		if (!("userid" in params)) return
		local victim = GetPlayerFromUserID(params.userid)
		if (!victim || !victim.IsValid() || !victim.IsPlayer()) return

		local immune = ::MaoLib.StatusEffects.Get(victim, "stagger_immunity")
		if (immune >= 1.0) {
			try {
				NetProps.SetPropFloatArray(victim, "m_staggerTimer", -1.0, 1)
				this.Dbg("stagger_immunity (player_shoved) cleared")
			} catch(e) {}
		}
	}

	// ============================================================
	// HEAL SUCCESS
	// ============================================================
	function OnGameEvent_heal_success(params)
	{
		if (!("userid" in params) || !("subject" in params)) return
		local healer = GetPlayerFromUserID(params.userid)
		local healed = GetPlayerFromUserID(params.subject)

		// heal_given bonus
		if (healer && healer.IsValid() && healer.IsPlayer() &&
		    healed && healed.IsValid() && healed.IsPlayer()) {
			local healGivenMult = ::MaoLib.StatusEffects.Get(healer, "damage_out") // Usamos damage_out como proxy
			if (healGivenMult > 1.0) {
				local bonus = 15 * (healGivenMult - 1.0)
				if (bonus > 0) {
					local buf = healed.GetHealthBuffer()
					healed.SetHealthBuffer(buf + bonus.tointeger())
					this.Dbg("heal_given bonus: " + bonus)
				}
			}
		}
	}

	// ============================================================
	// PILLS USED
	// ============================================================
	function OnGameEvent_pills_used(params)
	{
		local player = null
		if ("subject" in params)
			player = GetPlayerFromUserID(params.subject)
		else if ("userid" in params)
			player = GetPlayerFromUserID(params.userid)

		if (!player || !player.IsValid() || !player.IsPlayer()) return

		// No aplicamos nada por ahora — los buffs de items se manejan en item_buffs.nut
	}

	// ============================================================
	// ROUND CLEANUP
	// ============================================================
	function OnGameEvent_round_end(params)
	{
		if ("StatusEffects" in ::MaoLib) {
			::MaoLib.StatusEffects.ClearAllDoTs()
		}
		this._processingDamageEvent = false
	}

	function OnGameEvent_mission_lost(params)
	{
		if ("StatusEffects" in ::MaoLib) {
			::MaoLib.StatusEffects.ClearAllDoTs()
		}
	}

	function OnGameEvent_map_transition(params)
	{
		if ("StatusEffects" in ::MaoLib) {
			::MaoLib.StatusEffects.ClearAllDoTs()
		}
	}
}

__CollectGameEventCallbacks(::MaoLib.StatusHooks)
printl("[MaoLib.StatusHooks] v2.0 Minimalist loaded")
