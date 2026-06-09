// ═══════════════════════════════════════════════════════════════
// l4c_dymlight.nut — Dynamic Lighting System
// ═══════════════════════════════════════════════════════════════
::PI <- 3.14159265  // Squirrel no trae PI nativo
// - Luz dinámica para proyectiles (molotov, pipe, spit, etc.)
// - Flash rojo intenso cuando SI usan habilidades (26 MAY 2026)
//
// Eventos usados (SI Ability Flash):
//   OnGameEvent_ability_use  → Smoker, Boomer, Hunter, Spitter,
//                              Jockey, Charger, Tank (rock throw)
//   OnGameEvent_player_hurt  → Tank punch (rate-limited 1.5s)
// ═══════════════════════════════════════════════════════════════

::DLighting <- {
  attached = {}
  settings = null

  // ═════════════════════════════════════════════════════════════
  // SI ABILITY FLASH SYSTEM
  // ═════════════════════════════════════════════════════════════
  // Luz que aparece cuando SI usan habilidades.
  // - Sigue al SI mientras dura
  // - Fade in rápido (0.05s), fade out suave (0.15s)
  // - Desaparece tras 0.5s
  // ═════════════════════════════════════════════════════════════

  SI_FLASH_TIME = 0.5       // duración total (reducido 1.0→0.5)
  SI_FLASH_DIST = 120       // alcance (reducido 250→120)
  SI_FLASH_BRIGHT = 8       // intensidad (reducido 12→8)
  SI_FADE_TIME = 0.15       // tiempo de fade out
  SI_LAST_FLASH = {}         // rate limiting por entity index

  function spawnSIFlash(player, pos) {
    // ⚠️ startTime es LOCAL para que el closure lo capture
    //    (Squirrel 3.2 §2.8.2: las variables no-locales no se capturan)
    local startTime = Time()

    // Brillo fijo al spawnear — NUNCA se cambia en runtime
    //   __KeyValueFromString("brightness", X) causa ENTITY_CHANGE_NONE
    //   En vez de fade in/out por brightness, hacemos fade visual moviendo
    //   la luz: fade in = se acerca al SI, fade out = se aleja
    local light = SpawnEntityFromTable("light_dynamic", {
      _light = "255 0 0",
      distance = SI_FLASH_DIST,
      style = 0,
      brightness = SI_FLASH_BRIGHT       // brillo fijo desde el spawn
    })
    if (!light) return

    light.SetOrigin(pos + Vector(0, 0, 80))  // empezar arriba (fade in visual)
    light.ValidateScriptScope()
    local scope = light.GetScriptScope()

    // Fade visual via SetOrigin en vez de __KeyValueFromString brightness
    //   - Fade in: luz se mueve desde arriba hacia el SI (0 → 0.05s)
    //   - Full: luz sigue al SI (0.05s → SI_FLASH_TIME - 0.15s)
    //   - Fade out: luz se aleja del SI hacia arriba (últimos 0.15s)
    local siTimerName = "si_flash_" + UniqueString()
    MaoLib.AddTimerForce(siTimerName, 0.03, function() {
      if (!light || !light.IsValid()) {
        MaoLib.RemoveTimer(siTimerName)
        return
      }
      local elapsed = Time() - startTime
      if (elapsed > DLighting.SI_FLASH_TIME) {
        light.Kill()
        MaoLib.RemoveTimer(siTimerName)
        return
      }
      local basePos = pos
      if (player != null && player.IsValid()) {
        basePos = player.GetOrigin()
        pos = basePos
      }
      local fadeOffset = 0
      if (elapsed < 0.05) {
        fadeOffset = 80 * (1.0 - elapsed / 0.05)
      } else {
        local remaining = DLighting.SI_FLASH_TIME - elapsed
        if (remaining < DLighting.SI_FADE_TIME) {
          fadeOffset = 80 * (1.0 - remaining / DLighting.SI_FADE_TIME)
        }
      }
      light.SetOrigin(basePos + Vector(0, 0, fadeOffset))
    })
  }

  function OnGameEvent_ability_use(params) {
    if (!("userid" in params)) return
    local player = GetPlayerFromUserID(params.userid)
    if (!player || !player.IsValid()) return

    local zClass = NetProps.GetPropInt(player, "m_zombieClass")
    if (zClass < 1 || zClass > 8 || zClass == 7) return

    spawnSIFlash(player, player.GetOrigin())
  }

  function OnGameEvent_player_hurt(params) {
    if (!("userid" in params) || !("weapon" in params)) return
    if (params.weapon != "tank_claw") return
    if (!("attacker" in params)) return

    local attacker = GetPlayerFromUserID(params.attacker)
    if (!attacker || !attacker.IsValid()) return
    if (attacker.IsPlayer() == false) return

    local idx = attacker.GetEntityIndex()
    local now = Time()
    if ((idx in SI_LAST_FLASH) && now - SI_LAST_FLASH[idx] < 1.5) return
    SI_LAST_FLASH[idx] <- now

    spawnSIFlash(attacker, attacker.GetOrigin())
  }

  // ═════════════════════════════════════════════════════════════
  // SISTEMA ORIGINAL: Iluminación de Proyectiles
  // ═════════════════════════════════════════════════════════════

  function readConfig(path) {
    if (FileToString(path)==null) generateConfig(path)
    local out = {};
    foreach(line in split(FileToString(path), "\n")) {
      line = strip(line);
      if (line.len() == 0) continue;
      local colonPos = line.find(":");
      if (colonPos < 0) continue;
      local name = strip(line.slice(0, colonPos));
      local rest = strip(line.slice(colonPos + 1));
      local tbl = {};
      foreach(field in split(rest, ",")) {
        local f = strip(field);
        if (f.len() == 0) continue;
        local eq = f.find("=");
        if (eq < 0) continue;
        local k = strip(f.slice(0, eq));
        local v = strip(f.slice(eq + 1));
        if (v.find("\"")!=null)
          tbl[k] <- v.slice(1, v.len() - 1)
        else if (v.find(".") >= 0) tbl[k] <- v.tofloat()
        else tbl[k] <- v.tointeger()
      }
      out[name] <- tbl;
    }
    return out;
  }

  function generateConfig(path) {
    local cfg = ""
    cfg+="molotov_projectile   : color0=\"255 100 0\", style=6, distance0=500, brightness0=1\n"
    cfg+="spitter_projectile   : color0=\"0 192 0\",   style=0, distance0=500, brightness0=1\n"
    cfg+="inferno              : color0=\"255 100 0\", style=6, distance0=500, brightness0=5, distance=\"inferno\", strength=1000\n"
    cfg+="pipe_bomb_projectile : color0=\"255 0 0\",   style=0, distance0=500, brightness0=5, distance=\"pbblink\", strength=300\n"
    cfg+="fire_cracker_blast   : color0=\"0 255 255\", style=6, distance0=500, brightness0=5, distance=\"inferno\", strength=1000, color=\"rainbow\"\n"
    cfg+="insect_swarm         : color0=\"0 192 0\",   style=0, distance0=500, brightness0=1, distance=\"spit\",    strength=500, color=\"greenred\"\n"
    StringToFile(path, cfg)
  }

  function pbblink(params) {
    local min = Convars.GetFloat("pipe_bomb_beep_min_interval")
    local init = Convars.GetFloat("pipe_bomb_initial_beep_interval")
    local delta = Convars.GetFloat("pipe_bomb_beep_interval_delta")
    function func(time, strength=params.strength, interval_init=init, interval_delta=delta, interval_min=min) {
      local count = 0
      local time0 = 0
      local max = @(a,b) (a>b)?a:b
      while (true) {
        local time1 = time0+max(interval_init-interval_delta*(count++), interval_min)
        if (time < time1) break
        time0 = time1
      }
      return strength-(time-time0)*strength*2
    }
    return func
  }

  function pseudoperlin(seed, time) return (sin(seed*time)+sin(time)+2)/4

  function inferno(params) {
    local duration = Convars.GetFloat("inferno_flame_lifetime")
    function func(time, strength=params.strength, duration=duration, seed=RandomFloat(0.3,0.8)) {
      local rate = time/duration
      return 6.7 * pow((rate-1),2) * (1+(rate-1)) * (strength + DLighting.pseudoperlin(seed, time*20)*500)
    }
    return func
  }

  function spit(params) {
    function func(time, strength=params.strength, seed=RandomFloat(0.3,0.8)) {
      local rate = time/7
      if (rate >= 1) return 0
      return (sqrt(sin(PI*rate))+sin(3*PI*rate)/15)*1.068 * (strength + DLighting.pseudoperlin(seed, time*20)*300)
    }
    return func
  }

  function greenred(params) {
    function func(time, seed=RandomFloat(0.3,0.8)) {
      local rate = DLighting.pseudoperlin(seed, time*10)
      local r = null
      local g = null
      if (rate < 0.5) {
        r = rate*2
        g = 1
      }
      else {
        r = 1
        g = 1-(rate-0.5)*2
      }
      return (r*150).tointeger()+" "+(g*190).tointeger()+" 0"
    }
    return func
  }

  function rainbow(params) {
    function func(time, strength=params.strength, seedr=RandomFloat(0.3,0.8), seedg=RandomFloat(0.3,0.8), seedb=RandomFloat(0.3,0.8)) {
      time *= 15
      local channel = @(seed) (DLighting.pseudoperlin(seed, time)*255).tointeger()
      return channel(seedr)+" "+channel(seedg)+" "+channel(seedb)
    }
    return func
  }

  function illuminate(ent, params) {
    local entid = ent.GetEntityIndex()
    if (entid in attached && attached[entid].IsValid()) return
    local hLight = SpawnEntityFromTable("light_dynamic", {targetname="tl",
      _light = params.color0, distance = params.distance0, style = params.style, brightness = params.brightness0})
    attached[entid] <- hLight
    if(!hLight.ValidateScriptScope()) return
    local graphs = {}
    foreach (input in ["distance","color","brightness"]) if (input in params) graphs[input] <- DLighting[params[input]](params)
    hLight.GetScriptScope()["handle"] <- ent
    hLight.GetScriptScope()["handleid"] <- entid
    hLight.GetScriptScope()["start"] <- Time()
    hLight.GetScriptScope()["params"] <- graphs
    local projTimer = "illuminate_" + UniqueString()
    MaoLib.AddTimerForce(projTimer, 0.03, function() {
      if (!hLight || !hLight.IsValid()) {
        MaoLib.RemoveTimer(projTimer)
        return
      }
      if (!handle.IsValid()) {
        delete DLighting.attached[handleid]
        hLight.Kill()
        MaoLib.RemoveTimer(projTimer)
        return
      }
      local pos2 = handle.GetOrigin()
      if (hLight.GetOrigin() != pos2) hLight.SetOrigin(pos2)
      local now = Time()
      foreach (input in ["distance","color","brightness"])
        if (input in params)
          EntFire("!self", input, graphs[input](now - start).tostring(), 0, null, hLight)
    })
  }

  function update() {
    if (settings==null) settings = readConfig("light/projectile.txt")
    foreach (classname, params in settings) {
      local ent = null
      while (ent = Entities.FindByClassname(ent, classname)) illuminate(ent, params)
    }
    return 0.1
  }

  function OnGameEvent_player_spawn(params) {
    MaoLib.AddTimerForce("thinkLight", 0.1, @() ::DLighting.update())
  }

  // ── round_end: limpiar luces de proyectiles remanentes ──
  function OnGameEvent_round_end(params) {
    foreach (idx, light in attached) {
      if (light && light.IsValid()) light.Kill()
    }
    attached.clear()

    MaoLib.RemoveTimer("thinkLight")
  }

  function OnGameEvent_player_say(params) {
    if (params.text.find("!light reload")!=0) return
    settings = null
  }
}

__CollectGameEventCallbacks(::DLighting)
