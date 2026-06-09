// maolib_modifiers.nut - Registro de modificadores de velocidad y fricción
// Sistema centralizado para múltiples scripts que modifican movimiento de jugadores
//
// API:
//   MaoLib.Modifiers.RegisterSpeed(player, multiplier, duration, source)     -> Registra mod velocidad
//   MaoLib.Modifiers.RegisterFriction(player, friction, duration, source)    -> Registra mod fricción
//   MaoLib.Modifiers.GetSpeedMultiplier(player)                               -> Multiplicador final
//   MaoLib.Modifiers.GetFriction(player)                                      -> Fricción final (máx)
//   MaoLib.Modifiers.ClearAll(player)                                         -> Limpia todo
//   MaoLib.Modifiers.ClearSource(player, source)                              -> Limpia por source
//   MaoLib.Modifiers.ListActive(player)                                       -> Lista para debug

if ("MaoLib_Modifiers_init_guard" in getroottable()) return;
getroottable()["MaoLib_Modifiers_init_guard"] <- true;

::MaoLib.Modifiers <- {
	// ============================================================
	// DEBUG — 0 = silencioso, 1 = eventos (register/expire), 2 = think loop
	// ============================================================
	Debug = 1
	
	function Dbg(msg)
	{
		if (Debug) printl("[MaoLib.Modifiers][DEBUG] " + msg)
	}
	
	function DbgWarn(msg)
	{
		printl("[MaoLib.Modifiers][WARN] " + msg)
	}
	
	// ============================================================
	// ESTADO INTERNO
	// ============================================================
	
	// Data[uid] = { speed: [ {mult, expire, source}, ... ], friction: [ {val, expire, source}, ... ] }
	Data = {}
	
	// Think activo flag (auto-pausa)
	ThinkActive = false
	
	// Contador de cambios desde último think log (evita spam)
	_ChangeCount = 0
	
	// ============================================================
	// THINK — Aplica modificadores al m_flLaggedMovementValue
	// ============================================================
	// Corre cada 0.3s vía MaoLib.AddTimer. Auto-pausa cuando no hay datos.
	// NO loguea cada ciclo a menos que Debug >= 2.
	
	function _StartThink()
	{
		if (ThinkActive) return
		ThinkActive = true
		MaoLib.AddTimer("maolib_modifiers_think", 0.3, function() {
			::MaoLib.Modifiers._Think()
		})
		Dbg("_StartThink: think activado")
	}
	
	function _StopThink()
	{
		if (!ThinkActive) return
		ThinkActive = false
		MaoLib.RemoveTimer("maolib_modifiers_think")
		Dbg("_StopThink: think desactivado")
	}
	
	function _Think()
	{
		// 1. Cleanup global de expirados (fuera del foreach, evita corrupción)
		_CleanupAllExpired()
		
		// 2. Auto-pausa si no hay datos
		if (Data.len() == 0)
		{
			if (Debug >= 2) Dbg("_Think: no data, pausing think")
			_StopThink()
			return
		}
		
		// 3. Aplicar modificadores a cada player
		local appliedCount = 0
		local cumulativeChanged = false
		
		foreach (uid, playerData in Data)
		{
			local player = null
			try { player = EntIndexToHScript(uid.tointeger()) } catch (e) {}
			
			if (!player || !player.IsValid() || !player.IsPlayer())
			{
				// Player desapareció, limpiar sus datos
				delete Data[uid]
				_StoreInPlayerState(uid, "speed_mods", null)
				_StoreInPlayerState(uid, "friction_mods", null)
				continue
			}
			
			if (NetProps.GetPropInt(player, "m_lifeState") != 0) continue
			
			// Calcular speed combinada: producto de todos los multiplicadores
			local speedResult = 1.0
			foreach (entry in playerData.speed)
				speedResult *= entry.mult
			
			// Calcular friction combinada: máximo de todos
			local frictionResult = 1.0
			foreach (entry in playerData.friction)
				if (entry.val > frictionResult)
					frictionResult = entry.val
			
			// Valor final
			local combined = speedResult * frictionResult
			
			// Solo escribir si cambió (evita writes innecesarios)
			local current = NetProps.GetPropFloat(player, "m_flLaggedMovementValue")
			if (current != combined)
			{
				NetProps.SetPropFloat(player, "m_flLaggedMovementValue", combined)
				cumulativeChanged = true
			}
			
			appliedCount++
		}
		
		// 4. Debug no invasivo: solo si Debug >= 2 o hubo cambios
		if (Debug >= 2 || (Debug == 1 && cumulativeChanged))
		{
			_ChangeCount++
			// Loguear resumen cada 10 cambios o si Debug >= 2 siempre
			if (Debug >= 2 || _ChangeCount % 10 == 0)
				Dbg("_Think: applied=" + appliedCount + " players, dataSize=" + Data.len())
		}
	}
	
	// ============================================================
	// CLEANUP GLOBAL (para think loop)
	// ============================================================
	// Limpia expirados de TODOS los uids. Recolecta vacíos y los elimina
	// fuera del foreach para no corromper la iteración.
	
	function _CleanupAllExpired()
	{
		local now = Time()
		local emptyUids = []
		
		foreach (uid, playerData in Data)
		{
			local changed = false
			
			// Cleanup speed
			local newSpeed = []
			foreach (entry in playerData.speed)
			{
				if (entry.expire >= 0 && entry.expire <= now)
				{
					changed = true
					if (Debug) Dbg("_CleanupAllExpired: expired speed source=" + entry.source + " uid=" + uid)
				}
				else
				{
					newSpeed.append(entry)
				}
			}
			if (changed) playerData.speed = newSpeed
			
			// Cleanup friction
			local newFriction = []
			foreach (entry in playerData.friction)
			{
				if (entry.expire >= 0 && entry.expire <= now)
				{
					changed = true
					if (Debug) Dbg("_CleanupAllExpired: expired friction source=" + entry.source + " uid=" + uid)
				}
				else
				{
					newFriction.append(entry)
				}
			}
			if (changed) playerData.friction = newFriction
			
			// Marcar para eliminar si está vacío
			if (playerData.speed.len() == 0 && playerData.friction.len() == 0)
				emptyUids.append(uid)
		}
		
		// Eliminar entries vacíos (fuera del foreach)
		foreach (uid in emptyUids)
		{
			delete Data[uid]
			_StoreInPlayerState(uid, "speed_mods", null)
			_StoreInPlayerState(uid, "friction_mods", null)
			if (Debug) Dbg("_CleanupAllExpired: removed empty entry uid=" + uid)
		}
	}
	
	// ============================================================
	// REGISTER SPEED
	// ============================================================
	// multiplier: valor multiplicativo (1.0 = sin cambio, 1.5 = +50%, 0.5 = -50%)
	// duration: -1 = permanente, >0 = segundos
	// source: string identificador ("jaime_frenzy", "butcher_roar", etc.)
	function RegisterSpeed(player, multiplier, duration, source = "unknown")
	{
		Dbg("ENTER RegisterSpeed")
		
		if (!_ValidatePlayer(player))
		{
			Dbg("EXIT RegisterSpeed: invalid player")
			return false
		}
		
		if (typeof(multiplier) != "float" && typeof(multiplier) != "integer")
		{
			DbgWarn("RegisterSpeed: multiplier must be numeric, got " + typeof(multiplier))
			return false
		}
		
		local uid = _GetUID(player)
		local expire = (duration < 0) ? -1.0 : (Time() + duration)
		
		_InitPlayerData(uid)
		
		// Reemplazar entrada del mismo source si existe
		local replaced = false
		foreach (entry in Data[uid].speed)
		{
			if (entry.source == source)
			{
				entry.mult = multiplier.tofloat()
				entry.expire = expire
				replaced = true
				Dbg("  REPLACED speed: source=" + source + " mult=" + multiplier + " expire=" + expire)
				break
			}
		}
		
		if (!replaced)
		{
			Data[uid].speed.append({
				mult = multiplier.tofloat()
				expire = expire
				source = source
			})
			Dbg("  ADDED speed: source=" + source + " mult=" + multiplier + " expire=" + expire)
		}
		
		// Backing store en PlayerState si existe
		_StoreInPlayerState(uid, "speed_mods", Data[uid].speed)
		
		// Activar think si no está activo
		_StartThink()
		
		Dbg("EXIT RegisterSpeed: OK")
		return true
	}
	
	// ============================================================
	// REGISTER FRICTION
	// ============================================================
	// friction: valor absoluto (1.0 = default, >1.0 = más lento, <1.0 = más rápido/deslizante)
	// La fricción final es el MÁXIMO (más restrictivo) de todos los registrados
	// duration: -1 = permanente, >0 = segundos
	function RegisterFriction(player, friction, duration, source = "unknown")
	{
		Dbg("ENTER RegisterFriction")
		
		if (!_ValidatePlayer(player))
		{
			Dbg("EXIT RegisterFriction: invalid player")
			return false
		}
		
		if (typeof(friction) != "float" && typeof(friction) != "integer")
		{
			DbgWarn("RegisterFriction: friction must be numeric, got " + typeof(friction))
			return false
		}
		
		local uid = _GetUID(player)
		local expire = (duration < 0) ? -1.0 : (Time() + duration)
		
		_InitPlayerData(uid)
		
		// Reemplazar entrada del mismo source si existe
		local replaced = false
		foreach (entry in Data[uid].friction)
		{
			if (entry.source == source)
			{
				entry.val = friction.tofloat()
				entry.expire = expire
				replaced = true
				Dbg("  REPLACED friction: source=" + source + " val=" + friction + " expire=" + expire)
				break
			}
		}
		
		if (!replaced)
		{
			Data[uid].friction.append({
				val = friction.tofloat()
				expire = expire
				source = source
			})
			Dbg("  ADDED friction: source=" + source + " val=" + friction + " expire=" + expire)
		}
		
		// Backing store en PlayerState si existe
		_StoreInPlayerState(uid, "friction_mods", Data[uid].friction)
		
		// Activar think si no está activo
		_StartThink()
		
		Dbg("EXIT RegisterFriction: OK")
		return true
	}
	
	// ============================================================
	// GET SPEED MULTIPLIER
	// ============================================================
	// Multiplica TODOS los modificadores activos: result = 1.0 * m1 * m2 * ...
	// Devuelve 1.0 si no hay modificadores activos
	function GetSpeedMultiplier(player)
	{
		if (!_ValidatePlayer(player))
			return 1.0
		
		local uid = _GetUID(player)
		
		if (!(uid in Data))
			return 1.0
		
		_CleanupExpired(uid)
		
		local result = 1.0
		local activeCount = 0
		
		foreach (entry in Data[uid].speed)
		{
			result *= entry.mult
			activeCount++
		}
		
		if (Debug && activeCount > 0)
			Dbg("GetSpeedMultiplier: uid=" + uid + " count=" + activeCount + " result=" + result)
		
		return result
	}
	
	// ============================================================
	// GET FRICTION
	// ============================================================
	// Devuelve el MÁXIMO valor de fricción activo (más restrictivo gana)
	// Devuelve 1.0 si no hay modificadores activos
	function GetFriction(player)
	{
		if (!_ValidatePlayer(player))
			return 1.0
		
		local uid = _GetUID(player)
		
		if (!(uid in Data))
			return 1.0
		
		_CleanupExpired(uid)
		
		local maxFriction = 1.0
		local activeCount = 0
		
		foreach (entry in Data[uid].friction)
		{
			if (entry.val > maxFriction)
				maxFriction = entry.val
			activeCount++
		}
		
		if (Debug && activeCount > 0)
			Dbg("GetFriction: uid=" + uid + " count=" + activeCount + " result=" + maxFriction)
		
		return maxFriction
	}
	
	// ============================================================
	// CLEAR ALL
	// ============================================================
	// Elimina TODOS los modificadores de un jugador
	function ClearAll(player)
	{
		if (!_ValidatePlayer(player))
			return false
		
		local uid = _GetUID(player)
		
		if (uid in Data)
		{
			Dbg("ClearAll: uid=" + uid + " removed " + Data[uid].speed.len() + " speed + " + Data[uid].friction.len() + " friction mods")
			delete Data[uid]
		}
		
		// Limpiar backing store
		_StoreInPlayerState(uid, "speed_mods", null)
		_StoreInPlayerState(uid, "friction_mods", null)
		
		// Auto-pausa si Data quedó vacío
		if (Data.len() == 0)
			_StopThink()
		
		return true
	}
	
	// ============================================================
	// CLEAR SOURCE
	// ============================================================
	// Elimina modificadores de un source específico
	function ClearSource(player, source)
	{
		if (!_ValidatePlayer(player))
			return false
		
		local uid = _GetUID(player)
		
		if (!(uid in Data))
			return false
		
		local removedSpeed = 0
		local removedFriction = 0
		
		// Filtrar speed
		local newSpeed = []
		foreach (entry in Data[uid].speed)
		{
			if (entry.source == source)
			{
				removedSpeed++
			}
			else
			{
				newSpeed.append(entry)
			}
		}
		Data[uid].speed = newSpeed
		
		// Filtrar friction
		local newFriction = []
		foreach (entry in Data[uid].friction)
		{
			if (entry.source == source)
			{
				removedFriction++
			}
			else
			{
				newFriction.append(entry)
			}
		}
		Data[uid].friction = newFriction
		
		Dbg("ClearSource: uid=" + uid + " source=" + source + " removed " + removedSpeed + " speed + " + removedFriction + " friction")
		
		// Actualizar backing store
		_StoreInPlayerState(uid, "speed_mods", Data[uid].speed)
		_StoreInPlayerState(uid, "friction_mods", Data[uid].friction)
		
		return true
	}
	
	// ============================================================
	// LIST ACTIVE
	// ============================================================
	// Imprime modificadores activos de un jugador (para debug)
	function ListActive(player)
	{
		if (!_ValidatePlayer(player))
		{
			printl("[MaoLib.Modifiers] ListActive: invalid player")
			return
		}
		
		local uid = _GetUID(player)
		local now = Time()
		
		printl("=== MaoLib.Modifiers Active for uid=" + uid + " ===")
		
		if (!(uid in Data))
		{
			printl("  No modifiers registered")
			return
		}
		
		_CleanupExpired(uid)
		
		printl("  SPEED modifiers (" + Data[uid].speed.len() + "):")
		foreach (entry in Data[uid].speed)
		{
			local remaining = (entry.expire < 0) ? "PERMANENT" : (entry.expire - now) + "s"
			printl("    [" + entry.source + "] mult=" + entry.mult + " remaining=" + remaining)
		}
		
		printl("  FRICTION modifiers (" + Data[uid].friction.len() + "):")
		foreach (entry in Data[uid].friction)
		{
			local remaining = (entry.expire < 0) ? "PERMANENT" : (entry.expire - now) + "s"
			printl("    [" + entry.source + "] val=" + entry.val + " remaining=" + remaining)
		}
		
		printl("  COMBINED: speed=" + GetSpeedMultiplier(player) + " friction=" + GetFriction(player))
	}
	
	// ============================================================
	// INTERNAL: Validación de jugador
	// ============================================================
	function _ValidatePlayer(player)
	{
		if (!player || !player.IsValid())
			return false
		if (!player.IsPlayer())
			return false
		return true
	}
	
	// ============================================================
	// INTERNAL: Obtener UID
	// ============================================================
	function _GetUID(player)
	{
		return "" + player.entindex()
	}
	
	// ============================================================
	// INTERNAL: Inicializar datos de jugador
	// ============================================================
	function _InitPlayerData(uid)
	{
		if (!(uid in Data))
		{
			Data[uid] <- {
				speed = []
				friction = []
			}
		}
	}
	
	// ============================================================
	// INTERNAL: Cleanup lazy (llamado desde Get*)
	// ============================================================
	function _CleanupExpired(uid)
	{
		if (!(uid in Data))
			return
		
		local now = Time()
		local removedSpeed = 0
		local removedFriction = 0
		
		// Limpiar speed expirados
		local newSpeed = []
		foreach (entry in Data[uid].speed)
		{
			if (entry.expire >= 0 && entry.expire <= now)
			{
				removedSpeed++
			}
			else
			{
				newSpeed.append(entry)
			}
		}
		if (removedSpeed > 0)
		{
			Data[uid].speed = newSpeed
			Dbg("_CleanupExpired: uid=" + uid + " removed " + removedSpeed + " expired speed mods")
		}
		
		// Limpiar friction expirados
		local newFriction = []
		foreach (entry in Data[uid].friction)
		{
			if (entry.expire >= 0 && entry.expire <= now)
			{
				removedFriction++
			}
			else
			{
				newFriction.append(entry)
			}
		}
		if (removedFriction > 0)
		{
			Data[uid].friction = newFriction
			Dbg("_CleanupExpired: uid=" + uid + " removed " + removedFriction + " expired friction mods")
		}
		
		// Si no queda nada, limpiar la entrada
		if (Data[uid].speed.len() == 0 && Data[uid].friction.len() == 0)
		{
			delete Data[uid]
			_StoreInPlayerState(uid, "speed_mods", null)
			_StoreInPlayerState(uid, "friction_mods", null)
			Dbg("_CleanupExpired: uid=" + uid + " removed empty entry")
		}
		else
		{
			// Actualizar backing store
			_StoreInPlayerState(uid, "speed_mods", Data[uid].speed)
			_StoreInPlayerState(uid, "friction_mods", Data[uid].friction)
		}
	}
	
	// ============================================================
	// INTERNAL: Backing store en PlayerState
	// ============================================================
	function _StoreInPlayerState(uid, key, value)
	{
		if (!("PlayerState" in ::MaoLib))
			return
		
		try
		{
			if (value == null)
			{
				::MaoLib.PlayerState.Delete(uid, key)
			}
			else
			{
				::MaoLib.PlayerState.Set(uid, key, value)
			}
		}
		catch (e)
		{
			// PlayerState puede no tener la API esperada, ignorar silenciosamente
		}
	}
}

printl("[MaoLib.Modifiers] Loaded successfully")
