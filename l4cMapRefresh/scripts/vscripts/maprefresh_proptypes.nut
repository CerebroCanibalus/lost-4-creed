// ============================================================
// MapRefresh - maprefresh_proptypes.nut (CORREGIDO)
// Sistema de Tipos de Props - Modelos EXACTOS del repo original
// Fuente: avar.nut → tADMIT table
// ============================================================

::MapRefresh.PropTypes <- {
    
    Types = {
        // --- PROPS FÍSICOS (prop_physics) ---
        ice = {
            model = "models/props_urban/plastic_icechest_lid001.mdl",
            entity = "prop_physics",
            desc = "Tapa de hielera"
        },
        cart = {
            model = "models/props_urban/shopping_cart001.mdl",
            entity = "prop_physics",
            desc = "Carrito de compras"
        },
        can = {
            model = "models/props_street/garbage_can.mdl",
            entity = "prop_physics",
            desc = "Bote de basura metálico"
        },
        pot = {
            model = "models/props_foliage/urban_pot_large01.mdl",
            entity = "prop_physics",
            desc = "Maceta grande"
        },
        pot_clay = {
            model = "models/props_foliage/urban_pot_clay01.mdl",
            entity = "prop_physics",
            desc = "Maceta de barro"
        },
        bin = {
            model = "models/props_street/trashbin01.mdl",
            entity = "prop_physics",
            desc = "Bote de basura"
        },
        bin_a = {
            model = "models/props_junk/trashbin01a.mdl",
            entity = "prop_physics",
            desc = "Bote de basura con tapa"
        },
        barstool = {
            model = "models/props_furniture/cafe_barstool1.mdl",
            entity = "prop_physics",
            desc = "Silla de bar"
        },
        peanut = {
            model = "models/props_fairgrounds/Lil'Peanut_cutout001.mdl",
            entity = "prop_physics",
            desc = "Cartel de Lil Peanut"
        },
        pallet = {
            model = "models/props_junk/wood_pallet001a.mdl",
            entity = "prop_physics",
            desc = "Paleta de madera"
        },
        oxy = {
            model = "models/props_equipment/oxygentank01.mdl",
            entity = "prop_physics",
            desc = "Tanque de oxígeno",
            explosive = true
        },
        basin = {
            model = "models/props_urban/plastic_basin001.mdl",
            entity = "prop_physics",
            desc = "Bacinilla plástica"
        },
        oil = {
            model = "models/props_c17/oildrum001.mdl",
            entity = "prop_physics",
            desc = "Barril de petróleo"
        },
        pchair = {
            model = "models/props_urban/plastic_chair001.mdl",
            entity = "prop_physics",
            desc = "Silla plástica"
        },
        pbottle = {
            model = "models/props_junk/garbage_plasticbottle001a_fullsheet.mdl",
            entity = "prop_physics",
            desc = "Botella plástica"
        },
        pjug = {
            model = "models/props_urban/plastic_water_jug001.mdl",
            entity = "prop_physics",
            desc = "Garrafón de agua"
        },
        haybale = {
            model = "models/props_normandy/haybale.mdl",
            entity = "prop_physics",
            desc = "Paca de heno"
        },
        haybails = {
            model = "models/props/de_inferno/hay_bails.mdl",
            entity = "prop_physics",
            desc = "Paca de heno individual"
        },
        gascan = {
            model = "models/props_junk/gascan001a.mdl",
            entity = "prop_physics",
            desc = "Lata de gasolina"
        },
        
        // --- NUEVOS PROPS FÍSICOS (TACM reference) ---
        cone = {
            model = "models/props_fortifications/orange_cone001_reference.mdl",
            entity = "prop_physics",
            desc = "Cono naranja de construcción"
        },
        barrel_road = {
            model = "models/props_urban/highway_barrel001.mdl",
            entity = "prop_physics_override",
            desc = "Barril de carretera"
        },
        gurney = {
            model = "models/props_unique/hospital/gurney.mdl",
            entity = "prop_physics",
            desc = "Camilla hospital"
        },
        wheelchair = {
            model = "models/props_unique/wheelchair01.mdl",
            entity = "prop_physics",
            desc = "Silla de ruedas"
        },
        sleepingbag = {
            model = "models/props_equipment/sleeping_bag3.mdl",
            entity = "prop_physics",
            desc = "Bolsa de dormir"
        },
        mailbox = {
            model = "models/props_street/mail_dropbox.mdl",
            entity = "prop_physics_override",
            desc = "Buzón de correos"
        },
        bucket = {
            model = "models/props_urban/plastic_bucket001.mdl",
            entity = "prop_physics",
            desc = "Cubo de plástico"
        },
        concrete_post = {
            model = "models/props_fortifications/concrete_post001_48.mdl",
            entity = "prop_dynamic",
            desc = "Poste de concreto",
            solid = 0
        },
        
        // --- NUEVOS PROPS DINÁMICOS (TACM reference) ---
        newspaper = {
            model = "models/props/cs_militia/newspaperstack01.mdl",
            entity = "prop_dynamic",
            desc = "Pila de periódicos",
            solid = 0
        },
        deadbody = {
            model = "models/deadbodies/dead_male_civilian_body.mdl",
            entity = "prop_dynamic",
            desc = "Cadáver civil",
            solid = 0
        },
        crow = {
            model = "models/props_critters/crow_group.mdl",
            entity = "prop_dynamic",
            desc = "Grupo de cuervos",
            solid = 0
        },
        puddle = {
            model = "models/effects/urban_puddle_model01a.mdl",
            entity = "prop_dynamic",
            desc = "Charco urbano",
            solid = 0
        },
        luggage = {
            model = "models/props_unique/airport/luggage_pile1.mdl",
            entity = "prop_dynamic",
            desc = "Pila de maletas",
            solid = 0
        },
        watercooler = {
            model = "models/props_equipment/water_cooler.mdl",
            entity = "prop_dynamic",
            desc = "Enfriador de agua",
            solid = 0
        },
        barrier = {
            model = "models/props_fortifications/concrete_barrier01.mdl",
            entity = "prop_dynamic",
            desc = "Barrera de concreto",
            solid = 0
        },
        
        // --- NUEVOS PROPS TACM EXTRAS ---
        bush256 = {
            model = "models/props_foliage/urban_bush_angled_256.mdl",
            entity = "prop_dynamic",
            desc = "Arbusto angular grande",
            solid = 0
        },
        garb256_002b = {
            model = "models/props_junk/garbage256_composite002b.mdl",
            entity = "prop_dynamic",
            desc = "Escombros 256 variante",
            solid = 0
        },
        tire = {
            model = "models/props_urban/tire001.mdl",
            entity = "prop_physics",
            desc = "Llanta"
        },
        dumpster = {
            model = "models/props_junk/dumpster_2.mdl",
            entity = "prop_physics",
            desc = "Contenedor basura"
        },
        traffic_barrel = {
            model = "models/props_urban/traffic_barrel.mdl",
            entity = "prop_physics_override",
            desc = "Barril de tráfico"
        },
        van = {
            model = "models/props_vehicles/van001a.mdl",
            entity = "prop_dynamic",
            desc = "Camioneta",
            solid = 0
        },
        satellite = {
            model = "models/props_interiors/satellitedish_large01.mdl",
            entity = "prop_dynamic",
            desc = "Antena satelital",
            solid = 0
        },
        control_chair = {
            model = "models/props_office/controlroom_chair001a.mdl",
            entity = "prop_physics",
            desc = "Silla de oficina"
        },
        folding_table = {
            model = "models/props_interiors/table_folding_folded.mdl",
            entity = "prop_physics",
            desc = "Mesa plegable"
        },
        metalbucket = {
            model = "models/props_interiors/metalbucket02a.mdl",
            entity = "prop_physics",
            desc = "Cubeta de metal"
        },
        
        // --- PROPS DINÁMICOS (original) ---
        garbagePile01 = {
            model = "models/props_fairgrounds/garbage_pile01.mdl",
            entity = "prop_dynamic",
            desc = "Pila de basura 01",
            solid = 0
        },
        garbagePile02 = {
            model = "models/props_fairgrounds/garbage_pile02.mdl",
            entity = "prop_dynamic",
            desc = "Pila de basura 02",
            solid = 0
        },
        food03 = {
            model = "models/props_junk/food_pile03.mdl",
            entity = "prop_dynamic",
            desc = "Pila de comida",
            solid = 0
        },
        bushAngled128 = {
            model = "models/props_foliage/urban_bush_angled_128.mdl",
            entity = "prop_dynamic",
            desc = "Arbusto angular",
            solid = 0
        },
        garb256_001b = {
            model = "models/props_junk/garbage256_composite001b.mdl",
            entity = "prop_dynamic",
            desc = "Escombros 256",
            solid = 0
        },
        
        // --- PARTÍCULAS (info_particle_system) ---
        largeSmoke = {
            effect = "smoke_large_02",
            entity = "info_particle_system",
            desc = "Humo denso",
            start_active = true
        },
        riverSmoke = {
            effect = "fire_riverboat_smoke",
            entity = "info_particle_system",
            desc = "Humo de río",
            start_active = true
        },
        leaves = {
            effect = "leaves_green",
            entity = "info_particle_system",
            desc = "Hojas verdes cayendo",
            start_active = true
        },
        lowSmoke = {
            effect = "fire_chopper_lowsmoke",
            entity = "info_particle_system",
            desc = "Humo bajo",
            start_active = true
        },
        roach = {
            effect = "roaches_lot",
            entity = "info_particle_system",
            desc = "Enjambre de cucarachas",
            start_active = true
        },
        chainsawSmoke = {
            effect = "weapon_chainsaw_smoke_tp",
            entity = "info_particle_system",
            desc = "Humo de motosierra",
            start_active = true
        },
        exhaust01 = {
            effect = "smoke_exhaust_01",
            entity = "info_particle_system",
            desc = "Humo de escape",
            start_active = true
        },
        skySmoke01 = {
            effect = "skybox_smoke_01",
            entity = "info_particle_system",
            desc = "Humo de cielo",
            start_active = true
        },
        fogVol_1024_512 = {
            effect = "fog_volume_1024_512",
            entity = "info_particle_system",
            desc = "Volumen de niebla",
            start_active = true
        },
        steamDoorway = {
            effect = "steam_doorway",
            entity = "info_particle_system",
            desc = "Vapor de puerta",
            start_active = true
        },
        
        // --- DECALS ---
        bloodstain003 = {
            texture = "decals/bloodstain_003",
            entity = "infodecal",
            desc = "Mancha de sangre"
        },
        trash04 = {
            texture = "decals/trashdecal04a",
            entity = "infodecal",
            desc = "Decal de basura"
        },
        leavesDecal = {
            texture = "decals/leaves02",
            entity = "infodecal",
            desc = "Hojas en el suelo"
        },
        leavesGroundDecal = {
            texture = "decals/leaves_ground02",
            entity = "infodecal",
            desc = "Hojas en tierra"
        },
        cementStain = {
            texture = "de_train/train_cement_stain_01",
            entity = "infodecal",
            desc = "Mancha de cemento"
        },
        
        // --- SCAVENGE ---
        scavengegascanspawner = {
            entity = "weapon_scavenge_item_spawn",
            desc = "Spawner de latas de gas"
        }
    }
    
    function GetTypeInfo(category) {
        if (category in Types) return Types[category];
        printl("[MapRefresh:PropTypes] WARNING: Unknown category '" + category + "'");
        return null;
    }
    
    function HasCategory(category) {
        return (category in Types);
    }
    
    function GetModel(category) {
        if (category in Types && "model" in Types[category]) {
            return Types[category].model;
        }
        return null;
    }
    
    function GetEntityType(category) {
        if (category in Types && "entity" in Types[category]) {
            return Types[category].entity;
        }
        return "prop_physics";
    }
}

printl("[MapRefresh] PropTypes loaded. " + ::MapRefresh.PropTypes.Types.len() + " categories.");
