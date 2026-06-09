// ============================================================
// system_attributes.nut — Unified Attribute Engine
// ============================================================
// Capa 2: Reemplaza tactical movement de system_movement.nut
// Un solo think que aplica velocidad/friccion una vez por frame

if ("CharacterAttributes_init_guard" in getroottable()) return;
getroottable()["CharacterAttributes_init_guard"] <- true;

::CharacterAttributes <- {
    Debug = 1
    function Dbg(msg) { if (Debug) printl("[CharAttr][DEBUG] " + msg) }

    ADRENALINE_SPEED_MULT = 1.15
}

function CharacterAttributes::ComputeSpeedMultiplier(player) {
    if (!player || !player.IsValid() || !player.IsSurvivor()) return 1.0

    // Base speed is 1.0 — character-specific speed modifiers (e.g. Jason -15%)
    // are already registered in MaoLib.Modifiers via ApplyBaseAttributes().
    // We must NOT double-apply them here; Modifiers.GetSpeedMultiplier() already
    // includes char_base_* entries. Doing mult *= BaseAttributes.speedMult AND
    // mult *= Modifiers.GetSpeedMultiplier() caused double-stacking (Jason was -28%, not -15%).
    local mult = 1.0

    if (NetProps.GetPropInt(player, "m_bAdrenalineActive") == 1) {
        mult *= this.ADRENALINE_SPEED_MULT
    }

    mult *= ::MaoLib.Modifiers.GetSpeedMultiplier(player)

    return mult
}

function CharacterAttributes::ComputeFriction(player) {
    if (!player || !player.IsValid()) return 1.0
    local ext = ::MaoLib.Modifiers.GetFriction(player)
    return ext > 1.0 ? ext : 1.0
}

function CharacterAttributes::ApplyFrame(player) {
    if (!player || !player.IsValid() || !player.IsSurvivor()) return

    local isOnGround = !(NetProps.GetPropInt(player, "m_hGroundEntity") & 1)

    if (isOnGround) {
        local speed = this.ComputeSpeedMultiplier(player)
        NetProps.SetPropFloat(player, "m_flLaggedMovementValue", speed)
        player.SetFriction(this.ComputeFriction(player))
    } else {
        local extSpeed = ::MaoLib.Modifiers.GetSpeedMultiplier(player)
        if (extSpeed != 1.0) {
            NetProps.SetPropFloat(player, "m_flLaggedMovementValue", extSpeed)
        }
    }
}

function CharacterAttributes::Think() {
    foreach (player in ::MaoLib.YieldSurvivors()) {
        if (!player || !player.IsValid()) continue
        this.ApplyFrame(player)
    }
}

function CharacterAttributes::Init() {
    ::MaoLib.AddTimer("charattr_think", 0.05, function() {
        ::CharacterAttributes.Think()
    })
    this.Dbg("CharacterAttributes initialized")
}

::CharacterAttributes.Init()

::CharacterAttributes_Cleanup <- {
    function OnGameEvent_round_end(params) {
        MaoLib.RemoveTimer("charattr_think")
    }
}
__CollectGameEventCallbacks(::CharacterAttributes_Cleanup)

printl("[CharacterAttributes] Loaded v1.0")
