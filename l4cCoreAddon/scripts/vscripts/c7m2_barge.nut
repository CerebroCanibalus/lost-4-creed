//-----------------------------------------------------
//
//
//-----------------------------------------------------
Msg("SQUIRREL c7m2_barge script\n");

BargeCommonLimit <- 70	// use a lower common limit to combat infected related perf issues

if ( Director.IsPlayingOnConsole() )
{
	BargeCommonLimit <- 70
}


DirectorOptions <-
{
	CommonLimit = BargeCommonLimit	
}

