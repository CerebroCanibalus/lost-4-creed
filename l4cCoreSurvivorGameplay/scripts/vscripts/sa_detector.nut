// survivor_ai/detector.nut - Detect when vanilla AI is failing
// Philosophy: Only intervene when vanilla AI visibly fails

// ------------------------------------------------------------------
// MAIN DETECTION FUNCTION
// Returns task object if intervention needed, null if vanilla is handling it
// ------------------------------------------------------------------

function SurvivorAI::DetectTask(bot)
{
    if (!bot || !bot.IsValid())
        return null
    
    local now = Time()
    local botPos = bot.GetOrigin()
    local userid = bot.GetPlayerUserId()
    
    // 0. CRITICAL OVERRIDE: Fall warp (fatal fall avoidance)
    local fallTask = this.DetectFallRisk(bot)
    if (fallTask)
        return fallTask
    
    // 0. CRITICAL OVERRIDE: Tongue rescue (immediate action needed)
    local tongueTask = this.DetectTongueVictim(bot)
    if (tongueTask)
        return tongueTask
    
    // 1. HIGHEST PRIORITY: Immediate danger to self
    // Vanilla AI sometimes fails to dodge tank punches, chargers, rocks
    local surviveTask = this.DetectSurviveTask(bot)
    if (surviveTask)
        return surviveTask
    
    // 1.5. Event-driven dodge (spit burst, charger charge)
    local dodgeTask = this.DetectDodgeTask(bot)
    if (dodgeTask)
        return dodgeTask
    
    // 2. HIGH PRIORITY: Rescue pinned teammate
    // Vanilla AI often ignores or is very slow to rescue
    local rescueTask = this.DetectRescueTask(bot)
    if (rescueTask)
        return rescueTask
    
    // 3. MEDIUM PRIORITY: Combat assistance
    // Vanilla AI sometimes "freezes" with commons or ignores SI
    local combatTask = this.DetectCombatTask(bot)
    if (combatTask)
        return combatTask
    
    // 3.5. Auto nade throw (tank or horde)
    local nadeTask = this.DetectNadeOpportunity(bot)
    if (nadeTask)
        return nadeTask
    
    // 4. LOW PRIORITY: Position correction
    // Vanilla AI sometimes gets stuck or wanders off
    local positionTask = this.DetectPositionTask(bot)
    if (positionTask)
        return positionTask
    
    return null
}

// ------------------------------------------------------------------
// PRIORITY 0: FALL WARP - Detect fatal falls
// ------------------------------------------------------------------

function SurvivorAI::DetectFallRisk(bot)
{
    local vel = bot.GetVelocity()
    if (vel.z < this.FallWarpVelocity)
    {
        local botPos = bot.GetOrigin()
        
        // Find nearest alive teammate
        local nearestDist = this.FallWarpDistance
        local nearest = null
        
        foreach (uid, survivor in this.CachedSurvivors)
        {
            if (!survivor || !survivor.IsValid() || survivor == bot)
                continue
            if (NetProps.GetPropInt(survivor, "m_lifeState") != 0)
                continue
            
            local dist = (botPos - survivor.GetOrigin()).Length()
            if (dist < nearestDist)
            {
                nearestDist = dist
                nearest = survivor
            }
        }
        
        if (nearest)
        {
            this.LogDebug("FALL", "Bot " + bot.GetPlayerUserId() + " falling, warping to teammate")
            return { type = "FALL_WARP", priority = 100, target = nearest }
        }
    }
    
    return null
}

// ------------------------------------------------------------------
// PRIORITY 0: TONGUE VICTIM DETECTION - Rescue from smoker tongue
// ------------------------------------------------------------------

function SurvivorAI::DetectTongueVictim(bot)
{
    local botPos = bot.GetOrigin()
    
    // Check CachedSurvivors for tongue victims via netprops
    foreach (uid, survivor in this.CachedSurvivors)
    {
        if (!survivor || !survivor.IsValid())
            continue
        if (NetProps.GetPropInt(survivor, "m_lifeState") != 0)
            continue
        
        local tongueOwner = NetProps.GetPropEntity(survivor, "m_tongueOwner")
        if (tongueOwner && tongueOwner.IsValid())
        {
            local dist = (botPos - survivor.GetOrigin()).Length()
            
            if (dist < this.TongueShoveRange)
            {
                this.LogDebug("TONGUE", "Bot " + bot.GetPlayerUserId() + " close enough to shove tongue, dist=" + dist)
                return { type = "SHOVE_TONGUE", priority = 98, victim = survivor, attacker = tongueOwner, distance = dist }
            }
            
            if (dist < this.ShootTongueRange)
            {
                this.LogDebug("TONGUE", "Bot " + bot.GetPlayerUserId() + " shooting tongue, dist=" + dist)
                return { type = "SHOOT_TONGUE", priority = 97, victim = survivor, attacker = tongueOwner, distance = dist }
            }
        }
    }
    
    return null
}

// ------------------------------------------------------------------
// PRIORITY 1.5: DODGE - Event-driven danger avoidance
// ------------------------------------------------------------------

function SurvivorAI::DetectDodgeTask(bot)
{
    local now = Time()
    local botPos = bot.GetOrigin()
    
    // Check spit bursts (active spit puddles)
    foreach (spitId, data in this.SpitBursts)
    {
        if ((now - data.time) > 2.0)
            continue
        
        local dist = (botPos - data.pos).Length()
        this.LogDebug("DODGE", "Spit puddle dist=" + dist + " range=" + this.SpitDodgeRange)
        
        if (dist < this.SpitDodgeRange)
        {
            return { type = "DODGE", subtype = "SPIT", priority = 99, sourcePos = data.pos }
        }
    }
    
    // Check charger charges
    foreach (chUserId, data in this.ChargerCharges)
    {
        if ((now - data.startTime) > 3.0)
            continue
        
        if (chUserId in this.CachedSpecials)
        {
            local charger = this.CachedSpecials[chUserId]
            if (charger && charger.IsValid())
            {
                local dist = (botPos - data.startPos).Length()
                this.LogDebug("DODGE", "Charger charge dist=" + dist + " range=" + this.ChargerDodgeRange)
                
                if (dist < this.ChargerDodgeRange)
                {
                    return { type = "DODGE", subtype = "CHARGER", priority = 99, sourcePos = data.startPos, threat = charger }
                }
            }
        }
    }
    
    // Check death acid (spitter death puddle)
    foreach (acidId, data in this.DeathAcidPositions)
    {
        if ((now - data.time) > 3.0)
            continue
        
        local dist = (botPos - data.pos).Length()
        this.LogDebug("DODGE", "Death acid dist=" + dist + " range=" + this.DeathAcidDodgeRange)
        
        if (dist < this.DeathAcidDodgeRange)
        {
            return { type = "DODGE", subtype = "DEATH_ACID", priority = 98, sourcePos = data.pos }
        }
    }
    
    return null
}

// ------------------------------------------------------------------
// PRIORITY 3.5: GRENADE OPPORTUNITY - Auto-throw pipebomb/molotov/bile
// ------------------------------------------------------------------

function SurvivorAI::DetectNadeOpportunity(bot)
{
    local now = Time()
    local userid = bot.GetPlayerUserId()
    local botPos = bot.GetOrigin()
    
    // Check cooldown (30s between auto-nade throws)
    if (userid in this.LastHordeNadeTime && (now - this.LastHordeNadeTime[userid]) < 30.0)
        return null
    
    // Check if bot has a throwable (check slot2, not just active weapon)
    local throwableClass = this.GetThrowableSlot(bot)
    if (!throwableClass)
        return null
    
    // Classify what type of throwable the bot has
    local itemType = this.ClassifyThrowable(throwableClass)
    if (!itemType)
        return null
    
    // ---- Check tank opportunity ----
    local tank = this.FindTank()
    if (tank && tank.IsValid())
    {
        local dist = (botPos - tank.GetOrigin()).Length()
        this.LogDebug("NADE", "Tank dist=" + dist + " range=" + this.TankNadeRange + " chance=" + this.TankNadeChance)
        
        // Solo lanzar si config permite este throwable vs tank
        if (dist < this.TankNadeRange && this.CanUseThrowable(itemType, "TANK") && ::MaoLib.Probability(this.TankNadeChance * 100))
        {
            this.LogDebug("NADE", "Bot " + userid + " throwing " + throwableClass + " at tank")
            this.LastHordeNadeTime[userid] <- now
            return { type = "THROW_NADE", subtype = "TANK", priority = 65, target = tank }
        }
    }
    
    // ---- Check horde opportunity ----
    local commons = this.CountNearbyCommons(bot, this.HordeNadeRange)
    this.LogDebug("NADE", "Commons=" + commons + " threshold=" + this.HordeNadeSize + " chance=" + this.HordeNadeChance)
    
    if (commons >= this.HordeNadeSize && this.CanUseThrowable(itemType, "HORDE") && ::MaoLib.Probability(this.HordeNadeChance * 100))
    {
        this.LogDebug("NADE", "Bot " + userid + " throwing " + throwableClass + " at horde")
        this.LastHordeNadeTime[userid] <- now
        return { type = "THROW_NADE", subtype = "HORDE", priority = 55 }
    }
    
    return null
}

// ------------------------------------------------------------------
// PRIORITY 1: SURVIVE - Immediate danger detection
// ------------------------------------------------------------------

function SurvivorAI::DetectSurviveTask(bot)
{
    local botPos = bot.GetOrigin()
    
    // Check tank punch danger
    local tank = this.FindTank()
    if (tank && tank.IsValid())
    {
        local dist = (botPos - tank.GetOrigin()).Length()
        
        // Tank is very close and might punch
        if (dist < this.TankDangerRange)
        {
            // Check if tank is in punch animation
            local sequence = NetProps.GetPropInt(tank, "m_nSequence")
            if (sequence == 47 || sequence == 48)  // Punch sequences
            {
                return {
                    type = "SURVIVE",
                    subtype = "TANK_PUNCH",
                    priority = 100,
                    threat = tank
                }
            }
            
            // Tank is close enough to be dangerous even if not punching yet
            if (dist < 150)
            {
                return {
                    type = "SURVIVE",
                    subtype = "TANK_CLOSE",
                    priority = 95,
                    threat = tank
                }
            }
        }
        
        // Check tank rock
        local rock = this.FindTankRock(tank)
        if (rock && rock.IsValid())
        {
            local rockPos = rock.GetOrigin()
            local rockDist = (botPos - rockPos).Length()
            
            if (rockDist < 800 && rockDist > 100)
            {
                local rockVel = rock.GetVelocity()
                if (rockVel.Length() > 50)
                {
                    rockVel.Norm()
                    local toBot = botPos - rockPos
                    toBot.Norm()
                    
                    // Check if rock is heading towards us
                    local dot = rockVel.Dot(toBot)
                    if (dot > 1.0) dot = 1.0
                    if (dot < -1.0) dot = -1.0
                    local angleDiff = acos(dot) * 180 / PI
                    if (angleDiff < 30)
                    {
                        return {
                            type = "SURVIVE",
                            subtype = "TANK_ROCK",
                            priority = 98,
                            threat = rock,
                            threatOwner = tank
                        }
                    }
                }
            }
        }
    }
    
    // Check charger charge using vision system
    local chargerThreat = this.GetVisibleCharger(bot)
    if (chargerThreat)
    {
        local charger = chargerThreat.entity
        local dist = chargerThreat.distance
        
        // If charger is charging or very close, dodge
        if (("isCharging" in chargerThreat && chargerThreat.isCharging) || dist < 200)
        {
            return {
                type = "SURVIVE",
                subtype = "CHARGER_CHARGE",
                priority = 99,
                threat = charger,
                distance = dist
            }
        }
        
        // If charger is pummeling a teammate, we need to attack it
        if ("isPummeling" in chargerThreat && chargerThreat.isPummeling)
        {
            return {
                type = "ATTACK_CHARGER",
                subtype = "CHARGER_PUMMEL",
                priority = 96,
                threat = charger,
                distance = dist
            }
        }
    }
    
    // Check fire/acid
    if (this.IsInFireOrAcid(bot))
    {
        return {
            type = "SURVIVE",
            subtype = "FIRE_ACID",
            priority = 97
        }
    }
    
    return null
}

// ------------------------------------------------------------------
// PRIORITY 2: RESCUE - Pinned teammate detection
// ------------------------------------------------------------------

function SurvivorAI::DetectRescueTask(bot)
{
    local now = Time()
    local botPos = bot.GetOrigin()
    
    foreach (player in MaoLib.YieldSurvivors())
    {
        if (!player || !player.IsValid() || player == bot)
            continue
        
        if (NetProps.GetPropInt(player, "m_lifeState") != 0)
            continue
        
        local victimId = player.GetPlayerUserId()
        local isPinned = this.IsPinned(player)
        
        if (isPinned)
        {
            // Track when pin started
            if (!(victimId in this.PinStartTime))
                this.PinStartTime[victimId] <- now
            
            local pinDuration = now - this.PinStartTime[victimId]
            local dist = (botPos - player.GetOrigin()).Length()
            
            // Only intervene if within rescue distance
            if (dist > this.RescueMaxDist)
                continue
            
            // Determine timeout based on attacker type
            local attacker = this.GetAttackerOf(player)
            local timeout = this.RescueTimeoutSmoker
            
            if (attacker && attacker.IsValid())
            {
                local zClass = NetProps.GetPropInt(attacker, "m_zombieClass")
                switch (zClass)
                {
                    case 3: // HUNTER
                        timeout = this.RescueTimeoutHunter
                        break
                    case 5: // JOCKEY
                        timeout = this.RescueTimeoutJockey
                        break
                    case 6: // CHARGER
                        timeout = this.RescueTimeoutCharger
                        break
                }
            }
            
            // Intervene if vanilla AI hasn't rescued in time
            if (pinDuration >= timeout)
            {
                return {
                    type = "RESCUE",
                    priority = 90,
                    victim = player,
                    attacker = attacker,
                    pinDuration = pinDuration
                }
            }
        }
        else
        {
            // Not pinned anymore, clear tracking
            if (victimId in this.PinStartTime)
                delete this.PinStartTime[victimId]
        }
    }
    
    return null
}

// ------------------------------------------------------------------
// PRIORITY 3: COMBAT - Combat assistance detection
// ------------------------------------------------------------------

function SurvivorAI::DetectCombatTask(bot)
{
    local botPos = bot.GetOrigin()
    local userid = bot.GetPlayerUserId()
    local now = Time()
    
    // Check commons amassing in melee range
    // Pros only shove when 5+ commons are VERY close (actual shove range ~75u)
    // Shoving 2-3 commons at 150u is inefficient and wastes shove penalty
    local nearbyCommons = this.CountNearbyCommons(bot, this.CommonDetectRadius)
    if (nearbyCommons >= this.CommonShoveThreshold)
    {
        // Check cooldown
        if (!(userid in this.BotLastShoveTime) || (now - this.BotLastShoveTime[userid]) >= this.ShoveCooldown)
        {
            return {
                type = "SHOVE",
                priority = 80,
                count = nearbyCommons,
                isHorde = nearbyCommons >= this.CommonShoveMax
            }
        }
    }
    
    // Check special infected (vanilla AI sometimes ignores visible SI)
    // Usa caché de entidades en vez de escanear cada frame
    // CachedSpecials solo contiene SI no-tank (1-6), tanks van a CachedTanks
    foreach (siUid, si in this.CachedSpecials)
    {
        if (!si || !si.IsValid())
            continue
        
        local dist = (botPos - si.GetOrigin()).Length()
        if (dist < this.SIAttackRange)
        {
            // Check if we can see the SI
            // NOTE: L4D2 TraceLine uses 4 params: (start, end, ignoreEnt, resultsTable)
            local trace = {}
            TraceLine(bot.EyePosition(), si.GetOrigin(), null, trace)
            if (trace.fraction >= 0.95)
            {
                return {
                    type = "ATTACK_SI",
                    priority = 70,
                    target = si,
                    distance = dist
                }
            }
        }
    }
    
    // Check tank positioning (vanilla AI gets too close)
    local tank = this.FindTank()
    if (tank && tank.IsValid())
    {
        local dist = (botPos - tank.GetOrigin()).Length()
        if (dist < this.TankKiteRange && dist > this.TankDangerRange)
        {
            return {
                type = "KITE_TANK",
                priority = 60,
                threat = tank,
                distance = dist
            }
        }
    }
    
    return null
}

// ------------------------------------------------------------------
// PRIORITY 4: POSITION - Stuck / separated detection
// ------------------------------------------------------------------

function SurvivorAI::DetectPositionTask(bot)
{
    local now = Time()
    local botPos = bot.GetOrigin()
    local userid = bot.GetPlayerUserId()
    
    // Stuck detection
    if (!(userid in this.BotPositions))
    {
        this.BotPositions[userid] <- { pos = botPos, time = now }
        this.BotStuckState[userid] <- false
    }
    
    local last = this.BotPositions[userid]
    local moved = (botPos - last.pos).Length()
    
    if (moved > this.StuckMinDist)
    {
        // Bot moved, update tracking
        last.pos = botPos
        last.time = now
        this.BotStuckState[userid] = false
    }
    else if ((now - last.time) >= this.StuckThreshold)
    {
        // Bot hasn't moved enough in StuckThreshold seconds
        if (!this.BotStuckState[userid])
        {
            this.LogDebug("STUCK", "Bot " + userid + " stuck for " + format("%.1f", now - last.time) + "s")
            this.BotStuckState[userid] = true
        }
        
        return {
            type = "UNSTICK",
            priority = 50
        }
    }
    
    // Team separation check (only if no threats)
    local teamCenter = this.GetTeamCenter()
    if (teamCenter)
    {
        local distToTeam = (botPos - teamCenter).Length()
        if (distToTeam > this.TeamSeparationThreshold)
        {
            // Check if there are immediate threats (don't regroup during combat)
            local hasThreats = this.HasNearbyThreats(bot, 500)
            if (!hasThreats)
            {
                return {
                    type = "REGROUP",
                    priority = 40,
                    targetPos = teamCenter
                }
            }
        }
    }
    
    return null
}

// ------------------------------------------------------------------
// HELPER FUNCTIONS
// ------------------------------------------------------------------

function SurvivorAI::FindTank()
{
    foreach (userid, tank in this.CachedTanks)
    {
        if (tank && tank.IsValid())
            return tank
    }
    return null
}

function SurvivorAI::FindTankRock(tank)
{
    if (!tank || !tank.IsValid())
        return null
    
    local rock = null
    while (rock = Entities.FindByClassname(rock, "tank_rock"))
    {
        if (rock && rock.IsValid())
        {
            local thrower = NetProps.GetPropEntity(rock, "m_hThrower")
            if (thrower != null && thrower.IsValid() && thrower == tank)
                return rock
        }
    }
    return null
}

function SurvivorAI::FindChargerAimingAt(bot)
{
    local botPos = bot.GetOrigin()
    
    foreach (chUid, player in this.CachedSpecials)
    {
        if (!player || !player.IsValid())
            continue
        
        // Skip ghosts (invisible, can't interact)
        if (player.IsGhost())
            continue
        
        local zClass = NetProps.GetPropInt(player, "m_zombieClass")
        if (zClass != ZOMBIE_CLASS_CHARGER)
            continue
        
        local chargerPos = player.GetOrigin()
        local dist = (botPos - chargerPos).Length()
        
        if (dist < 80 || dist > 600)
            continue
        
        // Check if charger is charging (has ability entity)
        local ability = NetProps.GetPropEntity(player, "m_customAbility")
        if (!ability || !ability.IsValid())
            continue
        
        // Check angle
        local chargerAng = player.EyeAngles()
        local chargerForward = chargerAng.Forward()
        chargerForward.z = 0
        local forwardLen = chargerForward.Length()
        if (forwardLen > 0)
        {
            chargerForward.x /= forwardLen
            chargerForward.y /= forwardLen
        }
        
        local toBot = botPos - chargerPos
        toBot.z = 0
        local toBotLen = toBot.Length()
        if (toBotLen > 0)
        {
            toBot.x /= toBotLen
            toBot.y /= toBotLen
        }
        
        local dot = chargerForward.Dot(toBot)
        if (dot > 1.0) dot = 1.0
        if (dot < -1.0) dot = -1.0
        local angleDiff = acos(dot) * 180 / PI
        if (angleDiff < 45)
        {
            return player
        }
    }
    
    return null
}

function SurvivorAI::IsInFireOrAcid(bot)
{
    local botPos = bot.GetOrigin()
    local inferno = null
    while (inferno = Entities.FindByClassnameWithin(inferno, "inferno", botPos, 100))
    {
        if (inferno && inferno.IsValid())
            return true
    }
    return false
}

function SurvivorAI::CountNearbyCommons(bot, radius)
{
    local count = 0
    local common = null
    while (common = Entities.FindByClassnameWithin(common, "infected", bot.GetOrigin(), radius))
    {
        if (common && common.IsValid())
            count++
    }
    return count
}

function SurvivorAI::CanSeeEntity(viewer, target)
{
    if (!viewer || !viewer.IsValid() || !target || !target.IsValid())
        return false
    
    // TraceLine takes 4 params: (start, end, ignoreEnt, resultsTable)
    // Third param is entity to ignore (null = none), fourth gets filled with results
    local trace = {}
    TraceLine(viewer.EyePosition(), target.GetOrigin(), null, trace)
    return trace.fraction >= 0.95
}

function SurvivorAI::GetTeamCenter()
{
    local sum_x = 0.0, sum_y = 0.0, sum_z = 0.0
    local count = 0
    
    foreach (player in MaoLib.YieldSurvivors())
    {
        if (!player || !player.IsValid())
            continue
        if (NetProps.GetPropInt(player, "m_lifeState") != 0)
            continue
        
        local origin = player.GetOrigin()
        sum_x += origin.x
        sum_y += origin.y
        sum_z += origin.z
        count++
    }
    
    if (count > 0)
    {
        local inv = 1.0 / count
        return Vector(sum_x * inv, sum_y * inv, sum_z * inv)
    }
    
    return null
}

function SurvivorAI::HasNearbyThreats(bot, radius)
{
    local botPos = bot.GetOrigin()
    
    // Check SI (usa caché)
    foreach (threatUid, si in this.CachedSpecials)
    {
        if (si && si.IsValid() && (botPos - si.GetOrigin()).Length() < radius)
            return true
    }
    
    // Check Tanks (usa caché)
    foreach (tankUid, tank in this.CachedTanks)
    {
        if (tank && tank.IsValid() && (botPos - tank.GetOrigin()).Length() < radius)
            return true
    }
    
    // Check commons
    if (this.CountNearbyCommons(bot, radius) >= 3)
        return true
    
    return false
}

function SurvivorAI::GetAttackerOf(survivor)
{
    if (!survivor || !survivor.IsValid())
        return null
    
    local attacker = NetProps.GetPropEntity(survivor, "m_pounceAttacker")
    if (attacker && attacker.IsValid()) return attacker
    
    attacker = NetProps.GetPropEntity(survivor, "m_tongueOwner")
    if (attacker && attacker.IsValid()) return attacker
    
    attacker = NetProps.GetPropEntity(survivor, "m_jockeyAttacker")
    if (attacker && attacker.IsValid()) return attacker
    
    attacker = NetProps.GetPropEntity(survivor, "m_pummelAttacker")
    if (attacker && attacker.IsValid()) return attacker
    
    attacker = NetProps.GetPropEntity(survivor, "m_carryAttacker")
    if (attacker && attacker.IsValid()) return attacker
    
    return null
}

function SurvivorAI::IsPinned(survivor)
{
    if (!survivor || !survivor.IsValid())
        return false
    
    return (
        NetProps.GetPropEntity(survivor, "m_pounceAttacker") != null ||
        NetProps.GetPropEntity(survivor, "m_tongueOwner") != null ||
        NetProps.GetPropEntity(survivor, "m_jockeyAttacker") != null ||
        NetProps.GetPropEntity(survivor, "m_pummelAttacker") != null ||
        NetProps.GetPropEntity(survivor, "m_carryAttacker") != null
    )
}

function SurvivorAI::LogDebug(category, message)
{
    if (this.DebugEnabled)
    {
        printl("[SurvivorAI][" + category + "] " + message)
    }
}

printl("[SurvivorAI] detector.nut loaded")
