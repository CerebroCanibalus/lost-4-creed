// survivor_ai/core.nut - Main think loop for Minimal Intervention AI
// Orchestrates detector -> validator -> executor pipeline

// ------------------------------------------------------------------
// PER-BOT THINK FUNCTION
// Each bot gets its own MaoLib timer for better performance distribution
// ------------------------------------------------------------------

function SurvivorAI::BotThink(bot)
{
    if (!bot || !bot.IsValid())
        return -1
    
    // Only process bots
    if (!IsPlayerABot(bot))
        return -1
    
    // Skip dead bots
    if (NetProps.GetPropInt(bot, "m_lifeState") != 0)
        return -1
    
    // Skip bots being controlled by humans
    if (NetProps.GetPropInt(bot, "m_humanSpectatorUserID") != 0)
        return -1
    
    local userid = bot.GetPlayerUserId()
    
    // 0. CLEANUP: Clear forced buttons from previous frame
    local cleanButtons = NetProps.GetPropInt(bot, "m_afButtonForced")
    cleanButtons = cleanButtons & ~(IN_ATTACK | IN_ATTACK2)
    NetProps.SetPropInt(bot, "m_afButtonForced", cleanButtons)
    
    // 0. VISION SCAN: Update threat awareness
    if (this.ShouldVisionScan(bot))
    {
        this.VisionScan(bot)
    }
    
    // 0.5 DEADSTOP CHECK
    local airborneSI = this.GetAirborneHunterOrJockey(bot)
    if (airborneSI)
    {
        local dist = (bot.GetOrigin() - airborneSI.GetOrigin()).Length()
        if (dist < this.DeadstopRange)
        {
            this.ExecuteDeadstop(bot, airborneSI)
            return this.BotThinkInterval
        }
    }
    
    // 0.7 HEAL INTERRUPT CHECK
    local health = bot.GetHealth()
    if (health >= this.HealInterruptThreshold)
    {
        local usingMed = NetProps.GetPropInt(bot, "m_usingMedKit")
        local usingDefib = NetProps.GetPropInt(bot, "m_usingDefibrillator")
        if (usingMed || usingDefib)
        {
            local task = {
                type = "INTERRUPT_HEAL",
                priority = 95,
                health = health
            }
            this.ExecuteTask(bot, task)
            return this.BotThinkInterval
        }
    }
    
    // 1. DETECT: Does vanilla AI need help?
    local task = this.DetectTask(bot)
    
    // No task = vanilla AI is handling it fine
    if (!task)
    {
        // 1.2 ITEM CHECK (pickup/give throwables — no intrusivo)
        local itemTask = this.DetectItemTask(bot)
        if (itemTask)
        {
            this.ExecuteTask(bot, itemTask)
            return this.BotThinkInterval
        }
        
        // 1.5 CLOSE DOOR CHECK (only if no combat tasks)
        local doorTask = this.DetectCloseDoor(bot)
        if (doorTask)
        {
            this.ExecuteTask(bot, doorTask)
            return this.BotThinkInterval
        }
        
        return this.BotThinkInterval
    }
    
    // 2. EXECUTE: Minimal intervention
    this.ExecuteTask(bot, task)
    
    return this.BotThinkInterval
}

// ------------------------------------------------------------------
// PER-BOT THINK SETUP
// ------------------------------------------------------------------

function SurvivorAI::StartPerBotThink()
{
    printl("[SurvivorAI] Starting per-bot think...")
    
    foreach (player in MaoLib.YieldSurvivors())
    {
        if (!player || !player.IsValid())
            continue
        if (!IsPlayerABot(player))
            continue
        
        this.AttachBotThink(player)
    }
}

function SurvivorAI::AttachBotThink(bot)
{
    if (!bot || !bot.IsValid())
        return
    
    local userid = bot.GetPlayerUserId()
    
    // Remove existing think if any
    if (userid in this.BotThinkTimers && this.BotThinkTimers[userid])
    {
        MaoLib.RemoveTimer(this.BotThinkTimers[userid])
    }
    
    // Create a per-bot timer via MaoLib
    local timerName = "sa_bot_" + userid
    MaoLib.AddTimer(timerName, this.BotThinkInterval, function() {
        ::SurvivorAI.BotThink(bot)
    })
    
    this.BotThinkTimers[userid] <- timerName
}

function SurvivorAI::DetachAllBotThink()
{
    foreach (userid, timerName in this.BotThinkTimers)
    {
        MaoLib.RemoveTimer(timerName)
    }
    this.BotThinkTimers = {}
}

// ------------------------------------------------------------------
// DETECT TASKS
// ------------------------------------------------------------------

function SurvivorAI::DetectCloseDoor(bot)
{
    if (!bot || !bot.IsValid())
        return null
    
    local botPos = bot.GetOrigin()
    
    // Check if there's a checkpoint door nearby that's open
    local door = Entities.FindByClassnameNearest("prop_door_rotating_checkpoint", botPos, this.DoorCloseRadius)
    if (!door || !door.IsValid())
        return null
    
    local doorPos = door.GetOrigin()
    
    return {
        type = "CLOSE_DOOR",
        priority = 35,
        doorPos = doorPos,
        door = door
    }
}

// ------------------------------------------------------------------
// THINK SETUP (replaces global info_target + AddThinkToEnt)
// ------------------------------------------------------------------

function SurvivorAI::StartSurvivorAI()
{
    printl("[SurvivorAI] Starting Minimal Intervention AI system (per-bot think)...")
    this.StartPerBotThink()
}

// ------------------------------------------------------------------
// CLEANUP ON ROUND END
// ------------------------------------------------------------------

function SurvivorAI::Cleanup()
{
    printl("[SurvivorAI] Cleaning up state...")
    
    // Clear all runtime state
    this.BotLastCommandTime = {}
    this.BotLastShoveTime = {}
    this.BotPositions = {}
    this.BotStuckState = {}
    this.PinStartTime = {}
    this.BotVision = {}
    this.ThinkCount = 0
    
    // Clear event-driven dodge state
    this.SpitBursts = {}
    this.ChargerCharges = {}
    this.DeathAcidPositions = {}
    this.TongueTargets = {}
    this.LastHordeNadeTime = {}
    this.ItemPickupTimers = {}
    
    // Clear entity cache
    this.CachedSpecials = {}
    this.CachedTanks = {}
    this.CachedSurvivors = {}
}

// ------------------------------------------------------------------
// EVENT HANDLERS (TABLA REGISTRADA - NO GLOBALES)
// ------------------------------------------------------------------

::SurvivorAI.Events <- {
    function OnGameEvent_round_start(params)
    {
        ::SurvivorAI.Cleanup()
        
        // Restart think loop
        ::SurvivorAI.StartSurvivorAI()
    }
    
    function OnGameEvent_round_end(params)
    {
        ::SurvivorAI.DetachAllBotThink()
        ::SurvivorAI.Cleanup()
    }
    
    function OnGameEvent_mission_lost(params)
    {
        ::SurvivorAI.DetachAllBotThink()
        ::SurvivorAI.Cleanup()
    }
    
    function OnGameEvent_map_transition(params)
    {
        // Cleanup existing pipebombs to prevent pipebomb-between-maps bug
        local pipe = null
        while (pipe = Entities.FindByClassname(pipe, "weapon_pipebomb"))
        {
            if (pipe && pipe.IsValid())
                pipe.Kill()
        }
        
        ::SurvivorAI.DetachAllBotThink()
        ::SurvivorAI.Cleanup()
    }
    
    // ------------------------------------------------------------------
    // ENTITY CACHE: Actualizar cuando entidades aparecen/desaparecen
    // ------------------------------------------------------------------
    
    function OnGameEvent_player_spawn(params)
    {
        local player = GetPlayerFromUserID(params.userid)
        if (!player || !player.IsValid())
            return
        
        // Survivor?
        if (player.GetZombieType() == 9)
        {
            ::SurvivorAI.CachedSurvivors[params.userid] <- player
            return
        }
        
        // Special infected?
        local zClass = NetProps.GetPropInt(player, "m_zombieClass")
        if (zClass == ZOMBIE_CLASS_TANK)
        {
            ::SurvivorAI.CachedTanks[params.userid] <- player
        }
        else if (zClass >= ZOMBIE_CLASS_SMOKER && zClass <= ZOMBIE_CLASS_CHARGER)
        {
            ::SurvivorAI.CachedSpecials[params.userid] <- player
        }
    }
    
    function OnGameEvent_player_death(params)
    {
        // Guard: edge cases (map transition, entity destroyed) may omit userid
        if (!("userid" in params))
            return
        
        // Remove from all caches by userid
        local uid = params.userid
        if (uid in ::SurvivorAI.CachedSpecials)
            delete ::SurvivorAI.CachedSpecials[uid]
        if (uid in ::SurvivorAI.CachedTanks)
            delete ::SurvivorAI.CachedTanks[uid]
        if (uid in ::SurvivorAI.CachedSurvivors)
            delete ::SurvivorAI.CachedSurvivors[uid]
    }
    
    // ------------------------------------------------------------------
    // EVENT-DRIVEN DODGE: React to threats BEFORE they hit
    // ------------------------------------------------------------------
    
    function OnGameEvent_spit_burst(params)
    {
        // Spitter spit landed - record position for dodge detection
        local pos = Vector(params.x, params.y, params.z)
        local entityid = params.entid
        
        ::SurvivorAI.SpitBursts[entityid] <- {
            pos = pos,
            time = Time()
        }
        
        // Auto-expire after 8 seconds (spit duration) — DelayCall one-shot
        MaoLib.DelayCall(function() {
            if (entityid in ::SurvivorAI.SpitBursts)
                delete ::SurvivorAI.SpitBursts[entityid]
        }, 8.0)
    }
    
    function OnGameEvent_charger_charge_start(params)
    {
        // Charger started charging - record for dodge
        local charger = GetPlayerFromUserID(params.userid)
        if (!charger || !charger.IsValid())
            return
        
        local pos = charger.GetOrigin()
        
        ::SurvivorAI.ChargerCharges[params.userid] <- {
            startPos = pos,
            startTime = Time()
        }
        
        // Auto-expire after 3 seconds (charge duration max) — DelayCall one-shot
        local chargeUid = params.userid  // capture local para closure
        MaoLib.DelayCall(function() {
            if (chargeUid in ::SurvivorAI.ChargerCharges)
                delete ::SurvivorAI.ChargerCharges[chargeUid]
        }, 3.0)
    }
    
    function OnGameEvent_charger_killed(params)
    {
        // Charger killed - remove from tracking
        if (params.userid in ::SurvivorAI.ChargerCharges)
            delete ::SurvivorAI.ChargerCharges[params.userid]
    }
    
    function OnGameEvent_spitter_killed(params)
    {
        // Spitter killed - record death position for acid avoidance
        local spitter = GetPlayerFromUserID(params.userid)
        if (!spitter || !spitter.IsValid())
            return
        
        local deathPos = spitter.GetOrigin()
        
        ::SurvivorAI.DeathAcidPositions[params.userid] <- {
            pos = deathPos,
            time = Time()
        }
        
        // Auto-expire after 5 seconds (death acid duration) — DelayCall one-shot
        local acidUid = params.userid  // capture local para closure
        MaoLib.DelayCall(function() {
            if (acidUid in ::SurvivorAI.DeathAcidPositions)
                delete ::SurvivorAI.DeathAcidPositions[acidUid]
        }, 5.0)
    }
    
    function OnGameEvent_player_entered_checkpoint(params)
    {
        // Bot entered saferoom checkpoint - mark for door close on next think
        // The BotThink() loop handles actual door detection via DetectCloseDoor()
        // This event just ensures the bot will scan for doors on its next tick
        // (No additional action needed - DetectCloseDoor runs passively every tick)
    }
    
    function OnGameEvent_tongue_grab(params)
    {
        // Smoker grabbed a survivor - track for rescue
        local victim = GetPlayerFromUserID(params.victim)
        local attacker = GetPlayerFromUserID(params.userid)
        
        if (victim && victim.IsValid() && attacker && attacker.IsValid())
        {
            ::SurvivorAI.TongueTargets[params.victim] <- attacker
        }
    }
    
    function OnGameEvent_tongue_release(params)
    {
        // Tongue released - clear tracking
        if (params.victim in ::SurvivorAI.TongueTargets)
            delete ::SurvivorAI.TongueTargets[params.victim]
    }
    
    function OnGameEvent_player_incapacitated(params)
    {
        // Player incapacitated - could be relevant for heal interrupt
    }
    
}

// Registrar event handlers con tabla dedicada (NO getroottable())
__CollectGameEventCallbacks(::SurvivorAI.Events)

// ------------------------------------------------------------------
// AUTO-START
// ------------------------------------------------------------------
::SurvivorAI.StartSurvivorAI()

printl("[SurvivorAI] core.nut loaded - Minimal Intervention AI active")
