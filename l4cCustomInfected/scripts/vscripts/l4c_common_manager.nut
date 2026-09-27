// ============================================================
// l4c_common_manager.nut — Common Infected Scan Manager v1.0
// Replace 4 separate full-scans with 1 pass + cursor rotation
// ============================================================

if ("L4C_CommonManager" in getroottable()) return;
::L4C_CommonManager <- {
    // Cap: procesamos 30 infected por tick, rotando con cursor
    MAX_PER_TICK = 30
    SCAN_INTERVAL = 0.5       // 2Hz post-reducción

    // --- STATE ---
    _scanCursor = null         // entIndex del último procesado
    _converters = []           // {name, fn(ent, scope)}
    _deathMonitors = {}        // name → fn(idx) → bool (true = remove)
    _tracked = {}              // name → [entIndex, ...]

    // ============================================================
    // PUBLIC API
    // ============================================================

    function RegisterConverter(name, callback)
    {
        foreach (c in _converters)
        {
            if (c.name == name) { c.fn = callback; return; }
        }
        _converters.append({ name = name, fn = callback })
    }

    function UnregisterConverter(name)
    {
        for (local i = _converters.len() - 1; i >= 0; i--)
        {
            if (_converters[i].name == name)
                _converters.remove(i)
        }
    }

    function GetConverterCount() { return _converters.len() }

    function RegisterDeathMonitor(name, callback)
    {
        _deathMonitors[name] <- callback
    }

    function UnregisterDeathMonitor(name)
    {
        if (name in _deathMonitors)
            delete _deathMonitors[name]
    }

    // Añadir entidad a lista de monitoreo de muerte
    function TrackEntity(trackerName, entIndex)
    {
        if (!(trackerName in _tracked))
            _tracked[trackerName] <- []
        _tracked[trackerName].append(entIndex)
    }

    function UntrackEntity(trackerName, entIndex)
    {
        if (trackerName in _tracked)
        {
            local list = _tracked[trackerName]
            for (local i = list.len() - 1; i >= 0; i--)
            {
                if (list[i] == entIndex) { list.remove(i); return; }
            }
        }
    }

    function ClearTracked(trackerName)
    {
        if (trackerName in _tracked)
            delete _tracked[trackerName]
    }

    function ClearAll()
    {
        _converters.clear()
        _deathMonitors.clear()
        _tracked.clear()
        _scanCursor = null
    }

    // ============================================================
    // INIT — timer persistente
    // ============================================================

    function Init()
    {
        MaoLib.AddTimer("common_manager_scan", SCAN_INTERVAL, function() {
            ::L4C_CommonManager._Scan()
            ::L4C_CommonManager._DeathMonitor()
        })
    }

    // ============================================================
    // SCAN — 1 solo pase, capped 30/tick con cursor rotatorio
    // ============================================================

    function _Scan()
    {
        if (_converters.len() == 0) return

        local ent = null

        // Reanudar desde cursor si existe y es válido
        if (_scanCursor != null)
        {
            local cursorEnt = EntIndexToHScript(_scanCursor)
            if (cursorEnt && cursorEnt.IsValid())
                ent = cursorEnt
        }

        local count = 0
        ent = Entities.FindByClassname(ent, "infected")

        while (ent != null && count < MAX_PER_TICK)
        {
            if (ent.IsValid() && ent.GetHealth() > 0 && ent.ValidateScriptScope())
            {
                local scope = ent.GetScriptScope()
                foreach (conv in _converters)
                {
                    try { conv.fn(ent, scope) } catch(e) { printl("[L4C_CommonManager] ERROR in converter '" + conv.name + "': " + e) }
                }
            }

            count++
            _scanCursor = ent.GetEntityIndex()
            ent = Entities.FindByClassname(ent, "infected")
        }

        // Si llegamos al final, reiniciar cursor próximo tick
        if (ent == null)
            _scanCursor = null
    }

    // ============================================================
    // DEATH MONITOR — itera solo tracked lists, no full scan
    // ============================================================

    function _DeathMonitor()
    {
        foreach (name, list in _tracked)
        {
            if (!(name in _deathMonitors)) continue

            local callback = _deathMonitors[name]
            local newList = []

            foreach (idx in list)
            {
                local remove = false
                try { remove = callback(idx) } catch(e) { printl("[L4C_CommonManager] ERROR in death monitor '" + name + "': " + e) }
                if (!remove)
                    newList.append(idx)
            }

            _tracked[name] = newList
        }
    }
}

::L4C_CommonManager.Init()
printl("[L4C_CommonManager] Loaded — max " + ::L4C_CommonManager.MAX_PER_TICK + "/tick, " + ::L4C_CommonManager.SCAN_INTERVAL + "s interval")
