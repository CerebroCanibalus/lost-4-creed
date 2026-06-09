// tank_ai.nut - Aggressive Tank AI based on pro versus strategies
// States: ASSESS -> PRESSURE/COMMIT/ROLLBACK/THROW/FLANK/BERSERK
// Uses: MaoLib.NavUtils for pathfinding

const PI = 3.1415926535898;

// ------------------------------------------------------------------
// CONFIGURATION
// ------------------------------------------------------------------
::AggressiveTankAI <-
{
	ThinkInterval = 0.15          // 0.5 → 0.15: reacción más rápida (MaoLib timer)
	
	// PREDICTIVE MOVEMENT
	PredictionLead = 1.2          // multiplicador de tiempo para predecir posición del survivor
	JumpChance = 0.3              // 30% chance de saltar al cerrar distancia
	CloseJumpRange = 350          // distancia para considerar "cerrando distancia"
	
	// ENVIRONMENTAL DESTRUCTION (COMMIT) — solo props seguros
	PropScanRadius = 400          // radio para escanear props destructibles
	
	// ROCK THROW (THROW state)
	ThrowTargetSwitchTime = 1.5   // cambiar target cada 1.5s durante throw
	ThrowMaxDist = 1500           // distancia máxima para considerar throw
	
	// FLANK
	FlankCooldown = 4.0           // 8s → 4s: flanquea más seguido
	FlankCheckRadius = 600        // radio para buscar rutas de flanqueo
	
	// BERSERK BUNNYHOP (bots only)
	BhopInterval = 0.06           // 60ms ~16 veces/segundo
	BhopMaxSpeed = 225            // velocidad horizontal máxima (como reference)
	BhopForwardBoost = 60         // boost forward (como reference)
	BhopJumpBoost = 247           // altura del salto (como reference)
	CommitDuration = 2.0
	RollbackDuration = 1.5
	ThrowCooldown = 5.0
	
	CommitRange = 250
	ThrowRange = 1200
	RollbackHealthThreshold = 60
	
	TankStates = {}
	TankTimers = {}
	TankTargets = {}
	RollbackCache = {}  // idx -> { pos, time } — cache para reducir GetNavAreasInRadius
}

// ------------------------------------------------------------------
// HELPERS (nuevos)
// ------------------------------------------------------------------

/** Predice dónde estará el survivor en función de su velocidad */
function AggressiveTankAI::PredictTargetPosition(tank, target)
{
	local targetPos = target.GetOrigin();
	local targetVel = target.GetVelocity();
	local dist = (targetPos - tank.GetOrigin()).Length();
	
	// Tiempo estimado para alcanzar al survivor (velocidad tank ~210)
	local timeToReach = (dist / 210.0) * PredictionLead;
	
	// Si el survivor se mueve, predecir su posición futura
	if (targetVel.Length() > 10)
	{
		local predicted = targetPos + (targetVel * timeToReach);
		return predicted;
	}
	
	return targetPos;
}

/** Decide si el tank debería saltar para alcanzar al survivor */
function AggressiveTankAI::ShouldJump(tank, target)
{
	if (!IsPlayerABot(tank))
		return false;
	
	local dist = (target.GetOrigin() - tank.GetOrigin()).Length();
	if (dist > CloseJumpRange || dist < 100)
		return false;
	
	// 30% chance
	if (RandomFloat(0, 1) > JumpChance)
		return false;
	
	// Solo saltar si hay línea de visión
	if (!MaoLib.NavUtils.HasLineOfSight(tank.EyePosition(), target.EyePosition(), tank))
		return false;
	
	return true;
}

/** Fuerza al tank a saltar (solo bots) */
function AggressiveTankAI::ForceTankJump(tank)
{
	if (!IsPlayerABot(tank))
		return;
	
	// Forzar botón de salto (IN_JUMP = 2) y avance (IN_FORWARD = 8)
	MaoLib.StartKey(tank, 2);   // IN_JUMP
	MaoLib.StartKey(tank, 8);   // IN_FORWARD
	
	// Pequeño boost de velocidad hacia adelante
	local angles = tank.EyeAngles();
	local boostX = BhopForwardBoost * cos(angles.y * PI / 180);
	local boostY = BhopForwardBoost * sin(angles.y * PI / 180);
	local vel = tank.GetVelocity();
	tank.SetVelocity(Vector(vel.x + boostX, vel.y + boostY, vel.z));
}

/** Busca un prop destructible cerca — SOLO seguros (no explosivos ni fuego) */
function AggressiveTankAI::FindHighValueProp(tankPos, survivors)
{
	local bestProp = null;
	local bestScore = -1;
	
	// Buscar props físicos rompibles (muebles, barreras, obstáculos)
	// EXCLUIR explosivos (propane, gas) porque dañan al tank también
	local props = MaoLib.NavUtils.FindHittableProps(tankPos, PropScanRadius);
	
	foreach (p in props)
	{
		local ent = p.ent;
		if (!ent || !ent.IsValid())
			continue;
		
		local model = ent.GetModelName() || "";
		
		// ❌ Saltar explosivos y fuego — dañan al tank
		if (model.find("propane") != null || model.find("gascan") != null ||
			model.find("exploding") != null || model.find("gas") != null)
			continue;
		
		local score = 25; // breakable genérico
		
		// Bonus: si está cerca de un survivor, romperlo es más útil
		foreach (s in survivors)
		{
			if (!s || !s.IsValid()) continue;
			local d = (ent.GetOrigin() - s.GetOrigin()).Length();
			if (d < 300)
				score += 20;
		}
		
		if (score > bestScore)
		{
			bestScore = score;
			bestProp = ent;
		}
	}
	
	return bestProp;
}

// ------------------------------------------------------------------
// BERSERK BUNNYHOP (bots only)
// ------------------------------------------------------------------

/** Inicia el bunnyhop para un tank bot en berserk */
function AggressiveTankAI::StartBunnyhop(tank)
{
	if (!IsPlayerABot(tank))
		return;
	
	local idx = tank.GetEntityIndex().tostring();
	local timerName = "tank_bhop_" + idx;
	
	if (MaoLib.IsTimerActive(timerName))
		return;
	
	// Timer a 0.06s para bunnyhop fluido
	// Closure que captura tank + idx para cleanup seguro sin race conditions
	MaoLib.AddTimer(timerName, BhopInterval, function(t_ref, idx_ref) {
		return function() {
			::AggressiveTankAI.BunnyhopThink(t_ref, idx_ref);
		};
	}(tank, idx));
	
	printl("[TankAI] BERSERK BUNNYHOP iniciado para Tank " + idx);
}

/** Detiene el bunnyhop */
function AggressiveTankAI::StopBunnyhop(tank)
{
	if (!tank || !tank.IsValid()) return;
	
	local idx = tank.GetEntityIndex().tostring();
	local timerName = "tank_bhop_" + idx;
	
	if (MaoLib.IsTimerActive(timerName))
		MaoLib.RemoveTimer(timerName);
	
	// Liberar botones
	MaoLib.EndKey(tank, 2);
	MaoLib.EndKey(tank, 8);
}

/** Think del bunnyhop — fuerza salto + dirección hacia survivor más cercano */
function AggressiveTankAI::BunnyhopThink(tank, idx)
{
	if (!tank || !tank.IsValid() || !MaoLib.IsAlive(tank))
	{
		// idx viene del closure, así que podemos limpiar directamente sin depender del tank
		local timerName = "tank_bhop_" + idx;
		if (MaoLib.IsTimerActive(timerName))
			MaoLib.RemoveTimer(timerName);
		return;
	}
	
	// Verificar que sigue en BERSERK
	local state = GetTankState(idx);
	if (state != "BERSERK")
	{
		StopBunnyhop(tank);
		return;
	}
	
	// Obtener survivor más cercano vivo
	local survivors = GetAliveSurvivors();
	if (survivors.len() == 0) return;
	
	local nearest = null;
	local nearestDist = 99999;
	local tankPos = tank.GetOrigin();
	
	foreach (s in survivors)
	{
		if (!s || !s.IsValid()) continue;
		if (NetProps.GetPropInt(s, "m_lifeState") != 0) continue;
		local d = (s.GetOrigin() - tankPos).Length();
		if (d < nearestDist) { nearestDist = d; nearest = s; }
	}
	
	if (!nearest) return;
	
	local flags = NetProps.GetPropInt(tank, "m_fFlags");
	local onGround = (flags & 1) != 0;
	
	// Calcular dirección hacia el target (plano X/Y)
	local dir = nearest.GetOrigin() - tankPos;
	dir.z = 0;
	local dist = dir.Length();
	if (dist > 0) dir = dir / dist; // Normalizar
	
	// Calcular yaw hacia el target
	local desiredYaw = atan2(dir.y, dir.x) * (180.0 / PI);
	
	// Aplicar rotación hacia el target (solo yaw, mantener pitch/roll)
	local currentAngles = tank.EyeAngles();
	NetProps.SetPropVector(tank, "m_angRotation", Vector(0, desiredYaw, 0));
	
	// Mirar al target (para que el bot apunte correctamente)
	NetProps.SetPropEntity(tank, "m_lookatPlayer", nearest);
	
	if (onGround)
	{
		// === PULSE JUMP ===
		// En vez de StartKey (que mantiene el botón presionado), usamos
		// m_afButtonPressed que el engine limpia automáticamente cada frame.
		// Esto simula un "tap" de salto, necesario para bunnyhop:
		// si el botón sigue presionado al aterrizar, el engine no re-salta.
		local pressed = NetProps.GetPropInt(tank, "m_afButtonPressed");
		NetProps.SetPropInt(tank, "m_afButtonPressed", pressed | 2 | 8); // IN_JUMP(2) + IN_FORWARD(8)
		
		// === VELOCIDAD INICIAL ===
		// Aplicar impulso hacia arriba para el salto
		tank.ApplyAbsVelocityImpulse(Vector(0, 0, BhopJumpBoost));
		
		// Aplicar velocidad horizontal base en dirección al target
		local horizVel = dir * BhopMaxSpeed;
		local currentVel = tank.GetVelocity();
		tank.SetVelocity(Vector(horizVel.x, horizVel.y, currentVel.z));
		
		// También aplicar forward boost adicional
		local forwardBoost = dir * BhopForwardBoost;
		tank.ApplyAbsVelocityImpulse(Vector(forwardBoost.x, forwardBoost.y, 0));
	}
	else
	{
		// === EN EL AIRE ===
		// Soltar el botón de salto (por si acaso)
		MaoLib.EndKey(tank, 2);
		
		// Aplicar air control: empuje sutil hacia el target
		local vel = tank.GetVelocity();
		local horizSpeed = sqrt(vel.x * vel.x + vel.y * vel.y);
		
		// Solo acelerar si no hemos alcanzado la velocidad máxima
		if (horizSpeed < BhopMaxSpeed * 1.2)
		{
			local airBoost = dir * (BhopForwardBoost * 0.6);
			tank.ApplyAbsVelocityImpulse(Vector(airBoost.x, airBoost.y, 0));
		}
		
		// Si estamos cayendo muy rápido, reducir velocidad vertical (micro-strafe)
		if (vel.z < -100)
		{
			// Aplicar una pequeña fuerza hacia arriba para alargar el salto
			tank.ApplyAbsVelocityImpulse(Vector(0, 0, BhopForwardBoost * 0.3));
		}
	}
}

// ------------------------------------------------------------------
// ORIGINAL HELPERS (sin cambios)
// ------------------------------------------------------------------

// ------------------------------------------------------------------
// STATE MACHINE
// ------------------------------------------------------------------
function AggressiveTankAI::Think()
{
	foreach (tank in MaoLib.YieldSpecials())
	{
		if (!tank || !tank.IsValid())
			continue;
		
		if (NetProps.GetPropInt(tank, "m_zombieClass") != 8)
			continue;
		
		if (!IsPlayerABot(tank))
			continue;
		
		// CRITICAL: Skip dead tanks (body persists during death animation)
		if (!MaoLib.IsAlive(tank))
			continue;
		
		local idx = tank.GetEntityIndex().tostring();
		local state = GetTankState(idx);
		local survivors = GetAliveSurvivors();
		
		if (survivors.len() == 0)
			continue;
		
		local hpPercent = (tank.GetHealth().tofloat() / GetTankMaxHP(tank)) * 100.0;
		
		// BERSERK override
		if (hpPercent <= 15)
		{
			SetTankState(idx, "BERSERK");
			ExecuteBerserk(tank, survivors);
			continue;
		}
		
		switch (state)
		{
			case "ASSESS":
				ExecuteAssess(tank, survivors, idx);
				break;
			case "PRESSURE":
				ExecutePressure(tank, survivors, idx, hpPercent);
				break;
			case "COMMIT":
				ExecuteCommit(tank, survivors, idx, hpPercent);
				break;
			case "ROLLBACK":
				ExecuteRollback(tank, survivors, idx);
				break;
			case "THROW":
				ExecuteThrow(tank, survivors, idx);
				break;
			case "FLANK":
				ExecuteFlank(tank, survivors, idx);
				break;
		}
	}
}

// ------------------------------------------------------------------
// STATES
// ------------------------------------------------------------------
function AggressiveTankAI::ExecuteAssess(tank, survivors, idx)
{
	local tankPos = tank.GetOrigin();
	local target = SelectTarget(tank, survivors);
	TankTargets[idx] <- target;
	
	if (!target || !target.IsValid())
	{
		SetTankState(idx, "PRESSURE");
		return;
	}
	
	local distToTarget = (target.GetOrigin() - tankPos).Length();
	local timer = GetTankTimer(idx);
	local targetNav = MaoLib.NavUtils.GetNearestNavArea(target.GetOrigin());
	
	// [NUEVO] Verificar si el tank está en una posición desfavorable:
	// - Muchos survivors con LOS directo
	// - Cerca de fuego
	local losSurvivors = 0;
	foreach (s in survivors)
	{
		if (!s || !s.IsValid()) continue;
		if (MaoLib.NavUtils.HasLineOfSight(s.EyePosition(), tank.EyePosition(), s))
			losSurvivors++;
	}
	
	local nearFire = MaoLib.NavUtils.IsNearFire(tank, 300);
	
	// Si está expuesto a 3+ survivors o cerca de fuego → retroceder
	if ((losSurvivors >= 3 && distToTarget < 800) || nearFire)
	{
		if (Time() > timer.lastRollback + RollbackDuration * 2)
		{
			SetTankState(idx, "ROLLBACK");
			return;
		}
	}
	
	// Open area + far enough = THROW (sin cambios)
	if (distToTarget > CommitRange && distToTarget < ThrowRange &&
		targetNav && MaoLib.NavUtils.IsOpenArea(targetNav) &&
		Time() > timer.lastThrow + ThrowCooldown)
	{
		SetTankState(idx, "THROW");
		return;
	}
	
	// [MEJORADO] FLANK más agresivo:
	// - Ya no requiere chokepoint
	// - Flanquea si HAY ALGÚN survivor separado del grupo
	// - Cooldown reducido a 4s
	if (Time() > timer.lastFlank + FlankCooldown)
	{
		local anySeparated = false;
		foreach (s in survivors)
		{
			if (!s || !s.IsValid()) continue;
			local distFromGroup = 0;
			foreach (other in survivors)
			{
				if (other == s || !other || !other.IsValid()) continue;
				distFromGroup += (s.GetOrigin() - other.GetOrigin()).Length();
			}
			distFromGroup = distFromGroup / (survivors.len() - 1);
			if (distFromGroup > 400)
			{
				anySeparated = true;
				break;
			}
		}
		
		if (anySeparated)
		{
			SetTankState(idx, "FLANK");
			return;
		}
	}
	
	// Close enough = PRESSURE
	SetTankState(idx, "PRESSURE");
}

function AggressiveTankAI::ExecutePressure(tank, survivors, idx, hpPercent)
{
	local target = TankTargets[idx];
	
	if (!target || !target.IsValid())
	{
		SetTankState(idx, "ASSESS");
		return;
	}
	
	local tankPos = tank.GetOrigin();
	local distToTarget = (target.GetOrigin() - tankPos).Length();
	
	if (distToTarget <= CommitRange)
	{
		SetTankState(idx, "COMMIT");
		return;
	}
	
	// [MEJORADO] Throw check — también desde Pressure si hay oportunidad
	local timer = GetTankTimer(idx);
	local targetNav = MaoLib.NavUtils.GetNearestNavArea(target.GetOrigin());
	if (distToTarget > CommitRange && distToTarget < ThrowRange &&
		targetNav && MaoLib.NavUtils.IsOpenArea(targetNav) &&
		Time() > timer.lastThrow + ThrowCooldown)
	{
		SetTankState(idx, "THROW");
		return;
	}
	
	// [NUEVO] Movimiento predictivo — usar posición futura del survivor
	local predictedPos = PredictTargetPosition(tank, target);
	
	// [NUEVO] ZIGZAG: movimiento evasivo al acercarse
	// Oscila perpendicularmente a la dirección del target para ser más difícil de disparar
	distToTarget = (target.GetOrigin() - tankPos).Length();
	if (distToTarget > 300 && distToTarget < 800)
	{
		local dirToTarget = predictedPos - tankPos;
		dirToTarget.z = 0;
		local dist = dirToTarget.Length();
		if (dist > 0)
		{
			dirToTarget = dirToTarget / dist;
			// Vector perpendicular (rotar 90°)
			local perp = Vector(-dirToTarget.y, dirToTarget.x, 0);
			// Amplitud del zigzag: 80-150 unidades, oscilando cada 1.2s
			local zigzagAmount = 100 + sin(Time() * 5.2) * 50;
			predictedPos = predictedPos + (perp * zigzagAmount);
		}
	}
	
	CommandABot({ cmd = 1, bot = tank, pos = predictedPos });
	NetProps.SetPropEntity(tank, "m_lookatPlayer", target);
	
	// [NUEVO] Salto ocasional para cerrar distancia
	if (ShouldJump(tank, target))
		ForceTankJump(tank);
}

function AggressiveTankAI::ExecuteCommit(tank, survivors, idx, hpPercent)
{
	local timer = GetTankTimer(idx);
	local tankPos = tank.GetOrigin();
	local now = Time();
	
	// [NUEVO] Inicializar tracking de HP para detectar daño rápido
	if (!("_commit_hp_start" in timer))
		timer._commit_hp_start <- tank.GetHealth();
	if (!("_commit_hp_time" in timer))
		timer._commit_hp_time <- now;
	
	// [MEJORADO] Al entrar en COMMIT, buscar props destructibles de alto valor
	if (timer.commitStart == 0)
	{
		timer.commitStart <- now;
		timer._commit_hp_start <- tank.GetHealth();
		timer._commit_hp_time <- now;
		
		local highValueProp = FindHighValueProp(tankPos, survivors);
		if (highValueProp && highValueProp.IsValid())
		{
			// Ir al prop primero (explotará/herirá a survivors cercanos)
			CommandABot({ cmd = 1, bot = tank, pos = highValueProp.GetOrigin() });
			NetProps.SetPropEntity(tank, "m_lookatPlayer", highValueProp);
			printl("[TankAI] COMMIT atacando prop: " + highValueProp.GetClassname());
			return; // Dejar que el tank llegue al prop este frame
		}
	}
	
	// [NUEVO] Priorizar survivor incapacitado cercano
	// Esto fuerza a los teammates a exponerse para salvarlo
	local incapTarget = null;
	foreach (s in survivors)
	{
		if (!s || !s.IsValid()) continue;
		if (s.IsIncapacitated())
		{
			local d = (s.GetOrigin() - tankPos).Length();
			if (d < CommitRange * 2)
			{
				incapTarget = s;
				break;
			}
		}
	}
	
	// Si ya pasó el primer frame o no hay prop, atacar al target
	local target = incapTarget ? incapTarget : TankTargets[idx];
	if (target && target.IsValid())
	{
		CommandABot({ cmd = 0, bot = tank, target = target });
		NetProps.SetPropEntity(tank, "m_lookatPlayer", target);
	}
	
	// [MEJORADO] Buscar props también durante COMMIT (redirigir si hay uno cerca)
	local commitTime = now - timer.commitStart;
	local distToTarget = target ? (target.GetOrigin() - tankPos).Length() : 9999;
	
	// Cada 0.5s, checkear si hay un prop explosivo cerca para redirigir
	if (commitTime > 0.5 && (commitTime * 10).tointeger() % 3 == 0)
	{
		local nearbyProp = FindHighValueProp(tankPos, survivors);
		if (nearbyProp && nearbyProp.IsValid() && (nearbyProp.GetOrigin() - tankPos).Length() < 250)
		{
			// Redirigir al prop (está cerca, vale la pena)
			CommandABot({ cmd = 1, bot = tank, pos = nearbyProp.GetOrigin() });
		}
	}
	
	// [NUEVO] Early retreat: si ha perdido mucha HP rápidamente, huir antes
	local hpLost = timer._commit_hp_start - tank.GetHealth();
	local timeInCommit = now - timer._commit_hp_time;
	local shouldEarlyRetreat = false;
	
	if (timeInCommit > 1.0)
	{
		// Si perdió más de 15% de su HP máximo en menos de 2 segundos → retreat
		local maxHP = GetTankMaxHP(tank);
		local hpLostPercent = (hpLost.tofloat() / maxHP.tofloat()) * 100.0;
		local dps = hpLostPercent / timeInCommit;
		
		if (hpLostPercent > 15.0 || dps > 12.0) // 15% total o 12%/s
			shouldEarlyRetreat = true;
	}
	
	if (commitTime >= CommitDuration ||
		hpPercent <= RollbackHealthThreshold ||
		distToTarget > CommitRange * 1.5 ||
		shouldEarlyRetreat)
	{
		timer.lastCommit <- now;
		timer.commitStart <- 0;
		if (shouldEarlyRetreat)
			printl("[TankAI] COMMIT early retreat: HP lost=" + hpLost + " in " + timeInCommit + "s");
		SetTankState(idx, "ROLLBACK");
	}
}

function AggressiveTankAI::ExecuteRollback(tank, survivors, idx)
{
	local timer = GetTankTimer(idx);
	local tankPos = tank.GetOrigin();
	local now = Time();
	
	if (timer.rollbackStart == 0)
	{
		timer.rollbackStart <- now;
		
		local rollbackPos = FindRollbackPosition(tank, survivors);
		if (rollbackPos)
		{
			CommandABot({ cmd = 1, bot = tank, pos = rollbackPos });
			// Guardar posición objetivo para evaluar cuándo llegamos
			timer._rollback_target_pos <- rollbackPos;
		}
	}
	
	local rollbackTime = now - timer.rollbackStart;
	
	// [NUEVO] PEEK BEHAVIOR: si estamos en cobertura y vemos a los survivors,
	// evaluar si podemos tirar rocas desde aquí
	if (rollbackTime >= 0.8 && rollbackTime < RollbackDuration - 0.5)
	{
		local canSeeAny = CanSeeAnySurvivor(tankPos, survivors, tank);
		local losCount = CountLosToPosition(tankPos, survivors, tank);
		
		// Si podemos ver a alguien pero pocos nos pueden ver → oportunidad de throw
		if (canSeeAny && losCount <= 1 && Time() > timer.lastThrow + ThrowCooldown)
		{
			// Verificar que hay un target en rango y espacio abierto
			local target = TankTargets[idx];
			if (target && target.IsValid())
			{
				local dist = (target.GetOrigin() - tankPos).Length();
				local targetNav = MaoLib.NavUtils.GetNearestNavArea(target.GetOrigin());
				if (dist > CommitRange && dist < ThrowRange &&
					targetNav && MaoLib.NavUtils.IsOpenArea(targetNav))
				{
					printl("[TankAI] ROLLBACK → THROW (peek from cover, LOS count=" + losCount + ")");
					timer.rollbackStart <- 0;
					SetTankState(idx, "THROW");
					return;
				}
			}
		}
		
		// [NUEVO] Si llevamos mucho tiempo en rollback y no hay oportunidad,
		// reducir duración si los survivors están muy separados (podemos atacar)
		if (rollbackTime >= RollbackDuration * 0.6)
		{
			local separatedCount = 0;
			foreach (s in survivors)
			{
				if (!s || !s.IsValid()) continue;
				foreach (other in survivors)
				{
					if (other == s || !other || !other.IsValid()) continue;
					if ((s.GetOrigin() - other.GetOrigin()).Length() > 500)
						separatedCount++;
				}
			}
			if (separatedCount >= 2)
			{
				// Survivors separados → oportunidad de atacar
				printl("[TankAI] ROLLBACK early exit: survivors separated");
				timer.rollbackStart <- 0;
				timer.lastRollback <- now;
				SetTankState(idx, "FLANK");
				return;
			}
		}
	}
	
	if (rollbackTime >= RollbackDuration)
	{
		timer.lastRollback <- now;
		timer.rollbackStart <- 0;
		SetTankState(idx, "ASSESS");
	}
}

function AggressiveTankAI::ExecuteThrow(tank, survivors, idx)
{
	local timer = GetTankTimer(idx);
	
	// [MEJORADO] Buscar una posición con LOS a los survivors en lugar de "rock spots"
	if (timer.throwStart == 0)
	{
		timer.throwStart <- Time();
		timer._throwTargetIdx <- 0;
		
		// Opción 1: rock spots (high ground tradicional)
		local spots = MaoLib.NavUtils.FindRockSpots(tank, survivors, ThrowMaxDist);
		if (spots.len() > 0)
		{
			CommandABot({ cmd = 1, bot = tank, pos = spots[0].pos });
		}
		else
		{
			// Opción 2: posición abierta cerca del target más lejano
			local farTarget = null;
			local farDist = 0;
			foreach (s in survivors)
			{
				if (!s || !s.IsValid()) continue;
				local d = (s.GetOrigin() - tank.GetOrigin()).Length();
				if (d > farDist && d < ThrowMaxDist)
				{
					farDist = d;
					farTarget = s;
				}
			}
			
			if (farTarget)
			{
				// Mover a una posición abierta cerca del target lejano
				local targetPos = farTarget.GetOrigin();
				local nav = MaoLib.NavUtils.GetNearestNavArea(targetPos, 500);
				if (nav)
					CommandABot({ cmd = 1, bot = tank, pos = nav.GetCenter() });
				else
					CommandABot({ cmd = 1, bot = tank, pos = targetPos });
			}
			else
			{
				timer.throwStart <- 0;
				SetTankState(idx, "PRESSURE");
				return;
			}
		}
	}
	
	// [NUEVO] Cambiar de target cada ThrowTargetSwitchTime segundos
	// para que el aim predictivo (tankaim.nut) apunte a diferentes survivors
	local throwTime = Time() - timer.throwStart;
	local currentTargetCycle = (throwTime / ThrowTargetSwitchTime).tointeger();
	
	if (currentTargetCycle != timer._throwTargetIdx)
	{
		timer._throwTargetIdx <- currentTargetCycle;
		
		// Elegir un target diferente al actual (preferir el más lejano/abierto)
		local currentTarget = TankTargets[idx];
		local newTarget = null;
		
		foreach (s in survivors)
		{
			if (!s || !s.IsValid()) continue;
			if (s == currentTarget) continue;
			
			// Preferir survivor en espacio abierto (fácil de golpear)
			local sNav = MaoLib.NavUtils.GetNearestNavArea(s.GetOrigin());
			if (sNav && MaoLib.NavUtils.IsOpenArea(sNav))
			{
				newTarget = s;
				break;
			}
			if (!newTarget) newTarget = s;
		}
		
		if (newTarget)
		{
			TankTargets[idx] <- newTarget;
			NetProps.SetPropEntity(tank, "m_lookatPlayer", newTarget);
		}
	}
	
	// Mirar al target actual
	local target = TankTargets[idx];
	if (target && target.IsValid())
	{
		NetProps.SetPropEntity(tank, "m_lookatPlayer", target);
	}
	
	if (throwTime >= 3.0)
	{
		timer.lastThrow <- Time();
		timer.throwStart <- 0;
		SetTankState(idx, "ASSESS");
	}
}

function AggressiveTankAI::ExecuteFlank(tank, survivors, idx)
{
	local timer = GetTankTimer(idx);
	
	if (timer.flankStart == 0)
	{
		timer.flankStart <- Time();
		
		local target = TankTargets[idx];
		if (target && target.IsValid())
		{
			// [MEJORADO] Intentar "left", luego "right", luego fallback a high ground
			local flankPos = null;
			local sides = ["left", "right"];
			
			foreach (side in sides)
			{
				local flanks = MaoLib.NavUtils.FindFlankingRoutes(target, FlankCheckRadius, side);
				if (flanks.len() > 0)
				{
					flankPos = flanks[0].pos;
					break;
				}
			}
			
			// Si no hay ruta de flanqueo, buscar high ground cerca del target
			if (!flankPos)
			{
				local highGround = MaoLib.NavUtils.FindHighGround(target.GetOrigin(), FlankCheckRadius, 40);
				if (highGround)
					flankPos = highGround;
			}
			
			if (flankPos)
			{
				CommandABot({ cmd = 1, bot = tank, pos = flankPos });
			}
			else
			{
				timer.flankStart <- 0;
				SetTankState(idx, "PRESSURE");
				return;
			}
		}
	}
	
	local flankTime = Time() - timer.flankStart;
	if (flankTime >= 4.0)
	{
		timer.lastFlank <- Time();
		timer.flankStart <- 0;
		SetTankState(idx, "COMMIT");
	}
}

function AggressiveTankAI::ExecuteBerserk(tank, survivors)
{
	// [MEJORADO] En BERSERK, priorizar el survivor con MENOS HP que NO esté incapacitado
	// La estrategia es matar rápido a los que pueden pelear, no perder tiempo en incapacitados
	local bestTarget = null;
	local bestScore = -1;
	
	foreach (s in survivors)
	{
		if (!s || !s.IsValid()) continue;
		if (NetProps.GetPropInt(s, "m_lifeState") != 0) continue;
		
		local score = 0;
		local hp = s.GetHealth();
		local dist = (s.GetOrigin() - tank.GetOrigin()).Length();
		
		// Ignorar incapacitados (no pueden pelear, mates al resto primero)
		if (s.IsIncapacitated())
		{
			score = -100;
		}
		else
		{
			// Menos HP = mayor prioridad (más fácil de matar)
			score = 200 - hp;
			// Bonus si está cerca (podemos alcanzarlo rápido)
			if (dist < 500) score += 50;
			// Bonus si está solo (no tiene ayuda cercana)
			local nearbyTeammates = 0;
			foreach (other in survivors)
			{
				if (other != s && other.IsValid() && !other.IsIncapacitated())
				{
					if ((other.GetOrigin() - s.GetOrigin()).Length() < 400)
						nearbyTeammates++;
				}
			}
			score -= nearbyTeammates * 30; // Menos puntos si tiene ayuda cerca
		}
		
		if (score > bestScore)
		{
			bestScore = score;
			bestTarget = s;
		}
	}
	
	// Fallback: si no hay target válido, usar SelectTarget normal
	if (!bestTarget)
		bestTarget = SelectTarget(tank, survivors);
	
	if (bestTarget && bestTarget.IsValid())
	{
		CommandABot({ cmd = 0, bot = tank, target = bestTarget });
		NetProps.SetPropEntity(tank, "m_lookatPlayer", bestTarget);
	}
	else if (survivors.len() > 0)
	{
		CommandABot({ cmd = 1, bot = tank, pos = survivors[0].GetOrigin() });
	}
	
	// [NUEVO] Bunnyhop mode — solo bots, solo en BERSERK
	if (IsPlayerABot(tank))
		StartBunnyhop(tank);
}

// ------------------------------------------------------------------
// HELPERS
// ------------------------------------------------------------------
function AggressiveTankAI::SelectTarget(tank, survivors)
{
	local target = MaoLib.NavUtils.FindMostVulnerableSurvivor(survivors);
	
	if (target && target.IsValid())
		return target;
	
	local nearest = null;
	local nearestDist = 999999.0;
	local tankPos = tank.GetOrigin();
	
	foreach (survivor in survivors)
	{
		if (!survivor || !survivor.IsValid())
			continue;
		
		if (NetProps.GetPropInt(survivor, "m_lifeState") > 0)
			continue;
		
		local dist = (survivor.GetOrigin() - tankPos).Length();
		if (dist < nearestDist)
		{
			nearestDist = dist;
			nearest = survivor;
		}
	}
	
	return nearest;
}

function AggressiveTankAI::GetAliveSurvivors()
{
	local survivors = [];
	
	foreach (player in MaoLib.YieldSurvivors())
	{
		if (!player || !player.IsValid())
			continue;
		
		if (NetProps.GetPropInt(player, "m_lifeState") == 0)
			survivors.append(player);
	}
	
	return survivors;
}

function AggressiveTankAI::GetTankMaxHP(tank)
{
	local idx = tank.GetEntityIndex().tostring();
	
	if ("TankBerserker" in getroottable() && "TankMaxHP" in TankBerserker && idx in TankBerserker.TankMaxHP)
		return TankBerserker.TankMaxHP[idx];
	
	if (idx in TankTimers && "maxHP" in TankTimers[idx])
		return TankTimers[idx].maxHP;
	
	return 6000;
}

function AggressiveTankAI::GetTankState(idx)
{
	if (!(idx in TankStates))
		TankStates[idx] <- "ASSESS";
	return TankStates[idx];
}

function AggressiveTankAI::SetTankState(idx, state)
{
	local oldState = GetTankState(idx);
	if (oldState != state)
	{
		TankStates[idx] <- state;
	}
}

function AggressiveTankAI::GetTankTimer(idx)
{
	if (!(idx in TankTimers))
	{
		TankTimers[idx] <-
		{
			lastCommit = -1
			lastRollback = -1
			lastThrow = -1
			lastFlank = -1
			commitStart = 0
			rollbackStart = 0
			throwStart = 0
			flankStart = 0
			_throwTargetIdx = 0
		}
	}
	return TankTimers[idx];
}

/** Cuenta cuántos survivors tienen línea de visión DIRECTA a una posición */
function AggressiveTankAI::CountLosToPosition(pos, survivors, tank)
{
	local count = 0;
	foreach (s in survivors)
	{
		if (!s || !s.IsValid()) continue;
		if (NetProps.GetPropInt(s, "m_lifeState") != 0) continue;
		
		// Trace desde los ojos del survivor a la posición (a altura de pecho del tank)
		local eyePos = s.EyePosition();
		local targetPos = pos + Vector(0, 0, 48); // Altura de pecho
		
		// HasLineOfSight con ignoreEnt = tank (para que el tank no bloquee su propia posición)
		if (MaoLib.NavUtils.HasLineOfSight(eyePos, targetPos, tank))
			count++;
	}
	return count;
}

/** Verifica si desde una posición el tank puede ver al menos a un survivor */
function AggressiveTankAI::CanSeeAnySurvivor(fromPos, survivors, tank)
{
	foreach (s in survivors)
	{
		if (!s || !s.IsValid()) continue;
		if (NetProps.GetPropInt(s, "m_lifeState") != 0) continue;
		
		local eyePos = s.EyePosition();
		local tankEye = fromPos + Vector(0, 0, 48);
		
		if (MaoLib.NavUtils.HasLineOfSight(tankEye, eyePos, tank))
			return true;
	}
	return false;
}

function AggressiveTankAI::FindRollbackPosition(tank, survivors)
{
	local idx = tank.GetEntityIndex().tostring();
	local tankPos = tank.GetOrigin();
	
	// Cache: reusar resultado si el tank no se movió mucho y el cache es reciente
	if (idx in RollbackCache)
	{
		local cached = RollbackCache[idx];
		if (cached.pos && (cached.pos - tankPos).Length() < 100 && Time() - cached.time < 2.0)
			return cached.pos;
	}
	
	local areas = {};
	NavMesh.GetNavAreasInRadius(tankPos, 800, areas);
	
	local bestPos = null;
	local bestScore = -999999.0;
	
	foreach (nav in areas)
	{
		if (!MaoLib.NavUtils.IsAreaValid(nav))
			continue;
		
		local navPos = nav.GetCenter();
		local distFromTank = (navPos - tankPos).Length();
		
		if (distFromTank < 200)
			continue;
		
		local score = 0.0;
		
		// === ALTURA: bonus por high ground ===
		local heightDiff = navPos.z - tankPos.z;
		if (heightDiff > 30)
			score += heightDiff * 2.0; // Doble peso a la altura
		
		// === COBERTURA: bonus si bloquea LOS de survivors ===
		// Menos survivors que puedan ver esta posición = mejor cobertura
		local losCount = CountLosToPosition(navPos, survivors, tank);
		local totalSurvivors = survivors.len();
		if (totalSurvivors > 0)
		{
			local coverRatio = 1.0 - (losCount.tofloat() / totalSurvivors.tofloat());
			// Si nadie puede ver la posición: +150
			// Si todos pueden verla: +0
			score += coverRatio * 150.0;
		}
		
		// === PEEK: bonus si el tank puede ver al menos a un survivor desde aquí ===
		// Posición con cobertura total pero sin visión = mala (no puede atacar)
		if (CanSeeAnySurvivor(navPos, survivors, tank))
			score += 40.0;
		else
			score -= 30.0; // Penalizar posiciones ciegas
		
		// === CHOKEPOINT: bonus por espacios cerrados (más difícil de rodear) ===
		if (!MaoLib.NavUtils.IsOpenArea(nav))
			score += 60;
		
		// === DISTANCIA: bonus leve por alejarse (más seguro) ===
		if (distFromTank > 400)
			score += 20;
		
		// === FUEGO: penalización fuerte ===
		local fireNearNav = false;
		local inf = null;
		while (inf = Entities.FindByClassnameWithin(inf, "inferno", navPos, 200))
		{
			if (inf && inf.IsValid()) { fireNearNav = true; break; }
		}
		if (fireNearNav)
			score -= 200; // Penalización aumentada
		
		if (score > bestScore)
		{
			bestScore = score;
			bestPos = navPos;
		}
	}
	
	// Guardar en cache
	RollbackCache[idx] <- { pos = bestPos, time = Time() };
	
	return bestPos;
}

// ------------------------------------------------------------------
// THINKER
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// THINKER — callback del timer MaoLib
// ------------------------------------------------------------------
function TankAI_Think()
{
	// Detect new tanks and cleanup dead ones
	AggressiveTankAI.DetectNewTanks();
	AggressiveTankAI.CleanupDeadTanks();
	
	// Run state machine
	AggressiveTankAI.Think();
}

// Timer MaoLib (NO AddThinkToEnt — ver AGENTS.md regla crítica)

function AggressiveTankAI::DetectNewTanks()
{
	foreach (tank in MaoLib.YieldSpecials())
	{
		if (!tank || !tank.IsValid())
			continue;
		
		if (NetProps.GetPropInt(tank, "m_zombieClass") != 8)
			continue;
		
		// CRITICAL: Do NOT re-register dead tanks (body may still exist as entity)
		if (!MaoLib.IsAlive(tank))
			continue;
		
		local idx = tank.GetEntityIndex().tostring();
		
		if (!(idx in TankStates))
		{
			TankStates[idx] <- "ASSESS";
			TankTimers[idx] <-
			{
				lastCommit = -1
				lastRollback = -1
				lastThrow = -1
				lastFlank = -1
				commitStart = 0     // BUG FIX: era -1, las states checkean == 0
				rollbackStart = 0
				throwStart = 0
				flankStart = 0
				_throwTargetIdx = 0
				maxHP = tank.GetHealth()
			}
			
			printl("[TankAI] Aggressive AI initialized for Tank " + idx);
		}
	}
}

function AggressiveTankAI::CleanupDeadTanks()
{
	local activeTanks = {};
	
	foreach (tank in MaoLib.YieldSpecials())
	{
		if (!tank || !tank.IsValid())
			continue;
		
		if (NetProps.GetPropInt(tank, "m_zombieClass") == 8)
		{
			activeTanks[tank.GetEntityIndex().tostring()] <- true;
		}
	}
	
	foreach (idx, _ in TankStates)
	{
		if (!(idx in activeTanks))
		{
			// Grace period: wait 5 seconds after death before cleaning state.
			// The tank's body persists for ~3-5 seconds during death animation,
			// so we keep the state alive during that window.
			if (idx in TankTimers && "_deathTime" in TankTimers[idx])
			{
				if ((Time() - TankTimers[idx]._deathTime) < 5.0)
					continue; // Still in grace period, don't clean yet
			}
			// If no _deathTime recorded (edge case), clean immediately.
			
			// IMPORTANT: Stop bunnyhop timer BEFORE deleting state
			local timerName = "tank_bhop_" + idx;
			if (MaoLib.IsTimerActive(timerName))
				MaoLib.RemoveTimer(timerName);
			
			delete TankStates[idx];
			if (idx in TankTimers)
				delete TankTimers[idx];
			if (idx in TankTargets)
				delete TankTargets[idx];
		}
	}
}

// ------------------------------------------------------------------
// CLEANUP — round_end / mission_lost / map_transition
// ------------------------------------------------------------------
::TankAICleanup <-
{
	function _CleanupAll()
	{
		MaoLib.RemoveTimer("tank_aggressive_ai");
		
		// Limpiar todos los timers de bunnyhop activos
		foreach (idx, _ in AggressiveTankAI.TankStates)
		{
			local timerName = "tank_bhop_" + idx;
			if (MaoLib.IsTimerActive(timerName))
				MaoLib.RemoveTimer(timerName);
		}
		
		// Limpiar estados
		AggressiveTankAI.TankStates.clear();
		AggressiveTankAI.TankTimers.clear();
		AggressiveTankAI.TankTargets.clear();
		AggressiveTankAI.RollbackCache.clear();
		
		printl("[TankAI] Cleanup complete — all timers and states cleared");
	}
	
	function OnGameEvent_player_death(params)
	{
		if (!("userid" in params)) return;
		local victim = GetPlayerFromUserID(params.userid);
		if (!victim || !victim.IsValid()) return;
		if (victim.GetZombieType() != 8) return;
		
		// IMMEDIATELY stop bunnyhop for this tank — don't wait for CleanupDeadTanks()
		AggressiveTankAI.StopBunnyhop(victim);
		
		// Mark death time so CleanupDeadTanks() knows to wait for the death animation
		// (body persists for ~3-5 seconds before the engine removes it)
		local idx = victim.GetEntityIndex().tostring();
		if (idx in AggressiveTankAI.TankTimers)
		{
			AggressiveTankAI.TankTimers[idx]._deathTime <- Time();
		}
	}
	
	function OnGameEvent_round_end(params) { _CleanupAll(); }
	function OnGameEvent_mission_lost(params) { _CleanupAll(); }
	function OnGameEvent_map_transition(params) { _CleanupAll(); }
}

__CollectGameEventCallbacks(::TankAICleanup);

// Timer MaoLib permanente (NO AddThinkToEnt — ver AGENTS.md regla crítica)
if (!MaoLib.IsTimerActive("tank_aggressive_ai"))
{
	MaoLib.AddTimer("tank_aggressive_ai", AggressiveTankAI.ThinkInterval, @() TankAI_Think());
	printl("[TankAI] Aggressive AI Think started (MaoLib timer)");
}

printl("[TankAI] tank_ai.nut loaded - Aggressive Tank AI");