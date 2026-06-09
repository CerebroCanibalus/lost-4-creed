// MaoLib cargado exclusivamente por l4cCoreAddon

// NOTA: lepotitsa eliminado (erradicado del modpack)
// NOTA: hound eliminado — exclusivo de l4cCustomInfected

::GoreDebug <- true; // Set false to silence debug prints

// ============================================
// ULTRA GORE - RAGDOLL VERSION WITH PHYSICS + ATTACHED PARTICLES
// ============================================

if (::GoreDebug) printl("[GoreSystem] Initializing tables...");

GoreModels <- {
    brains = [
        "models/infected/limbs/brain_01.mdl",
        "models/infected/limbs/brain_02.mdl", 
        "models/infected/limbs/brain_03.mdl"
    ],
    heart = "models/infected/limbs/heart_veins.mdl",
    steaks = [
        "models/infected/limbs/steak1.mdl",
        "models/infected/limbs/steak2.mdl",
        "models/infected/limbs/steak3.mdl",
    ]
};

// Track last hit info for each infected
LastHitInfo <- {};
getroottable()["LastHitInfo"] <- LastHitInfo;

// Particle mapping by body part and direction
ParticleMap <- {
    // Head particles
    head = [
        "gore_wound_arterial_spray_1",
        "gore_wound_arterial_spray_2", 
        "gore_wound_arterial_spray_3",
        "gore_wound_brain",
        "gore_wound_jaw"
    ],
    // Chest/belly (front)
    chest_front = [
        "gore_wound_belly_right",
        "gore_wound_belly_left",
        "gore_wound_fullbody_1"
    ],
    // Chest/back (rear)
    chest_back = [
        "gore_wound_back_lower", 
        "gore_wound_back"
    ],
    // Groin
    groin = [
        "gore_wound_groin",
        "gore_wound_groin_2"
    ],
    // Arms
    arms = [
        "gore_wound_arterial_spray_1",
        "gore_wound_arterial_spray_2",
        "gore_wound_arterial_spray_3"
    ]
};

// Special Tank particles
TankParticles <- [
    "blood_impact_tank_01",
    "blood_impact_red_01_backspray_shotgun",
    "blood_impact_red_01_chunk_shotgun",
];

// Bone mapping for different hitgroups
BoneMap <- {
    [0] = "ValveBiped.Bip01_Spine2", // Default/General
    [1] = "ValveBiped.Bip01_Head1", // Head
    [2] = "ValveBiped.Bip01_Spine2", // Chest
    [3] = "ValveBiped.Bip01_Spine", // Stomach
    [4] = "ValveBiped.Bip01_L_UpperArm", // Left Arm
    [5] = "ValveBiped.Bip01_R_UpperArm", // Right Arm
    [6] = "ValveBiped.Bip01_L_Thigh", // Left Leg
    [7] = "ValveBiped.Bip01_R_Thigh" // Right Leg
};

// Gib limits to prevent lag
GibLimits <- {
    maxTotalGibs = 30,      // Maximum gibs in the world at once
    maxGibsPerKill = 8,     // Maximum gibs per kill (except tank)
    gibLifetime = 3.0,      // How long gibs last (seconds)
    tankGibLifetime = 5.0,  // Tank gibs last longer
    cleanupInterval = 5.0   // How often to clean old hit info (seconds)
};
getroottable()["GibLimits"] <- GibLimits;

// Track active gibs
ActiveGibs <- [];
getroottable()["ActiveGibs"] <- ActiveGibs;
LastCleanupTime <- 0.0;
getroottable()["LastCleanupTime"] <- LastCleanupTime;

function Gore_round_start(params)
{
    if (::GoreDebug) printl("[GoreSystem] round_start - Precaching gore models...");
    
    // Precache brains
    local precached = 0;
    foreach (brain in GoreModels.brains)
    {
        try { PrecacheModel(brain); precached++; } catch(e) { if (::GoreDebug) printl("[GoreSystem] Failed to precache brain: " + brain); }
    }
    
    // Precache heart
    try { PrecacheModel(GoreModels.heart); precached++; } catch(e) { if (::GoreDebug) printl("[GoreSystem] Failed to precache heart"); }
    
    if (::GoreDebug) printl("[GoreSystem] round_start - Precached " + precached + " models");
    
    // Precache steaks
    foreach (steak in GoreModels.steaks)
    {
        try { PrecacheModel(steak); } catch(e) {}
    }
    
    // Precache particles
    foreach (particleList in ParticleMap)
    {
        foreach (particle in particleList)
        {
            try { PrecacheParticleSystem(particle); } catch(e) {}
        }
    }
    
    // Precache tank particles
    foreach (particle in TankParticles)
    {
        try { PrecacheParticleSystem(particle); } catch(e) {}
    }
    
    // Clear all tracking
    LastHitInfo.clear();
    ActiveGibs.clear();
    LastCleanupTime = Time();
    
   
}

function Gore_player_hurt(params)
{
    if (!("userid" in params) || !("hitgroup" in params)) return;
    
    local victim = GetPlayerFromUserID(params.userid);
    if (!victim || !victim.IsValid()) return;
    
    if (victim.GetClassname() != "player") return;
    
    // ADD TEAM CHECK USING NETPROPS
    local team = NetProps.GetPropInt(victim, "m_iTeamNum");
    if (team == 2) return; // Survivor team = 2
    
    local zombieType = 0;
    try { zombieType = victim.GetZombieType(); } catch(e) { return; }
    
    if (zombieType == 0) return; // Skip survivors (redundant but safe)
    if (zombieType == 2) return; // Boomer skip — intencional: ya sueltan muchísima partícula por su explosión nativa
    
    if (::GoreDebug) printl("[GoreSystem] player_hurt - Infected zType=" + zombieType + " hitgroup=" + params.hitgroup);
	
    // Clean old hit info periodically
    ::CleanupOldHitInfo();
    
    // Get attacker for direction calculation
    local attacker = null;
    if ("attacker" in params && params.attacker > 0 && params.attacker != params.userid)
    {
        attacker = GetPlayerFromUserID(params.attacker);
    }
    
    // Determine direction of hit (front/back)
    local direction = "front";
    if (attacker && attacker.IsValid() && attacker != victim)
    {
        local victimOrigin = victim.GetOrigin();
        local attackerOrigin = attacker.GetOrigin();
        
        // Get victim's forward direction from angles
        local victimAngles = victim.GetAngles();
        
        // Convert yaw (y angle) to forward vector
        local yaw = victimAngles.y;
        local rad = yaw * (3.14159 / 180.0); // Convert to radians
        local victimForward = Vector(cos(rad), sin(rad), 0);
        
        // Get direction from victim to attacker
        local toAttacker = attackerOrigin - victimOrigin;
        toAttacker.z = 0; // Ignore vertical difference
        toAttacker.Norm();
        
        // Calculate dot product
        local dot = victimForward.x * toAttacker.x + victimForward.y * toAttacker.y;
        
        if (dot < 0) // Attacker is behind if dot product is negative
            direction = "back";
    }
    
    // Store last hit info with bone position
    local victimIdx = victim.GetEntityIndex();
    local bonePos = null;
    local boneName = "";
    
    // Get bone position for the hitgroup
    if (params.hitgroup in BoneMap) {
        boneName = BoneMap[params.hitgroup];
        try {
            local boneIndex = victim.LookupBone(boneName);
            if (boneIndex != -1) {
                bonePos = victim.GetBoneOrigin(boneIndex);
            }
        } catch(e) {
            // If bone lookup fails, use center of mass
            bonePos = victim.GetOrigin() + Vector(0, 0, 40);
        }
    } else {
        // Default position
        bonePos = victim.GetOrigin() + Vector(0, 0, 40);
        boneName = "center";
    }
    
    LastHitInfo[victimIdx] <- {
        hitgroup = params.hitgroup,
        direction = direction,
        time = Time(),
        bonePos = bonePos,
        boneName = boneName
    };
    
    // Clean up old entries
    ::CleanupOldHitInfo();
}

function CleanupOldHitInfo()
{
    local currentTime = Time();
    
    // Only clean up every X seconds
    if (currentTime - LastCleanupTime < GibLimits.cleanupInterval) {
        return;
    }
    
    LastCleanupTime = currentTime;
    
    // Remove entries older than 30 seconds
    local toRemove = [];
    foreach (idx, info in LastHitInfo)
    {
        if (currentTime - info.time > 30.0) {
            toRemove.push(idx);
        }
    }
    
    foreach (idx in toRemove)
    {
        delete LastHitInfo[idx];
    }
    
    if (toRemove.len() > 0 && ::GoreDebug) {
        printl("[GoreSystem] Cleaned up " + toRemove.len() + " old hit info entries");
    }
}

function CleanupOldGibs()
{
    local currentTime = Time();
    local toRemove = [];
    
    // Check all active gibs
    foreach (i, gibInfo in ActiveGibs)
    {
        local gib = gibInfo.gib;
        if (!gib || !gib.IsValid()) {
            toRemove.push(i);
            continue;
        }
        
        // Remove gib if it's been around too long
        if (currentTime - gibInfo.spawnTime > gibInfo.lifetime) {
            try {
                gib.Kill();
            } catch(e) {}
            toRemove.push(i);
        }
    }
    
    // Remove from array (reverse order to maintain indices)
    for (local i = toRemove.len() - 1; i >= 0; i--)
    {
        ActiveGibs.remove(toRemove[i]);
    }
    
    // If we have too many gibs, remove the oldest ones
    if (ActiveGibs.len() > GibLimits.maxTotalGibs)
    {
        // Sort by spawn time (oldest first)
        ActiveGibs.sort(function(a, b) {
            if (a.spawnTime < b.spawnTime) return -1
            if (a.spawnTime > b.spawnTime) return 1
            return 0
        });
        
        local removeCount = ActiveGibs.len() - GibLimits.maxTotalGibs;
        for (local i = 0; i < removeCount; i++)
        {
            if (i < ActiveGibs.len())
            {
                local oldGib = ActiveGibs[i].gib;
                if (oldGib && oldGib.IsValid()) {
                    try {
                        oldGib.Kill();
                    } catch(e) {}
                }
            }
        }
        
        // Remove from array
        ActiveGibs = ActiveGibs.slice(removeCount);
       
    }
}

function Gore_player_death(params)
{
    if (!("userid" in params)) return;
    
    local victim = GetPlayerFromUserID(params.userid);
    if (!victim || !victim.IsValid()) return;
    
    if (victim.GetClassname() != "player") return;
    
    // ADD TEAM CHECK USING NETPROPS
    local team = NetProps.GetPropInt(victim, "m_iTeamNum");
    if (team == 2) return; // Survivor team = 2
    
    local zombieType = 0;
    try { zombieType = victim.GetZombieType(); } catch(e) { return; }
    
    if (zombieType == 0) return; // Skip survivors (redundant but safe)
    if (zombieType == 2) return; // Boomer skip — intencional: ya sueltan muchísima partícula por su explosión nativa
    
    if (::GoreDebug) printl("[GoreSystem] player_death - Infected zType=" + zombieType + " ActiveGibs=" + ActiveGibs.len());
	 
    local pos = victim.GetOrigin();
    local victimIdx = victim.GetEntityIndex();
    
    // Clean up old gibs before spawning new ones
    ::CleanupOldGibs();
    
    // Get last hit info
    local hitgroup = -1;
    local direction = "front";
    local bonePos = null;
    local boneName = "";
    
    if (victimIdx in LastHitInfo)
    {
        hitgroup = LastHitInfo[victimIdx].hitgroup;
        direction = LastHitInfo[victimIdx].direction;
        bonePos = LastHitInfo[victimIdx].bonePos;
        boneName = LastHitInfo[victimIdx].boneName;
        delete LastHitInfo[victimIdx]; // Clean up immediately
    }
    else if ("hitgroup" in params)
    {
        hitgroup = params.hitgroup;
        // Try to get bone info now if we don't have it stored
        if (hitgroup in BoneMap) {
            boneName = BoneMap[hitgroup];
            try {
                local boneIndex = victim.LookupBone(boneName);
                if (boneIndex != -1) {
                    bonePos = victim.GetBoneOrigin(boneIndex);
                }
            } catch(e) {
                // If bone lookup fails, use center of mass
                bonePos = victim.GetOrigin() + Vector(0, 0, 40);
            }
        } else {
            // Default position
            bonePos = victim.GetOrigin() + Vector(0, 0, 40);
            boneName = "center";
        }
    }
    
    // If still no bone position, use default
    if (bonePos == null) {
        bonePos = victim.GetOrigin() + Vector(0, 0, 40);
        boneName = "center";
    }
    
    local weapon = ("weapon" in params) ? params.weapon : "";
    
    
    
    // Spawn blood based on infected type
    if (zombieType == 8) // Tank
    {
        // Bigger blood effect for tank
        local blood = SpawnEntityFromTable("info_particle_system", {
            origin = pos + Vector(0, 0, 60),
            effect_name = "blood_impact_red_01_chunk_shotgun",
            start_active = 1
        });
        if (blood) EntFire("!self", "Kill", "", 2, blood);
        
        // Extra tank blood explosion
        local explosion = SpawnEntityFromTable("info_particle_system", {
            origin = pos + Vector(0, 0, 50),
            effect_name = "blood_impact_tank_01",
            start_active = 1
        });
        if (explosion) EntFire("!self", "Kill", "", 3, explosion);
    }
    else
    {
        // Normal blood for other infected
        local blood = SpawnEntityFromTable("info_particle_system", {
            origin = pos + Vector(0, 0, 40),
            effect_name = "blood_impact_red_01",
            start_active = 1
        });
        if (blood) EntFire("!self", "Kill", "", 1, blood);
    }
    
    // ATTACHED PARTICLES BASED ON LAST HIT
    if (zombieType == 8) // Tank gets special particles
    {
        AttachTankGoreParticles(hitgroup, direction, bonePos);
    }
    else
    {
        AttachGoreParticles(hitgroup, direction, bonePos);
    }
    
    // Determine chunk count with limits
    local chunkCount = RandomInt(3, 5);
    
    // More for heavy weapons
    if (weapon.find("shotgun") != null) chunkCount += 2;
    if (weapon.find("pipe") != null || weapon.find("grenade") != null) chunkCount += 4;
    if (zombieType == 7) chunkCount += 2; // Witch
    
    // Apply per-kill limit (except for tank)
    if (zombieType != 8 && chunkCount > GibLimits.maxGibsPerKill) {
        if (::GoreDebug) printl("[GoreSystem] Limiting gibs: " + chunkCount + " -> " + GibLimits.maxGibsPerKill + " (per-kill cap)");
        chunkCount = GibLimits.maxGibsPerKill;
    }
    
    // Tank gets more but still limited
    if (zombieType == 8) {
        chunkCount += 8; // Tank gets more chunks
        if (chunkCount > 15) chunkCount = 15; // Cap at 15 for tank
    }
    
    // BRAIN SPAWN ONLY FOR HEADSHOT
    local brainSpawned = false;
    
    // For tank headshots, spawn multiple brains!
    local brainCount = 1;
    if (zombieType == 8 && hitgroup == 1) {
        brainCount = RandomInt(2, 4); // 2-4 brains for tank headshot
    }
    
    // Spawn chunks
    for (local i = 0; i < chunkCount; i++)
    {
        // Choose model based on hitgroup
        local model = "";
        
        // Spawn brain only for headshots
        if (hitgroup == 1 && brainSpawned == false)
        {
            model = GoreModels.brains[RandomInt(0, GoreModels.brains.len() - 1)];
            brainSpawned = true;
            
            
            // For tank, check if we should spawn more brains
            if (zombieType == 8 && brainCount > 1) {
                brainCount--;
                brainSpawned = false; // Reset to spawn another brain
            }
        }
        // Second chunk could be heart (but not if we spawned brain)
        else if (i == 1 && RandomInt(1, 100) > 70 && !brainSpawned)
        {
            model = GoreModels.heart;
        }
        // Rest are steaks
        else
        {
            model = GoreModels.steaks[RandomInt(0, GoreModels.steaks.len() - 1)];
        }
        
        // If no model selected (e.g., not headshot but brain check failed), use steak
        if (model == "")
        {
            model = GoreModels.steaks[RandomInt(0, GoreModels.steaks.len() - 1)];
        }
        
        // Spawn position around body
        local spawnPos = pos + Vector(
            RandomInt(-30, 30),
            RandomInt(-30, 30),
            20 + RandomInt(0, 20)
        );
        
        // For tank, chunks fly further
        if (zombieType == 8) {
            spawnPos = pos + Vector(
                RandomInt(-50, 50),
                RandomInt(-50, 50),
                30 + RandomInt(0, 40)
            );
        }
        
        // Spawn as ragdoll
		local ragdollAngles = QAngle(RandomInt(0, 360), RandomInt(0, 360), RandomInt(0, 360));
		local ragdoll = SpawnEntityFromTable("prop_ragdoll", {
            origin = spawnPos,
            angles = ragdollAngles.x + " " + ragdollAngles.y + " " + ragdollAngles.z,
            model = model,
            spawnflags = 4
        });
        
        if (ragdoll)
        {
            // Apply physics force to ragdoll
            local velocity = Vector(
                RandomInt(-200, 200),
                RandomInt(-200, 200),
                RandomInt(150, 300)
            );
            
            // For tank, more force!
            if (zombieType == 8) {
                velocity = Vector(
                    RandomInt(-400, 400),
                    RandomInt(-400, 400),
                    RandomInt(300, 600)
                );
            }
            
            // Get all bones and apply force
            for (local bone = 0; bone < 10; bone++)
            {
                try {
                    local bonePos = ragdoll.GetBoneOrigin(bone);
                    if (bonePos)
                    {
                        // Apply impulse at bone position
                        ragdoll.ApplyAbsVelocityImpulse(velocity);
                        break;
                    }
                } catch(e) {}
            }
            
            // Determine gib lifetime
            local gibLifetime = GibLimits.gibLifetime;
            if (zombieType == 8) gibLifetime = GibLimits.tankGibLifetime;
            
            // Add some randomness to lifetime
            gibLifetime += RandomFloat(-0.5, 0.5);
            
            // Kill after delay
            EntFire("!self", "Kill", "", gibLifetime, ragdoll);
            
            // Track this gib
            ActiveGibs.push({
                gib = ragdoll,
                spawnTime = Time(),
                lifetime = gibLifetime
            });
            
            
        }
    }
}

function AttachGoreParticles(hitgroup, direction, bonePos)
{
    if (bonePos == null) return;
    
    local particleList = null;
    
    // Determine particle based on hitgroup and direction
    switch(hitgroup)
    {
        case 0: // General/unknown hit
            // Random chest or back particle
            if (direction == "front")
                particleList = ParticleMap.chest_front;
            else
                particleList = ParticleMap.chest_back;
            break;
            
        case 1: // Head
            particleList = ParticleMap.head;
            break;
            
        case 2: // Chest
        case 3: // Stomach
            if (direction == "front")
                particleList = ParticleMap.chest_front;
            else
                particleList = ParticleMap.chest_back;
            break;
            
        case 4: // Left Arm
        case 5: // Right Arm
            particleList = ParticleMap.arms;
            break;
            
        case 6: // Left Leg
        case 7: // Right Leg
            // Check if it's groin hit (upper leg)
            if (RandomInt(1, 100) > 70) // 30% chance for groin
                particleList = ParticleMap.groin;
            else
                // Use chest particles for leg hits (no specific leg particles in your list)
                particleList = ParticleMap.chest_front;
            break;
            
        default:
            // Random body part for general hits
            local randomChoice = RandomInt(1, 3);
            if (randomChoice == 1)
            {
                particleList = ParticleMap.chest_front;
            }
            else if (randomChoice == 2)
            {
                particleList = ParticleMap.arms;
            }
            break;
    }
    
    // If we have a valid particle list, create the particle
    if (particleList != null)
    {
        local particleName = particleList[RandomInt(0, particleList.len() - 1)];
        
        // Create particle system at stored bone position
        local particle = SpawnEntityFromTable("info_particle_system", {
            origin = bonePos,
            effect_name = particleName,
            start_active = 1
        });
        
        if (particle)
        {
            // Kill the particle after ragdoll duration
            EntFire("!self", "Kill", "", 4, particle); // Reduced from 7 to 4 seconds
            
            // Create additional blood effect
            local bloodParticle = SpawnEntityFromTable("info_particle_system", {
                origin = bonePos,
                effect_name = "blood_impact_headshot_01",
                start_active = 1
            });
            if (bloodParticle) {
                EntFire("!self", "Kill", "", 1, bloodParticle);
            }
        }
    }
}

function AttachTankGoreParticles(hitgroup, direction, bonePos)
{
    if (bonePos == null) return;
    
    // Tank gets multiple big blood particles (reducido — tank_death.nut maneja secuencia completa)
    local particleCount = RandomInt(2, 3);
    
    for (local i = 0; i < particleCount; i++)
    {
        // Get random tank particle
        local particleName = TankParticles[RandomInt(0, TankParticles.len() - 1)];
        
        // Offset position for multiple particles
        local offsetPos = bonePos + Vector(
            RandomInt(-20, 20),
            RandomInt(-20, 20),
            RandomInt(-10, 30)
        );
        
        // Create particle system
        local particle = SpawnEntityFromTable("info_particle_system", {
            origin = offsetPos,
            effect_name = particleName,
            start_active = 1
        });
        
        if (particle)
        {
            // Tank particles last longer but not too long
            EntFire("!self", "Kill", "", RandomInt(2, 4), particle); // Reduced from 3-5
            
            // For headshots, add extra particles
            if (hitgroup == 1 && i == 0) {
                local extraParticle = SpawnEntityFromTable("info_particle_system", {
                    origin = bonePos + Vector(0, 0, 20),
                    effect_name = "blood_impact_red_01",
                    start_active = 1
                });
                if (extraParticle) {
                    EntFire("!self", "Kill", "", 3, extraParticle); // Reduced from 4
                }
            }
        }
    }
    
    // Always create a big blood explosion for tank
    local explosion = SpawnEntityFromTable("info_particle_system", {
        origin = bonePos + Vector(0, 0, 30),
        effect_name = "blood_impact_red_01",
        start_active = 1
    });
    if (explosion) {
        EntFire("!self", "Kill", "", 2, explosion); // Reduced from 3
    }
}

// Also handle witch
function Gore_witch_killed(params)
{
    if (!("witchid" in params)) return;
    
    local witch = EntIndexToHScript(params.witchid);
    if (!witch || !witch.IsValid()) return;
    
    if (::GoreDebug) printl("[GoreSystem] witch_killed - ActiveGibs=" + ActiveGibs.len());
    
    local pos = witch.GetOrigin();
    local hitgroup = ("hitgroup" in params) ? params.hitgroup : -1;
	
	
    // Clean up old gibs before spawning new ones
    ::CleanupOldGibs();
    
    // Spawn blood
    local blood = SpawnEntityFromTable("info_particle_system", {
        origin = pos + Vector(0, 0, 50),
        effect_name = "blood_impact_red_01",
        start_active = 1
    });
    if (blood) EntFire("!self", "Kill", "", 1.5, blood);
    
    // For witch, use center position
    local bonePos = pos + Vector(0, 0, 50);
    
    // ATTACHED PARTICLES FOR WITCH (assume front hit)
    AttachGoreParticles(hitgroup, "front", bonePos);
    
    // BRAIN SPAWN ONLY FOR HEADSHOT
    local brainSpawned = false;
    
    // Spawn chunks for witch (limited)
    local chunkCount = RandomInt(6, 9);
    if (chunkCount > GibLimits.maxGibsPerKill) {
        chunkCount = GibLimits.maxGibsPerKill;
    }
    
    for (local i = 0; i < chunkCount; i++)
    {
        local model = "";
        
        // Spawn brain only for headshots
        if (!brainSpawned && hitgroup == 1)
        {
            model = GoreModels.brains[RandomInt(0, GoreModels.brains.len() - 1)];
            brainSpawned = true;
        }
        else if (i == 1 && !brainSpawned)
        {
            model = GoreModels.heart;
        }
        else
        {
            model = GoreModels.steaks[RandomInt(0, GoreModels.steaks.len() - 1)];
        }
        
        // Default to steak if no model selected
        if (model == "")
        {
            model = GoreModels.steaks[RandomInt(0, GoreModels.steaks.len() - 1)];
        }
        
        local spawnPos = pos + Vector(
            RandomInt(-40, 40),
            RandomInt(-40, 40),
            30 + RandomInt(0, 30)
        );
        
		local ragdollAngles = QAngle(RandomInt(0, 360), RandomInt(0, 360), RandomInt(0, 360));
        local ragdoll = SpawnEntityFromTable("prop_ragdoll", {
            origin = spawnPos,
            angles = ragdollAngles.x + " " + ragdollAngles.y + " " + ragdollAngles.z,
            model = model,
			disableshadows = 1,
		    spawnflags = 4,
        });
        
        if (ragdoll)
        {
            // Apply velocity
            try {
                ragdoll.ApplyAbsVelocityImpulse(Vector(
                    RandomInt(-250, 250),
                    RandomInt(-250, 250),
                    RandomInt(200, 400)
                ));
            } catch(e) {}
            
            // Kill after shorter delay
            local gibLifetime = GibLimits.gibLifetime + RandomFloat(-0.5, 0.5);
            EntFire("!self", "Kill", "", gibLifetime, ragdoll);
            
            // Track this gib
            ActiveGibs.push({
                gib = ragdoll,
                spawnTime = Time(),
                lifetime = gibLifetime
            });
        }
    }
}

printl("==================================");
printl("ULTRA GORE SYSTEM WITH GIB LIMITS");
printl("Features:");
printl("  - Gib limits: Max " + GibLimits.maxTotalGibs + " total gibs");
printl("==================================");

// Create references in getroottable() so ::GoreSystem can find them
// (functions are in DirectorScript scope, not getroottable())
getroottable()["Gore_round_start"] <- Gore_round_start;
getroottable()["Gore_player_hurt"] <- Gore_player_hurt;
getroottable()["Gore_player_death"] <- Gore_player_death;
getroottable()["Gore_witch_killed"] <- Gore_witch_killed;
getroottable()["CleanupOldHitInfo"] <- CleanupOldHitInfo;
getroottable()["CleanupOldGibs"] <- CleanupOldGibs;

// Event handlers in dedicated table (replaces global auto-detect to avoid conflicts)
// try/catch wrappers ensure a crash here doesn't cascade to other scripts' handlers
::GoreSystem <-
{
    function OnGameEvent_round_start(params)
    {
        try { ::Gore_round_start(params); }
        catch(e) { if (::GoreDebug) printl("[GoreSystem] ERROR in Gore_round_start: " + e); }
    }
    function OnGameEvent_player_hurt(params)
    {
        try { ::Gore_player_hurt(params); }
        catch(e) { if (::GoreDebug) printl("[GoreSystem] ERROR in Gore_player_hurt: " + e); }
    }
    function OnGameEvent_player_death(params)
    {
        try { ::Gore_player_death(params); }
        catch(e) { if (::GoreDebug) printl("[GoreSystem] ERROR in Gore_player_death: " + e); }
    }
    function OnGameEvent_witch_killed(params)
    {
        try { ::Gore_witch_killed(params); }
        catch(e) { if (::GoreDebug) printl("[GoreSystem] ERROR in Gore_witch_killed: " + e); }
    }
}
__CollectGameEventCallbacks(::GoreSystem);
printl("[GoreSystem] Event handlers registered via table (compatible pattern)")