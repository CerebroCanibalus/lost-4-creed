// queue for death event - Used to delay the blood pool spawn
g_DeathQueue <- [];
g_SpawnedPositions <- {}; // Keep track of where we�ve already spawned pools to avoid duplicates

// Blood Pool
const POOL_SPAWN_CHANCE = 10; // 10% chance to spawn a pool (reducido — antes 25% y se generaban demasiadas)
const TRACE_MASK = 0x2004003; // MASK_SOLID for ground trace
const MIN_GROUND_Z = -1000;   // Lowest Z we allow for ground (like basements)
const MAX_GROUND_Z = 3000;    // Highest Z we allow for ground (like top floors)
const MIN_NORMAL_Z = 0.97;    // How flat the ground needs to be (stricter to avoid staircases)
const MAX_VERTICAL_DISTANCE = 50; // Max distance from infected�s feet to ground (wider range)
const VERTICAL_SPEED_THRESHOLD = 100; // Speed to detect climbing or jumping
const MAX_ELEVATION = 500;    // Max height for ground (skip ledges above this)

// Stuff we don�t want to spawn pools on, like props, ladders, map brushes, or ragdolls
g_BuggedEnts <- {
    prop_physics = 0,
    prop_dynamic = 0,
    func_ladder = 0,
    prop_static = 0,
    func_brush = 0,
    prop_ragdoll = 0 // Added to skip dead bodies
}

BloodPool <-
{
    // precache the blood effects
    function Precache()
    {
        PrecacheEntityFromTable({ classname = "info_particle_system", effect_name = "blood_bleedout" });
        PrecacheEntityFromTable({ classname = "info_particle_system", effect_name = "blood_incapacitated" });
    }

    // infected gets killed
    // NOTA: En L4D2, player_death con victimname="Infected" captura TANTO Special Infected
    // como Common Infected. No hace falta escuchar infected_death aparte — este handler
    // ya cubre todos los infected (incluyendo Commons, confirmado en game testing).
    function OnGameEvent_player_death(params)
    {
        if (params.victimname != "Infected") return; // Only care about infected
        if (RandomInt(1, 100) > POOL_SPAWN_CHANCE) return; // Skip half the time
        
        // NOTE: velocity check removed - userid no es entindex, y para infected
        // comunes no hay forma segura de obtener la entidad desde player_death.
        // Este check no es crítico, solo evitaba pools en terreno empinado.
        
        local targetPos = Vector(params.victim_x, params.victim_y, params.victim_z);
        // Delay the ground check a bit so the body settles
        MaoLib.DelayCall(function() { BloodPool.FindGround(targetPos); }, 0.2);
    }

    // Ground level for pool spawn, checks for flat ground and avoids props/ladders
    function FindGround(pos)
    {
        
        // Trace down to find the ground
        local trace = {
            start = pos + Vector(0,0,5),  // Start a bit above the position
            end = pos - Vector(0,0,200),  // Look down farther to reach the real ground
            ignore = null,
            mask = TRACE_MASK // solid stuff
        };
        
        if (TraceLine(trace) && "pos" in trace)
        {
            // Make sure the ground isn�t too far below the infected
            local verticalDistance = pos.z - trace.pos.z;
            if (verticalDistance > MAX_VERTICAL_DISTANCE)
            {
                return; // Ground is too far down, skip
            }
            
            // Check if the surface is flat enough (if we have a normal)
            local isValidNormal = true;
            if ("normal" in trace)
            {
                isValidNormal = trace.normal.z >= MIN_NORMAL_Z;
            }
            
            // Make sure the ground height is within our allowed range and not too high
            if (isValidNormal && trace.pos.z >= MIN_GROUND_Z && trace.pos.z <= MAX_GROUND_Z && trace.pos.z <= MAX_ELEVATION)
            {
                // Check if we�re on a prop, ladder, map brush, or ragdoll
                local propCheck = {
                    start = trace.pos + Vector(0,0,5),
                    end = trace.pos - Vector(0,0,10),
                    ignore = null,
                    mask = TRACE_MASK
                };
                if (TraceLine(propCheck) && "enthit" in propCheck && propCheck.enthit.GetClassname() in g_BuggedEnts)
                {
                    return; // On a prop, ladder, brush, or ragdoll, skip
                }
                
                // Don�t spawn in the same spot twice
                local posKey = format("%f,%f,%f", trace.pos.x, trace.pos.y, trace.pos.z);
                if (!(posKey in g_SpawnedPositions))
                {
                    g_SpawnedPositions[posKey] <- true;
                    g_DeathQueue.append({ pos = trace.pos + Vector(0,0,-0.2), time = Time() });
                }
            }
        }
    },

    // main loop, spawn the blood
    function Think()
    {
        local now = Time();
        local newQueue = [];
        
        foreach(death in g_DeathQueue)
        {
            if (now >= death.time + 3.0) // Wait 3 seconds before spawning
            {
                local spawnPos = death.pos;
                local effect = (RandomInt(1,100) <= 50) ? "blood_bleedout" : "blood_incapacitated"; // 50/50 chance
                
                local particle = SpawnEntityFromTable("info_particle_system", {
                    effect_name = effect,
                    start_active = 1,
                    origin = format("%f %f %f", spawnPos.x, spawnPos.y, spawnPos.z)
                });
                if (particle) {
                    DoEntFire("!self", "Kill", "", 60.0, null, particle); // Clean up after 60s
                }
            }
            else
            {
                newQueue.append(death);
            }
        }
        
        g_DeathQueue = newQueue;
    }
}

// Cool Beans
BloodPool.Precache();
MaoLib.AddTimer("bloodpool_think", 0.5, @() BloodPool.Think());

function BloodPool::OnGameEvent_round_end(params)
{
    MaoLib.RemoveTimer("bloodpool_think")
}

__CollectGameEventCallbacks(BloodPool);