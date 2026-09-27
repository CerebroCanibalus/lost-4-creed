// ============================================================================
// MaoLib.HUD — Messaging System for L4D2
// ============================================================================
// Send messages to players via chat, center text, hints, or game_text.
// Features throttle, queue, priority, and color helpers.
//
// MODES:
//   "chat"      — Chat window message (default)
//   "center"    — Center of screen text
//   "hint"      — Hint text (fades in/out)
//   "game_text" — game_text entity (custom position, channel, duration)
//
// OPTS:
//   typeKey    : string for throttle grouping (default: auto from message)
//   duration   : seconds for game_text (default: 2.0)
//   throttle   : seconds between repeats (default: 3.0)
//   color      : "R G B" for game_text (default: "255 255 255")
//   sound      : sound path via EmitSoundOnClient (default: null)
//   channel    : game_text channel 0-5 (default: 2)
//   priority   : "low", "normal", "high" — high ignores throttle
//   mode       : "chat"|"center"|"hint"|"game_text"
//   x, y       : position for game_text (default: -1 = center)
//   fadein     : seconds fade in (default: 0.1)
//   fadeout    : seconds fade out (default: 0.5)
//
// USAGE:
//   MaoLib.HUD.Notify(player, "Hello!", { mode = "chat" })
//   MaoLib.HUD.NotifyAll("Everyone sees this!", { mode = "hint", throttle = 5.0 })
//   MaoLib.HUD.Clear(player, 2)
//   MaoLib.HUD.ColorGreen("text")  → "\x04text\x01"
//   MaoLib.HUD.ColorRed("text")    → "\x07text\x01"
//   MaoLib.HUD.ColorYellow("text") → "\x05text\x01"
//
// CHAT COLOR CODES (L4D2):
//   \x01 = white (reset)    \x03 = blue
//   \x04 = green            \x05 = yellow
//   \x07 = red              \x06 = orange
// ============================================================================

if ("MaoLib_HUD_init_guard" in getroottable()) return;
getroottable()["MaoLib_HUD_init_guard"] <- true;

::MaoLib.HUD <- {
    Debug = 0

    function Dbg(msg) { if (Debug) printl("[MaoLib.HUD][DEBUG] " + msg) }
    function DbgWarn(msg) { printl("[MaoLib.HUD][WARN] " + msg) }

    // Internal state
    LastNotifyTime = {}
    MessageQueue = {}
    IncomingQueue = []
    GameTextEntities = {}
    QueueTimerActive = false

    // ============================================================
    // COLOR HELPERS
    // ============================================================
    function ColorGreen(text)  { return "\x04" + text + "\x01" }
    function ColorRed(text)    { return "\x07" + text + "\x01" }
    function ColorYellow(text) { return "\x05" + text + "\x01" }
    function ColorBlue(text)   { return "\x03" + text + "\x01" }

    // ============================================================
    // NOTIFY — Send message to a single player
    // ============================================================
    function Notify(player, message, opts = {})
    {
        if (!player || !player.IsValid()) return false
        if (!player.IsPlayer()) return false

        local uid = player.GetPlayerUserId()
        local typeKey = ("typeKey" in opts) ? opts.typeKey : ("hash_" + message.len() + "_" + message.slice(0, ::MaoLib.min(16, message.len())))
        local throttle = ("throttle" in opts) ? opts.throttle : 3.0
        local priority = ("priority" in opts) ? opts.priority : "normal"
        local channel = ("channel" in opts) ? opts.channel : 2
        local mode = ("mode" in opts) ? opts.mode : "chat"

        // Auto-detect game_text mode from opts
        if (!("mode" in opts) && ("x" in opts || "y" in opts || channel != 2))
            mode = "game_text"

        // Throttle check
        local throttleKey = uid + "_" + typeKey
        local now = Time()

        if (priority != "high" && throttleKey in LastNotifyTime)
        {
            local elapsed = now - LastNotifyTime[throttleKey]
            if (elapsed < throttle)
            {
                _Enqueue(uid, message, opts)
                return false
            }
        }

        local result = _Send(player, message, opts, mode, channel)
        if (result) LastNotifyTime[throttleKey] <- now
        return result
    }

    // ============================================================
    // NOTIFYALL — Broadcast to all players
    // ============================================================
    function NotifyAll(message, opts = {})
    {
        local count = 0
        foreach (player in ::MaoLib.YieldPlayers())
        {
            if (Notify(player, message, opts)) count++
        }
        return count
    }

    // ============================================================
    // CLEAR — Remove game_text from a channel
    // ============================================================
    function Clear(player, channel = 2)
    {
        if (!player || !player.IsValid() || !player.IsPlayer()) return false
        local uid = player.GetPlayerUserId()
        local key = uid + "_" + channel
        if (key in GameTextEntities)
        {
            local ent = GameTextEntities[key]
            if (ent && ent.IsValid()) ent.Kill()
            delete GameTextEntities[key]
        }
        return true
    }

    // ============================================================
    // INTERNAL: Process Queue
    // ============================================================
    function ProcessQueue()
    {
        local now = Time()
        local processed = 0
        local expired = 0

        // Merge IncomingQueue -> MessageQueue (avoids race condition)
        foreach (incoming in IncomingQueue)
        {
            local uid = incoming.uid
            if (!(uid in MessageQueue)) MessageQueue[uid] <- []
            MessageQueue[uid].append(incoming.entry)
        }
        IncomingQueue.clear()

        foreach (uid, queue in MessageQueue)
        {
            local newQueue = []
            foreach (entry in queue)
            {
                local elapsed = now - entry.enqueueTime
                if (elapsed > 10.0) { expired++; continue }  // discard old

                local player = GetPlayerFromUserID(uid)
                if (!player || !player.IsValid() || !player.IsPlayer()) { expired++; continue }

                local opts = entry.opts
                local typeKey = ("typeKey" in opts) ? opts.typeKey : ("hash_" + entry.message.len() + "_" + entry.message.slice(0, ::MaoLib.min(16, entry.message.len())))
                local throttleKey = uid + "_" + typeKey
                local throttle = ("throttle" in opts) ? opts.throttle : 3.0
                local lastTime = (throttleKey in LastNotifyTime) ? LastNotifyTime[throttleKey] : 0

                if (now - lastTime >= throttle)
                {
                    local mode = ("mode" in opts) ? opts.mode : "chat"
                    local channel = ("channel" in opts) ? opts.channel : 2
                    if (_Send(player, entry.message, opts, mode, channel))
                    {
                        LastNotifyTime[throttleKey] <- now
                        processed++
                        continue
                    }
                }
                newQueue.append(entry)
            }

            if (newQueue.len() == 0) delete MessageQueue[uid]
            else MessageQueue[uid] = newQueue
        }

        if (MessageQueue.len() == 0 && QueueTimerActive)
        {
            ::MaoLib.RemoveTimer("maolib_hud_queue")
            QueueTimerActive = false
        }
    }

    // ============================================================
    // INTERNAL: Enqueue
    // ============================================================
    function _Enqueue(uid, message, opts)
    {
        IncomingQueue.append({ uid = uid, entry = { message = message, opts = opts, enqueueTime = Time() } })
        if (!QueueTimerActive)
        {
            QueueTimerActive = true
            ::MaoLib.AddTimer("maolib_hud_queue", 0.5, function() { ::MaoLib.HUD.ProcessQueue() })
        }
    }

    // ============================================================
    // INTERNAL: Send (actual dispatch)
    // ============================================================
    function _Send(player, message, opts, mode, channel)
    {
        local sound = ("sound" in opts) ? opts.sound : null

        switch (mode)
        {
            case "chat":   _ClientPrintSafe(player, 3, message); break
            case "center": _ClientPrintSafe(player, 4, message); break
            case "hint":   _ClientPrintSafe(player, 5, message); break
            case "game_text": _GameTextSafe(player, message, opts, channel); break
            default: _ClientPrintSafe(player, 3, message); break
        }

        if (sound && sound.len() > 0)
        {
            try { EmitSoundOnClient(sound, player) } catch (e) { DbgWarn("EmitSoundOnClient failed: " + e) }
        }

        return true
    }

    function _ClientPrintSafe(player, channel, text)
    {
        try { ClientPrint(player, channel, text) } catch (e) { DbgWarn("ClientPrint failed: " + e) }
    }

    function _GameTextSafe(player, message, opts, channel)
    {
        local uid = player.GetPlayerUserId()
        local key = uid + "_" + channel
        local duration = ("duration" in opts) ? opts.duration : 2.0
        local color = ("color" in opts) ? opts.color : "255 255 255"
        local x = ("x" in opts) ? opts.x : -1
        local y = ("y" in opts) ? opts.y : -1
        local fadein = ("fadein" in opts) ? opts.fadein : 0.1
        local fadeout = ("fadeout" in opts) ? opts.fadeout : 0.5

        // Kill previous game_text on same channel
        if (key in GameTextEntities)
        {
            local oldEnt = GameTextEntities[key]
            if (oldEnt && oldEnt.IsValid()) oldEnt.Kill()
            delete GameTextEntities[key]
        }

        local ent = SpawnEntityFromTable("game_text", {
            message = message,
            x = x, y = y,
            holdtime = duration,
            fadein = fadein,
            fadeout = fadeout,
            channel = channel,
            color = color,
            spawnflags = 1  // Wait for input
        })

        if (!ent || !ent.IsValid()) { DbgWarn("_GameTextSafe: failed to spawn"); return false }

        GameTextEntities[key] <- ent
        DoEntFire("!self", "Display", "", 0.01, player, ent)
        DoEntFire("!self", "Kill", "", duration + 1.0, null, ent)
        return true
    }
}

// ============================================================
// EVENTS — Round cleanup
// ============================================================
::MaoLib_HUD_Events <- {
    function OnGameEvent_round_end(params)      { _Cleanup() }
    function OnGameEvent_mission_lost(params)   { _Cleanup() }
    function OnGameEvent_map_transition(params) { _Cleanup() }
    
    function _Cleanup() {
        ::MaoLib.HUD.LastNotifyTime.clear()
        ::MaoLib.HUD.MessageQueue.clear()
        ::MaoLib.HUD.IncomingQueue.clear()
        ::MaoLib.HUD.QueueTimerActive = false
        ::MaoLib.RemoveTimer("maolib_hud_queue")
    }
}
__CollectGameEventCallbacks(::MaoLib_HUD_Events)

printl("[MaoLib.HUD] Loaded successfully")
