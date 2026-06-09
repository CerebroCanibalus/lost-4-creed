Witch_SpecialMusic <-
{
    function OnGameEvent_lunge_pounce( params )
    {
        if("userid" in params)
        {
            if(params.userid)
            {    
                local hunter = GetPlayerFromUserID(params.userid)

                EmitSoundOnClient("Event.HunterPounce", hunter)
            }
        }
    }

    function OnGameEvent_pounce_end( params )
    {
        if("userid" in params)
        {
            if(params.userid)
            {    
                local hunter = GetPlayerFromUserID(params.userid)

                StopSoundOn("Event.HunterPounce", hunter)
            }
        }
    }

    function OnGameEvent_pounce_stopped( params )
    {
        if("userid" in params)
        {
            if(params.userid)
            {    
                local hunter = GetPlayerFromUserID(params.userid)

                StopSoundOn("Event.HunterPounce", hunter)
            }
        }
    }

    function OnGameEvent_tongue_grab( params )
    {
        if("userid" in params)
        {
            if(params.userid)
            {    
                local smoker = GetPlayerFromUserID(params.userid)

                EmitSoundOnClient("Event.SmokerDrag", smoker)
            }
        }
    }

    function OnGameEvent_choke_start( params )
    {
        if("userid" in params)
        {
            if(params.userid)
            {    
                local smoker = GetPlayerFromUserID(params.userid)

                StopSoundOn("Event.SmokerDrag", smoker)
                EmitSoundOnClient("Event.SmokerChoke", smoker)
            }
        }
    }

    function OnGameEvent_tongue_release( params )
    {
        if("userid" in params)
        {
            if(params.userid)
            {    
                local smoker = GetPlayerFromUserID(params.userid)

                StopSoundOn("Event.SmokerDrag", smoker)
                StopSoundOn("Event.SmokerChoke", smoker)
            }
        }
    }

    function OnGameEvent_jockey_ride( params )
    {
        if("userid" in params)
        {
            if(params.userid)
            {    
                local jockey = GetPlayerFromUserID(params.userid)

                EmitSoundOnClient("Event.JockeyRide", jockey)
            }
        }
    }

    function OnGameEvent_jockey_ride_end( params )
    {
        if("userid" in params)
        {
            if(params.userid)
            {    
                local jockey = GetPlayerFromUserID(params.userid)

                StopSoundOn("Event.JockeyRide", jockey)
            }
        }
    }

    function OnGameEvent_charger_carry_start( params )
    {
        if("userid" in params)
        {
            if(params.userid)
            {    
                local charger = GetPlayerFromUserID(params.userid)

                EmitSoundOnClient("Event.ChargerSmash", charger)
            }
        }
    }

    function OnGameEvent_charger_pummel_start( params )
    {
        if("userid" in params)
        {
            if(params.userid)
            {    
                local charger = GetPlayerFromUserID(params.userid)

                EmitSoundOnClient("Event.ChargerSlam", charger)
            }
        }
    }

    function OnGameEvent_charger_pummel_end( params )
    {
        if("userid" in params)
        {
            if(params.userid)
            {    
                local charger = GetPlayerFromUserID(params.userid)

                StopSoundOn("Event.ChargerSlam", charger)
            }
        }
    }

    function OnGameEvent_mission_lost( params )
    {
        for (local player; player = Entities.FindByClassname(player, "player"); )
        {
            if(player.GetZombieType() == 1)
            {
                StopSoundOn("Event.SmokerDrag", player)
                StopSoundOn("Event.SmokerChoke", player)
            }
            if(player.GetZombieType() == 3)
            {
                StopSoundOn("Event.HunterPounce", player)
            }
            if(player.GetZombieType() == 5)
            {
                StopSoundOn("Event.JockeyRide", player)
            }
            if(player.GetZombieType() == 6)
            {
                StopSoundOn("Event.ChargerSlam", player)
            }
        }
    }

    function OnGameEvent_tank_spawn( params )
    {
        if("userid" in params)
        {
            if(params.userid)
            {    
                local tank = GetPlayerFromUserID(params.userid)

                StopSoundOn("Event.JockeyRide", tank)
                StopSoundOn("Event.ChargerSlam", tank)
                StopSoundOn("Event.HunterPounce", tank)
                StopSoundOn("Event.SmokerDrag", tank)
                StopSoundOn("Event.SmokerChoke", tank)
            }
        }
    }
}
__CollectGameEventCallbacks(Witch_SpecialMusic);