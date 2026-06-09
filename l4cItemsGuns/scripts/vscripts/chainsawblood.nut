ChainsawBlood <- {}

//DEBUGGING
ChainsawBlood.OnGameEvent_infected_death <- function ( params )
{
	local attacker = GetPlayerFromUserID(params.attacker);
	if( !attacker || !attacker.IsSurvivor() )
		return;
		
	local activeWep = attacker.GetActiveWeapon();
	if(activeWep.GetClassname() != "weapon_chainsaw")
		return;
		
	local bloodlevel = NetProps.GetPropInt(activeWep, "m_iBloodyWeaponLevel");
	if(bloodlevel == 10)
		return;
	
	NetProps.SetPropInt(activeWep, "m_iBloodyWeaponLevel", bloodlevel + 1);
}

ChainsawBlood.OnGameEvent_player_hurt <- function ( params )
{
	local attacker = GetPlayerFromUserID(params.attacker);
	if( !attacker || !attacker.IsSurvivor() )
		return;

	local activeWep = attacker.GetActiveWeapon();	
	if(activeWep.GetClassname() != "weapon_chainsaw")
		return;
		
	local bloodlevel = NetProps.GetPropInt(activeWep, "m_iBloodyWeaponLevel");
	if(bloodlevel == 10)
		return;
	
	NetProps.SetPropInt(activeWep, "m_iBloodyWeaponLevel", bloodlevel + 1);
}

ChainsawBlood.OnGameEvent_infected_hurt <- function ( params )
{
	local attacker = GetPlayerFromUserID(params.attacker);
	if( !attacker || !attacker.IsSurvivor() )
		return;
		
	local activeWep = attacker.GetActiveWeapon();
	if(activeWep.GetClassname() != "weapon_chainsaw")
		return;
		
	local bloodlevel = NetProps.GetPropInt(activeWep, "m_iBloodyWeaponLevel");
	if(bloodlevel == 10)
		return;
	
	NetProps.SetPropInt(activeWep, "m_iBloodyWeaponLevel", bloodlevel + 1);
}

__CollectGameEventCallbacks(ChainsawBlood)