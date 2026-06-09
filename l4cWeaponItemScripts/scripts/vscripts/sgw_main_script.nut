::g_SGW_Main <- {
	item_spawn_model = {
		weapon_pain_pills_spawn = "models/w_models/weapons/w_eq_painpills.mdl",
		weapon_adrenaline_spawn = "models/w_models/weapons/w_eq_adrenaline.mdl",
		weapon_molotov_spawn = "models/w_models/weapons/w_eq_molotov.mdl",
		weapon_pipe_bomb_spawn = "models/w_models/weapons/w_eq_pipebomb.mdl",
		weapon_ammo_spawn = "models/props/terror/ammo_stack.mdl"
	}

	function OnGameEvent_weapon_drop(params)
	{
		HandleWeaponDrop(params);
	}

	function HandleWeaponDrop(params)
	{
		if(!("propid" in params)) {
			return;
		}
		local toDrop = EntIndexToHScript(params.propid);

		if(NetProps.HasProp(toDrop, "m_upgradeBitVec") && NetProps.GetPropInt(toDrop, "m_upgradeBitVec") == 0) {
			NetProps.SetPropInt(toDrop, "m_upgradeBitVec", 1);
			EntFire("worldspawn", "RunScriptCode", "NetProps.SetPropInt(activator, \"m_upgradeBitVec\", 0)", 0.1, toDrop);
		}
	}

	function OnGameEvent_spawner_give_item(params)
	{
		HandleSpawnerGiveItem(params);
	}

	function HandleSpawnerGiveItem(params)
	{
		local spawner = EntIndexToHScript(params.spawner);
		if(spawner == null) {
			return;
		}
		local classname = spawner.GetClassname();
		if(classname in item_spawn_model) {
			local item_model = item_spawn_model[classname];
			local spawner_origin = spawner.GetOrigin();
			for(local ent = null; ent = Entities.FindByClassnameWithin(ent, "prop_*", spawner_origin, 100);) {
				if(ent.GetModelName() == item_model) {
					ent.Kill();
					return;
				}
			}
		}
		spawner.Kill();
	}

	function OnGameEvent_round_start(params)
	{
		HandleRoundStart(params);
	}

	function HandleRoundStart(params)
	{
		for(local weapon = null; weapon = Entities.FindByClassname(weapon, "we*");) {
			if(weapon.GetClassname().find("_spawn") != null) {
				weapon.__KeyValueFromInt("spawnflags", 0);
				weapon.__KeyValueFromInt("count", 1);
			}
		}
	}
}

__CollectGameEventCallbacks(::g_SGW_Main);
