// MaoLib.NavUtils - Global pathfinding utilities for ALL Special Infected
// Extracted and enhanced from PassiveTank navigation system
// Provides: high ground finding, choke points, flanking routes, hittable detection

// Safety check: MaoLib must be loaded first
if ( !( "MaoLib" in getroottable() ) )
{
	printl( "[MaoLib.NavUtils] ERROR: MaoLib not loaded! Cannot initialize NavUtils." )
	return
}

if ( "NavUtils" in MaoLib )
{
	printl( "[MaoLib.NavUtils] Already loaded, skipping." )
	return
}

MaoLib.NavUtils <-
{
	// ------------------------------------------------------------------
	// CORE NAVIGATION
	// ------------------------------------------------------------------
	
	// Find nearest nav area to a position
	// @param pos: Vector position to search from
	// @param maxDist: Maximum search distance (default 500)
	// @param checkBlocked: Whether to check for blocked areas (default false)
	// @return: CNavArea entity or null
	function GetNearestNavArea( pos, maxDist = 500, checkBlocked = false )
	{
		return NavMesh.GetNearestNavArea( pos, maxDist, checkBlocked, true )
	}
	
	// Build a path between two nav areas using A*
	// @param startNav: Starting CNavArea
	// @param endNav: Target CNavArea
	// @param team: Team number for pathfinding (default 3 = infected)
	// @return: Array of CNavAreas from end to start, or null if no path
	function BuildPath( startNav, endNav, team = 3 )
	{
		if ( !startNav || !startNav.IsValid() || !endNav || !endNav.IsValid() )
		{
			if ( MaoLib.IsDeveloperMode() )
				printl( "[MaoLib.NavUtils.BuildPath] WARNING: Invalid nav areas provided" )
			return null
		}
		
		if ( !NavMesh.NavAreaBuildPath( startNav, endNav, endNav.GetCenter(), 0, team, false ) )
		{
			if ( MaoLib.IsDeveloperMode() )
				printl( "[MaoLib.NavUtils.BuildPath] No path found between areas" )
			return null
		}
		
		// Reconstruct path by following parent pointers
		local path = []
		local current = endNav
		while ( current )
		{
			path.append( current )
			current = current.GetParent()
		}
		
		if ( MaoLib.IsDeveloperMode() )
			printl( "[MaoLib.NavUtils.BuildPath] Path found with " + path.len() + " nodes" )
		
		return path
	}
	
	// Calculate total distance of a path (sum of distances between nodes)
	function GetPathDistance( path )
	{
		if ( !path || path.len() < 2 )
			return 0.0
		
		local total = 0.0
		for ( local i = 1; i < path.len(); i++ )
		{
			total += ( path[i].GetCenter() - path[i-1].GetCenter() ).Length()
		}
		return total
	}
	
	// Calculate flow distance difference between start and end of path
	// Flow distance represents progress through the map (0 = start, 100 = end)
	function GetPathFlowDistance( path )
	{
		if ( !path || path.len() == 0 )
			return 0.0
		
		return fabs( GetFlowDistanceForPosition( path[0].GetCenter() ) - GetFlowDistanceForPosition( path[path.len()-1].GetCenter() ) )
	}
	
	// ------------------------------------------------------------------
	// AREA ANALYSIS
	// ------------------------------------------------------------------
	
	// Check if a nav area is valid for navigation
	// @param needWater: If true, area must be underwater
	// @return: true if area is valid and usable
	// 
	// IMPORTANT: There are TWO types of nav attributes in L4D2:
	// 1. Spawn Attributes (HasSpawnAttributes) - TERROR_NAV_* constants
	//    Used for: spawn rules, checkpoints, escape routes, etc.
	// 2. Mesh Attributes (HasAttributes) - NAV_MESH_* constants  
	//    Used for: movement rules (crouch, jump, avoid, etc.)
	//
	function IsAreaValid( nav, needWater = false )
	{
		if ( !nav || !nav.IsValid() )
			return false
		
		if ( needWater && !nav.IsUnderwater() )
			return false
		
		if ( nav.IsDamaging() || nav.HasAvoidanceObstacle( 80 ) )
			return false
		
		if ( nav.IsBlocked( 2, false ) || nav.IsBlocked( 3, false ) )
			return false
		
		// SPAWN ATTRIBUTES (TERROR_NAV_*): Avoid checkpoints, rescue closets, escape routes, doors
		if ( nav.HasSpawnAttributes( MaoLib.TERROR_NAV_CHECKPOINT + MaoLib.TERROR_NAV_RESCUE_CLOSET + MaoLib.TERROR_NAV_ESCAPE_ROUTE + MaoLib.TERROR_NAV_DOOR ) )
			return false
		
		// MESH ATTRIBUTES (NAV_MESH_*): Avoid areas marked as dangerous/unreachable
		if ( nav.HasAttributes( MaoLib.NAV_MESH_AVOID ) )
			return false
		
		return true
	}
	
	// Check if a nav area is large/open (good for combat, bad for ambushes)
	function IsOpenArea( nav )
	{
		if ( !nav || !nav.IsValid() )
			return false
		
		// Large area = open (size > 200 units in both dimensions)
		return nav.GetSizeX() > 200 && nav.GetSizeY() > 200
	}
	
	// Check if a nav area is a choke point (narrow, good for ambushes)
	function IsChokePoint( nav )
	{
		if ( !nav || !nav.IsValid() )
			return false
		
		// Narrow area = choke point (size < 100 units in any dimension)
		return ( nav.GetSizeX() < 100 || nav.GetSizeY() < 100 )
	}
	
	// Calculate height difference between nav area and reference position
	function GetAreaHeightDiff( nav, referencePos )
	{
		if ( !nav || !nav.IsValid() )
			return 0.0
		
		return fabs( nav.GetCenter().z - referencePos.z )
	}
	
	// ------------------------------------------------------------------
	// HIGH GROUND (for Tank rocks, Hunter pounces, Spitter shots)
	// ------------------------------------------------------------------
	// Note: Uses NavMesh.GetNavAreasInRadius() - undocumented Valve function
	// that works in L4D2 but not officially documented
	
	function FindHighGround( center, radius, minHeightDiff = 50 )
	{
		local areas = {}
		NavMesh.GetNavAreasInRadius( center, radius, areas )
		
		local highGround = []
		foreach ( nav in areas )
		{
			if ( !IsAreaValid( nav ) )
				continue
			
			local heightDiff = GetAreaHeightDiff( nav, center )
			if ( heightDiff >= minHeightDiff )
			{
				local navCenter = nav.GetCenter()
				highGround.append( { nav = nav, pos = Vector(navCenter.x, navCenter.y, navCenter.z), height = heightDiff } )
			}
		}
		
		// Sort by height (highest first)
		highGround.sort( function( a, b ) { return b.height - a.height } )
		
		if ( MaoLib.IsDeveloperMode() && highGround.len() > 0 )
			printl( "[MaoLib.NavUtils.FindHighGround] Found " + highGround.len() + " high ground spots" )
		
		return highGround
	}
	
	// ------------------------------------------------------------------
	// CHOKE POINTS (for Tank pressure, Smoker drags)
	// ------------------------------------------------------------------
	// Note: Uses NavMesh.GetNavAreasInRadius() - undocumented Valve function
	
	function FindChokePoints( center, radius )
	{
		local areas = {}
		NavMesh.GetNavAreasInRadius( center, radius, areas )
		
		local chokes = []
		foreach ( nav in areas )
		{
			if ( !IsAreaValid( nav ) )
				continue
			
			if ( IsChokePoint( nav ) )
			{
				chokes.append( { nav = nav, pos = nav.GetCenter(), width = nav.GetSizeX(), length = nav.GetSizeY() } )
			}
		}
		
		// Sort by narrowness (narrowest first)
		chokes.sort( function( a, b ) { return (a.width + a.length) - (b.width + b.length) } )
		
		if ( MaoLib.IsDeveloperMode() && chokes.len() > 0 )
			printl( "[MaoLib.NavUtils.FindChokePoints] Found " + chokes.len() + " choke points" )
		
		return chokes
	}
	
	// ------------------------------------------------------------------
	// FLANKING ROUTES (for any SI)
	// ------------------------------------------------------------------
	// Note: Uses NavMesh.GetNavAreasInRadius() - undocumented Valve function
	
	function FindFlankingRoutes( target, radius, side = "auto" )
	{
		local targetPos = target.GetOrigin()
		local targetNav = GetNearestNavArea( targetPos, 500 )
		
		if ( !targetNav )
		{
			if ( MaoLib.IsDeveloperMode() )
				printl( "[MaoLib.NavUtils.FindFlankingRoutes] WARNING: Could not find nav area for target" )
			return []
		}
		
		local areas = {}
		NavMesh.GetNavAreasInRadius( targetPos, radius, areas )
		
		local flanks = []
		foreach ( nav in areas )
		{
			if ( !IsAreaValid( nav ) )
				continue
			
			local navPos = nav.GetCenter()
			local distToTarget = ( navPos - targetPos ).Length()
			
			// Must be far enough from target but within radius
			if ( distToTarget < 300 || distToTarget > radius )
				continue
			
			// Check if it's on the side (not in front/back)
			local targetForward = target.GetForwardVector()
			local toNav = ( navPos - targetPos )
			toNav.Norm()
			
			local dot = targetForward.Dot( toNav )
			
			// Side = dot product near 0 (perpendicular)
			if ( fabs( dot ) < 0.5 )
			{
				flanks.append( { nav = nav, pos = navPos, dist = distToTarget, side = dot < 0 ? "left" : "right" } )
			}
		}
		
		// Sort by closest
		flanks.sort( function( a, b ) { return a.dist - b.dist } )
		
		if ( MaoLib.IsDeveloperMode() && flanks.len() > 0 )
			printl( "[MaoLib.NavUtils.FindFlankingRoutes] Found " + flanks.len() + " flanking routes" )
		
		return flanks
	}
	
	// ------------------------------------------------------------------
	// HITTABLE PROPS (for Tank)
	// ------------------------------------------------------------------
	
	function FindHittableProps( center, radius )
	{
		local hittables = []
		local prop = null
		
		while ( prop = Entities.FindByClassnameWithin( prop, "prop_physics", center, radius ) )
		{
			if ( !prop || !prop.IsValid() )
				continue
			
			// Check if it's a hittable by model name
			local model = prop.GetModelName()
			if ( model && ( model.find( "car" ) != null || model.find( "dumpster" ) != null || 
				  model.find( "trash" ) != null || model.find( "barrel" ) != null ||
				  model.find( "hittable" ) != null || model.find( "container" ) != null ) )
			{
				local origin = prop.GetOrigin()
				hittables.append( { ent = prop, pos = Vector(origin.x, origin.y, origin.z), dist = ( prop.GetOrigin() - center ).Length() } )
			}
		}
		
		// Sort by closest
		hittables.sort( function( a, b ) { return a.dist - b.dist } )
		
		if ( MaoLib.IsDeveloperMode() && hittables.len() > 0 )
			printl( "[MaoLib.NavUtils.FindHittableProps] Found " + hittables.len() + " hittable props" )
		
		return hittables
	}
	
	// ------------------------------------------------------------------
	// ROCK SPOTS (for Tank throw)
	// ------------------------------------------------------------------
	
	function FindRockSpots( tank, survivors, radius = 1500 )
	{
		if ( !tank || !tank.IsValid() )
		{
			if ( MaoLib.IsDeveloperMode() )
				printl( "[MaoLib.NavUtils.FindRockSpots] WARNING: Invalid tank entity" )
			return []
		}
		
		local tankPos = tank.GetOrigin()
		local spots = []
		
		// Get high ground spots
		local highGround = FindHighGround( tankPos, radius, 30 )
		
		foreach ( spot in highGround )
		{
			local hasLineOfSight = false
			
			// Check if spot has line of sight to any survivor
			foreach ( survivor in survivors )
			{
				if ( !survivor || !survivor.IsValid() )
					continue
				
				if ( HasLineOfSight( spot.pos + Vector( 0, 0, 50 ), survivor.EyePosition(), tank ) )
				{
					hasLineOfSight = true
					break
				}
			}
			
			if ( hasLineOfSight )
			{
				spots.append( spot )
			}
		}
		
		if ( MaoLib.IsDeveloperMode() && spots.len() > 0 )
			printl( "[MaoLib.NavUtils.FindRockSpots] Found " + spots.len() + " rock spots" )
		
		return spots
	}
	
	// ------------------------------------------------------------------
	// LINE OF SIGHT
	// ------------------------------------------------------------------
	
	// Check if there's clear line of sight between two points
	// @param ignoreEnt: Entity to ignore in trace (usually the viewer)
	// @return: true if fraction >= 0.95 (mostly clear)
	function HasLineOfSight( start, end, ignoreEnt = null )
	{
		local trace = {}
		TraceLine( start, end, ignoreEnt, trace )
		return trace.fraction >= 0.95
	}
	
	// Check if viewer can see target (eye to eye)
	function CanSeeEntity( viewer, target )
	{
		if ( !viewer || !viewer.IsValid() || !target || !target.IsValid() )
			return false
		
		return HasLineOfSight( viewer.EyePosition(), target.EyePosition(), viewer )
	}
	
	// ------------------------------------------------------------------
	// DISTANCE & FLOW
	// ------------------------------------------------------------------
	
	// Get minimum flow distance from entity to any survivor
	// Flow distance represents map progress (0 = start, 100 = end)
	// Lower value = entity is closer to survivors in flow
	function GetFlowDistanceToSurvivors( entity, survivors )
	{
		if ( !entity || !entity.IsValid() )
			return 999999.0
		
		local minFlow = 999999.0
		local entityFlow = GetCurrentFlowPercentForPlayer( entity )
		
		foreach ( survivor in survivors )
		{
			if ( !survivor || !survivor.IsValid() )
				continue
			
			local survivorFlow = GetCurrentFlowPercentForPlayer( survivor )
			local diff = fabs( survivorFlow - entityFlow )
			if ( diff < minFlow )
				minFlow = diff
		}
		
		return minFlow
	}
	
	// Check if entity is ahead of all survivors in flow
	// Returns true if entity has progressed further than all survivors
	function IsAheadOfSurvivors( entity, survivors )
	{
		if ( !entity || !entity.IsValid() )
			return false
		
		local entityFlow = GetCurrentFlowPercentForPlayer( entity )
		
		foreach ( survivor in survivors )
		{
			if ( !survivor || !survivor.IsValid() )
				continue
			
			if ( GetCurrentFlowPercentForPlayer( survivor ) > entityFlow )
				return false
		}
		
		return true
	}
	
	// ------------------------------------------------------------------
	// SURVIVOR POSITION ANALYSIS
	// ------------------------------------------------------------------
	
	// Check if survivors are grouped together within maxDist of their center
	// @param maxDist: Maximum distance from group center (default 300)
	// @return: true if all survivors are within maxDist of center
	function AreSurvivorsGrouped( survivors, maxDist = 300 )
	{
		if ( survivors.len() < 2 )
			return false
		
		local sum_x = 0.0, sum_y = 0.0, sum_z = 0.0
		local count = 0
		foreach ( survivor in survivors )
		{
			if ( !survivor || !survivor.IsValid() )
				continue
			
			local origin = survivor.GetOrigin()
			if ( origin != null )
			{
				sum_x += origin.x
				sum_y += origin.y
				sum_z += origin.z
				count++
			}
		}
		
		if ( count == 0 )
			return false
		
		local inv_count = 1.0 / count
		local center = Vector( sum_x * inv_count, sum_y * inv_count, sum_z * inv_count )
		
		// Check if all survivors are within maxDist of center
		foreach ( survivor in survivors )
		{
			if ( !survivor || !survivor.IsValid() )
				continue
			
			if ( ( survivor.GetOrigin() - center ).Length() > maxDist )
				return false
		}
		
		if ( MaoLib.IsDeveloperMode() )
			printl( "[MaoLib.NavUtils.AreSurvivorsGrouped] Survivors are grouped (center at " + center + ")" )
		
		return true
	}
	
	// Find the most vulnerable survivor based on health, status, and items
	// Scoring: low health (+25-50), incapacitated (+30), molotov holder (+40), being attacked (+35)
	function FindMostVulnerableSurvivor( survivors )
	{
		local best = null
		local bestScore = -1.0
		
		foreach ( survivor in survivors )
		{
			if ( !survivor || !survivor.IsValid() )
				continue
			
			// Skip dead/dying
			if ( NetProps.GetPropInt( survivor, "m_lifeState" ) > 0 )
				continue
			
			local score = 0.0
			
			// Low health = more vulnerable
			local health = survivor.GetHealth()
			if ( health < 40 )
				score += 50
			else if ( health < 80 )
				score += 25
			
			// Incapacitated = very vulnerable
			if ( survivor.IsIncapacitated() )
				score += 30
			
			// Holding molotov = priority target
			local weapon = survivor.GetActiveWeapon()
			if ( weapon && weapon.GetClassname() == "weapon_molotov" )
				score += 40
			
			// Being pounced/smoked = vulnerable
			if ( NetProps.GetPropInt( survivor, "m_isHangingFromLedge" ) > 0 ||
				 NetProps.GetPropEntity( survivor, "m_reviveOwner" ) != null )
				score += 35
			
			if ( score > bestScore )
			{
				bestScore = score
				best = survivor
			}
		}
		
		if ( MaoLib.IsDeveloperMode() && best )
			printl( "[MaoLib.NavUtils.FindMostVulnerableSurvivor] Most vulnerable: " + best.GetName() + " (score: " + bestScore + ")" )
		
		return best
	}
	
	// ------------------------------------------------------------------
	// ENVIRONMENTAL HAZARDS
	// ------------------------------------------------------------------
	
	// Check if entity is near any fire (inferno entity)
	function IsNearFire( entity, radius = 200 )
	{
		if ( !entity || !entity.IsValid() )
			return false
		
		local origin = entity.GetOrigin()
		local inferno = null
		
		while ( inferno = Entities.FindByClassnameWithin( inferno, "inferno", origin, radius ) )
		{
			if ( inferno && inferno.IsValid() )
				return true
		}
		
		return false
	}
	
	// Count number of active infernos near entity
	function CountNearbyInfernos( entity, radius = 500 )
	{
		if ( !entity || !entity.IsValid() )
			return 0
		
		local count = 0
		local origin = entity.GetOrigin()
		local inferno = null
		
		while ( inferno = Entities.FindByClassnameWithin( inferno, "inferno", origin, radius ) )
		{
			if ( inferno && inferno.IsValid() )
				count++
		}
		
		return count
	}
}

printl( "[MaoLib.NavUtils] Loaded successfully." )
