printl("faster reloads while adrenaline boosted")

ChCh_AdrenReloads <-
{
function HandleWeaponReload( params )
{
    if("userid" in params)
    {
        if(params.userid)
        {
            local player = GetPlayerFromUserID(params.userid)
            if (!player) return;
            local wep = player.GetActiveWeapon()
	    	if(wep && player.IsAdrenalineActive())
	    	{
                local newreloadtime = ((NetProps.GetPropFloat(wep, "m_flNextPrimaryAttack") - Time()) / 1.5) + Time()
                NetProps.SetPropFloat(wep, "m_flPlaybackRate", 1.5)
                NetProps.SetPropFloat(wep, "m_flNextPrimaryAttack", newreloadtime)
                NetProps.SetPropFloat(player, "m_flNextAttack", newreloadtime)
	    	}
        }
    }
}
}
function ChCh_AdrenReloads::OnGameEvent_weapon_reload(params) { ChCh_AdrenReloads.HandleWeaponReload(params); }
__CollectGameEventCallbacks(ChCh_AdrenReloads);