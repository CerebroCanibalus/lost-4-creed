Msg("Lost 4 Creed Custom Infected ENABLED\n");

//Spitter - Orden crítico: butcher ANTES de maolib
IncludeScript("butcher", getroottable());
printl("Custom Spitter working!");

//Hunter
printl("Custom Hunter Scripts working!");

//Jockey
IncludeScript("hound", getroottable());
printl("Custom Jockey Scripts working!");

//Charger
printl("Custom Charger Scripts working!");

//Witch
printl("Custom Witch Scripts working!");

//Boomer
printl("Custom Boomer Scripts working!");

//Hordes
printl("Custom Horde Scripts working!");

//Tank
printl("Custom Tank Scripts working!");

//New Commons
IncludeScript("kamikaze_mob", getroottable());
IncludeScript("corpse_mob", getroottable());
IncludeScript("sewer_mob", getroottable());
printl("Custom Commons working!");

// NOTA: MaoLib es cargado por l4cCoreAddon. NO incluir aquí.
// Si se intenta IncludeScript("maolib") desde este addon y l4cCoreAddon
// no se ha cargado aún (orden de VPKs), todo el script muere.
// MaoLib es dependencia DURA. Si no está cargado, este script fallará rápidamente.