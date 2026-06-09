::OverdosePlayers <- {}  // Tracks pill counts per player
if (!("L4COV_MaxOverdosePillsLimit" in getroottable())) ::L4COV_MaxOverdosePillsLimit <- 5

::OverdosingAddon <-
{
    bActive = true,
    ////////////////////////////////////////////////////////////////
    // Called when a player uses a pill
    PlayerUsePills = function(UserId)
    {
        local player = GetPlayerFromUserID(UserId)
        if (player == null || !player.IsValid() || !player.IsSurvivor()) return

        if (!(UserId in ::OverdosePlayers))
        {
            ::OverdosePlayers.rawset(UserId, {count = 0, lastMaxHP = player.GetMaxHealth()})
        }

        local data = ::OverdosePlayers[UserId]
        data.count += 1

        // Prevent max health from going negative or below 1
        local newMax = data.lastMaxHP - 10
        if (newMax < 1) newMax = 1
        player.SetMaxHealth(newMax)

        // Sync current health down if it exceeds new max
        if (player.GetHealth() > player.GetMaxHealth())
        {
            player.SetHealth(player.GetMaxHealth())
        }

        if (data.count >= ::L4COV_MaxOverdosePillsLimit)
        {
            player.SetHealth(0) // Instantly kill without blood decals
            data.count = 0
            data.lastMaxHP = player.GetMaxHealth()
        }
        else
        {
            data.lastMaxHP = player.GetMaxHealth()
        }
    },

    OnGameEvent_pills_used = function(Event)
    {
        ::OverdosingAddon.PlayerUsePills(Event.userid)
    },

    OnGameEvent_player_death = function(Event)
    {
        ::OverdosingAddon.HandlePlayerDeath(Event)
    },

    HandlePlayerDeath = function(Event)
    {
        if ("userid" in Event && Event.userid in ::OverdosePlayers)
        {
            ::OverdosePlayers.rawdelete(Event.userid)
        }
    },

    OnGameEvent_round_end = function(Event)
    {
        // Clean up all overdose data on round end and stop the schedule loop
        ::OverdosingAddon.bActive = false
        ::OverdosePlayers.clear()
    },

    OnGameEvent_mission_lost = function(Event)
    {
        ::OverdosingAddon.bActive = false
        ::OverdosePlayers.clear()
    },

    ////////////////////////////////////////////////////////////////
    // Periodically update maxHP baseline for active survivors
    Start = function()
    {
        ::OverdosingAddon.bActive = true
        ::OverdosingAddon.ScheduleNextCheck()
    },

    ScheduleNextCheck = function()
    {
        if (::OverdosingAddon.bActive)
            MaoLib.AddTimer("OverdoseCheck", 7.5, function() { ::OverdosingAddon.CheckMaxHPLoop(); })
    },

    CheckMaxHPLoop = function()
    {
        foreach (id, data in ::OverdosePlayers)
        {
            local player = GetPlayerFromUserID(id)
            if (player == null || !player.IsValid() || NetProps.GetPropInt(player, "m_lifeState") != 0) continue

            // Refresh baseline max if it's higher than stored
            if (player.GetMaxHealth() > data.lastMaxHP)
            {
                data.lastMaxHP = player.GetMaxHealth()
            }
        }
        if (::OverdosingAddon.bActive)
        {
            ::OverdosingAddon.ScheduleNextCheck()
        }
    }
}

__CollectGameEventCallbacks(::OverdosingAddon);
::OverdosingAddon.Start()

printl("Overdose Pills System Active.")
