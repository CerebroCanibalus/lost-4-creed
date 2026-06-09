body_sequence_rag <- "";
//body_sequence_defib <- "";
parentBone <- "ValveBiped.Bip01_Pelvis";

if (!("clSlot" in this)) clSlot <- null;
if (!("body" in this)) body <- null;

//local script_1 = "vscript_script_defibshock";

local allowBoogie = false;

local allowDeadCam = true;
deadCamera <- null;

function InitiateRagdoll()
{
	if ( this.body == null || !this.body.IsValid() ) { RemoveSelf(); return; }
	
	NetProps.SetPropInt(self, "m_CollisionGroup", 1); // COLLISION_GROUP_DEBRIS
	NetProps.SetPropInt(self, "m_iEFlags", (1<<17));
	
	NetProps.SetPropInt(this.body, "m_MoveType", 0);
	
	self.__KeyValueFromInt("rendermode", 10);
	
	NetProps.SetPropInt(this.body, "m_fEffects", 1|512); // EF_BONEMERGE|EF_PARENT_ANIMATES
	
	body_sequence_rag = this.body.LookupActivity("ACT_DIERAGDOLL");
	this.body.ResetSequence(body_sequence_rag);
	
	//DoEntFire("!self", "RunScriptFile", script_1, 0, null, this.body);
	if (!this.body.ValidateScriptScope()) return;
	local bodyScope = this.body.GetScriptScope();
	
	bodyScope.timeTilThink1 <- -1.0;
	bodyScope.doThink1 <- false;
	bodyScope.InputShock <- function()
	{
		// This think stuff is so we don't run into an infinite loop when we call Shock again
		local game_time = Time();
		if (timeTilThink1 >= game_time && doThink1 == true)
		{
			doThink1 = false;
			return true;
		}
		timeTilThink1 = game_time+0.05;
		doThink1 = true;
		
		local moveparent = self.GetMoveParent();
		
		if (moveparent == null || moveparent.GetClassname() != "survivor_death_model") return true;
		// ^ actually checking for prop_ragdoll
		DoEntFire("!self", "ClearParent", "", 0, null, self);
		DoEntFire("!self", "CallScriptFunction", "AllowBoogie", 0, null, moveparent);
		DoEntFire("!self", "StartRagdollBoogie", "", 0, null, moveparent);
		DoEntFire("!self", "SetParent", "!activator", 0, moveparent, self);
		DoEntFire("!self", "CallScriptFunction", "DisallowBoogie", 0, null, moveparent);
		DoEntFire("!self", "Shock", "", 0.01, null, self);
		// Do shock again because clearing parent clears the shock effect
		
		DoEntFire("!self", "CallScriptFunction", "SetBoogieValues", 0.01, null, moveparent);
	}
	
	//body_sequence_defib = this.body.LookupActivity("ACT_TERROR_DEFIBRILLATOR_SHOCK");
	
	//NetProps.SetPropInt(self, "m_nCharacterType", NetProps.GetPropInt(this.body, "m_nCharacterType"));
	//Msg("m_nCharacterType: "+NetProps.GetPropInt(self, "m_nCharacterType")+"\n");
}

local timeTilThink1 = -1.0;
local timeTilThink2 = -1.0;
function DefibRagdollThink()
{
	local game_time = Time();
	if (timeTilThink1 < game_time)
	{
		timeTilThink1 = game_time+1.0;
		CheckForTeleport();
	}
	if (timeTilThink2 < game_time)
	{
		timeTilThink2 = game_time+0.1;
		if (this.body == null || !this.body.IsValid()) { RemoveSelf(); return 1.0; }
	}
	
	FindDeadCamera();
	
	return 0.033;
}

function SetBoogieValues()
{
	// Boogie entity is env_ragdoll_boogie. Try to find some kind of trickery to set it's time limit
	// without potentially affecting other boogie entities
	local boogie = FindBoogie();
	if (boogie != null)
	{
		NetProps.SetPropFloat(boogie, "m_flBoogieLength", 0.25);
		NetProps.SetPropFloat(boogie, "m_flMagnitude", 150.0);
	}
}

function InputStartRagdollBoogie()
{
	//Msg("allowBoogie: "+allowBoogie+"\n");
	// The Boogie input will remove all children from a ragdoll, so we have to deny it when body is parented
	return allowBoogie;
	// This one works as of now
	
	/*
	if (this.body == null || !this.body.IsValid()) return true;
	
	DoEntFire("!self", "ClearParent", "", 0, null, this.body);
	DoEntFire("!self", "SetParent", "!activator", 0.02, self, this.body);
	*/
}

function InputBecomeRagdoll()
{
	// DON'T do this under any circumstances.
	// I know people really like BecomeRagdoll'ing the damn death models, but this is already a ragdoll damn you
	return false;
}

function AllowBoogie()
{ allowBoogie = true; }

function DisallowBoogie()
{ allowBoogie = false; }

function FindBoogie()
{
	local boogie = Entities.FindByClassname(null, "env_ragdoll_boogie");
	for ( boogie; boogie != null; boogie = Entities.FindByClassname(boogie, "env_ragdoll_boogie"))
	{
		local moveparent = boogie.GetMoveParent();
		if (moveparent == null || moveparent != self) continue;
		
		return boogie;
	}
	return null;
}

function FindDeadCamera()
{
	if (!allowDeadCam) return;
	if (deadCamera == null || !deadCamera.IsValid() || deadCamera.GetClassname() != "player" || (NetProps.GetPropInt(deadCamera, "m_lifeState") != 1 && NetProps.GetPropInt(deadCamera, "m_lifeState") != 2)) return;
	
	if (!NetProps.HasProp(deadCamera, "m_iObserverMode"))
	{
		allowDeadCam = false;
		return;
	}
	
	local obs_mode = NetProps.GetPropInt(deadCamera, "m_iObserverMode");
	// if OBS_MODE_DEATHCAM or OBS_MODE_FREEZECAM then death cam follow time
	if (obs_mode == 1 || obs_mode == 2)
		deadCamera.SetOrigin(self.GetOrigin());
	else
		allowDeadCam = false;
	
	/*int iRagdoll = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");
	if(iRagdoll == INVALID_ENT_REFERENCE || iRagdoll != EntRefToEntIndex(iTrackedRagdollRef[iClient]))
	{
		SDKUnhook(iClient, SDKHook_PostThinkPost, FollowCam);
		return;
	}
	
	float vecClientPos[3];
	float vecRagdollPos[3];
	
	GetAbsOrigin(iClient, vecClientPos);
	GetAbsOrigin(iRagdoll, vecRagdollPos);
	
	if(GetVectorDistance(vecClientPos, vecRagdollPos) > 250.0)
	{
		TeleportEntity(iClient, vecRagdollPos, NULL_VECTOR, NULL_VECTOR);
		return;
	}
	
	float vecResult[3];
	VectorLerp(vecClientPos, vecRagdollPos, 0.05, vecResult);
	
	if(GetVectorDistance(vecClientPos, vecResult) > 1.0)
	{
		TeleportEntity(iClient, vecResult, NULL_VECTOR, NULL_VECTOR);
	}*/
}

function RemoveSelf()
{
	local player = null;
	for (local loopPly; loopPly = Entities.FindByClassname( loopPly, "player" );)
	{
		if ( loopPly == null || !loopPly.IsSurvivor() )
			continue;
		
		local theirSlot = loopPly.GetSurvivorSlot();
		if (theirSlot != clSlot) continue;
		player = loopPly;
		break;
	}
	/*local attach_bone = GetAttachmentBoneOrigin();
	if (attach_bone != Vector())
	{
		local player = Entities.FindByClassnameNearest("player", attach_bone, 25.0);*/
		if (player != null)
		{
			local ply_origin = player.GetOrigin();
			local body_origin = self.GetOrigin();
			local distance = (ply_origin-body_origin).LengthSqr() / 32;
			//printl(self+"'s distance to body is: "+distance);
			//printl("sequence: "+player.GetSequenceName(player.GetSequence()));
			if (distance <= 32 && NetProps.GetPropInt(player, "m_lifeState") == 0)
			{
				SetToMiddle(player);
				defibragdolls.FixTilt(player);
			}
		}
	//}
	DoEntFire("!self", "Kill", "", 0, null, self);
}

// Ported over from Fainting Ragdolls
function SetToMiddle(target, immediate = false, trace = true)
{
	if (target.GetClassname() != "player")
		immediate = false;
	
	local parent_bone = self.LookupBone(parentBone);
	if (parent_bone < 0) parent_bone = 0;
	
	local origin = self.GetBoneOrigin(parent_bone);
	local origin_max_heightcheck = 35.0;
	
	local trace_Table = {};
	if (trace)
	{
		trace_Table =
		{
			start = Vector(origin.x, origin.y, origin.z+origin_max_heightcheck),
			end = Vector(origin.x, origin.y, origin.z-origin_max_heightcheck),
			mask = 1174421507 // TRACE_MASK_SHOT
			// https://github.com/jacob404/Official-Vscripts-Decompiled/blob/5017fc6170ae9aa2299cba2c70e05de871090a01/update/rocketdude/rd_utils.nut#L11
		}
		TraceLine(trace_Table);
	}
	
	local final_pos = origin;
	
	if (trace && developer()) g_ModeScript.DeepPrintTable(trace_Table);
	if (trace && trace_Table && ("pos" in trace_Table) && ("hit" in trace_Table) && trace_Table.hit && (!("startsolid" in trace_Table) || !trace_Table.startsolid))
	//if (trace && trace_Table && trace_Table.hit)
		final_pos = trace_Table.pos;
	
	switch (immediate)
	{
		case true: 
		{
			target.SetOrigin(final_pos);
			break;
		}
		default: 
		{
			//DoEntFire("!self", "RunScriptCode", "self.SetOrigin(Vector("+final_pos.x+", "+final_pos.y+", "+final_pos.z+"));", 0.01, null, client);
			local cl_Angles = QAngle(0, 0, 0);
			if (target.GetClassname() == "player") cl_Angles = target.EyeAngles();
			local keyValues =
			{
				origin = final_pos.x+" "+final_pos.y+" "+final_pos.z,
				angles = cl_Angles.x+" "+cl_Angles.y+" "+cl_Angles.z,
				target = "!activator"
			};
			
			local point_tele = SpawnEntityFromTable("point_teleport", keyValues);
			DoEntFire("!self", "Teleport", "", 0, target, point_tele);
			DoEntFire("!self", "Kill", "", 0, null, point_tele);
			break;
		}
	}
}

local backupAttachOrigin = null;

// turns out i don't really need to set attachments, only set movetype to none
// fuck me
/*function DoAttachments(enforced = false)
{
	if ( this.body == null || !this.body.IsValid() ) return;
	
	if (!enforced)
	{
		local attach_bone = GetAttachmentBoneOrigin();
		if (attach_bone == null) return;
		
		local body_origin = this.body.GetOrigin();
		local distance = (body_origin-attach_bone).LengthSqr();
		//Msg(self+"'s distance to this.body is: "+distance+"\n");
		
		if (distance > 10)
		{
			DoAttachments(true);
			return;
		}
		
		if (NetProps.GetPropInt(this.body, "m_iParentAttachment") > 0) return;
	}
	
	NetProps.SetPropInt(this.body, "m_MoveType", 0);
}*/

function CheckForTeleport()
{
	local self_origin = self.GetOrigin();
	self_origin = Vector(self_origin.x, self_origin.y, self_origin.z-4.0);
	
	//local distance = (self_origin-lastOrigin).Length();
	//Msg(self+"'s origin distance to old origin distance is: "+distance+"\n");
	
	local trace_InSolid =
	{
		start = self_origin,
		end = self_origin,
		//mask = 33636363 // TRACE_MASK_PLAYER_SOLID
		mask = 16395 // MASK_SOLID_BRUSHONLY
	}
	TraceLine(trace_InSolid);
	
	if (("startsolid" in trace_InSolid) && trace_InSolid.startsolid)
	{
		//Awaken();
		SetupTelePose();
		//SetToMiddle(self);
		DoEntFire("!self", "CallScriptFunction", "Awaken", 0.1, null, self);
		DoEntFire("!self", "RunScriptCode", "SetToMiddle(self)", 0.3, null, self);
	}
}

function Awaken()
{
	local self_origin = self.GetOrigin();
	
	local keyValues =
	{
		Damage = 5,
		DamageTarget = "!activator",
		DamageType = 64+128, // DMG_BLAST + DMG_CLUB
		origin = self_origin.x+" "+self_origin.y+" "+self_origin.z
	}
	
	local hurt = SpawnEntityFromTable("point_hurt", keyValues);
	DoEntFire("!self", "Hurt", "", 0, self, hurt);
	DoEntFire("!self", "Kill", "", 0, null, hurt);
}

function SetupTelePose()
{
	local self_origin = self.GetOrigin();
	local self_angles = self.GetAngles();
	
	local keyValues =
	{
		origin = self_origin.x+" "+self_origin.y+" "+self_origin.z,
		angles = self_angles.x+" "+self_angles.y+" "+self_angles.z,
		target = "!activator"
	}
	
	local point_tele = SpawnEntityFromTable("point_teleport", keyValues);
	DoEntFire("!self", "Teleport", "", 0, self, point_tele);
	DoEntFire("!self", "Kill", "", 0, null, point_tele);
}

/*function GetAttachmentBoneOrigin()
{
	local attach_bone = 1;
	if ((attach_bone = self.GetAttachmentOrigin(attach_bone)) != Vector())
	{
		return attach_bone;
	}
	return null;
}*/