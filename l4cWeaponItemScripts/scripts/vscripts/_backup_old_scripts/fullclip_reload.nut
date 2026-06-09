RF_RealMag <- {}
RF_RealMag.OnGameEvent_weapon_reload <- function(event)
{
	local p = GetPlayerFromUserID(event.userid);
	if(IsPlayerABot(p))
		return;
	local Gun = p.GetActiveWeapon();
	switch(Gun.GetClassname())
	{
		case "weapon_rifle":
		case "weapon_rifle_ak47":
		case "weapon_rifle_m60":
			DoEntFire("worldspawn", "RunScriptCode", "g_ModeScript.RFClipIn()", 1.2, p, Gun); break;
		case "weapon_rifle_desert":
			DoEntFire("worldspawn", "RunScriptCode", "g_ModeScript.RFClipIn()", 1.8, p, Gun); break;
		case "weapon_rifle_sg552":
			DoEntFire("worldspawn", "RunScriptCode", "g_ModeScript.RFClipIn()", 1.6, p, Gun); break;
		case "weapon_smg":
		case "weapon_smg_silenced":
			DoEntFire("worldspawn", "RunScriptCode", "g_ModeScript.RFClipIn()", 1.04, p, Gun); break;
		case "weapon_smg_mp5":
			DoEntFire("worldspawn", "RunScriptCode", "g_ModeScript.RFClipIn()", 1.7, p, Gun); break;
		case "weapon_hunting_rifle":
			DoEntFire("worldspawn", "RunScriptCode", "g_ModeScript.RFClipIn()", 2.6, p, Gun); break;
		case "weapon_sniper_military":
			DoEntFire("worldspawn", "RunScriptCode", "g_ModeScript.RFClipIn()", 1.8, p, Gun); break;
		case "weapon_sniper_scout":
			DoEntFire("worldspawn", "RunScriptCode", "g_ModeScript.RFClipIn()", 1.45, p, Gun); break;
		case "weapon_sniper_awp":
			DoEntFire("worldspawn", "RunScriptCode", "g_ModeScript.RFClipIn()", 2.0, p, Gun); break;
		case "weapon_grenade_launcher":
			DoEntFire("worldspawn", "RunScriptCode", "g_ModeScript.RFClipIn()", 2.5, p, Gun); break;
		case "weapon_pistol_magnum":
		case "weapon_pistol":
		{
			if(Convars.GetFloat("ammo_pistol_max") != -2)
			{
				if(NetProps.GetPropInt(Gun, "m_isDualWielding"))
					DoEntFire("worldspawn", "RunScriptCode", "g_ModeScript.RFClipIn()", 1.75, p, Gun);
				else
					DoEntFire("worldspawn", "RunScriptCode", "g_ModeScript.RFClipIn()", 1.19, p, Gun);
			}
			else if(NetProps.GetPropInt(Gun, "m_isDualWielding"))
			{
				DoEntFire("worldspawn", "RunScriptCode", "g_ModeScript.RFClipInD()", 1.0, p, Gun);
				DoEntFire("worldspawn", "RunScriptCode", "g_ModeScript.RFClipInP()", 1.75, p, Gun);
			}
			else
				DoEntFire("worldspawn", "RunScriptCode", "g_ModeScript.RFClipInP()", 1.19, p, Gun);
			break;
		}
		default:
			break;
	}
}

function RFClipIn()
{
	if(caller == null || activator == null)
		return;
	if(!NetProps.GetPropInt(caller, "m_bInReload") || activator.GetActiveWeapon() != caller)
		return;

	local PrimType = NetProps.GetPropInt(caller, "m_iPrimaryAmmoType");
	local RAmmo = NetProps.GetPropIntArray(activator, "m_iAmmo", PrimType);
	local CAmmo = caller.Clip1();
	local MaxAmmo = caller.GetMaxClip1();
	local RemAmmo = MaxAmmo - CAmmo;

	if(RAmmo + CAmmo > MaxAmmo)
		caller.SetClip1(MaxAmmo);
	else
		caller.SetClip1(RAmmo + CAmmo);
	if(RAmmo > RemAmmo)
		NetProps.SetPropIntArray(activator, "m_iAmmo", RAmmo - RemAmmo, PrimType);
	else
		NetProps.SetPropIntArray(activator, "m_iAmmo", 0, PrimType);
}

function RFClipInP()
{
	if(caller == null || activator == null)
		return;
	if(!NetProps.GetPropInt(caller, "m_bInReload") || activator.GetActiveWeapon() != caller)
		return;
	caller.SetClip1(caller.GetMaxClip1());
}

function RFClipInD()
{
	if(caller == null || activator == null)
		return;
	if(!NetProps.GetPropInt(caller, "m_bInReload") || activator.GetActiveWeapon() != caller)
		return;
	if(caller.Clip1() > caller.GetMaxClip1() / 2)
		return;
	caller.SetClip1(caller.GetMaxClip1() / 2);
}
__CollectGameEventCallbacks(RF_RealMag);