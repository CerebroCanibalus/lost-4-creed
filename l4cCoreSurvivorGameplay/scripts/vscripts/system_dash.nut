// ============================================================
// system_dash.nut — Dash System (Consultivo)
// ============================================================
// Capa 3: Extraido de system_movement.nut
// Consulta CharacterSystem para dashEnabled en lugar de DisabledPlayers

if ("SystemDash_init_guard" in getroottable()) return;
getroottable()["SystemDash_init_guard"] <- true;

::SystemDash <- {
    Debug = 1
    function Dbg(msg) { if (Debug) printl("[Dash][DEBUG] " + msg) }

    Config = {
        SOUND = {
            DASH = ["Melee.Miss"],
            DASH_RECHARGE = ["Buttons.blip1"],
            DASH_EFFORT = ["Weapon_Axe.Swing"]
        },
        DASH_SETTINGS = {
            IMPULSE_FORCE = 330,
            LIFT_FORCE = 240
        },
        TIMING = {
            THINK_INTERVAL = 0.05,
            RECHARGE_TIME = 2.6,
            MAX_CHARGES = 2,
            DASH_DURATION = 0.8
        },
        FEEDBACK = {
            DUST_PARTICLE = "smoke_small_01",
            FULL_CHARGE_SOUND_INTERVAL = 8.0
        },
        DEBUG = {
            ENABLED = true
        }
    },

    CONSTANTS = {
        MOVEMENT_BUTTONS = 8 | 16 | 512 | 1024,
        IN_SPEED = 131072,
        INVALID_GROUND_ENTITY = -1
    },

    PLAYER_STATE = {}
}

function SystemDash::Log(msg, level = "debug") {
    if (this.Config.DEBUG.ENABLED || level != "debug") {
        printl("[SystemDash " + level + "] " + msg)
    }
}

function SystemDash::InitPlayerState(userid) {
    this.PLAYER_STATE[userid] <- {
        lastButtonMask = 0,
        dashCharges = this.Config.TIMING.MAX_CHARGES,
        rechargeAccumulator = 0.0,
        lastThinkTime = Time()
    }
}

function SystemDash::CleanupPlayerState(userid) {
    if (userid in this.PLAYER_STATE) {
        delete this.PLAYER_STATE[userid]
    }
}

function SystemDash::CanPlayerDash(player, state) {
    if (state.dashCharges <= 0) return false
    if (!::MaoLib.IsAlive(player)) return false

    // Consultar dashEnabled del CharacterSystem (source of truth)
    // Si el personaje no se puede identificar → denegar dash por seguridad
    local charId = ::CharacterSystem.GetCharacterId(player)
    if (!charId || !(charId in ::CharacterSystem.BaseAttributes))
        return false
    local attrs = ::CharacterSystem.BaseAttributes[charId]
    if ("dashEnabled" in attrs && attrs.dashEnabled == false)
        return false

    return !(
        NetProps.GetPropInt(player, "m_hGroundEntity") == this.CONSTANTS.INVALID_GROUND_ENTITY ||
        NetProps.GetPropInt(player, "m_isIncapacitated") != 0 ||
        NetProps.GetPropInt(player, "m_isHangingFromLedge") != 0 ||
        NetProps.GetPropEntity(player, "m_pounceAttacker") != null ||
        NetProps.GetPropEntity(player, "m_tongueOwner") != null ||
        NetProps.GetPropEntity(player, "m_jockeyAttacker") != null ||
        NetProps.GetPropEntity(player, "m_pummelAttacker") != null ||
        NetProps.GetPropEntity(player, "m_carryAttacker") != null ||
        (NetProps.GetPropFloat(player, "m_flProgressBarStartTime") > 0.0 &&
         NetProps.GetPropFloat(player, "m_flProgressBarDuration") > 0.0)
    )
}

function SystemDash::Think() {
    local now = Time()

    local players = []
    foreach (player in ::MaoLib.YieldSurvivors()) {
        players.append(player)
    }

    foreach (player in players) {
        if (!player || !player.IsValid()) continue

        local userid = player.GetPlayerUserId()
        if (!(userid in this.PLAYER_STATE)) {
            this.InitPlayerState(userid)
        }

        local state = this.PLAYER_STATE[userid]
        local delta = now - state.lastThinkTime
        state.lastThinkTime = now

        if (state.dashCharges < this.Config.TIMING.MAX_CHARGES) {
            state.rechargeAccumulator += delta

            while (
                state.rechargeAccumulator >= this.Config.TIMING.RECHARGE_TIME &&
                state.dashCharges < this.Config.TIMING.MAX_CHARGES
            ) {
                state.dashCharges++
                state.rechargeAccumulator -= this.Config.TIMING.RECHARGE_TIME

                local rechargeSounds = this.Config.SOUND.DASH_RECHARGE
                local rechargeSnd = rechargeSounds[RandomInt(0, rechargeSounds.len() - 1)]
                EmitAmbientSoundOn(rechargeSnd, 0.6, 75, RandomInt(95,105), player)
            }
        }

        local buttons = player.GetButtonMask()
        local moveMask = buttons & this.CONSTANTS.MOVEMENT_BUTTONS

        local shiftNow = (buttons & this.CONSTANTS.IN_SPEED)
        local shiftBefore = (state.lastButtonMask & this.CONSTANTS.IN_SPEED)
        local shiftPressed = shiftNow && !shiftBefore

        if (shiftPressed && moveMask && this.CanPlayerDash(player, state)) {
            this.PerformDash(player, state, buttons)
            state.dashCharges--
        }

        state.lastButtonMask = buttons
    }
}

function SystemDash::PerformDash(player, state, buttons) {
    local dir = this.GetDashVector(player, buttons)
    if (dir.Length() <= 0) return

    local origin = player.GetOrigin()
    player.SetOrigin(Vector(origin.x, origin.y, origin.z + 1))

    local vel = player.GetVelocity()
    vel.x = dir.x * this.Config.DASH_SETTINGS.IMPULSE_FORCE
    vel.y = dir.y * this.Config.DASH_SETTINGS.IMPULSE_FORCE
    vel.z = this.Config.DASH_SETTINGS.LIFT_FORCE

    player.SetVelocity(vel)
    NetProps.SetPropFloat(player, "localdata.m_Local.m_flFallVelocity", 0.0)

    this.Log("Dash! Dir: " + dir + " | Force: " + this.Config.DASH_SETTINGS.IMPULSE_FORCE + " | Lift: " + this.Config.DASH_SETTINGS.LIFT_FORCE + " | Vel: " + vel, "info")

    local dashSounds = this.Config.SOUND.DASH
    local dashSnd = dashSounds[RandomInt(0, dashSounds.len() - 1)]
    EmitAmbientSoundOn(dashSnd, 0.7, 75, RandomInt(95,105), player)

    local effortSounds = this.Config.SOUND.DASH_EFFORT
    local effortSnd = effortSounds[RandomInt(0, effortSounds.len() - 1)]
    EmitAmbientSoundOn(effortSnd, 0.7, 75, RandomInt(95,105), player)

    // Polvo al dashear — MaoLib_VFX maneja Start + ciclo de vida correctamente
    ::MaoLib_VFX.SpawnParticle(
        player.GetOrigin() + Vector(0, 0, 4),
        this.Config.FEEDBACK.DUST_PARTICLE,
        0.3,
        "gameplay"
    )

    this.Log("Dash by " + player.GetPlayerUserId() + " | Charges: " + state.dashCharges, "info")
}

function SystemDash::GetDashVector(player, buttons) {
    local yaw = player.EyeAngles().y * PI / 180
    local fwd = Vector(cos(yaw), sin(yaw), 0)
    local right = Vector(sin(yaw), -cos(yaw), 0)

    local v = Vector(0, 0, 0)
    if (buttons & 8)  v += fwd
    if (buttons & 16) v -= fwd
    if (buttons & 512) v -= right
    if (buttons & 1024) v += right

    v.Norm()
    return v
}

function SystemDash::Init() {
    foreach (snd in this.Config.SOUND.DASH) {
        PrecacheSound(snd)
    }
    foreach (snd in this.Config.SOUND.DASH_RECHARGE) {
        PrecacheSound(snd)
    }
    foreach (snd in this.Config.SOUND.DASH_EFFORT) {
        PrecacheSound(snd)
    }

    ::MaoLib.AddTimer("sysdash_think", this.Config.TIMING.THINK_INTERVAL, function() {
        ::SystemDash.Think()
    })

    this.Log("Dash system initialized", "info")
}

::SystemDash.Init()

::SystemDash.Events <- {
    function OnGameEvent_player_spawn(e) {
        local p = GetPlayerFromUserID(e.userid)
        if (p && p.IsValid() && p.IsSurvivor())
            ::SystemDash.InitPlayerState(e.userid)
    }

    function OnGameEvent_player_death(e) {
        if ("userid" in e) ::SystemDash.CleanupPlayerState(e.userid)
    }

    function OnGameEvent_player_disconnect(e) {
        if ("userid" in e) ::SystemDash.CleanupPlayerState(e.userid.tointeger())
    }

    function OnGameEvent_round_start(e) {
        ::SystemDash.PLAYER_STATE.clear()
        foreach (s in ::MaoLib.YieldSurvivors()) {
            if (s.IsSurvivor()) ::SystemDash.InitPlayerState(s.GetPlayerUserId())
        }
    }

    function OnGameEvent_round_end(e) {
        ::SystemDash.PLAYER_STATE.clear()
        MaoLib.RemoveTimer("sysdash_think")
    }
}
__CollectGameEventCallbacks(::SystemDash.Events)

printl("[SystemDash] v1.1 Loaded — Dash global (SHIFT+WASD), 2 charges, 2.6s recharge")
printl("[SystemDash]   dashEnabled source: CharacterSystem.BaseAttributes | Particle: MaoLib_VFX.SpawnParticle")
printl("[SystemDash]   Debug=" + ::SystemDash.Debug)
