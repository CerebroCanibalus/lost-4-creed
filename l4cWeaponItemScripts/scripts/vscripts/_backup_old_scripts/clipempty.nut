// ===================================
// clipempty.nut v2.0 - Optimized
// ===================================
// Detects empty clip sounds for survivors
// Reduced from 100Hz to 10Hz timer
// Eliminated VSLib timer system (info_target + AddThinkToEnt leak)
// Simplified 16-branch if-else into table lookups
// Reduced 8 sounds per event to 2
// Added round_end cleanup

::ClipEmpty <-
{
	// Track last known clip state per player (by userid)
	// 0 = unknown/loaded, 1 = empty (rifle), 2 = empty (pistol)
	RifleState = {}
	PistolState = {}
	
	// Sound cooldown per player to prevent spam
	LastSoundTime = {}
	SOUND_COOLDOWN = 0.3
	
	RIFLE_WEAPONS = {
		weapon_smg = true,
		weapon_smg_mp5 = true,
		weapon_smg_silenced = true,
		weapon_rifle = true,
		weapon_rifle_ak47 = true,
		weapon_rifle_desert = true,
		weapon_rifle_sg552 = true,
		weapon_rifle_m60 = true,
		weapon_sniper_awp = true,
		weapon_sniper_military = true,
		weapon_sniper_scout = true,
		weapon_hunting_rifle = true
	}
	
	PISTOL_WEAPONS = {
		weapon_pistol = true,
		weapon_pistol_magnum = true
	}
}

function ::ClipEmpty::HandleRoundStart(params)
{
	::ClipEmpty.RifleState.clear();
	::ClipEmpty.PistolState.clear();
	::ClipEmpty.LastSoundTime.clear();
}

function ::ClipEmpty::HandleRoundEnd(params)
{
	local timer = Entities.FindByName(null, "clipempty123");
	if (timer != null && timer.IsValid())
	{
		timer.Kill();
	}
}

::ClipEmpty.PlayEmptySound <- function(player, isPistol)
{
	local uid = player.GetPlayerUserId();
	local now = Time();
	
	// Cooldown check
	if (uid in ::ClipEmpty.LastSoundTime)
	{
		if (now - ::ClipEmpty.LastSoundTime[uid] < ::ClipEmpty.SOUND_COOLDOWN)
			return;
	}
	::ClipEmpty.LastSoundTime[uid] <- now;
	
	local sound = isPistol ? "weapons/clipempty_pistol.wav" : "weapons/clipempty_rifle.wav";
	EmitSoundOn(sound, player);
}

::clipempty_think <- function()
{
	local ent = null;
	while (ent = Entities.FindByClassname(ent, "player"))
	{
		if (NetProps.GetPropInt(ent, "m_lifeState") != 0 || !ent.IsSurvivor())
			continue;
		
		local uid = ent.GetPlayerUserId();
		local weapon = ent.GetActiveWeapon();
		if (weapon == null)
			continue;
		
		local wpc = weapon.GetClassname();
		local clip = weapon.Clip1();
		local maxClip = weapon.GetMaxClip1();
		local isAttacking = ent.GetButtonMask() & 1;
		
		// --- RIFLE EMPTY CLIP ---
		if (wpc in ::ClipEmpty.RIFLE_WEAPONS)
		{
			local wasEmpty = (uid in ::ClipEmpty.RifleState) ? ::ClipEmpty.RifleState[uid] : false;
			
			if (clip == 0 && !wasEmpty)
			{
				// Just became empty
				::ClipEmpty.RifleState[uid] <- true;
				if (isAttacking)
				{
					::ClipEmpty.PlayEmptySound(ent, false);
				}
			}
			else if (clip > 0 && wasEmpty)
			{
				// Reloaded, reset state
				::ClipEmpty.RifleState[uid] <- false;
			}
		}
		// --- PISTOL EMPTY CLIP ---
		else if (wpc in ::ClipEmpty.PISTOL_WEAPONS)
		{
			local wasEmpty = (uid in ::ClipEmpty.PistolState) ? ::ClipEmpty.PistolState[uid] : false;
			
			// Special case: dual pistols have 30 max clip, single has 15
			local emptyThreshold = (maxClip == 30) ? 1 : 0;
			
			if (clip <= emptyThreshold && !wasEmpty)
			{
				::ClipEmpty.PistolState[uid] <- true;
				if (isAttacking)
				{
					::ClipEmpty.PlayEmptySound(ent, true);
				}
			}
			else if (clip > emptyThreshold && wasEmpty)
			{
				::ClipEmpty.PistolState[uid] <- false;
			}
		}
	}
}

// Spawn timer at 10Hz (0.1s) instead of 100Hz (0.01s)
if (!Entities.FindByName(null, "clipempty123"))
{
	SpawnEntityFromTable("logic_timer", {
		targetname = "clipempty123",
		RefireTime = 0.1,
		OnTimer = "!self,RunScriptCode,::clipempty_think()"
	});
}

function ::ClipEmpty::OnGameEvent_round_start(params) { ::ClipEmpty.HandleRoundStart(params); }
function ::ClipEmpty::OnGameEvent_round_end(params) { ::ClipEmpty.HandleRoundEnd(params); }
__CollectGameEventCallbacks(::ClipEmpty);
