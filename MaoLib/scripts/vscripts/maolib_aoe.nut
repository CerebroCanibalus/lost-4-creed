// ============================================================================
// MaoLib.AoE — Area of Effect System for L4D2
// ============================================================================
// Architecture: SELECTION → APPLICATION
//   Phase 1: Selectors find entities (Circle, Cone, Line, ExpandingCircle)
//   Phase 2: Applicators affect entities (Damage, Heal, Stagger, Push, etc.)
//
// USAGE:
//   // 1. Select targets
//   local targets = MaoLib.AoE.Select.Circle(origin, 500, { className = "infected" })
//   
//   // 2. Apply effect
//   MaoLib.AoE.Apply.Damage(targets, 50, attacker, (1 << 1), { falloff = "linear", origin = origin, radius = 500 })
//   MaoLib.AoE.Apply.Heal(targets, 25)
//   MaoLib.AoE.Apply.HealTemp(targets, 50)
//   MaoLib.AoE.Apply.Stagger(targets, { origin = origin })
//   MaoLib.AoE.Apply.Push(targets, 500, { origin = origin, verticalBoost = 100 })
//   MaoLib.AoE.Apply.ModifierSpeed(targets, 0.5, 3.0, "my_slow")
//   MaoLib.AoE.Apply.Callback(targets, function(ent) { ent.Kill() })
//
//   // 3. Expanding circle (progressive wave)
//   MaoLib.AoE.Select.ExpandingCircle(origin, 1000, 2.0, 10,
//     function(radius, newTargets, allTargets) {
//       MaoLib.AoE.Apply.Damage(newTargets, 10, attacker, (1 << 1))
//     })
// ============================================================================

if ("MaoLib_AoE_init_guard" in getroottable()) return;
getroottable()["MaoLib_AoE_init_guard"] <- true;

::MaoLib.AoE <- {
    Debug = 0
    function Dbg(msg) { if (Debug) printl("[MaoLib.AoE][DEBUG] " + msg) }
    function DbgWarn(msg) { printl("[MaoLib.AoE][WARN] " + msg) }
}

::MaoLib.AoE.Select <- {
    // ============================================================
    // SELECTORS — Only return entity arrays. NEVER apply effects.
    // ============================================================

    /**
     * Circular area selection.
     * @param {Vector} origin  Center point
     * @param {float}  radius  Search radius
     * @param {table}  opts    Options:
     *   className:   "player" | "infected" | "witch" | "prop_physics" (default "player")
     *   filter:      function(entity) -> bool — additional filtering
     *   requireLOS:  bool — require line of sight from origin (default false)
     *   maxResults:  int — result limit (default 0 = unlimited)
     *   aliveOnly:   bool — exclude dead entities (default true)
     *   ignoreEnt:   entity — entity to exclude
     * @return {array} of entity handles
     */
    function Circle(origin, radius, opts = {})
    {
        if (!origin || radius <= 0) { ::MaoLib.AoE.DbgWarn("Select.Circle: invalid args"); return [] }

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

            // Precise distance check (FindByClassnameWithin uses bounding box)
            if ((ent.GetOrigin() - origin).Length() > radius) continue

            if (requireLOS)
            {
                try {
                    if (!::MaoLib.NavUtils.HasLineOfSight(origin, ent.GetOrigin(), ignoreEnt)) continue
                } catch (e) {
                    local frac = TraceLine(origin + Vector(0,0,32), ent.GetOrigin() + Vector(0,0,32), ignoreEnt)
                    if (frac < 0.95) continue
                }
            }

            if (filter != null) { try { if (!filter(ent)) continue } catch (e) { continue } }

            results.append(ent)
            count++
            if (maxResults > 0 && count >= maxResults) break
        }

        return results
    }

    /**
     * Cone (sector) selection.
     * @param {Vector} origin          Apex of cone
     * @param {Vector} direction       Forward direction
     * @param {float}  halfAngleDegrees  Half-angle of cone (45 = 90° total)
     * @param {float}  maxDist          Maximum distance
     * @param {table}  opts            Same as Circle
     */
    function Cone(origin, direction, halfAngleDegrees, maxDist, opts = {})
    {
        if (!origin || !direction || maxDist <= 0 || halfAngleDegrees <= 0) return []

        local dir = Vector(direction.x, direction.y, direction.z)
        if (dir.Norm() <= 0) return []

        local cName = (opts && "className" in opts) ? opts.className : "player"
        local candidates = Circle(origin, maxDist, opts)
        local cosThreshold = cos(halfAngleDegrees * PI / 180.0)
        local results = []

        foreach (ent in candidates)
        {
            local toTarget = ent.GetOrigin() - origin
            toTarget.Norm()
            if (dir.Dot(toTarget) >= cosThreshold) results.append(ent)
        }

        return results
    }

    /**
     * Line (capsule) selection.
     * Useful for: piercing bullets, Charger charges, beams.
     */
    function Line(origin, direction, length, width, opts = {})
    {
        if (!origin || !direction || length <= 0 || width <= 0) return []

        local dir = Vector(direction.x, direction.y, direction.z)
        dir.Norm()

        local searchRadius = sqrt(length*length + width*width) * 0.5
        local candidates = Circle(origin + dir * (length * 0.5), searchRadius, opts)
        local results = []

        foreach (ent in candidates)
        {
            local pos = ent.GetOrigin()
            local toPoint = pos - origin
            local proj = toPoint.Dot(dir)
            if (proj < 0 || proj > length) continue

            local closest = origin + dir * proj
            if ((pos - closest).Length() <= width) results.append(ent)
        }

        return results
    }

    /**
     * Expanding circle (progressive wave).
     * Calls onPulse(radius, newTargets, allTargets) on each pulse.
     * @return timerName (can be used with RemoveTimer to cancel)
     */
    function ExpandingCircle(origin, maxRadius, duration, pulses, onPulse)
    {
        if (!origin || maxRadius <= 0 || duration <= 0 || pulses <= 0 || !onPulse)
        { ::MaoLib.AoE.DbgWarn("Select.ExpandingCircle: invalid args"); return null }

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
                        if (!dup) { newTargets.append(ent); allTargetsSoFar.append(ent) }
                    }
                }
            }

            try { onPulse(currentRadius, newTargets, allTargetsSoFar) }
            catch (e) { ::MaoLib.AoE.DbgWarn("ExpandingCircle onPulse error: " + e) }

            if (currentPulse >= pulses) ::MaoLib.RemoveTimer(timerName)
        }

        ::MaoLib.AddTimer(timerName, interval, function() { DoPulse() })
        try { onPulse(0, [], []) } catch (e) {}

        return timerName
    }
}

::MaoLib.AoE.Apply <- {
    // ============================================================
    // APPLICATORS — Receive entity arrays. NEVER search for entities.
    // ============================================================

    /**
     * Deal damage to multiple entities.
     * @param {array}  targets       Entity array
     * @param {float}  baseDamage    Damage amount
     * @param {entity} attacker      Attacker entity
     * @param {int}    dmgType       Damage type bitmask (e.g., 1<<1 = DMG_BULLET)
     * @param {table}  opts:
     *   falloff:      "none"|"linear"|"quadratic"
     *   origin/radius: required for falloff
     *   minDamage:    float minimum after falloff
     *   dmgMultiplier: float (default 1.0)
     *   onHit:        callback(entity, damageDealt)
     * @return {int} number of hits
     *
     * ⚠️ CRITICAL: If calling from OnGameEvent_player_hurt/infected_hurt,
     * you MUST use a _processingDamageEvent guard flag to prevent
     * infinite recursion (TakeDamage → event → TakeDamage → ...).
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

        if (falloff != "none" && (!origin || radius <= 0)) falloff = "none"

        local hitCount = 0
        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid() || !::MaoLib.IsAlive(ent)) continue

            local multiplier = 1.0
            if (falloff != "none" && origin)
            {
                local dist = (ent.GetOrigin() - origin).Length()
                if (falloff == "linear")    multiplier = ::MaoLib.AoE.Math.Falloff(dist, radius)
                else if (falloff == "quadratic") multiplier = ::MaoLib.AoE.Math.FalloffQuad(dist, radius)
            }

            local dmg = baseDamage * multiplier * dmgMult
            if (dmg < minDmg) dmg = minDmg
            dmg = dmg.tointeger()
            if (dmg <= 0) continue

            try {
                ent.TakeDamage(dmg, dmgType, attacker)
                hitCount++
                if (onHit != null) { try { onHit(ent, dmg) } catch (e) {} }
            } catch (e) { ::MaoLib.AoE.DbgWarn("Apply.Damage failed: " + e) }
        }

        return hitCount
    }

    /**
     * Heal (real HP) multiple entities.
     * Only works on survivor players.
     */
    function Heal(targets, amount, opts = {})
    {
        if (!targets || targets.len() == 0 || amount <= 0) return 0

        local capMax = (opts && "maxHealthCap" in opts) ? opts.maxHealthCap : true
        local onHeal = (opts && "onHeal" in opts) ? opts.onHeal : null
        local healed = 0

        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid() || !ent.IsPlayer() || !ent.IsSurvivor()) continue
            if (!::MaoLib.IsAlive(ent)) continue

            try {
                local curr = ent.GetHealth()
                local maxHp = ent.GetMaxHealth()
                local newHp = curr + amount
                if (capMax && newHp > maxHp) newHp = maxHp
                if (newHp > curr) {
                    ent.SetHealth(newHp)
                    healed++
                    if (onHeal != null) { try { onHeal(ent, newHp - curr) } catch (e) {} }
                }
            } catch (e) { ::MaoLib.AoE.DbgWarn("Apply.Heal failed: " + e) }
        }
        return healed
    }

    /**
     * Heal temporary HP (health buffer).
     */
    function HealTemp(targets, amount, opts = {})
    {
        if (!targets || targets.len() == 0 || amount <= 0) return 0

        local onHeal = (opts && "onHeal" in opts) ? opts.onHeal : null
        local healed = 0

        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid() || !ent.IsPlayer() || !ent.IsSurvivor()) continue
            if (!::MaoLib.IsAlive(ent)) continue

            try {
                ent.SetHealthBuffer(ent.GetHealthBuffer() + amount)
                healed++
                if (onHeal != null) { try { onHeal(ent, amount) } catch (e) {} }
            } catch (e) { ::MaoLib.AoE.DbgWarn("Apply.HealTemp failed: " + e) }
        }
        return healed
    }

    /**
     * Stagger multiple entities.
     */
    function Stagger(targets, opts = {})
    {
        if (!targets || targets.len() == 0) return 0

        local direction = (opts && "direction" in opts) ? opts.direction : null
        local origin = (opts && "origin" in opts) ? opts.origin : null
        local onStagger = (opts && "onStagger" in opts) ? opts.onStagger : null

        if (direction == null && origin == null) { ::MaoLib.AoE.DbgWarn("Apply.Stagger: requires direction or origin"); return 0 }

        local count = 0
        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid() || !::MaoLib.IsAlive(ent)) continue
            try {
                local dir = direction
                if (dir == null) { dir = ent.GetOrigin() - origin; dir.Norm() }
                ent.Stagger(dir)
                count++
                if (onStagger != null) { try { onStagger(ent) } catch (e) {} }
            } catch (e) { ::MaoLib.AoE.DbgWarn("Apply.Stagger failed: " + e) }
        }
        return count
    }

    /**
     * Push (physics impulse) multiple entities.
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

        if (direction == null && origin == null) { ::MaoLib.AoE.DbgWarn("Apply.Push: requires direction or origin"); return 0 }

        local pushed = 0
        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid() || !::MaoLib.IsAlive(ent)) continue

            local multiplier = 1.0
            if (falloff != "none" && origin && radius > 0)
            {
                local dist = (ent.GetOrigin() - origin).Length()
                if (falloff == "linear")    multiplier = ::MaoLib.AoE.Math.Falloff(dist, radius)
                else if (falloff == "quadratic") multiplier = ::MaoLib.AoE.Math.FalloffQuad(dist, radius)
            }
            if (multiplier <= 0) continue

            try {
                local dir = direction
                if (dir == null) { dir = ent.GetOrigin() - origin; dir.Norm() }
                local vel = dir * force * multiplier
                if (verticalBoost != 0) vel.z += verticalBoost * multiplier

                if (useImpulse) ent.ApplyAbsVelocityImpulse(vel)
                else ent.SetVelocity(vel)

                pushed++
                if (onPush != null) { try { onPush(ent, vel) } catch (e) {} }
            } catch (e) { ::MaoLib.AoE.DbgWarn("Apply.Push failed: " + e) }
        }
        return pushed
    }

    /**
     * Apply speed modifier via MaoLib.Modifiers.
     */
    function ModifierSpeed(targets, multiplier, duration, source = "aoe_speed")
    {
        if (!targets || targets.len() == 0) return 0
        local applied = 0
        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid() || !ent.IsPlayer() || !::MaoLib.IsAlive(ent)) continue
            try { ::MaoLib.Modifiers.RegisterSpeed(ent, multiplier, duration, source); applied++ }
            catch (e) { ::MaoLib.AoE.DbgWarn("Apply.ModifierSpeed failed: " + e) }
        }
        return applied
    }

    /**
     * Apply friction modifier via MaoLib.Modifiers.
     */
    function ModifierFriction(targets, friction, duration, source = "aoe_friction")
    {
        if (!targets || targets.len() == 0) return 0
        local applied = 0
        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid() || !ent.IsPlayer() || !::MaoLib.IsAlive(ent)) continue
            try { ::MaoLib.Modifiers.RegisterFriction(ent, friction, duration, source); applied++ }
            catch (e) { ::MaoLib.AoE.DbgWarn("Apply.ModifierFriction failed: " + e) }
        }
        return applied
    }

    /**
     * Apply arbitrary callback to each entity.
     * @return array of { entity, result }
     */
    function Callback(targets, callback, opts = {})
    {
        if (!targets || targets.len() == 0 || !callback) return []
        local results = []
        foreach (ent in targets)
        {
            if (!ent || !ent.IsValid()) continue
            try { results.append({ entity = ent, result = callback(ent) }) }
            catch (e) { ::MaoLib.AoE.DbgWarn("Apply.Callback failed: " + e) }
        }
        return results
    }
}

::MaoLib.AoE.Math <- {
    function Falloff(dist, radius) {
        if (radius <= 0) return 0.0
        if (dist <= 0) return 1.0
        if (dist >= radius) return 0.0
        return 1.0 - (dist / radius)
    }

    function FalloffQuad(dist, radius) {
        if (radius <= 0) return 0.0
        if (dist <= 0) return 1.0
        if (dist >= radius) return 0.0
        local t = dist / radius
        return 1.0 - (t * t)
    }

    function IsInCone(point, origin, direction, halfAngleDegrees) {
        if (!point || !origin || !direction || halfAngleDegrees <= 0) return false
        local dir = Vector(direction.x, direction.y, direction.z)
        if (dir.Norm() <= 0) return false
        local toPoint = (point - origin); toPoint.Norm()
        return dir.Dot(toPoint) >= cos(halfAngleDegrees * PI / 180.0)
    }

    function IsInRadius(point, origin, radius) {
        if (!point || !origin || radius <= 0) return false
        return (point - origin).Length() <= radius
    }
}

printl("[MaoLib.AoE] Loaded successfully")
