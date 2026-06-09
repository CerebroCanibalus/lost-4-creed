# Eventos existentes
$existing = @(
    'player_spawn','player_death','player_hurt','player_team','player_incapacitated',
    'player_incapacitated_start','player_ledge_grab','player_ledge_release',
    'player_disconnect','player_connect','heal_success','heal_begin','heal_interrupted',
    'revive_success','revive_begin','revive_interrupted','defibrillator_used',
    'survivor_rescued','pills_used','adrenaline_used','player_no_longer_it',
    'player_now_it','weapon_fire','weapon_reload','weapon_zoom','ammo_pickup',
    'ammo_pack_used','item_pickup','grenade_bounce','molotov_thrown','pipe_bomb_thrown',
    'vomitjar_thrown','melee_kill','bullet_impact','infected_death','infected_hurt',
    'infected_shoved','witch_spawn','witch_killed','witch_harasser_set','tank_spawn',
    'tank_frustrated','tank_killed','hunter_punched','hunter_headshot','smoker_choke',
    'smoker_tongue_broken','charger_carry_start','charger_carry_end',
    'charger_pummel_start','charger_pummel_end','jockey_ride','jockey_ride_end',
    'spitter_killed','boomer_exploded','lunge_pounce','lunge_shove','round_start',
    'round_end','map_transition','mission_lost','mission_complete','finale_start',
    'finale_vehicle_incoming','finale_vehicle_ready','finale_escape_start','finale_win',
    'door_open','door_close','door_unlock','rescue_door_open','checkpoint_door_open',
    'break_prop','explosion','fire_ignite','triggered_car_alarm',
    'triggered_car_alarm_cancel','create_panic_event','panic_event_finished',
    'mob_spawn','horde_alert','player_say','player_chat','achievement_earned',
    'award_earned','player_jump','player_land','bot_player_replace',
    'player_bot_replace','entity_shoved','entity_visible','tongue_grab',
    'tongue_release','choke_begin','choke_end','pounce_begin','pounce_end',
    'pounce_stopped','tongue_pull_stopped','charger_killed','jockey_killed'
)

# Nuevos eventos
$new = @(
    'ability_use','player_shoved','choke_start','choke_stopped','choke_end',
    'weapon_drop','weapon_drop_to_prop','break_breakable','player_use',
    'friendly_fire','round_start_post_nav','player_transitioned',
    'difficulty_changed','hegrenade_detonate','upgrade_pack_used',
    'mounted_gun_start','weapon_given','scavenge_gas_can_destroyed',
    'charger_charge_start','charger_charge_end','spit_burst','entered_spit',
    'charger_impact','player_afk','weapon_fire_on_empty','player_footstep',
    'player_blind','player_falldamage','door_moving',
    'waiting_checkpoint_door_used','waiting_door_used_versus',
    'waiting_checkpoint_button_used','success_checkpoint_button_used',
    'round_freeze_end','round_start_pre_entity','nav_blocked','nav_generate',
    'round_end_message','vote_ended','vote_started','vote_changed','vote_passed',
    'vote_failed','vote_cast_yes','vote_cast_no','hostname_changed',
    'finale_rush','finale_vehicle_leaving','finale_radio_start',
    'finale_radio_damaged','final_reportscreen','heal_end','drag_begin',
    'drag_end','player_entered_start_area','player_first_spawn',
    'player_left_start_area','player_left_safe_area','player_entered_checkpoint',
    'player_left_checkpoint','player_jump_apex','player_blocked','area_cleared',
    'tongue_broke_bent','tongue_broke_victim_died','pounce_end',
    'pounce_attempt_stopped','fatal_vomit','survivor_call_for_help',
    'survivor_rescue_abandoned','relocated','respawning','spec_target_updated',
    'spawner_give_item','entity_visible','weapon_spawn_visible','boomer_near',
    'explain_*','begin_scavenge_overtime','scavenge_*','versus_*','gascan_*',
    'use_target','gameinstructor_*','request_weapon_stats','player_talking_state',
    'weapon_pickup','zombie_ignited','non_pistol_fired','weapon_fire_at_40',
    'total_ammo_below_40','player_hurt_concise','tank_rock_killed',
    'achievement_write_failed','ghost_spawn_time','survival_at_30min',
    'survival_at_10min','gauntlet_finale_start','upgrade_incendiary_ammo',
    'upgrade_explosive_ammo','receive_upgrade','explain_vehicle_arrival',
    'mounted_gun_overheated','explain_burger_sign','explain_carousel_button',
    'explain_carousel_destination','explain_stage_lighting',
    'explain_stage_finale_start','explain_stage_survival_start',
    'ability_out_of_range','explain_stage_pyrotechnics','explain_c3m4_radio1',
    'explain_c3m4_radio2','explain_gates_are_open','explain_c2m4_ticketbooth',
    'explain_c3m4_rescue','explain_hotel_elevator_doors',
    'explain_gun_shop_tanker','explain_gun_shop','explain_store_alarm',
    'explain_store_item','explain_store_item_stop','explain_survival_generic',
    'explain_survival_alarm','explain_survival_radio','explain_survival_carousel',
    'explain_return_item','explain_save_items','temp_c4m1_getgas',
    'temp_c4m3_return_to_boat','explain_c1m4_finale','c1m4_scavenge_instructions',
    'punched_clown','jockey_punched','jockey_headshot','non_melee_fired',
    'infected_decapitated','upgrade_pack_added','vomit_bomb_tank',
    'chair_charged','song_played','foot_locker_opened','golden_crowbar_pickup',
    'pills_used_fail','ammo_pack_used_fail_no_weapon','ammo_pack_used_fail_full',
    'ammo_pack_used_fail_doesnt_use_ammo','ammo_pile_weapon_cant_use_ammo',
    'defibrillator_begin','defibrillator_used_fail','defibrillator_interrupted',
    'upgrade_pack_begin','upgrade_item_already_used','upgrade_failed_no_primary',
    'dead_survivor_visible','adrenaline_used','revive_end','give_weapon',
    'player_hurt_concise','tank_rock_killed','ghost_spawn_time',
    'survival_at_30min','survival_at_10min','versus_marker_reached',
    'start_score_animation','survival_round_start','explain_sewer_gate',
    'explain_sewer_run','explain_c6m3_finale','finale_bridge_lowering',
    'm60_streak_ended','set_instructor_group_enabled','stashwhacker_game_won'
)

# Fusionar y eliminar duplicados
$all = $existing + $new | Sort-Object -Unique
Write-Host "Total eventos: $($all.Count)"

# Formatear como array de PowerShell
$output = @('$validGameEvents = @(')
$line = '    '
$count = 0
foreach ($event in $all) {
    if ($count -gt 0) { $line += ',' }
    $line += "'$event'"
    $count++
    if ($count -ge 4) {
        $output += $line
        $line = '    '
        $count = 0
    }
}
if ($count -gt 0) {
    $output += $line
}
$output += ')'

# Guardar a archivo temporal
$output | Out-File -FilePath 'D:\Software\SourceStuff\addons\testing\events_new.txt' -Encoding UTF8
Write-Host 'Eventos guardados en testing\events_new.txt'
