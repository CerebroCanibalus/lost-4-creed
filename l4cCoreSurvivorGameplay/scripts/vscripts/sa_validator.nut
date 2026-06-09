// survivor_ai/validator.nut - Navmesh validation and safe pathfinding
// Uses MaoLib.NavUtils for robust navigation validation

// ------------------------------------------------------------------
// VALIDATE NAVIGATION POSITION
// Returns true if position is on valid navmesh
// ------------------------------------------------------------------

function SurvivorAI::IsValidNavPos(pos)
{
    if (!pos)
        return false
    
    try
    {
        // Try MaoLib.NavUtils first (most robust)
        if ("NavUtils" in MaoLib)
        {
            local nav = MaoLib.NavUtils.GetNearestNavArea(pos, this.NavValidationRadius, true)
            if (nav && MaoLib.NavUtils.IsAreaValid(nav))
            {
                // Additional check: ensure it's not a bogus checkpoint
                local attr = NetProps.GetPropInt(nav, "m_attributeFlags")
                if (attr & 4096)  // NAV_MESH_CHECKPOINT
                {
                    // Verify there's actually a checkpoint door nearby
                    local door = Entities.FindByClassnameNearest("prop_door_rotating_checkpoint", pos, 500)
                    if (!door)
                    {
                        // Bogus checkpoint nav area (known bug in some maps)
                        return false
                    }
                }
                return true
            }
        }
        
        // Fallback: direct NavMesh call
        local nav = NavMesh.GetNearestNavArea(pos, this.NavValidationRadius, true, true, 2)
        if (nav)
            return true
    }
    catch (ex)
    {
        // NavMesh not available on this map
    }
    
    return false
}

// ------------------------------------------------------------------
// GET SAFE POSITION NEAR TARGET
// If target position is invalid, find nearest valid nav area
// ------------------------------------------------------------------

function SurvivorAI::GetSafePosition(targetPos, maxSearchRadius)
{
    if (!maxSearchRadius)
        maxSearchRadius = 300
    
    // First check: is target position valid?
    if (this.IsValidNavPos(targetPos))
        return targetPos
    
    // Second check: try MaoLib.NavUtils to find nearby valid area
    if ("NavUtils" in MaoLib)
    {
        try
        {
            // Search in expanding circles
            local searchRadii = [100, 200, 300, 500]
            foreach (radius in searchRadii)
            {
                if (radius > maxSearchRadius)
                    break
                
                // Use NavUtils to find high ground or open areas nearby
                local areas = MaoLib.NavUtils.FindHighGround(targetPos, radius, 10)
                if (areas && areas.len() > 0)
                {
                    foreach (areaInfo in areas)
                    {
                        if ("pos" in areaInfo && this.IsValidNavPos(areaInfo.pos))
                            return areaInfo.pos
                    }
                }
                
                // Try finding any valid nav area
                local nav = MaoLib.NavUtils.GetNearestNavArea(targetPos, radius, true)
                if (nav && MaoLib.NavUtils.IsAreaValid(nav))
                {
                    local center = nav.GetCenter()
                    if (this.IsValidNavPos(center))
                        return center
                }
            }
        }
        catch (ex)
        {
            // NavUtils function not available, continue to fallback
        }
    }
    
    // Fallback: manual spiral search
    return this.SpiralSearchValidNav(targetPos, maxSearchRadius)
}

// ------------------------------------------------------------------
// SPIRAL SEARCH FOR VALID NAV POSITION
// Search in spiral pattern around center point
// ------------------------------------------------------------------

function SurvivorAI::SpiralSearchValidNav(center, maxRadius)
{
    local angles = [0, 45, 90, 135, 180, 225, 270, 315]
    local radii = [50, 100, 150, 200, 250, 300]
    
    foreach (radius in radii)
    {
        if (radius > maxRadius)
            break
        
        foreach (angle in angles)
        {
            local rad = angle * PI / 180.0
            local offset = Vector(cos(rad) * radius, sin(rad) * radius, 0)
            local checkPos = center + offset
            
            if (this.IsValidNavPos(checkPos))
                return checkPos
        }
    }
    
    return null
}

// ------------------------------------------------------------------
// CHECK IF POSITION IS SAFE (not in fire/acid, not near tank punch)
// ------------------------------------------------------------------

function SurvivorAI::IsSafePosition(bot, pos, ctx)
{
    if (!pos || !this.IsValidNavPos(pos))
        return false
    
    // Check fire/acid
    if (MaoLib.NavUtils && "IsNearFire" in MaoLib.NavUtils)
    {
        if (MaoLib.NavUtils.IsNearFire(pos, 100))
            return false
    }
    else
    {
        // Fallback: manual fire check
        local inferno = null
        while (inferno = Entities.FindByClassnameWithin(inferno, "inferno", pos, 100))
        {
            if (inferno && inferno.IsValid())
                return false
        }
    }
    
    // Check tank proximity
    if (ctx && ctx.threats && ctx.threats.tank && ctx.threats.tank.IsValid())
    {
        local dist = (pos - ctx.threats.tank.GetOrigin()).Length()
        if (dist < this.TankDangerRange)
            return false
    }
    
    return true
}

// ------------------------------------------------------------------
// GET POSITION BEHIND TEAMMATE (for repositioning)
// ------------------------------------------------------------------

function SurvivorAI::GetPositionBehind(bot, target, distance)
{
    if (!target || !target.IsValid())
        return null
    
    local targetPos = target.GetOrigin()
    local botPos = bot.GetOrigin()
    
    // Direction from target to bot
    local dir = botPos - targetPos
    dir.z = 0
    local len = dir.Length()
    if (len > 0)
    {
        dir.x /= len
        dir.y /= len
    }
    else
    {
        dir = Vector(1, 0, 0)
    }
    
    local behindPos = targetPos + dir * distance
    return this.GetSafePosition(behindPos, 200)
}

// ------------------------------------------------------------------
// VALIDATE UNSTICK POSITION
// Ensure unstick position is valid and safe
// ------------------------------------------------------------------

function SurvivorAI::GetUnstickPosition(bot, ctx)
{
    local pos = bot.GetOrigin()
    local angles = [0, 90, 180, 270, 45, 135, 225, 315]
    
    foreach (angle in angles)
    {
        local rad = angle * PI / 180.0
        local dir = Vector(cos(rad), sin(rad), 0)
        local nudgePos = pos + dir * this.UnstickSearchRadius
        
        // Validate navmesh
        if (!this.IsValidNavPos(nudgePos))
            continue
        
        // Check safety
        if (!this.IsSafePosition(bot, nudgePos, ctx))
            continue
        
        // Don't nudge into tank or witch
        if (ctx && ctx.threats)
        {
            if (ctx.threats.tank && ctx.threats.tank.IsValid())
            {
                if ((nudgePos - ctx.threats.tank.GetOrigin()).Length() < 200)
                    continue
            }
            if (ctx.threats.witch && ctx.threats.witch.IsValid())
            {
                if ((nudgePos - ctx.threats.witch.GetOrigin()).Length() < 200)
                    continue
            }
        }
        
        return nudgePos
    }
    
    return null
}

printl("[SurvivorAI] validator.nut loaded")
