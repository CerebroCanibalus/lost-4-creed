printl("Breakable melees")

PrecacheSound("weapons/axe/axe_break.wav")
PrecacheSound("weapons/pan/pan_break.wav")

PrecacheSound("physics/metal/fireaxe_impact1.wav")
PrecacheSound("physics/metal/fireaxe_impact2.wav")
PrecacheSound("physics/metal/fireaxe_impact3.wav")
PrecacheSound("physics/metal/fireaxe_impact4.wav")

PrecacheSound("physics/metal/golfclub_impact1.wav")
PrecacheSound("physics/metal/golfclub_impact2.wav")
PrecacheSound("physics/metal/golfclub_impact3.wav")
PrecacheSound("physics/metal/golfclub_impact4.wav")

PrecacheSound("physics/metal/blade_impact_hard1.wav")
PrecacheSound("physics/metal/blade_impact_hard2.wav")
PrecacheSound("physics/metal/blade_impact_hard3.wav")
PrecacheSound("physics/metal/blade_impact_hard4.wav")

IncludeScript("response_testbed", this)

meleebreaking <-
{
meleeDurabilites = 
{
    fireaxe = 30,
    fryingpan = 45,
    machete = 40,
    baseballbat = 35,
    crowbar = 20,
    cricketbat = 35,
    baton = 30,
    katana = 75,
    guitar = 50,
    knife = 20,
    golfclub = 40,
    pitchfork = 100, //based gg
    shovel = 60,
    defaultwep = 50
}

Settings = 
{
    givepistol = 1,
    vocaliselines = 0,
    textlines = 1
}

PickedMelees = {}

function HandleItemPickup( params )
{
    if("userid" in params && "item" in params)
    {
        local player = GetPlayerFromUserID(params.userid)

        if(params.item == "melee" && player.IsSurvivor())
        {
            local invTable = {}

            GetInvTable(player,invTable) 

            if("slot1" in invTable)
            {
                if(invTable.slot1.GetClassname() != "weapon_chainsaw")
                {
                if(PickedMelees.rawin(invTable.slot1) == false)
                {
                    if(invTable.slot1.Clip1() == -1)
                    {
                        invTable.slot1.SetClip1(GetMeleeDur(invTable.slot1)) 
                        PickedMelees.rawset(invTable.slot1,invTable.slot1.Clip1())
                    }
                }
                }
            }
        }
    }
}

function HandleFriendlyFire( params )
{ 
    if("guilty" in params)
    {
        local player = GetPlayerFromUserID(params.guilty)

        if(player.IsSurvivor())
        {
            local invTable = {}

            GetInvTable(player,invTable) 
            
            if("slot1" in invTable)
            {
                if(invTable.slot1.GetClassname() == "weapon_melee")
                {
                foreach(key,val in PickedMelees)
                {
                    if(invTable.slot1 == key)
                    {
                        TakeDurabilityReal(invTable.slot1,1,player)
                    }
                }
                }
            }
        }
    }
}

function HandleInfectedHurt( params )
{
    if("amount" in params && "attacker" in params && "type" in params)
    {
        local player = GetPlayerFromUserID(params.attacker)
        if(params.attacker)
        {
        if(player.IsSurvivor() && player.GetActiveWeapon().GetClassname() == "weapon_melee" && params.amount >= 1)
        {
            if(params.type == -2145386492 || params.type == 2097280)
            {
            foreach(key,val in PickedMelees)
            {
                if(player.GetActiveWeapon() == key)
                {
                    TakeDurabilityReal(player.GetActiveWeapon(),1,player)
                }
            }
            }
        }
        }
    }
}

function HandlePlayerHurt( params )
{
    if("userid" in params && "attackerentid" in params && "weapon" in params)
    {
        local player = EntIndexToHScript(params.attackerentid)
        local special = GetPlayerFromUserID(params.userid)

        if(params.attackerentid)
        {
        if(player.GetClassname() == "player")
        {
        if(player.IsSurvivor() && !special.IsSurvivor() && params.weapon == "melee" && params.dmg_health >= 2 && params.dmg_health < 3000) //fix tank death eating melees
        {
            local invTable = {}

            GetInvTable(player,invTable) 
            
            if("slot1" in invTable)
            {
                foreach(key,val in PickedMelees)
                {
                    if(invTable.slot1 == key)
                    {
                        if(special.GetZombieType() <= 7)
                        {
                            TakeDurabilityReal(invTable.slot1,1,player)
                        }
                        else
                        {
                            TakeDurabilityReal(invTable.slot1,RandomInt(1,2),player)
                        }
                    }
                }
            }
        }
        }
        }
    }
}

function ReturnDurability(wep)
{
    foreach(key,val in PickedMelees)
    {
        if(key == wep)
        {
            return val
        } 
    }
}

function SetDurability(wep)
{
    foreach(key,val in PickedMelees)
    {
        if(key == wep)
        {
            val = wep.Clip1()
        } 
    }
}

function GetMeleeDur(wep) //else if statement moment
{
//    local type = NetProps.GetPropInt( wep, "m_hMeleeWeaponInfo" )
    local type = wep.GetModelName()

    if(type == "models/weapons/melee/v_fireaxe.mdl")
    {
        return meleeDurabilites.fireaxe
    }
    else if(type == "models/weapons/melee/v_frying_pan.mdl")
    {
        return meleeDurabilites.fryingpan
    }
    else if(type == "models/weapons/melee/v_machete.mdl")
    {
        return meleeDurabilites.machete
    }
    else if(type == "models/weapons/melee/v_bat.mdl")
    {
        return meleeDurabilites.baseballbat
    }
    else if(type == "models/weapons/melee/v_crowbar.mdl")
    {
        return meleeDurabilites.crowbar
    }
    else if(type == "models/weapons/melee/v_cricket_bat.mdl")
    {
        return meleeDurabilites.cricketbat
    }
    else if(type == "models/weapons/melee/v_tonfa.mdl")
    {
        return meleeDurabilites.baton
    }
    else if(type == "models/weapons/melee/v_katana.mdl")
    {
        return meleeDurabilites.katana
    }
    else if(type == "models/weapons/melee/v_electric_guitar.mdl")
    {
        return meleeDurabilites.guitar
    }
    else if(type == "models/v_models/v_knife_t.mdl")
    {
        return meleeDurabilites.knife
    }
    else if(type == "models/weapons/melee/v_golfclub.mdl")
    {
        return meleeDurabilites.golfclub
    }
    else if(type == "models/weapons/melee/v_pitchfork.mdl")
    {
        return meleeDurabilites.pitchfork
    }
    else if(type == "models/weapons/melee/v_shovel.mdl")
    {
        return meleeDurabilites.shovel
    }
    else
    {
        return meleeDurabilites.defaultwep
    }
}

function GetMeleeBreakSound(wep) //else if statement moment 2
{
    local type = wep.GetModelName()

    if(type == "models/weapons/melee/v_fireaxe.mdl")
    {
        return "weapons/axe/axe_break.wav"
    }
    else if(type == "models/weapons/melee/v_frying_pan.mdl")
    {
        return "weapons/pan/pan_break.wav"
    }
    else if(type == "models/weapons/melee/v_machete.mdl")
    {
        return "weapons/axe/axe_break.wav"
    }
    else if(type == "models/weapons/melee/w_bat.mdl")
    {
        return "weapons/axe/axe_break.wav"
    }
    else if(type == "models/weapons/melee/w_crowbar.mdl")
    {
        return "weapons/pan/pan_break.wav"
    }
    else if(type == "models/weapons/melee/v_cricket_bat.mdl")
    {
        return "weapons/axe/axe_break.wav"
    }
    else if(type == "models/weapons/melee/v_tonfa.mdl")
    {
        return "weapons/axe/axe_break.wav"
    }
    else if(type == "models/weapons/melee/v_katana.mdl")
    {
        return "weapons/pan/pan_break.wav"
    }
    else if(type == "models/weapons/melee/v_electric_guitar.mdl")
    {
        return "weapons/pan/pan_break.wav"
    }
    else if(type == "models/v_models/v_knife_t.mdl")
    {
        return "weapons/axe/axe_break.wav"
    }
    else if(type == "models/weapons/melee/v_golfclub.mdl")
    {
        return "weapons/pan/pan_break.wav"
    }
    else if(type == "models/weapons/melee/v_pitchfork.mdl")
    {
        return "weapons/axe/axe_break.wav"
    }
    else if(type == "models/weapons/melee/v_shovel.mdl")
    {
        return "weapons/pan/pan_break.wav"
    }
    else
    {
        if(RandomInt(1, 2) == 1)
        {
            return "weapons/pan/pan_break.wav"
        }
        else
        {
            return "weapons/axe/axe_break.wav"
        }
    }
}

function GetMeleeHurtSound(wep) //else if statement moment 3: the final battle
{
    local type = wep.GetModelName()

    if(type == "models/weapons/melee/v_fireaxe.mdl")
    {
        local WhichOne = RandomInt(0,3)
        if(WhichOne == 0)
        {
            return "physics/metal/fireaxe_impact1.wav"
        }
        else if(WhichOne == 1)
        {
            return "physics/metal/fireaxe_impact2.wav"
        }
        else if(WhichOne == 2)
        {
            return "physics/metal/fireaxe_impact3.wav"
        }
        else if(WhichOne == 3)
        {
            return "physics/metal/fireaxe_impact4.wav"
        }
    }
    else if(type == "models/weapons/melee/v_frying_pan.mdl")
    {
        local WhichOne = RandomInt(0,3)
        if(WhichOne == 0)
        {
            return "physics/metal/golfclub_impact1.wav"
        }
        else if(WhichOne == 1)
        {
            return "physics/metal/golfclub_impact2.wav"
        }
        else if(WhichOne == 2)
        {
            return "physics/metal/golfclub_impact3.wav"
        }
        else if(WhichOne == 3)
        {
            return "physics/metal/golfclub_impact4.wav"
        }
    }
    else if(type == "models/weapons/melee/v_machete.mdl")
    {
        local WhichOne = RandomInt(0,3)
        if(WhichOne == 0)
        {
            return "physics/metal/blade_impact_hard1.wav"
        }
        else if(WhichOne == 1)
        {
            return "physics/metal/blade_impact_hard2.wav"
        }
        else if(WhichOne == 2)
        {
            return "physics/metal/blade_impact_hard3.wav"
        }
        else if(WhichOne == 3)
        {
            return "physics/metal/blade_impact_hard4.wav"
        }
    }
    else if(type == "models/weapons/melee/w_bat.mdl")
    {
        local WhichOne = RandomInt(0,3)
        if(WhichOne == 0)
        {
            return "physics/metal/fireaxe_impact1.wav"
        }
        else if(WhichOne == 1)
        {
            return "physics/metal/fireaxe_impact2.wav"
        }
        else if(WhichOne == 2)
        {
            return "physics/metal/fireaxe_impact3.wav"
        }
        else if(WhichOne == 3)
        {
            return "physics/metal/fireaxe_impact4.wav"
        }
    }
    else if(type == "models/weapons/melee/w_crowbar.mdl")
    {
        local WhichOne = RandomInt(0,3)
        if(WhichOne == 0)
        {
            return "physics/metal/golfclub_impact1.wav"
        }
        else if(WhichOne == 1)
        {
            return "physics/metal/golfclub_impact2.wav"
        }
        else if(WhichOne == 2)
        {
            return "physics/metal/golfclub_impact3.wav"
        }
        else if(WhichOne == 3)
        {
            return "physics/metal/golfclub_impact4.wav"
        }
    }
    else if(type == "models/weapons/melee/v_cricket_bat.mdl")
    {
        local WhichOne = RandomInt(0,3)
        if(WhichOne == 0)
        {
            return "physics/metal/fireaxe_impact1.wav"
        }
        else if(WhichOne == 1)
        {
            return "physics/metal/fireaxe_impact2.wav"
        }
        else if(WhichOne == 2)
        {
            return "physics/metal/fireaxe_impact3.wav"
        }
        else if(WhichOne == 3)
        {
            return "physics/metal/fireaxe_impact4.wav"
        }
    }
    else if(type == "models/weapons/melee/v_tonfa.mdl")
    {
        local WhichOne = RandomInt(0,3)
        if(WhichOne == 0)
        {
            return "physics/metal/fireaxe_impact1.wav"
        }
        else if(WhichOne == 1)
        {
            return "physics/metal/fireaxe_impact2.wav"
        }
        else if(WhichOne == 2)
        {
            return "physics/metal/fireaxe_impact3.wav"
        }
        else if(WhichOne == 3)
        {
            return "physics/metal/fireaxe_impact4.wav"
        }
    }
    else if(type == "models/weapons/melee/v_katana.mdl")
    {
        local WhichOne = RandomInt(0,3)
        if(WhichOne == 0)
        {
            return "physics/metal/blade_impact_hard1.wav"
        }
        else if(WhichOne == 1)
        {
            return "physics/metal/blade_impact_hard2.wav"
        }
        else if(WhichOne == 2)
        {
            return "physics/metal/blade_impact_hard3.wav"
        }
        else if(WhichOne == 3)
        {
            return "physics/metal/blade_impact_hard4.wav"
        }
    }
    else if(type == "models/weapons/melee/v_electric_guitar.mdl")
    {
        local WhichOne = RandomInt(0,3)
        if(WhichOne == 0)
        {
            return "physics/metal/fireaxe_impact1.wav"
        }
        else if(WhichOne == 1)
        {
            return "physics/metal/fireaxe_impact2.wav"
        }
        else if(WhichOne == 2)
        {
            return "physics/metal/fireaxe_impact3.wav"
        }
        else if(WhichOne == 3)
        {
            return "physics/metal/fireaxe_impact4.wav"
        }
    }
    else if(type == "models/v_models/v_knife_t.mdl")
    {
        local WhichOne = RandomInt(0,3)
        if(WhichOne == 0)
        {
            return "physics/metal/blade_impact_hard1.wav"
        }
        else if(WhichOne == 1)
        {
            return "physics/metal/blade_impact_hard2.wav"
        }
        else if(WhichOne == 2)
        {
            return "physics/metal/blade_impact_hard3.wav"
        }
        else if(WhichOne == 3)
        {
            return "physics/metal/blade_impact_hard4.wav"
        }
    }
    else if(type == "models/weapons/melee/v_golfclub.mdl")
    {
        local WhichOne = RandomInt(0,3)
        if(WhichOne == 0)
        {
            return "physics/metal/golfclub_impact1.wav"
        }
        else if(WhichOne == 1)
        {
            return "physics/metal/golfclub_impact2.wav"
        }
        else if(WhichOne == 2)
        {
            return "physics/metal/golfclub_impact3.wav"
        }
        else if(WhichOne == 3)
        {
            return "physics/metal/golfclub_impact4.wav"
        }
    }
    else if(type == "models/weapons/melee/v_pitchfork.mdl")
    {
        local WhichOne = RandomInt(0,3)
        if(WhichOne == 0)
        {
            return "physics/metal/golfclub_impact1.wav"
        }
        else if(WhichOne == 1)
        {
            return "physics/metal/golfclub_impact2.wav"
        }
        else if(WhichOne == 2)
        {
            return "physics/metal/golfclub_impact3.wav"
        }
        else if(WhichOne == 3)
        {
            return "physics/metal/golfclub_impact4.wav"
        }
    }
    else if(type == "models/weapons/melee/v_shovel.mdl")
    {
        local WhichOne = RandomInt(0,3)
        if(WhichOne == 0)
        {
            return "physics/metal/golfclub_impact1.wav"
        }
        else if(WhichOne == 1)
        {
            return "physics/metal/golfclub_impact2.wav"
        }
        else if(WhichOne == 2)
        {
            return "physics/metal/golfclub_impact3.wav"
        }
        else if(WhichOne == 3)
        {
            return "physics/metal/golfclub_impact4.wav"
        }
    }
    else
    {
        local WhichOne = RandomInt(0,3)
        if(WhichOne == 0)
        {
            return "physics/metal/blade_impact_hard1.wav"
        }
        else if(WhichOne == 1)
        {
            return "physics/metal/blade_impact_hard2.wav"
        }
        else if(WhichOne == 2)
        {
            return "physics/metal/fireaxe_impact1.wav"
        }
        else if(WhichOne == 3)
        {
            return "physics/metal/fireaxe_impact2.wav"
        }
    }
}
/*
function HurtDurMelee(who, wep)
{
    local tracestuff =
    {
        start = who.EyePosition(),
        end = who.GetForwardVector() * 999999,
        ignore = who
    }

    if(TraceLine(tracestuff))
    {
	    if(tracestuff.hit)
	    {
            if(tracestuff.enthit.GetClassname() == "player")
            {
            if(tracestuff.enthit.IsSurvivor())
            {
            for (local guy; guy = Entities.FindByClassnameWithin(guy, "player", tracestuff.enthit.GetOrigin(), Convars.GetFloat("melee_range")); )
            {
            if(guy == who)
            {
                TakeDurabilityReal(wep,1,who)
                SetDurability(wep)
            }   
            }
            }
            }
        }
    }
}*/

function TakeDurabilityReal(wep, how, who)
{
    if(wep.Clip1() - how <= -1)
    {
        KillMelee(who, wep)
    }
    else
    {
        wep.SetClip1(wep.Clip1() - how)
        SetDurability(wep)
        if(wep.Clip1() == abs(GetMeleeDur(wep) / 7))
        {
            if(Settings.textlines == 1)
            {
                ClientPrint(who, 3 , "\x01" + "You feel your melee getting quite flimsy...")
            }
            EmitAmbientSoundOn(GetMeleeHurtSound(wep), 1.0, 120, RandomInt(80,120), who)
        }
        if(wep.Clip1() == abs(GetMeleeDur(wep) / 16))
        {
            if(Settings.textlines == 1)
            {
                ClientPrint(who, 3 , "\x01" + "You feel your melee about to break...")
            }
            EmitAmbientSoundOn(GetMeleeHurtSound(wep), 1.0, 120, RandomInt(80,120), who)
        }
    } 
}


function KillMelee(who, wep)
{
//    NetProps.SetPropFloat(wep, "LocalActiveWeaponData.m_flNextPrimaryAttack", 999.9)
//	  NetProps.SetPropFloat(wep, "LocalActiveWeaponData.m_flNextSecondaryAttack", 999.9)
    wep.Kill()
    if(Settings.givepistol == 1)
    {
        who.GiveItem("weapon_pistol")
    }
    EmitAmbientSoundOn(GetMeleeBreakSound(wep), 1.0, 65, 100, who)
    if(Settings.vocaliselines == 1)
    {
        DoEntFire("!self", "SpeakResponseConcept", "ChCh_MeleeBreak", RandomFloat(0.3, 0.6), null, who)
    }
}

	function ParseDurabilityConfig()
	{
		local tData;

		local function SerializeSettings()
		{
			local sData = "{"
			foreach (key, val in meleeDurabilites)
			{
				sData = sData + "\n\t" + key + " = " + val
			}
			sData = sData + "\n}"
			StringToFile("BreakMelees/Durabilities.cfg", sData)
		}

		if (tData = FileToString("BreakMelees/Durabilities.cfg"))
		{
			try {
				tData = compilestring("return " + tData)()
				local hasMissingKey = false
				foreach (key, val in meleeDurabilites)
				{
					if (key in tData)
					{
						meleeDurabilites[key] = tData[key]
					}
					else if (!hasMissingKey)
					{ hasMissingKey = true }
				}
				if (hasMissingKey)
				{ SerializeSettings() }
			}
			catch (error) {
				SerializeSettings()
			}
		}
		else
		{
			SerializeSettings();
		}
	}

	function ParseSettings()
	{
		local tData;

		local function SerializeSettings()
		{
			local sData = "{"
			foreach (key, val in Settings)
			{
				sData = sData + "\n\t" + key + " = " + val + ","
			}
			sData = sData + "\n}"
			StringToFile("BreakMelees/Settings.cfg", sData)
		}

		if (tData = FileToString("BreakMelees/Settings.cfg"))
		{
			try {
				tData = compilestring("return " + tData)()
				local hasMissingKey = false
				foreach (key, val in Settings)
				{
					if (key in tData)
					{
						Settings[key] = tData[key]
					}
					else if (!hasMissingKey)
					{ hasMissingKey = true }
				}
				if (hasMissingKey)
				{ SerializeSettings() }
			}
			catch (error) {
				SerializeSettings()
			}
		}
		else
		{
			SerializeSettings();
		}
	}

	function OnGameEvent_item_pickup(params) { HandleItemPickup(params); }
	function OnGameEvent_friendly_fire(params) { HandleFriendlyFire(params); }
	function OnGameEvent_infected_hurt(params) { HandleInfectedHurt(params); }
	function OnGameEvent_player_hurt(params) { HandlePlayerHurt(params); }
}

__CollectGameEventCallbacks(meleebreaking);

meleebreaking.ParseDurabilityConfig()
meleebreaking.ParseSettings()

function IsTalkNick(query) 
{
    local player = null
	while( player = Entities.FindByClassname(player, "player") )
    {
        if(player.IsSurvivor() && NetProps.GetPropInt(player, "m_lifeState") == 0)
        {
            if(ResponseCriteria.GetValue(player, "TalkGambler") != "1")
            {
                return true
            }
            else
            {
                return false
            }
        }
    }
}

function IsTalkRo(query) 
{
    local player = null
	while( player = Entities.FindByClassname(player, "player") )
    {
        if(player.IsSurvivor() && NetProps.GetPropInt(player, "m_lifeState") == 0)
        {
            if(ResponseCriteria.GetValue(player, "TalkProducer") != "1")
            {
                return true
            }
            else
            {
                return false
            }
        }
    }
}

function IsTalkCoach(query) 
{
    local player = null
	while( player = Entities.FindByClassname(player, "player") )
    {
        if(player.IsSurvivor() && NetProps.GetPropInt(player, "m_lifeState") == 0)
        {
            if(ResponseCriteria.GetValue(player, "TalkCoach") != "1")
            {
                return true
            }
            else
            {
                return false
            }
        }
    }
}

function IsTalkEllis(query) 
{
    local player = null
	while( player = Entities.FindByClassname(player, "player") )
    {
        if(player.IsSurvivor() && NetProps.GetPropInt(player, "m_lifeState") == 0)
        {
            if(ResponseCriteria.GetValue(player, "TalkMechanic") != "1")
            {
                return true
            }
            else
            {
                return false
            }
        }
    }
}

function IsTalkNamvet(query) 
{
    local player = null
	while( player = Entities.FindByClassname(player, "player") )
    {
        if(player.IsSurvivor() && NetProps.GetPropInt(player, "m_lifeState") == 0)
        {
            if(ResponseCriteria.GetValue(player, "worldTalk") != "1")
            {
                if(ResponseCriteria.GetValue(player, "TalkNamvet") != "1")
                {
                    return true
                }
            }
            else
            {
                return false
            }
        }
    }
}

function IsTalkTeenGirl(query) 
{
    local player = null
	while( player = Entities.FindByClassname(player, "player") )
    {
        if(player.IsSurvivor() && NetProps.GetPropInt(player, "m_lifeState") == 0)
        {
            if(ResponseCriteria.GetValue(player, "worldTalk") != "1")
            {
                if(ResponseCriteria.GetValue(player, "TalkTeenGirl") != "1")
                {
                    return true
                }
            }
            else
            {
                return false
            }
        }
    }
}

function IsTalkManager(query) 
{
    local player = null
	while( player = Entities.FindByClassname(player, "player") )
    {
        if(player.IsSurvivor() && NetProps.GetPropInt(player, "m_lifeState") == 0)
        {
            if(ResponseCriteria.GetValue(player, "worldTalk") != "1")
            {
                if(ResponseCriteria.GetValue(player, "TalkManager") != "1")
                {
                    return true
                }
            }
            else
            {
                return false
            }
        }
    }
}

function IsTalkBiker(query) 
{
    local player = null
	while( player = Entities.FindByClassname(player, "player") )
    {
        if(player.IsSurvivor() && NetProps.GetPropInt(player, "m_lifeState") == 0)
        {
            if(ResponseCriteria.GetValue(player, "worldTalk") != "1")
            {
                if(ResponseCriteria.GetValue(player, "TalkBiker") != "1")
                {
                    return true
                }
            }
            else
            {
                return false
            }
        }
    }
}

local newrules =
[
	{
		name = "ChCh_MeleeBreakGambler",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Gambler" ],
			[ "InCombatMusic", 0 ],
            [ IsTalkNick ],
		],
		responses =
		[
            {   scenename = "scenes/Gambler/ReactionNegative02.vcd",   }  //Damn...
            {   scenename = "scenes/Gambler/ReactionNegative03.vcd",   }  //Shit!
            {   scenename = "scenes/Gambler/ReactionNegative04.vcd",   }  //God damn it.
            {   scenename = "scenes/Gambler/ReactionNegative05.vcd",   }  //Bullshit!
            {   scenename = "scenes/Gambler/ReactionNegative08.vcd",   }  //Ah, tits!
            {   scenename = "scenes/Gambler/ReactionNegative09.vcd",   }  //Son of a bitch.
            {   scenename = "scenes/Gambler/ReactionNegative10.vcd",   }  //Son of a bitch.
            {   scenename = "scenes/Gambler/ReactionNegative11.vcd",   }  //Oh bullshit!
            {   scenename = "scenes/Gambler/ReactionNegative15.vcd",   }  //Shit!
            {   scenename = "scenes/Gambler/ReactionNegative16.vcd",   }  //God damn it.
            {   scenename = "scenes/Gambler/ReactionNegative17.vcd",   }  //Bullshit!
            {   scenename = "scenes/Gambler/ReactionNegative19.vcd",   }  //Shit!
            {   scenename = "scenes/Gambler/ReactionNegative21.vcd",   }  //Son of a bitch.
            {   scenename = "scenes/Gambler/ReactionNegative22.vcd",   }  //Oh bullshit!
            {   scenename = "scenes/Gambler/ReactionNegative23.vcd",   }  //My ass.
            {   scenename = "scenes/Gambler/ReactionNegative24.vcd",   }  //Is this some kind of sick joke?
            {   scenename = "scenes/Gambler/ReactionNegative34.vcd",   }  //Screw this.
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakRespGambler",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreakResp" ],
			[ "who", "Gambler" ],
			[ "InCombatMusic", 0 ],
            [ "healthfrac" 0.5,1 ],
            [ IsTalkNick ],
		],
		responses =
		[
            {   scenename = "scenes/Gambler/DLC1_C6M3_SafeRoomConvo10.vcd", speakonce = true, odds = 25  }  //What are you nervous about? You had your chance, you didn't do shit. Now you can watch Nick take care of business.
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakProducer",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Producer" ],
			[ "InCombatMusic", 0 ],
            [ IsTalkRo ],
		],
		responses =
		[
            {   scenename = "scenes/Producer/ReactionNegative02.vcd",   }  //Damnn...
            {   scenename = "scenes/Producer/ReactionNegative04.vcd",   }  //Oh shit!
            {   scenename = "scenes/Producer/ReactionNegative05.vcd",   }  //Sweet Jesus!
            {   scenename = "scenes/Producer/ReactionNegative06.vcd",   }  //Sweet Lincoln's mullet!
            {   scenename = "scenes/Producer/ReactionNegative08.vcd",   }  //Mother of Mercy.
            {   scenename = "scenes/Producer/ReactionNegative09.vcd",   }  //Well this just sucks.
            {   scenename = "scenes/Producer/ReactionNegative10.vcd",   }  //Blarg!
            {   scenename = "scenes/Producer/ReactionNegative16.vcd",   }  //We do not have time for this shit.
            {   scenename = "scenes/Producer/ReactionNegative17.vcd",   }  //We don't have time for this shit.
            {   scenename = "scenes/Producer/ReactionNegative18.vcd",   }  //Goddamnit!
            {   scenename = "scenes/Producer/ReactionNegative19.vcd",   }  //Can just one more goddamn thing go wrong?
            {   scenename = "scenes/Producer/ReactionNegative20.vcd",   }  //Argghh! (disgusted)
            {   scenename = "scenes/Producer/GettingRevived21.vcd",   }  //Broke.
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakCoach",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Coach" ],
			[ "InCombatMusic", 0 ],
            [ IsTalkCoach ],
		],
		responses =
		[
            {   scenename = "scenes/Coach/ReactionNegative01.vcd",   }  //Shit.
            {   scenename = "scenes/Coach/ReactionNegative02.vcd",   }  //What the f-
            {   scenename = "scenes/Coach/ReactionNegative03.vcd",   }  //Damn!
            {   scenename = "scenes/Coach/ReactionNegative06.vcd",   }  //Hell no.
            {   scenename = "scenes/Coach/ReactionNegative07.vcd",   }  //hhhhhhh [frustrated]
            {   scenename = "scenes/Coach/ReactionNegative08.vcd",   }  //Goddamnit!
            {   scenename = "scenes/Coach/ReactionNegative09.vcd",   }  //Shiiit.
            {   scenename = "scenes/Coach/ReactionNegative10.vcd",   }  //Shiiit.
            {   scenename = "scenes/Coach/ReactionNegative11.vcd",   }  //What the? hhhhhhh [frustrated]
            {   scenename = "scenes/Coach/ReactionNegative12.vcd",   }  //Bullshit.
            {   scenename = "scenes/Coach/ReactionNegative14.vcd",   }  //Bullshit.
            {   scenename = "scenes/Coach/ReactionNegative15.vcd",   }  //Goddamn!
            {   scenename = "scenes/Coach/ReactionNegative16.vcd",   }  //Son of a bitch.
            {   scenename = "scenes/Coach/ReactionNegative17.vcd",   }  //Son of a bitch.
            {   scenename = "scenes/Coach/ReactionNegative18.vcd",   }  //Goddamn!
            {   scenename = "scenes/Coach/ReactionNegative20.vcd",   }  //Bullshit.
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakMechanic",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Mechanic" ],
			[ "InCombatMusic", 0 ],
            [ IsTalkEllis ],
		],
		responses =
		[
            {   scenename = "scenes/Mechanic/ReactionNegative01.vcd", followup = RThen( "Gambler",  "ChCh_MeleeBreakResp", {additionalcontext="null"}, 0.1 )  }  //No!
            {   scenename = "scenes/Mechanic/ReactionNegative02.vcd", followup = RThen( "Gambler",  "ChCh_MeleeBreakResp", {additionalcontext="null"}, 0.1 )  }  //Ahh SHIT!
            {   scenename = "scenes/Mechanic/ReactionNegative03.vcd", followup = RThen( "Gambler",  "ChCh_MeleeBreakResp", {additionalcontext="null"}, 0.1 )  }  //God DAMN!
            {   scenename = "scenes/Mechanic/ReactionNegative04.vcd", followup = RThen( "Gambler",  "ChCh_MeleeBreakResp", {additionalcontext="null"}, 0.1 )  }  //Ah Lord!
            {   scenename = "scenes/Mechanic/ReactionNegative07.vcd", followup = RThen( "Gambler",  "ChCh_MeleeBreakResp", {additionalcontext="null"}, 0.1 )  }  //Oh SHIT!
            {   scenename = "scenes/Mechanic/ReactionNegative08.vcd", followup = RThen( "Gambler",  "ChCh_MeleeBreakResp", {additionalcontext="null"}, 0.1 )  }  //God DAMN!
            {   scenename = "scenes/Mechanic/ReactionNegative12.vcd", followup = RThen( "Gambler",  "ChCh_MeleeBreakResp", {additionalcontext="null"}, 0.1 )  }  //BULLSHIT!
            {   scenename = "scenes/Mechanic/ReactionNegative13.vcd", followup = RThen( "Gambler",  "ChCh_MeleeBreakResp", {additionalcontext="null"}, 0.1 )  }  //Oh, hogwash, man!
            {   scenename = "scenes/Mechanic/ReactionNegative14.vcd", followup = RThen( "Gambler",  "ChCh_MeleeBreakResp", {additionalcontext="null"}, 0.1 )  }  //Well piss!
            {   scenename = "scenes/Mechanic/ReactionNegative15.vcd", followup = RThen( "Gambler",  "ChCh_MeleeBreakResp", {additionalcontext="null"}, 0.1 )  }  //Hogwash!
            {   scenename = "scenes/Mechanic/ReactionNegative16.vcd", followup = RThen( "Gambler",  "ChCh_MeleeBreakResp", {additionalcontext="null"}, 0.1 )  }  //Ain't that a load of shit.
            {   scenename = "scenes/Mechanic/ReactionNegative17.vcd", followup = RThen( "Gambler",  "ChCh_MeleeBreakResp", {additionalcontext="null"}, 0.1 )  }  //That's bullshit!
            {   scenename = "scenes/Mechanic/ReactionNegative18.vcd", followup = RThen( "Gambler",  "ChCh_MeleeBreakResp", {additionalcontext="null"}, 0.1 )  }  //Hogwash!
            {   scenename = "scenes/Mechanic/ReactionNegative20.vcd", followup = RThen( "Gambler",  "ChCh_MeleeBreakResp", {additionalcontext="null"}, 0.1 )  }  //Ain't that a load of shit.
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakNamvet",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Namvet" ],
			[ "InCombatMusic", 0 ],
            [ IsTalkNamvet ],
		],
		responses =
		[
            {   scenename = "scenes/NamVet/Swears03.vcd",   }  //
            {   scenename = "scenes/NamVet/Swears04.vcd",   }  //
            {   scenename = "scenes/NamVet/Swears05.vcd",   }  //
            {   scenename = "scenes/NamVet/Swears07.vcd",   }  //
            {   scenename = "scenes/NamVet/Swears08.vcd",   }  //
            {   scenename = "scenes/NamVet/Swears09.vcd",   }  //
            {   scenename = "scenes/NamVet/Swears10.vcd",   }  //
            {   scenename = "scenes/NamVet/Swears12.vcd",   }  //
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakTeengirl",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Teengirl" ],
			[ "InCombatMusic", 0 ],
            [ IsTalkTeenGirl ],
		],
		responses =
		[
            {   scenename = "scenes/TeenGirl/ReactionNegative01.vcd",   }  //Uh oh
            {   scenename = "scenes/TeenGirl/ReactionNegative03.vcd",   }  //This sucks
            {   scenename = "scenes/TeenGirl/ReactionNegative04.vcd",   }  //This sucks big time
            {   scenename = "scenes/TeenGirl/ReactionNegative06.vcd",   }  //This isn't working
            {   scenename = "scenes/TeenGirl/ReactionNegative11.vcd",   }  //Are you kidding me?
            {   scenename = "scenes/TeenGirl/ReactionNegative12.vcd",   }  //Not again
            {   scenename = "scenes/TeenGirl/ReactionNegative15.vcd",   }  //This is not going well
            {   scenename = "scenes/TeenGirl/ReactionNegative18.vcd",   }  //This sucks
            {   scenename = "scenes/TeenGirl/ReactionNegative19.vcd",   }  //This sucks big time
            {   scenename = "scenes/TeenGirl/ReactionNegative25.vcd",   }  //Crap
            {   scenename = "scenes/TeenGirl/ReactionNegative26.vcd",   }  //No No No No NO
            {   scenename = "scenes/TeenGirl/ReactionNegative33.vcd",   }  //Ah crap!
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakManager",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Manager" ],
			[ "InCombatMusic", 0 ],
            [ IsTalkManager ],
		],
		responses =
		[
            {   scenename = "scenes/Manager/Swears02.vcd",   }  //Dammit.
            {   scenename = "scenes/Manager/Swears03.vcd",   }  //Aw hell.
            {   scenename = "scenes/Manager/Swears05.vcd",   }  //Shit.
            {   scenename = "scenes/Manager/Swears06.vcd",   }  //Ah shit.
            {   scenename = "scenes/Manager/Swears10.vcd",   }  //Dammit.
            {   scenename = "scenes/Manager/Swears11.vcd",   }  //Aw hell.
            {   scenename = "scenes/Manager/Swears12.vcd",   }  //Shit.
            {   scenename = "scenes/Manager/Swears13.vcd",   }  //Ah shit.
            {   scenename = "scenes/Manager/Swears16.vcd",   }  //That's some country-ass bullshit.
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakBiker",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Biker" ],
			[ "InCombatMusic", 0 ],
            [ IsTalkBiker ],
		],
		responses =
		[
            {   scenename = "scenes/Biker/ReactionNegative04.vcd",   }  //Holy Jesus.
            {   scenename = "scenes/Biker/ReactionNegative05.vcd",   }  //Shit.
            {   scenename = "scenes/Biker/ReactionNegative06.vcd",   }  //Ah shit.
            {   scenename = "scenes/Biker/ReactionNegative09.vcd",   }  //Ahhhhh.
            {   scenename = "scenes/Biker/ReactionNegative07.vcd",   }  //Damnit.
            {   scenename = "scenes/Biker/ReactionNegative08.vcd",   }  //Damnit.
            {   scenename = "scenes/Biker/ReactionNegative10.vcd",   }  //Effin hell.
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakCombatGambler",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Gambler" ],
			[ "InCombatMusic", 1 ],
            [ IsTalkNick ],
		],
		responses =
		[
         {   scenename = "scenes/Gambler/DoubleDeathResponse03.vcd",   }  //Ahhh SHIT!
         {   scenename = "scenes/Gambler/GrabbedBySmoker01b.vcd",   }  //NO!!!!!!!!
         {   scenename = "scenes/Gambler/ReactionNegative25.vcd",   } //Is this some kind of sick joke?
         {   scenename = "scenes/Gambler/WorldC5M4B06.vcd",   }  //SHIT!
         {   scenename = "scenes/Gambler/WorldC5M4B07.vcd",   } //SHIT!
         {   scenename = "scenes/Gambler/World219.vcd",   }  //WHAT THE -  (reaction to bombing)
         {   scenename = "scenes/Gambler/BoomerReaction01.vcd",   }  //Ohh god damn it!
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakCombatProducer",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Producer" ],
			[ "InCombatMusic", 1 ],
            [ IsTalkRo ],
		],
		responses =
		[
         {   scenename = "scenes/Producer/DLC1_C6M1_WeddingWitchAttacking01.vcd",   }  //NOT AGAIN!
         {   scenename = "scenes/Producer/DLC1_C6M1_WeddingWitchAttacking02.vcd",   }  //UGH, NOT AGAIN!
         {   scenename = "scenes/Producer/GrabbedBySmoker04.vcd",   }  //no, No,  No, NO!!!!!!!!
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakCombatCoach",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Coach" ],
			[ "InCombatMusic", 1 ],
            [ IsTalkCoach ],
		],
		responses =
		[
         {   scenename = "scenes/Coach/Exclamation01.vcd",   }  //Oh Shit!
         {   scenename = "scenes/Coach/HeardTanklC102.vcd",   }  //Ahhh nooooo.
         {   scenename = "scenes/Coach/GrabbedBySmoker01d.vcd",   }  //NOOOOOOO!!!!!!!!!
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakCombatMechanic",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Mechanic" ],
			[ "InCombatMusic", 1 ],
            [ IsTalkEllis ],
		],
		responses =
		[
         {   scenename = "scenes/Mechanic/DLC1_L4D1Tank02.vcd",   }  //Shiiiiiiittttt!
         {   scenename = "scenes/Mechanic/DLC1_L4D1Tank04.vcd",   }  //Oh shiiiiiiittttt!
         {   scenename = "scenes/Mechanic/GrabbedBySmoker02b.vcd",   }  //NOOOOOOO!!!!
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakCombatNamvet",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Namvet" ],
			[ "InCombatMusic", 1 ],
            [ IsTalkNamvet ],
		],
		responses =
		[
            {   scenename = "scenes/NamVet/GrabbedBySmoker01a.vcd",   }  //no, No, NO, NOOOOOOO!!!!!!!!!
            {   scenename = "scenes/NamVet/GrabbedBySmoker02a.vcd",   }  //no, No, NO, NOOOOOOO!!!!!!!!!
            {   scenename = "scenes/NamVet/Swears04.vcd",   }  //Bull-frickin-horseshit.
            {   scenename = "scenes/NamVet/ReactionBoomerVomit01.vcd",   }  //
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakCombatTeengirl",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Teengirl" ],
			[ "InCombatMusic", 1 ],
            [ IsTalkTeenGirl ],
		],
		responses =
		[
            {   scenename = "scenes/TeenGirl/Fallshort02.vcd",   }  //Ohhh nooooo!
            {   scenename = "scenes/TeenGirl/DoubleDeathResponse03.vcd",   } //Oh, shit man, no. No. NO! 
            {   scenename = "scenes/TeenGirl/GrabbedBySmoker01c.vcd",   }  //no, No, No, NO, NOOOOOOO!!!!!!!!!
            {   scenename = "scenes/TeenGirl/GrabbedBySmoker02c.vcd",   }  //no, No, No, NO, NO, NOOOOOOO!!!!!!!!!
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakCombatManager",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Manager" ],
			[ "InCombatMusic", 1 ],
            [ IsTalkManager ],
		],
		responses =
		[
            {   scenename = "scenes/Manager/GrabbedBySmoker01a.vcd",   }  //no, No, NO, NO!!!!!
            {   scenename = "scenes/Manager/Swears07.vcd",   }  //Shit shit shit.
            {   scenename = "scenes/Manager/GrabbedBySmoker02a.vcd",   }  //no, No, NO, NOOOOOOO!!!!!!!!!
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}

	{
		name = "ChCh_MeleeBreakCombatBiker",
		criteria =
		[
			[ "concept", "ChCh_MeleeBreak" ],
			[ "who", "Biker" ],
			[ "InCombatMusic", 1 ],
            [ IsTalkBiker ],
		],
		responses =
		[
            {   scenename = "scenes/Biker/FallShort01.vcd",   }  //Oh no.
            {   scenename = "scenes/Biker/GrabbedBySmoker03.vcd",   }  //no, No, NO, NO!!!
            {   scenename = "scenes/Biker/C6DLC3JUMPINGOFFBRIDGE10.vcd",   }  //Don't move! I have a plan!
            {   scenename = "scenes/Biker/DLC2M2FinaleButtonPressGen303.vcd", speakonce = true   }  //Soon as we get the truck moving, I am going to RUN YOU OVER. You goddamn piece of shit.
		],
		group_params = g_rr.RGroupParams({ permitrepeats = true, sequential = false, norepeat = false, /*matchonce = false*/ })
	}
]
g_rr.rr_ProcessRules( newrules );