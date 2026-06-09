// item_buffs DESACTIVADO — equipment effects ahora en system_perks_unified.nut (l4cCoreSurvivorGameplay)
// SpawnEntityFromTable("env_soundscape_triggerable", { vscripts = "item_buffs" });

printl("Activating single grab weapons");
SpawnEntityFromTable("logic_versus_random", {
    targetname = "nescius_single_grab_weapons",
    vscripts = "sgw_main_script",
    OnRandom01 = ""
});

if (!("g_MapspawnAddon" in getroottable())) {
    ::g_MapspawnAddon <- {}
    function g_MapspawnAddon::OnGameEvent_round_end(params) {
    ::g_MapspawnAddon.HandleRoundEnd(params);
}

function g_MapspawnAddon::HandleRoundEnd(params) {
        EntFire("nescius_single_grab_weapons", "Kill", "", 0, null)
    }
}

__CollectGameEventCallbacks(::g_MapspawnAddon);
