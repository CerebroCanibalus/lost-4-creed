ChCh_BleedSharps <-
{
    function OnGameEvent_player_hurt(params) { HandlePlayerHurt(params); }
    function OnGameEvent_infected_hurt(params) { HandleInfectedHurt(params); }

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
                            switch(activewep.GetModelName())
                            {
                                case "models/weapons/melee/v_fireaxe.mdl":
                                case "models/weapons/melee/w_fireaxe.mdl":
                                    HurtTheBastard(surv, special, params.dmg_health, Settings.Fireaxe_Damage)
                                    BleedEm(special, surv, 0)
                                    break;
                                case "models/weapons/melee/v_crowbar.mdl":
                                case "models/weapons/melee/w_crowbar.mdl":
                                    HurtTheBastard(surv, special, params.dmg_health, Settings.Crowbar_Damage)
                                    BleedEm(special, surv, 0)
                                    break;
                                case "models/weapons/melee/v_machete.mdl":
                                case "models/weapons/melee/w_machete.mdl":
                                    HurtTheBastard(surv, special, params.dmg_health, Settings.Machete_Damage)
                                    BleedEm(special, surv, 0)
                                    break;
                                case "models/v_models/v_knife_t.mdl":
                                case "models/w_models/weapons/w_knife_t.mdl":
                                    HurtTheBastard(surv, special, params.dmg_health, Settings.Knife_Damage)
                                    BleedEm(special, surv, 0)
                                    break;
                                case "models/weapons/melee/v_katana.mdl":
                                case "models/weapons/melee/w_katana.mdl":
                                    BleedEm(special, surv, 0)
                                    break;
                                case "models/weapons/melee/v_pitchfork.mdl":
                                case "models/weapons/melee/w_pitchfork.mdl": 
                                    HurtTheBastard(surv, special, params.dmg_health, Settings.Pitchfork_Damage)
                                    BleedEm(special, surv, 0)
                                    break;
                            }
                        }
                    }
                }
            }
        }
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
                            switch(activewep.GetModelName())
                            {
                                case "models/weapons/melee/v_fireaxe.mdl":
                                case "models/weapons/melee/w_fireaxe.mdl":
                                    HurtTheBastard(surv, zambie, params.amount, Settings.Fireaxe_Damage)
                                    BleedEm(zambie, surv, 0)
                                    break;
                                case "models/weapons/melee/v_crowbar.mdl":
                                case "models/weapons/melee/w_crowbar.mdl":
                                    HurtTheBastard(surv, zambie, params.amount, Settings.Crowbar_Damage)
                                    BleedEm(zambie, surv, 0)
                                    break;
                                case "models/weapons/melee/v_machete.mdl":
                                case "models/weapons/melee/w_machete.mdl":
                                    HurtTheBastard(surv, zambie, params.amount, Settings.Machete_Damage)
                                    BleedEm(zambie, surv, 0)
                                    break;
                                case "models/v_models/v_knife_t.mdl":
                                case "models/w_models/weapons/w_knife_t.mdl":
                                    HurtTheBastard(surv, zambie, params.amount, Settings.Knife_Damage)
                                    BleedEm(zambie, surv, 0)
                                    break;
                                case "models/weapons/melee/v_katana.mdl":
                                case "models/weapons/melee/w_katana.mdl":
                                    BleedEm(zambie, surv, 0)
                                    break;
                                case "models/weapons/melee/v_pitchfork.mdl":
                                case "models/weapons/melee/w_pitchfork.mdl": 
                                    HurtTheBastard(surv, zambie, params.amount, Settings.Pitchfork_Damage)
                                    BleedEm(zambie, surv, 0)
                                    break;
                            }
                        }
                    }
                }
            }
        }
    }

    function BleedEm(damagetaker, damagegiver, index)
    {
        if(NetProps.GetPropInt(damagetaker, "m_lifeState") == 0)
        {
            damagetaker.TakeDamage(Settings.BleedDamage, 131072, damagegiver)
            index++

            local bleedparticle = SpawnEntityFromTable("info_particle_system", { origin = damagetaker.GetOrigin() + Vector(0, 0, 40), angles = damagetaker.GetAngles().x.tostring() + " " + damagetaker.GetAngles().y.tostring() + " " + damagetaker.GetAngles().z.tostring(), effect_name = "blood_impact_headshot_01g", start_active = 1, flag_as_weather = 0})
            EntFire("worldspawn", "RunScriptCode", "EntIndexToHScript(" + bleedparticle.GetEntityIndex().tostring() + ").Kill()", 0.5, null)

            if(index < Settings.BleedTime * 2 && NetProps.GetPropInt(damagetaker, "m_lifeState") == 0)
            {
                EntFire("worldspawn", "runscriptcode", "ChCh_BleedSharps.BleedEm(EntIndexToHScript(" + damagetaker.GetEntityIndex() + "), GetPlayerFromUserID(" + damagegiver.GetPlayerUserId() + "), " + index + ")", 0.5, null)
            }
        }
    }

    Settings = 
    {
        Fireaxe_Damage = 500,
        Crowbar_Damage = 500,
        Machete_Damage = 500,
        Knife_Damage = 500,
        Pitchfork_Damage = 500,
        BleedTime = 10,
        BleedDamage = 5
    }

    function ParseSettings()
    {
        local SettingsFileName = "BleedSharps/Settings.cfg"
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

    function HurtTheBastard(whom, bastard, amount, dingle)
    {
        bastard.TakeDamage(dingle - amount, 131072, whom)
    }
}

__CollectGameEventCallbacks(ChCh_BleedSharps);
ChCh_BleedSharps.ParseSettings()