// maolib_hud.nut - Sistema de mensajería HUD robusto para Lost 4 Creed
// Usa ClientPrint como primario y game_text como fallback para efectos especiales
//
// API:
//   MaoLib.HUD.Notify(player, message, opts)   -> Mensaje a un jugador
//   MaoLib.HUD.NotifyAll(message, opts)        -> Broadcast a todos
//   MaoLib.HUD.Clear(player, channel)          -> Limpia game_text de canal
//   MaoLib.HUD.ColorGreen(text)                -> Helper color verde chat
//   MaoLib.HUD.ColorRed(text)                  -> Helper color rojo chat
//   MaoLib.HUD.ColorYellow(text)               -> Helper color amarillo chat

if ("MaoLib_HUD_init_guard" in getroottable()) return;
getroottable()["MaoLib_HUD_init_guard"] <- true;

::MaoLib.HUD <- {
	// ============================================================
	// DEBUG
	// ============================================================
	Debug = 1
	
	function Dbg(msg)
	{
		if (Debug) printl("[MaoLib.HUD][DEBUG] " + msg)
	}
	
	function DbgWarn(msg)
	{
		printl("[MaoLib.HUD][WARN] " + msg)
	}
	
	// ============================================================
	// ESTADO INTERNO
	// ============================================================
	
	// Throttle tracking: key "uid_typeKey" -> timestamp del último envío
	LastNotifyTime = {}
	
	// Cola de mensajes activa: uid -> array de {message, opts, enqueueTime}
	MessageQueue = {}
	
	// Cola de entrada temporal (evita race condition entre _Enqueue y ProcessQueue)
	IncomingQueue = []
	
	// Entidades game_text por jugador: uid_channel -> entity handle
	GameTextEntities = {}
	
	// Timer de procesamiento de cola (se inicializa al primer Notify)
	QueueTimerActive = false
	
	// ============================================================
	// COLORES DE CHAT (códigos de control L4D2)
	// ============================================================
	
	function ColorGreen(text)
	{
		return "\x04" + text + "\x01"
	}
	
	function ColorRed(text)
	{
		return "\x07" + text + "\x01"
	}
	
	function ColorYellow(text)
	{
		return "\x05" + text + "\x01"
	}
	
	function ColorBlue(text)
	{
		return "\x03" + text + "\x01"
	}
	
	// ============================================================
	// NOTIFY - Envía mensaje a un jugador
	// ============================================================
	// opts:
	//   typeKey     : string para throttle (default: hash simple del mensaje)
	//   duration    : segundos para game_text (default: 2.0)
	//   throttle    : segundos de cooldown (default: 3.0)
	//   color       : string "R G B" para game_text (default: "255 255 255")
	//   sound       : path de sonido para EmitSoundOnClient (default: null)
	//   channel     : canal de game_text 0-5 (default: 2)
	//   priority    : "low", "normal", "high" — high ignora throttle (default: "normal")
	//   x, y        : posición para game_text (default: -1 = centrar)
	//   fadein      : segundos fade in game_text (default: 0.1)
	//   fadeout     : segundos fade out game_text (default: 0.5)
	//
	function Notify(player, message, opts = {})
	{
		Dbg("ENTER Notify")
		
		// Guard: player null
		if (!player || !player.IsValid())
		{
			Dbg("EXIT Notify: player null/invalid")
			return false
		}
		
		// Guard: player no es jugador humano/bot
		if (!player.IsPlayer())
		{
			Dbg("EXIT Notify: entity is not a player")
			return false
		}
		
		local uid = player.GetPlayerUserId()
		local typeKey = ("typeKey" in opts) ? opts.typeKey : ("hash_" + message.len() + "_" + message.slice(0, ::MaoLib.min(16, message.len())))
		local throttle = ("throttle" in opts) ? opts.throttle : 3.0
		local priority = ("priority" in opts) ? opts.priority : "normal"
		local channel = ("channel" in opts) ? opts.channel : 2
		local mode = ("mode" in opts) ? opts.mode : "chat"
		
		// Si no se especificó mode, inferir del resto de opts
		if (!("mode" in opts))
		{
			if ("x" in opts || "y" in opts || channel != 2)
				mode = "game_text"
		}
		
		Dbg("  uid=" + uid + " typeKey=" + typeKey + " mode=" + mode + " priority=" + priority)
		
		// Throttle check
		local throttleKey = uid + "_" + typeKey
		local now = Time()
		
		if (priority != "high" && throttleKey in LastNotifyTime)
		{
			local elapsed = now - LastNotifyTime[throttleKey]
			if (elapsed < throttle)
			{
				Dbg("  THROTTLED: elapsed=" + elapsed + " < throttle=" + throttle + ", enqueuing")
				_Enqueue(uid, message, opts)
				return false
			}
		}
		
		// Enviar mensaje
		local result = _Send(player, message, opts, mode, channel)
		
		if (result)
		{
			LastNotifyTime[throttleKey] <- now
			Dbg("EXIT Notify: sent successfully")
		}
		else
		{
			Dbg("EXIT Notify: send failed")
		}
		
		return result
	}
	
	// ============================================================
	// NOTIFYALL - Broadcast a todos los jugadores
	// ============================================================
	function NotifyAll(message, opts = {})
	{
		Dbg("ENTER NotifyAll: \"" + message + "\"")
		local count = 0
		
		foreach (player in MaoLib.YieldPlayers())
		{
			if (Notify(player, message, opts))
				count++
		}
		
		Dbg("EXIT NotifyAll: sent to " + count + " players")
		return count
	}
	
	// ============================================================
	// CLEAR - Limpia mensajes game_text de un canal específico
	// ============================================================
	function Clear(player, channel = 2)
	{
		if (!player || !player.IsValid() || !player.IsPlayer())
			return false
		
		local uid = player.GetPlayerUserId()
		local key = uid + "_" + channel
		
		if (key in GameTextEntities)
		{
			local ent = GameTextEntities[key]
			if (ent && ent.IsValid())
			{
				ent.Kill()
				Dbg("Clear: killed game_text for uid=" + uid + " channel=" + channel)
			}
			delete GameTextEntities[key]
		}
		
		return true
	}
	
	// ============================================================
	// PROCESAR COLA - Revisa mensajes encolados
	// ============================================================
	function ProcessQueue()
	{
		Dbg("ENTER ProcessQueue")
		local now = Time()
		local processed = 0
		local expired = 0
		
		// Mergear IncomingQueue -> MessageQueue (evita race condition)
		foreach (incoming in IncomingQueue)
		{
			local uid = incoming.uid
			if (!(uid in MessageQueue))
				MessageQueue[uid] <- []
			MessageQueue[uid].append(incoming.entry)
		}
		IncomingQueue.clear()
		
		foreach (uid, queue in MessageQueue)
		{
			local newQueue = []
			
			foreach (entry in queue)
			{
				local elapsed = now - entry.enqueueTime
				
				// Descartar mensajes viejos (>10s en cola)
				if (elapsed > 10.0)
				{
					expired++
					Dbg("  DISCARD old message: uid=" + uid + " age=" + elapsed)
					continue
				}
				
				// Buscar jugador
				local player = GetPlayerFromUserID(uid)
				if (!player || !player.IsValid() || !player.IsPlayer())
				{
					// Jugador desconectado/muerto, descartar
					expired++
					continue
				}
				
				local opts = entry.opts
				local typeKey = ("typeKey" in opts) ? opts.typeKey : ("hash_" + entry.message.len() + "_" + entry.message.slice(0, ::MaoLib.min(16, entry.message.len())))
				local throttleKey = uid + "_" + typeKey
				local throttle = ("throttle" in opts) ? opts.throttle : 3.0
				local lastTime = (throttleKey in LastNotifyTime) ? LastNotifyTime[throttleKey] : 0
				
				if (now - lastTime >= throttle)
				{
					// Intentar enviar
					local mode = ("mode" in opts) ? opts.mode : "chat"
					local channel = ("channel" in opts) ? opts.channel : 2
					
					if (_Send(player, entry.message, opts, mode, channel))
					{
						LastNotifyTime[throttleKey] <- now
						processed++
						Dbg("  SENT queued: uid=" + uid + " typeKey=" + typeKey)
						continue // No re-encolar
					}
				}
				
				// No se pudo enviar, mantener en cola
				newQueue.append(entry)
			}
			
			if (newQueue.len() == 0)
			{
				delete MessageQueue[uid]
			}
			else
			{
				MessageQueue[uid] = newQueue
			}
		}
		
		Dbg("EXIT ProcessQueue: processed=" + processed + " expired=" + expired)
		
		// Si la cola está vacía, pausar el timer para ahorrar CPU
		if (MessageQueue.len() == 0 && QueueTimerActive)
		{
			MaoLib.RemoveTimer("maolib_hud_queue")
			QueueTimerActive = false
			Dbg("Queue timer stopped (empty queue)")
		}
	}
	
	// ============================================================
	// INTERNAL: Enqueue
	// ============================================================
	function _Enqueue(uid, message, opts)
	{
		// Añadir a IncomingQueue en vez de MessageQueue directamente
		// ProcessQueue hará el merge — evita race condition
		IncomingQueue.append({
			uid = uid
			entry = {
				message = message
				opts = opts
				enqueueTime = Time()
			}
		})
		
		Dbg("_Enqueue: uid=" + uid + " incomingSize=" + IncomingQueue.len())
		
		// Asegurar que el timer de cola esté activo
		if (!QueueTimerActive)
		{
			QueueTimerActive = true
			MaoLib.AddTimer("maolib_hud_queue", 0.5, function() { ::MaoLib.HUD.ProcessQueue(); })
			Dbg("Queue timer started")
		}
	}
	
	// ============================================================
	// INTERNAL: Send (el envío real)
	// ============================================================
	function _Send(player, message, opts, mode, channel)
	{
		local sound = ("sound" in opts) ? opts.sound : null
		
		switch (mode)
		{
			case "chat":
				_ClientPrintSafe(player, 3, message)
				break
			
			case "center":
				_ClientPrintSafe(player, 4, message)
				break
			
			case "hint":
				_ClientPrintSafe(player, 5, message)
				break
			
			case "game_text":
				_GameTextSafe(player, message, opts, channel)
				break
			
			default:
				DbgWarn("_Send: unknown mode '" + mode + "', falling back to chat")
				_ClientPrintSafe(player, 3, message)
				break
		}
		
		// Sonido opcional
		if (sound && sound.len() > 0)
		{
			try
			{
				EmitSoundOnClient(sound, player)
			}
			catch (e)
			{
				DbgWarn("_Send: EmitSoundOnClient failed: " + e)
			}
		}
		
		return true
	}
	
	// ============================================================
	// INTERNAL: ClientPrint con guard
	// ============================================================
	function _ClientPrintSafe(player, channel, text)
	{
		try
		{
			ClientPrint(player, channel, text)
		}
		catch (e)
		{
			DbgWarn("_ClientPrintSafe failed: " + e)
		}
	}
	
	// ============================================================
	// INTERNAL: game_text con gestión de entidades
	// ============================================================
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
		
		// Limpiar game_text anterior del mismo canal
		if (key in GameTextEntities)
		{
			local oldEnt = GameTextEntities[key]
			if (oldEnt && oldEnt.IsValid())
			{
				oldEnt.Kill()
			}
			delete GameTextEntities[key]
		}
		
		// Spawnear nuevo game_text
		local ent = SpawnEntityFromTable("game_text", {
			message = message
			x = x
			y = y
			holdtime = duration
			fadein = fadein
			fadeout = fadeout
			channel = channel
			color = color
			spawnflags = 1 // Wait for input (no auto-display)
		})
		
		if (!ent || !ent.IsValid())
		{
			DbgWarn("_GameTextSafe: failed to spawn game_text")
			return false
		}
		
		GameTextEntities[key] <- ent
		
		// Display + Kill programado
		DoEntFire("!self", "Display", "", 0.01, player, ent)
		DoEntFire("!self", "Kill", "", duration + 1.0, null, ent)
		
		Dbg("_GameTextSafe: uid=" + uid + " channel=" + channel + " duration=" + duration)
		return true
	}
}

printl("[MaoLib.HUD] Loaded successfully")
