Msg("Initiating Church Panic Event\n");

EntFire( "@director", "panicevent", "", 0 )
EntFire( "@director", "ScriptedPanicEvent", "c10m3_church_minifinale", 30 )
EntFire( "relay_enable_chuch_zombie_loop", "trigger", "", 90 )