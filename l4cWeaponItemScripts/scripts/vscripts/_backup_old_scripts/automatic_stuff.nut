//NasCoz is veyr cool uhmmm okay??????
//Nascoz: Okay bro your mod is now very cool +1000 coins brodar

RF_AUTOGUNS <-
{
	OnGameEvent_weapon_fire = function(event)
	{
		local Surv = GetPlayerFromUserID(event.userid);
		if(Surv != null && Surv.IsValid() && Surv.IsSurvivor() && !IsPlayerABot(Surv))
		{
			local wep = event["weapon"];
			if(wep == "pistol" || wep == "sniper_military")
			{
				NetProps.SetPropInt(Surv.GetActiveWeapon(), "m_isHoldingFireButton", 0);
				//NetProps.SetPropInt(Surv, "m_afButtonDisabled", NetProps.GetPropInt(Surv, "m_afButtonDisabled") | 1);
				//DoEntFire("!self", "RunScriptCode", "RestoreFire()", 0, Surv, Surv);
			}
		}
	}
}
__CollectEventCallbacks(RF_AUTOGUNS, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);