ChCh_M60Staggorzz <-
{
    function OnGameEvent_player_hurt( params )
    {
        HandlePlayerHurt( params );
    }

    function HandlePlayerHurt( params )
    {
    	if("userid" in params && "attacker" in params && "weapon" in params)
        {
            if(params.userid && params.attacker)
            {
                local special = GetPlayerFromUserID(params.userid)
                local surv = GetPlayerFromUserID(params.attacker)

                if(!special.IsSurvivor() && surv.IsSurvivor())
                {
                    if(RandomInt(1, 100) <= 15 && params.weapon == "rifle_m60" && (special.GetZombieType() == 6 || special.GetZombieType() == 8))
                    {
                        special.Stagger(surv.GetOrigin())
                    }
                }
            }
        }
    }
}

__CollectGameEventCallbacks(ChCh_M60Staggorzz);