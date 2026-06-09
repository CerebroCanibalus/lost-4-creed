
// lets get freaky here

// players with a riot shield in hand cant be grabbed by a smoker, hunter or jockey

// ISSUES :
// - I dont know how to detect if player is facing the hunter/jockey, so skip for now

okkg_RiotShieldBuff <- {

	sounds = ["weapons/riotshield/RiotShield_Block1.mp3","weapons/riotshield/RiotShield_Block2.mp3","weapons/riotshield/RiotShield_Block3.mp3","weapons/riotshield/RiotShield_Block4.mp3","weapons/riotshield/RiotShield_Block5.mp3"],
	ChargerCanBeStopped = false,
	HunterCanBeStopped = true,
	SmokerCanBeStopped = true,
	JockeyCanBeStopped = false,
	BoomerVomitCanBeStopped = true,
	TankRocksCanBeStopped = true,
	CanBlockAttacks = true,
	OnlyBlockCommons = true,
	AttackBlockChance = 15,
	DamageToDeal = 14,
	NoBlockSound = false,
	NoComplexBlocking = false,

	function AreLookingAtEachother(user, victim, skipcomplexblock)
	{
		if (skipcomplexblock == false) {
			if (NoComplexBlocking == "true" || NoComplexBlocking == "True") return true;
		}
	
		local look = victim.GetForwardVector()
		local userorigin = user.GetOrigin();
		local victimorigin = victim.GetOrigin();

		
		if ((userorigin - victimorigin).Dot(look) >= 0.7) { // why the fuck did he have a error here
			return true;
		}
	}
	
	function Precache() {
		foreach (sound in sounds) {		
			PrecacheSound(sound);
		}
	}
	
	function PlayShieldSound(player) 
	{
		if (NoBlockSound == "true" || NoBlockSound == "True") return;
	
		EmitAmbientSoundOn(sounds[RandomInt(0, sounds.len() - 1)], 1, 80, 100, player);
	}
	
	function CheckWeapon(player)
	{
		if (player.GetActiveWeapon() == null || !player.GetActiveWeapon().IsValid()) return false;
	
		if (player.GetActiveWeapon().GetModelName() == "models/weapons/melee/v_riotshield.mdl") // https://tenor.com/view/drake-computer-notebook-explaning-gif-21152267
		{
			//printl(true);
			return true;
		}		
		return false;
	}

	function OnGameEvent_round_start_post_nav(params) {
		local file = FileToString("riotshieldbuffs/cfg.txt");
		
		if (!file) {
			StringToFile("riotshieldbuffs/cfg.txt", "Smoker Can Be Stopped = true\nJockey Can Be Stopped = true\nHunter Can Be Stopped = true\nAttacks Can Be Blocked = true\nOnly Block Common Attacks = true\nAttack Block Chance = 15\nDamage Dealt From Blocking Special Attacks = 5\nNo Block Sound = false\nNo Complex Blocking = false");
			return
		} 	
		else {
			local var1 = split(file, "\n");
			foreach(var01 in var1) {
				local var = strip(var01);
				local parts = split(var, "=");
				local description = strip(parts[0]); 
				local value = strip(parts[1]); 
				
				// yanderedev code
				
				if (description == "Smoker Can Be Stopped") { 
					SmokerCanBeStopped = value;
					continue;
				}	
				if (description == "Jockey Can Be Stopped") { 
					JockeyCanBeStopped = value;
					continue;
				}
				if (description == "Hunter Can Be Stopped") { 
					HunterCanBeStopped = value;
					continue;
				}
				if (description == "Boomer Vomit Can Be Stopped") { 
					BoomerVomitCanBeStopped = value;
					continue;
				}
				if (description == "Charger Can Be Stopped") { 
					ChargerCanBeStopped = value;
					continue;
				}
				if (description == "Attacks Can Be Blocked") { 
					CanBlockAttacks = value;
					continue;
				}
				if (description == "Only Block Common Attacks") { 
					OnlyBlockCommons = value;
					continue;
				}
				if (description == "Attack Block Chance") { 
					AttackBlockChance = value.tointeger();
					continue;
				}
				if (description == "Damage Dealt From Blocking Special Attacks") { 
					DamageToDeal = value.tointeger();
					continue;
				}
				if (description == "No Block Sound") { 
					NoBlockSound = value;
					continue;
				}
				if (description == "No Complex Blocking") {
					NoComplexBlocking = value;
					continue;
				}
			}
		}
	}


	function OnGameEvent_player_hurt(params) {
		okkg_RiotShieldBuff.HandlePlayerHurt(params);
	}

	function HandlePlayerHurt(params) { 
		
		// hi im okkg and im a fucking dumbass programmer
				
		if (CanBlockAttacks == "false" || CanBlockAttacks == "False") return;
		
		if (RandomInt(1, 100) <= AttackBlockChance) {
			if ("attackerentid" in params && "userid" in params && "userid" in params) {
				local attacker = EntIndexToHScript(params.attackerentid);
								
				local player = GetPlayerFromUserID(params.userid);
				if (!player) return;
				local commonsonlycheck = false;
				
				if (attacker == null) return;
				if (!attacker.IsValid()) return;

				if (attacker.GetClassname() != "player") {
					commonsonlycheck = true
				}else {
					if (OnlyBlockCommons == "false") {
						commonsonlycheck = true
					}
				}
				
				if (CheckWeapon(player) && !player.IsStaggering() && params.type == 128 && attacker.IsValid()) {
				
					// i forgot to make common attacks be only blocked while facing them
				
					if (!AreLookingAtEachother(attacker, player, true) && commonsonlycheck && NoComplexBlocking == "true") {
						printl("back")
						PlayShieldSound(player);
						player.SetHealth(player.GetHealth() + (params.dmg_health / 2));
					} 
					if (AreLookingAtEachother(attacker, player, true)) {
						printl("front")
						PlayShieldSound(player);
						player.SetHealth(player.GetHealth() + params.dmg_health);
					}
				}
			}
		} else {
			return;
		}
	}
	

	function OnGameEvent_tongue_grab(params) { 
	
		if (SmokerCanBeStopped == "false" || SmokerCanBeStopped == "False") return;
	
		local player = GetPlayerFromUserID(params.victim);
		if (!player) return;
		local attacker = GetPlayerFromUserID(params.userid);
		if (!attacker) return;
		
		if (CheckWeapon(player) && AreLookingAtEachother(attacker, player, false) && !player.IsStaggering() && player.IsValid()) {
			player.TakeDamage(DamageToDeal,0,attacker);
			PlayShieldSound(player);
			player.Stagger(attacker.GetOrigin());
			attacker.Stagger(player.GetOrigin());
		}
	}
	
	function OnGameEvent_jockey_ride(params) { 
	
		if (JockeyCanBeStopped == "false" || JockeyCanBeStopped == "False") return;
	
		local player = GetPlayerFromUserID(params.victim);
		if (!player) return;
		local attacker = GetPlayerFromUserID(params.userid);
		if (!attacker) return;
		
		if (CheckWeapon(player) && !player.IsStaggering() && player.IsValid()) {
			player.TakeDamage(DamageToDeal,0,attacker);	
			PlayShieldSound(player);			
			player.Stagger(attacker.GetOrigin());
			attacker.Stagger(player.GetOrigin());
		}
	}
	
	function OnGameEvent_lunge_pounce(params) { 
	
		if (HunterCanBeStopped == "false" || HunterCanBeStopped == "False") return;

		local player = GetPlayerFromUserID(params.victim);
		if (!player) return;
		local attacker = GetPlayerFromUserID(params.userid);
		if (!attacker) return;
		
		if (CheckWeapon(player) && !player.IsStaggering() && player.IsValid()) {
			player.TakeDamage(DamageToDeal,0,attacker);
			PlayShieldSound(player);
			player.Stagger(attacker.GetOrigin());
			attacker.Stagger(player.GetOrigin());
		}
	}
	
	function OnGameEvent_player_now_it(params) { 
		return;
		if (BoomerVomitCanBeStopped == "false" || BoomerVomitCanBeStopped == "False" || !"attacker" in params) return;
		
		local player = GetPlayerFromUserID(params.userid);
		if (!player) return;
		local attacker = GetPlayerFromUserID(params.attacker);
		if (!attacker) return;
			
		if (CheckWeapon(player) && !player.IsStaggering() && AreLookingAtEachother(attacker, player, false)) {
			PlayShieldSound(player);
			player.Stagger(attacker.GetOrigin());
			//player.TakeDamage(DamageToDeal,0,attacker);	
			attacker.Stagger(player.GetOrigin());
		}
		
	}	
	
	// wip
	
	function OnGameEvent_charger_carry_start(params) { 
		
		if (ChargerCanBeStopped == "false" || ChargerCanBeStopped == "False") return;
		
		local player = GetPlayerFromUserID(params.victim);
		if (!player) return;
		local attacker = GetPlayerFromUserID(params.userid);
		if (!attacker) return;
		
		if (CheckWeapon(player) && !player.IsStaggering()) {
			player.Stagger(attacker.GetOrigin());
			player.TakeDamage(15,0,attacker);	
			attacker.Stagger(player.GetOrigin());
		}
	}
	
	function OnGameEvent_charger_impact(params) { 
		
		if (ChargerCanBeStopped == "false" || ChargerCanBeStopped == "False") return;
		
		local player = GetPlayerFromUserID(params.victim);
		if (!player) return;
		local attacker = GetPlayerFromUserID(params.userid);
		if (!attacker) return;
		
		if (CheckWeapon(player) && !player.IsStaggering()) {
			player.Stagger(attacker.GetOrigin());
			player.TakeDamage(15,0,attacker);	
			attacker.Stagger(player.GetOrigin());
		}
	}
}
okkg_RiotShieldBuff.Precache();
__CollectGameEventCallbacks(okkg_RiotShieldBuff);