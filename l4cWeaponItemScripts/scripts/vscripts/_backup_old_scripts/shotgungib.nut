ShotgunGibCommons <-
{
    function ApplyGib(what,who) // The function for calling gibs, copied from Chimi, we consider it an abstract class of sorts.
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
            if(params.entityid && params.attacker) //Checks if there is even an attacker and target here
            {
				local common = EntIndexToHScript(params.entityid)
				local surv = GetPlayerFromUserID(params.attacker)
				local gender = NetProps.GetPropInt(common, "m_Gender")

				if(surv.IsSurvivor() && (surv.GetOrigin() - common.GetOrigin()).Length() < 100) // Checks if attacker is survivor and the magnitude from player to zombie
				{	
				    if((common.GetHealth() - params.amount) <= 0) // Checks if the zombie will die.
				    {
				    	local badgenders = [14,15,17] //fallen, riot, jimmy
				    	if(badgenders.find(gender) == null) // Doesn't gib if an invalid common
				    	{

                                    		if(params.type & 536870912) //Checks if buckshot + works with incendiary, thanks tomaz!
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
    }
}

__CollectGameEventCallbacks(ShotgunGibCommons);