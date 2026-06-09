Msg("Initiating c11m3 scripts\n");

if (SessionState.MapName = "c11m3_garage")
{
	IncludeScript("c11m3_garage_coop", getroottable());
}

EntFire( "barricade_gas_can", "AddOutput", "OnBreak @director:ScriptedPanicEvent:c11m3_garage_minifinale:5:-1", 0 )

EntFire( "barricade_gas_can", "AddOutput", "OnBreak @director:EndScript::40:-1", 0 )