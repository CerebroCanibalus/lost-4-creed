// survivor_ai/vision.nut - Proactive vision system for survivor bots
// Detects threats before they attack, enables early response

// ------------------------------------------------------------------
// MAIN VISION SCAN
// Scans environment for visible threats and caches results
// ------------------------------------------------------------------

getroottable().SurvivorAI.VisionScan <- function(bot)
{
    if (!bot || !bot.IsValid())
        return null
    
    local botPos = bot.GetOrigin()
    local botEye = bot.EyePosition()
    local botAngles = bot.EyeAngles()
    local botForward = botAngles.Forward()
    
    local threats = []
    local now = Time()
    
    // Scan Special Infected (usa caché en vez de escanear cada frame)
    foreach (siUid, si in this.CachedSpecials)
    {
        if (!si || !si.IsValid())
            continue
        
        // Skip ghosts
        if (si.IsGhost())
            continue
        
        local siPos = si.GetOrigin()
        local dist = (botPos - siPos).Length()
        
        // Skip if too far
        if (dist > this.VisionMaxDistance)
            continue
        
        // Check FOV (with peripheral vision for very close threats)
        local toSI = siPos - botPos
        toSI.z = 0
        local toSILen = toSI.Length()
        if (toSILen > 0)
        {
            toSI.x /= toSILen
            toSI.y /= toSILen
        }
        
        local botFwd2D = botForward
        botFwd2D.z = 0
        local fwdLen = botFwd2D.Length()
        if (fwdLen > 0)
        {
            botFwd2D.x /= fwdLen
            botFwd2D.y /= fwdLen
        }
        
        local dot = botFwd2D.Dot(toSI)
        if (dot > 1.0) dot = 1.0
        if (dot < -1.0) dot = -1.0
        local angleDiff = acos(dot) * 180 / PI
        
        // Within FOV or very close (peripheral vision)
        if (angleDiff > this.VisionFOV && dist > 200)
            continue
        
        // Line of sight check
        if (!this.CanSeeEntity(bot, si))
            continue
        
        // Get threat info
        local zClass = NetProps.GetPropInt(si, "m_zombieClass")
        local threat = {
            entity = si,
            classId = zClass,
            distance = dist,
            angle = angleDiff,
            visible = true,
            lastSeen = now
        }
        
        // Charger-specific early detection
        if (zClass == ZOMBIE_CLASS_CHARGER)
        {
            threat.isCharging <- this.IsChargerCharging(si)
            threat.isPreCharge <- this.IsChargerPreCharge(si)
            threat.isPummeling <- this.IsChargerPummeling(si)
        }
        
        // Hunter/Jockey air detection for deadstop
        if (zClass == ZOMBIE_CLASS_HUNTER || zClass == ZOMBIE_CLASS_JOCKEY)
        {
            threat.isAirborne <- this.IsAirborneAtPlayer(si, bot)
        }
        
        threats.append(threat)
    }
    
    // Scan Tanks (caché separado)
    foreach (tankUid, tank in this.CachedTanks)
    {
        if (!tank || !tank.IsValid())
            continue
        
        local tankPos = tank.GetOrigin()
        local dist = (botPos - tankPos).Length()
        
        if (dist > this.VisionMaxDistance)
            continue
        
        // At close range, tanks are always detected (peripheral awareness)
        if (dist > 200)
        {
            local toTank = tankPos - botPos
            toTank.z = 0
            local toTankLen = toTank.Length()
            if (toTankLen > 0)
            {
                toTank.x /= toTankLen
                toTank.y /= toTankLen
            }
            
            local botFwd2D = botForward
            botFwd2D.z = 0
            local fwdLen = botFwd2D.Length()
            if (fwdLen > 0)
            {
                botFwd2D.x /= fwdLen
                botFwd2D.y /= fwdLen
            }
            
            local dot = botFwd2D.Dot(toTank)
            if (dot > 1.0) dot = 1.0
            if (dot < -1.0) dot = -1.0
            local angleDiff = acos(dot) * 180 / PI
            
            // Apply FOV check only for farther tanks
            if (angleDiff > this.VisionFOV)
                continue
        }
        
        if (this.CanSeeEntity(bot, tank))
        {
            threats.append({
                entity = tank,
                classId = ZOMBIE_CLASS_TANK,
                distance = dist,
                angle = 0,
                visible = true,
                lastSeen = now
            })
        }
    }
    
    // Count visible commons for horde awareness
    local commonCount = 0
    local common = null
    while (common = Entities.FindByClassnameWithin(common, "infected", botPos, this.VisionCommonRadius))
    {
        if (common && common.IsValid() && this.CanSeeEntity(bot, common))
            commonCount++
    }
    
    // Store vision state for this bot
    local userid = bot.GetPlayerUserId()
    this.BotVision[userid] <- {
        threats = threats,
        commonCount = commonCount,
        lastScan = now,
        scanPos = botPos
    }
    
    return threats
}

// ------------------------------------------------------------------
// CHARGER DETECTION HELPERS
// ------------------------------------------------------------------

getroottable().SurvivorAI.IsChargerCharging <- function(charger)
{
    if (!charger || !charger.IsValid())
        return false
    
    // Charging chargers have high velocity
    local vel = charger.GetVelocity()
    return vel.Length() > 250
}

getroottable().SurvivorAI.IsChargerPreCharge <- function(charger)
{
    if (!charger || !charger.IsValid())
        return false
    
    local ability = NetProps.GetPropEntity(charger, "m_customAbility")
    if (!ability || !ability.IsValid())
        return false
    
    // Has ability but not charging yet = preparing
    local vel = charger.GetVelocity()
    return vel.Length() < 150
}

getroottable().SurvivorAI.IsChargerPummeling <- function(charger)
{
    if (!charger || !charger.IsValid())
        return false
    
    // Check survivors for m_pummelAttacker pointing to this charger
    foreach (survivor in MaoLib.YieldSurvivors())
    {
        if (!survivor || !survivor.IsValid())
            continue
        
        local attacker = NetProps.GetPropEntity(survivor, "m_pummelAttacker")
        if (attacker != null && attacker.IsValid() && attacker == charger)
            return true
    }
    return false
}

// ------------------------------------------------------------------
// HUNTER/JOCKEY AIRBORNE DETECTION (for deadstop)
// ------------------------------------------------------------------

getroottable().SurvivorAI.IsAirborneAtPlayer <- function(infected, player)
{
    if (!infected || !infected.IsValid() || !player || !player.IsValid())
        return false
    
    // Check if airborne (not on ground)
    local flags = NetProps.GetPropInt(infected, "m_fFlags")
    if (flags & 1) // FL_ONGROUND
        return false
    
    // Check velocity (moving toward player)
    local infPos = infected.GetOrigin()
    local playerPos = player.GetOrigin()
    local vel = infected.GetVelocity()
    
    if (vel.z < 50) // Not jumping/pouncing up
        return false
    
    local dist = (infPos - playerPos).Length()
    if (dist > 300)
        return false
    
    // Check if trajectory is toward player
    local toPlayer = playerPos - infPos
    toPlayer.z = 0
    toPlayer.Norm()
    
    local vel2D = vel
    vel2D.z = 0
    vel2D.Norm()
    
    return toPlayer.Dot(vel2D) > 0.5 // Moving roughly toward player
}

// ------------------------------------------------------------------
// VISION STATE ACCESSORS
// ------------------------------------------------------------------

getroottable().SurvivorAI.GetVisibleThreats <- function(bot)
{
    if (!bot || !bot.IsValid())
        return []
    
    local userid = bot.GetPlayerUserId()
    if (userid in this.BotVision && this.BotVision[userid])
    {
        local vision = this.BotVision[userid]
        // Return cached threats if recent enough
        if (Time() - vision.lastScan < this.VisionCacheTime)
            return vision.threats
    }
    
    // Scan now
    return this.VisionScan(bot)
}

getroottable().SurvivorAI.GetBestAttackTarget <- function(bot)
{
    local threats = this.GetVisibleThreats(bot)
    if (threats.len() == 0)
        return null
    
    // Score each threat
    local bestScore = -1
    local bestTarget = null
    
    foreach (threat in threats)
    {
        local score = 0
        
        // Closer = higher priority (but not too close)
        if (threat.distance < 100)
            score += 300
        else if (threat.distance < 500)
            score += 200
        else
            score += (1500 - threat.distance) * 0.1
        
        // Class priorities
        switch (threat.classId)
        {
            case ZOMBIE_CLASS_CHARGER:
                score += 600
                if ("isCharging" in threat && threat.isCharging)
                    score += 1000
                if ("isPummeling" in threat && threat.isPummeling)
                    score += 800
                break
            case ZOMBIE_CLASS_HUNTER:
                score += 500
                if ("isAirborne" in threat && threat.isAirborne)
                    score += 700 // High priority for deadstop
                break
            case ZOMBIE_CLASS_JOCKEY:
                score += 400
                if ("isAirborne" in threat && threat.isAirborne)
                    score += 600
                break
            case ZOMBIE_CLASS_SMOKER:
                score += 450
                break
            case ZOMBIE_CLASS_TANK:
                score += 300
                break
            case ZOMBIE_CLASS_SPITTER:
                score += 250
                break
            case ZOMBIE_CLASS_BOOMER:
                score += 200
                break
        }
        
        // Lower angle (more directly in front) = slightly higher priority
        score += (180 - threat.angle) * 0.5
        
        if (score > bestScore)
        {
            bestScore = score
            bestTarget = threat.entity
        }
    }
    
    return bestTarget
}

getroottable().SurvivorAI.GetVisibleCharger <- function(bot)
{
    local threats = this.GetVisibleThreats(bot)
    foreach (threat in threats)
    {
        if (threat.classId == ZOMBIE_CLASS_CHARGER)
            return threat
    }
    return null
}

getroottable().SurvivorAI.GetAirborneHunterOrJockey <- function(bot)
{
    local threats = this.GetVisibleThreats(bot)
    foreach (threat in threats)
    {
        if ((threat.classId == ZOMBIE_CLASS_HUNTER || threat.classId == ZOMBIE_CLASS_JOCKEY)
            && "isAirborne" in threat && threat.isAirborne)
        {
            return threat.entity
        }
    }
    return null
}

// ------------------------------------------------------------------
// SHOULD SCAN CHECK
// ------------------------------------------------------------------

printl("[SurvivorAI] vision.nut loaded")
