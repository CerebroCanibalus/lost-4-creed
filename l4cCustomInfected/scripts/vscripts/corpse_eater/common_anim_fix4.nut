//------------------------------------------------------------
// Shared Common Infected Animation Fix
// Fixes A-posing / frozen commons after model swap
// Activates ONLY if ScriptScope flag is present
//------------------------------------------------------------

nanas_common_anim_fix4 <-
{
	//--------------------------------------------------------
	// CONFIG
	//--------------------------------------------------------
	THINK_INTERVAL = 0.05      // fast but cheap
	STUMBLE_FLAG   = 33554432  // DMG_STUMBLE
	BULLET_FLAG    = 2         // DMG_BULLET

	//--------------------------------------------------------
	function OnGameEvent_round_start(params)
	{
		MaoLib.AddTimer("anim_fix4", THINK_INTERVAL, function() {
			::nanas_common_anim_fix4.Think()
		})
	}

	function OnGameEvent_round_end(params)
	{
		MaoLib.RemoveTimer("anim_fix4")
	}

	//--------------------------------------------------------
	function Think()
	{
		local ent = null;

		while (ent = Entities.FindByClassname(ent, "infected"))
		{
			if (!ent || !ent.IsValid() || ent.GetHealth() <= 0)
				continue;

			if (!ent.ValidateScriptScope())
				continue;

			local s = ent.GetScriptScope();

			//------------------------------------------------
			// REQUIRED FLAG (set by other mods)
			//------------------------------------------------
			if (!("IsCorpse_Eater" in s))
				continue;

			//------------------------------------------------
			// Prevent repeated application
			//------------------------------------------------
			if ("AnimFixApplied" in s)
				continue;

			s.AnimFixApplied <- true;

			//------------------------------------------------
			// Delay slightly so model + netprops settle
			//------------------------------------------------
			local fixEnt = ent;  // capture per-iteration (evita closure bug de loop variable)
			MaoLib.AddTimer("af4_" + fixEnt.entindex(), 0.5, function() {
				if (!fixEnt || !fixEnt.IsValid() || fixEnt.GetHealth() <= 0) return;
				local s2 = fixEnt.GetScriptScope();
				if (!("IsCorpse_Eater" in s2)) return;
				::nanas_common_anim_fix4.ApplyFix(fixEnt);
			});
		}
	}

	//--------------------------------------------------------
	function ApplyFix(ent)
	{
		if (!ent || !ent.IsValid() || ent.GetHealth() <= 0)
			return;

		//----------------------------------------------------
		// 1) Fake stumble (break animation lock)
		//----------------------------------------------------
		ent.TakeDamage(0.0, STUMBLE_FLAG, null);

		//----------------------------------------------------
		// 2) Bullet nudge (forces anim state update)
		//----------------------------------------------------
		ent.TakeDamage(1, BULLET_FLAG, null);

		//----------------------------------------------------
		// 3) Force animation cycle forward
		//----------------------------------------------------
		try
		{
			NetProps.SetPropFloat(ent, "m_flCycle", 1.0);
		}
		catch (e) {}

		//----------------------------------------------------
		// 4) Force running gesture
		//----------------------------------------------------
		try
		{
			NetProps.SetPropIntArray(
				ent,
				"m_NetGestureSequence",
				ent.LookupSequence("ACT_RUN"),
				6
			);

			NetProps.SetPropIntArray(
				ent,
				"m_NetGestureActivity",
				ent.LookupActivity("ACT_RUN"),
				6
			);

			NetProps.SetPropFloatArray(
				ent,
				"m_NetGestureStartTime",
				Time(),
				6
			);
		}
		catch (e) {}
	}
}

//------------------------------------------------------------
// REGISTER
//------------------------------------------------------------
::nanas_common_anim_fix4 <- nanas_common_anim_fix4;
__CollectGameEventCallbacks(nanas_common_anim_fix4)
