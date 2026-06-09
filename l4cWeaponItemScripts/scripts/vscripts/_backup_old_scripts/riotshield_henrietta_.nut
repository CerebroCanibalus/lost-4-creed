printl("Loaded RiotReduction" + "\n" + "By Solved/Devlos aka Timonenluca" + "\n" + "Commissioned by Henrietta")

HenriettaRiotReduction <- 
{
    Settings = {
        DamageReceived = 0.60
        DamageReceivedBehind = 1.3
        DamageTypes = [8 , 263168]
        Debug = false
    }

    OnIncapDamage = {
        tank_claw = [24 , 24 , 33 , 300]
        tank_rock = [24 , 24 , 33 , 33]
        charger_claw = [5 , 10 , 15 , 20]
        hunter_claw = [10 , 10 , 20 , 40]
        jockey_claw = [5 , 10 , 15 , 20]
        smoker_claw = [1 , 10 , 5 , 20]
        spitter_claw = [1 , 2 , 5 , 20]
        boomer_claw = [5 , 10 , 5 , 20]
        zombie = [1 , 2 , 5 , 20]
    }
    
    function ParseDurabilityConfig()
    {
        local SettingsFileName = "RiotReduction_Devlos/RiotShield_Settings.cfg"
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
                    else if(!hasMissingKey){
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

    function IsPositionInFieldOfView(ent, forwardVector, entpostocheck , ViewAngle){

        if(entpostocheck == null){
            return true
        }

        local positionToCheck = entpostocheck.GetOrigin()

        local origin = ent.GetOrigin()
        local localVector = positionToCheck - origin
    
        forwardVector.Norm()
        localVector.Norm()
    
        local dotProduct = forwardVector.Dot(localVector)
    
        local angleDegrees = acos(dotProduct) * 180 / PI
    
        if (abs(angleDegrees) <= ViewAngle / 2) {
            return true
        } else {
            return false
        }
    }

    function ApplyDamage(Victim , CurrentAttacker , TotalDamage , DamageType , Weapon , EarlyHealth , EarlyHealthBuffer){

        local FOVAmount = Convars.GetClientConvarValue("fov_desired", Victim.GetEntityIndex()).tointeger();
        local InView = IsPositionInFieldOfView(Victim , Victim.GetForwardVector() , CurrentAttacker , FOVAmount)

        local DamageReceived = Settings.DamageReceived
        local DamageReceivedBehind = Settings.DamageReceivedBehind
        
        
        local ReductionPercentage = DamageReceived > 1.0 ? 1.0 : (DamageReceived < 0 ? 0 : DamageReceived);
        local ReductionPercentageBehind = DamageReceivedBehind > 2.0 ? 2.0 : (DamageReceivedBehind < 1.0 ? 1.0 : DamageReceivedBehind);
        
        local TotalDamageR = TotalDamage * (1 - ReductionPercentage)
        local TotalDamageRBehind = TotalDamage * (1 - ReductionPercentageBehind)

        local TempHealth = (EarlyHealthBuffer - TotalDamage)
        local RealHealth = (EarlyHealth - TotalDamage)

        local AddHealth = null;
        local AddBuffer = null;

        if(InView){
            AddHealth = EarlyHealth+TotalDamageR
            AddBuffer = EarlyHealthBuffer+TotalDamageR
        }
        else if(!InView){
            AddHealth = EarlyHealth+TotalDamageRBehind
            AddBuffer = EarlyHealthBuffer+TotalDamageRBehind
        }
        
        if(RealHealth >= 0 && TempHealth >= 0){
            Victim.SetHealth(AddHealth)
        }
        else if(RealHealth <= 0 && TempHealth >= 0){
            Victim.SetHealthBuffer(AddBuffer)
        }
        else if(RealHealth >= 0 && TempHealth <= 0){
            Victim.SetHealth(AddHealth)
        }
        else{
            if(TempHealth > 0){
                Victim.SetHealthBuffer(AddBuffer)
            }
            else{
                Victim.SetHealth(AddHealth)
            }
        }
        
        if(Settings.Debug){
            printl(
                "Attacker: "+CurrentAttacker.GetClassname()+"\n"+
                "Weapon used: "+Weapon+"\n"+
                "TempHealth: "+TempHealth+"\n"+
                "RealHealth: "+RealHealth+"\n"+
                "DamageType: "+DamageType+"\n"+
                "Hit Infront: "+InView+"\n"+
                "Damage Originally Received: "+(TotalDamage)+"\n"+
                "Damage Received Front: "+(TotalDamage - TotalDamageR)+"\n"+
                "Damage Received Back: "+(TotalDamage - TotalDamageRBehind)+"\n"+
                "DamageReceived Value: "+DamageReceived+"\n"+
                "DamageReceivedBehind Value: "+DamageReceivedBehind
            )
        }
    }

    function OnGameEvent_player_hurt ( params ){
        HenriettaRiotReduction.HandlePlayerHurt(params);
    }

    function HandlePlayerHurt ( params ){

        if("userid" in params && "dmg_health" in params && "type" in params && "weapon" in params){

            local Victim = GetPlayerFromUserID( params.userid );
            if (!Victim) return;
            local TotalDamage = params.dmg_health;
            local DamageType = params.type;
            local Weapon = params.weapon

            local EarlyHealth = Victim.GetHealth()
            local EarlyHealthBuffer = Victim.GetHealthBuffer()

            local CurrentAttacker = null;

            if("attackerentid" in params){
                CurrentAttacker = EntIndexToHScript( params.attackerentid );
            }
            else if("attacker" in params){
                CurrentAttacker = GetPlayerFromUserID( params.attacker );
            }

            if(Victim != null && Victim.IsValid()){

                if(Victim.IsSurvivor()
                && !Victim.IsIncapacitated()
                && !Victim.IsDominatedBySpecialInfected()
                && !Victim.IsImmobilized()
                && Victim.GetActiveWeapon().GetModelName() == "models/weapons/melee/v_riotshield.mdl"){

                    if(Settings.DamageTypes.find(DamageType) == null){
                        ApplyDamage(Victim , CurrentAttacker , TotalDamage , DamageType , Weapon , EarlyHealth , EarlyHealthBuffer)
                    }
                }
            }
        }
    }
    function OnGameEvent_player_incapacitated_start ( params ){
        
        if("userid" in params && "type" in params){

            printl("INCAP")
            local Victim = GetPlayerFromUserID( params.userid );
            if (!Victim) return;
            local DamageType = params.type;

            local EarlyHealth = Victim.GetHealth()
            local EarlyHealthBuffer = Victim.GetHealthBuffer()

            local Weapon = null;
            local CurrentAttacker = null;

            if("weapon" in params){
                Weapon = params.weapon
            }

            if("attackerentid" in params){
                CurrentAttacker = EntIndexToHScript( params.attackerentid );
            }
            else if("attacker" in params){
                CurrentAttacker = GetPlayerFromUserID( params.attacker );
            }

            if(Victim != null && Victim.IsValid()){
                if(Victim.IsSurvivor()
                && !Victim.IsDominatedBySpecialInfected()
                && !Victim.IsImmobilized()
                && Victim.GetActiveWeapon().GetModelName() == "models/weapons/melee/v_riotshield.mdl"){

                    if(Settings.DamageTypes.find(DamageType) == null){
                        if(CurrentAttacker != null && CurrentAttacker.GetClassname() == "infected"){
                            ApplyDamage(Victim , CurrentAttacker , OnIncapDamage["zombie"][GetDifficulty()] , DamageType , Weapon , EarlyHealth , EarlyHealthBuffer)
                        }
                        else if(CurrentAttacker != null && CurrentAttacker.GetClassname() == "player"){
                            ApplyDamage(Victim , CurrentAttacker , OnIncapDamage[Weapon][GetDifficulty()] , DamageType , Weapon , EarlyHealth , EarlyHealthBuffer)
                        }
                    }
                }
            }
        }
    }
}
__CollectGameEventCallbacks(HenriettaRiotReduction);
HenriettaRiotReduction.ParseDurabilityConfig();