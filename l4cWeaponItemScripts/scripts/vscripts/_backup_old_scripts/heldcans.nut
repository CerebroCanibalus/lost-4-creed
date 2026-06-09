heldcans <-
{

	function GetHeldSlot(victim)
	{
		local invTable = {};
		GetInvTable(victim, invTable);
		if(!("slot5" in invTable))
		{
			return null;
		}
		local weapon = invTable.slot5;
		if(weapon)
		{
			return weapon.GetClassname();
		}
		return null;
	}

	function GetActiveMainWeapon(victim)
	{
		local weapon = victim.GetActiveWeapon();
		if(weapon)
		{
			return weapon.GetClassname();
		}
		return null;
	}

	function OnGameEvent_friendly_fire(event)
	{
		local victim = GetPlayerFromUserID(event.victim);
		if (!victim) return;
		local weapontokill = victim.GetActiveWeapon();
		if(GetActiveMainWeapon(victim) == GetHeldSlot(victim))
		{
			local thingy = GetHeldSlot(victim);
			if(thingy != "weapon_gnome" && thingy != "weapon_cola_bottles")
			{
				victim.DropItem(GetHeldSlot(victim));
				weapontokill.Kill();
				if(thingy == "weapon_gascan")
				{
					DropFire(victim.GetOrigin());
				}
				if(thingy == "weapon_propanetank")
				{
					victim.TakeDamage(21, 6, victim)
					victim.Stagger(Vector(0,0,0))
					local ent = null
					local victim_origin = victim.GetOrigin()
					while( ent = Entities.FindByClassnameWithin(ent, "infected", victim_origin, 250))
					{
						ent.TakeDamage(25, 33554432, victim)
					}
					local ent = null
					local victim_origin = victim.GetOrigin()
					while( ent = Entities.FindByClassnameWithin(ent, "player", victim_origin, 250))
					{
						ent.TakeDamage(10, 33554432, victim)
						ent.Stagger(Vector(0,0,0))
					}
				}
				if(thingy == "weapon_fireworkcrate")
				{
					DropFire(victim.GetOrigin());
				}
				if(thingy == "weapon_oxygentank")
				{
					RushVictim(victim, 300)
					victim.TakeDamage(15, 6, victim)
					victim.Stagger(Vector(0,0,0))
					local ent = null
					local victim_origin = victim.GetOrigin()
					while( ent = Entities.FindByClassnameWithin(ent, "infected", victim_origin, 200))
					{
						ent.TakeDamage(20, 33554432, victim)
					}
					local ent = null
					local victim_origin = victim.GetOrigin()
					while( ent = Entities.FindByClassnameWithin(ent, "player", victim_origin, 200))
					{
						ent.TakeDamage(5, 33554432, victim)
						ent.Stagger(Vector(0,0,0))
					}
				}
			}
		}
	}
}

__CollectEventCallbacks(heldcans, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);