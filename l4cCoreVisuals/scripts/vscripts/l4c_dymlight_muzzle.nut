// ═══════════════════════════════════════════════════════════════════════════════
// MUZZLE FLASH — luz dinámica para fogonazos de armas
// ═══════════════════════════════════════════════════════════════════════════════
//
// ARQUITECTURA V4 (28 MAY 2026 — UNIFIED PERSISTENT LIGHTS)
// ═══════════════════════════════════════════════════════════════════════════════
// - TODAS las armas usan una luz persistente por jugador (4 max)
//   → Sin SpawnEntityFromTable por disparo = cero lag incluso en semi-auto
//   → La luz se reusa para cada disparo del mismo jugador
//
// - On/Off vía inputs estándar TurnOn/TurnOff (documentados en VDC)
//   → NO usar EntFire("brightness") — ESO NO ES UN INPUT VÁLIDO
//   → light_dynamic inputs oficiales: TurnOn, TurnOff, SetBrightness, etc.
//
// - Cambio de brillo vía SetBrightness (input estándar)
//   → Si el jugador cambia de arma, se actualiza el brillo sin recrear entidad
//
// - Armas AUTOMÁTICAS: flicker dinámico (getFlashTimeAuto on / off según cycle)
// - Armas SEMI-AUTO: flash continuo por duración calculada, luego TurnOff
//
// ═══════════════════════════════════════════════════════════════════════════════

::LightMuzzle <- {
  // ── Constantes ──
  OFFSCREEN = Vector(99999, 0, 0)   // posición segura cuando inactiva
  DEFAULT_DISTANCE = 500             // alcance de la luz
  COLOR = "255 110 30"              // naranja fogonazo (R G B)
  FLASH_TIME_AUTO_MAX = 0.04         // flash máx para auto weapons (más brusco)
  DEFAULT_DURATION = 0.08            // fallback si arma no está en cycleTimes

  // ── Persistent lights (TODAS las armas, una por jugador) ──
  //   playerSlots[entityIndex] = {light, playerRef, weapon, brightness, fireStart, lastOn, active}
  playerSlots = {}

  // ── Shotgun weapon list ──
  SHOTGUNS = {
    ["autoshotgun"] = true,
    ["pumpshotgun"] = true,
    ["shotgun_chrome"] = true,
    ["shotgun_spas"] = true,
  }

  // ── Automatic weapon list (flicker pattern en globalTick) ──
  autoWeapons = {
    ["smg"] = true,
    ["smg_silenced"] = true,
    ["smg_mp5"] = true,
    ["rifle"] = true,
    ["rifle_ak47"] = true,
    ["rifle_desert"] = true,
    ["rifle_sg552"] = true,
    ["rifle_m60"] = true,
  }

  // ── Per-weapon brightness ──
  weaponBrightness = {
    ["pistol"]           = 1,
    ["pistol_magnum"]    = 3,
    ["smg"]              = 1,
    ["smg_silenced"]     = 1,
    ["smg_mp5"]          = 4,
    ["rifle"]            = 4,
    ["rifle_ak47"]       = 3,
    ["rifle_desert"]     = 2,
    ["rifle_sg552"]      = 1,
    ["rifle_m60"]        = 5,
    ["autoshotgun"]      = 3,
    ["pumpshotgun"]      = 4,
    ["shotgun_chrome"]   = 6,
    ["shotgun_spas"]     = 2,
    ["hunting_rifle"]    = 4,
    ["sniper_awp"]       = 7,
    ["sniper_military"]  = 2,
    ["sniper_scout"]     = 1,
  }

  // ── Cycle times from weapon .txt files (engine-authoritative) ──
  cycleTimes = {
    "autoshotgun":       0.28,
    "hunting_rifle":     0.445,
    "pistol":            0.35,
    "pistol_magnum":     0.29,
    "pumpshotgun":       0.10,
    "rifle":             0.1,
    "rifle_ak47":        0.070,
    "rifle_desert":      0.035,
    "rifle_m60":         0.20,
    "rifle_sg552":       0.1705,
    "shotgun_chrome":    0.06,
    "shotgun_spas":      0.35,
    "smg":               0.070,
    "smg_mp5":           0.090,
    "smg_silenced":      0.110,
    "sniper_awp":        1.15,
    "sniper_military":   0.13,
    "sniper_scout":      1.18,
  }

  // ════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════

  function isPersistent(weapon) {
    return (weapon in autoWeapons)
  }

  function getBrightness(weapon) {
    if (weapon in weaponBrightness) return weaponBrightness[weapon]
    return 2
  }

  function getMuzzlePos(player) {
    return player.EyePosition()
           + player.GetForwardVector() * 55
           - Vector(0, 0, 14)
  }

  // ── Flash time para auto weapons (flicker dinámico según cycle) ──
  //   Más brusco: flash corto proporcional al ciclo.
  //   Rápidas (<0.07s): flash ~0.02s (mín visible, casi continuo)
  //   Medias (0.07-0.15): flash ~0.025-0.04s  (35% duty cycle, sharp pulse)
  //   Lentas (>0.15): flash 0.04s (23-20% duty, muy brusco)
  function getFlashTimeAuto(cycle) {
    local t = cycle * 0.35
    t = (t < 0.02) ? 0.02 : t
    return (t > FLASH_TIME_AUTO_MAX) ? FLASH_TIME_AUTO_MAX : t
  }

  // ── Duración del flash (semi-auto: tiempo que la luz queda encendida) ──
  function getFlashDuration(weapon) {
    if (!(weapon in cycleTimes)) return DEFAULT_DURATION
    local cycle = cycleTimes[weapon]

    if (weapon in SHOTGUNS) {
      local t = cycle * 0.9
      return (t < 0.35) ? t : 0.35
    }

    // Semi-auto: flash visible durante la mayor parte del ciclo
    local t = cycle * 0.8
    return (t < 0.25) ? t : 0.25
  }

  // ════════════════════════════════════════════════════════════════
  // PLAYER LIGHT MANAGEMENT
  // ════════════════════════════════════════════════════════════════

  // ── Obtiene o crea luz persistente para un jugador ──
  //   Si ya existe: actualiza brillo vía SetBrightness (sin recrear)
  //   Si no existe: spawnea con keyvalues
  function getPlayerLight(player, weapon) {
    local idx = player.GetEntityIndex()
    local needBrightness = getBrightness(weapon)

    if (idx in playerSlots) {
      local slot = playerSlots[idx]
      if (slot.light && slot.light.IsValid()) {
        // Brillo cambió? (arma diferente)
        if (slot.brightness != needBrightness) {
          EntFire(slot.light.GetName(), "SetBrightness", needBrightness.tostring())
          slot.brightness = needBrightness
        }
        return slot
      }
      // Luz muerta: limpiar slot stale
      delete playerSlots[idx]
    }

    // Crear luz nueva con brillo inicial
    local light = SpawnEntityFromTable("light_dynamic", {
      targetname = UniqueString("l4c_muzzle_p_"),
      _light = COLOR,
      distance = DEFAULT_DISTANCE,
      style = 0,
      brightness = needBrightness
    })
    if (!light) return null

    light.SetOrigin(OFFSCREEN)
    EntFire(light.GetName(), "TurnOff")

    local slot = {
      light = light
      playerRef = player
      weapon = weapon
      brightness = needBrightness
      fireStart = -1
      lastOn = false     // track estado para evitar EntFire redundantes
      active = false
    }
    playerSlots[idx] <- slot
    return slot
  }

  // ════════════════════════════════════════════════════════════════
  // GLOBAL THINK
  // ════════════════════════════════════════════════════════════════

  function setupThink() {
    MaoLib.AddTimerForce("thinkMuzzleGlobal", 0.03, @() ::LightMuzzle.globalTick())
  }

  function globalTick() {
    foreach (idx, slot in playerSlots) {
      if (!slot.active) continue
      if (!slot.light || !slot.light.IsValid()) {
        slot.active = false
        continue
      }

      // ── Player tracking (DEBE ir antes del timeout) ──
      local p = slot.playerRef
      local isShooting = false
      if (p && p.IsValid() && p.GetHealth() > 0) {
        isShooting = (p.GetButtonMask() & 1) != 0  // IN_ATTACK
        slot.light.SetOrigin(getMuzzlePos(p))
      }

      local weapon = slot.weapon
      local elapsed = Time() - slot.fireStart
      local cycle = weapon in cycleTimes ? cycleTimes[weapon] : 0.1

      // ── AUTO: timeout + flicker ──
      if (isPersistent(weapon)) {
        local timeout = (cycle < 0.1) ? 0.15 : cycle * 2.0
        // CROUCH WORKAROUND: no apagar si el jugador sigue atacando
        // (el engine interrumpe weapon_fire al agacharse)
        if (elapsed > timeout && !isShooting) {
          turnOff(slot)
          continue
        }
        flicker(slot, elapsed, cycle)
      }

      // ── SEMI-AUTO: flash por duración ──
      else {
        local duration = getFlashDuration(weapon)
        if (elapsed > duration && !isShooting) {
          turnOff(slot)
          continue
        }
        turnOn(slot)
      }
    }
    return 0.03
  }

  // ── Helpers de estado on/off ──
  function turnOn(slot) {
    if (slot.lastOn) return        // ya está on
    slot.lastOn = true
    EntFire(slot.light.GetName(), "TurnOn")
  }

  function turnOff(slot) {
    if (!slot.lastOn) return       // ya está off
    slot.lastOn = false
    EntFire(slot.light.GetName(), "TurnOff")
    slot.active = false
  }

  // ── Flicker para automáticas (flash dinámico según cycle) ──
  function flicker(slot, elapsed, cycle) {
    local flashTime = getFlashTimeAuto(cycle)
    local shouldBeOn = (elapsed % cycle < flashTime)
    if (shouldBeOn == slot.lastOn) return

    slot.lastOn = shouldBeOn
    EntFire(slot.light.GetName(), shouldBeOn ? "TurnOn" : "TurnOff")
  }

  // ════════════════════════════════════════════════════════════════
  // EVENT HANDLER
  // ════════════════════════════════════════════════════════════════

  function OnGameEvent_weapon_fire(params) {
    if (!("userid" in params) || !("weapon" in params)) return
    if (!(params.weapon in cycleTimes)) return

    local player = GetPlayerFromUserID(params.userid)
    if (!player || !player.IsValid()) return
    if (player.GetHealth() <= 0) return
    if (IsPlayerABot(player)) return

    local weapon = params.weapon
    local slot = getPlayerLight(player, weapon)
    if (!slot || !slot.light) return

    // Posicionar + brillo correcto + encender
    slot.light.SetOrigin(getMuzzlePos(player))
    slot.fireStart = Time()
    slot.playerRef = player
    slot.weapon = weapon
    slot.active = true

    // Forzar on inicial (el think se encarga del flicker luego)
    slot.lastOn = true
    EntFire(slot.light.GetName(), "TurnOn")

    // Asegurar globalThink
    if (!Entities.FindByName(null, "thinkMuzzleGlobal")) setupThink()
  }

  // ════════════════════════════════════════════════════════════════
  // CLEANUP
  // ════════════════════════════════════════════════════════════════

  function OnGameEvent_round_start_post_nav(params) {
    cleanupAll()
  }

  function OnGameEvent_round_end(params) {
    MaoLib.RemoveTimer("thinkMuzzleGlobal")
    cleanupAll()
  }

  function cleanupAll() {
    foreach (idx, slot in playerSlots) {
      if (slot.light && slot.light.IsValid()) {
        EntFire(slot.light.GetName(), "TurnOff")
        slot.light.Kill()
      }
    }
    playerSlots.clear()

    // Orphaned lights de rondas previas
    local e = null
    while (e = Entities.FindByClassname(e, "light_dynamic")) {
      local n = e.GetName()
      if (n.len() > 0 && n.find("l4c_muzzle_") == 0) {
        if (e.IsValid()) e.Kill()
      }
    }
  }
}

__CollectGameEventCallbacks(::LightMuzzle)
