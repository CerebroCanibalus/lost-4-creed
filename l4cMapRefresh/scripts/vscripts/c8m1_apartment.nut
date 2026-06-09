// ============================================================================
// l4cMapRefresh - No Mercy: Apartments (c8m1_apartment)
// ============================================================================
// Source: jeremyvillanuevar/vscripts_custom (aspawns.nut)
// ============================================================================

::MapRefresh.c8m1_apartment <- {
    _initialized = false,
    
    function Init() {
        if (_initialized) return
        _initialized = true
        
        SpawnReducedProps()
        
        MaoLib.Printf("[MapRefresh] c8m1_apartment initialized")
    }
    
    function SpawnReducedProps() {
        if (!("c8m1_Props" in ::MapRefresh)) return
        
        local allProps = ::MapRefresh.c8m1_Props
        local propList = []
        foreach (name, data in allProps) {
            propList.append({ name = name, data = data })
        }
        
        propList = ShuffleArray(propList)
        local count = (propList.len() * 0.6).tointeger()
        if (count < 1) count = 1
        
        local spawned = 0
        for (local i = 0; i < count && i < propList.len(); i++) {
            local p = propList[i]
            if (::MapRefresh.Utils.SpawnProp(p.data, p.name)) spawned++
        }
        
        MaoLib.Printf("[MapRefresh] Spawned %d/%d props in c8m1_apartment", spawned, propList.len())
    }
    
    function ShuffleArray(arr) {
        local n = arr.len()
        for (local i = n - 1; i > 0; i--) {
            local j = RandomInt(0, i)
            local temp = arr[i]
            arr[i] = arr[j]
            arr[j] = temp
        }
        return arr
    }
}

::MapRefresh.c8m1_apartment_Events <- {
    function OnGameEvent_round_start(params) {
        MaoLib.AddTimer("apartment_init", 2.0, function() {
            if ("c8m1_apartment" in ::MapRefresh) {
                ::MapRefresh.c8m1_apartment.Init()
            }
        })
    }

    function OnGameEvent_round_end(params) {
        MaoLib.RemoveTimer("apartment_init")
    }
}

__CollectGameEventCallbacks(::MapRefresh.c8m1_apartment_Events)
