param([string]$Map = "c1m1")

$ModelToCategory = @{
    'orange_cone' = 'cone'
    'plastic_icechest_lid' = 'ice'
    'shopping_cart' = 'cart'
    'garbage_can\.mdl' = 'can'
    'garbage_can001' = 'can'
    'urban_pot_large' = 'pot'
    'mall_pot_large' = 'pot'
    'trashbin01\.mdl' = 'bin'
    'trashbin01a' = 'bin_a'
    'highway_barrel' = 'barrel_road'
    'plastic_bucket' = 'bucket'
    'sleeping_bag' = 'sleepingbag'
    'gurney' = 'gurney'
    'wheelchair' = 'wheelchair'
    'mail_dropbox' = 'mailbox'
    'wood_pallet' = 'pallet'
    'oxygentank' = 'oxy'
    'gascan001a' = 'gascan'
    'plastic_chair' = 'pchair'
    'plastic_water_jug' = 'pjug'
    'plastic_basin' = 'basin'
    'oildrum' = 'oil'
    'cafe_barstool' = 'barstool'
    'garbage_pile01' = 'garbagePile01'
    'garbage_pile02' = 'garbagePile02'
    'garbage256_composite001b' = 'garb256_001b'
    'garbage256_composite002b' = 'garb256_002b'
    'urban_bush_angled_128' = 'bushAngled128'
    'urban_bush_angled_256' = 'bush256'
    'food_pile' = 'food03'
    'newspaperstack' = 'newspaper'
    'concrete_post' = 'concrete_post'
    'dead_male_civilian_body' = 'deadbody'
    'dead_male_civilian_02' = 'deadbody'
    'dead_female_civilian_02' = 'deadbody'
    'dead_male_legs' = 'deadbody'
    'dead_male_torso' = 'deadbody'
    'dead_male_suit' = 'deadbody'
    'crow_group' = 'crow'
    'urban_puddle_model' = 'puddle'
    'luggage_pile' = 'luggage'
    'water_cooler' = 'watercooler'
    'concrete_barrier01' = 'barrier'
    'tire001' = 'tire'
    'dumpster_2' = 'dumpster'
    'dumpster\.mdl' = 'dumpster'
    'traffic_barrel' = 'traffic_barrel'
    'van001a' = 'van'
    'satellitedish_large01' = 'satellite'
    'controlroom_chair001a' = 'control_chair'
    'table_folding_folded' = 'folding_table'
    'metalbucket02a' = 'metalbucket'
}

$ExcludeModels = @(
    'urban_tree_giant01_skysphere'
    'common_male_ceda'
    'wall_192_c'
    'de_train_horizontalcoolingtank'
    'scaffolding_norails'
    'mall_rampbundle'
    'elevator_buttons'
    'handtruck'
    'sawhorse'
    'ceda_trailer_closed'
    'pipeset08d_corner128d'
    'outhouse_door001'
    'concrete_debris128pile'
    'concrete_pipe001a'
    'concrete_chunk01a'
    'concrete_chunk01b'
    'concrete_chunk01c'
    'concrete_chunk02a'
    'concrete_chunk07a'
    'tree_trunk_chunk02'
    'tree_trunk_fallen'
    'tree_stump01'
    'wood_crate002a'
    'stove02'
    'fence_b'
    'garbage128_composite001d'
    'garbage256_composite001a'
    'tree_base_bushes01'
    'tree_base_bushes02'
    'urban_tree_base_bushes01_large'
    'sign_street_05'
    'hmmwv_supply'
)

$tacmPath = "D:\Software\SourceStuff\addons\referencias\tacm maps\maps\c1m1_hotel_entities_coop.txt"
if ($Map -eq "c1m2") { $tacmPath = "D:\Software\SourceStuff\addons\referencias\tacm maps\maps\c1m2_streets_entities_coop.txt" }

Write-Host "Parsing $tacmPath ..." -ForegroundColor Cyan
$content = Get-Content $tacmPath -Raw
$entityBlocks = [regex]::Matches($content, '"entity"\s*\{[^}]*\}')
Write-Host "Found $($entityBlocks.Count) entities total" -ForegroundColor Gray

$output = @()
$matched = 0
$unknown = 0
$skipped = 0

foreach ($block in $entityBlocks) {
    $text = $block.Value
    $m = [regex]::Match($text, '"classname"\s*"([^"]+)"')
    if (!$m.Success) { continue }
    $classname = $m.Groups[1].Value

    if ($classname -eq 'infodecal') { $skipped++; continue }
    if ($classname -notmatch '^prop_') { $skipped++; continue }

    $m = [regex]::Match($text, '"model"\s*"([^"]+)"')
    if (!$m.Success) { $skipped++; continue }
    $model = $m.Groups[1].Value
    $modelName = $model.Split('/')[-1]

    $exclude = $false
    foreach ($ex in $ExcludeModels) {
        if ($modelName -match [regex]::Escape($ex)) { $exclude = $true; break }
    }
    if ($exclude) { $skipped++; continue }

    $category = $null
    foreach ($pattern in $ModelToCategory.Keys) {
        if ($modelName -match $pattern) { $category = $ModelToCategory[$pattern]; break }
    }

    if (!$category) { $unknown++; continue }

    $m = [regex]::Match($text, '"origin"\s*"([^"]+)"')
    if (!$m.Success) { $skipped++; continue }
    $originParts = ($m.Groups[1].Value) -split '\s+'
    if ($originParts.Count -lt 3) { $skipped++; continue }

    $m = [regex]::Match($text, '"angles"\s*"([^"]+)"')
    $angleStr = if ($m.Success) { $m.Groups[1].Value } else { "0 0 0" }
    $angleParts = $angleStr -split '\s+'
    if ($angleParts.Count -lt 3) { $angleParts = @("0","0","0") }

    $m = [regex]::Match($text, '"spawnflags"\s*"([^"]+)"')
    $spawnflags = if ($m.Success) { $m.Groups[1].Value } else { "0" }

    $uniqueName = "${category}_${matched}"

    $ox = [math]::Round([double]$originParts[0], 1)
    $oy = [math]::Round([double]$originParts[1], 1)
    $oz = [math]::Round([double]$originParts[2], 1)
    $ap = [math]::Round([double]$angleParts[0], 2)
    $ay = [math]::Round([double]$angleParts[1], 2)
    $ar = [math]::Round([double]$angleParts[2], 2)

    $output += "    $uniqueName = [$ox, $oy, $oz, $ap, $ay, $ar, $spawnflags, `"$category`"],"
    $matched++
}

Write-Host "`n=== RESULT ===" -ForegroundColor Green
Write-Host "  Matched: $matched  Unknown: $unknown  Skipped: $skipped" -ForegroundColor Green

Write-Host "`n========================== VSCRIPT OUTPUT ==========================" -ForegroundColor Cyan
Write-Host "// Props from TACM $Map ($matched entities)`n"

$chunkSize = 15
for ($i = 0; $i -lt $output.Count; $i += $chunkSize) {
    $end = [Math]::Min($i + $chunkSize, $output.Count)
    Write-Host "`n        // Props $($i+1)-$end"
    for ($j = $i; $j -lt $end; $j++) {
        Write-Host "        $($output[$j])"
    }
}

Write-Host "`n[Done]" -ForegroundColor Green
