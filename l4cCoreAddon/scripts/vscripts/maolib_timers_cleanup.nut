// MaoLib Timer Manager — Monitor de estadísticas (NO auto-cleanup)
// Cada script gestiona su propio ciclo de vida de timers.
// Usa table + __CollectGameEventCallbacks.
//
// Load this after maolib.nut

if (!("g_TimersCleanup" in getroottable()))
{
	::g_TimersCleanup <- {
		// ============================================================
		// MONITOR DE TIMERS — NO auto-cleanup
		// Cada script gestiona su propio ciclo de vida.
		// ============================================================
		
		_prevTimerCount = 0,   // Para detección de fugas
		_lastReport = "",      // Último reporte generado
		
		function OnGameEvent_round_end(params) {
			if ( !("MaoLib" in getroottable()) ) return
			
			// 1. Reporte completo de timers
			if ( "GetTimerDebugInfo" in ::MaoLib )
			{
				::g_TimersCleanup._lastReport = ::MaoLib.GetTimerDebugInfo()
				printl( ::g_TimersCleanup._lastReport )
			}
			else if ( "PrintTimerStats" in ::MaoLib )
			{
				::MaoLib.PrintTimerStats()
			}
			
			// 2. Detección de fugas (timers que crecen entre rondas)
			if ( "GetTimerTable" in ::MaoLib )
			{
				::g_TimersCleanup.CheckForLeaks()
				::g_TimersCleanup.CheckAbandonedTimers()
				::g_TimersCleanup.CheckSlowTimers()
			}
			
			// 3. Actualizar contador para próxima ronda
			if ( "GetTimerCount" in ::MaoLib )
				::g_TimersCleanup._prevTimerCount = ::MaoLib.GetTimerCount()
		}
		
		function OnGameEvent_mission_lost(params) {
			// No limpiamos — los timers se recrean en el próximo round_start
		}
		
		function OnGameEvent_map_transition(params) {
			// No limpiamos — los timers se recrean en el próximo round_start
		}
		
		// ============================================================
		// DETECCIÓN DE PROBLEMAS
		// ============================================================
		
		// Detecta timers cuyo contador crece ronda a ronda (posible leak)
		function CheckForLeaks()
		{
			local current = ::MaoLib.GetTimerCount()
			
			if ( _prevTimerCount > 0 && current > _prevTimerCount )
			{
				local diff = current - _prevTimerCount
				printl( "[TIMER-LEAK] " + diff + " timer(s) SIN LIMPIAR entre rondas:" )
				printl( "            Anterior: " + _prevTimerCount + " → Actual: " + current )
				
				// Identificar QUÉ timers son nuevos (ejecución 0, podrían ser huérfanos)
				if ( "GetTimerTable" in ::MaoLib )
				{
					local table = ::MaoLib.GetTimerTable()
					foreach ( name, timer in table )
					{
						if ( timer.execCount == 0 )
							printl( "            [POSIBLE LEAK] '" + name + "' — 0 ejecuciones" )
					}
				}
			}
			else if ( _prevTimerCount > 0 && current < _prevTimerCount )
			{
				printl( "[TIMER-OK] Timers reducidos: " + _prevTimerCount + " → " + current )
			}
		}
		
		// Detecta timers que nunca se ejecutaron (podrían estar rotos)
		function CheckAbandonedTimers()
		{
			if ( !("GetTimerTable" in ::MaoLib) ) return
			
			local table = ::MaoLib.GetTimerTable()
			local now = Time()
			local warned = false
			
			foreach ( name, timer in table )
			{
				// Timer activo pero nunca ejecutado y está retrasado
				if ( timer.active && timer.execCount == 0 && ( now - timer.nextRun ) > 5.0 )
				{
					printl( "[TIMER-STUCK] '" + name + "' — activo pero NUNCA ejecutado" )
					warned = true
				}
				
				// Timer con muchas ejecuciones en poco tiempo (posible hot loop)
				if ( timer.execCount > 100 && timer.totalTime > 0.5 )
				{
					local avgMs = ( timer.totalTime / timer.execCount ) * 1000
					if ( avgMs > 1.0 )
					{
						printl( "[TIMER-SLOW] '" + name + "' — " + timer.execCount + " ejec, promedio " + format( "%.2f", avgMs ) + "ms" )
						warned = true
					}
				}
			}
			
			if ( !warned )
				printl( "[TIMER-OK] Todos los timers saludables" )
		}
		
		// Detecta timers con tiempo de ejecución alto (rendimiento)
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
						printl( "[TIMER-PERF] '" + name + "' — promedio " + format( "%.2f", avgMs ) + "ms por ejec (ALTO)" )
						found = true
					}
				}
			}
			
			if ( !found )
				printl( "[TIMER-PERF] Sin problemas de rendimiento" )
		}
	}
	
	// ============================================================
	// COMANDO DE CONSOLA
	// Uso:  script ::DumpTimers()
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
				printl( "[DumpTimers] MaoLib no disponible" )
			}
		}
	}
	
	// ============================================================
	// COMANDO DE CONSOLA — Último reporte
	// Uso:  script ::LastTimerReport()
	// ============================================================
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
				printl( "[LastTimerReport] No hay reporte disponible (esperar round_end)" )
			}
		}
	}
	__CollectGameEventCallbacks(::g_TimersCleanup);
}

printl("[MaoLib.TimersCleanup] Active");
