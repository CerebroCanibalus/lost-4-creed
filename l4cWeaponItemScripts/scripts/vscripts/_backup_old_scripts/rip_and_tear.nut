RipAndTear <-
{
    deadInfected = {}
    hitCount = {}

    function ApplyGib(what, who, woundNum = 0)
    {
        local wound1 = NetProps.GetPropInt(who, "m_iRequestedWound1")
        local wound2 = NetProps.GetPropInt(who, "m_iRequestedWound2")
        
        if (woundNum == 1 && wound1 == -1)
        {
            NetProps.SetPropInt(who, "m_iRequestedWound1", what)
        }
        else if (woundNum == 0)
        {
            NetProps.SetPropInt(who, "m_iRequestedWound1", what)
        }
    }

    function ResetWounds(who)
    {
        NetProps.SetPropInt(who, "m_iRequestedWound1", -1)
        NetProps.SetPropInt(who, "m_iRequestedWound2", -1)
    }

    function OnGameEvent_infected_hurt(params)
    {
        HandleInfectedHurt(params);
    }

    function HandleInfectedHurt(params)
    {
        if ("entityid" in params && "attacker" in params && "amount" in params)
        {
            local common = EntIndexToHScript(params.entityid)
            local surv = GetPlayerFromUserID(params.attacker)
            if (!common || !surv || !surv.IsSurvivor())
                return

            local health = common.GetHealth()
            local entityID = params.entityid

            if (health > 0 && (health - params.amount) <= 0)
            {
                local weapon = surv.GetActiveWeapon()
                if (weapon)
                {
                    local weaponClass = weapon.GetClassname()
                    if (weaponClass == "weapon_rifle_ak47" ||     // AK47
                        weaponClass == "weapon_rifle_sg552" ||    // SG552
                        weaponClass == "weapon_rifle" ||          // M16
                        weaponClass == "weapon_rifle_desert")     // Combat Rifle
                    {
                        ResetWounds(common)
                        deadInfected[entityID] <- Time()
                        hitCount[entityID] <- 0
                    }
                }
            }
        }
    }

    function CheckMagDump()
    {
        local surv = null
        local ent = null
        while (ent = Entities.FindByClassname(ent, "player"))
        {
            if (ent.IsSurvivor() && ent.IsValid())
            {
                local weapon = ent.GetActiveWeapon()
                if (weapon)
                {
                    local weaponClass = weapon.GetClassname()
                    if (weaponClass == "weapon_rifle_ak47" ||     // AK47
                        weaponClass == "weapon_rifle_sg552" ||    // SG552
                        weaponClass == "weapon_rifle" ||          // M16
                        weaponClass == "weapon_rifle_desert")     // Combat Rifle
                    {
                        surv = ent
                        break
                    }
                }
            }
        }

        if (surv && (NetProps.GetPropInt(surv, "m_nButtons") & (1 << 0)) != 0) // Firing
        {
            // Trace what�s being hit
            local eyePos = surv.EyePosition()
            local eyeAngles = surv.EyeAngles()
            local trace = { start = eyePos, end = eyePos + VectorFromQAngle(eyeAngles, 1000.0), ignore = surv, mask = 0x4600400B } // MASK_SHOT
            TraceLine(trace)

            if (trace.hit && trace.enthit && trace.enthit.GetClassname() == "infected")
            {
                local hitEntity = trace.enthit
                local entityID = hitEntity.GetEntityIndex()

                if (entityID in deadInfected) // Only count hits on tracked dead infected
                {
                    local deathTime = deadInfected[entityID]
                    local timeSinceDeath = Time() - deathTime

                    if (timeSinceDeath > 0.1 && timeSinceDeath <= 3.0)
                    {
                        hitCount[entityID] <- hitCount[entityID] + 1
                        local gender = NetProps.GetPropInt(hitEntity, "m_Gender")
                        local badgenders = [14, 15, 17]

                        if (badgenders.find(gender) == null)
                        {
                            if (hitCount[entityID] == 2)
                            {
                                if (gender == 11)
                                    ApplyGib(3, hitEntity, 1)
                                else if (gender == 15)
                                    ApplyGib(3, hitEntity, 1)
                                else
                                    ApplyGib(22, hitEntity, 1)
                            }
                            else if (hitCount[entityID] >= 13)
                            {
                                if (RandomFloat(0.0, 1.0) <= 0.5)
                                {
                                    if (gender == 11)
                                    {
                                        local gibs = [1, 2, 4, 5, 6, 7, 8, 9]
                                        ApplyGib(gibs[RandomInt(0, gibs.len() - 1)], hitEntity, 0)
                                    }
                                    else if (gender == 15)
                                    {
                                        local gibs = [4, 5]
                                        ApplyGib(gibs[RandomInt(0, gibs.len() - 1)], hitEntity, 0)
                                    }
                                    else
                                    {
                                        local gibs = [23, 24, 25]
                                        ApplyGib(gibs[RandomInt(0, gibs.len() - 1)], hitEntity, 0)
                                    }
                                    delete deadInfected[entityID]
                                    delete hitCount[entityID]
                                }
                            }
                        }
                    }
                    else if (timeSinceDeath > 3.0)
                    {
                        delete deadInfected[entityID]
                        delete hitCount[entityID]
                    }
                }
            }
        }

        // Cleanup expired entries
        foreach (entityID, deathTime in deadInfected)
        {
            if (Time() - deathTime > 3.0)
            {
                delete deadInfected[entityID]
                delete hitCount[entityID]
            }
        }

        EntFire("worldspawn", "RunScriptCode", "RipAndTear.CheckMagDump()", 0.1)
    }
}

function VectorFromQAngle(angles, radius)
{
    local pitch = angles.x * -1 * (3.14159 / 180)
    local yaw = angles.y * (3.14159 / 180)
    local tmp = radius * cos(pitch)
    return Vector(tmp * cos(yaw), tmp * sin(yaw), radius * sin(pitch))
}

EntFire("worldspawn", "RunScriptCode", "RipAndTear.CheckMagDump()", 0.1)
__CollectGameEventCallbacks(RipAndTear);