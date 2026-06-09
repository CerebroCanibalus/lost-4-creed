/**
 * ============================================================================
 * MaoLib_VFX - Sistema de Efectos Visuales y Sonoros para L4D2 VScript v2.2
 * ============================================================================
 * FIX v2.2: Entity pooling eliminado para info_particle_system y ambient_generic
 *           El engine requiere effect_name/message al spawn; __KeyValueFromString
 *           post-spawn no funciona. Ahora se spawnean entidades frescas con
 *           keyvalues correctos desde el inicio.
 * 
 * FEATURES:
 * - Spawn fresco de info_particle_system (effect_name correcto desde spawn)
 * - Budget por Prioridad: critical/gameplay/ambient con límites independientes
 * - Sonidos: EmitAmbientSoundOn nativo con info_target dummy (no ambient_generic pooling)
 * - SpawnExplosion: reutiliza env_explosion (patrón rifle M203)
 * - Auto-precache, SafeKill, GetEffectPosition (LookupBone-safe)
 * 
 * DEPENDENCIAS: MaoLib (auto-cargada)
 * API PÚBLICA: Compatible v1.x (sin breaking changes)
 * ============================================================================
 */

if ("MaoLib_VFX" in getroottable()) return;

::MaoLib_VFX <- {
    // ============================================================
    // CONFIGURACIÓN
    // ============================================================
    DEFAULT_PARTICLE_LIFETIME = 3.0,
    
    // Budget por prioridad (partículas por segundo)
    BUDGET = {
        critical = { max = 8,  decay = 0.5 },  // Explosiones, impactos gameplay
        gameplay = { max = 12, decay = 0.3 },  // Sangre, trails, debris
        ambient  = { max = 4,  decay = 0.2 }   // Humo, partículas ambientales
    },
    
    // ============================================================
    // ESTADO INTERNO
    // ============================================================
    _particles_this_frame = 0,
    _last_frame_time      = 0,
    
    // Budget tracking por tiempo real
    _spawn_counts    = { critical = 0, gameplay = 0, ambient = 0 },
    _last_budget_reset = 0,
    
    // Explosion reutilizable (env_explosion SÍ se puede reusar vía input)
    _explosion_entity = null,
    _explosion_template = {
        classname = "env_explosion",
        targetname = "maolib_vfx_explosion",
        iRadiusOverride = 120,
        iMagnitude = 0,
        spawnflags = 6 | 256,
        rendermode = 5,
        ignoredClass = 1,
        origin = Vector(0, 0, 0)
    },
    
    // Precache
    _precached_sounds = {},
    
    // ============================================================
    // THROTTLE POR PRIORIDAD
    // ============================================================
    
    function CanSpawnParticle(priority = "gameplay") {
        local now = Time()
        
        // Reset budget cada segundo aproximadamente
        if (now >= _last_budget_reset + 1.0) {
            _spawn_counts = { critical = 0, gameplay = 0, ambient = 0 }
            _last_budget_reset = now
        }
        
        // Throttle frame-based (legacy, preventivo)
        if (now > _last_frame_time) {
            _particles_this_frame = 0
            _last_frame_time = now
        }
        if (_particles_this_frame >= 8) {  // Hard cap frame
            return false
        }
        
        // Budget por prioridad
        local budget = BUDGET[priority]
        if (!budget) budget = BUDGET.gameplay
        
        return _spawn_counts[priority] < budget.max
    },
    
    function _TrackSpawn(priority) {
        _spawn_counts[priority]++
        _particles_this_frame++
    },
    
    // ============================================================
    // PARTICLES (SPAWN FRESCO — effect_name desde el inicio)
    // ============================================================
    
    function SpawnParticle(pos, effect, lifetime = 3.0, priority = "gameplay") {
        if (!CanSpawnParticle(priority)) {
            return null
        }
        
        if (!IsValidPosition(pos)) {
            printl("[MaoLib_VFX] ERROR: posición inválida")
            return null
        }
        
        if (effect == null || effect == "") {
            printl("[MaoLib_VFX] ERROR: effect name vacío")
            return null
        }
        
        // Spawn fresco con effect_name correcto DESDE EL INICIO
        local particle = SpawnEntityFromTable("info_particle_system", {
            effect_name = effect,
            origin = pos
        })
        
        if (!particle || !particle.IsValid()) {
            printl("[MaoLib_VFX] ERROR: falló spawn de info_particle_system para '" + effect + "'")
            return null
        }
        
        // Iniciar
        DoEntFire("!self", "Start", "", 0.0, null, particle)
        _TrackSpawn(priority)
        
        // Auto-kill después de lifetime
        if (lifetime > 0) {
            SafeKill(particle, lifetime)
        }
        
        return particle
    },
    
    function SpawnParticleOnEntity(entity, effect, attachment = "", lifetime = 3.0, priority = "gameplay") {
        if (!entity || !entity.IsValid()) {
            printl("[MaoLib_VFX] ERROR: entidad inválida")
            return null
        }
        
        if (!CanSpawnParticle(priority)) {
            return null
        }
        
        local pos = GetEffectPosition(entity)
        
        local particle = SpawnEntityFromTable("info_particle_system", {
            effect_name = effect,
            origin = pos
        })
        
        if (!particle || !particle.IsValid()) {
            printl("[MaoLib_VFX] ERROR: falló spawn de info_particle_system para '" + effect + "'")
            return null
        }
        
        if (attachment != "") {
            particle.SetParent(entity, attachment)
        } else {
            particle.SetParent(entity)
        }
        
        DoEntFire("!self", "Start", "", 0.0, null, particle)
        _TrackSpawn(priority)
        
        if (lifetime > 0) {
            SafeKill(particle, lifetime)
        }
        
        return particle
    },
    
    function SpawnTrail(entity, effect, attachment = "", priority = "gameplay") {
        if (!entity || !entity.IsValid()) {
            printl("[MaoLib_VFX] ERROR: entidad inválida en SpawnTrail")
            return null
        }
        
        if (!CanSpawnParticle(priority)) {
            return null
        }
        
        local pos = GetEffectPosition(entity)
        
        local particle = SpawnEntityFromTable("info_particle_system", {
            effect_name = effect,
            origin = pos
        })
        
        if (!particle || !particle.IsValid()) {
            printl("[MaoLib_VFX] ERROR: falló spawn de info_particle_system para '" + effect + "'")
            return null
        }
        
        if (attachment != "") {
            particle.SetParent(entity, attachment)
        } else {
            particle.SetParent(entity)
        }
        
        DoEntFire("!self", "Start", "", 0.0, null, particle)
        _TrackSpawn(priority)
        
        // Trails NO se auto-kill (se detienen manualmente con StopParticle)
        return particle
    },
    
    function StopParticle(particle, fade_out = false) {
        if (!particle || !particle.IsValid()) return
        
        if (fade_out) {
            DoEntFire("!self", "Stop", "", 0.0, null, particle)
            SafeKill(particle, 0.5)
        } else {
            SafeKill(particle, 0.0)
        }
    },
    
    // ============================================================
    // EXPLOSIONES
    // ============================================================
    
    function SpawnExplosion(pos, size = "medium") {
        if (!_explosion_entity || !_explosion_entity.IsValid()) {
            _explosion_entity = SpawnEntityFromTable("env_explosion", _explosion_template)
            if (!_explosion_entity || !_explosion_entity.IsValid()) {
                printl("[MaoLib_VFX] ERROR: No se pudo crear env_explosion")
                return
            }
        }
        
        if (!IsValidPosition(pos)) {
            printl("[MaoLib_VFX] ERROR: posición inválida para SpawnExplosion")
            return
        }
        
        _explosion_entity.SetOrigin(pos)
        DoEntFire("!self", "Explode", "", 0.0, null, _explosion_entity)
        
        switch(size) {
            case "small":
                SpawnParticle(pos, "weapon_pipebomb_child_explosion", 1.0, "critical")
                SpawnParticle(pos, "smoke_small_01", 2.0, "ambient")
                break
            case "medium":
                SpawnParticle(pos, "weapon_grenade_explosion", 1.5, "critical")
                SpawnParticle(pos, "smoke_medium_01", 3.0, "ambient")
                SpawnParticle(pos, "impact_spark_spray", 0.5, "gameplay")
                break
            case "large":
                SpawnParticle(pos, "explosion_huge_b", 2.5, "critical")
                SpawnParticle(pos, "smoke_large_01", 5.0, "ambient")
                SpawnParticle(pos, "impact_spark_spray_large", 1.0, "gameplay")
                break
            default:
                SpawnParticle(pos, "weapon_grenade_explosion", 1.5, "critical")
                break
        }
    },
    
    // ============================================================
    // IMPACTOS
    // ============================================================
    
    function SpawnImpact(pos, normal, type = "generic", scale = 1.0) {
        if (!IsValidPosition(pos)) return
        
        local effect = null
        switch(type) {
            case "blood":    effect = "blood_impact_red_01"; break
            case "concrete": effect = "impact_concrete"; break
            case "metal":    effect = "impact_metal"; break
            case "wood":     effect = "impact_wood"; break
            case "dirt":     effect = "impact_dirt"; break
            case "water":    effect = "impact_water"; break
            default:         effect = "impact_generic_burst"; break
        }
        
        if (effect) {
            SpawnParticle(pos, effect, 1.0, "gameplay")
        }
        
        if (type == "metal" || type == "concrete") {
            SpawnParticle(pos, "impact_spark_spray", 0.3, "gameplay")
        }
    },
    
    // ============================================================
    // DECALS
    // ============================================================
    
    function SpawnDecal(pos, normal, type = "blood", size = 1.0) {
        if (!IsValidPosition(pos)) return false
        
        local texture = null
        switch(type) {
            case "blood":       texture = "{bloodpool}"; break
            case "blood_pool":  texture = "{bloodpool}"; break
            case "bullet":      texture = "decals/impact_bullet"; break
            case "scorch":      texture = "decals/scorch"; break
            case "impact_concrete": texture = "decals/concrete/impact"; break
            default:            texture = type; break
        }
        
        if (!texture) {
            printl("[MaoLib_VFX] ERROR: tipo de decal desconocido: " + type)
            return false
        }
        
        // NOTA: info_projecteddecal está PROHIBIDO en L4D2 (causa crash).
        // Usamos infodecal que es el decal estándar del engine.
        local decal = SpawnEntityFromTable("infodecal", {
            texture = texture
        })
        
        if (!decal || !decal.IsValid()) {
            printl("[MaoLib_VFX] ERROR: Falló spawn de infodecal")
            return false
        }
        
        decal.SetOrigin(pos)
        DoEntFire("!self", "Activate", "", 0.0, null, decal)
        SafeKill(decal, 0.1)
        
        return true
    },
    
    // ============================================================
    // SONIDOS (SIN POOLING — spawn fresco o nativo directo)
    // ============================================================
    
    function EmitSound(entity, sound, volume = 1.0, pitch = 100) {
        if (!entity || !entity.IsValid()) {
            printl("[MaoLib_VFX] ERROR: entidad inválida en EmitSound")
            return
        }
        
        if (sound == null || sound == "") {
            printl("[MaoLib_VFX] ERROR: sound path vacío")
            return
        }
        
        // Auto-precache
        if (!(sound in _precached_sounds)) {
            if (!IsSoundPrecached(sound)) {
                PrecacheSound(sound)
            }
            _precached_sounds[sound] <- true
        }
        
        // Pitch default (100): nativo más rápido y limpio
        if (pitch == 100) {
            EmitSoundOn(sound, entity)
            return
        }
        
        // Pitch personalizado: usar EmitAmbientSoundOn con dummy info_target
        // ambient_generic NO soporta SetParent() y __KeyValueFromString("message")
        // post-spawn no funciona correctamente para cambiar el sonido.
        local dummy = SpawnEntityFromTable("info_target", {
            origin = entity.GetOrigin(),
            targetname = "maolib_vfx_sd_" + UniqueString()
        })
        
        if (dummy && dummy.IsValid()) {
            EmitAmbientSoundOn(sound, volume, 0, pitch, dummy)
            SafeKill(dummy, 5.0)
        }
    },
    
    function EmitSoundAt(pos, sound, volume = 1.0, pitch = 100) {
        if (!IsValidPosition(pos)) {
            printl("[MaoLib_VFX] ERROR: posición inválida en EmitSoundAt")
            return
        }
        
        if (sound == null || sound == "") {
            printl("[MaoLib_VFX] ERROR: sound path vacío")
            return
        }
        
        if (!(sound in _precached_sounds)) {
            if (!IsSoundPrecached(sound)) {
                PrecacheSound(sound)
            }
            _precached_sounds[sound] <- true
        }
        
        local dummy = SpawnEntityFromTable("info_target", {
            origin = pos,
            targetname = "maolib_vfx_sd_" + UniqueString()
        })
        
        if (dummy && dummy.IsValid()) {
            EmitAmbientSoundOn(sound, volume, 0, pitch, dummy)
            SafeKill(dummy, 5.0)
        }
    },
    
    function EmitSoundOnClient(player, sound) {
        if (!player || !player.IsValid() || !player.IsPlayer()) {
            printl("[MaoLib_VFX] ERROR: player inválido en EmitSoundOnClient")
            return
        }
        
        if (sound == null || sound == "") {
            printl("[MaoLib_VFX] ERROR: sound path vacío")
            return
        }
        
        if (!(sound in _precached_sounds)) {
            if (!IsSoundPrecached(sound)) {
                PrecacheSound(sound)
            }
            _precached_sounds[sound] <- true
        }
        
        getroottable().EmitSoundOnClient(sound, player)
    },
    
    // ============================================================
    // SCREEN EFFECTS
    // ============================================================
    
    function ScreenShake(pos, amplitude = 4, frequency = 10, duration = 1.0, radius = 0) {
        if (!IsValidPosition(pos)) {
            printl("[MaoLib_VFX] ERROR: posición inválida en ScreenShake")
            return
        }
        
        local shaker = SpawnEntityFromTable("env_shake", {
            origin = pos,
            amplitude = amplitude,
            frequency = frequency,
            duration = duration,
            radius = radius
        })
        
        if (!shaker || !shaker.IsValid()) {
            printl("[MaoLib_VFX] ERROR: Falló spawn de env_shake")
            return
        }
        
        DoEntFire("!self", "StartShake", "", 0.0, null, shaker)
        SafeKill(shaker, duration + 0.5)
    },
    
    function ScreenEffect(players, effect, duration = 1.0) {
        local targets = []
        
        if (players == null) {
            local player = null
            while (player = Entities.FindByClassname(player, "player")) {
                if (player.IsSurvivor() && player.IsValid()) {
                    targets.append(player)
                }
            }
        } else if (typeof players == "array") {
            targets = players
        } else {
            targets = [players]
        }
        
        local particle_name = null
        switch(effect) {
            case "blood":       particle_name = "screen_blood_splatter"; break
            case "bashed":      particle_name = "screen_bashed"; break
            case "adrenaline":  particle_name = "screen_adrenaline"; break
            case "mud":         particle_name = "screen_mud_splatter"; break
            default:
                printl("[MaoLib_VFX] ERROR: efecto de pantalla desconocido: " + effect)
                return
        }
        
        foreach (player in targets) {
            if (!player || !player.IsValid()) continue
            
            local pos = player.EyePosition()
            local particle = SpawnParticle(pos, particle_name, duration, "gameplay")
            if (particle && particle.IsValid()) {
                particle.SetParent(player)
            }
        }
    },
    
    // ============================================================
    // UTILIDADES
    // ============================================================
    
    function GetEffectPosition(entity) {
        if (!entity || !entity.IsValid()) {
            return Vector(0, 0, 0)
        }
        
        local classname = entity.GetClassname()
        if (classname == "infected") {
            return entity.GetOrigin() + Vector(0, 0, 32)
        }
        if (entity.IsPlayer()) {
            return entity.EyePosition()
        }
        return entity.GetOrigin()
    },
    
    function IsValidPosition(pos) {
        if (pos == null) return false
        return pos.x != 0 || pos.y != 0 || pos.z != 0
    },
    
    function SafeKill(entity, delay = 0.0) {
        if (!entity || !entity.IsValid()) return
        
        if (delay <= 0) {
            entity.Kill()
        } else {
            DoEntFire("!self", "Kill", "", delay, null, entity)
        }
    },
    
    // ============================================================
    // INIT / CLEANUP
    // ============================================================
    
    function Init(cleanup_interval = 0) {
        // Explosion
        if (!_explosion_entity || !_explosion_entity.IsValid()) {
            _explosion_entity = SpawnEntityFromTable("env_explosion", _explosion_template)
            if (_explosion_entity && _explosion_entity.IsValid()) {
                printl("[MaoLib_VFX] env_explosion reutilizable creado")
            }
        }
        
        // Reset estado
        _precached_sounds = {}
        _spawn_counts = { critical = 0, gameplay = 0, ambient = 0 }
        _last_budget_reset = Time()
        _particles_this_frame = 0
        _last_frame_time = 0
        
        // Cleanup timer
        if (cleanup_interval > 0) {
            if (MaoLib.HasTimer("maolib_vfx_cleanup")) {
                MaoLib.RemoveTimer("maolib_vfx_cleanup")
            }
            MaoLib.AddTimer("maolib_vfx_cleanup", cleanup_interval, function() {
                ::MaoLib_VFX._CleanupOrphans()
            })
        }
    },
    
    function _CleanupOrphans() {
        // Limpiar dummies de sonido (FindByName NO soporta wildcards en Source)
        // Iteramos por classname y filtramos por targetname manualmente
        local ent = null
        while (ent = Entities.FindByClassname(ent, "info_target")) {
            if (ent && ent.IsValid()) {
                local name = ent.GetName()
                if (name.len() >= 15 && name.slice(0, 15) == "maolib_vfx_sd_") {
                    ent.Kill()
                }
            }
        }
        
        // Verificar explosion
        if (_explosion_entity && !_explosion_entity.IsValid()) {
            _explosion_entity = null
        }
        
        // Reset budget
        _spawn_counts = { critical = 0, gameplay = 0, ambient = 0 }
        _particles_this_frame = 0
        _last_frame_time = 0
    },
    
    // ============================================================
    // PATRONES GEOMETRICOS DE PARTICULAS
    // ============================================================
    
    /**
     * Spawnea un anillo de partículas en un círculo.
     * @param center   Vector — centro del anillo
     * @param radius   Float — radio del anillo
     * @param count    Int — cantidad de partículas (recomendado: 8-24)
     * @param effect   String — nombre de la partícula
     * @param opts     Tabla opcional:
     *   duration  = segundos de vida (default: 2.0)
     *   expand    = bool — el anillo se expande (default: false)
     *   vertical  = bool — anillo vertical en vez de horizontal (default: false)
     *   priority  = string (default: "gameplay")
     * @return       Array de handles de partículas
     */
    function SpawnRing(center, radius, count, effect, opts = null) {
        local duration = 2.0
        local expand = false
        local vertical = false
        local priority = "gameplay"
        
        if (opts != null) {
            if ("duration" in opts) duration = opts.duration
            if ("expand" in opts) expand = opts.expand
            if ("vertical" in opts) vertical = opts.vertical
            if ("priority" in opts) priority = opts.priority
        }
        
        local particles = []
        local angleStep = (2.0 * PI) / count
        
        for (local i = 0; i < count; i++) {
            local angle = angleStep * i
            local pos = null
            
            if (vertical) {
                // Anillo vertical (en plano Y-Z)
                pos = center + Vector(0, cos(angle) * radius, sin(angle) * radius)
            } else {
                // Anillo horizontal (en plano X-Y)
                pos = center + Vector(cos(angle) * radius, sin(angle) * radius, 0)
            }
            
            local p = SpawnParticle(pos, effect, duration, priority)
            if (p) particles.append(p)
        }
        
        // Si expand=true, animar el radio con keyframes
        if (expand && particles.len() > 0) {
            Keyframes.AnimateRing(particles, center, radius, duration, vertical)
        }
        
        return particles
    },
    
    /**
     * Spawnea una espiral 3D de partículas.
     * @param center   Vector — base de la espiral
     * @param opts     Tabla:
     *   radius    = radio inicial (default: 50)
     *   height    = altura total (default: 150)
     *   turns     = vueltas completas (default: 3)
     *   count     = partículas (default: 24)
     *   effect    = nombre de partícula
     *   duration  = segundos (default: 3.0)
     *   priority  = string (default: "gameplay")
     * @return       Array de handles
     */
    function SpawnSpiral(center, opts = null) {
        local radius = 50.0
        local height = 150.0
        local turns = 3.0
        local count = 24
        local effect = ""
        local duration = 3.0
        local priority = "gameplay"
        
        if (opts != null) {
            if ("radius" in opts) radius = opts.radius
            if ("height" in opts) height = opts.height
            if ("turns" in opts) turns = opts.turns
            if ("count" in opts) count = opts.count
            if ("effect" in opts) effect = opts.effect
            if ("duration" in opts) duration = opts.duration
            if ("priority" in opts) priority = opts.priority
        }
        
        if (effect == "" || count <= 0) return []
        
        local particles = []
        local angleStep = (2.0 * PI * turns) / count
        local heightStep = height / count
        
        for (local i = 0; i < count; i++) {
            local angle = angleStep * i
            local h = heightStep * i
            local pos = center + Vector(cos(angle) * radius, sin(angle) * radius, h)
            
            local p = SpawnParticle(pos, effect, duration, priority)
            if (p) particles.append(p)
        }
        
        return particles
    },
    
    /**
     * Spawnea una onda sinusoidal entre dos puntos.
     * @param start    Vector — punto inicial
     * @param end      Vector — punto final
     * @param opts     Tabla:
     *   amplitude  = altura máxima de la ola (default: 50)
     *   frequency  = ciclos completos (default: 4)
     *   count      = partículas (default: 32)
     *   effect     = nombre de partícula
     *   duration   = segundos (default: 2.0)
     *   priority   = string (default: "gameplay")
     * @return       Array de handles
     */
    function SpawnWave(start, end, opts = null) {
        local amplitude = 50.0
        local frequency = 4.0
        local count = 32
        local effect = ""
        local duration = 2.0
        local priority = "gameplay"
        
        if (opts != null) {
            if ("amplitude" in opts) amplitude = opts.amplitude
            if ("frequency" in opts) frequency = opts.frequency
            if ("count" in opts) count = opts.count
            if ("effect" in opts) effect = opts.effect
            if ("duration" in opts) duration = opts.duration
            if ("priority" in opts) priority = opts.priority
        }
        
        if (effect == "" || count <= 0) return []
        
        local particles = []
        local direction = end - start
        local length = direction.Length()
        local normalized = direction.Scale(1.0 / length)
        
        // Vector perpendicular para la amplitud
        local perp = Vector(-normalized.y, normalized.x, 0)
        if (perp.LengthSqr() < 0.001) {
            perp = Vector(0, 0, 1)
        }
        perp = perp.Scale(1.0 / perp.Length())
        
        for (local i = 0; i < count; i++) {
            local t = i.tofloat() / (count - 1)
            local basePos = start + normalized.Scale(length * t)
            local waveOffset = sin(t * PI * 2 * frequency) * amplitude
            local pos = basePos + perp.Scale(waveOffset)
            
            local p = SpawnParticle(pos, effect, duration, priority)
            if (p) particles.append(p)
        }
        
        return particles
    },
    
    /**
     * Spawnea una línea curva (arco) entre dos puntos.
     * @param start    Vector — punto inicial
     * @param end      Vector — punto final
     * @param opts     Tabla:
     *   height     = altura del ápice (default: 100)
     *   count      = partículas (default: 20)
     *   effect     = nombre de partícula
     *   duration   = segundos (default: 2.0)
     *   priority   = string (default: "gameplay")
     * @return       Array de handles
     */
    function SpawnCurve(start, end, opts = null) {
        local height = 100.0
        local count = 20
        local effect = ""
        local duration = 2.0
        local priority = "gameplay"
        
        if (opts != null) {
            if ("height" in opts) height = opts.height
            if ("count" in opts) count = opts.count
            if ("effect" in opts) effect = opts.effect
            if ("duration" in opts) duration = opts.duration
            if ("priority" in opts) priority = opts.priority
        }
        
        if (effect == "" || count <= 0) return []
        
        local particles = []
        local mid = (start + end) * 0.5
        mid.z += height  // Ápice arriba
        
        for (local i = 0; i < count; i++) {
            local t = i.tofloat() / (count - 1)
            // Interpolación cuadrática de Bézier
            local pos = start.Scale((1-t)*(1-t)) + mid.Scale(2*(1-t)*t) + end.Scale(t*t)
            
            local p = SpawnParticle(pos, effect, duration, priority)
            if (p) particles.append(p)
        }
        
        return particles
    },
    
    /**
     * Spawnea un círculo lleno usando distribución sunflower (fibonacci).
     * @param center   Vector — centro
     * @param radius   Float — radio máximo
     * @param opts     Tabla:
     *   count      = partículas (default: 50)
     *   effect     = nombre de partícula
     *   duration   = segundos (default: 1.5)
     *   priority   = string (default: "gameplay")
     * @return       Array de handles
     */
    function SpawnCircleFilled(center, radius, opts = null) {
        local count = 50
        local effect = ""
        local duration = 1.5
        local priority = "gameplay"
        
        if (opts != null) {
            if ("count" in opts) count = opts.count
            if ("effect" in opts) effect = opts.effect
            if ("duration" in opts) duration = opts.duration
            if ("priority" in opts) priority = opts.priority
        }
        
        if (effect == "" || count <= 0) return []
        
        local particles = []
        local goldenAngle = PI * (3.0 - sqrt(5.0))  // ~2.39996 radianes
        
        for (local i = 0; i < count; i++) {
            local r = sqrt(i.tofloat() / count) * radius
            local theta = i * goldenAngle
            local pos = center + Vector(cos(theta) * r, sin(theta) * r, 0)
            
            local p = SpawnParticle(pos, effect, duration, priority)
            if (p) particles.append(p)
        }
        
        return particles
    },
    
    // ============================================================
    // SISTEMA DE KEYFRAMES Y EASING
    // ============================================================
    
    Keyframes = {
        // Easing functions
        EaseLinear = function(t) { return t },
        
        EaseInSine = function(t) { return 1.0 - cos((t * PI) / 2.0) },
        EaseOutSine = function(t) { return sin((t * PI) / 2.0) },
        EaseInOutSine = function(t) { return -(cos(PI * t) - 1.0) / 2.0 },
        
        EaseInQuad = function(t) { return t * t },
        EaseOutQuad = function(t) { return 1.0 - (1.0 - t) * (1.0 - t) },
        EaseInOutQuad = function(t) {
            if (t < 0.5) return 2.0 * t * t
            return 1.0 - pow(-2.0 * t + 2.0, 2) / 2.0
        },
        
        EaseOutBack = function(t) {
            local c1 = 1.70158
            local c3 = c1 + 1.0
            return 1.0 + c3 * pow(t - 1.0, 3) + c1 * pow(t - 1.0, 2)
        },
        
        EaseOutElastic = function(t) {
            local c4 = (2.0 * PI) / 3.0
            if (t == 0) return 0
            if (t == 1) return 1
            return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * c4) + 1.0
        },
        
        EaseOutBounce = function(t) {
            local n1 = 7.5625
            local d1 = 2.75
            if (t < 1.0 / d1) {
                return n1 * t * t
            } else if (t < 2.0 / d1) {
                local t2 = t - 1.5 / d1
                return n1 * t2 * t2 + 0.75
            } else if (t < 2.5 / d1) {
                local t2 = t - 2.25 / d1
                return n1 * t2 * t2 + 0.9375
            } else {
                local t2 = t - 2.625 / d1
                return n1 * t2 * t2 + 0.984375
            }
        },
        
        // Lookup table para easing por nombre
        _GetEasing = function(name) {
            switch(name) {
                case "linear": return ::MaoLib_VFX.Keyframes.EaseLinear
                case "easeInSine": return ::MaoLib_VFX.Keyframes.EaseInSine
                case "easeOutSine": return ::MaoLib_VFX.Keyframes.EaseOutSine
                case "easeInOutSine": return ::MaoLib_VFX.Keyframes.EaseInOutSine
                case "easeInQuad": return ::MaoLib_VFX.Keyframes.EaseInQuad
                case "easeOutQuad": return ::MaoLib_VFX.Keyframes.EaseOutQuad
                case "easeInOutQuad": return ::MaoLib_VFX.Keyframes.EaseInOutQuad
                case "easeOutBack": return ::MaoLib_VFX.Keyframes.EaseOutBack
                case "easeOutElastic": return ::MaoLib_VFX.Keyframes.EaseOutElastic
                case "easeOutBounce": return ::MaoLib_VFX.Keyframes.EaseOutBounce
                default: return ::MaoLib_VFX.Keyframes.EaseLinear
            }
        },
        
        /**
         * Interpola entre dos vectores usando easing.
         * @param a     Vector — valor inicial
         * @param b     Vector — valor final
         * @param t     Float — 0.0 a 1.0
         * @param ease  String — nombre del easing
         * @return      Vector — valor interpolado
         */
        LerpVector = function(a, b, t, ease = "linear") {
            local easingFunc = ::MaoLib_VFX.Keyframes._GetEasing(ease)
            local et = easingFunc(t)
            return a + (b - a) * et
        },
        
        /**
         * Interpola entre dos floats usando easing.
         * @param a     Float — valor inicial
         * @param b     Float — valor final
         * @param t     Float — 0.0 a 1.0
         * @param ease  String — nombre del easing
         * @return      Float — valor interpolado
         */
        LerpFloat = function(a, b, t, ease = "linear") {
            local easingFunc = ::MaoLib_VFX.Keyframes._GetEasing(ease)
            local et = easingFunc(t)
            return a + (b - a) * et
        },
        
        /**
         * Anima una propiedad de entidad usando keyframes.
         * @param entity     Handle — entidad a animar
         * @param property   String — "position", "origin", "angles"
         * @param keyframes  Array — [ { time = 0.0, value = x, ease = "linear" }, ... ]
         * @param duration   Float — duración total en segundos
         * @return           String — nombre del timer (para cancelar)
         */
        Animate = function(entity, property, keyframes, duration) {
            if (!entity || !entity.IsValid()) return null
            if (keyframes.len() < 2) return null
            
            local timerName = "vfx_anim_" + UniqueString()
            local startTime = Time()
            
            MaoLib.AddTimer(timerName, 0.05, function() {
                // Verificar que entity sigue vivo
                if (!entity || !entity.IsValid()) {
                    MaoLib.RemoveTimer(timerName)
                    return
                }
                
                local elapsed = Time() - startTime
                local t = elapsed / duration
                
                if (t >= 1.0) {
                    // Final: aplicar último keyframe
                    local last = keyframes[keyframes.len() - 1]
                    ::MaoLib_VFX.Keyframes._ApplyValue(entity, property, last.value)
                    MaoLib.RemoveTimer(timerName)
                    return
                }
                
                // Encontrar keyframes actual y siguiente
                local currentIdx = 0
                for (local i = 0; i < keyframes.len() - 1; i++) {
                    if (t >= keyframes[i].time && t < keyframes[i + 1].time) {
                        currentIdx = i
                        break
                    }
                }
                // Fallback: si t está más allá del último par, usar los últimos dos
                if (t >= keyframes[keyframes.len() - 1].time) {
                    currentIdx = keyframes.len() - 2
                }
                
                local k1 = keyframes[currentIdx]
                local k2 = keyframes[currentIdx + 1]
                
                // Normalizar t entre los dos keyframes (proteger división por cero)
                local timeDiff = k2.time - k1.time
                if (timeDiff <= 0) timeDiff = 0.001
                local localT = (t - k1.time) / timeDiff
                local ease = "ease" in k2 ? k2.ease : "linear"
                
                // Interpolar
                local val = null
                if (typeof k1.value == "Vector") {
                    val = ::MaoLib_VFX.Keyframes.LerpVector(k1.value, k2.value, localT, ease)
                } else {
                    val = ::MaoLib_VFX.Keyframes.LerpFloat(k1.value, k2.value, localT, ease)
                }
                
                ::MaoLib_VFX.Keyframes._ApplyValue(entity, property, val)
            })
            
            return timerName
        },
        
        /**
         * Anima un anillo de partículas expandiéndose.
         * Uso interno por SpawnRing con expand=true.
         */
        AnimateRing = function(particles, center, startRadius, duration, vertical) {
            local timerName = "vfx_ring_" + UniqueString()
            local startTime = Time()
            local targetRadius = startRadius * 3.0  // Expande 3x
            
            MaoLib.AddTimer(timerName, 0.05, function() {
                local elapsed = Time() - startTime
                local t = elapsed / duration
                
                if (t >= 1.0 || particles.len() == 0) {
                    MaoLib.RemoveTimer(timerName)
                    return
                }
                
                local et = ::MaoLib_VFX.Keyframes.EaseOutSine(t)
                local currentRadius = startRadius + (targetRadius - startRadius) * et
                local count = particles.len()
                local angleStep = (2.0 * PI) / count
                
                for (local i = 0; i < count; i++) {
                    local p = particles[i]
                    if (!p || !p.IsValid()) continue
                    
                    local angle = angleStep * i
                    local pos = null
                    
                    if (vertical) {
                        pos = center + Vector(0, cos(angle) * currentRadius, sin(angle) * currentRadius)
                    } else {
                        pos = center + Vector(cos(angle) * currentRadius, sin(angle) * currentRadius, 0)
                    }
                    
                    p.SetOrigin(pos)
                }
            })
        },
        
        // Aplica valor a propiedad de entidad
        _ApplyValue = function(entity, property, value) {
            if (!entity || !entity.IsValid()) return
            
            switch(property) {
                case "position":
                case "origin":
                    entity.SetOrigin(value)
                    break
                case "angles":
                    entity.SetAngles(value)
                    break
                case "health":
                    entity.SetHealth(value.tointeger())
                    break
                case "modelscale":
                    entity.SetModelScale(value, 0.0)
                    break
            }
        }
    }
}

printl("[MaoLib_VFX] v2.2 cargado — spawn fresco + budget + patrones + keyframes")
