Msg("[RagdollSystem] Survivor Ragdolls Active\n");

local precache1 = SpawnEntityFromTable("env_ragdoll_boogie", {});
if (precache1 != null)
	DoEntFire("!self", "Kill", "0", 0, null, precache1);

local default_folder = "defib_ragdolls";
local info_path = default_folder+"/info.txt";
local settings_path = default_folder+"/settings.cfg";


RagdollSystem <-
{
	Debug = 1 // 0=silent, 1=verbose
	
	Settings =
	{
		allowBurningCorpse = true,
		moreStableDefaultPoseSpawn = true
	}
	
	function Dbg(msg) { if (Debug) printl("[RagdollSystem] "+msg) }
	function DbgWarn(msg) { printl("[RagdollSystem][WARN] "+msg) }
	
	// ====================================================================
	// RAGDOLL TRACKING (replaces entity-script ragdoll_system_think.nut)
	// ====================================================================
	// ActiveRagdolls[slot] = { ragdoll, body, deadCamera, nextTeleportCheck, allowBoogie }
	ActiveRagdolls = {}
	
	// ====================================================================
	// UNIFIED RAGDOLL UPDATE (0.1s timer) — death cam + teleport checks
	// ====================================================================
	function RagdollUpdate()
	{
		local toRemove = []
		local now = Time()
		
		foreach (slot, data in ActiveRagdolls)
		{
			if (!data.ragdoll || !data.ragdoll.IsValid())
			{
				Dbg("RagdollUpdate: ragdoll invalid for slot " + slot + ", removing")
				toRemove.append(slot)
				continue
			}
			
			// Body check — si el death model murió, cleanup
			if (!data.body || !data.body.IsValid())
			{
				Dbg("RagdollUpdate: body invalid for slot " + slot + ", cleanup")
				RemoveSelfForSlot(slot)
				toRemove.append(slot)
				continue
			}
			
			// Death cam: sigue al ragdoll
			FindDeadCamera(data)
			
			// Teleport check: cada 1s, si stuck en geometría
			if (now >= data.nextTeleportCheck)
			{
				data.nextTeleportCheck = now + 1.0
				CheckForTeleport(data)
			}
		}
		
		foreach (slot in toRemove)
			delete ActiveRagdolls[slot]
		
		// Auto-stop timer si no hay ragdolls activos
		if (ActiveRagdolls.len() == 0)
			MaoLib.RemoveTimer("ragdoll_system_update")
	}
	
	// ====================================================================
	// INLINE InitiateRagdoll (antes en ragdoll_system_think.nut)
	// ====================================================================
	function InitiateRagdollInline(ragdoll, body, slot, cameraPlayer)
	{
		if (!ragdoll || !ragdoll.IsValid() || !body || !body.IsValid())
		{
			DbgWarn("InitiateRagdollInline: invalid entities")
			return
		}
		
		// Config colisión y flags
		NetProps.SetPropInt(ragdoll, "m_CollisionGroup", 1) // COLLISION_GROUP_DEBRIS
		NetProps.SetPropInt(ragdoll, "m_iEFlags", (1<<17))
		NetProps.SetPropInt(body, "m_MoveType", 0)
		ragdoll.__KeyValueFromInt("rendermode", 10)
		NetProps.SetPropInt(body, "m_fEffects", 1|512) // EF_BONEMERGE|EF_PARENT_ANIMATES
		
		// Animación de muerte
		local seq = body.LookupActivity("ACT_DIERAGDOLL")
		if (seq != "") body.ResetSequence(seq)
		
		// Registrar InputShock en el body (necesario para entity I/O de defib)
		if (body.ValidateScriptScope())
		{
			local bs = body.GetScriptScope()
			bs.timeTilThink1 <- -1.0
			bs.doThink1 <- false
			bs.InputShock <- function()
			{
				local gt = Time()
				if (timeTilThink1 >= gt && doThink1 == true)
				{
					doThink1 = false
					return true
				}
				timeTilThink1 = gt + 0.05
				doThink1 = true
				
				local rag = self.GetMoveParent()
				if (rag == null || rag.GetClassname() != "survivor_death_model") return true
				
				DoEntFire("!self", "ClearParent", "", 0, null, self)
				DoEntFire("!self", "StartRagdollBoogie", "", 0, null, rag)
				DoEntFire("!self", "SetParent", "!activator", 0, rag, self)
				
				// Find and set boogie values
				local boogie
				while (boogie = Entities.FindByClassname(boogie, "env_ragdoll_boogie"))
				{
					if (boogie.GetMoveParent() == rag)
					{
						NetProps.SetPropFloat(boogie, "m_flBoogieLength", 0.25)
						NetProps.SetPropFloat(boogie, "m_flMagnitude", 150.0)
						break
					}
				}
			}
		}
		
		// Track
		ActiveRagdolls[slot] <- {
			ragdoll = ragdoll
			body = body
			deadCamera = cameraPlayer
			nextTeleportCheck = Time() + 1.0
			allowBoogie = false
		}
		
		// Asegurar timer activo
		MaoLib.AddTimerForce("ragdoll_system_update", 0.1, @() ::RagdollSystem.RagdollUpdate())
		
		Dbg("InitiateRagdollInline: slot " + slot + " tracked")
	}
	
	// ====================================================================
	// DEATH CAM — sigue la cámara del jugador muerto al ragdoll
	// ====================================================================
	function FindDeadCamera(data)
	{
		if (data.deadCamera == null || !data.deadCamera.IsValid()) return
		if (data.deadCamera.GetClassname() != "player") return
		
		local ls = NetProps.GetPropInt(data.deadCamera, "m_lifeState")
		if (ls != 1 && ls != 2) return
		
		if (!NetProps.HasProp(data.deadCamera, "m_iObserverMode")) return
		local obs = NetProps.GetPropInt(data.deadCamera, "m_iObserverMode")
		if (obs == 1 || obs == 2)
			data.deadCamera.SetOrigin(data.ragdoll.GetOrigin())
	}
	
	// ====================================================================
	// CHECK FOR TELEPORT — libera ragdolls atascados en geometría
	// ====================================================================
	function CheckForTeleport(data)
	{
		local pos = data.ragdoll.GetOrigin()
		pos.z -= 4.0
		
		local trace = { start = pos, end = pos, mask = 16395 }
		TraceLine(trace)
		
		if (("startsolid" in trace) && trace.startsolid)
		{
			Dbg("CheckForTeleport: ragdoll stuck in solid, freeing")
			
			// Dañar ragdoll para activar física (Awaken)
			local originStr = data.ragdoll.GetOrigin().x + " " + data.ragdoll.GetOrigin().y + " " + data.ragdoll.GetOrigin().z
			local hurt = SpawnEntityFromTable("point_hurt", {
				Damage = 5,
				DamageTarget = "!activator",
				DamageType = 64+128,
				origin = originStr
			})
			if (hurt)
			{
				DoEntFire("!self", "Hurt", "", 0, data.ragdoll, hurt)
				DoEntFire("!self", "Kill", "", 0.1, null, hurt)
			}
			
			// Teleport ragdoll a sí mismo para forzar reposicionamiento
			local ang = data.ragdoll.GetAngles()
			local tele = SpawnEntityFromTable("point_teleport", {
				origin = originStr,
				angles = ang.x + " " + ang.y + " " + ang.z,
				target = "!activator"
			})
			if (tele)
			{
				DoEntFire("!self", "Teleport", "", 0.3, data.ragdoll, tele)
				DoEntFire("!self", "Kill", "", 0.5, null, tele)
			}
		}
	}
	
	// ====================================================================
	// CLEANUP — teleport + kill (reemplaza RemoveSelf del entity-script)
	// ====================================================================
	function RemoveSelfForSlot(slot)
	{
		if (!(slot in ActiveRagdolls)) return
		local data = ActiveRagdolls[slot]
		if (!data.ragdoll || !data.ragdoll.IsValid()) return
		
		// Encontrar jugador por survivor slot
		local player = null
		for (local p; p = Entities.FindByClassname(p, "player"); )
		{
			if (!p || !p.IsSurvivor()) continue
			if (p.GetSurvivorSlot() != slot) continue
			player = p
			break
		}
		
		if (player != null)
		{
			local plyOrig = player.GetOrigin()
			local ragOrig = data.ragdoll.GetOrigin()
			local dist = (plyOrig - ragOrig).LengthSqr() / 32
			if (dist <= 32 && NetProps.GetPropInt(player, "m_lifeState") == 0)
			{
				// Teleport jugador a la posición del ragdoll
				SetPlayerToMiddle(player, data.ragdoll)
				FixTilt(player)
			}
		}
		
		if (data.body && data.body.IsValid())
			data.body.Kill()
		
		DoEntFire("!self", "Kill", "", 0, null, data.ragdoll)
		
		delete ActiveRagdolls[slot]
		Dbg("RemoveSelfForSlot: slot " + slot + " cleaned up")
	}
	
	function SetPlayerToMiddle(player, ragdoll)
	{
		local parentBone = "ValveBiped.Bip01_Pelvis"
		local boneIdx = -1
		try { boneIdx = ragdoll.LookupBone(parentBone) } catch(e) {}
		if (boneIdx < 0) boneIdx = 0
		
		local origin = ragdoll.GetBoneOrigin(boneIdx)
		
		// Trace contra suelo
		local trace = {
			start = Vector(origin.x, origin.y, origin.z + 35.0),
			end = Vector(origin.x, origin.y, origin.z - 35.0),
			mask = 1174421507
		}
		TraceLine(trace)
		
		local finalPos = origin
		if (trace && ("pos" in trace) && ("hit" in trace) && trace.hit && (!("startsolid" in trace) || !trace.startsolid))
			finalPos = trace.pos
		
		// Teleport via point_teleport (más suave)
		local ang = player.EyeAngles()
		local tele = SpawnEntityFromTable("point_teleport", {
			origin = finalPos.x + " " + finalPos.y + " " + finalPos.z,
			angles = ang.x + " " + ang.y + " " + ang.z,
			target = "!activator"
		})
		if (tele)
		{
			DoEntFire("!self", "Teleport", "", 0, player, tele)
			DoEntFire("!self", "Kill", "", 0, null, tele)
		}
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
		if (client == null) { Dbg("player_death: client null, skip"); return; }
		if (!client.IsSurvivor()) { Dbg("player_death: not survivor, skip"); return; }
		
		local lifeState = NetProps.GetPropInt(client, "m_lifeState");
		// Solo skip si YA está completamente muerto (lifeState 2).
		// Durante player_death, el estado es 1 (dying) o 2 (dead);
		// si es 1 procesamos el ragdoll, si es 2 ya fue manejado.
		if (lifeState == 2) { Dbg("player_death: lifeState=2 (already dead), skip"); return; }
		
		Dbg("player_death: processing survivor uid=" + params.userid + " lifeState=" + lifeState);
		
		local prev_ragdoll = NetProps.GetPropEntity(client, "m_hRagdoll");
		
		local cl_Origin = client.GetOrigin();
		// Buscar death model por proximidad (tolerancia 0.5u)
		// en vez de comparación exacta de floats — más robusto.
		local body = null;
		for (local death_model; death_model = Entities.FindByClassname( death_model, "survivor_death_model" );)
		{
			local dm_Origin = death_model.GetOrigin();
			local dist = (dm_Origin - cl_Origin).LengthSqr();
			if (dist < 0.25) // sqrt(0.25) = 0.5 units tolerance
			{
				body = death_model;
				Dbg("player_death: found death_model at dist " + dist);
				break;
			}
		}
		if (body == null) Dbg("player_death: no death_model found, will spawn new one");
		
		// Guard explícito: si survivordeathanims existe globalmente y es truthy,
		// skip para no interferir con ese sistema (evita el try/catch frágil).
		if ("survivordeathanims" in getroottable() && survivordeathanims)
		{
			Dbg("player_death: survivordeathanims detected, skip");
			return;
		}
		Dbg("player_death: calling CreateDeathRagdoll");
		CreateDeathRagdoll(client, prev_ragdoll, body, params);
		Dbg("player_death: CreateDeathRagdoll done");
	}
	
	function CreateDeathRagdoll(client, prevRagdoll = null, body = null, params = null)
	{
		local isPlayer = client.GetClassname() == "player";
		local clientScope = null;
		if (!isPlayer)
		{
			if (!client.ValidateScriptScope()) { DbgWarn("CreateDeathRagdoll: no script scope for non-player"); return; }
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
		
		local cl_model = client.GetModelName();
		
		local cl_char = null;
		if (isPlayer)
		{ cl_char = NetProps.GetPropInt(client, "m_survivorCharacter"); }
		else
		{ cl_char = clientScope.TempChar; }
		
		Dbg("CreateDeathRagdoll: isPlayer=" + isPlayer + " body=" + body + " prevRagdoll=" + prevRagdoll);
		
		if ( body == null || body.GetClassname().find("survivor_death_model") == null && prevRagdoll != null )
		{
			Dbg("CreateDeathRagdoll: spawning new survivor_death_model (body=" + body + ", prevRagdoll=" + prevRagdoll + ")");
		body = SpawnEntityFromTable("survivor_death_model", {
			origin = cl_Origin.x.tostring() + " " + cl_Origin.y.tostring() + " " + cl_Origin.z.tostring(),
			angles = cl_Angles.x.tostring() + " " + cl_Angles.y.tostring() + " " + cl_Angles.z.tostring()
		});
			if (body == null) { DbgWarn("CreateDeathRagdoll: failed to spawn death model!"); return; }
			body.SetModel(cl_model);
			NetProps.SetPropInt(body, "m_nCharacterType", cl_char);
			Dbg("CreateDeathRagdoll: spawned death_model OK");
		}
		else if (body == null)
		{
			DbgWarn("CreateDeathRagdoll: no body and no prevRagdoll, can't proceed");
			return;
		}
		
		if (prevRagdoll != null)
		{
			Dbg("CreateDeathRagdoll: killing prevRagdoll");
			prevRagdoll.Kill();
		}
		
		local clSlot = null;
		if (isPlayer)
			clSlot = client.GetSurvivorSlot();
		else
			clSlot = clientScope.TempSlot;
		local rag_Name = "ragdoll_system_rag_"+clSlot;
		
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
		}
		
	Dbg("CreateDeathRagdoll: spawning prop_ragdoll for slot " + clSlot);
	local ragdoll = SpawnEntityFromTable("prop_ragdoll", {
		model = cl_model,
		spawnflags = 4,
		targetname = rag_Name,
		origin = cl_Origin.x.tostring() + " " + cl_Origin.y.tostring() + " " + cl_Origin.z.tostring(),
		angles = cl_Angles.x.tostring() + " " + cl_Angles.y.tostring() + " " + cl_Angles.z.tostring(),
			angleOverride = pose_str,
			classname = "survivor_death_model",
		});
		if (ragdoll == null)
		{
			DbgWarn("CreateDeathRagdoll: FAILED to spawn prop_ragdoll!");
			return;
		}
		Dbg("CreateDeathRagdoll: prop_ragdoll spawned OK");
		body.__KeyValueFromString("classname", "survivor_death_model_main");
		
		DoEntFire("!self", "SetParent", "!activator", 0, ragdoll, body);
		
		// Inline InitiateRagdoll (reemplaza entity-script y CallScriptFunction)
		local cameraPlayer = (!IsPlayerABot(client)) ? client : null
		InitiateRagdollInline(ragdoll, body, clSlot, cameraPlayer)
		
		body.SetOrigin(ragdoll.GetOrigin());
		
		if (isOnFire)
			DoEntFire("!self", "IgniteLifeTime", "15", 0, null, body);
		
		local vel_Vec = null;
		if (isPlayer)
		{
			vel_Vec = Vector(NetProps.GetPropFloat(client, "m_vecVelocity[0]"),
				NetProps.GetPropFloat(client, "m_vecVelocity[1]"),
				NetProps.GetPropFloat(client, "m_vecVelocity[2]"));
		}
		else
			vel_Vec = client.GetVelocity();
		
		try { ragdoll.ApplyAbsVelocityImpulse(vel_Vec); } catch(e) { DbgWarn("ApplyAbsVelocityImpulse failed: " + e); }
		NetProps.SetPropInt(ragdoll, "m_nForceBone", NetProps.GetPropInt(client, "m_nForceBone"));
		
		local attacker = null;
		if (params)
		{
			if ( ("attacker" in params) )
				attacker = GetPlayerFromUserID( params["attacker"] );
			else if ( ("attackerentid" in params) )
				attacker = EntIndexToHScript( params["attackerentid"] );
		}
		local damageAm = 0;
		if (isPlayer)
		{ damageAm = NetProps.GetPropInt(client, "m_lastDamageAmount"); }
		else
		{ damageAm = clientScope.TempDamage; }
		
		DamageEntity(ragdoll, damageAm+100, attacker);
		
		Dbg("CreateDeathRagdoll: SUCCESS for slot " + clSlot);
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
	
	
	function GetAnimatingPoseStringAlt(entity, client)
	{
		local pOut = "";
		local listCount = NetProps.GetPropInt(entity, "m_BoneFollowerManager.m_iNumBones");
		if (listCount <= 0) return "";
		
		for ( local i = 0; i < listCount; i++ )
		{
			if ( i != 0 )
				pOut = pOut+",";
			
			local m_ragAngles = client.GetBoneAngles(i);
			local str = format("%d,%.2f %.2f %.2f", i, m_ragAngles.x, m_ragAngles.y, m_ragAngles.z);
			pOut = pOut+str;
		}
		return pOut;
	}
	

	
	function GetBoneListFromClient( client, typeBool = false )
	{
		local cl_Origin = client.GetOrigin();
		local cl_Angles = client.EyeAngles().y;
		
		local cl_model = client.GetModelName();
		
		local keyValues =
		{
			model = cl_model,
			solid = 0,
			origin = cl_Origin.x+" "+cl_Origin.y+" "+cl_Origin.z,
			angles = "0 "+cl_Angles+" 0",
			rendermode = 10
		}
		
		local pose_ent = "prop_dynamic";
		if (typeBool) pose_ent = "commentary_dummy";
		
		pose_ent = SpawnEntityFromTable(pose_ent, keyValues);
		if (pose_ent == null) return null;
		
		DoEntFire("!self", "Kill", "", 0, null, pose_ent);
		
		return pose_ent;
	}
	
	function DamageEntity(ent_val, fl_dmg, attacker)
	{
		if (!fl_dmg) fl_dmg = 10.0;
		
		local ent_hurtOrig = ent_val;
		if (attacker != null)
			ent_hurtOrig = attacker;
		
		local ent_hurtOrig_Origin = ent_hurtOrig.GetOrigin();
		if (ent_hurtOrig.GetClassname() == "player")
			ent_hurtOrig_Origin = ent_hurtOrig.EyePosition();
		
		local keyValues =
		{
			Damage = fl_dmg,
			DamageTarget = "!activator",
			DamageType = 64+128, // DMG_BLAST + DMG_CLUB
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
	
	// ====================================================================
	// ROUND END — cleanup total
	// ====================================================================
	function OnGameEvent_round_end(params)
	{
		MaoLib.RemoveTimer("ragdoll_system_update")
		ActiveRagdolls.clear()
	}
	
}

RagdollSystem.ParseConfigFile();

StringToFile(info_path,"THIS IS ONLY AN INFO FILE IN CASE YOU DON'T KNOW WHAT THE SETTINGS DO.\nDon't edit this to change the settings.\n- allowBurningCorpse (Allow fire damage like Molotovs or Incendiary Ammo to set the body on fire)\n- moreStableDefaultPoseSpawn (Make ragdolls spawn in the default pose instead of crumpled up into a ball)");

__CollectGameEventCallbacks(RagdollSystem);
