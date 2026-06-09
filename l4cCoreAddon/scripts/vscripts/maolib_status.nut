// maolib_status.nut — Status Effects v2.0 (Minimalist)
// Sistema ultra-simplificado de buffs/debuffs.
//
// API:
//   MaoLib.StatusEffects.Apply(player, type, value, duration=-1, source="generic")
//   MaoLib.StatusEffects.Get(player, type) → valor combinado
//   MaoLib.StatusEffects.Remove(player, type, source="")
//   MaoLib.StatusEffects.ClearAll(player)
//   MaoLib.StatusEffects.ApplyDoT(victim, type, dps, duration, attacker)
//   MaoLib.StatusEffects.RemoveDoT(victim, type)
//
// Convención: Movimiento (speed/friction) → MaoLib.Modifiers
//             Todo lo demás → MaoLib.StatusEffects

if ("MaoLib_Status_init_guard" in getroottable()) return;
getroottable()["MaoLib_Status_init_guard"] <- true;

::MaoLib.StatusEffects <- {
	// ============================================================
	// CONFIG — Solo tipos que USAMOS
	// ============================================================
	Debug = 1

	// Tipo: { default, combine }
	// combine: "multiply" | "add" | "max"
	Types = {
		damage_out       = { def = 1.0, combine = "multiply" },
		damage_in        = { def = 1.0, combine = "multiply" },
		fire_rate        = { def = 1.0, combine = "multiply" },
		reload_speed     = { def = 1.0, combine = "multiply" },
		melee_speed      = { def = 1.0, combine = "multiply" },
		move_speed       = { def = 1.0, combine = "multiply" },
		lifesteal        = { def = 0.0, combine = "replace" },
		stagger_immunity = { def = 0,   combine = "max"      },
		fire_immunity    = { def = 0,   combine = "max"      },
	}

	// Data[entindex][type][source] = { value, expire }
	Data = {}

	// DoT timers: DoTTimers[entindex][type] = timerName
	DoTTimers = {}

	// ============================================================
	// DEBUG
	// ============================================================
	function Dbg(msg) {
		if (Debug) printl("[Status][DBG] " + msg)
	}
	function DbgWarn(msg) {
		printl("[Status][WARN] " + msg)
	}

	// ============================================================
	// APPLY
	// ============================================================
	function Apply(player, type, value, duration = -1, source = "generic")
	{
		if (!player || !player.IsValid() || !player.IsPlayer()) return false
		if (!(type in Types)) { DbgWarn("unknown type: " + type); return false }

		local uid = player.entindex().tostring()
		if (!(uid in Data)) Data[uid] <- {}
		if (!(type in Data[uid])) Data[uid][type] <- {}

		Data[uid][type][source] <- {
			value = value.tofloat(),
			expire = (duration < 0) ? -1.0 : (Time() + duration)
		}

		Dbg("APPLY " + type + "=" + value + " src=" + source + " dur=" + duration)
		return true
	}

	// ============================================================
	// GET
	// ============================================================
	function Get(player, type)
	{
		if (!player || !player.IsValid()) return _GetDefault(type)
		local uid = player.entindex().tostring()
		if (!(uid in Data) || !(type in Data[uid])) return _GetDefault(type)

		_CleanupExpired(uid, type)
		if (Data[uid][type].len() == 0) return _GetDefault(type)

		local rule = Types[type].combine
		local def = Types[type].def

		switch (rule) {
			case "multiply": {
				local r = def
				foreach (_, entry in Data[uid][type]) r *= entry.value
				return r
			}
			case "add": {
				local r = def
				foreach (_, entry in Data[uid][type]) r += entry.value
				return r
			}
			case "max": {
				local r = def
				foreach (_, entry in Data[uid][type])
					if (entry.value > r) r = entry.value
				return r
			}
			case "replace": {
				// Último valor (mayor expire time, o -1 = permanente)
				local latest = null
				local latestTime = -999
				foreach (_, entry in Data[uid][type]) {
					local t = entry.expire
					if (t < 0) t = 999999
					if (t > latestTime) { latestTime = t; latest = entry.value }
				}
				return latest != null ? latest : def
			}
			default: return def
		}
	}

	// ============================================================
	// REMOVE
	// ============================================================
	function Remove(player, type, source = "")
	{
		if (!player || !player.IsValid()) return false
		local uid = player.entindex().tostring()
		if (!(uid in Data) || !(type in Data[uid])) return false

		if (source == "") {
			// Remove ALL sources of this type
			delete Data[uid][type]
		} else if (source in Data[uid][type]) {
			delete Data[uid][type][source]
		}

		if (Data[uid][type].len() == 0) delete Data[uid][type]
		if (Data[uid].len() == 0) delete Data[uid]
		return true
	}

	// ============================================================
	// CLEAR ALL
	// ============================================================
	function ClearAll(player)
	{
		if (!player || !player.IsValid()) return false
		local uid = player.entindex().tostring()
		if (uid in Data) delete Data[uid]
		// Limpiar DoTs también
		if (uid in DoTTimers) {
			foreach (type, timerName in DoTTimers[uid]) {
				::MaoLib.RemoveTimer(timerName)
			}
			delete DoTTimers[uid]
		}
		return true
	}

	// ============================================================
	// DoT (Damage over Time) — Simple timer-based
	// ============================================================
	function ApplyDoT(victim, type, dps, duration, attacker)
	{
		if (!victim || !victim.IsValid()) return false
		if (dps <= 0 || duration <= 0) return false

		local uid = victim.entindex().tostring()
		local timerName = "dot_" + type + "_" + uid

		// Remover DoT anterior del mismo tipo
		RemoveDoT(victim, type)

		local endTime = Time() + duration
		local tickDmg = dps  // Daño por segundo (tick de 1.0s)

		Dbg("DoT START: " + type + " dps=" + dps + " dur=" + duration + " on " + uid)

		::MaoLib.AddTimer(timerName, 1.0, function() {
			if (!victim || !victim.IsValid()) {
				::MaoLib.RemoveTimer(timerName)
				return
			}
			if (NetProps.GetPropInt(victim, "m_lifeState") != 0) {
				::MaoLib.RemoveTimer(timerName)
				return
			}
			if (Time() >= endTime) {
				::MaoLib.RemoveTimer(timerName)
				return
			}
			// Aplicar daño
			local atk = (attacker && attacker.IsValid()) ? attacker : victim
			victim.TakeDamage(tickDmg.tointeger(), (1 << 1), atk)
		})

		// Track
		if (!(uid in DoTTimers)) DoTTimers[uid] <- {}
		DoTTimers[uid][type] <- timerName

		return true
	}

	function RemoveDoT(victim, type)
	{
		if (!victim || !victim.IsValid()) return
		local uid = victim.entindex().tostring()
		if (uid in DoTTimers && type in DoTTimers[uid]) {
			::MaoLib.RemoveTimer(DoTTimers[uid][type])
			delete DoTTimers[uid][type]
			if (DoTTimers[uid].len() == 0) delete DoTTimers[uid]
		}
	}

	function ClearAllDoTs()
	{
		foreach (uid, types in DoTTimers) {
			foreach (type, timerName in types) {
				::MaoLib.RemoveTimer(timerName)
			}
		}
		DoTTimers = {}
	}

	// ============================================================
	// INTERNAL
	// ============================================================
	function _GetDefault(type)
	{
		return (type in Types) ? Types[type].def : 0
	}

	function _CleanupExpired(uid, type)
	{
		if (!(uid in Data) || !(type in Data[uid])) return
		local now = Time()
		local toRemove = []
		foreach (source, entry in Data[uid][type]) {
			if (entry.expire >= 0 && entry.expire <= now)
				toRemove.append(source)
		}
		foreach (source in toRemove)
			delete Data[uid][type][source]
		if (Data[uid][type].len() == 0)
			delete Data[uid][type]
		if (Data[uid].len() == 0)
			delete Data[uid]
	}
}

printl("[MaoLib.StatusEffects] v2.0 Minimalist loaded")
