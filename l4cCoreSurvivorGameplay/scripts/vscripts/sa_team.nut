// survivor_ai/team.nut - TeamState, FlowState, Leader dinamico, Blackboard
// Fase 1 (2026-08-09): infraestructura de Utility AI.
//   - Blackboard: estado compartido del equipo (TeamPhase, Leader, Threats)
//   - TeamPhase: SAFE/ALERT/COMBAT/EMERGENCY
//   - FlowState: GetBotFlow/GetTeamFlow (basico — Fase 2 usara NavAreaTravelDistance)
//   - GetDynamicLeader: lider por flow (Fase 1 = fallback a GetLeader actual)
// El BotThink NO depende criticamente de esto aun (regresion cero).
// Fase 2+: TeamPhase y FlowState alimentan los scores dinamicos.

// ------------------------------------------------------------------
// BLACKBOARD — estado compartido del equipo
// ------------------------------------------------------------------

::SurvivorAI.Blackboard <- {
    TeamPhase = "SAFE",        // SAFE/ALERT/COMBAT/EMERGENCY
    Leader = null,             // entity del lider dinamico
    AdvanceTarget = null,      // Vector — waypoint principal (Fase 2)
    Threats = [],              // array de entidades amenazantes (SI + tank)
    PointsOfInterest = [],     // array de { pos, checked } (Fase 4)
    LastUpdate = 0             // timestamp del ultimo update
}

// ------------------------------------------------------------------
// TEAM PHASE — fase actual del equipo
// ------------------------------------------------------------------

function SurvivorAI::GetTeamPhase()
{
    // EMERGENCY: alguien incap o pinned
    // (2026-08-10) YieldActiveSurvivors: un espectador no es un survivor
    // jugando — no debe disparar fases ni contar para amenazas.
    foreach (player in MaoLib.YieldActiveSurvivors())
    {
        if (!player || !player.IsValid()) continue
        local lifeState = NetProps.GetPropInt(player, "m_lifeState")
        if (lifeState == 1) return this.TeamPhaseEmergency
        if (lifeState == 0 && this.IsPinned(player)) return this.TeamPhaseEmergency
    }
    
    // COMBAT: tank presente
    local tank = this.FindTank()
    if (tank && tank.IsValid()) return this.TeamPhaseCombat
    
    // COMBAT: SI visible cerca de cualquier survivor
    foreach (uid, si in this.CachedSpecials)
    {
        if (!si || !si.IsValid()) continue
        foreach (player in MaoLib.YieldActiveSurvivors())
        {
            if (!player || !player.IsValid()) continue
            if ((player.GetOrigin() - si.GetOrigin()).Length() < this.SIAttackRange)
                return this.TeamPhaseCombat
        }
    }
    
    // ALERT: witch calmada CERCA de algún survivor (no en todo el mapa)
    // (2026-08-10) Usa GetCachedWitches() — mismo cache que DetectWitchTask
    foreach (witch in this.GetCachedWitches())
    {
        if (!witch || !witch.IsValid()) continue
        if (MaoLib.GetWitchAnger(witch) >= 0.1) continue
        
        foreach (player in MaoLib.YieldActiveSurvivors())
        {
            if (!player || !player.IsValid()) continue
            if ((player.GetOrigin() - witch.GetOrigin()).Length() < this.WitchAlertRange)
                return this.TeamPhaseAlert
        }
    }
    
    return this.TeamPhaseSafe
}

// ------------------------------------------------------------------
// FLOW STATE — flow del bot y del equipo
// Fase 2: flow real = NavAreaTravelDistance desde el área inicial del
// mapa (cacheada en round_start_post_nav). Cache por ID de área.
// ------------------------------------------------------------------

function SurvivorAI::GetAreaFlow(area)
{
    if (!area) return 0.0
    
    local areaId = area.GetID()
    if (areaId in this.FlowCache)
        return this.FlowCache[areaId]
    
    // Sin área inicial cacheada → sin flow info aún
    if (!this.MapStartArea)
        return 0.0
    
    // NavAreaTravelDistance: distancia REAL por navmesh, -1 si no hay camino
    local dist = NavMesh.NavAreaTravelDistance(this.MapStartArea, area, this.FlowMaxDistance)
    if (dist < 0) dist = 0.0  // sin camino → flow 0 (nunca avanzar hacia ahí)
    
    this.FlowCache[areaId] <- dist
    return dist
}

function SurvivorAI::GetBotFlow(bot)
{
    if (!bot || !bot.IsValid()) return 0.0
    
    // GetLastKnownArea: área nav actual del bot (confirmado en archived_core_addon)
    local area = null
    if ("GetLastKnownArea" in bot)
        area = bot.GetLastKnownArea()
    if (!area)
        area = NavMesh.GetNearestNavArea(bot.GetOrigin(), 100, false, true)
    if (!area) return 0.0
    
    return this.GetAreaFlow(area)
}

function SurvivorAI::GetTeamFlow()
{
    local sum = 0.0
    local count = 0
    // (2026-08-10) Active: el espectador no debe sesgar el promedio de flow
    foreach (player in MaoLib.YieldActiveSurvivors())
    {
        if (!player || !player.IsValid()) continue
        if (NetProps.GetPropInt(player, "m_lifeState") != 0) continue
        sum += this.GetBotFlow(player)
        count++
    }
    if (count > 0) return sum / count
    return 0.0
}

// ------------------------------------------------------------------
// CACHE MAP START AREA — área inicial del mapa (para flow)
// Se llama en round_start_post_nav (los survivors ya están spawnados).
// ------------------------------------------------------------------

function SurvivorAI::CacheMapStartArea()
{
    // (2026-08-10) Active: el área inicial debe ser la de un survivor
    // REAL (bot/humano jugando). Un espectador no tiene posición válida
    // en el mapa — su GetLastKnownArea/GetNearestNavArea cachearía un
    // área fantasma y el flow entero se basaría en ella.
    foreach (player in MaoLib.YieldActiveSurvivors())
    {
        if (!player || !player.IsValid()) continue
        
        local area = null
        if ("GetLastKnownArea" in player)
            area = player.GetLastKnownArea()
        if (!area)
            area = NavMesh.GetNearestNavArea(player.GetOrigin(), 100, false, true)
        
        if (area)
        {
            this.MapStartArea = area
            this.LogDebug("FLOW", "Map start area cached (id=" + area.GetID() + ")")
            return
        }
    }
}

// ------------------------------------------------------------------
// DYNAMIC LEADER — líder por flow
// Fase 2: el bot con mayor flow lidera. Histéresis: mantener el líder
// actual si su flow no pierde más de LeaderFlowHysteresis (anti-flapping).
// Si muere, otro toma el rol. Fallback: líder designado (Zoey > Nick)
// si aún no hay flow info (MapStartArea null).
// ------------------------------------------------------------------

function SurvivorAI::GetDynamicLeader()
{
    // Fallback: sin flow info aún → líder designado (Zoey > Nick > any)
    if (!this.MapStartArea)
        return this.GetLeader()
    
    local best = null
    local bestFlow = -1.0
    // 🐛 FIX (2026-08-10): YieldActiveSurvivors() en vez de YieldSurvivors().
    // Un espectador (host en spectator) cuenta como survivor y su flow es el
    // del inicio del mapa → se convertía en LÍDER → los bots eran followers
    // → GetNavAhead() nunca se llamaba → 0 movimiento. El líder debe ser un
    // survivor ACTIVO (team 2), nunca un espectador.
    foreach (player in MaoLib.YieldActiveSurvivors())
    {
        if (!player || !player.IsValid()) continue
        if (NetProps.GetPropInt(player, "m_lifeState") != 0) continue
        local flow = this.GetBotFlow(player)
        if (flow > bestFlow)
        {
            bestFlow = flow
            best = player
        }
    }
    
    // Histéresis: mantener el líder actual si sigue vivo y su flow
    // no es significativamente menor que el máximo (evita flapping)
    local current = this.Blackboard.Leader
    if (current && current.IsValid() && current != best)
    {
        // 🐛 FIX (2026-08-10): NO mantener líderes MUERTOS ni ESPECTADORES.
        // Un handle IsValid() sigue siendo true para entidades muertas, y un
        // espectador tiene lifeState 0 (vivo) pero team 1 → si el host pasa a
        // spectator (jointeam 1) el juego spawnea un bot en su slot, pero la
        // histéresis mantenía al host-espectador como líder → los bots lo
        // seguían a él (posición basura) → 0 movimiento.
        if (MaoLib.IsActiveSurvivor(current))
        {
            local currentFlow = this.GetBotFlow(current)
            if (currentFlow >= bestFlow - this.LeaderFlowHysteresis)
                return current
        }
    }
    
    return best
}

// ------------------------------------------------------------------
// UPDATE BLACKBOARD — actualiza estado compartido (guard de tiempo)
// ------------------------------------------------------------------

function SurvivorAI::UpdateBlackboard()
{
    local now = Time()
    if (now - this.Blackboard.LastUpdate < this.TeamPhaseUpdateInterval)
        return
    
    this.Blackboard.LastUpdate = now
    this.Blackboard.TeamPhase = this.GetTeamPhase()
    this.Blackboard.Leader = this.GetDynamicLeader()
    
    // Threats: SI + tank del cache
    local threats = []
    foreach (uid, si in this.CachedSpecials)
    {
        if (si && si.IsValid()) threats.append(si)
    }
    foreach (uid, tank in this.CachedTanks)
    {
        if (tank && tank.IsValid()) threats.append(tank)
    }
    this.Blackboard.Threats = threats
}

printl("[BRAIN] team.nut loaded - TeamState/FlowState/Blackboard")
