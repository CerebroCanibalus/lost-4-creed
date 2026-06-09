// survivor_ai/executor.nut - Execute minimal interventions
// Philosophy: Intervene briefly, then let vanilla AI take over again

// ------------------------------------------------------------------
// MAIN EXECUTION FUNCTION
// ------------------------------------------------------------------

function SurvivorAI::ExecuteTask(bot, task)
{
    if (!bot || !bot.IsValid() || !task)
        return
    
    local now = Time()
    local userid = bot.GetPlayerUserId()
    
    // Check command cooldown (prevent spam)
    if (userid in this.BotLastCommandTime && (now - this.BotLastCommandTime[userid]) < this.CommandCooldown)
    {
        // Still within cooldown - only allow SURVIVE tasks to override
        if (task.priority < 95)
            return
    }
    
    // Execute based on task type
    switch (task.type)
    {
        case "SURVIVE":
            this.ExecuteSurvive(bot, task)
            break
        case "RESCUE":
            this.ExecuteRescue(bot, task)
            break
        case "SHOVE":
            this.ExecuteShove(bot, task)
            break
        case "ATTACK_SI":
            this.ExecuteAttackSI(bot, task)
            break
        case "ATTACK_CHARGER":
            this.ExecuteAttackCharger(bot, task)
            break
        case "KITE_TANK":
            this.ExecuteKiteTank(bot, task)
            break
        case "UNSTICK":
            this.ExecuteUnstick(bot, task)
            break
        case "REGROUP":
            this.ExecuteRegroup(bot, task)
            break
        case "SHOVE_TONGUE":
            this.ExecuteShoveTongue(bot, task)
            break
        case "SHOOT_TONGUE":
            this.ExecuteShootTongue(bot, task)
            break
        case "DODGE":
            this.ExecuteDodge(bot, task)
            break
        case "THROW_NADE":
            this.ExecuteThrowNade(bot, task)
            break
        case "FALL_WARP":
            this.ExecuteFallWarp(bot, task)
            break
        case "CLOSE_DOOR":
            this.ExecuteCloseDoor(bot, task)
            break
        case "INTERRUPT_HEAL":
            this.ExecuteInterruptHeal(bot, task)
            break
        case "ITEM_PICKUP":
            this.ExecutePickupItem(bot, task)
            break
        case "ITEM_GIVE":
            this.ExecuteGiveItem(bot, task)
            break
    }
}

// ------------------------------------------------------------------
// PRIORITY 1: SURVIVE - Execute evasion
// ------------------------------------------------------------------

function SurvivorAI::ExecuteSurvive(bot, task)
{
    local botPos = bot.GetOrigin()
    
    switch (task.subtype)
    {
        case "TANK_PUNCH":
        case "TANK_CLOSE":
        {
            local tank = task.threat
            if (!tank || !tank.IsValid())
                return
            
            // Move away from tank
            local away = botPos - tank.GetOrigin()
            away.z = 0
            local len = away.Length()
            if (len > 0)
            {
                away.x /= len
                away.y /= len
            }
            else
            {
                away = Vector(1, 0, 0)
            }
            
            // Add lateral movement for better evasion
            local strafe = Vector(-away.y, away.x, 0)
            if (RandomInt(0, 1))
                strafe = Vector(away.y, -away.x, 0)
            
            local escapePos = botPos + away * 250 + strafe * 100
            local safePos = this.GetSafePosition(escapePos, 300)
            
            if (safePos)
            {
                CommandABot({cmd = 1, bot = bot, pos = safePos})
                this.BotLastCommandTime[bot.GetPlayerUserId()] <- Time()
                this.LogDebug("SURVIVE", "Bot " + bot.GetPlayerUserId() + " evading tank")
            }
            break
        }
        
        case "TANK_ROCK":
        {
            local rock = task.threat
            if (!rock || !rock.IsValid())
                return
            
            // Dodge perpendicular to rock trajectory
            local rockVel = rock.GetVelocity()
            rockVel.Norm()
            
            local dodgeDir = Vector(-rockVel.y, rockVel.x, 0)
            dodgeDir.Norm()
            
            // Choose side away from rock centerline
            local rockPos = rock.GetOrigin()
            local toBot = botPos - rockPos
            toBot.Norm()
            
            if (RandomInt(0, 1))
                dodgeDir = Vector(rockVel.y, -rockVel.x, 0)
            
            local dodgePos = botPos + dodgeDir * 250
            local safePos = this.GetSafePosition(dodgePos, 200)
            
            if (safePos)
            {
                CommandABot({cmd = 1, bot = bot, pos = safePos})
                this.BotLastCommandTime[bot.GetPlayerUserId()] <- Time()
                this.LogDebug("SURVIVE", "Bot " + bot.GetPlayerUserId() + " dodging rock")
            }
            break
        }
        
        case "CHARGER_CHARGE":
        {
            local charger = task.threat
            if (!charger || !charger.IsValid())
                return
            
            // Dodge perpendicular to charge direction
            local chargerAng = charger.EyeAngles()
            local chargerForward = chargerAng.Forward()
            chargerForward.z = 0
            local fwdLen = chargerForward.Length()
            if (fwdLen > 0)
            {
                chargerForward.x /= fwdLen
                chargerForward.y /= fwdLen
            }
            
            local dodgeDir = Vector(-chargerForward.y, chargerForward.x, 0)
            if (RandomInt(0, 1))
                dodgeDir = Vector(chargerForward.y, -chargerForward.x, 0)
            
            local dodgePos = botPos + dodgeDir * 300
            local safePos = this.GetSafePosition(dodgePos, 300)
            
            if (safePos)
            {
                CommandABot({cmd = 1, bot = bot, pos = safePos})
                this.BotLastCommandTime[bot.GetPlayerUserId()] <- Time()
                this.LogDebug("SURVIVE", "Bot " + bot.GetPlayerUserId() + " dodging charger")
            }
            break
        }
        
        case "FIRE_ACID":
        {
            // Find direction away from fire/acid
            local botPos = bot.GetOrigin()
            local inferno = Entities.FindByClassnameWithin(null, "inferno", botPos, 100)
            if (inferno && inferno.IsValid())
            {
                local infernoPos = inferno.GetOrigin()
                local away = botPos - infernoPos
                away.z = 0
                away.Norm()
                
                // Try multiple angles to find safe spot
                local angles = [0, 45, -45, 90, -90, 135, -135, 180]
                foreach (angle in angles)
                {
                    local rad = angle * PI / 180.0
                    local dir = Vector(
                        away.x * cos(rad) - away.y * sin(rad),
                        away.x * sin(rad) + away.y * cos(rad),
                        0
                    )
                    
                    local checkPos = botPos + dir * 200
                    local safePos = this.GetSafePosition(checkPos, 200)
                    
                    if (safePos)
                    {
                        CommandABot({cmd = 1, bot = bot, pos = safePos})
                        this.BotLastCommandTime[bot.GetPlayerUserId()] <- Time()
                        this.LogDebug("SURVIVE", "Bot " + bot.GetPlayerUserId() + " escaping fire/acid")
                        return
                    }
                }
            }
            break
        }
    }
}

// ------------------------------------------------------------------
// PRIORITY 2: RESCUE - Execute rescue
// CRITICAL: Move towards ATTACKER, not victim
// ------------------------------------------------------------------

function SurvivorAI::ExecuteRescue(bot, task)
{
    local victim = task.victim
    local attacker = task.attacker
    
    if (!victim || !victim.IsValid())
        return
    
    local botPos = bot.GetOrigin()
    local userid = bot.GetPlayerUserId()
    
    if (attacker && attacker.IsValid())
    {
        // We know who the attacker is - move towards ATTACKER
        local attackerPos = attacker.GetOrigin()
        local distToAttacker = (botPos - attackerPos).Length()
        
        // Determine attacker type
        local zClass = NetProps.GetPropInt(attacker, "m_zombieClass")
        local isCharger = (zClass == 6)
        
        if (distToAttacker > 80)
        {
            // Move closer to attacker
            local safePos = this.GetSafePosition(attackerPos, 200)
            if (safePos)
            {
                CommandABot({cmd = 1, bot = bot, pos = safePos})
                this.BotLastCommandTime[userid] <- Time()
                this.LogDebug("RESCUE", "Bot " + userid + " moving to attacker (dist: " + format("%.0f", distToAttacker) + ")")
            }
        }
        else
        {
            // Close enough - attack the attacker
            // CRITICAL: Charger CANNOT be shoved to release victim (pro strategy: just kill it)
            if (!isCharger)
            {
                // Smoker/Hunter/Jockey: shove + attack
                NetProps.SetPropInt(bot, "m_afButtonForced",
                    NetProps.GetPropInt(bot, "m_afButtonForced") | IN_ATTACK2)
                this.LogDebug("RESCUE", "Bot " + userid + " shoving attacker")
            }
            else
            {
                // Charger: ONLY attack, NEVER shove (shove doesn't work on Charger)
                this.LogDebug("RESCUE", "Bot " + userid + " attacking Charger (shove ineffective)")
            }
            
            CommandABot({cmd = 0, bot = bot, target = attacker})
            this.BotLastCommandTime[userid] <- Time()
        }
    }
    else
    {
        // No visible attacker - move towards victim
        // (This shouldn't happen often, but handle it)
        local victimPos = victim.GetOrigin()
        local distToVictim = (botPos - victimPos).Length()
        
        if (distToVictim > 100)
        {
            local safePos = this.GetSafePosition(victimPos, 200)
            if (safePos)
            {
                CommandABot({cmd = 1, bot = bot, pos = safePos})
                this.BotLastCommandTime[userid] <- Time()
                this.LogDebug("RESCUE", "Bot " + userid + " moving to victim (no attacker visible)")
            }
        }
    }
}

// ------------------------------------------------------------------
// PRIORITY 3: SHOVE - Execute shove against commons
// ------------------------------------------------------------------

function SurvivorAI::ExecuteShove(bot, task)
{
    local userid = bot.GetPlayerUserId()
    local now = Time()
    
    // Force shove button
    NetProps.SetPropInt(bot, "m_afButtonForced",
        NetProps.GetPropInt(bot, "m_afButtonForced") | IN_ATTACK2)
    
    this.BotLastShoveTime[userid] <- now
    
    // Horde detection: if 10+ commons, log as horde defense
    if (task.isHorde)
    {
        this.LogDebug("SHOVE", "Bot " + userid + " shoving HORDE of " + task.count + " commons!")
    }
    else
    {
        this.LogDebug("SHOVE", "Bot " + userid + " shoving " + task.count + " commons")
    }
}

// ------------------------------------------------------------------
// PRIORITY 3: ATTACK_SI - Force attack on special infected
// ------------------------------------------------------------------

function SurvivorAI::ExecuteAttackSI(bot, task)
{
    local target = task.target
    if (!target || !target.IsValid())
        return
    
    local userid = bot.GetPlayerUserId()
    
    // Force bot to attack the SI
    CommandABot({cmd = 0, bot = bot, target = target})
    this.BotLastCommandTime[userid] <- Time()
    this.LogDebug("ATTACK", "Bot " + userid + " attacking SI at " + format("%.0f", task.distance) + "u")
}

// ------------------------------------------------------------------
// PRIORITY 3: KITE_TANK - Maintain distance from tank
// ------------------------------------------------------------------

function SurvivorAI::ExecuteKiteTank(bot, task)
{
    local tank = task.threat
    if (!tank || !tank.IsValid())
        return
    
    local botPos = bot.GetOrigin()
    local tankPos = tank.GetOrigin()
    local dist = (botPos - tankPos).Length()
    local userid = bot.GetPlayerUserId()
    
    // If too close, retreat
    if (dist < this.TankKiteRange * 0.7)
    {
        local away = botPos - tankPos
        away.z = 0
        away.Norm()
        
        local retreatPos = botPos + away * 300
        local safePos = this.GetSafePosition(retreatPos, 300)
        
        if (safePos)
        {
            CommandABot({cmd = 1, bot = bot, pos = safePos})
            this.BotLastCommandTime[userid] <- Time()
            this.LogDebug("KITE", "Bot " + userid + " retreating from tank (dist: " + format("%.0f", dist) + ")")
        }
    }
    // If at good distance, let vanilla AI handle shooting
}

// ------------------------------------------------------------------
// PRIORITY 4: UNSTICK - Break free from being stuck
// ------------------------------------------------------------------

function SurvivorAI::ExecuteUnstick(bot, task)
{
    local userid = bot.GetPlayerUserId()
    
    // Find valid unstick position
    local unstickPos = this.GetUnstickPosition(bot, null)
    
    if (unstickPos)
    {
        CommandABot({cmd = 1, bot = bot, pos = unstickPos})
        this.BotLastCommandTime[userid] <- Time()
        
        // Reset stuck state
        this.BotStuckState[userid] = false
        this.BotPositions[userid] = { pos = unstickPos, time = Time() }
        
        this.LogDebug("UNSTICK", "Bot " + userid + " nudged to break free")
    }
    else
    {
        this.LogDebug("UNSTICK", "Bot " + userid + " could not find unstick position")
    }
}

// ------------------------------------------------------------------
// PRIORITY 4: REGROUP - Return to team
// ------------------------------------------------------------------

function SurvivorAI::ExecuteRegroup(bot, task)
{
    local targetPos = task.targetPos
    if (!targetPos)
        return
    
    local userid = bot.GetPlayerUserId()
    local safePos = this.GetSafePosition(targetPos, 400)
    
    if (safePos)
    {
        CommandABot({cmd = 1, bot = bot, pos = safePos})
        this.BotLastCommandTime[userid] <- Time()
        this.LogDebug("REGROUP", "Bot " + userid + " regrouping with team")
    }
}

// ------------------------------------------------------------------
// CHARGER COMBAT - CRITICAL FIX
// NEVER approach, NEVER shove, ONLY shoot from optimal range
// ------------------------------------------------------------------

function SurvivorAI::ExecuteAttackCharger(bot, task)
{
    local charger = task.threat
    if (!charger || !charger.IsValid())
        return
    
    local userid = bot.GetPlayerUserId()
    local botPos = bot.GetOrigin()
    local chargerPos = charger.GetOrigin()
    local dist = (botPos - chargerPos).Length()
    
    // CASE 1: Too close - back up to optimal range
    if (dist < this.ChargerMinRange)
    {
        local away = botPos - chargerPos
        away.z = 0
        local len = away.Length()
        if (len > 0)
        {
            away.x /= len
            away.y /= len
        }
        else
        {
            away = Vector(1, 0, 0)
        }
        
        // Back up to optimal range + buffer
        local backUpDist = this.ChargerOptimalRange - dist + 100
        local backUpPos = botPos + away * backUpDist
        local safePos = this.GetSafePosition(backUpPos, 300)
        
        if (safePos)
        {
            CommandABot({cmd = 1, bot = bot, pos = safePos})
            this.BotLastCommandTime[userid] <- Time()
            this.LogDebug("CHARGER", "Bot " + userid + " backing up from Charger (dist: " + format("%.0f", dist) + ")")
        }
        return
    }
    
    // CASE 2: Too far - move closer to optimal range
    if (dist > this.ChargerMaxRange)
    {
        local toward = chargerPos - botPos
        toward.z = 0
        toward.Norm()
        
        local approachPos = chargerPos - toward * this.ChargerOptimalRange
        local safePos = this.GetSafePosition(approachPos, 300)
        
        if (safePos)
        {
            CommandABot({cmd = 1, bot = bot, pos = safePos})
            this.BotLastCommandTime[userid] <- Time()
            this.LogDebug("CHARGER", "Bot " + userid + " approaching Charger (dist: " + format("%.0f", dist) + ")")
        }
        return
    }
    
    // CASE 3: At optimal range - STAND GROUND and SHOOT
    // Do NOT move closer, do NOT shove - just aim and fire
    
    // Select Charger as target (vanilla AI will aim at it)
    CommandABot({cmd = 0, bot = bot, target = charger})
    
    // Force fire button - this is the KEY fix
    // We FORCE the bot to pull the trigger instead of hoping vanilla AI will do it
    NetProps.SetPropInt(bot, "m_afButtonForced",
        NetProps.GetPropInt(bot, "m_afButtonForced") | IN_ATTACK)
    
    this.BotLastCommandTime[userid] <- Time()
    this.LogDebug("CHARGER", "Bot " + userid + " shooting Charger at optimal range (" + format("%.0f", dist) + "u)")
}

// ------------------------------------------------------------------
// MANUAL ATTACK SYSTEM
// Forces bot to actively shoot at target instead of passive target selection
// ------------------------------------------------------------------

function SurvivorAI::ExecuteManualAttack(bot, target)
{
    if (!bot || !bot.IsValid() || !target || !target.IsValid())
        return
    
    local userid = bot.GetPlayerUserId()
    
    // Select target
    CommandABot({cmd = 0, bot = bot, target = target})
    
    // Force fire
    NetProps.SetPropInt(bot, "m_afButtonForced",
        NetProps.GetPropInt(bot, "m_afButtonForced") | IN_ATTACK)
    
    this.BotLastCommandTime[userid] <- Time()
}

// ------------------------------------------------------------------
// DEADSTOP - Automatic shove against airborne Hunter/Jockey
// ------------------------------------------------------------------

function SurvivorAI::ExecuteDeadstop(bot, target)
{
    if (!bot || !bot.IsValid() || !target || !target.IsValid())
        return
    
    local userid = bot.GetPlayerUserId()
    local now = Time()
    
    // Check shove cooldown
    if (userid in this.BotLastShoveTime && (now - this.BotLastShoveTime[userid]) < this.ShoveCooldown)
        return
    
    // Force shove
    NetProps.SetPropInt(bot, "m_afButtonForced",
        NetProps.GetPropInt(bot, "m_afButtonForced") | IN_ATTACK2)
    
    this.BotLastShoveTime[userid] <- now
    
    local zClass = NetProps.GetPropInt(target, "m_zombieClass")
    local className = (zClass == ZOMBIE_CLASS_HUNTER) ? "Hunter" : "Jockey"
    this.LogDebug("DEADSTOP", "Bot " + userid + " deadstopping " + className + "!")
}

// ------------------------------------------------------------------
// SHOVE_TONGUE - Break tongue grab by shoving victim
// ------------------------------------------------------------------

function SurvivorAI::ExecuteShoveTongue(bot, task)
{
    local victim = task.victim
    if (!victim || !victim.IsValid())
        return
    
    local userid = bot.GetPlayerUserId()
    local botPos = bot.GetOrigin()
    local victimPos = victim.GetOrigin()
    local dist = (botPos - victimPos).Length()
    
    if (dist > 100)
    {
        local safePos = this.GetSafePosition(victimPos, 200)
        if (safePos)
            CommandABot({cmd = 1, bot = bot, pos = safePos})
    }
    else
    {
        NetProps.SetPropInt(bot, "m_afButtonForced",
            NetProps.GetPropInt(bot, "m_afButtonForced") | IN_ATTACK2)
    }
    
    this.BotLastCommandTime[userid] <- Time()
    this.LogDebug("TONGUE", "Bot " + userid + " shoving tongue off teammate")
}

// ------------------------------------------------------------------
// SHOOT_TONGUE - Shoot smoker to free teammate at range
// ------------------------------------------------------------------

function SurvivorAI::ExecuteShootTongue(bot, task)
{
    local attacker = task.attacker
    if (!attacker || !attacker.IsValid())
        return
    
    local userid = bot.GetPlayerUserId()
    
    CommandABot({cmd = 0, bot = bot, target = attacker})
    
    NetProps.SetPropInt(bot, "m_afButtonForced",
        NetProps.GetPropInt(bot, "m_afButtonForced") | IN_ATTACK)
    
    this.BotLastCommandTime[userid] <- Time()
    this.LogDebug("TONGUE", "Bot " + userid + " shooting smoker to free teammate")
}

// ------------------------------------------------------------------
// DODGE - Evade danger (spit, charger, death acid)
// ------------------------------------------------------------------

function SurvivorAI::ExecuteDodge(bot, task)
{
    local sourcePos = task.sourcePos
    if (!sourcePos)
        return
    
    local userid = bot.GetPlayerUserId()
    local botPos = bot.GetOrigin()
    
    local away = botPos - sourcePos
    away.z = 0
    local len = away.Length()
    if (len > 0)
    {
        away.x /= len
        away.y /= len
    }
    else
    {
        away = Vector(1, 0, 0)
    }
    
    local strafe = Vector(-away.y, away.x, 0)
    if (RandomInt(0, 1))
        strafe = Vector(away.y, -away.x, 0)
    
    local dodgePos = botPos + away * 250 + strafe * 100
    local safePos = this.GetSafePosition(dodgePos, 250)
    
    if (safePos)
    {
        CommandABot({cmd = 1, bot = bot, pos = safePos})
        this.BotLastCommandTime[userid] <- Time()
        this.LogDebug("DODGE", "Bot " + userid + " dodging " + task.subtype)
    }
}

// ------------------------------------------------------------------
// THROW_NADE - Throw grenade at tank or horde
// ------------------------------------------------------------------

function SurvivorAI::ExecuteThrowNade(bot, task)
{
    local userid = bot.GetPlayerUserId()
    local now = Time()
    
    this.LastHordeNadeTime[userid] <- now
    
    // 1. Switch to throwable weapon (garantiza que el bot la tenga equipada)
    local throwable = this.GetThrowableSlot(bot)
    if (throwable)
    {
        bot.SwitchToItem(throwable)
    }
    
    // 2. Aim at target (tank o direccion de la horda)
    if (task.subtype == "TANK" && task.target && task.target.IsValid())
    {
        CommandABot({cmd = 0, bot = bot, target = task.target})
        this.LogDebug("NADE", "Bot " + userid + " throwing nade at tank")
    }
    else if (task.subtype == "HORDE")
    {
        // Para horda sin target específico, aim forward
        this.LogDebug("NADE", "Bot " + userid + " throwing nade at horde")
    }
    
    // 3. Force fire after short delay (da tiempo a SwitchToItem) — DelayCall one-shot
    MaoLib.DelayCall(function() {
        if (!bot || !bot.IsValid()) return
        NetProps.SetPropInt(bot, "m_afButtonForced",
            NetProps.GetPropInt(bot, "m_afButtonForced") | IN_ATTACK)
        // Release después de 0.1s para evitar stuck fire — DelayCall one-shot
        MaoLib.DelayCall(function() {
            if (bot && bot.IsValid())
            {
                NetProps.SetPropInt(bot, "m_afButtonForced",
                    NetProps.GetPropInt(bot, "m_afButtonForced") & ~IN_ATTACK)
            }
        }, 0.1)
    }, 0.15)
    
    this.BotLastCommandTime[userid] <- now
}

// ------------------------------------------------------------------
// FALL_WARP - Teleport bot to teammate to prevent fatal fall
// ------------------------------------------------------------------

function SurvivorAI::ExecuteFallWarp(bot, task)
{
    local target = task.target
    if (!target || !target.IsValid())
        return
    
    local userid = bot.GetPlayerUserId()
    local targetPos = target.GetOrigin()
    
    bot.SetOrigin(targetPos)
    
    this.LogDebug("WARP", "Bot " + userid + " warped to teammate (fatal fall prevented)")
}

// ------------------------------------------------------------------
// CLOSE_DOOR - Close saferoom door after checkpoint
// ------------------------------------------------------------------

function SurvivorAI::ExecuteCloseDoor(bot, task)
{
    local doorPos = task.doorPos
    if (!doorPos)
        return
    
    local userid = bot.GetPlayerUserId()
    
    local safePos = this.GetSafePosition(doorPos, 200)
    if (safePos)
    {
        CommandABot({cmd = 1, bot = bot, pos = safePos})
        this.BotLastCommandTime[userid] <- Time()
        
        MaoLib.AddTimer("close_door_" + userid, 0.5, function() {
            local door = Entities.FindByClassnameNearest("prop_door_rotating_checkpoint", doorPos, 100)
            if (door && door.IsValid())
            {
                DoEntFire("!self", "Close", "", 0, null, door)
                ::SurvivorAI.LogDebug("DOOR", "Bot " + userid + " closed saferoom door")
            }
        })
    }
}

// ------------------------------------------------------------------
// INTERRUPT_HEAL - Cancel heal if health is decent
// ------------------------------------------------------------------

function SurvivorAI::ExecuteInterruptHeal(bot, task)
{
    if (!bot || !bot.IsValid())
        return
    
    local userid = bot.GetPlayerUserId()
    
    CommandABot({cmd = 1, bot = bot, pos = bot.GetOrigin()})
    
    this.LogDebug("HEAL", "Bot " + userid + " interrupted heal (hp=" + task.health + ", threshold=" + this.HealInterruptThreshold + ")")
}

printl("[SurvivorAI] executor.nut loaded")

::SurvivorAI_Cleanup <- {
    function OnGameEvent_round_end(params) {
        // 🛡️ Only remove timers this script owns.
        // NEVER call MaoLib.ClearAllTimers() — it kills the shared timer manager
        // and can leave duplicate logic_timer entities between rounds.
        foreach (uid, _ in ::SurvivorAI.BotLastCommandTime) {
            MaoLib.RemoveTimer("close_door_" + uid)
        }
        ::SurvivorAI.BotLastCommandTime = {}
    }
}
__CollectGameEventCallbacks(::SurvivorAI_Cleanup)
