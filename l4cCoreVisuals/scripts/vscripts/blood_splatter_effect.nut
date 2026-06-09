// a fix for the crashing/string table overflow was gracefully provided by Nescius on 18 DEC 2024 (thank you so much Nescius)
// code written by Nescius will be highlighted with his name at the start and the end of said code so you can see what changed exactly

// lotsa randomints and floats up in here

printl("==============================");
printl("BLOOD SPLATTER EFFECT by tomaz");
printl("==============================");

const BSE_context_name = "BSE_spraying_blood";
// > NESCIUS
// ⚠️ CORREGIDO: info_projecteddecal → infodecal
// info_projecteddecal está PROHIBIDO en L4D2 — causa crash del engine.
// infodecal es el decal estándar y acepta los mismos keyvalues (origin, angles, texture).
const BSE_entfire_snip = @"SpawnEntityGroupFromTable({
		a = {
			infodecal = tomazblooddecal[%d]
		}
	})";


local ambientix = 0, bloodix = 0;
::tomazblooddecal <- array(256);
// < NESCIUS

BSE <-
{
	blood_decals =
	{
		"normal":
		[
			"decals/blood1",
			"decals/blood2",
			"decals/blood3",
			"decals/blood4",
			"decals/blood5",
			"decals/blood6",
			"decals/blood7",
			"decals/blood8"
		],

		"big":
		[
			"decals/blood1_subrect",
			"decals/blood2_subrect",
			"decals/blood3_subrect",
			"decals/blood4_subrect",
			"decals/blood5_subrect",
			"decals/blood6_subrect"
		],

		"tiny":
		[
			"decals/flesh/blood1",
			"decals/flesh/blood2",
			"decals/flesh/blood3",
			"decals/flesh/blood4",
			"decals/flesh/blood5"
		]
	},

	splat_sounds =
	[
		"player/survivor/splat/zombie_blood_spray_01.wav",
		"player/survivor/splat/zombie_blood_spray_02.wav",
		"player/survivor/splat/zombie_blood_spray_03.wav",
		"player/survivor/splat/zombie_blood_spray_04.wav",
		"player/survivor/splat/zombie_blood_spray_05.wav",
		"player/survivor/splat/zombie_blood_spray_06.wav"
	],

	function OnGameEvent_player_hurt(params)
	{
		if( ("userid" in params) && ("attacker" in params) && ("weapon" in params) && ("hitgroup" in params) && ("type" in params) )
		{
			if(params.attacker == 0 && params.weapon == null) return;

			local victim = GetPlayerFromUserID(params.userid);
			local attacker = GetPlayerFromUserID(params.attacker);
			if(!victim || !attacker) return;

			// don't spray if it's the charger's pummeling attack, doesn't make sense to me
			if(attacker.GetZombieType() == 6 && victim.IsDominatedBySpecialInfected()) return;

			local type = params.type;
			if(type == 128 && attacker.IsSurvivor()) return;
			if(!IsValidDMGType(type)) return;

			local hitgroup = params.hitgroup;
			local classname = params.weapon;
			local amount = DetermineAmount(classname, hitgroup);

			SprayBlood(victim, amount, hitgroup, attacker);
		}
	}

	function OnGameEvent_infected_hurt(params)
	{
		if( ("entityid" in params) && ("attacker" in params) && ("hitgroup" in params) && ("type" in params) )
		{
			local victim = EntIndexToHScript(params.entityid);
			local attacker = GetPlayerFromUserID(params.attacker);
			if(!victim || !attacker) return;

			local weapon = attacker.GetActiveWeapon();
			if(!weapon) return;
			local classname = weapon.GetClassname();

			local type = params.type;
			if(type == 128 && attacker.IsSurvivor()) return;
			if(!IsValidDMGType(type)) return;

			local hitgroup = params.hitgroup;
			local amount = DetermineAmount(classname, hitgroup);

			SprayBlood(victim, amount, hitgroup, attacker);
		}
	}

	function SprayBlood(victim, amount, hitgroup = null, attacker = null)
	{
		local is_airborne = NetProps.GetPropInt(victim, "m_hGroundEntity") == -1;
		if(is_airborne) return;
		
		// supposedly GetContext is faster, shame it barely works most of the time lol
		if(!ResponseCriteria.HasCriterion(victim, BSE_context_name))
		{
			local attacker_fwd = attacker ? attacker.GetForwardVector() : null;

			// blood size
			local is_headshot = hitgroup && hitgroup == 1;
			local pounce_netprop = NetProps.GetPropEntity(victim, "m_pounceAttacker");
			local is_pounced = (attacker && attacker.GetZombieType() == 3) && pounce_netprop; // if getting ripped up by a hunter.

			local blood_size;
			if(is_headshot || is_pounced)
			{
				blood_size = "big";
			}
			else
			{
				blood_size = "normal";
			}

			// blood decals
			local blood_decals = BSE.blood_decals[blood_size];
			local tiny_blood_decals = BSE.blood_decals["tiny"];

			// origin stuff
			local origin = hitgroup ? GetBestOrigin(victim, hitgroup) : victim.GetOrigin();
			local spray_origin = Vector(origin.x + RandomInt(-10, 10),
										origin.y + RandomInt(-10, 10),
										origin.z + 0.5);

			if(attacker_fwd)
			{
				spray_origin -= attacker_fwd * RandomInt(8, 12);
			}

			local delay = RandomFloat(0.2, 0.35);

			// =============================================================================
			// 										SOUND
			// =============================================================================

			local splat_sounds = BSE.splat_sounds;
			local splat_sound = splat_sounds[RandomInt(0, splat_sounds.len() - 1)];
			// > NESCIUS
			ambientix = (ambientix + 1) % 256;
			local name = "tomazbloodambient" + ambientix;
			local snd_ent = SpawnEntityGroupFromTable(
			{
				a =
				{
					ambient_generic =
					{
						targetname = name,
						origin = spray_origin,
						message = splat_sound,
						radius = 384,
						spawnflags = 48,
						health = 10
					}
				}
			});
			EntFire(name, "PlaySound", "", delay);
			EntFire(name, "Kill", "", delay);
			// < NESCIUS

			// =============================================================================
			// 							     	SPRAY DECAL
			// =============================================================================

			local last_decal;

			for(local b = 0; b < amount; b++)
			{
				local f_blood_decals;

				// prevent consecutive decal tex
				if(last_decal)
				{
					f_blood_decals = blood_decals.filter( function(idx, decal) { return decal != last_decal; } );
				}
				else
				{
					f_blood_decals = blood_decals;
				}

				local blood_tex = f_blood_decals[RandomInt(0, f_blood_decals.len() - 1)];
				last_decal = blood_tex;

				// re-randomize if it's not the 1st iteration
				if(b != 0)
				{
					delay += RandomFloat(0.025, 0.05); // change up a bit
					
					local offset_dir = Vector(RandomFloat(-1, 1), RandomFloat(-1, 1), 0);
					offset_dir.Norm();
					local offset_dist = RandomFloat(8, 12);
					
					spray_origin += offset_dir * offset_dist;
				}

				// SPRAY BIG DECAL ONCE
				SpawnBloodDecal(spray_origin, blood_tex, delay);

				// SMALLER ONES LATER
				for(local s = 0; s < RandomInt(3, 5); s++) // is this too much?
				{
					local tiny_spray_origin = Vector(spray_origin.x + RandomInt(-5, 5),
													 spray_origin.y + RandomInt(-5, 5),
													 spray_origin.z);

					if(attacker_fwd)
					{
						tiny_spray_origin -= attacker_fwd * RandomInt(5, 15);
					}

					local tiny_blood_tex = tiny_blood_decals[RandomInt(0, tiny_blood_decals.len() - 1)];

					SpawnBloodDecal(tiny_spray_origin, tiny_blood_tex, RandomFloat(0.2, 0.35)); // RandomFloat here is intentional. trying to make it a bit more unpredictable for more variety
				}
			}

			victim.SetContext(BSE_context_name, "1", 0.25);
		}
	}

	function GetBestOrigin(victim, hitgroup)
	{
		local origin = victim.GetOrigin();
		local bone;
		local is_invalid = false;

		// annoyingly enough the charger, jockey and spitter have different bone names
		// i could counter it but i don't think i'm gonna bother tbh
		// my only real concern was with the laying down/sleeping commons for example. before the splatter would appear at their origin, regardless of whatever limb you shoot
		// i might change my mind, idk

		switch(hitgroup)
		{
			case 1: // HEAD
				bone = "ValveBiped.Bip01_Head1";
				break;

			case 2: // CHEST
				bone = "ValveBiped.Bip01_Spine4";
				break;

			case 3: // STOMACH/PELVIS
				bone = "ValveBiped.Bip01_Spine1";
				break;

			case 4: // L ARM
				bone = "ValveBiped.Bip01_L_Forearm";
				break;

			case 5: // R ARM
				bone = "ValveBiped.Bip01_R_Forearm";
				break;

			case 6: // L LEG
				bone = "ValveBiped.Bip01_L_Calf";
				break;

			case 7: // R LEG
				bone = "ValveBiped.Bip01_R_Calf";
				break;

			default:
				// error("[BSE] Invalid hitgroup!!! Defaulting to player origin\n");
				is_invalid = true;
		}

		local lookup_bone = victim.LookupBone(bone);

		if(lookup_bone == -1 || is_invalid) return origin;

		local bone_origin = victim.GetBoneOrigin(lookup_bone);
		bone_origin.z = origin.z;

		return bone_origin;
	}
	
	function DetermineAmount(classname, hitgroup)
	{
		local amount;

		if(classname.find("shotgun") != null || (classname == "weapon_melee" || classname == "melee"))
		{
			amount = 3;
		}
		else
		{
			amount = hitgroup == 1 ? RandomInt(2, 3) : RandomInt(1, 2); // if headshot
		}
		
		return amount;
	}

	// if bullet or melee or si claw (club). dmg types can be combined so do BITWISE OR
	function IsValidDMGType(dmg_type)
	{
		return (dmg_type == (dmg_type | 2  /* DMG_BULLET */)) ||
			   (dmg_type == (dmg_type | 128  /* DMG_MELEE/DMG_CLUB */)) ||
			   (dmg_type == 128);
	}

	function SpawnBloodDecal(origin, blood_tex, delay)
	{
		// unless i've somehow been doing it all wrong, i've experienced weirdness when trying to delay the Activate input while setting a targetname, sooo... do this
		
		// > NESCIUS
		tomazblooddecal[bloodix] =
		{
			origin = origin,
			angles = Vector(90, 0, 0),
			texture = blood_tex
		}
		local code = format(BSE_entfire_snip, bloodix);
		bloodix = (bloodix + 1) % 256;
		
		EntFire("worldspawn", "RunScriptCode", code, delay);
		// < NESCIUS
	}
}

__CollectGameEventCallbacks(BSE);