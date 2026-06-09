/**
 * ============================================================================
 * MaoLib_PlayerState - Registro de Estado por Jugador para L4D2 VScript
 * ============================================================================
 * Unifica las tablas dispersas (State, LastButtonMask, FocusEndTime, etc.)
 * en un solo lugar centralizado.
 *
 * DEPENDENCIAS: MaoLib (hard dependency)
 * EVENTOS: player_disconnect, round_end (central system — allowed)
 * API PUBLICA:
 *   MaoLib.PlayerState.Set(uid, key, value)
 *   MaoLib.PlayerState.Get(uid, key, defaultVal)
 *   MaoLib.PlayerState.Delete(uid, key)
 *   MaoLib.PlayerState.Clear(uid)
 *   MaoLib.PlayerState.Has(uid, key)
 *   MaoLib.PlayerState.GetAll(uid)
 *   MaoLib.PlayerState.RegisterOnClear(name, callback)
 *   MaoLib.PlayerState.UnregisterOnClear(name)
 * ============================================================================
 */

if ("MaoLib_PlayerState_init_guard" in getroottable()) return;
getroottable()["MaoLib_PlayerState_init_guard"] <- true;

::MaoLib.PlayerState <- {
    // ============================================================
    // DEBUG
    // ============================================================
    Debug = 1

    function Dbg(msg)
    {
        if (Debug) printl("[MaoLib.PlayerState][DEBUG] " + msg)
    }

    function DbgWarn(msg)
    {
        printl("[MaoLib.PlayerState][WARN] " + msg)
    }

    // ============================================================
    // ESTADO INTERNO
    // ============================================================

    // Data[userid][key] = value
    Data = {}

    // OnClearCallbacks[name] = function(uid)
    OnClearCallbacks = {}

    // ============================================================
    // API PUBLICA
    // ============================================================

    function Set(uid, key, value)
    {
        Dbg("ENTER Set uid=" + uid + " key=" + key)

        if (!uid || key == null)
        {
            DbgWarn("ABORT Set: invalid args")
            return false
        }

        if (!(uid in Data))
            Data[uid] <- {}

        Data[uid][key] <- value

        Dbg("Set OK uid=" + uid + " key=" + key + " value=" + value)
        Dbg("EXIT Set")
        return true
    }

    function Get(uid, key, defaultVal = null)
    {
        Dbg("ENTER Get uid=" + uid + " key=" + key)

        if (uid in Data && key in Data[uid])
        {
            local val = Data[uid][key]
            Dbg("Get OK uid=" + uid + " key=" + key + " value=" + val)
            Dbg("EXIT Get")
            return val
        }

        Dbg("Get MISS uid=" + uid + " key=" + key + " returning default")
        Dbg("EXIT Get")
        return defaultVal
    }

    function Delete(uid, key)
    {
        Dbg("ENTER Delete uid=" + uid + " key=" + key)

        if (uid in Data && key in Data[uid])
        {
            delete Data[uid][key]
            Dbg("Delete OK uid=" + uid + " key=" + key)

            if (Data[uid].len() == 0)
                delete Data[uid]

            Dbg("EXIT Delete")
            return true
        }

        Dbg("Delete MISS uid=" + uid + " key=" + key)
        Dbg("EXIT Delete")
        return false
    }

    function Clear(uid)
    {
        Dbg("ENTER Clear uid=" + uid)

        if (!(uid in Data))
        {
            Dbg("Clear: uid not found")
            Dbg("EXIT Clear")
            return false
        }

        // Notificar a listeners ANTES de eliminar
        Dbg("Clear: notifying " + OnClearCallbacks.len() + " listeners")
        foreach (name, callback in OnClearCallbacks)
        {
            try
            {
                callback(uid)
            }
            catch (e)
            {
                DbgWarn("OnClear callback '" + name + "' failed: " + e)
            }
        }

        delete Data[uid]

        Dbg("Clear OK uid=" + uid)
        Dbg("EXIT Clear")
        return true
    }

    function Has(uid, key)
    {
        return (uid in Data) && (key in Data[uid])
    }

    function GetAll(uid)
    {
        Dbg("ENTER GetAll uid=" + uid)

        if (uid in Data)
        {
            Dbg("GetAll OK uid=" + uid + " keys=" + Data[uid].len())
            Dbg("EXIT GetAll")
            return Data[uid]
        }

        Dbg("GetAll MISS uid=" + uid)
        Dbg("EXIT GetAll")
        return {}
    }

    function RegisterOnClear(name, callback)
    {
        Dbg("ENTER RegisterOnClear name=" + name)

        if (!name || !callback)
        {
            DbgWarn("ABORT RegisterOnClear: invalid args")
            return false
        }

        OnClearCallbacks[name] <- callback

        Dbg("RegisterOnClear OK name=" + name)
        Dbg("EXIT RegisterOnClear")
        return true
    }

    function UnregisterOnClear(name)
    {
        Dbg("ENTER UnregisterOnClear name=" + name)

        if (name in OnClearCallbacks)
        {
            delete OnClearCallbacks[name]
            Dbg("UnregisterOnClear OK name=" + name)
            Dbg("EXIT UnregisterOnClear")
            return true
        }

        Dbg("UnregisterOnClear MISS name=" + name)
        Dbg("EXIT UnregisterOnClear")
        return false
    }

    // ============================================================
    // LIMPIEZA TOTAL (round_end / mission_lost / etc.)
    // ============================================================

    function ClearAll()
    {
        Dbg("ENTER ClearAll")

        local count = Data.len()

        // Guardar copia de keys para evitar reentrancia
        // (un callback podría llamar a Set/Clear modificando Data mientras iteramos)
        local uids = []
        foreach (uid, _ in Data)
            uids.append(uid)

        // Notificar a todos los listeners para cada uid
        foreach (uid in uids)
        {
            foreach (name, callback in OnClearCallbacks)
            {
                try
                {
                    callback(uid)
                }
                catch (e)
                {
                    DbgWarn("OnClear callback '" + name + "' failed for uid " + uid + ": " + e)
                }
            }
        }

        Data.clear()

        Dbg("ClearAll OK removed=" + count + " uids")
        Dbg("EXIT ClearAll")
        return true
    }
}

// ============================================================
// EVENTOS — Tabla dedicada con __CollectGameEventCallbacks
// Este ES un sistema central, SÍ puede usar eventos.
// ============================================================

::MaoLib_PlayerState_Events <- {
    Debug = 1

    function Dbg(msg)
    {
        if (Debug) printl("[MaoLib.PlayerState.Events][DEBUG] " + msg)
    }

    function OnGameEvent_player_disconnect(params)
    {
        Dbg("ENTER player_disconnect")

        local userid = params.userid
        if (!userid)
        {
            Dbg("ABORT: no userid")
            return
        }

        Dbg("player_disconnect uid=" + userid + " — clearing state")
        ::MaoLib.PlayerState.Clear(userid)

        Dbg("EXIT player_disconnect")
    }

    function OnGameEvent_round_end(params)
    {
        Dbg("ENTER round_end")
        Dbg("round_end — clearing ALL player state")
        ::MaoLib.PlayerState.ClearAll()
        Dbg("EXIT round_end")
    }

    function OnGameEvent_mission_lost(params)
    {
        Dbg("ENTER mission_lost")
        Dbg("mission_lost — clearing ALL player state")
        ::MaoLib.PlayerState.ClearAll()
        Dbg("EXIT mission_lost")
    }
}

__CollectGameEventCallbacks(::MaoLib_PlayerState_Events)

printl("[MaoLib.PlayerState] Loaded successfully")
