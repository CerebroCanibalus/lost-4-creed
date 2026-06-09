printl( "Char Boxeador XDDD");

chargerbounce <-
{
	function bounce(victim)
	{
		if (victim.IsDominatedBySpecialInfected()) return;

		victim.SetOrigin(victim.GetOrigin() + Vector(0, 0, 1));
		local direction = RandomInt(1, 8);
		if (direction == 1)
			victim.SetVelocity(Vector(0, 200, 500));
		else if (direction == 2)
			victim.SetVelocity(Vector(200, 200, 500));
		else if (direction == 3)
			victim.SetVelocity(Vector(200, 0, 500));
		else if (direction == 4)
			victim.SetVelocity(Vector(200, -200, 500));
		else if (direction == 5)
			victim.SetVelocity(Vector(0, -200, 500));
		else if (direction == 6)
			victim.SetVelocity(Vector(-200, -200, 500));
		else if (direction == 7)
			victim.SetVelocity(Vector(-200, 0, 500));
		else if (direction == 8)
			victim.SetVelocity(Vector(-200, 200, 500));
	}

    function HandlePlayerHurt(event)
    {
        local victim = GetPlayerFromUserID(event.userid);
        local attacker = GetPlayerFromUserID(event.attacker);
        if (victim != null && attacker != null && attacker.GetZombieType() == 6)
        {
            if (victim.IsSurvivor())
            {
                bounce(victim);
            }
        }
    }

    function OnGameEvent_player_hurt(params) { chargerbounce.HandlePlayerHurt(params); }
}

__CollectGameEventCallbacks(chargerbounce);