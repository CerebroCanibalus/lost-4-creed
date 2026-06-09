::g_DifficultyLimitedAmmo <- {
	ammoUses = 0

	function HandleAmmoPickup(params) {
		local currentdif = GetDifficulty()
		local player = GetPlayerFromUserID(params.userid);
		if (!player) return;
		local ammo = Entities.FindByClassnameNearest("weapon_ammo_spawn", player.GetOrigin(), 150);

		if (ammo != null) {
			ammoUses++;
			if(currentdif == 0) {
			}
			if(currentdif == 1) {
				if (ammoUses >= 3) {
				ammo.Kill();
				ammoUses = 0;
				}
			}
			if(currentdif == 2) {
				if (ammoUses >= 2) {
				ammo.Kill();
				ammoUses = 0;
				}
			}
			if(currentdif == 3) {
				if (ammoUses >= 1) {
				ammo.Kill();
				ammoUses = 0;
				}
			}
		}
	}
	function OnGameEvent_ammo_pickup(params) { HandleAmmoPickup(params); }
}

__CollectGameEventCallbacks(::g_DifficultyLimitedAmmo);