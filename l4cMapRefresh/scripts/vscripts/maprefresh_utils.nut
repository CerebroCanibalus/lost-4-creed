// ============================================================
// MapRefresh - maprefresh_utils.nut (v2)
// Shared utilities with PropTypes integration
// ============================================================

::MapRefresh.Utils <- {
    // ============================================================
    // SPAWNER PRINCIPAL (usa PropTypes)
    // ============================================================
    
    // Spawn a prop using the category system
    function SpawnFromCategory(name, origin, angles, category, spawnflags = null)
    {
        local typeInfo = ::MapRefresh.PropTypes.GetTypeInfo(category);
        if (!typeInfo)
        {
            printl("[MapRefresh:Utils] ERROR: Unknown category '" + category + "' for " + name);
            return null;
        }
        
        local entityType = typeInfo.entity;
        
        // Spawn según tipo de entidad
        switch (entityType)
        {
            case "prop_physics":
                return SpawnPropPhysics(name, origin, angles, 
                    typeInfo.model, 
                    spawnflags != null ? spawnflags : 256);
                
            case "prop_physics_override":
                return SpawnPropPhysicsOverride(name, origin, angles,
                    typeInfo.model,
                    spawnflags != null ? spawnflags : 256);
                
            case "prop_dynamic":
                return SpawnPropDynamic(name, origin, angles,
                    typeInfo.model,
                    spawnflags != null ? spawnflags : 256);
                
            case "info_particle_system":
                return SpawnParticleSystem(name, origin, angles,
                    typeInfo.effect,
                    typeInfo.start_active);
                
            case "infodecal":
                return SpawnDecal(origin, angles, typeInfo.texture);
                
            case "weapon_scavenge_item_spawn":
                return SpawnScavengeCan(name, origin, angles);
                
            default:
                printl("[MapRefresh:Utils] ERROR: Unknown entity type '" + entityType + "'");
                return null;
        }
    }
    
    // ============================================================
    // ENTITY SPAWNING (LOW LEVEL)
    // ============================================================
    
    function SpawnPropPhysics(name, origin, angles, model, spawnflags = 256)
    {
        local ent = SpawnEntityFromTable("prop_physics", {
            targetname = name,
            origin = origin,
            angles = angles,
            model = model,
            spawnflags = spawnflags,
            disableshadows = 1
        });
        
        if (ent && ent.IsValid())
        {
            // printl("[MapRefresh] Spawned prop_physics: " + name + " (" + model + ")");
            return ent;
        }
        return null;
    }
    
    function SpawnPropPhysicsOverride(name, origin, angles, model, spawnflags = 256)
    {
        local ent = SpawnEntityFromTable("prop_physics_override", {
            targetname = name,
            origin = origin,
            angles = angles,
            model = model,
            spawnflags = spawnflags,
            disableshadows = 1
        });
        
        if (ent && ent.IsValid())
        {
            // printl("[MapRefresh] Spawned prop_physics_override: " + name);
            return ent;
        }
        return null;
    }
    
    function SpawnPropDynamic(name, origin, angles, model, spawnflags = 256)
    {
        local ent = SpawnEntityFromTable("prop_dynamic", {
            targetname = name,
            origin = origin,
            angles = angles,
            model = model,
            spawnflags = spawnflags,
            disableshadows = 1,
            solid = 0
        });
        
        if (ent && ent.IsValid())
        {
            // printl("[MapRefresh] Spawned prop_dynamic: " + name);
            return ent;
        }
        return null;
    }
    
    function SpawnParticleSystem(name, origin, angles, effectName, startActive = true)
    {
        local ent = SpawnEntityFromTable("info_particle_system", {
            targetname = name,
            origin = origin,
            angles = angles,
            effect_name = effectName,
            start_active = startActive ? 1 : 0
        });
        
        if (ent && ent.IsValid())
        {
            // printl("[MapRefresh] Spawned particle: " + name + " (" + effectName + ")");
            return ent;
        }
        return null;
    }
    
    function SpawnAmbientSound(name, origin, soundFile, volume = 1.0, radius = 125000)
    {
        local ent = SpawnEntityFromTable("ambient_generic", {
            targetname = name,
            origin = origin,
            message = soundFile,
            volstart = volume,
            spawnflags = 0,
            radius = radius,
            pitchstart = 100,
            health = 10
        });
        
        if (ent && ent.IsValid())
        {
            // printl("[MapRefresh] Spawned ambient sound: " + name);
            return ent;
        }
        return null;
    }
    
    function SpawnDecal(origin, angles, texture)
    {
        local ent = SpawnEntityFromTable("infodecal", {
            origin = origin,
            angles = angles,
            texture = texture
        });
        
        if (ent && ent.IsValid())
        {
            DoEntFire("!self", "activate", "", 0.0, ent, ent);
            return ent;
        }
        return null;
    }
    
    function SpawnLight(name, origin, color, brightness, distance)
    {
        local ent = SpawnEntityFromTable("light_dynamic", {
            targetname = name,
            origin = origin,
            _light = color,
            brightness = brightness,
            distance = distance,
            spawnflags = 0,
            style = 0
        });
        
        if (ent && ent.IsValid())
        {
            // printl("[MapRefresh] Spawned light: " + name);
            return ent;
        }
        return null;
    }
    
    function SpawnScavengeCan(name, origin, angles)
    {
        local spawnerTable = {
            origin = origin,
            angles = angles,
            targetname = name
        };
        local can_spawner = SpawnEntityFromTable("weapon_scavenge_item_spawn", spawnerTable);
        if (can_spawner)
        {
            DoEntFire("!self", "SpawnItem", "", 0, null, can_spawner);
            // printl("[MapRefresh] Spawned scavenge can spawner: " + name);
            return can_spawner;
        }
        return null;
    }
    
    // ============================================================
    // BATCH SPAWNING FROM DATA TABLES
    // ============================================================
    
    // Spawn a single prop from data array (format: [x, y, z, pitch, yaw, roll, spawnflags, category])
    function SpawnProp(data, name = "maprefresh_prop")
    {
        if (data.len() < 8)
        {
            printl("[MapRefresh:Utils] WARNING: Invalid prop data (need 8 elements)");
            return null;
        }
        
        local origin = Vector(data[0], data[1], data[2]);
        local angles = Vector(data[3], data[4], data[5]);
        local spawnflags = data[6];
        local category = data[7];
        
        return SpawnFromCategory(name, origin, angles, category, spawnflags);
    }
    
    // Spawn props from a data table (format: [x, y, z, pitch, yaw, roll, spawnflags, category])
    function SpawnFromDataTable(dataTable)
    {
        local spawned = 0;
        foreach (name, data in dataTable)
        {
            if (data.len() < 8)
            {
                printl("[MapRefresh:Utils] WARNING: Invalid data for " + name);
                continue;
            }
            
            local origin = Vector(data[0], data[1], data[2]);
            local angles = Vector(data[3], data[4], data[5]);
            local spawnflags = data[6];
            local category = data[7];
            
            local ent = SpawnFromCategory(name, origin, angles, category, spawnflags);
            if (ent) spawned++;
        }
        
        printl("[MapRefresh:Utils] Spawned " + spawned + " entities from data table.");
        return spawned;
    }
    
    // ============================================================
    // WEATHER / AMBIENCE
    // ============================================================
    
    function CreateRainArea(namePrefix, centerOrigin, areaSize)
    {
        printl("[MapRefresh] Creating rain area: " + namePrefix);
        
        local spawned = 0;
        local step = 512;
        
        for (local x = -areaSize; x <= areaSize; x += step)
        {
            for (local y = -areaSize; y <= areaSize; y += step)
            {
                local pos = Vector(
                    centerOrigin.x + x,
                    centerOrigin.y + y,
                    centerOrigin.z + 300
                );
                
                local rainEnt = SpawnParticleSystem(
                    namePrefix + "_rain_" + spawned,
                    pos,
                    Vector(0, 0, 0),
                    "rain_street",
                    true
                );
                
                if (rainEnt) spawned++;
            }
        }
        
        printl("[MapRefresh] Spawned " + spawned + " rain emitters.");
        return spawned;
    }
    
    function CreateMistArea(namePrefix, centerOrigin, count = 3)
    {
        printl("[MapRefresh] Creating mist area: " + namePrefix);
        
        local spawned = 0;
        for (local i = 0; i < count; i++)
        {
            local offsetX = RandomInt(-200, 200);
            local offsetY = RandomInt(-200, 200);
            local pos = Vector(
                centerOrigin.x + offsetX,
                centerOrigin.y + offsetY,
                centerOrigin.z
            );
            
            local mistEnt = SpawnParticleSystem(
                namePrefix + "_mist_" + i,
                pos,
                Vector(0, 0, 0),
                "smoke_medium",
                true
            );
            
            if (mistEnt) spawned++;
        }
        
        return spawned;
    }
    
    // ============================================================
    // RANDOMIZATION UTILITIES
    // ============================================================
    
    function Chance(percent)
    {
        return RandomFloat(0, 100) < percent;
    }
    
    function RandomPick(array)
    {
        if (array.len() == 0) return null;
        return array[RandomInt(0, array.len() - 1)];
    }
    
    function RandomPos(center, minOffset, maxOffset)
    {
        local angle = RandomFloat(0, 360);
        local dist = RandomFloat(minOffset, maxOffset);
        return Vector(
            center.x + cos(angle * PI / 180) * dist,
            center.y + sin(angle * PI / 180) * dist,
            center.z
        );
    }
    
    // ============================================================
    // DEBUG
    // ============================================================
    
    function DebugPrint(msg)
    {
        if (::MapRefresh.DEBUG)
        {
            printl("[MapRefresh:DEBUG] " + msg);
        }
    }
}

printl("[MapRefresh] Utils loaded.");
