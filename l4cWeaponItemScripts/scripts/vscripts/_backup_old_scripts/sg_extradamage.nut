ChCh_SGZoomDMG <-
{
    function OnGameEvent_player_hurt( params )
    {
        HandlePlayerHurt( params );
    }

    function HandlePlayerHurt( params )
    {
    	if("userid" in params && "attacker" in params && "dmg_health" in params && "type" in params)
        {
            if(params.userid && params.attacker)
            {
                local special = GetPlayerFromUserID(params.userid)
                local surv = GetPlayerFromUserID(params.attacker)
                local type = params.type

                if(!special.IsSurvivor() && surv.IsSurvivor())
                {
                    if(type != 131072 && !(type == (type | 8)) && !(type == (type | 64)))
                    {
                        local activewep = surv.GetActiveWeapon()
                        if(activewep)
                        {
                            if(activewep.GetClassname() == "weapon_rifle_sg552" && NetProps.GetPropInt(surv, "m_hZoomOwner") != -1)
                            {
                                special.TakeDamage(params.dmg_health * 0.66, 131072, surv)
                            }
                        }
                    }
                }
            }
        }
    }

    function OnGameEvent_infected_hurt( params )
    {
        HandleInfectedHurt( params );
    }

    function HandleInfectedHurt( params )
    {
    	if("entityid" in params && "attacker" in params && "amount" in params && "type" in params)
        {
            if(params.entityid && params.attacker)
            {
                local zambie = EntIndexToHScript(params.entityid)
                local surv = GetPlayerFromUserID(params.attacker)
                local type = params.type

                if(surv.IsSurvivor())
                {
                    if(type != 131072 && !(type == (type | 8)) && !(type == (type | 64)))
                    {
                        local activewep = surv.GetActiveWeapon()
                        if(activewep)
                        {
                            if(activewep.GetClassname() == "weapon_rifle_sg552" && NetProps.GetPropInt(surv, "m_hZoomOwner") != -1)
                            {
                                zambie.TakeDamage(params.amount * 0.66, 131072, surv)
                            }
                        }
                    }
                }
            }
        }
    }
}

__CollectGameEventCallbacks(ChCh_SGZoomDMG);