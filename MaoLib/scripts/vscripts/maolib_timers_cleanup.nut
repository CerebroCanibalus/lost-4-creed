// ============================================================================
// MaoLib — Timer Monitor & Leak Detection
// ============================================================================
// This module MONITORS timer health — it does NOT auto-cleanup timers.
// Each script is responsible for its own timer lifecycle.
//
// FEATURES:
//   - Reports timer state on round_end via PrintTimerStats/GetTimerDebugInfo
//   - Detects timer leaks (timers accumulating across rounds)
//   - Detects stuck timers (active but never executed)
//   - Detects slow timers (high per-execution time, performance warning)
//   - Console commands: DumpTimers() and LastTimerReport()
//
// USAGE:
//   // Check timer health at any time:
//   script ::DumpTimers()
//
//   // View the last round_end report:
//   script ::LastTimerReport()
// ============================================================================

if (!("g_TimersCleanup" in getroottable()))
{
	::g_TimersCleanup <- {
		_prevTimerCount = 0,
		_lastReport = "",
		
		function OnGameEvent_round_end(params) {
			if ( !("MaoLib" in getroottable()) ) return
			
			// 1. Report timer state
			if ( "GetTimerDebugInfo" in ::MaoLib )
			{
				::g_TimersCleanup._lastReport = ::MaoLib.GetTimerDebugInfo()
				printl( ::g_TimersCleanup._lastReport )
			}
			else if ( "PrintTimerStats" in ::MaoLib )
			{
				::MaoLib.PrintTimerStats()
			}
			
			// 2. Leak detection
			if ( "GetTimerTable" in ::MaoLib )
			{
				::g_TimersCleanup.CheckForLeaks()
				::g_TimersCleanup.CheckAbandonedTimers()
				::g_TimersCleanup.CheckSlowTimers()
			}
			
			// 3. Update counter for next round
			if ( "GetTimerCount" in ::MaoLib )
				::g_TimersCleanup._prevTimerCount = ::MaoLib.GetTimerCount()
		}
		
		function OnGameEvent_mission_lost(params) {
			// Timers persist — they self-recreate on next round_start
		}
		
		function OnGameEvent_map_transition(params) {
			// Timers persist — they self-recreate on next round_start
		}
		
		// ============================================================
		// LEAK DETECTION
		// ============================================================
		
		// Detect timers whose count grows round-to-round
		function CheckForLeaks()
		{
			local current = ::MaoLib.GetTimerCount()
			
			if ( _prevTimerCount > 0 && current > _prevTimerCount )
			{
				local diff = current - _prevTimerCount
				printl( "[TIMER-LEAK] " + diff + " timer(s) NOT CLEANED between rounds:" )
				printl( "            Previous: " + _prevTimerCount + " → Current: " + current )
				
				if ( "GetTimerTable" in ::MaoLib )
				{
					local table = ::MaoLib.GetTimerTable()
					foreach ( name, timer in table )
					{
						if ( timer.execCount == 0 )
							printl( "            [POSSIBLE LEAK] '" + name + "' — 0 executions" )
					}
				}
			}
			else if ( _prevTimerCount > 0 && current < _prevTimerCount )
			{
				printl( "[TIMER-OK] Timers reduced: " + _prevTimerCount + " → " + current )
			}
		}
		
		// Detect timers that never executed (possibly broken)
		function CheckAbandonedTimers()
		{
			if ( !("GetTimerTable" in ::MaoLib) ) return
			
			local table = ::MaoLib.GetTimerTable()
			local now = Time()
			local warned = false
			
			foreach ( name, timer in table )
			{
				if ( timer.active && timer.execCount == 0 && ( now - timer.nextRun ) > 5.0 )
				{
					printl( "[TIMER-STUCK] '" + name + "' — active but NEVER executed" )
					warned = true
				}
				
				if ( timer.execCount > 100 && timer.totalTime > 0.5 )
				{
					local avgMs = ( timer.totalTime / timer.execCount ) * 1000
					if ( avgMs > 1.0 )
					{
						printl( "[TIMER-SLOW] '" + name + "' — " + timer.execCount + " exec, avg " + format( "%.2f", avgMs ) + "ms" )
						warned = true
					}
				}
			}
			
			if ( !warned )
				printl( "[TIMER-OK] All timers healthy" )
		}
		
		// Detect timers with high execution time (performance issues)
		function CheckSlowTimers()
		{
			if ( !("GetTimerTable" in ::MaoLib) ) return
			
			local table = ::MaoLib.GetTimerTable()
			local found = false
			
			foreach ( name, timer in table )
			{
				if ( timer.execCount > 0 )
				{
					local avgMs = ( timer.totalTime / timer.execCount ) * 1000
					if ( avgMs > 5.0 )
					{
						printl( "[TIMER-PERF] '" + name + "' — avg " + format( "%.2f", avgMs ) + "ms per exec (HIGH)" )
						found = true
					}
				}
			}
			
			if ( !found )
				printl( "[TIMER-PERF] No performance issues" )
		}
	}
}

// ============================================================
// CONSOLE COMMANDS
// ============================================================
// Type these in the developer console:
//   script ::DumpTimers()       — print current timer debug info
//   script ::LastTimerReport()  — print last round_end report
// ============================================================

if (!("DumpTimers" in getroottable()))
{
	::DumpTimers <- function()
	{
		if ( "MaoLib" in getroottable() && "GetTimerDebugInfo" in ::MaoLib )
		{
			printl( ::MaoLib.GetTimerDebugInfo() )
		}
		else
		{
			printl( "[DumpTimers] MaoLib not available" )
		}
	}
}

if (!("LastTimerReport" in getroottable()))
{
	::LastTimerReport <- function()
	{
		if ( "g_TimersCleanup" in getroottable() && ::g_TimersCleanup._lastReport != "" )
		{
			printl( ::g_TimersCleanup._lastReport )
		}
		else
		{
			printl( "[LastTimerReport] No report available (wait for round_end)" )
		}
	}
}

__CollectGameEventCallbacks(::g_TimersCleanup);

printl("[MaoLib.TimersCleanup] Active — use script DumpTimers() to inspect")
