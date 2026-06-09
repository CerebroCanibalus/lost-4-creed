::SimpleBloom_Activator <-
{
    _overlayName = "simplebloom_entity"

    function SpawnOverlay()
    {
        // Matar overlays previos (evita duplicados en player_spawn)
        local old = null;
        while (old = Entities.FindByName(old, _overlayName))
            old.Kill();

        local overlay = SpawnEntityFromTable("env_screenoverlay",
        {
            targetname      = _overlayName,
            OverlayName1    = "effects/shaders/simple_bloom",
            OverlayTime1    = -1,
        });
        if (overlay)
            EntFire(_overlayName, "StartOverlays");
    }

    function KillOverlay()
    {
        local ent = null;
        while (ent = Entities.FindByName(ent, _overlayName)) ent.Kill();
    }

    function OnGameEvent_player_spawn(params)
    {
        SpawnOverlay();
    }

    function OnGameEvent_round_end(params)
    {
        KillOverlay();
    }

    function OnGameEvent_map_transition(params)
    {
        KillOverlay();
    }

    function OnGameEvent_mission_lost(params)
    {
        KillOverlay();
    }
}

__CollectGameEventCallbacks(::SimpleBloom_Activator);
