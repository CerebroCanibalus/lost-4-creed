/**
 * ============================================================================
 * MaoLib_Input - Sistema de Input Centralizado para L4D2 VScript
 * ============================================================================
 * Reemplaza los 7+ timers de botones que cada perk crea individualmente.
 * Un solo timer Think() itera survivors y detecta pressed/released/held.
 *
 * DEPENDENCIAS: MaoLib (hard dependency, asume que existe)
 * API PUBLICA:
 *   MaoLib.Input.Register(userid, button, eventType, callback, context)
 *   MaoLib.Input.Unregister(userid, button, eventType)
 *   MaoLib.Input.UnregisterAll(userid)
 * ============================================================================
 */

if ("MaoLib_Input_init_guard" in getroottable()) return;
getroottable()["MaoLib_Input_init_guard"] <- true;

::MaoLib.Input <- {
    // ============================================================
    // DEBUG
    // ============================================================
    Debug = 1

    function Dbg(msg)
    {
        if (Debug) printl("[MaoLib.Input][DEBUG] " + msg)
    }

    function DbgWarn(msg)
    {
        printl("[MaoLib.Input][WARN] " + msg)
    }

    // ============================================================
    // ESTADO INTERNO
    // ============================================================

    // Subscribers[userid][button][eventType] = array of { callback, context }
    Subscribers = {}

    // LastButtonMasks[userid] = buttonMask anterior
    LastButtonMasks = {}

    // Timer activo flag
    TimerActive = false

    // Contador de suscriptores total (para auto-pause)
    SubscriberCount = 0

    // ============================================================
    // API PUBLICA
    // ============================================================

    function Register(userid, button, eventType, callback, context = null)
    {
        Dbg("ENTER Register uid=" + userid + " btn=" + button + " evt=" + eventType)

        if (!userid || button == null || !eventType || !callback)
        {
            DbgWarn("ABORT Register: invalid args")
            return false
        }

        if (eventType != "pressed" && eventType != "released" && eventType != "held")
        {
            DbgWarn("ABORT Register: eventType must be pressed|released|held, got '" + eventType + "'")
            return false
        }

        // Inicializar estructura anidada
        if (!(userid in Subscribers))
            Subscribers[userid] <- {}

        if (!(button in Subscribers[userid]))
            Subscribers[userid][button] <- {}

        if (!(eventType in Subscribers[userid][button]))
            Subscribers[userid][button][eventType] <- []

        // Agregar suscriptor
        Subscribers[userid][button][eventType].append({
            callback = callback
            context = context
        })

        SubscriberCount++
        Dbg("Register OK uid=" + userid + " btn=" + button + " evt=" + eventType + " totalSubs=" + SubscriberCount)

        // Auto-init timer en primera suscripcion
        if (!TimerActive)
            Init()

        Dbg("EXIT Register")
        return true
    }

    function Unregister(userid, button, eventType)
    {
        Dbg("ENTER Unregister uid=" + userid + " btn=" + button + " evt=" + eventType)

        if (!(userid in Subscribers))
        {
            Dbg("Unregister: uid not found")
            return false
        }

        if (!(button in Subscribers[userid]))
        {
            Dbg("Unregister: button not found")
            return false
        }

        if (!(eventType in Subscribers[userid][button]))
        {
            Dbg("Unregister: eventType not found")
            return false
        }

        local removed = Subscribers[userid][button][eventType].len()
        SubscriberCount -= removed

        delete Subscribers[userid][button][eventType]

        // Limpiar niveles vacios
        if (Subscribers[userid][button].len() == 0)
            delete Subscribers[userid][button]

        if (Subscribers[userid].len() == 0)
            delete Subscribers[userid]

        Dbg("Unregister OK removed=" + removed + " totalSubs=" + SubscriberCount)

        // Auto-pause si no quedan suscriptores
        if (SubscriberCount <= 0 && TimerActive)
        {
            PauseThink()
        }

        Dbg("EXIT Unregister")
        return true
    }

    function UnregisterAll(userid)
    {
        Dbg("ENTER UnregisterAll uid=" + userid)

        if (!(userid in Subscribers))
        {
            Dbg("UnregisterAll: uid not found")
            return false
        }

        // Contar cuantos eliminamos
        foreach (button, events in Subscribers[userid])
        {
            foreach (eventType, callbacks in events)
            {
                SubscriberCount -= callbacks.len()
            }
        }

        delete Subscribers[userid]
        delete LastButtonMasks[userid]

        Dbg("UnregisterAll OK uid=" + userid + " totalSubs=" + SubscriberCount)

        if (SubscriberCount <= 0 && TimerActive)
        {
            PauseThink()
        }

        Dbg("EXIT UnregisterAll")
        return true
    }

    // ============================================================
    // TIMER / THINK
    // ============================================================

    function Init()
    {
        Dbg("ENTER Init")

        if (TimerActive)
        {
            Dbg("Init: already active")
            return
        }

        MaoLib.AddTimer("maolib_input_think", 0.05, function() { ::MaoLib.Input.Think(); })
        TimerActive = true

        Dbg("Init OK timer registered")
        Dbg("EXIT Init")
    }

    function PauseThink()
    {
        Dbg("ENTER PauseThink")

        if (!TimerActive)
        {
            Dbg("PauseThink: not active")
            return
        }

        MaoLib.RemoveTimer("maolib_input_think")
        TimerActive = false

        Dbg("PauseThink OK timer paused")
        Dbg("EXIT PauseThink")
    }

    function Think()
    {
        // No logs en Think() — corre cada 0.05s, saturaria consola
        if (!TimerActive)
            return

        // Si no hay suscriptores, pausar
        if (SubscriberCount <= 0)
        {
            PauseThink()
            return
        }

        foreach (player in MaoLib.YieldSurvivors())
        {
            if (!player || !player.IsValid())
                continue

            local userid = NetProps.GetPropInt(player, "m_iUserID")
            if (!userid)
                continue

            // Si no hay suscriptores para este uid, saltar
            if (!(userid in Subscribers))
                continue

            local currentMask = player.GetButtonMask()
            local previousMask = 0

            if (userid in LastButtonMasks)
                previousMask = LastButtonMasks[userid]

            // Solo iterar botones que tienen suscriptores para este uid
            foreach (button, events in Subscribers[userid])
            {
                local isCurrent = (currentMask & button) != 0
                local wasPrevious = (previousMask & button) != 0

                // Detectar transiciones
                if (isCurrent && !wasPrevious && "pressed" in events)
                {
                    _FireCallbacks(player, events["pressed"])
                }
                else if (!isCurrent && wasPrevious && "released" in events)
                {
                    _FireCallbacks(player, events["released"])
                }
                else if (isCurrent && "held" in events)
                {
                    // held: dispara en CADA think (0.05s) — el callback decide throttle
                    _FireCallbacks(player, events["held"])
                }
            }

            LastButtonMasks[userid] <- currentMask
        }
    }

    // ============================================================
    // PRIVADO
    // ============================================================

    function _FireCallbacks(player, callbacks)
    {
        foreach (entry in callbacks)
        {
            try
            {
                if (entry.context != null)
                {
                    entry.callback(player, entry.context)
                }
                else
                {
                    entry.callback(player)
                }
            }
            catch (e)
            {
                if (Debug)
                    printl("[MaoLib.Input][ERROR] Callback failed: " + e)
            }
        }
    }
}

printl("[MaoLib.Input] Loaded successfully")
