printl("======================================");
printl("REPULSION ON TANK PUNCH INCAP by tomaz");
printl("======================================");

ROTPI <-
{
	function OnGameEvent_player_incapacitated(params)
	{
		if( ("userid" in params) && ("weapon" in params) && ("type" in params) )
		{
			local player = GetPlayerFromUserID(params.userid);
			local tank_weapon = params.weapon;
			local type = params.type;
	
			if(tank_weapon == "tank_claw" && type == 128)
			{
				// Workaround: desincapacitar momentáneamente para que el engine aplique el impulso físico
				NetProps.SetPropInt(player, "m_isIncapacitated", 0);
				player.SetHealth(0);
				
				// 🛡️ REFACTOR: Reemplazar DoEntFire("RunScriptCode") por MaoLib timer
				// El patrón DoEntFire("!self", "RunScriptCode", ...) es peligroso porque
				// self.Kill() se ignora y el string code no se valida en tiempo de carga.
				// MaoLib.AddTimerSafe usa closure — tipado seguro, sin compilestring.
				local uid2 = params.userid;
				MaoLib.DelayCall(function() {
					if (!player || !player.IsValid()) return;
					NetProps.SetPropInt(player, "m_isIncapacitated", 1);
					player.SetHealth(Convars.GetFloat("survivor_incap_health"));
				}, 0.01);
				
				// Prevenir animación de pararse al aterrizar
				local timerName = "rotpi_check_" + params.userid;
				
				// Evitar duplicados
				if (MaoLib.IsTimerActive(timerName))
					return;
				
				// Delay de 0.25s (como el original) antes de empezar a checkear
				MaoLib.DelayCall(function() {
					MaoLib.AddTimerForce(timerName, 0.05, function() {
						if (!player || !player.IsValid())
						{
							MaoLib.RemoveTimer(timerName);
							return;
						}
						
						// Si tocó suelo
						if (NetProps.GetPropInt(player, "m_hGroundEntity") != -1)
						{
							// Forzar animación de incapacitación, descubierto por Shadowysn
							local slot = 6;
							local weapon = player.GetActiveWeapon();
							local isDual = (weapon && weapon.IsValid() && NetProps.GetPropInt(weapon, "m_isDualWielding") == 1);
							local anim = isDual ? "ACT_IDLE_INCAP_ELITES" : "ACT_IDLE_INCAP_PISTOL";
							
							NetProps.SetPropIntArray(player, "m_NetGestureSequence", player.LookupSequence(anim), slot);
							NetProps.SetPropIntArray(player, "m_NetGestureActivity", player.LookupActivity(anim), slot);
							NetProps.SetPropFloatArray(player, "m_NetGestureStartTime", Time(), slot);
							
							MaoLib.RemoveTimer(timerName);
						}
					});
				}, 0.25);
			}
		}
	}
	
	// cancel anim?
	function OnGameEvent_revive_begin(params)
	{
		local player = GetPlayerFromUserID(params.subject);
		if(player == null) return;
		
		local slot = 6;
		local seq = NetProps.GetPropIntArray(player, "m_NetGestureSequence", slot);
		local act = NetProps.GetPropIntArray(player, "m_NetGestureActivity", slot);
		
		if(seq != 0 || act != 0)
		{
			NetProps.SetPropIntArray(player, "m_NetGestureSequence", 0, slot);
			NetProps.SetPropIntArray(player, "m_NetGestureActivity", 0, slot);
			NetProps.SetPropFloatArray(player, "m_NetGestureStartTime", -1, slot);
		}
	}
}

__CollectGameEventCallbacks(ROTPI);