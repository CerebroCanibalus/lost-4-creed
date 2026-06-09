Msg("Activating Survivor Ragdolls (Defib-Mode)\n");

if ("survivorragdolls" in getroottable())
{
	delete survivorragdolls;
}

// CHANGELOG
// - Capped thinking function to 0.033

//local script_1 = "vscript_defib_ragdoll_ragremove";

local script_think = "vscript_defib_ragdoll_think";

// Thanks to Lux
local precache1 = SpawnEntityFromTable("env_ragdoll_boogie", {});
if (precache1 != null)
	DoEntFire("!self", "Kill", "0", 0, null, precache1);

local default_folder = "defib_ragdolls";
local info_path = default_folder+"/info.txt";
local settings_path = default_folder+"/settings.cfg";

/*
//local sda_targName = null;

// NOTE: loading the survivordeathanims script and then loading this script in the same session
// seems to clear the survivordeathanims from event callbacks, but it may trick this check that the mod
// is active.
try
{
	if (survivordeathanims in this && survivordeathanims != null)
	{
		Msg("Got a survivordeathanims\n");
		
		if (survivordeathanims.rawin("targName"))
		{
			sda_targName = survivordeathanims.targName;
		}
	}
}
catch (error)
{ Msg("Got no survivordeathanims sadface\n"); }
*/

defibragdolls <-
{
	Settings =
	{
		allowBurningCorpse = true,
		moreStableDefaultPoseSpawn = true
	}
	
	function ParseConfigFile()
	{
		local tData;

		local function Clamp(n, min, max)
		{
			return n < min ? min : (n > max ? max : n);
		}

		local function SerializeSettings()
		{
			local sData = "{";
			foreach (key, val in Settings)
			{
				switch (typeof val)
				{
				case "string":
					sData = format("%s\n\t%s = \"%s\"", sData, key, val);
					break;
				
				case "float":
					sData = format("%s\n\t%s = %.2f", sData, key, val);
					break;
				
				case "integer":
				case "bool":
					sData = sData + "\n\t" + key + " = " + val;
					break;
				}
			}
			sData = sData + "\n}";
			StringToFile(settings_path, sData);
		}

		if (tData = FileToString(settings_path))
		{
			try {
				tData = MaoLib.ParseConfigString(tData);
				local hasMissingKey = false;
				foreach (key, val in Settings)
				{
					if (key in tData)
					{
						Settings[key] = tData[key];
					}
					else if (!hasMissingKey)
					{ hasMissingKey = true; }
				}
				if (hasMissingKey)
				{ SerializeSettings(); }
			}
			catch (error) {
				SerializeSettings();
			}
		}
		else
		{
			SerializeSettings();
		}
	}
	
	function FixTilt(client)
	{
		DoEntFire("!self", "RunScriptCode", "local eye_angles = self.EyeAngles();self.SnapEyeAngles(QAngle(eye_angles.x,eye_angles.y,0));", 0, null, client);
	}
	
	function OnGameEvent_player_death( params )
	{
		local client = Event_GetClient( params, "userid" );
		
		if ( client == null || !client.IsSurvivor() || NetProps.GetPropInt(client, "m_lifeState") != 0 )
			return;
		
		local prev_ragdoll = NetProps.GetPropEntity(client, "m_hRagdoll");
		
		local cl_Origin = client.GetOrigin();
		local body = null;
		for (local death_model; death_model = Entities.FindByClassname( death_model, "survivor_death_model" );)
		{
			local dm_Origin = death_model.GetOrigin();
			if (dm_Origin.x == cl_Origin.x &&
			dm_Origin.y == cl_Origin.y &&
			dm_Origin.z == cl_Origin.z)
			{
				body = death_model;
				break;
			}
		}
		
		try
		{
			if (survivordeathanims)
			{
				
			}
		}
		catch (error)
		{
			CreateDeathRagdoll(client, prev_ragdoll, body, params);
		}
	}
	
	function CreateDeathRagdoll(client, prevRagdoll = null, body = null, params = null)
	{
		local isPlayer = client.GetClassname() == "player";
		local clientScope = null;
		if (!isPlayer)
		{
			if (!client.ValidateScriptScope()) return;
			clientScope = client.GetScriptScope();
		}
		
		local isOnFire = false;
		if (Settings.allowBurningCorpse && "isOnFire" in params) isOnFire = params["isOnFire"];
		
		local cl_Origin = client.GetOrigin();
		
		local cl_Angles = null;
		if (isPlayer)
			cl_Angles = QAngle(0, client.EyeAngles().y, 0.0);
		else
			cl_Angles = client.GetAngles();
		
		local cl_model = NetProps.GetPropString(client, "m_ModelName");
		
		local cl_char = null;
		if (isPlayer)
		{ cl_char = NetProps.GetPropInt(client, "m_survivorCharacter"); }
		else
		{ cl_char = clientScope.TempChar; }
		
		if ( body == null || body.GetClassname().find("survivor_death_model") == null && prevRagdoll != null )
		{
			/*local pelvis_Bone = client.LookupBone("ValveBiped.Bip01_Pelvis");
			if (pelvis_Bone >= 0)
			{
				cl_Origin = client.GetBoneOrigin(pelvis_Bone);
			}*/
			
		body = SpawnEntityFromTable("survivor_death_model", {
			//model = cl_model,
			origin = cl_Origin.x.tostring() + " " + cl_Origin.y.tostring() + " " + cl_Origin.z.tostring(),
			angles = cl_Angles.x.tostring() + " " + cl_Angles.y.tostring() + " " + cl_Angles.z.tostring()
		});
			if (body == null) return;
			body.SetModel(cl_model);
			NetProps.SetPropInt(body, "m_nCharacterType", cl_char);
		}
		else if (body == null)
			return;
		
		if (prevRagdoll != null)
			prevRagdoll.Kill();
		
		local clSlot = null;
		if (isPlayer)
			clSlot = client.GetSurvivorSlot();
		else
			clSlot = clientScope.TempSlot;
		local rag_Name = "vscript_defib_ragdolls_rag_"+clSlot;
		
		local pose_str = "";
		if (!Settings.moreStableDefaultPoseSpawn)
		{
			cl_Angles = QAngle(0, 0, 0.0);
			
			local pose_ent = null;
			if (isPlayer)
			{ pose_ent = GetBoneListFromClient( client ); }
			else
			{ pose_ent = client; }
			
			local pelvis_Bone = pose_ent.LookupBone("ValveBiped.Bip01_Pelvis");
			if (pelvis_Bone >= 0)
			{
				cl_Origin = pose_ent.GetBoneOrigin(pelvis_Bone);
			}
			pose_str = GetAnimatingPoseStringAlt(pose_ent, client);
			//pose_str = GetAnimatingPoseString(client);
			//pose_str = "0,-29.36 129.84 -0.48,1,-5.23 -145.79 70.91,2,13.51 -154.89 77.32,3,37.85 -66.14 176.80,4,13.96 114.47 20.11,5,17.59 28.47 -74.75,6,3.24 23.97 -72.78,7,-2.48 -15.43 -10.32,8,5.75 1.15 -43.53,9,-22.32 -126.63 13.74,10,19.87 -119.75 -41.46,11,0.61 39.44 -62.52,12,3.00 45.07 -35.32,13,4.19 5.75 -14.41,14,13.89 57.17 -37.32,15,0.91 173.17 11.18,16,-0.15 147.62 -0.27,17,27.50 -152.71 -114.29"
			/*
			0,-29.36 129.84 -0.48,1,-5.23 -145.79 70.91,2,13.51 -154.89 77.32,3,37.85 -66.14 176.80,4,13.96 114.47 20.11,5,17.59 28.47 -74.75,6,3.24 23.97 -72.78,7,-2.48 -15.43 -10.32,8,5.75 1.15 -43.53,9,-22.32 -126.63 13.74,10,19.87 -119.75 -41.46,11,0.61 39.44 -62.52,12,3.00 45.07 -35.32,13,4.19 5.75 -14.41,14,13.89 57.17 -37.32,15,0.91 173.17 11.18,16,-0.15 147.62 -0.27,17,27.50 -152.71 -114.29
			
			0, 0.00 76.00 90.00,1, -85.23 166.00 90.00,2, -75.38 166.00 90.00,3, -74.47 166.00 90.00,4, -77.15 -14.00 -90.00,5, 17.87 -123.37 76.53,6, 61.00 -95.21 -172.30,7, 59.27 -81.14 -160.08,8, 17.87 95.37 99.16,9, 61.00 67.21 -7.70,10, 59.27 53.14 -19.92,11, 67.42 64.73 68.74,12, 67.42 -92.74 111.05,13, 86.21 -140.21 149.56,14, 0.00 -14.00 0.00,15, 0.00 -14.00 0.00,16, -62.80 -14.00 90.00,17, -89.37 -13.98 89.98
			*/
		}
		
		//local cl_AltOrigin = client.EyePosition();
		
	local ragdoll = SpawnEntityFromTable("prop_ragdoll", {
		model = cl_model,
		spawnflags = 4,
		targetname = rag_Name,
		//gravity = 0,
		origin = cl_Origin.x.tostring() + " " + cl_Origin.y.tostring() + " " + cl_Origin.z.tostring(),
		angles = cl_Angles.x.tostring() + " " + cl_Angles.y.tostring() + " " + cl_Angles.z.tostring(),
			angleOverride = pose_str,
			vscripts = script_think,
			thinkfunction = "DefibRagdollThink",
			classname = "survivor_death_model",
		});
		if (ragdoll == null || !ragdoll.ValidateScriptScope()) return;
		body.__KeyValueFromString("classname", "survivor_death_model_main");
		
		local ragScope = ragdoll.GetScriptScope();
		ragScope.clSlot <- clSlot;
		ragScope.body <- body;
		
		DoEntFire("!self", "SetParent", "!activator", 0, ragdoll, body);
		DoEntFire("!self", "CallScriptFunction", "InitiateRagdoll", 0, null, ragdoll);
		
		body.SetOrigin(ragdoll.GetOrigin());
		
		if (isOnFire)
			DoEntFire("!self", "IgniteLifeTime", "15", 0, null, body);
		
		//local vecForce = NetProps.GetPropVector(client, "m_vecForce");
		
		local vel_Vec = null;
		if (isPlayer)
		{
			vel_Vec = Vector(NetProps.GetPropFloat(client, "m_vecVelocity[0]"),
				NetProps.GetPropFloat(client, "m_vecVelocity[1]"),
				NetProps.GetPropFloat(client, "m_vecVelocity[2]"));
		}
		else
			vel_Vec = client.GetVelocity();
		
		ragdoll.ApplyAbsVelocityImpulse(vel_Vec);
		//ragdoll.ApplyAbsVelocityImpulse(vecForce);
		NetProps.SetPropInt(ragdoll, "m_nForceBone", NetProps.GetPropInt(client, "m_nForceBone"));
		
		local attacker = null;
		if (params)
		{
			if ( ("attacker" in params) )
				attacker = GetPlayerFromUserID( params["attacker"] );
			else if ( ("attackerentid" in params) )
				attacker = EntIndexToHScript( params["attackerentid"] );
			//Msg("m_lastDamageAmount: "+NetProps.GetPropInt(client, "m_lastDamageAmount")+"\n");
		}
		local damageAm = 0;
		if (isPlayer)
		{ damageAm = NetProps.GetPropInt(client, "m_lastDamageAmount"); }
		else
		{ damageAm = clientScope.TempDamage; }
		
		DamageEntity(ragdoll, damageAm+100, attacker);
		
		if (!isPlayer) client = GetPlayerFromUserID(clientScope.TempClient);
		if (client == null || client.GetClassname() != "player") return;
		
		if (!IsPlayerABot(client))
			ragScope.deadCamera <- client;
		
		try
		{
			Left4Bots.Deads[cl_char] <- { dmodel = body, player = client };
		}
		catch (error)
		{}
	}
	
	function OnGameEvent_player_spawn( params )
	{
		local client = Event_GetClient( params, "userid" );
		
		if ( client == null || !client.IsSurvivor() )
			return;
		if (NetProps.GetPropInt(client, "m_iTeamNum") == 4 && (NetProps.GetPropInt(client, "m_fFlags") & (1 << 8))) // FL_FAKECLIENT
			return;
		// I like to occasionally play as Team 4, so i did this check instead of IsPlayerABot lol sorry
		
		FixTilt(client);
	}
	
	/*function OnGameEvent_survivor_rescued( params )
	{
		local client = Event_GetClient( params, "userid" );
		
		if ( client == null || !client.IsSurvivor() ) return;
		
		local entity_Flags = NetProps.GetPropInt(client, "m_fFlags");
		if (entity_Flags & (1 << 8)) // FL_FAKECLIENT
			return;
		
		
	}*/
	
	/*function ConformToPose( client, ragdoll )
	{
		local pose_str = GetAnimatingPoseString(client);
		
		//Msg(pose_str+"\n");
		
		ragdoll.__KeyValueFromString("angleOverride", pose_str);
		
		//local pose_str = GetRagdollPoseString(ragdoll);
		//Msg(pose_str+"\n");
		//
		//local pose_str_2 = GetAnimatingPoseString(client);
		//Msg(pose_str_2+"\n");
	}*/
	
	/*function GetAnimatingPoseString(entity)
	{
		local pOut = "";
		local listCount = NetProps.GetPropInt(entity, "m_BoneFollowerManager.m_iNumBones");
		Msg("listCount: "+listCount+"\n");
		if (listCount <= 0) return "";
		
		for ( local i = 0; i < listCount; i++ )
		{
			if ( i != 0 )
			{
				pOut = pOut+",";
			}
			
			local m_ragAngles = entity.GetBoneAngles(i);
			Msg("m_ragAngles: "+m_ragAngles+"\n");
			local str = i+","+m_ragAngles.x.tointeger()+".2f "+m_ragAngles.y.tointeger()+".2f "+m_ragAngles.z.tointeger()+".2f";
			pOut = pOut+str;
		}
		Msg("pOut: "+pOut+"\n");
		return pOut;
	}*/
	
	function GetAnimatingPoseStringAlt(entity, client)
	{
	//	local function NormalizeVector(vec)
	//	{
	//		return vec.Scale(1.0 / vec.Length());
	//	}
		
		local pOut = "";
		local listCount = NetProps.GetPropInt(entity, "m_BoneFollowerManager.m_iNumBones");
		//Msg("listCount: "+listCount+"\n");
		if (listCount <= 0) return "";
		
		//local cl_Angles = client.EyeAngles();
		
		for ( local i = 0; i < listCount; i++ )
		{
			if ( i != 0 )
			{
				pOut = pOut+",";
			}
			
			local m_ragAngles = client.GetBoneAngles(i); //Msg("m_ragAngles: "+m_ragAngles+"\n");
			//m_ragAngles = Vector(cos(m_ragAngles.x), sin(m_ragAngles.y), m_ragAngles.z);
			//m_ragAngles = Vector(m_ragAngles.x, m_ragAngles.y, m_ragAngles.z);
			//NormalizeVector(m_ragAngles);
			//local m_ragAngles = NetProps.GetPropVectorArray(client, "m_ragAngles", i);
			//Msg(m_ragAngles+"\n");
			local str = format("%d,%.2f %.2f %.2f", i, m_ragAngles.x, m_ragAngles.y, m_ragAngles.z);
			pOut = pOut+str;
		}
		//printl(pOut);
		return pOut;
	}
	
	/*function RAD2DEG(x)
	{ return (x * (180.0 / 3.14159265358979323846)); }
	
	function DEG2RAD(x)
	{ return (x * (3.14159265358979323846 / 180.0)); }*/
	
	/*function AngleMatrix(angles, matrix)
	{
		local sr, sp, sy, cr, cp, cy = 0.0;
	
		SinCos( DEG2RAD( angles.y ), &sy, &cy );
		SinCos( DEG2RAD( angles.p ), &sp, &cp );
		SinCos( DEG2RAD( angles.r ), &sr, &cr );
	
		// matrix = (YAW * PITCH) * ROLL
		matrix[0][0] = cp*cy;
		matrix[1][0] = cp*sy;
		matrix[2][0] = -sp;
	
		// NOTE: Do not optimize this to reduce multiplies! optimizer bug will screw this up.
		matrix[0][1] = sr*sp*cy+cr*-sy;
		matrix[1][1] = sr*sp*sy+cr*cy;
		matrix[2][1] = sr*cp;
		matrix[0][2] = (cr*sp*cy+-sr*-sy);
		matrix[1][2] = (cr*sp*sy+-sr*cy);
		matrix[2][2] = cr*cp;
	
		matrix[0][3] = 0.0f;
		matrix[1][3] = 0.0f;
		matrix[2][3] = 0.0f;
	}*/
	
	/*function GetRagdollPoseString(entity)
	{
		local pOut = "";
		local listCount = NetProps.GetPropInt(entity, "m_ragdoll.listCount");
		
		if (listCount <= 0) return "";
		
		for ( local i = 0; i < listCount; i++ )
		{
			if ( i != 0 )
			{
				pOut = pOut+",";
			}
			
			local m_ragAngles = NetProps.GetPropVectorArray(entity, "m_ragAngles", i);
			
			//local str = "%d,%.2f %.2f %.2f", i, m_ragAngles[i].x, m_ragAngles[i].y, m_ragAngles[i].z;
			local str = i+","+m_ragAngles.x+" "+m_ragAngles.y+" "+m_ragAngles.z;
			pOut = pOut+str;
		}
		
		return pOut;
	}*/
	
	function GetBoneListFromClient( client, typeBool = false )
	{
		local cl_Origin = client.GetOrigin();
		local cl_Angles = client.EyeAngles().y;
		
		local cl_model = NetProps.GetPropString(client, "m_ModelName");
		
		local keyValues =
		{
			model = cl_model,
			solid = 0,
			origin = cl_Origin.x+" "+cl_Origin.y+" "+cl_Origin.z,
			//angles = cl_Angles.x+" "+cl_Angles.y+" "+cl_Angles.z,
			angles = "0 "+cl_Angles+" 0",
			rendermode = 10
			//DisableBoneFollowers = 1,
			//solid = 0
		}
		
		local pose_ent = "prop_dynamic";
		if (typeBool) pose_ent = "commentary_dummy";
		
		pose_ent = SpawnEntityFromTable(pose_ent, keyValues);
		if (pose_ent == null) return null;
		
		DoEntFire("!self", "Kill", "", 0, null, pose_ent);
		
		/*NetProps.SetPropInt(pose_ent, "m_nSequence", NetProps.GetPropInt(client, "m_nSequence"));
		NetProps.SetPropFloat(pose_ent, "m_flCycle", NetProps.GetPropFloat(client, "m_flCycle"));
		NetProps.SetPropInt(pose_ent, "m_flAnimTime", NetProps.GetPropInt(client, "m_flAnimTime"));
		NetProps.SetPropInt(pose_ent, "m_flSimulationTime", NetProps.GetPropInt(client, "m_flSimulationTime"));
		NetProps.SetPropFloat(pose_ent, "m_flPlaybackRate", 0);
		
		// Taken from the Survivor Legs plugin by Lux https://forums.alliedmods.net/showthread.php?t=299560
		for (local i = 1; i < 23; i++)
		{
			NetProps.SetPropFloatArray(pose_ent, "m_flPoseParameter", NetProps.GetPropFloatArray(client, "m_flPoseParameter", i), i); //credit to death chaos for animating legs
		}*/
		
		return pose_ent;
		
		/*local pose_str = GetAnimatingPoseString(client);
		return pose_str;*/
		
	//	//DoEntFire("!self", "DisableMotion", "", 0, null, ragdoll);
	//	DoEntFire("!self", "SetParent", "!activator", 0, pose_ent, ragdoll);
	//	//NetProps.SetPropEntity(ragdoll, "moveparent", pose_ent);
	//	NetProps.SetPropInt(ragdoll, "m_fEffects", 1|512); // EF_BONEMERGE|EF_PARENT_ANIMATES
	//	//NetProps.SetPropEntity(ragdoll, "moveparent", null);
	//	DoEntFire("!self", "ClearParent", "", 0.1, null, ragdoll);
	//	//DoEntFire("!self", "EnableMotion", "", 0, null, ragdoll);
	}
	
	function DamageEntity(ent_val, fl_dmg, attacker)
	{
		if (!fl_dmg)
		fl_dmg = 10.0;
		
		//Msg("Damage: "+fl_dmg+"\n");
		
		local ent_hurtOrig = ent_val;
		if (attacker != null)
			ent_hurtOrig = attacker;
		
		//Msg(attacker+"\n");
		//local ent_val_Origin = ent_val.GetOrigin();
		local ent_hurtOrig_Origin = ent_hurtOrig.GetOrigin();
		if (ent_hurtOrig.GetClassname() == "player")
			ent_hurtOrig_Origin = ent_hurtOrig.EyePosition();
		
		local keyValues =
		{
			Damage = fl_dmg,
			DamageTarget = "!activator",
			//DamageType = 128, // DMG_CLUB
			DamageType = 64+128, // DMG_BLAST
			origin = ent_hurtOrig_Origin.x+" "+ent_hurtOrig_Origin.y+" "+ent_hurtOrig_Origin.z
		}
		
		local hurt = SpawnEntityFromTable("point_hurt", keyValues);
		DoEntFire("!self", "Hurt", "", 0, ent_val, hurt);
		DoEntFire("!self", "Kill", "", 0.1, null, hurt);
	}
	
	function Event_GetClient(params, id_str = "userid")
	{
		if ( !(id_str in params) )
		return null;
		local client = GetPlayerFromUserID( params[id_str] );
		
		return client;
	}
	
	/*function Event_GetEntity(params, id_str = "targetid")
	{
		if ( !(id_str in params) )
		return null;
		local entity = EntIndexToHScript( params[id_str] );
		
		return entity;
	}*/
	
}

defibragdolls.ParseConfigFile();

//if (!FileToString(info_path))
//{
	/*StringToFile(info_path,"THIS IS ONLY AN INFO FILE IN CASE YOU DON'T KNOW WHAT THE SETTINGS DO.\n
	Don't edit this to change the settings.\n
	- allowBurningCorpse (Allow fire damage like Molotovs or Incendiary Ammo to set the body on fire)\n
	- moreStableDefaultPoseSpawn (Make ragdolls spawn in the default pose instead of crumpled up into a ball)");*/
	StringToFile(info_path,"THIS IS ONLY AN INFO FILE IN CASE YOU DON'T KNOW WHAT THE SETTINGS DO.\nDon't edit this to change the settings.\n- allowBurningCorpse (Allow fire damage like Molotovs or Incendiary Ammo to set the body on fire)\n- moreStableDefaultPoseSpawn (Make ragdolls spawn in the default pose instead of crumpled up into a ball)");
//}

__CollectGameEventCallbacks(defibragdolls);