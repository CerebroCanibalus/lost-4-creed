ChCh_SlowSpecials <-
{
    Settings =
    {
        SlowType = 1,
        SlowAmount = 0.75,
    }

    function OnGameEvent_player_now_it( params )
    {
    	if("userid" in params)
        {
            if(params.userid)
            {
                local player = GetPlayerFromUserID(params.userid)

                if(!player.IsSurvivor())
                {
                    if(Settings.SlowType == 0)
                    {
                        NetProps.SetPropInt(player, "m_afButtonForced", NetProps.GetPropInt(player, "m_afButtonForced") | 131072 )
                    }
                    else
                    {
                        player.SetFriction(1 / Settings.SlowAmount)
                    }
                }
            }
        }
    }

    function OnGameEvent_player_no_longer_it( params )
    {
    	if("userid" in params)
        {
            if(params.userid)
            {
                local player = GetPlayerFromUserID(params.userid)

                if(!player.IsSurvivor())
                {
                    if(Settings.SlowType == 0)
                    {
                        NetProps.SetPropInt(player, "m_afButtonForced", NetProps.GetPropInt(player, "m_afButtonForced") & ~131072 )
                    }
                    else
                    {
                        player.SetFriction(1)
                    }
                }
            }
        }
    }

    function ParseSettings()
    {
        local SettingsFileName = "slowass_specials/Settings.cfg"
        local file = FileToString(SettingsFileName)
    
        local tData;
        local function SerializeSettings() {
            local sData = "{"
            foreach (key, val in Settings) {
                if (typeof(val) == "string") {
                    val = "\"" + val + "\""
                } else if (typeof(val) == "array") {
                    local newValue = "["
                    for (local i = 0; i < val.len(); i++) {
                        if (typeof(val[i]) == "string") {
                            newValue += "\"" + val[i] + "\""
                        } else {
                            newValue += val[i].tostring()
                        }
                        if (i < val.len() - 1) {
                            newValue += ", "
                        }
                    }
                    newValue += "]"
                    val = newValue
                }
                sData += "\n\t" + key + " = " + val
            }
            sData += "\n}"
            StringToFile(SettingsFileName, sData)
        }
        if (tData = file){
            try {
                tData = compilestring("return " + tData)()
                local hasMissingKey = false
                foreach (key, val in Settings){
                    if (key in tData){
                        Settings[key] = tData[key]
                    }
                    else if (!hasMissingKey){
                        hasMissingKey = true 
                    }
                }
                if (hasMissingKey)
                { SerializeSettings() }
            }
            catch (error) {
                SerializeSettings()
            }
        }
        else{
            SerializeSettings();
        }
    }
}

__CollectGameEventCallbacks(ChCh_SlowSpecials);
ChCh_SlowSpecials.ParseSettings()