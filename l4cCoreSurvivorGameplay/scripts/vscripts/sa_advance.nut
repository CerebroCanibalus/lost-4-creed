// survivor_ai/advance.nut - Map advancement for all-bot scenarios
// When there are no human survivors, bots need explicit commands
// to advance through the map. Vanilla AI doesn't do this automatically.
//
// Strategy:
// 1. Detect all-bot mode (no human players)
// 2. Designated LEADER: Zoey (character 1) preferred, Nick (character 4) fallback
//    - L4D1 cast campaigns: Zoey leads
//    - L4D2 cast campaigns: Nick leads
// 3. Leader advances toward the nav frontier (nav areas ahead via GetNavAhead)
// 4. Other bots follow/regroup toward the leader
//
// Priority: 30 (below combat 70-100, checked before close_door 35 in think loop)

// ------------------------------------------------------------------
// CHARACTER CONSTANTS (m_survivorCharacter netprop)
// ------------------------------------------------------------------
::SURVIVOR_BILL <- 0
::SURVIVOR_ZOEY <- 1
::SURVIVOR_FRANCIS <- 2
::SURVIVOR_LOUIS <- 3
::SURVIVOR_NICK <- 4
::SURVIVOR_ROCHELLE <- 5
::SURVIVOR_COACH <- 6
::SURVIVOR_ELLIS <- 7

// ------------------------------------------------------------------
// ALL-BOT DETECTION
// ------------------------------------------------------------------

function SurvivorAI::HasHumanPlayer()
{
    // 🚀 PERF (2026-08-10): Cache con TTL — el team de un player rara vez
    // cambia (spawn/team switch), y esto se llamaba ~3× por tick por bot
    // (DetectPositionTask, DetectAdvanceTask, HasNearbyThreats). Cada llamada
    // iteraba 32 slots con PlayerInstanceFromIndex. Ahora: 1 scan cada 0.5s.
    local now = Time()
    if (this.HumanCheckCache && (now - this.HumanCheckCache.time) < this.HumanCheckTTL)
        return this.HumanCheckCache.result
    
    local result = false
    foreach (player in MaoLib.YieldActiveSurvivors())
    {
        if (!IsPlayerABot(player))
        {
            result = true
            break
        }
    }
    
    this.HumanCheckCache = { time = now, result = result }
    return result
}

// ------------------------------------------------------------------
// GET LEADER — Find the designated advance leader
// Priority: Zoey > Nick > any survivor
// ------------------------------------------------------------------

function SurvivorAI::GetLeader()
{
    local zoey = null
    local nick = null
    local anySurvivor = null
    
    foreach (uid, s in this.CachedSurvivors)
    {
        if (!s || !s.IsValid()) continue
        // (2026-08-10) Un espectador en CachedSurvivors NO puede ser líder
        // designado (un host espectando con Zoey robaría el liderazgo).
        if (!MaoLib.IsActiveSurvivor(s)) continue
        if (NetProps.GetPropInt(s, "m_lifeState") != 0) continue
        
        local char = NetProps.GetPropInt(s, "m_survivorCharacter")
        if (char == SURVIVOR_ZOEY)
            zoey = s
        else if (char == SURVIVOR_NICK)
            nick = s
        else
            anySurvivor = s
    }
    
    // Zoey > Nick > any other survivor
    if (zoey) return zoey
    if (nick) return nick
    return anySurvivor
}

// ------------------------------------------------------------------
// GET ADVANCE TARGET — Find where to send the bot
// Leader advances toward nav frontier via GetNavAhead.
// Followers move toward the leader's position + forward offset.
// ------------------------------------------------------------------

function SurvivorAI::GetAdvanceTarget(bot)
{
    if (!bot || !bot.IsValid())
        return null
    
    // 1. Get leader — usa Blackboard.Leader (actualizado cada 0.15s por
    // UpdateBlackboard con histéresis). 🚀 PERF (2026-08-10): antes se
    // llamaba GetDynamicLeader() aquí → 2× por bot por tick (Blackboard
    // + este). Ahora: 1 cálculo cada 0.15s compartido por todos los bots.
    // 🐛 FIX (2026-08-10): IsActiveSurvivor — un espectador tiene lifeState
    // 0 pero team 1; si quedara como líder los bots seguirían posición basura.
    local leader = this.Blackboard.Leader
    if (!leader || !MaoLib.IsActiveSurvivor(leader))
        leader = this.GetDynamicLeader()
    
    // 🐛 FIX (2026-08-10): FALLBACK — sin líder válido (muerto, no spawneó,
    // todos incap), el bot se auto-designa líder temporal (self-lead) y
    // avanza solo. Sin esto, un líder muerto/fantasma paraba a todo el
    // equipo (0 movimiento). El self-lead es seguro: GetNavAhead() ya tiene
    // sus propios guards (saferoom, flow info, safety gate).
    if (!leader || !leader.IsValid() || NetProps.GetPropInt(leader, "m_lifeState") != 0)
    {
        this.LogDebug("ADVANCE", "Bot " + bot.GetPlayerUserId() + " no leader — self-lead")
        return this.GetNavAhead(bot)
    }
    
    // If this bot IS the leader, find a nav area ahead to advance to
    if (leader == bot)
    {
        return this.GetNavAhead(bot)
    }
    
    // For followers: move toward leader's position (+ buffer to avoid crowding)
    local leaderPos = leader.GetOrigin()
    local botPos = bot.GetOrigin()
    local distToLeader = (botPos - leaderPos).Length()
    
    // 🐛 FIX: If leader is inside the saferoom (checkpoint area), followers
    // should NOT advance toward it — that's the "bots leave then re-enter
    // the saferoom" bug. Wait at the saferoom edge instead.
    local leaderNav = NavMesh.GetNearestNavArea(leaderPos, 100, false, true)
    if (leaderNav && leaderNav.HasAttributes(NAV_MESH_CHECKPOINT))
    {
        // Leader is in the saferoom — followers hold position near the exit
        local exitNav = this.FindExitNavArea(leaderPos)
        if (exitNav)
            return exitNav
        // No exit found — just stay put (return null = no advance)
        return null
    }
    
    // If already close to leader, leader can pull them forward
    // via advance - just nudge slightly ahead of leader
    if (distToLeader < this.AdvanceFollowRadius)
    {
        // Move to a position slightly ahead of leader
        local facing = leader.EyeAngles().Forward()
        facing.z = 0
        local fwdLen = facing.Length()
        if (fwdLen > 0.01)
        {
            facing.x /= fwdLen
            facing.y /= fwdLen
        }
        else
        {
            facing = Vector(1, 0, 0)
        }
        
        return leaderPos + facing * this.AdvanceFollowOffset
    }
    
    // Too far from leader — regroup toward them
    return leaderPos
}

// ------------------------------------------------------------------
// GET NAV AHEAD — Find a nav area further along the map
// Uses NavMesh.GetNearestNavArea with forward-offset positions
// (Safe: GetNearestNavArea is a confirmed native)
// ------------------------------------------------------------------

function SurvivorAI::GetNavAhead(bot)
{
    local botPos = bot.GetOrigin()
    
    // 🐛 FIX: Check if bot is inside a checkpoint area (saferoom).
    // If so, we must NOT advance toward another checkpoint area (the saferoom
    // itself) — that's the "bots leave the saferoom then try to re-enter" bug.
    local currentNav = NavMesh.GetNearestNavArea(botPos, 100, false, true)
    if (!currentNav) return null
    local isInSaferoom = (currentNav.HasAttributes(NAV_MESH_CHECKPOINT))
    
    // 🐛 FIX: In saferoom and all probes hit checkpoint areas —
    // find the EXIT (nearest non-checkpoint area) instead of using
    // gaze direction, which points INTO the saferoom when leaving.
    if (isInSaferoom)
    {
        local exitNav = this.FindExitNavArea(botPos)
        if (exitNav)
        {
            this.LogDebug("ADVANCE", "Bot " + bot.GetPlayerUserId() + " exiting saferoom via nav exit")
            return exitNav
        }
        return null
    }
    
    // ============================================================
    // FLOW GRADIENT ASCENT (Fase 2 — 2026-08-09)
    // Avanzar hacia el área con MAYOR FLOW alcanzable (distancia real
    // por navmesh desde el inicio del mapa). No depende de la mirada.
    // Safety gate: verificar camino de VUELTA antes de avanzar
    // (fail-closed — nunca avanzar a zona sin retorno).
    // ============================================================
    local botFlow = this.GetAreaFlow(currentNav)
    if (botFlow <= 0)
    {
        // Sin flow info aún (start area no cacheada) — no avanzar
        this.LogDebug("ADVANCE", "Bot " + bot.GetPlayerUserId() + " no flow info — holding")
        return null
    }
    
    // Buscar el área con mayor flow en radio de búsqueda
    // (>= con tie-break por distancia: en mesetas de flow igual, avanzar
    // hacia la más lejana — evita bots parados en zonas planas)
    local areas = {}
    NavMesh.GetNavAreasInRadius(botPos, this.AdvanceNavSearchRadius, areas)
    local best = null
    local bestFlow = botFlow
    local bestDist = 0
    
    foreach (area in areas)
    {
        if (!area) continue
        if (area == currentNav) continue
        // Nunca avanzar hacia checkpoint areas (saferooms) ni áreas dañinas
        if (area.HasAttributes(NAV_MESH_CHECKPOINT)) continue
        if (area.IsDamaging()) continue
        
        local areaFlow = this.GetAreaFlow(area)
        if (areaFlow > bestFlow || (areaFlow == bestFlow && best))
        {
            local center = area.GetCenter()
            local d = (center - botPos).Length()
            if (areaFlow > bestFlow || d > bestDist)
            {
                bestFlow = areaFlow
                best = area
                bestDist = d
            }
        }
    }
    
    // SAFETY GATE: solo para el mejor candidato (fail-closed, coste 1 A*)
    if (best)
    {
        local returnDist = NavMesh.NavAreaTravelDistance(best, currentNav, this.FlowMaxDistance)
        if (returnDist < 0)
        {
            this.LogDebug("ADVANCE", "Bot " + bot.GetPlayerUserId() + " best area sin retorno — holding")
            best = null
        }
    }
    
    if (best)
    {
        local center = best.GetCenter()
        local distFromBot = (center - botPos).Length()
        if (distFromBot > this.AdvanceMinStep)
        {
            this.LogDebug("ADVANCE", "Bot " + bot.GetPlayerUserId() + " flow gradient +" + format("%.0f", bestFlow - botFlow) + "u")
            return center
        }
    }
    
    // 🐛 FIX (2026-08-09): Fallback por dirección de FLOW.
    // Si el gradiente local no encontró nada (meseta), buscar el área con
    // mayor flow en un radio grande (2000u) — la dirección general del mapa.
    if (!isInSaferoom)
    {
        local areas2 = {}
        NavMesh.GetNavAreasInRadius(botPos, this.AdvanceFallbackDist, areas2)
        local farthest = null
        local farthestFlow = botFlow
        local farthestDist = 0
        foreach (area in areas2)
        {
            if (!area) continue
            // Nunca avanzar hacia checkpoint areas (saferooms) ni áreas dañinas
            if (area.HasAttributes(NAV_MESH_CHECKPOINT)) continue
            if (area.IsDamaging()) continue
            
            local areaFlow = this.GetAreaFlow(area)
            if (areaFlow > farthestFlow || (areaFlow == farthestFlow && farthest))
            {
                local center = area.GetCenter()
                local d = (center - botPos).Length()
                if (areaFlow > farthestFlow || d > farthestDist)
                {
                    farthestFlow = areaFlow
                    farthest = area
                    farthestDist = d
                }
            }
        }
        
        // Safety gate también para el fallback
        if (farthest)
        {
            local returnDist = NavMesh.NavAreaTravelDistance(farthest, currentNav, this.FlowMaxDistance)
            if (returnDist < 0)
            {
                this.LogDebug("ADVANCE", "Bot " + bot.GetPlayerUserId() + " fallback sin retorno — holding")
                farthest = null
            }
        }
        
        if (farthest)
        {
            this.LogDebug("ADVANCE", "Bot " + bot.GetPlayerUserId() + " flow fallback +" + format("%.0f", farthestFlow - botFlow) + "u")
            return farthest.GetCenter()
        }
    }
    
    // 🐛 FIX: Fallback was "move toward gaze direction" — but if the bot
    // just left the saferoom, its gaze points INTO the saferoom, sending
    // it back ("leave then re-enter" bug). Return null instead: no advance
    // is safer than advancing into the saferoom. The bot will retry next tick.
    this.LogDebug("ADVANCE", "Bot " + bot.GetPlayerUserId() + " no valid nav ahead — holding position")
    return null
}

// ------------------------------------------------------------------
// FIND EXIT NAV AREA — nearest non-checkpoint area (saferoom exit)
// Used when the bot is inside the saferoom and all forward probes
// hit checkpoint areas. Searches expanding radii for the exit.
// ------------------------------------------------------------------

function SurvivorAI::FindExitNavArea(botPos)
{
    local radii = [200, 400, 600, 800, 1000]
    
    foreach (radius in radii)
    {
        local areas = {}
        NavMesh.GetNavAreasInRadius(botPos, radius, areas)
        
        foreach (area in areas)
        {
            if (!area)
                continue
            // Skip checkpoint (saferoom) and damaging areas
            if (area.HasAttributes(NAV_MESH_CHECKPOINT))
                continue
            if (area.IsDamaging())
                continue
            
            return area.GetCenter()
        }
    }
    
    return null
}

// ------------------------------------------------------------------
// DETECT ADVANCE TASK
// Returns ADVANCE task if:
//   - All-bot mode (no human survivors)
//   - Bot is alive and not pinned
//   - No immediate survival threats
//   - Not in active combat
//   - Bot has been in quiet state for > AdvanceIdleDelay
// ------------------------------------------------------------------

function SurvivorAI::DetectAdvanceTask(bot)
{
    if (!bot || !bot.IsValid())
        return null
    
    local userid = bot.GetPlayerUserId()
    local now = Time()
    
    // 1. Only in all-bot mode
    if (this.HasHumanPlayer())
        return null
    
    // 2. Only handle alive, unpinned bots
    if (NetProps.GetPropInt(bot, "m_lifeState") != 0)
        return null
    
    if (this.IsPinned(bot))
        return null
    
    // 3. Check for immediate threats via SurviveTask
    local surviveTask = this.DetectSurviveTask(bot)
    if (surviveTask && surviveTask.priority >= 95)
        return null
    
    // 4. Don't advance during active combat
    // Check if being attacked or commons are swarming
    if (this.HasNearbyThreats(bot, 300))
        return null
    
    // 5. Don't advance if currently being revived
    if (NetProps.GetPropInt(bot, "m_reviveOwner") > 0)
        return null
    
    // 6. Cooldown between advance commands
    local lastAdv = this.BotLastAdvanceTime[userid]
    if (lastAdv && (now - lastAdv) < this.AdvanceCommandInterval)
        return null
    
    // 7. Get target position
    local targetPos = this.GetAdvanceTarget(bot)
    if (!targetPos)
        return null
    
    // 8. Check if we already reached the target (avoid micro-corrections)
    local botPos = bot.GetOrigin()
    local posDiff = (targetPos - botPos).Length()
    if (posDiff < this.AdvanceMinStep)
        return null
    
    return {
        type = "ADVANCE",
        priority = 30,
        targetPos = targetPos,
        distance = posDiff
    }
}

// ------------------------------------------------------------------
// EXECUTE ADVANCE — Command the bot to move forward
// ------------------------------------------------------------------

function SurvivorAI::ExecuteAdvance(bot, task)
{
    if (!bot || !bot.IsValid() || !task)
        return
    
    local targetPos = task.targetPos
    if (!targetPos)
        return
    
    local userid = bot.GetPlayerUserId()
    
    // Validate position is on navmesh before commanding
    local safePos = this.GetSafePosition(targetPos, this.AdvanceNavSearchRadius)
    if (!safePos)
    {
        // Fallback: just move forward using vanilla pathfinding
        CommandABot({cmd = 3, bot = bot})
        this.BotLastCommandTime[userid] <- Time()
        this.LogDebug("ADVANCE", "Bot " + userid + " vanilla fallback (no safe nav)")
        return
    }
    
    // Command bot to move to position
    CommandABot({cmd = 1, bot = bot, pos = safePos})
    this.BotLastCommandTime[userid] <- Time()
    this.BotLastAdvanceTime[userid] <- Time()
    
    // If this bot is the leader, also tell followers via regroup
    // (followers naturally detect separation via REGROUP task)
    
    this.LogDebug("ADVANCE", "Bot " + userid + " advancing " + format("%.0f", task.distance) + "u")
}

printl("[BRAIN] advance.nut loaded")
