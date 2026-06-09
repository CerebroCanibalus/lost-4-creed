// survivor_ai/config.nut - Configuration and state for Minimal Intervention AI
// Philosophy: Intervene ONLY when vanilla AI fails. Be minimal.

::SurvivorAI <-
{
    // ------------------------------------------------------------------
    // TIMING
    // ------------------------------------------------------------------
    ThinkInterval = 0.2           // 5Hz - reactivo gracias al entity cache
    
    // ------------------------------------------------------------------
    // COOLDOWNS (seconds)
    // ------------------------------------------------------------------
    ShoveCooldown = 0.8           // Reduced from 2.5s - more responsive
    CommandCooldown = 0.3         // Min time between CommandABot per bot
    RescueTimeoutSmoker = 2.0     // Seconds before we intervene on smoker pin
    RescueTimeoutHunter = 3.0     // Seconds before we intervene on hunter pin
    RescueTimeoutJockey = 3.0     // Seconds before we intervene on jockey pin
    RescueTimeoutCharger = 2.0    // Seconds before we intervene on charger pin
    StuckThreshold = 3.0          // Seconds without movement = stuck
    
    // ------------------------------------------------------------------
    // DISTANCES
    // ------------------------------------------------------------------
    RescueMaxDist = 2000          // Max distance to rescue a teammate
    // NOTE: Shove range is ~75 units. Only shove when commons are VERY close and MANY.
    // Pros don't shove 2-3 commons at 150u - they shove 5-10 that are amassed in melee range.
    CommonDetectRadius = 100      // Reduced to actual shove range (~75u + buffer)
    CommonShoveThreshold = 5      // Only shove when 5+ commons amassed (was 2)
    CommonShoveMax = 10           // Consider it a horde when 10+ commons
    TankDangerRange = 200         // Critical distance to tank
    TankKiteRange = 800           // Optimal distance to maintain from tank
    SIAttackRange = 800           // Range to trigger SI attack intervention
    TeamSeparationThreshold = 600 // Max distance from team before regrouping
    
    // ------------------------------------------------------------------
    // MOVEMENT
    // ------------------------------------------------------------------
    StuckMinDist = 75             // Minimum distance to count as "moved"
    UnstickSearchRadius = 300     // Radius to search for unstick position
    
    // ------------------------------------------------------------------
    // NAVMESH VALIDATION
    // ------------------------------------------------------------------
    NavValidationRadius = 500     // Max distance to search for valid nav area
    
    // ------------------------------------------------------------------
    // RUNTIME STATE
    // ------------------------------------------------------------------
    // Bot tracking
    BotLastCommandTime = {}       // userid -> last CommandABot timestamp
    BotLastShoveTime = {}         // userid -> last shove timestamp
    BotPositions = {}             // userid -> { pos, time }
    BotStuckState = {}            // userid -> bool
    
    // Pin tracking (to detect overdue rescues)
    PinStartTime = {}             // victim_userid -> timestamp when pinned
    
    // Event-driven state tables (populated by core events, read by detector)
    SpitBursts = {}               // entityid -> { pos, time } — active spit puddles
    ChargerCharges = {}           // charger_userid -> { startPos, startTime } — active charges
    DeathAcidPositions = {}       // entityid -> { pos, time } — spitter death acid
    TongueTargets = {}            // victim_userid -> attacker — active tongue grabs
    LastHordeNadeTime = {}        // userid -> timestamp — cooldown per bot
    ItemPickupTimers = {}         // userid -> timestamp — cooldown per bot pickup
    
    // Per-bot think tracking
    BotThinkTimers = {}           // userid -> timer name
    
    // ------------------------------------------------------------------
    // ENTITY CACHE (actualizado por eventos, NO escaneado cada frame)
    // ------------------------------------------------------------------
    CachedSpecials = {}           // userid -> entity (Special Infected no-tank)
    CachedTanks = {}              // userid -> entity (Tanks)
    CachedSurvivors = {}          // userid -> entity (Survivors)
    
    // Debug
    DebugEnabled = false          // Set to true for verbose logging
    ThinkCount = 0                // Total think iterations
    
    // ------------------------------------------------------------------
    // VISION SYSTEM
    // ------------------------------------------------------------------
    VisionFOV = 120                // Field of view in degrees
    VisionMaxDistance = 600        // Max distance to scan for SI
    VisionCommonRadius = 300       // Radius to scan for visible commons
    VisionCacheTime = 0.25         // How long to cache vision results (seconds)
    VisionScanInterval = 0.15      // Min time between scans per bot (seconds)
    
    // ------------------------------------------------------------------
    // CHARGER COMBAT
    // ------------------------------------------------------------------
    ChargerOptimalRange = 400      // Ideal distance to attack Charger
    ChargerMinRange = 150          // Too close - back up
    ChargerMaxRange = 1200         // Too far - move closer
    
    // ------------------------------------------------------------------
    // MANUAL ATTACK
    // ------------------------------------------------------------------
    ManualAttackInterval = 0.05    // How often to force fire (seconds)
    DeadstopRange = 150            // Range for automatic deadstop
    
    // ------------------------------------------------------------------
    // TONGUE RESCUE (teammate being strangled by Smoker)
    // ------------------------------------------------------------------
    TongueShoveRange = 150         // Max distance to shove tongue off teammate
    ShootTongueRange = 800         // Max distance to shoot tongue (instead of shove)
    
    // ------------------------------------------------------------------
    // EVENT-DRIVEN DODGE (spit burst, charger charge, death acid)
    // ------------------------------------------------------------------
    SpitDodgeRange = 300           // Distance to flee from spit burst
    ChargerDodgeRange = 400        // Distance threshold for charge dodge
    DeathAcidDodgeRange = 250      // Distance to flee from death acid
    
    // ------------------------------------------------------------------
    // AUTO GRENADES (molotov/bile vs tank, pipe vs horde)
    // ------------------------------------------------------------------
    TankNadeRange = 800            // Max distance to throw nade at tank
    TankNadeChance = 0.25          // Probability per think tick
    HordeNadeRange = 500           // Max distance to throw nade at horde
    HordeNadeSize = 10             // Min commons count for horde nade
    HordeNadeChance = 0.30         // Probability per think tick
    
    // ------------------------------------------------------------------
    // HEAL INTERRUPT (prevent wasting medkits)
    // ------------------------------------------------------------------
    HealInterruptThreshold = 50    // Health ≥ this → interrupt heal
    
    // ------------------------------------------------------------------
    // FALL WARP (teleport to teammate on fatal fall)
    // ------------------------------------------------------------------
    FallWarpVelocity = -750        // Vertical velocity threshold (negative = falling)
    FallWarpDistance = 500         // Max distance to teammate for warp
    
    // ------------------------------------------------------------------
    // SAFEROOM DOOR CLOSE
    // ------------------------------------------------------------------
    DoorCloseRadius = 400          // Distance to checkpoint door to close it
    DoorCloseDelay = 1.5           // Seconds after checkpoint to try closing
    
    // ------------------------------------------------------------------
    // ITEM SYSTEM (pickup, use, give)
    // Separado en módulo sa_items.nut — minimalista, auto-contenido
    // ------------------------------------------------------------------
    ItemPickupEnabled = 1          // Bots recogen throwables del suelo
    ItemGiveEnabled = 1            // Bots dan throwables a humanos sin uno
    ItemPickupRange = 150          // Distancia máxima para recoger item
    ItemGiveRange = 200            // Distancia máxima para dar item
    ItemPickupCooldown = 2.0       // Segundos entre intentos de pickup
    ItemThrowCooldown = 20.0       // Segundos entre lanzamientos
    MobSizeToThrow = 6             // Mínimo de commons para lanzar granada
    UsePipeBomb = 3                // 0=no usar, 1=horde, 2=tank, 3=ambos
    UseMolotov = 3                 // 0=no usar, 1=horde, 2=tank, 3=ambos
    UseVomitjar = 0                // 0=humans only (bile atrae horda al lanzador — muy peligroso para bots), 1=horde, 2=tank, 3=ambos
    
    // ------------------------------------------------------------------
    // PER-BOT THINK
    // ------------------------------------------------------------------
    BotThinkInterval = 0.25        // Per-bot think interval (vs global 0.3)
    
    // ------------------------------------------------------------------
    // VISION RUNTIME STATE
    // ------------------------------------------------------------------
    BotVision = {}                 // userid -> vision state
}

printl("[SurvivorAI] config.nut - TABLE DEFINIDA exitosamente")
printl("[SurvivorAI] config.nut - typeof(::SurvivorAI) = " + typeof(::SurvivorAI))

// ================================================================
// SHOULD SCAN CHECK
// Definida AQUÍ (no dentro del table literal) para evitar
// problemas de sintaxis con métodos en definiciones de tabla
// ================================================================
printl("[SurvivorAI] config.nut - ANTES de asignar ShouldVisionScan")
::SurvivorAI.ShouldVisionScan <- function(bot)
{
    if (!bot || !bot.IsValid())
        return false
    
    local userid = bot.GetPlayerUserId()
    if (!(userid in this.BotVision) || !this.BotVision[userid])
        return true
    
    local vision = this.BotVision[userid]
    return (Time() - vision.lastScan) >= this.VisionScanInterval
}

// Math constant (necesario para acos() * 180 / PI)
::PI <- 3.141592653589793

// Input constants (built-ins, definidos por si acaso)
::IN_ATTACK <- 1        // Fire button
::IN_ATTACK2 <- 2048    // Melee/shove button

// Zombie class constants
::ZOMBIE_CLASS_SMOKER <- 1
::ZOMBIE_CLASS_BOOMER <- 2
::ZOMBIE_CLASS_HUNTER <- 3
::ZOMBIE_CLASS_SPITTER <- 4
::ZOMBIE_CLASS_JOCKEY <- 5
::ZOMBIE_CLASS_CHARGER <- 6
::ZOMBIE_CLASS_WITCH <- 7
::ZOMBIE_CLASS_TANK <- 8

// Nav attributes
::NAV_MESH_CHECKPOINT <- 4096  // 0x1000 - CHECKPOINT nav area flag

printl("[SurvivorAI] config.nut - DESPUES de asignar ShouldVisionScan, exists? " + ("ShouldVisionScan" in ::SurvivorAI))
printl("[SurvivorAI] config.nut loaded")
