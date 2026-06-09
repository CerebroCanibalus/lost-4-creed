ChCh_StuffInCrates <-
{
    ItemModels = ["models/w_models/weapons/w_eq_adrenaline.mdl", 
                  "models/w_models/weapons/w_eq_bile_flask.mdl", 
                  "models/w_models/weapons/w_eq_defibrillator.mdl", 
                  "models/w_models/weapons/w_eq_explosive_ammopack.mdl", 
                  "models/w_models/weapons/w_eq_incendiary_ammopack.mdl",
                  "models/w_models/weapons/w_eq_medkit.mdl",
                  "models/w_models/weapons/w_eq_molotov.mdl",
                  "models/w_models/weapons/w_eq_painpills.mdl",
                  "models/w_models/weapons/w_eq_pipebomb.mdl"]
    FoundItems = []

    function OnGameEvent_round_start( params )
    {
        if ("g_MapScript" in getroottable())
            g_MapScript.ScriptedMode_CallNextUpdate(function() { ::ChCh_StuffInCrates.ChCh_CrateItems() })
    }

	function ChCh_CrateItems()
	{
    	for (local item; item = Entities.FindByClassname(item, "weapon_*"); )
		{
			if(::ChCh_StuffInCrates.HowsItem(item) && ::ChCh_StuffInCrates.FoundItems.find(item) == null)
            {
                local itemsnear = []
                for (local item2; item2 = Entities.FindByClassnameWithin(item2, item.GetClassname(), item.GetOrigin(), 64); )
                {
                    if(::ChCh_StuffInCrates.ItemModels.find(item.GetModelName().tolower()) != null)
                    {
                        itemsnear.append(::ChCh_StuffInCrates.ItemClassFromModel(item2.GetModelName().tolower()))
                        ::ChCh_StuffInCrates.FoundItems.append(item2)
                        if (item2 && item2.IsValid()) item2.Kill()
                    }
                }
                ::ChCh_StuffInCrates.SpawnCrate(item, itemsnear)
                item.Kill()
            }
 		}
 	}

    function HowsItem(item)
    {
 		if(NetProps.GetPropEntity(item, "m_hOwner") == null)
        {
            if(::ChCh_StuffInCrates.ItemModels.find(item.GetModelName().tolower()) != null && !(NetProps.GetPropInt(item, "m_spawnflags") == (NetProps.GetPropInt(item, "m_spawnflags") | 8)) && Entities.FindByClassnameNearest("prop_health_cabinet", item.GetOrigin(), 128) == null && (NetProps.GetPropInt(item, "m_itemCount") == 1 || !NetProps.HasProp(item, "m_itemCount")))
            {
                local nearnav = NavMesh.GetNearestNavArea(item.GetOrigin(), 512, true, false)
                if(nearnav)
                {
                    local spot = nearnav.GetSpawnAttributes()
                    if(!(spot == (spot | 128)) && !(spot == (spot | 2048)))
                    {
                        return true
                    }
                }
            }
        }
    }

    function SpawnCrate(item, amount)
    {
        local crate = SpawnEntityFromTable("prop_physics", { 
        targetname = "chch_itemcrate",
        origin = item.GetOrigin() + Vector(0,0,16), 
        angles = "0 " + RandomInt(0,180) + " 0",
        model = amount.len() > 1 ? "models/props_crates/supply_crate02.mdl" : "models/props_crates/supply_crate01.mdl", 
        solid = 0,
        spawnflags = 8192 
        })
        crate.ValidateScriptScope()
        crate.GetScriptScope()["ChCh_StuffInside"] <- amount
    }

    function SpawnItem(item, prop)
    {
		local item = SpawnEntityFromTable(item, { origin = prop.GetOrigin(), angles = RandomInt(0,359).tostring() + " " + RandomInt(0,359).tostring() + " " + RandomInt(0,359).tostring() })

        if(item)
        {
            item.SetVelocity(prop.GetVelocity() + Vector(RandomInt(-50,50),RandomInt(-50,50),RandomInt(100,160)))
        }
    }

    function ItemClassFromModel(model)
    {
        switch(model)
        {
            case "models/w_models/weapons/w_eq_adrenaline.mdl":
                return "weapon_adrenaline"
                break
            case "models/w_models/weapons/w_eq_bile_flask.mdl":
                return "weapon_vomitjar"
                break
            case "models/w_models/weapons/w_eq_defibrillator.mdl":
                return "weapon_defibrillator"
                break
            case "models/w_models/weapons/w_eq_explosive_ammopack.mdl":
                return "weapon_upgradepack_explosive"
                break
            case "models/w_models/weapons/w_eq_incendiary_ammopack.mdl":
                return "weapon_upgradepack_incendiary"
                break
            case "models/w_models/weapons/w_eq_medkit.mdl":
                return "weapon_first_aid_kit"
                break
            case "models/w_models/weapons/w_eq_molotov.mdl":
                return "weapon_molotov"
                break
            case "models/w_models/weapons/w_eq_painpills.mdl":
                return "weapon_pain_pills"
                break
            case "models/w_models/weapons/w_eq_pipebomb.mdl":
                return "weapon_pipe_bomb"
                break
        }
    }

    function OnGameEvent_break_prop( params )
    {
        if(params.entindex)
		{
			if("entindex" in params)
			{
				local prop = EntIndexToHScript(params.entindex)

				if(prop.GetModelName() == "models/props_crates/supply_crate01.mdl" || prop.GetModelName() == "models/props_crates/supply_crate02.mdl")
				{
                    if(prop.GetName() == "chch_itemcrate")
                    {
                        foreach(dingle in prop.GetScriptScope()["ChCh_StuffInside"])
                        {
                            SpawnItem(dingle, prop)
                        }
                    }
				}
			}
		}
    }
}

__CollectGameEventCallbacks(ChCh_StuffInCrates);
/*
ChCh_StuffInCrates <-
{
    ItemModels = ["models/w_models/weapons/w_eq_adrenaline.mdl", 
                  "models/w_models/weapons/w_eq_bile_flask.mdl", 
                  "models/w_models/weapons/w_eq_defibrillator.mdl", 
                  "models/w_models/weapons/w_eq_explosive_ammopack.mdl", 
                  "models/w_models/weapons/w_eq_incendiary_ammopack.mdl",
                  "models/w_models/weapons/w_eq_medkit.mdl",
                  "models/w_models/weapons/w_eq_molotov.mdl",
                  "models/w_models/weapons/w_eq_painpills.mdl",
                  "models/w_models/weapons/w_eq_pipebomb.mdl"]
    FoundItems = []

    function OnGameEvent_round_start( params )
    {
        if ("g_MapScript" in getroottable())
            g_MapScript.ScriptedMode_CallNextUpdate(function() { ::ChCh_StuffInCrates.ChCh_CrateItems() })
    }

	function ChCh_CrateItems()
	{
    	for (local item; item = Entities.FindByClassname(item, "weapon_*"); )
		{
			if(::ChCh_StuffInCrates.HowsItem(item) && ::ChCh_StuffInCrates.FoundItems.find(item) == null)
            {
                local itemsnear = []
                for (local item2; item2 = Entities.FindByClassnameWithin(item2, item.GetClassname(), item.GetOrigin(), 64); )
                {
                    if(item2.GetModelName() == item.GetModelName())
                    {
                        itemsnear.append(item2)
                        ::ChCh_StuffInCrates.FoundItems.append(item2)
                        if (item2 && item2.IsValid()) item2.Kill()
                    }
                }
                ::ChCh_StuffInCrates.SpawnCrate(item, itemsnear.len())
                item.Kill()
            }
		}
	}

    function HowsItem(item)
    {
		if(NetProps.GetPropEntity(item, "m_hOwner") == null)
        {
            if(::ChCh_StuffInCrates.ItemModels.find(item.GetModelName().tolower()) != null && !(NetProps.GetPropInt(item, "m_spawnflags") == (NetProps.GetPropInt(item, "m_spawnflags") | 8)) && Entities.FindByClassnameNearest("prop_health_cabinet", item.GetOrigin(), 128) == null && (NetProps.GetPropInt(item, "m_itemCount") == 1 || !NetProps.HasProp(item, "m_itemCount")))
            {
                local nearnav = NavMesh.GetNearestNavArea(item.GetOrigin(), 512, true, false)
                if(nearnav)
                {
                    local spot = nearnav.GetSpawnAttributes()
                    if(!(spot == (spot | 128)) && !(spot == (spot | 2048)))
                    {
                        return true
                    }
                }
            }
        }
    }

    function SpawnCrate(item, amount)
    {
        local crate = SpawnEntityFromTable("prop_physics", { 
        targetname = amount + "dinglestick" + item.GetModelName(),
        origin = item.GetOrigin() + Vector(0,0,16), 
        angles = QAngle(0, RandomInt(0,180), 0).ToKVString() , 
        model = amount > 1 ? "models/props_crates/supply_crate02.mdl" : "models/props_crates/supply_crate01.mdl", 
        solid = 0,
        spawnflags = 8192 
        })
    }

    function SpawnItem(item, prop)
    {
		local item = SpawnEntityFromTable(item, { origin = prop.GetOrigin(), angles = QAngle(RandomInt(0,359), RandomInt(0,359), RandomInt(0,359)).ToKVString() })
		
		item.SetVelocity(prop.GetVelocity() + Vector(RandomInt(-50,50),RandomInt(-50,50),RandomInt(100,160)))
    }

    function OnGameEvent_break_prop( params )
    {
        if(params.entindex)
		{
			if("entindex" in params)
			{
				local prop = EntIndexToHScript(params.entindex)

				if(prop.GetModelName() == "models/props_crates/supply_crate01.mdl" || prop.GetModelName() == "models/props_crates/supply_crate02.mdl")
				{
                    local name = prop.GetName()
                    local dinglespot = name.find("dinglestick",0)
                    if(name.len() > 15 && dinglespot != null)
                    {
                        local amount = name.slice(0, dinglespot).tointeger()
					    switch(name.slice(dinglespot + 11, name.len()).tolower())
                        {
                            case "models/w_models/weapons/w_eq_adrenaline.mdl":
                                for(local index = 0 ; index < amount ; index += 1)
                                {
                                    SpawnItem("weapon_adrenaline", prop)
                                }
                                break
                            case "models/w_models/weapons/w_eq_bile_flask.mdl":
                                for(local index = 0 ; index < amount ; index += 1)
                                {
                                    SpawnItem("weapon_vomitjar", prop)
                                }
                                break
                            case "models/w_models/weapons/w_eq_defibrillator.mdl":
                                for(local index = 0 ; index < amount ; index += 1)
                                {
                                    SpawnItem("weapon_defibrillator", prop)
                                }
                                break
                            case "models/w_models/weapons/w_eq_explosive_ammopack.mdl":
                                for(local index = 0 ; index < amount ; index += 1)
                                {
                                    SpawnItem("weapon_upgradepack_explosive", prop)
                                }
                                break
                            case "models/w_models/weapons/w_eq_incendiary_ammopack.mdl":
                                for(local index = 0 ; index < amount ; index += 1)
                                {
                                    SpawnItem("weapon_incendiarypack_explosive", prop)
                                }
                                break
                            case "models/w_models/weapons/w_eq_medkit.mdl":
                                for(local index = 0 ; index < amount ; index += 1)
                                {
                                    SpawnItem("weapon_first_aid_kit", prop)
                                }
                                break
                            case "models/w_models/weapons/w_eq_molotov.mdl":
                                for(local index = 0 ; index < amount ; index += 1)
                                {
                                    SpawnItem("weapon_molotov", prop)
                                }
                                break
                            case "models/w_models/weapons/w_eq_painpills.mdl":
                                for(local index = 0 ; index < amount ; index += 1)
                                {
                                    SpawnItem("weapon_pain_pills", prop)
                                }
                                break
                            case "models/w_models/weapons/w_eq_pipebomb.mdl":
                                for(local index = 0 ; index < amount ; index += 1)
                                {
                                    SpawnItem("weapon_pipe_bomb", prop)
                                }
                                break
                        }
                    }
				}
			}
		}
    }
}

__CollectGameEventCallbacks(ChCh_StuffInCrates);
*/