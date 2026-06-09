::AWP_Explosive <-
{
    DEBUG = true
    EXPLOSION_RADIUS = 140
    DAMAGE_SPECIAL = 75
    DAMAGE_COMMON = 250
    DMG_BLAST_GIB = 64 | 512  // DMG_BLAST | DMG_ALWAYSGIB
    PENDING = {}
    
    VALID_WEAPONS =
    {
        weapon_sniper_awp = true
        weapon_sniper_scout = true
    }

    function DebugPrint(msg)
    {
        if(DEBUG) printl("[AWP_EXPLOSIVE] " + msg)
    }

    function OnGameEvent_round_start(params)
    {
        DebugPrint("Round started — clearing pending shots")
        
        // Clear pending queues
        foreach(userid, queue in PENDING)
        {
            delete PENDING[userid]
        }
        
        // Precache explosion sound via ambient_generic table
        PrecacheEntityFromTable({
            classname = "ambient_generic"
            message = "weapons/hegrenade/explode5.wav"
            health = 10
            spawnflags = 48
        })
    }

    function OnGameEvent_weapon_fire(params)
    {
        if(!("weapon" in params) || !("userid" in params))
            return
        
        local weapon = params.weapon
        if(weapon in VALID_WEAPONS)
        {
            if(!(params.userid in PENDING))
                PENDING[params.userid] <- []
            PENDING[params.userid].append({ time = Time(), weapon = weapon })
            DebugPrint("Shot registered: " + weapon + " | userid=" + params.userid + " | queue=" + PENDING[params.userid].len())
        }
    }

    function OnGameEvent_bullet_impact(params)
    {
        if(!("userid" in params) || !("x" in params))
            return
        
        local userid = params.userid
        if(!(userid in PENDING) || PENDING[userid].len() == 0)
            return
        
        local queue = PENDING[userid]
        local shot = queue[0]
        queue.remove(0)
        if(queue.len() == 0)
            delete PENDING[userid]
        
        // Safety: ignore stale shots
        local elapsed = Time() - shot.time
        if(elapsed > 2.0)
            return
        
        // CRITICAL: verify weapon hasn't changed since fire
        local weapon = shot.weapon
        if(!(weapon in VALID_WEAPONS))
            return
        
        local player = GetPlayerFromUserID(userid)
        if(!player || !player.IsValid() || !player.IsSurvivor())
            return
        
        local pos = Vector(params.x, params.y, params.z)
        DebugPrint("Impact at " + pos + " | weapon=" + weapon + " | elapsed=" + elapsed + "s")
        
        CreateExplosion(pos, player)
    }

    function CreateExplosion(pos, attacker)
    {
        // FX: Screen shake
        MaoLib_VFX.ScreenShake(pos, 6, 20, 0.4, 500)
        
        // FX: Explosion visual (medium = weapon_grenade_explosion)
        MaoLib_VFX.SpawnExplosion(pos, "medium")
        
        // FX: Sparks and debris
        MaoLib_VFX.SpawnParticle(pos, "impact_spark_spray", 0.5)
        MaoLib_VFX.SpawnParticle(pos, "impact_ricochet_sparks", 0.4)
        
        // Sound: Explosion
        MaoLib_VFX.EmitSoundAt(pos, "weapons/hegrenade/explode5.wav")
        
        local count = 0
        
        // Damage common infected (guaranteed gib with overkill blast damage)
        local ent = null
        while(ent = Entities.FindByClassnameWithin(ent, "infected", pos, EXPLOSION_RADIUS))
        {
            if(ent && ent.IsValid() && NetProps.GetPropInt(ent, "m_lifeState") == 0)
            {
                ent.TakeDamage(DAMAGE_COMMON, DMG_BLAST_GIB, attacker)
                MaoLib_VFX.SpawnParticle(ent.GetOrigin(), "blood_impact_red_01_chunk_shotgun", 0.8)
                count++
            }
        }
        
        // Damage witches
        ent = null
        while(ent = Entities.FindByClassnameWithin(ent, "witch", pos, EXPLOSION_RADIUS))
        {
            if(ent && ent.IsValid() && NetProps.GetPropInt(ent, "m_lifeState") == 0)
            {
                ent.TakeDamage(DAMAGE_SPECIAL, 64, attacker)
                count++
            }
        }
        
        // Damage special infected (player entities)
        ent = null
        while(ent = Entities.FindByClassnameWithin(ent, "player", pos, EXPLOSION_RADIUS))
        {
            if(ent && ent.IsValid() && !ent.IsSurvivor() && NetProps.GetPropInt(ent, "m_lifeState") == 0)
            {
                ent.TakeDamage(DAMAGE_SPECIAL, 64, attacker)
                count++
            }
        }
        
        DebugPrint("Explosion affected " + count + " entities")
    }
}

__CollectGameEventCallbacks(::AWP_Explosive)
printl("[AWP_EXPLOSIVE] Loaded v6.0 — Explosive Rounds Active")
