printl("reloading but you lose most of your ammo cause thats a fun game mechanic i should do that")

ChCh_RealReload <-
{
    function OnGameEvent_weapon_reload(params) 
    {
        if("userid" in params)
        {
            if(params.userid)
            {
                local player = GetPlayerFromUserID(params.userid)
                if (!player) return;
                local wep = player.GetActiveWeapon()
                if(wep)
                {
                    local badweps = ["weapon_autoshotgun", "weapon_chainsaw", "weapon_pumpshotgun", "weapon_shotgun_chrome", "weapon_shotgun_spas"]

                    if(badweps.find(wep.GetClassname()) == null)
                    {
                        local ammoleft = NetProps.GetPropIntArray(player, "m_iAmmo", NetProps.GetPropInt(wep, "m_iPrimaryAmmoType"))

                        //if(GetWhatever(wep) > 0)
                        //{
                        //    wep.SetClip1(1)
                        //}

                        if(ammoleft - GetWhatever(wep) > 0)
                        {
                            SetAmmoPls(player, wep, ammoleft - GetWhatever(wep))
                        }
                    }
                }
            }
        }
    }

    function GetWhatever(wep)
    {
        local clip = ResponseCriteria.GetValue(wep, "chch_currentclip")
        if(clip == "")
        {
            return 0
        }
        else
        {
            return clip.tointeger()
        }
    }

    function SetAmmoPls(ply, wep, how)
    {
        NetProps.SetPropIntArray(ply, "m_iAmmo", how, NetProps.GetPropInt(wep, "m_iPrimaryAmmoType"))
    }

    function OnGameEvent_weapon_fire(params) 
    {
        if("userid" in params)
        {
            if(params.userid)
            {
                local player = GetPlayerFromUserID(params.userid)
                if (!player) return;
                local wep = player.GetActiveWeapon()
                if(wep)
                {
                    //ole mate doesnt have a script scope
                    //printl(wep.GetScriptScope())
                    //wep.GetScriptScope()["chch_currentclip"] <- wep.Clip1()
                    //printl(wep.GetScriptScope()["chch_currentclip"])

                    wep.SetContext("chch_currentclip", (wep.Clip1() - 1).tostring(), -1)
                }
            }
        }
    }
}

__CollectEventCallbacks(ChCh_RealReload, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);