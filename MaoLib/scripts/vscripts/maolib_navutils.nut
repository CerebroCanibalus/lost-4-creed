// ============================================================================
// MaoLib.NavUtils — Pathfinding & Navigation Utilities for L4D2
// ============================================================================
// Extracted from the Lost 4 Creed Tank AI system. Provides common
// navigation queries used by all special infected AI.
//
// DEPENDENCIES: ::MaoLib core (constants: NAV_MESH_*, TERROR_NAV_*)
//
// API:
//   MaoLib.NavUtils.GetNearestNavArea(pos, maxDist, checkBlocked)
//   MaoLib.NavUtils.BuildPath(startNav, endNav, team)
//   MaoLib.NavUtils.GetPathDistance(path)
//   MaoLib.NavUtils.GetPathFlowDistance(path)
//   MaoLib.NavUtils.IsAreaValid(nav, needWater)
//   MaoLib.NavUtils.IsOpenArea(nav)
//   MaoLib.NavUtils.IsChokePoint(nav)
//   MaoLib.NavUtils.GetAreaHeightDiff(nav, referencePos)
//   MaoLib.NavUtils.FindHighGround(center, radius, minHeightDiff)
//   MaoLib.NavUtils.FindChokePoints(center, radius)
//   MaoLib.NavUtils.FindFlankingRoutes(target, radius, side)
//   MaoLib.NavUtils.FindHittableProps(center, radius)
//   MaoLib.NavUtils.FindRockSpots(tank, survivors, radius)
//   MaoLib.NavUtils.HasLineOfSight(start, end, ignoreEnt)
//   MaoLib.NavUtils.CanSeeEntity(viewer, target)
//   MaoLib.NavUtils.GetFlowDistanceToSurvivors(entity, survivors)
//   MaoLib.NavUtils.IsAheadOfSurvivors(entity, survivors)
//   MaoLib.NavUtils.AreSurvivorsGrouped(survivors, maxDist)
//   MaoLib.NavUtils.FindMostVulnerableSurvivor(survivors)
//   MaoLib.NavUtils.IsNearFire(entity, radius)
//   MaoLib.NavUtils.CountNearbyInfernos(entity, radius)
//
// NATIVE FUNCTIONS USED (all confirmed in L4D2):
//   NavMesh.GetNearestNavArea(pos, maxDist, blocked, ground)
//   NavMesh.NavAreaBuildPath(from, to, goalPos, maxDist, team, useFarthest)
//   NavMesh.GetNavAreasInRadius(center, radius, outputTable)
//   TraceLine(start, end, ignore, outputTable)
// ============================================================================

// Safety: MaoLib must be loaded first
if ( !( "MaoLib" in getroottable() ) )
{
	printl( "[MaoLib.NavUtils] ERROR: MaoLib not loaded! Cannot initialize." )
	return
}

if ( "NavUtils" in MaoLib )
{
	printl( "[MaoLib.NavUtils] Already loaded, skipping." )
	return
}

MaoLib.NavUtils <-
{
	// ================================================================
	// CORE NAVIGATION
	// ================================================================
	
	// Find the nearest CNavArea to a position
	function GetNearestNavArea( pos, maxDist = 500, checkBlocked = false )
	{
		return NavMesh.GetNearestNavArea( pos, maxDist, checkBlocked, true )
	}
	
	// Build an A* path between two nav areas.
	// Returns array of CNavAreas [end, ..., start], or null if no path.
	function BuildPath( startNav, endNav, team = 3 )
	{
		if ( !startNav || !startNav.IsValid() || !endNav || !endNav.IsValid() )
		{
			if ( MaoLib.IsDeveloperMode() )
				printl( "[MaoLib.NavUtils.BuildPath] WARNING: Invalid nav areas" )
			return null
		}
		
		if ( !NavMesh.NavAreaBuildPath( startNav, endNav, endNav.GetCenter(), 0, team, false ) )
		{
			if ( MaoLib.IsDeveloperMode() )
				printl( "[MaoLib.NavUtils.BuildPath] No path found" )
			return null
		}
		
		local path = []
		local current = endNav
		while ( current )
		{
			path.append( current )
			current = current.GetParent()
		}
		
		return path
	}
	
	// Get total distance of a path
	function GetPathDistance( path )
	{
		if ( !path || path.len() < 2 ) return 0.0
		
		local total = 0.0
		for ( local i = 1; i < path.len(); i++ )
			total += ( path[i].GetCenter() - path[i-1].GetCenter() ).Length()
		return total
	}
	
	// Get flow distance difference between start and end of path
	function GetPathFlowDistance( path )
	{
		if ( !path || path.len() == 0 ) return 0.0
		return fabs( GetFlowDistanceForPosition( path[0].GetCenter() ) - GetFlowDistanceForPosition( path[path.len()-1].GetCenter() ) )
	}
	
	// ================================================================
	// AREA ANALYSIS
	// ================================================================
	
	// Validate a nav area for navigation use.
	// Checks: damaging, blocked, checkpoint, rescue closet, etc.
	function IsAreaValid( nav, needWater = false )
	{
		if ( !nav || !nav.IsValid() ) return false
		if ( needWater && !nav.IsUnderwater() ) return false
		if ( nav.IsDamaging() || nav.HasAvoidanceObstacle( 80 ) ) return false
		if ( nav.IsBlocked( 2, false ) || nav.IsBlocked( 3, false ) ) return false
		
		// Avoid special areas
		if ( nav.HasSpawnAttributes( MaoLib.TERROR_NAV_CHECKPOINT + MaoLib.TERROR_NAV_RESCUE_CLOSET + MaoLib.TERROR_NAV_ESCAPE_ROUTE + MaoLib.TERROR_NAV_DOOR ) )
			return false
		
		if ( nav.HasAttributes( MaoLib.NAV_MESH_AVOID ) )
			return false
		
		return true
	}
	
	// Check if nav area is large/open (good for combat)
	function IsOpenArea( nav )
	{
		if ( !nav || !nav.IsValid() ) return false
		return nav.GetSizeX() > 200 && nav.GetSizeY() > 200
	}
	
	// Check if nav area is narrow (choke point, good for ambushes)
	function IsChokePoint( nav )
	{
		if ( !nav || !nav.IsValid() ) return false
		return ( nav.GetSizeX() < 100 || nav.GetSizeY() < 100 )
	}
	
	// Get height difference between nav area center and a reference position
	function GetAreaHeightDiff( nav, referencePos )
	{
		if ( !nav || !nav.IsValid() ) return 0.0
		return fabs( nav.GetCenter().z - referencePos.z )
	}
	
	// ================================================================
	// HIGH GROUND
	// ================================================================
	// Finds elevated nav areas — useful for Tank rock throws,
	// Hunter pounce positions, Spitter acid placement.
	
	function FindHighGround( center, radius, minHeightDiff = 50 )
	{
		local areas = {}
		NavMesh.GetNavAreasInRadius( center, radius, areas )
		
		local highGround = []
		foreach ( nav in areas )
		{
			if ( !IsAreaValid( nav ) ) continue
			
			local heightDiff = GetAreaHeightDiff( nav, center )
			if ( heightDiff >= minHeightDiff )
			{
				local navCenter = nav.GetCenter()
				highGround.append( { nav = nav, pos = Vector(navCenter.x, navCenter.y, navCenter.z), height = heightDiff } )
			}
		}
		
		highGround.sort( function( a, b ) { return b.height - a.height } )
		return highGround
	}
	
	// ================================================================
	// CHOKE POINTS
	// ================================================================
	// Finds narrow nav areas — useful for Tank pressure, Smoker drags.
	
	function FindChokePoints( center, radius )
	{
		local areas = {}
		NavMesh.GetNavAreasInRadius( center, radius, areas )
		
		local chokes = []
		foreach ( nav in areas )
		{
			if ( !IsAreaValid( nav ) ) continue
			if ( IsChokePoint( nav ) )
				chokes.append( { nav = nav, pos = nav.GetCenter(), width = nav.GetSizeX(), length = nav.GetSizeY() } )
		}
		
		chokes.sort( function( a, b ) { return (a.width + a.length) - (b.width + b.length) } )
		return chokes
	}
	
	// ================================================================
	// FLANKING ROUTES
	// ================================================================
	// Finds nav areas to the side of a target — useful for any SI
	// trying to approach from an unexpected angle.
	
	function FindFlankingRoutes( target, radius, side = "auto" )
	{
		local targetPos = target.GetOrigin()
		local targetNav = GetNearestNavArea( targetPos, 500 )
		
		if ( !targetNav ) return []
		
		local areas = {}
		NavMesh.GetNavAreasInRadius( targetPos, radius, areas )
		
		local flanks = []
		foreach ( nav in areas )
		{
			if ( !IsAreaValid( nav ) ) continue
			
			local navPos = nav.GetCenter()
			local distToTarget = ( navPos - targetPos ).Length()
			
			if ( distToTarget < 300 || distToTarget > radius ) continue
			
			local targetForward = target.GetForwardVector()
			local toNav = ( navPos - targetPos )
			toNav.Norm()
			
			local dot = targetForward.Dot( toNav )
			
			// Perpendicular = side
			if ( fabs( dot ) < 0.5 )
				flanks.append( { nav = nav, pos = navPos, dist = distToTarget, side = dot < 0 ? "left" : "right" } )
		}
		
		flanks.sort( function( a, b ) { return a.dist - b.dist } )
		return flanks
	}
	
	// ================================================================
	// HITTABLE PROPS (for Tank throws)
	// ================================================================
	
	function FindHittableProps( center, radius )
	{
		local hittables = []
		local prop = null
		
		while ( prop = Entities.FindByClassnameWithin( prop, "prop_physics", center, radius ) )
		{
			if ( !prop || !prop.IsValid() ) continue
			
			local model = prop.GetModelName()
			if ( model && ( model.find( "car" ) != null || model.find( "dumpster" ) != null || 
				  model.find( "trash" ) != null || model.find( "barrel" ) != null ||
				  model.find( "hittable" ) != null || model.find( "container" ) != null ) )
			{
				local origin = prop.GetOrigin()
				hittables.append( { ent = prop, pos = Vector(origin.x, origin.y, origin.z), dist = ( prop.GetOrigin() - center ).Length() } )
			}
		}
		
		hittables.sort( function( a, b ) { return a.dist - b.dist } )
		return hittables
	}
	
	// ================================================================
	// ROCK SPOTS (Tank throw positions)
	// ================================================================
	
	function FindRockSpots( tank, survivors, radius = 1500 )
	{
		if ( !tank || !tank.IsValid() ) return []
		
		local tankPos = tank.GetOrigin()
		local spots = []
		local highGround = FindHighGround( tankPos, radius, 30 )
		
		foreach ( spot in highGround )
		{
			local hasLineOfSight = false
			foreach ( survivor in survivors )
			{
				if ( !survivor || !survivor.IsValid() ) continue
				if ( HasLineOfSight( spot.pos + Vector( 0, 0, 50 ), survivor.EyePosition(), tank ) )
				{
					hasLineOfSight = true
					break
				}
			}
			if ( hasLineOfSight ) spots.append( spot )
		}
		
		return spots
	}
	
	// ================================================================
	// LINE OF SIGHT
	// ================================================================
	
	// Check LOS between two points. Fraction >= 0.95 = clear.
	function HasLineOfSight( start, end, ignoreEnt = null )
	{
		local trace = {}
		TraceLine( start, end, ignoreEnt, trace )
		return trace.fraction >= 0.95
	}
	
	// Check if viewer can see target (eye-to-eye LOS)
	function CanSeeEntity( viewer, target )
	{
		if ( !viewer || !viewer.IsValid() || !target || !target.IsValid() ) return false
		return HasLineOfSight( viewer.EyePosition(), target.EyePosition(), viewer )
	}
	
	// ================================================================
	// DISTANCE & FLOW
	// ================================================================
	
	// Get minimum flow distance from entity to any survivor
	function GetFlowDistanceToSurvivors( entity, survivors )
	{
		if ( !entity || !entity.IsValid() ) return 999999.0
		
		local minFlow = 999999.0
		local entityFlow = GetCurrentFlowPercentForPlayer( entity )
		
		foreach ( survivor in survivors )
		{
			if ( !survivor || !survivor.IsValid() ) continue
			local survivorFlow = GetCurrentFlowPercentForPlayer( survivor )
			local diff = fabs( survivorFlow - entityFlow )
			if ( diff < minFlow ) minFlow = diff
		}
		
		return minFlow
	}
	
	// Check if entity is ahead of all survivors in flow progression
	function IsAheadOfSurvivors( entity, survivors )
	{
		if ( !entity || !entity.IsValid() ) return false
		
		local entityFlow = GetCurrentFlowPercentForPlayer( entity )
		
		foreach ( survivor in survivors )
		{
			if ( !survivor || !survivor.IsValid() ) continue
			if ( GetCurrentFlowPercentForPlayer( survivor ) > entityFlow )
				return false
		}
		
		return true
	}
	
	// ================================================================
	// SURVIVOR GROUP ANALYSIS
	// ================================================================
	
	// Check if all survivors are clustered within maxDist of their center
	function AreSurvivorsGrouped( survivors, maxDist = 300 )
	{
		if ( survivors.len() < 2 ) return false
		
		local sum_x = 0.0, sum_y = 0.0, sum_z = 0.0
		local count = 0
		foreach ( survivor in survivors )
		{
			if ( !survivor || !survivor.IsValid() ) continue
			local origin = survivor.GetOrigin()
			if ( origin != null )
			{
				sum_x += origin.x; sum_y += origin.y; sum_z += origin.z
				count++
			}
		}
		
		if ( count == 0 ) return false
		
		local inv_count = 1.0 / count
		local center = Vector( sum_x * inv_count, sum_y * inv_count, sum_z * inv_count )
		
		foreach ( survivor in survivors )
		{
			if ( !survivor || !survivor.IsValid() ) continue
			if ( ( survivor.GetOrigin() - center ).Length() > maxDist )
				return false
		}
		
		return true
	}
	
	// Find most vulnerable survivor based on health, status, items
	function FindMostVulnerableSurvivor( survivors )
	{
		local best = null
		local bestScore = -1.0
		
		foreach ( survivor in survivors )
		{
			if ( !survivor || !survivor.IsValid() ) continue
			if ( NetProps.GetPropInt( survivor, "m_lifeState" ) > 0 ) continue
			
			local score = 0.0
			local health = survivor.GetHealth()
			if ( health < 40 ) score += 50
			else if ( health < 80 ) score += 25
			
			if ( survivor.IsIncapacitated() ) score += 30
			
			local weapon = survivor.GetActiveWeapon()
			if ( weapon && weapon.GetClassname() == "weapon_molotov" ) score += 40
			
			if ( NetProps.GetPropInt( survivor, "m_isHangingFromLedge" ) > 0 ||
				 NetProps.GetPropEntity( survivor, "m_reviveOwner" ) != null )
				score += 35
			
			if ( score > bestScore ) { bestScore = score; best = survivor }
		}
		
		return best
	}
	
	// ================================================================
	// ENVIRONMENTAL HAZARDS
	// ================================================================
	
	// Check if entity is near fire (inferno entity)
	function IsNearFire( entity, radius = 200 )
	{
		if ( !entity || !entity.IsValid() ) return false
		
		local origin = entity.GetOrigin()
		local inferno = null
		
		while ( inferno = Entities.FindByClassnameWithin( inferno, "inferno", origin, radius ) )
		{
			if ( inferno && inferno.IsValid() ) return true
		}
		return false
	}
	
	// Count number of active infernos near entity
	function CountNearbyInfernos( entity, radius = 500 )
	{
		if ( !entity || !entity.IsValid() ) return 0
		
		local count = 0
		local origin = entity.GetOrigin()
		local inferno = null
		
		while ( inferno = Entities.FindByClassnameWithin( inferno, "inferno", origin, radius ) )
		{
			if ( inferno && inferno.IsValid() ) count++
		}
		return count
	}
}

printl( "[MaoLib.NavUtils] Loaded successfully." )
