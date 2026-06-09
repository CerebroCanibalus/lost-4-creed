/**
 * ============================================================================
 * MaoLib_AoE - Sistema de Área de Efecto (Area of Effect) para L4D2 VScript
 * ============================================================================
 * Arquitectura: SELECCIÓN -> APLICACIÓN -> VFX (por el caller)
 *
 * Fase 1 - Selectores: devuelven arrays de entidades filtradas
 * Fase 2 - Aplicadores: reciben array de entidades, aplican efecto
 *
 * DEPENDENCIAS: MaoLib (hard dependency)
 * API PUBLICA:
 *   MaoLib.AoE.Select.Circle(origin, radius, opts) -> array entities
 *   MaoLib.AoE.Select.Cone(origin, direction, angle, maxDist, opts) -> array
 *   MaoLib.AoE.Select.Line(origin, direction, length, width, opts) -> array
 *   MaoLib.AoE.Select.ExpandingCircle(origin, maxRadius, duration, pulses, onPulse) -> timer
 *
 *   MaoLib.AoE.Apply.Damage(targets, baseDamage, attacker, dmgType, opts) -> hits
 *   MaoLib.AoE.Apply.Heal(targets, amount, opts) -> healed
 *   MaoLib.AoE.Apply.HealTemp(targets, amount, opts) -> healed
 *   MaoLib.AoE.Apply.Stagger(targets, opts) -> staggered
 *   MaoLib.AoE.Apply.Push(targets, force, opts) -> pushed
 *   MaoLib.AoE.Apply.ModifierSpeed(targets, multiplier, duration, source) -> applied
 *   MaoLib.AoE.Apply.Callback(targets, callback, opts) -> results
 *
 *   MaoLib.AoE.Math.Falloff(dist, radius) -> float
 *   MaoLib.AoE.Math.FalloffQuad(dist, radius) -> float
 *   MaoLib.AoE.Math.IsInCone(point, origin, dir, angle) -> bool
 * ============================================================================
 */

if ("MaoLib_AoE_init_guard" in getroottable()) return;
getroottable()["MaoLib_AoE_init_guard"] <- true;

::MaoLib.AoE <- {
    Debug = 1
    function Dbg(msg) { if (Debug) printl("[MaoLib.AoE][DEBUG] " + msg) }
    function DbgWarn(msg) { printl("[MaoLib.AoE][WARN] " + msg) }
}

::MaoLib.AoE.Select <- {
    // ============================================================
    // SELECTORES - Solo devuelven arrays. NUNCA aplican efectos.
    // ============================================================

    /**
     * Selector circular usando spatial partition del engine.
     * opts:
     *   className: "player" | "infected" | "witch" | "prop_physics" (default "player")
     *   filter: function(entity) -> bool — filtro adicional
     *   requireLOS: bool — requiere line of sight desde origin (default false)
     *   maxResults: int — límite de resultados (default 0 = ilimitado)
     *   aliveOnly: bool — excluye entidades muertas (default true)
     *   ignoreEnt: entity — entidad a excluir de resultados
     */
    function Circle(origin, radius, opts = {})
    {
        if (!origin || radius <= 0)
        {
            ::MaoLib.AoE.DbgWarn("Select.Circle: invalid args")
            return []
        }

        local className = (opts && "className" in opts) ? opts.className : "player"
        local filter = (opts && "filter" in opts) ? opts.filter : null
        local requireLOS = (opts && "requireLOS" in opts) ? opts.requireLOS : false
        local maxResults = (opts && "maxResults" in opts) ? opts.maxResults : 0
        local aliveOnly = (opts && "aliveOnly" in opts) ? opts.aliveOnly : true
        local ignoreEnt = (opts && "ignoreEnt" in opts) ? opts.ignoreEnt : null

        local results = []
        local ent = null
        local count = 0

        while (ent = Entities.FindByClassnameWithin(ent, className, origin, radius))
        {
            if (!ent || !ent.IsValid()) continue
            if (ignoreEnt && ent == ignoreEnt) continue

            if (aliveOnly && !::MaoLib.IsAlive(ent)) continue

            // Verificar radio exacto (FindByClassnameWithin usa bounding box)
            local dist = (ent.GetOrigin() - origin).Length()
            if (dist > radius) continue

            // Line of sight check
            if (requireLOS)
            {
                try
                {
                    if (!::MaoLib.NavUtils.HasLineOfSight(origin, ent.GetOrigin(), ignoreEnt))
                        continue
                }
                catch (e)
                {
                    // Fallback a TraceLine simple si NavUtils no está
                    local frac = TraceLine(origin + Vector(0,0,32), ent.GetOrigin() + Vector(0,0,32), ignoreEnt)
                    if (frac < 0.95) continue
                }
            }

            if (filter != null)
            {
                try { if (!filter(ent)) continue }
                catch (e) { continue }
            }

            results.append(ent)
            count++
            if (maxResults > 0 && count >= maxResults) break
        }

        ::MaoLib.AoE.Dbg("Select.Circle: " + results.len() + " results")
        return results
    }

    /**
     * Selector cónico (sector circular).
     * @param halfAngleDegrees Ángulo MITAD del cono (ej: 45 = 90° total)
     */
    function Cone(origin, direction, halfAngleDegrees, maxDist, opts = {})
    {
        if (!origin || !direction || maxDist <= 0 || halfAngleDegrees <= 0)
        {
            ::MaoLib.AoE.DbgWarn("Select.Cone: invalid args")
            return []
        }

        local dir = Vector(direction.x, direction.y, direction.z)
        if (dir.Norm() <= 0)
        {
            ::MaoLib.AoE.DbgWarn("Select.Cone: zero direction")
            return []
        }

        // Buscar en círculo del tamaño del cono como optimización
        local cName = (opts && "className" in opts) ? opts.className : "player"
        local candidates = Circle(origin, maxDist, opts)

        local cosThreshold = cos(halfAngleDegrees * PI / 180.0)
        local results = []

        foreach (ent in candidates)
        {
            local toTarget = ent.GetOrigin() - origin
            toTarget.Norm()
            local dot = dir.x * toTarget.x + dir.y * toTarget.y + dir.z * toTarget.z
            if (dot >= cosThreshold)
                results.append(ent)
        }

        ::MaoLib.AoE.Dbg("Select.Cone: " + results.len() + " results")
        return results
    }

    /**
     * Selector lineal (cápsula).
     * Útil para: rayos, disparos penetrantes, charge de Charger.
     */
    function Line(origin, direction, length, width, opts = {})
    {
        if (!origin || !direction || length <= 0 || width <= 0)
        {
            ::MaoLib.AoE.DbgWarn("Select.Line: invalid args")
            return []
        }

        local dir = Vector(direction.x, direction.y, direction.z)
        dir.Norm()

        // Buscar en caja aproximada
        local searchRadius = sqrt(length*length + width*width) * 0.5
        local candidates = Circle(origin + dir * (length * 0.5), searchRadius, opts)

        local results = []
        foreach (ent in candidates)
        {
            local pos = ent.GetOrigin()
            local toPoint = pos - origin
            local proj = toPoint.x * dir.x + toPoint.y * dir.y + toPoint.z * dir.z
            if (proj < 0 || proj > length) continue

            local closest = origin + dir * proj
            local perpDist = (pos - closest).Length()
            if (perpDist <= width)
                results.append(ent)
        }

        ::MaoLib.AoE.Dbg("Select.Line: " + results.len() + " results")
        return results
    }

    /**
     * Selector de círculo expansivo (progresivo).
     * Ejecuta onPulse en pulsos mientras expande.
     * Útil para: ondas de choque, explosiones que crecen.
     * @return timerName para cancelar, o null
     */
    function ExpandingCircle(origin, maxRadius, duration, pulses, onPulse)
    {
        if (!origin || maxRadius <= 0 || duration <= 0 || pulses <= 0 || !onPulse)
        {
            ::MaoLib.AoE.DbgWarn("Select.ExpandingCircle: invalid args")
            return null
        }

        local interval = duration / pulses.tofloat()
        local currentPulse = 0
        local allTargetsSoFar = []
        local timerName = "maolib_aoe_exp_" + UniqueString()

        local function DoPulse()
        {
            currentPulse++
            local progress = currentPulse / pulses.tofloat()
            local currentRadius = maxRadius * progress
            local prevRadius = (currentPulse > 1) ? (maxRadius * ((currentPulse - 1) / pulses.tofloat())) : 0

            local newTargets = []
            if (currentRadius > 0)
            {
                local candidates = Circle(origin, currentRadius, { className = "player", aliveOnly = true })
                foreach (ent in candidates)
                {
                    local dist = (ent.GetOrigin() - origin).Length()
                    if (dist > prevRadius && dist <= currentRadius)
                    {
                        local dup = false
                        foreach (t in allTargetsSoFar) { if (t == ent) { dup = true; break } }
                        if (!dup)
                        {
                            newTargets.append(ent)
                            allTargetsSoFar.append(ent)
                        }
                    }
                }
            }

            try { onPulse(currentRadius, newTargets, allTargetsSoFar) }
            catch (e) { ::MaoLib.AoE.DbgWarn("ExpandingCircle onPulse error: " + e) }

            if (currentPulse >= pulses)
                ::MaoLib.RemoveTimer(timerName)
        }

        ::MaoLib.AddTimer(timerName, interval, function() { DoPulse(); })
        try { onPulse(0, [], []) } catch (e) {}

        ::MaoLib.AoE.Dbg("Select.ExpandingCircle: timer=" + timerName)
        return timerName
    }
}

::MaoLib.AoE.Apply <- {
    // ============================================================
    // APLICADORES - Reciben array de entidades. NUNCA buscan.
    // ============================================================

    /**
     * Daño a múltiples entidades.
     * opts:
     *   falloff: "none" | "linear" | "quadratic"
     *   origin: Vector origen (requerido para falloff)
     *   radius: float (requerido para falloff)
     *   minDamage: float mínimo (default 0)
     *   dmgMultiplier: float (default 1.0)
     *   onHit: callback(entity, damageDealt)
     */
    function Damage(targets, baseDamage, attacker, dmgType, opts = {})
    {
        if (!targets || targets.len() == 0 || baseDamage <= 0) return 0

        local falloff = (opts && "falloff" in opts) ? opts.falloff : "none"
        local origin = (opts && "origin" in opts) ? opts.origin : null
        local radius = (opts && "radius" in opts) ? opts.radius : 0
        local minDmg = (opts && "minDamage" in opts) ? opts.minDamage : 0
        local dmgMult = (opts && "dmgMultiplier" in opts) ? opts.dmgMultiplier : 1.0
        local onHit = (opts && "onHit" in opts) ? opts.onHit : null

        if (falloff != "none" && (!origin || radius <= 0))
        {
            ::MaoLib.AoE.DbgWarn("Apply.Damage: falloff requires origin+radius")
            falloff = "none"
        }

        local hitCount = 0
        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid()) continue
            if (!::MaoLib.IsAlive(ent)) continue

            local multiplier = 1.0
            if (falloff != "none" && origin)
            {
                local dist = (ent.GetOrigin() - origin).Length()
                if (falloff == "linear")
                    multiplier = ::MaoLib.AoE.Math.Falloff(dist, radius)
                else if (falloff == "quadratic")
                    multiplier = ::MaoLib.AoE.Math.FalloffQuad(dist, radius)
            }

            local dmg = baseDamage * multiplier * dmgMult
            if (dmg < minDmg) dmg = minDmg
            dmg = dmg.tointeger()
            if (dmg <= 0) continue

            try
            {
                ent.TakeDamage(dmg, dmgType, attacker)
                hitCount++
                if (onHit != null) { try { onHit(ent, dmg) } catch (e) {} }
            }
            catch (e) { ::MaoLib.AoE.DbgWarn("Apply.Damage failed: " + e) }
        }

        ::MaoLib.AoE.Dbg("Apply.Damage: " + hitCount + "/" + targets.len())
        return hitCount
    }

    /**
     * Curación real (SetHealth) a múltiples entidades.
     * opts:
     *   maxHealthCap: bool (default true)
     *   onHeal: callback(entity, amountHealed)
     */
    function Heal(targets, amount, opts = {})
    {
        if (!targets || targets.len() == 0 || amount <= 0) return 0

        local capMax = (opts && "maxHealthCap" in opts) ? opts.maxHealthCap : true
        local onHeal = (opts && "onHeal" in opts) ? opts.onHeal : null

        local healed = 0
        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid()) continue
            if (!ent.IsPlayer() || !ent.IsSurvivor()) continue
            if (!::MaoLib.IsAlive(ent)) continue

            try
            {
                local curr = ent.GetHealth()
                local maxHp = ent.GetMaxHealth()
                local newHp = curr + amount
                if (capMax && newHp > maxHp) newHp = maxHp
                if (newHp > curr)
                {
                    ent.SetHealth(newHp)
                    healed++
                    if (onHeal != null) { try { onHeal(ent, newHp - curr) } catch (e) {} }
                }
            }
            catch (e) { ::MaoLib.AoE.DbgWarn("Apply.Heal failed: " + e) }
        }

        return healed
    }

    /**
     * Curación temporal (HP buffer) a múltiples entidades.
     */
    function HealTemp(targets, amount, opts = {})
    {
        if (!targets || targets.len() == 0 || amount <= 0) return 0

        local onHeal = (opts && "onHeal" in opts) ? opts.onHeal : null

        local healed = 0
        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid()) continue
            if (!ent.IsPlayer() || !ent.IsSurvivor()) continue
            if (!::MaoLib.IsAlive(ent)) continue

            try
            {
                local curr = ent.GetHealthBuffer()
                ent.SetHealthBuffer(curr + amount)
                healed++
                if (onHeal != null) { try { onHeal(ent, amount) } catch (e) {} }
            }
            catch (e) { ::MaoLib.AoE.DbgWarn("Apply.HealTemp failed: " + e) }
        }

        return healed
    }

    /**
     * Stagger a múltiples entidades.
     * opts:
     *   direction: Vector dirección. Si null, se calcula desde origin.
     *   origin: Vector origen (requerido si direction es null)
     *   onStagger: callback(entity)
     */
    function Stagger(targets, opts = {})
    {
        if (!targets || targets.len() == 0) return 0

        local direction = (opts && "direction" in opts) ? opts.direction : null
        local origin = (opts && "origin" in opts) ? opts.origin : null
        local onStagger = (opts && "onStagger" in opts) ? opts.onStagger : null

        if (direction == null && origin == null)
        {
            ::MaoLib.AoE.DbgWarn("Apply.Stagger: requires direction or origin")
            return 0
        }

        local staggered = 0
        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid()) continue
            if (!::MaoLib.IsAlive(ent)) continue

            try
            {
                local dir = direction
                if (dir == null)
                {
                    dir = ent.GetOrigin() - origin
                    dir.Norm()
                }
                ent.Stagger(dir)
                staggered++
                if (onStagger != null) { try { onStagger(ent) } catch (e) {} }
            }
            catch (e) { ::MaoLib.AoE.DbgWarn("Apply.Stagger failed: " + e) }
        }

        return staggered
    }

    /**
     * Empuje físico a múltiples entidades.
     * opts:
     *   direction: Vector dirección base. Si null, se calcula desde origin.
     *   origin: Vector origen (requerido si direction es null)
     *   falloff: "none" | "linear" | "quadratic" (default "none")
     *   radius: float (requerido para falloff)
     *   verticalBoost: float boost Z (default 0)
     *   useImpulse: bool (default true) — ApplyAbsVelocityImpulse vs SetVelocity
     *   onPush: callback(entity, velocity)
     */
    function Push(targets, force, opts = {})
    {
        if (!targets || targets.len() == 0 || force == 0) return 0

        local direction = (opts && "direction" in opts) ? opts.direction : null
        local origin = (opts && "origin" in opts) ? opts.origin : null
        local falloff = (opts && "falloff" in opts) ? opts.falloff : "none"
        local radius = (opts && "radius" in opts) ? opts.radius : 0
        local verticalBoost = (opts && "verticalBoost" in opts) ? opts.verticalBoost : 0
        local useImpulse = (opts && "useImpulse" in opts) ? opts.useImpulse : true
        local onPush = (opts && "onPush" in opts) ? opts.onPush : null

        if (direction == null && origin == null)
        {
            ::MaoLib.AoE.DbgWarn("Apply.Push: requires direction or origin")
            return 0
        }

        local pushed = 0
        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid()) continue
            if (!::MaoLib.IsAlive(ent)) continue

            local multiplier = 1.0
            if (falloff != "none" && origin && radius > 0)
            {
                local dist = (ent.GetOrigin() - origin).Length()
                if (falloff == "linear")
                    multiplier = ::MaoLib.AoE.Math.Falloff(dist, radius)
                else if (falloff == "quadratic")
                    multiplier = ::MaoLib.AoE.Math.FalloffQuad(dist, radius)
            }

            if (multiplier <= 0) continue

            try
            {
                local dir = direction
                if (dir == null)
                {
                    dir = ent.GetOrigin() - origin
                    dir.Norm()
                }

                local vel = dir * force * multiplier
                if (verticalBoost != 0)
                    vel.z += verticalBoost * multiplier

                if (useImpulse)
                    ent.ApplyAbsVelocityImpulse(vel)
                else
                    ent.SetVelocity(vel)

                pushed++
                if (onPush != null) { try { onPush(ent, vel) } catch (e) {} }
            }
            catch (e) { ::MaoLib.AoE.DbgWarn("Apply.Push failed: " + e) }
        }

        return pushed
    }

    /**
     * Modificador de velocidad a múltiples entidades vía MaoLib.Modifiers.
     */
    function ModifierSpeed(targets, multiplier, duration, source = "aoe_speed")
    {
        if (!targets || targets.len() == 0) return 0

        local applied = 0
        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid()) continue
            if (!ent.IsPlayer() || !::MaoLib.IsAlive(ent)) continue

            try
            {
                ::MaoLib.Modifiers.RegisterSpeed(ent, multiplier, duration, source)
                applied++
            }
            catch (e) { ::MaoLib.AoE.DbgWarn("Apply.ModifierSpeed failed: " + e) }
        }

        return applied
    }

    /**
     * Modificador de fricción a múltiples entidades vía MaoLib.Modifiers.
     */
    function ModifierFriction(targets, friction, duration, source = "aoe_friction")
    {
        if (!targets || targets.len() == 0) return 0

        local applied = 0
        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid()) continue
            if (!ent.IsPlayer() || !::MaoLib.IsAlive(ent)) continue

            try
            {
                ::MaoLib.Modifiers.RegisterFriction(ent, friction, duration, source)
                applied++
            }
            catch (e) { ::MaoLib.AoE.DbgWarn("Apply.ModifierFriction failed: " + e) }
        }

        return applied
    }

    /**
     * Callback arbitrario a cada entidad.
     * @return array de { entity, result }
     */
    function Callback(targets, callback, opts = {})
    {
        if (!targets || targets.len() == 0 || !callback) return []

        local results = []
        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid()) continue
            try
            {
                local res = callback(ent)
                results.append({ entity = ent, result = res })
            }
            catch (e) { ::MaoLib.AoE.DbgWarn("Apply.Callback failed: " + e) }
        }

        return results
    }
}

::MaoLib.AoE.Math <- {
    // ============================================================
    // MATEMÁTICAS DE ÁREA
    // ============================================================

    /**
     * Atenuación lineal. 1.0 en centro, 0.0 en borde.
     */
    function Falloff(dist, radius)
    {
        if (radius <= 0) return 0.0
        if (dist <= 0) return 1.0
        if (dist >= radius) return 0.0
        return 1.0 - (dist / radius)
    }

    /**
     * Atenuación cuadrática.
     */
    function FalloffQuad(dist, radius)
    {
        if (radius <= 0) return 0.0
        if (dist <= 0) return 1.0
        if (dist >= radius) return 0.0
        local t = dist / radius
        return 1.0 - (t * t)
    }

    /**
     * Verifica si un punto está dentro de un cono.
     */
    function IsInCone(point, origin, direction, halfAngleDegrees)
    {
        if (!point || !origin || !direction || halfAngleDegrees <= 0) return false

        local dir = Vector(direction.x, direction.y, direction.z)
        if (dir.Norm() <= 0) return false

        local toPoint = point - origin
        toPoint.Norm()
        local dot = dir.x * toPoint.x + dir.y * toPoint.y + dir.z * toPoint.z
        return dot >= cos(halfAngleDegrees * PI / 180.0)
    }

    /**
     * Verifica si un punto está dentro de radio.
     */
    function IsInRadius(point, origin, radius)
    {
        if (!point || !origin || radius <= 0) return false
        return (point - origin).Length() <= radius
    }
}

printl("[MaoLib.AoE] Loaded successfully")
