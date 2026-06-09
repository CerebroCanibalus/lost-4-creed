// sa_items.nut - Item management for Survivor AI
// ================================================================
// FILOSOFÍA: Módulo auto-contenido, minimalista, no intrusivo.
// Los bots recogen, usan y comparten items solo cuando la IA
// vanilla falla en manejarlos correctamente.
//
// Features:
//   - Recoger throwables del suelo (pipe, molotov, bile)
//   - Usar throwables según tipo (pipe→horde, molotov→tank, bile→horde/tank)
//   - Compartir throwables con humanos que no tengan uno
//
// Integración: Llamar DetectItemTask(bot) desde BotThink como
// tarea de baja prioridad. No requiere AddThinkToEnt ni timers.
// ================================================================

// ================================================================
// INVENTORY HELPERS
// ================================================================

/**
 * Obtiene el classname del throwable en slot2 (pipe/molotov/bile)
 * o null si no hay throwable equipado.
 */
function SurvivorAI::GetThrowableSlot(bot)
{
    if (!bot || !bot.IsValid()) return null
    local invTable = {}
    GetInvTable(bot, invTable)
    if (!("slot2" in invTable)) return null
    local weapon = invTable.slot2
    if (weapon && weapon.IsValid()) return weapon.GetClassname()
    return null
}

/**
 * Verifica si el bot tiene algún throwable equipado.
 */
function SurvivorAI::HasThrowable(bot)
{
    return this.GetThrowableSlot(bot) != null
}

/**
 * Clasifica un throwable por su tipo.
 * Returns: "PIPE", "MOLOTOV", "BILE", o null
 */
function SurvivorAI::ClassifyThrowable(classname)
{
    if (!classname) return null
    if (classname.find("pipe_bomb") != null) return "PIPE"
    if (classname.find("molotov") != null) return "MOLOTOV"
    if (classname.find("vomitjar") != null) return "BILE"
    return null
}

/**
 * Verifica si el bot puede usar un tipo específico de throwable
 * según la configuración UsePipeBomb/UseMolotov/UseVomitjar.
 * itemType: "PIPE", "MOLOTOV", "BILE"
 * targetType: "HORDE" o "TANK"
 */
function SurvivorAI::CanUseThrowable(itemType, targetType)
{
    if (itemType == "PIPE")
    {
        if (this.UsePipeBomb == 3) return true
        if (this.UsePipeBomb == 1 && targetType == "HORDE") return true
        if (this.UsePipeBomb == 2 && targetType == "TANK") return true
        return false
    }
    if (itemType == "MOLOTOV")
    {
        if (this.UseMolotov == 3) return true
        if (this.UseMolotov == 1 && targetType == "HORDE") return true
        if (this.UseMolotov == 2 && targetType == "TANK") return true
        return false
    }
    if (itemType == "BILE")
    {
        if (this.UseVomitjar == 3) return true
        if (this.UseVomitjar == 1 && targetType == "HORDE") return true
        if (this.UseVomitjar == 2 && targetType == "TANK") return true
        return false
    }
    return false
}

// ================================================================
// FIND HELPERS
// ================================================================

/**
 * Encuentra el throwable (pipe/molotov/bile) más cercano sin dueño.
 */
function SurvivorAI::FindNearestThrowable(origin, maxRange)
{
    local best = null
    local bestDist = null
    
    for (local ent = null; ent = Entities.FindByClassname(ent, "weapon_*"); )
    {
        if (ent.GetOwnerEntity() != null) continue
        
        local cls = ent.GetClassname()
        local isThrowable = (cls.find("pipe_bomb") != null ||
                             cls.find("molotov") != null ||
                             cls.find("vomitjar") != null)
        if (!isThrowable) continue
        
        local dist = (origin - ent.GetOrigin()).Length()
        if (dist > maxRange) continue
        
        // Verificar config: este tipo de throwable está habilitado?
        local itemType = this.ClassifyThrowable(cls)
        if (!itemType) continue
        if (!this.CanUseThrowable(itemType, "HORDE") && !this.CanUseThrowable(itemType, "TANK"))
            continue
        
        if (best == null || dist < bestDist)
        {
            best = ent
            bestDist = dist
        }
    }
    
    return best
}

/**
 * Encuentra un jugador humano (no bot) cerca que no tenga throwable.
 */
function SurvivorAI::FindHumanWithoutThrowable(bot, maxRange)
{
    local botPos = bot.GetOrigin()
    
    foreach (uid, s in this.CachedSurvivors)
    {
        if (!s || !s.IsValid()) continue
        if (IsPlayerABot(s)) continue  // Only give to humans
        
        local dist = (botPos - s.GetOrigin()).Length()
        if (dist > maxRange) continue
        
        if (!this.HasThrowable(s))
        {
            return s
        }
    }
    
    return null
}

/**
 * Encuentra un compañero bot cercano para darle un item (futuro).
 */
function SurvivorAI::FindNearestTeammate(bot, maxRange)
{
    local botPos = bot.GetOrigin()
    local best = null
    local bestDist = maxRange
    
    foreach (uid, s in this.CachedSurvivors)
    {
        if (!s || !s.IsValid()) continue
        if (s == bot) continue
        if (!IsPlayerABot(s)) continue  // Only bots
        
        local dist = (botPos - s.GetOrigin()).Length()
        if (dist < bestDist)
        {
            best = s
            bestDist = dist
        }
    }
    
    return best
}

// ================================================================
// DETECT: Item task detection (llamado desde BotThink)
// ================================================================

/**
 * Detecta si el bot necesita intervención con items.
 * Prioridades (bajas — no interferir con combate):
 *   35 = recoger throwable del suelo
 *   25 = dar throwable a humano
 */
function SurvivorAI::DetectItemTask(bot)
{
    local now = Time()
    local userid = bot.GetPlayerUserId()
    local botPos = bot.GetOrigin()
    
    // --- PRIORIDAD 35: RECOGER THROWABLE ---
    // Solo si el bot no tiene throwable y está habilitado
    if (this.ItemPickupEnabled && !this.HasThrowable(bot))
    {
        // Cooldown entre intentos de pickup
        if (!(userid in this.ItemPickupTimers) ||
            (now - this.ItemPickupTimers[userid]) >= this.ItemPickupCooldown)
        {
            // Set timer incluso si no encuentra nada (evita escanear cada tick)
            this.ItemPickupTimers[userid] <- now
            
            local item = this.FindNearestThrowable(botPos, this.ItemPickupRange)
            if (item)
            {
                this.LogDebug("ITEMS", "Bot " + userid + " found throwable nearby: " + item.GetClassname())
                return { type = "ITEM_PICKUP", priority = 35, item = item }
            }
        }
    }
    
    // --- PRIORIDAD 25: DAR THROWABLE A HUMANO ---
    // Solo si el bot tiene throwable y un humano cerca no tiene
    if (this.ItemGiveEnabled && this.HasThrowable(bot))
    {
        local target = this.FindHumanWithoutThrowable(bot, this.ItemGiveRange)
        if (target)
        {
            this.LogDebug("ITEMS", "Bot " + userid + " giving throwable to human " + target.GetPlayerUserId())
            return { type = "ITEM_GIVE", priority = 25, target = target }
        }
    }
    
    return null
}

// ================================================================
// EXECUTE: Item task execution
// ================================================================

/**
 * Ejecuta ITEM_PICKUP — bot recoge throwable del suelo.
 * Usa DoEntFire("Use") que es el mecanismo nativo de L4D2 para
 * que un bot "use" un item (equivalente a E key).
 */
function SurvivorAI::ExecutePickupItem(bot, task)
{
    local userid = bot.GetPlayerUserId()
    local item = task.item
    
    if (!item || !item.IsValid()) return false
    
    // Usar cooldown para evitar spam
    this.ItemPickupTimers[userid] <- Time()
    
    // El bot "usa" el item (como si presionara E)
    DoEntFire("!self", "Use", "", 0.0, bot, item)
    
    this.LogDebug("ITEMS", "Bot " + userid + " picking up " + item.GetClassname())
    return true
}

/**
 * Ejecuta ITEM_GIVE — bot da su throwable a un humano.
 * Usa GiveItem() que es nativo de L4D2.
 */
function SurvivorAI::ExecuteGiveItem(bot, task)
{
    local target = task.target
    if (!target || !target.IsValid()) return false
    
    local userid = bot.GetPlayerUserId()
    local throwable = this.GetThrowableSlot(bot)
    if (!throwable) return false
    
    // Dar el item al humano
    target.GiveItem(throwable)
    
    // Feedback sonoro
    EmitSoundOnClient("Hint.LittleReward", target)
    
    // Eliminar el item del bot (el GiveItem ya lo transfiere,
    // pero forzamos la eliminación del slot por seguridad)
    local invTable = {}
    GetInvTable(bot, invTable)
    if ("slot2" in invTable && invTable.slot2)
    {
        invTable.slot2.Kill()
    }
    
    this.LogDebug("ITEMS", "Bot " + userid + " gave " + throwable + " to human " + target.GetPlayerUserId())
    return true
}

printl("[SurvivorAI] sa_items.nut loaded — Item management module")
