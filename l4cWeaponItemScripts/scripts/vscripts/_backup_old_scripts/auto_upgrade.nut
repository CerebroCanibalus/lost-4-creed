::UpgradeShare <- {

	OnGameEvent_upgrade_pack_used = function(event) {
		local upgradeID = event.upgradeid.tointeger();

		local upgradeEnt = EntIndexToHScript(upgradeID);
		if (!upgradeEnt || !upgradeEnt.IsValid()) return;

		local upgradeClass = upgradeEnt.GetClassname();
		local upgradeType = -1;

		if (upgradeClass == "upgrade_ammo_explosive") {
			upgradeType = 1;
		} else if (upgradeClass == "upgrade_ammo_incendiary") {
			upgradeType = 0;
		}

		if (upgradeType == -1) return;
		
		local survivors = ::UpgradeShare.FindAllSurvivors();

	    foreach(idx, survivor in survivors) {
            if (survivor.IsValid() && !survivor.IsIncapacitated() && NetProps.GetPropInt(survivor, "m_lifeState") == 0) {
                survivor.GiveUpgrade(upgradeType);
            }
		}
		upgradeEnt.Kill();
	},
	
	FindAllSurvivors = function() {
        local survivors = {};
        local i = 0;
        for (local player = null; player = Entities.FindByClassname(player, "player"); ) {
            if (player.IsValid() && player.IsSurvivor()) {
                survivors[i] <- player;
                i++;
            }
        }
        return survivors;
    }	
};

__CollectEventCallbacks(::UpgradeShare, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);