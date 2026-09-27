// survivor_ai/utility.nut - Utility AI: consideraciones + arbiter
// Fase 1 (2026-08-09): cada consideracion envuelve un detector existente
// y devuelve { score, task }. El arbiter elige la de mayor score (empates →
// orden de registro). Los ScoreTier* replican la precedencia de la cascada
// original → regresion cero garantizada.
//
// Escalable (Fase 2+): anadir comportamiento = anadir 1 consideracion con
// su score function. No tocar el pipeline.

// ------------------------------------------------------------------
// CONSIDERATION REGISTRY
// ------------------------------------------------------------------

::SurvivorAI.Considerations <- []  // array de { name, fn, maxScore }

function SurvivorAI::RegisterConsideration(name, fn, maxScore)
{
    // Evitar duplicados (idempotente — safe para recargas)
    foreach (c in this.Considerations)
    {
        if (c.name == name)
        {
            this.LogDebug("UTILITY", "Consideration '" + name + "' ya registrada — skip")
            return
        }
    }
    this.Considerations.append({ name = name, fn = fn, maxScore = maxScore })
}

// ------------------------------------------------------------------
// EVALUATE — evalua las consideraciones, devuelve la ganadora
// Early-exit (Fase 2): si el mejor score ya supera el maxScore de la
// consideración actual (y de todas las siguientes — orden descendente),
// ninguna puede ganar → parar. Con tiers estáticos es idéntico a la
// cascada; con scores dinámicos (ADVANCE) sigue siendo correcto porque
// el early-exit compara contra el MÁXIMO posible, no contra el score.
// ------------------------------------------------------------------

function SurvivorAI::EvaluateConsiderations(bot)
{
    local bestTask = null
    local bestScore = 0
    
    foreach (c in this.Considerations)
    {
        // Early-exit: ni esta ni las siguientes (maxScore <= c.maxScore) pueden ganar
        if (bestScore >= c.maxScore) break
        
        local result = c.fn(bot)
        if (!result) continue
        if (result.score > bestScore)
        {
            bestScore = result.score
            bestTask = result.task
        }
    }
    
    if (bestTask)
        this.LogDebug("UTILITY", "Bot " + bot.GetPlayerUserId() + " → " + bestTask.type + " (score=" + bestScore + ")")
    
    return bestTask
}

// ------------------------------------------------------------------
// ARBITER — wrapper publico del pipeline
// ------------------------------------------------------------------

function SurvivorAI::Arbiter(bot)
{
    return this.EvaluateConsiderations(bot)
}

// ------------------------------------------------------------------
// CONSIDERATION WRAPPERS — envuelven detectores existentes
// Los wrappers usan ::SurvivorAI.X() en runtime (lazy) — el orden de
// carga de modulos no importa.
// ------------------------------------------------------------------

function SurvivorAI::Consideration_FallWarp(bot)
{
    local task = this.DetectFallRisk(bot)
    if (!task) return null
    return { score = this.ScoreTierFallWarp, task = task }
}

function SurvivorAI::Consideration_Tongue(bot)
{
    local task = this.DetectTongueVictim(bot)
    if (!task) return null
    return { score = this.ScoreTierTongue, task = task }
}

function SurvivorAI::Consideration_Survive(bot)
{
    local task = this.DetectSurviveTask(bot)
    if (!task) return null
    return { score = this.ScoreTierSurvive, task = task }
}

function SurvivorAI::Consideration_Dodge(bot)
{
    local task = this.DetectDodgeTask(bot)
    if (!task) return null
    return { score = this.ScoreTierDodge, task = task }
}

function SurvivorAI::Consideration_IncapBlock(bot)
{
    local task = this.DetectIncapBlockTask(bot)
    if (!task) return null
    return { score = this.ScoreTierIncapBlock, task = task }
}

function SurvivorAI::Consideration_Rescue(bot)
{
    local task = this.DetectRescueTask(bot)
    if (!task) return null
    return { score = this.ScoreTierRescue, task = task }
}

function SurvivorAI::Consideration_Witch(bot)
{
    local task = this.DetectWitchTask(bot)
    if (!task) return null
    return { score = this.ScoreTierWitch, task = task }
}

function SurvivorAI::Consideration_RockShoot(bot)
{
    local task = this.DetectRockShootTask(bot)
    if (!task) return null
    return { score = this.ScoreTierRockShoot, task = task }
}

function SurvivorAI::Consideration_Combat(bot)
{
    local task = this.DetectCombatTask(bot)
    if (!task) return null
    return { score = this.ScoreTierCombat, task = task }
}

function SurvivorAI::Consideration_Nade(bot)
{
    local task = this.DetectNadeOpportunity(bot)
    if (!task) return null
    return { score = this.ScoreTierNade, task = task }
}

function SurvivorAI::Consideration_Position(bot)
{
    local task = this.DetectPositionTask(bot)
    if (!task) return null
    return { score = this.ScoreTierPosition, task = task }
}

function SurvivorAI::Consideration_Advance(bot)
{
    local task = this.DetectAdvanceTask(bot)
    if (!task) return null
    
    // Score dinámico (Fase 2): sube en SAFE, baja en COMBAT/EMERGENCY.
    // COMBAT (600) gana sobre cualquier score de ADVANCE — el avance solo
    // compite cuando no hay amenazas activas. Prepara Fase 3+ donde los
    // scores de combate también serán dinámicos.
    local score = this.ScoreTierAdvance
    local phase = this.Blackboard.TeamPhase
    if (phase == this.TeamPhaseCombat || phase == this.TeamPhaseEmergency)
        score = 150
    else if (phase == this.TeamPhaseAlert)
        score = 250
    
    return { score = score, task = task }
}

function SurvivorAI::Consideration_Item(bot)
{
    local task = this.DetectItemTask(bot)
    if (!task) return null
    return { score = this.ScoreTierItem, task = task }
}

function SurvivorAI::Consideration_CloseDoor(bot)
{
    local task = this.DetectCloseDoor(bot)
    if (!task) return null
    return { score = this.ScoreTierCloseDoor, task = task }
}

// ------------------------------------------------------------------
// REGISTER ALL — orden = precedencia de la cascada original
// ------------------------------------------------------------------

function SurvivorAI::RegisterAllConsiderations()
{
    this.RegisterConsideration("FALL_WARP", function(bot) {
        return ::SurvivorAI.Consideration_FallWarp(bot)
    }, this.ScoreTierFallWarp)
    this.RegisterConsideration("TONGUE", function(bot) {
        return ::SurvivorAI.Consideration_Tongue(bot)
    }, this.ScoreTierTongue)
    this.RegisterConsideration("SURVIVE", function(bot) {
        return ::SurvivorAI.Consideration_Survive(bot)
    }, this.ScoreTierSurvive)
    this.RegisterConsideration("DODGE", function(bot) {
        return ::SurvivorAI.Consideration_Dodge(bot)
    }, this.ScoreTierDodge)
    this.RegisterConsideration("INCAP_BLOCK", function(bot) {
        return ::SurvivorAI.Consideration_IncapBlock(bot)
    }, this.ScoreTierIncapBlock)
    this.RegisterConsideration("RESCUE", function(bot) {
        return ::SurvivorAI.Consideration_Rescue(bot)
    }, this.ScoreTierRescue)
    this.RegisterConsideration("WITCH", function(bot) {
        return ::SurvivorAI.Consideration_Witch(bot)
    }, this.ScoreTierWitch)
    this.RegisterConsideration("ROCK_SHOOT", function(bot) {
        return ::SurvivorAI.Consideration_RockShoot(bot)
    }, this.ScoreTierRockShoot)
    this.RegisterConsideration("COMBAT", function(bot) {
        return ::SurvivorAI.Consideration_Combat(bot)
    }, this.ScoreTierCombat)
    this.RegisterConsideration("NADE", function(bot) {
        return ::SurvivorAI.Consideration_Nade(bot)
    }, this.ScoreTierNade)
    this.RegisterConsideration("POSITION", function(bot) {
        return ::SurvivorAI.Consideration_Position(bot)
    }, this.ScoreTierPosition)
    this.RegisterConsideration("ADVANCE", function(bot) {
        return ::SurvivorAI.Consideration_Advance(bot)
    }, this.ScoreTierAdvance)
    this.RegisterConsideration("ITEM", function(bot) {
        return ::SurvivorAI.Consideration_Item(bot)
    }, this.ScoreTierItem)
    this.RegisterConsideration("CLOSE_DOOR", function(bot) {
        return ::SurvivorAI.Consideration_CloseDoor(bot)
    }, this.ScoreTierCloseDoor)
}

::SurvivorAI.RegisterAllConsiderations()

printl("[BRAIN] utility.nut loaded - " + ::SurvivorAI.Considerations.len() + " considerations registered")
