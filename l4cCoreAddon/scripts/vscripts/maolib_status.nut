// maolib_status.nut — Status Effects v3.0 (Ultra-Minimalist)
// 
// PARA QUÉ NOS SIRVE:
//   1. DoT (Damage over Time) — sangrado de hunting rifle, hellhound, melee.
//   2. Registry key-value plano — buffs/debuffs temporales de items/perks.
//
// QUÉ ELIMINAMOS:
//   - Stacking rules complejas (multiply/add/max/replace). Sobrediseño.
//   - Hooks automáticos de daño (maolib_status_hooks.nut). Nadie aplicaba los efectos.
//   - Categorías predefinidas. Ahora es key-value libre.
//
// API:
//   MaoLib.StatusEffects.ApplyDoT(victim, type, dps, duration, attacker)
//   MaoLib.StatusEffects.RemoveDoT(victim, type)
//   MaoLib.StatusEffects.ClearAllDoTs()
//
//   MaoLib.StatusEffects.Set(player, key, value, duration=-1, source="generic")
//   MaoLib.StatusEffects.Get(player, key) → tabla de {source, value, expire} o null
//   MaoLib.StatusEffects.Remove(player, key, source="")
//   MaoLib.StatusEffects.Clear(player)

if ("MaoLib_Status_init_guard" in getroottable()) return;
getroottable()["MaoLib_Status_init_guard"] <- true;

::MaoLib.StatusEffects <- {
	Debug = 0

	function Dbg(msg) {
		if (Debug) printl("[Status][DBG] " + msg)
	}
	function DbgWarn(msg) {
		printl("[Status][WARN] " + msg)
	}

	// ============================================================
	// DoT SUBSYSTEM
	// ============================================================
	DoTTimers = {}

	function ApplyDoT(victim, type, dps, duration, attacker)
	{
		if (!victim || !victim.IsValid()) return false
		if (dps <= 0 || duration <= 0) return false

		local uid = victim.entindex().tostring()
		local timerName = "dot_" + type + "_" + uid

		// Remover DoT anterior del mismo tipo en esta víctima
		RemoveDoT(victim, type)

		local endTime = Time() + duration
		local tickDmg = dps

		this.Dbg("DoT START: " + type + " dps=" + dps + " dur=" + duration + " on " + uid)

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
			local atk = (attacker && attacker.IsValid()) ? attacker : victim
			victim.TakeDamage(tickDmg.tointeger(), (1 << 1), atk)
		})

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
	// SIMPLE KEY-VALUE REGISTRY (plano, sin stacking rules)
	// ============================================================
	// Data[entindex][key][source] = { value, expire }
	//
	// Para stacking: el script consumidor itera las entries y decide.
	// Esto evita magia oculta y hace el sistema predecible.
	// ============================================================
	Data = {}

	function Set(player, key, value, duration = -1, source = "generic")
	{
		if (!player || !player.IsValid() || !player.IsPlayer()) return false
		if (typeof key != "string" || key == "") { DbgWarn("Set: key invalid"); return false }

		local uid = player.entindex().tostring()
		if (!(uid in Data)) Data[uid] <- {}
		if (!(key in Data[uid])) Data[uid][key] <- {}

		Data[uid][key][source] <- {
			value = value,
			expire = (duration < 0) ? -1.0 : (Time() + duration)
		}

		Dbg("SET " + key + "=" + value + " src=" + source + " dur=" + duration)
		return true
	}

	function Get(player, key)
	{
		if (!player || !player.IsValid()) return null
		local uid = player.entindex().tostring()
		if (!(uid in Data) || !(key in Data[uid])) return null

		_CleanupExpired(uid, key)
		if (Data[uid][key].len() == 0) return null

		// Devolvemos la tabla raw para que el consumidor decida cómo combinar
		return Data[uid][key]
	}

	function Remove(player, key, source = "")
	{
		if (!player || !player.IsValid()) return false
		local uid = player.entindex().tostring()
		if (!(uid in Data) || !(key in Data[uid])) return false

		if (source == "") {
			delete Data[uid][key]
		} else if (source in Data[uid][key]) {
			delete Data[uid][key][source]
		}

		if (Data[uid][key].len() == 0) delete Data[uid][key]
		if (Data[uid].len() == 0) delete Data[uid]
		return true
	}

	function Clear(player)
	{
		if (!player || !player.IsValid()) return false
		local uid = player.entindex().tostring()
		if (uid in Data) delete Data[uid]
		if (uid in DoTTimers) {
			foreach (type, timerName in DoTTimers[uid]) {
				::MaoLib.RemoveTimer(timerName)
			}
			delete DoTTimers[uid]
		}
		return true
	}

	function ClearAll()
	{
		Data = {}
		ClearAllDoTs()
	}

	// ============================================================
	// INTERNAL
	// ============================================================
	function _CleanupExpired(uid, key)
	{
		if (!(uid in Data) || !(key in Data[uid])) return
		local now = Time()
		local toRemove = []
		foreach (source, entry in Data[uid][key]) {
			if (entry.expire >= 0 && entry.expire <= now)
				toRemove.append(source)
		}
		foreach (source in toRemove)
			delete Data[uid][key][source]
		if (Data[uid][key].len() == 0)
			delete Data[uid][key]
		if (Data[uid].len() == 0)
			delete Data[uid]
	}
}

printl("[MaoLib.StatusEffects] v3.0 Ultra-Minimalist loaded")
