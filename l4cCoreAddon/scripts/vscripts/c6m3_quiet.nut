Msg("Quieting director\n");

DirectorOptions <-
{
	ProhibitBosses = true
	SpecialRespawnInterval = 999999
	CommonLimit = 60
}


// number of cans needed to escape.

if ( Director.IsSinglePlayerGame() )
{
	NumCansNeeded <- 10
	Msg("---------------------------SINGLE PLAYER\n");
}
else
{
	NumCansNeeded <- 16
	Msg("---------------------------MULTI PLAYER\n");
}

EntFire( "progress_display", "SetTotalItems", NumCansNeeded )


function GasCanPoured(){}
Footer
© 2023 GitHub, Inc.
Footer navigation
Terms
Privacy
Security
Status
Docs
Contact GitHub
Pricing
API
Training
Blog
About
