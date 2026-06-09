printl("Initializing Nescius' pipe damage script");
//if you are mutation maker and want to prevent this script from taking effect simply do
//EntFire("nescius_pipe_damage", "Kill") in your mutation script

::NesciusPipeDamage <- {
    function OnGameEvent_player_hurt(params) {
        if("weapon" in params && params.weapon == "pipe_bomb" && (params.type & 134217792)) {
            local victim = GetPlayerFromUserID(params.userid);
            if(victim == null || victim.IsSurvivor()) {
                return;
            }
            local attacker = GetPlayerFromUserID(params.attacker);
            if(attacker == null || !attacker.IsValid()) {
                attacker = Entities.First();
            }
            attacker.ValidateScriptScope();

            local damage = params.dmg_health >= 10 ? 1500 : params.dmg_health * 50;

            DoEntFire("!self", "RunScriptCode", format("activator.TakeDamage(%d,0,self)",damage), 0, victim, attacker);
        }
    }
}

__CollectGameEventCallbacks(::NesciusPipeDamage);
