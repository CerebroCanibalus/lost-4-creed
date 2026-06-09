MinigunGib <-
{
    function ApplyGib(what,who)
    	{
    		if(NetProps.GetPropInt(who, "m_iRequestedWound1") == -1)
    		{
    			NetProps.SetPropInt(who, "m_iRequestedWound1", what)
    		}
    		else if(NetProps.GetPropInt(who, "m_iRequestedWound2") == -1 && NetProps.GetPropInt(who, "m_iRequestedWound1") != what)
    		{
    			NetProps.SetPropInt(who, "m_iRequestedWound2", what)
    		}
    	}

    function OnGameEvent_infected_hurt( params )
    {
        HandleInfectedHurt( params );
    }

    function HandleInfectedHurt( params )
    {
        if("entityid" in params && "attacker" in params && "type" in params && "amount" in params)
        {
            if(params.entityid && params.attacker)
            {
				local common = EntIndexToHScript(params.entityid)
				local surv = GetPlayerFromUserID(params.attacker)
				local gender = NetProps.GetPropInt(common, "m_Gender")
				local type = params.type

				local badgenders = [14,15,17] //fallen, riot, jimmy
				if(badgenders.find(gender) == null) // Doesn't gib if an invalid common
				{
                    if(type == -2147483646 && NetProps.GetPropInt(surv, "m_usingMountedWeapon") == 1) 
                	{
                        if(gender == 11) //ceda
                	    {
                		    local gibs = [1,2,3,4,5,6,7,8,9]
                        	ApplyGib(gibs[RandomInt(0, gibs.len()-1)],common)
                        }
                        else if(gender == 15) //riot
                        {
                    	    local gibs = [3,4,5]
                            ApplyGib(gibs[RandomInt(0, gibs.len()-1)],common)
                    	}
                    	else
                    	{
                            local gibs = [22,23,24,25]
                	        ApplyGib(gibs[RandomInt(0, gibs.len()-1)],common)
            	   	 	}
         	        }
				}
			}
		}
    }
}


__CollectGameEventCallbacks(MinigunGib);