//------------------------------------------------------------
// Common Infected Animation Fix — UNIFIED v2
// Replaces common_anim_fix2/4/5 (3×20Hz → 1×5Hz)
// Single iteration checks all 3 custom infected flags
//------------------------------------------------------------

::L4C_CommonAnimFix <- {
    THINK_INTERVAL = 0.5       // 2Hz (vs 3×20Hz = 60Hz antes)

    //--------------------------------------------------------
    function OnGameEvent_round_start(params)
    {
        // Registrar en manager central — se ejecuta tras los conversores
        ::L4C_CommonManager.RegisterConverter("anim_fix", function(ent, scope) {
            if (!("IsKamikaze" in scope) && !("IsCorpse_Eater" in scope) && !("IsSewerWorker" in scope))
                return
            if ("AnimFixApplied" in scope) return
            scope.AnimFixApplied <- true
            local fixEnt = ent
            MaoLib.DelayCall(function() {
                if (!fixEnt || !fixEnt.IsValid() || fixEnt.GetHealth() <= 0) return
                local s2 = fixEnt.GetScriptScope()
                if (!("IsKamikaze" in s2) && !("IsCorpse_Eater" in s2) && !("IsSewerWorker" in s2)) return
                ::L4C_CommonAnimFix.ApplyFix(fixEnt)
            }, 0.5)
        })
    }

    function OnGameEvent_round_end(params)
    {
        ::L4C_CommonManager.UnregisterConverter("anim_fix")
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

            // Check all 3 custom infected flags
            if (!("IsKamikaze" in s) && !("IsCorpse_Eater" in s) && !("IsSewerWorker" in s))
                continue;

            // Prevent repeated application (shared flag name)
            if ("AnimFixApplied" in s)
                continue;

            s.AnimFixApplied <- true;

            // Delay so model + netprops settle
            local fixEnt = ent;
            MaoLib.AddTimer("af_" + fixEnt.GetEntityIndex(), 0.5, function() {
                if (!fixEnt || !fixEnt.IsValid() || fixEnt.GetHealth() <= 0) return;
                local s2 = fixEnt.GetScriptScope();
                if (!("IsKamikaze" in s2) && !("IsCorpse_Eater" in s2) && !("IsSewerWorker" in s2)) return;
                ::L4C_CommonAnimFix.ApplyFix(fixEnt);
            });
        }
    }

    //--------------------------------------------------------
    function ApplyFix(ent)
    {
        if (!ent || !ent.IsValid() || ent.GetHealth() <= 0)
            return;

        // 1) Force animation cycle forward
        try { NetProps.SetPropFloat(ent, "m_flCycle", 1.0); } catch (e) {}

        // 2) Force running gesture
        try {
            NetProps.SetPropIntArray(ent, "m_NetGestureSequence", ent.LookupSequence("ACT_RUN"), 6);
            NetProps.SetPropIntArray(ent, "m_NetGestureActivity", ent.LookupActivity("ACT_RUN"), 6);
            NetProps.SetPropFloatArray(ent, "m_NetGestureStartTime", Time(), 6);
        } catch (e) {}
    }
}

// Register events
__CollectGameEventCallbacks(::L4C_CommonAnimFix)
