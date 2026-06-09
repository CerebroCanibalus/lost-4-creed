/*
 * ================================================================
 * WITCH DAMAGE SYSTEM - Consolidated Damage & Size Module
 * ================================================================
 * Replaces: witchdamage.nut, witch_size.nut, witchmulti.nut
 * 
 * This module handles witch damage modification and model scaling:
 * - Reduces witch damage to survivors by 70% (30% of original)
 * - Customizable witch size via cvar (default 1.5x, random option)
 * ================================================================
 */

::WitchDamageSystem <-
{
	// ============================================================
	// SIZE SETTINGS
	// ============================================================
	SizeCvar = "kuro_witch_size"
	DefaultSize = 1.5

	// ============================================================
	// EVENT: Witch Spawn - Apply size scaling
	// ============================================================
	function OnGameEvent_witch_spawn(event)
	{
		local witch = null
		if ("witchid" in event)
			witch = EntIndexToHScript(event.witchid)
		
		if (!witch || !witch.IsValid())
			return

		local size = Convars.GetFloat(SizeCvar)
		
		if (size == 666)
		{
			// Random size mode: 0.5x to 2.5x
			NetProps.SetPropFloat(witch, "m_flModelScale", RandomFloat(0.5, 2.5))
			printl("[WitchDamage] Random size applied to witch")
		}
		else if (size != null && size > 0)
		{
			NetProps.SetPropFloat(witch, "m_flModelScale", size)
		}
		else
		{
			// Fallback to default
			NetProps.SetPropFloat(witch, "m_flModelScale", DefaultSize)
		}
	}

	// ============================================================
	// DAMAGE MODIFICATION - AllowTakeDamage hook
	// ============================================================
	function AllowTakeDamage(event)
	{
		// Validate event data
		if (!event.Weapon && !event.Attacker && event.Victim)
			return true

		local attacker = event.Attacker
		local victim = event.Victim

		// Check if witch attacking survivor
		if (attacker && attacker.GetClassname() == "witch" && 
		    victim && victim.GetClassname() == "player" && 
		    victim.IsSurvivor())
		{
			// Reduce damage to 30% of original
			event.DamageDone = event.DamageDone * 0.3
		}

		return true
	}
}

// ================================================================
// SETUP CVAR AND REGISTER
// ================================================================

// Initialize cvar with default size
Convars.SetValue(::WitchDamageSystem.SizeCvar, ::WitchDamageSystem.DefaultSize.tostring())

// Register game event callbacks
::__CollectGameEventCallbacks(WitchDamageSystem)

printl("[WitchDamageSystem] Loaded - Damage reduction (30%) + Size scaling (" + ::WitchDamageSystem.DefaultSize + "x)")
