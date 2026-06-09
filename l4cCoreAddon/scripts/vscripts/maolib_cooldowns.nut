/**
 * ============================================================================
 * MaoLib_Cooldowns - Gestor de Cooldowns con Notificacion Automatica
 * ============================================================================
 * Sistema unificado de cooldowns por jugador. Notificacion automatica
 * cuando un cooldown expira.
 *
 * DEPENDENCIAS: MaoLib (hard dependency)
 *               MaoLib.PlayerState (optional — se usa si existe)
 * API PUBLICA:
 *   MaoLib.Cooldowns.Start(uid, name, duration)
 *   MaoLib.Cooldowns.IsReady(uid, name)
 *   MaoLib.Cooldowns.GetRemaining(uid, name)
 *   MaoLib.Cooldowns.Reset(uid, name)
 *   MaoLib.Cooldowns.ResetAll(uid)
 *   MaoLib.Cooldowns.AutoNotify(uid, name, msg, sound, hudType)
 * ============================================================================
 */

if ("MaoLib_Cooldowns_init_guard" in getroottable()) return;
getroottable()["MaoLib_Cooldowns_init_guard"] <- true;

::MaoLib.Cooldowns <- {
    // ============================================================
    // DEBUG
    // ============================================================
    Debug = 1

    function Dbg(msg)
    {
        if (Debug) printl("[MaoLib.Cooldowns][DEBUG] " + msg)
    }

    function DbgWarn(msg)
    {
        printl("[MaoLib.Cooldowns][WARN] " + msg)
    }

    // ============================================================
    // ESTADO INTERNO
    // ============================================================

    // Timers[uid][name] = { endTime, notified, msg, sound, hudType }
    Timers = {}

    // Timer think activo
    ThinkActive = false

    // ============================================================
    // API PUBLICA
    // ============================================================

    function Start(uid, name, duration)
    {
        Dbg("ENTER Start uid=" + uid + " name=" + name + " dur=" + duration)

        if (!uid || !name || duration <= 0)
        {
            DbgWarn("ABORT Start: invalid args")
            return false
        }

        if (!(uid in Timers))
            Timers[uid] <- {}

        Timers[uid][name] <- {
            endTime = Time() + duration
            notified = false
            msg = null
            sound = null
            hudType = "chat"
        }

        // Persistir en PlayerState si existe (para recuperacion entre rounds, etc.)
        if ("PlayerState" in ::MaoLib)
        {
            ::MaoLib.PlayerState.Set(uid, "cooldown_" + name, Timers[uid][name])
        }

        Dbg("Start OK uid=" + uid + " name=" + name + " endsAt=" + (Time() + duration))

        // Asegurar que el think timer corra
        if (!ThinkActive)
            _StartThink()

        Dbg("EXIT Start")
        return true
    }

    function IsReady(uid, name)
    {
        Dbg("ENTER IsReady uid=" + uid + " name=" + name)

        if (!(uid in Timers) || !(name in Timers[uid]))
        {
            Dbg("IsReady: no cooldown found — READY")
            Dbg("EXIT IsReady")
            return true
        }

        local ready = Time() >= Timers[uid][name].endTime
        Dbg("IsReady uid=" + uid + " name=" + name + " ready=" + ready)
        Dbg("EXIT IsReady")
        return ready
    }

    function GetRemaining(uid, name)
    {
        Dbg("ENTER GetRemaining uid=" + uid + " name=" + name)

        if (!(uid in Timers) || !(name in Timers[uid]))
        {
            Dbg("GetRemaining: no cooldown found — 0")
            Dbg("EXIT GetRemaining")
            return 0
        }

        local remaining = Timers[uid][name].endTime - Time()
        if (remaining < 0)
            remaining = 0

        Dbg("GetRemaining uid=" + uid + " name=" + name + " remaining=" + remaining)
        Dbg("EXIT GetRemaining")
        return remaining
    }

    function Reset(uid, name)
    {
        Dbg("ENTER Reset uid=" + uid + " name=" + name)

        if (uid in Timers && name in Timers[uid])
        {
            delete Timers[uid][name]

            if (Timers[uid].len() == 0)
                delete Timers[uid]

            // Limpiar de PlayerState tambien
            if ("PlayerState" in ::MaoLib)
            {
                ::MaoLib.PlayerState.Delete(uid, "cooldown_" + name)
            }

            Dbg("Reset OK uid=" + uid + " name=" + name)
            Dbg("EXIT Reset")
            return true
        }

        Dbg("Reset MISS uid=" + uid + " name=" + name)
        Dbg("EXIT Reset")
        return false
    }

    function ResetAll(uid)
    {
        Dbg("ENTER ResetAll uid=" + uid)

        if (uid in Timers)
        {
            // Limpiar de PlayerState tambien
            if ("PlayerState" in ::MaoLib)
            {
                foreach (name, _ in Timers[uid])
                {
                    ::MaoLib.PlayerState.Delete(uid, "cooldown_" + name)
                }
            }

            delete Timers[uid]
            Dbg("ResetAll OK uid=" + uid)
            Dbg("EXIT ResetAll")
            return true
        }

        Dbg("ResetAll MISS uid=" + uid)
        Dbg("EXIT ResetAll")
        return false
    }

    function AutoNotify(uid, name, msg, sound = null, hudType = "chat")
    {
        Dbg("ENTER AutoNotify uid=" + uid + " name=" + name)

        if (!(uid in Timers) || !(name in Timers[uid]))
        {
            DbgWarn("AutoNotify: cooldown not found for uid=" + uid + " name=" + name)
            Dbg("EXIT AutoNotify")
            return false
        }

        Timers[uid][name].msg <- msg
        Timers[uid][name].sound <- sound
        Timers[uid][name].hudType <- hudType
        Timers[uid][name].notified <- false

        Dbg("AutoNotify OK uid=" + uid + " name=" + name + " msg=\"" + msg + "\"")
        Dbg("EXIT AutoNotify")
        return true
    }

    // ============================================================
    // THINK INTERNO
    // ============================================================

    function Think()
    {
        // No logs aqui — corre cada 1.0s
        if (!ThinkActive)
            return

        local now = Time()
        local activeCount = 0

        foreach (uid, cooldowns in Timers)
        {
            foreach (name, cd in cooldowns)
            {
                // Si ya paso el tiempo y no notificamos
                if (now >= cd.endTime && !cd.notified)
                {
                    cd.notified = true
                    _SendNotification(uid, cd)
                }

                // Contar cooldowns aun activos (no expirados o ya notificados)
                if (now < cd.endTime || !cd.notified)
                {
                    activeCount++
                }
            }
        }

        // Auto-pause si no hay cooldowns activos
        if (activeCount == 0 && ThinkActive)
        {
            _StopThink()
        }
    }

    // ============================================================
    // PRIVADO
    // ============================================================

    function _StartThink()
    {
        Dbg("ENTER _StartThink")

        if (ThinkActive)
        {
            Dbg("_StartThink: already active")
            Dbg("EXIT _StartThink")
            return
        }

        MaoLib.AddTimer("maolib_cooldowns_think", 1.0, function() { ::MaoLib.Cooldowns.Think(); })
        ThinkActive = true

        Dbg("_StartThink OK")
        Dbg("EXIT _StartThink")
    }

    function _StopThink()
    {
        Dbg("ENTER _StopThink")

        if (!ThinkActive)
        {
            Dbg("_StopThink: not active")
            Dbg("EXIT _StopThink")
            return
        }

        MaoLib.RemoveTimer("maolib_cooldowns_think")
        ThinkActive = false

        Dbg("_StopThink OK")
        Dbg("EXIT _StopThink")
    }

    function _SendNotification(uid, cd)
    {
        if (!cd.msg)
            return

        // Buscar jugador
        local player = GetPlayerFromUserID(uid)
        if (!player || !player.IsValid())
        {
            DbgWarn("_SendNotification: player not found for uid=" + uid)
            return
        }

        // Enviar mensaje HUD
        // Nota: MaoLib.HUD no existe todavia. Si existe, usarlo.
        // Sino, fallback a printl (para testing) o no hacer nada.
        if ("HUD" in ::MaoLib && "Notify" in ::MaoLib.HUD)
        {
            try
            {
                local opts = { mode = cd.hudType }
                ::MaoLib.HUD.Notify(player, cd.msg, opts)
            }
            catch (e)
            {
                DbgWarn("HUD.Notify failed: " + e)
            }
        }
        else
        {
            // Fallback: solo loggear en modo developer
            if (MaoLib.IsDeveloperMode())
            {
                printl("[MaoLib.Cooldowns][NOTIFY] uid=" + uid + ": " + cd.msg)
            }
        }

        // Sonido opcional
        if (cd.sound)
        {
            try
            {
                EmitSoundOnClient(cd.sound, player)
            }
            catch (e)
            {
                DbgWarn("EmitSoundOnClient failed: " + e)
            }
        }

        Dbg("_SendNotification sent to uid=" + uid + " msg=\"" + cd.msg + "\"")
    }
}

// ============================================================
// REGISTRO EN PlayerState.OnClearCallbacks
// Auto-limpieza de cooldowns cuando un jugador se desconecta
// ============================================================

if ("PlayerState" in ::MaoLib)
{
    ::MaoLib.PlayerState.RegisterOnClear("MaoLib_Cooldowns", function(uid) {
        ::MaoLib.Cooldowns.ResetAll(uid)
    })

    printl("[MaoLib.Cooldowns] Auto-cleanup registered with PlayerState")
}

printl("[MaoLib.Cooldowns] Loaded successfully")
