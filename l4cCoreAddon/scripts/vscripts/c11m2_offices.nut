Msg("Initiating c11m2 scripts\n");

if (SessionState.MapName = "c11m2_offices")
{
	IncludeScript("c11m2_offices_coop", getroottable());
}

EntFire( "func_button", "AddOutput", "OnPressed director:ScriptedPanicEvent:c11m2_offices_minifinale:0:-1", 0 )
EntFire( "func_button", "AddOutput", "OnPressed director:EndScript::55:-1", 0 )