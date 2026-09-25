param(
	[string]$ModPath = (Split-Path -Parent $PSScriptRoot),
	[string]$GamePath = 'D:\Steam\steamapps\common\Stellaris'
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path -LiteralPath $ModPath)) { throw "Mod path not found: $ModPath" }

$scriptFiles = Get-ChildItem -LiteralPath $ModPath -Recurse -File |
	Where-Object { $_.Extension -in '.txt', '.gfx', '.mod' }
foreach ($file in $scriptFiles) {
	$text = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8)
	$clean = [regex]::Replace($text, '"(?:\\.|[^"\\])*"', '""')
	$clean = [regex]::Replace($clean, '(?m)#.*$', '')
	$depth = 0
	foreach ($char in $clean.ToCharArray()) {
		if ($char -eq '{') { $depth++ }
		elseif ($char -eq '}') { $depth--; if ($depth -lt 0) { break } }
	}
	if ($depth -ne 0) { $errors.Add("Unbalanced braces ($depth): $($file.FullName)") }
}

$descriptorPath = Join-Path $ModPath 'descriptor.mod'
$launcherPath = Join-Path $ModPath 'launcher\rogue_servitor_enhanced_v2.mod'
foreach ($item in @(
	@($descriptorPath, 'version="2.8.1"', 'supported_version="4.4.*"'),
	@($launcherPath, 'version="2.8.1"', 'path="mod/rogue_servitor_enhanced_v2"')
)) {
	if (-not (Test-Path -LiteralPath $item[0])) { $errors.Add("Descriptor missing: $($item[0])"); continue }
	$text = [IO.File]::ReadAllText($item[0], [Text.Encoding]::UTF8)
	foreach ($needle in $item[1..($item.Count - 1)]) {
		if (-not $text.Contains($needle)) { $errors.Add("Descriptor value missing: $needle") }
	}
	if ($text -match 'replace_path|\[TEST\]|prototype') { $errors.Add("Formal descriptor contains a forbidden test/replace label: $($item[0])") }
}

$allKeys = @()
$locRoot = Join-Path $ModPath 'localisation\simp_chinese'
foreach ($file in (Get-ChildItem -LiteralPath $locRoot -Filter '*.yml' -File)) {
	$bytes = [IO.File]::ReadAllBytes($file.FullName)
	if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
		$errors.Add("Localisation must be UTF-8 with BOM: $($file.Name)")
	}
	$text = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8)
	if ($text -notmatch '^l_simp_chinese:') { $errors.Add("Bad localisation header: $($file.Name)") }
	$allKeys += [regex]::Matches($text, '(?m)^\s+([A-Za-z0-9_.-]+):\d+\s') | ForEach-Object { $_.Groups[1].Value }
}
foreach ($dup in ($allKeys | Group-Object | Where-Object Count -gt 1)) { $errors.Add("Duplicate localisation key: $($dup.Name)") }
foreach ($key in @(
	'job_rse_exhausted_bio_trophy_desc', 'building_rse_alley_clothing_workshop_desc',
	'building_rse_city_dome_desc', 'building_rse_planetary_dome_desc',
	'leader_trait_rse_bridal_desc', 'leader_trait_rse_portable_jar_network_desc',
	'decision_rse_white_leader_desc', 'rse_proto.200.name', 'rse_proto.201.c.effect', 'rse_proto.241.name',
	'rse_home_service_fixed', 'rse_home_service_tradition_fixed',
	'rse_activity_recorder_fixed', 'rse_activity_recorder_tradition_fixed',
	'rse_home_service_assembly_capped',
	'planet_rse_activity_recorders',
	'edict_rse_portable_space_utilization', 'edict_rse_portable_space_utilization_desc',
	'edict_rse_growth_plan_reorganization_act', 'edict_rse_growth_plan_reorganization_act_desc',
	'edict_rse_recruit_trophy_leader', 'edict_rse_recruit_trophy_leader_desc',
	'pop_cat_rse_servitor', 'pop_cat_rse_servitor_plural', 'pop_cat_rse_servitor_desc',
	'planet_jobs_rse_servitor', 'mod_pop_cat_rse_servitor_bonus_workforce_mult',
	'rse_route_universal_shelter_effect', 'rse_servitors_can_only_enslave_foreign_organics',
	'rse_maid_production_10', 'rse_maid_production_10_name', 'rse_maid_production_10_desc',
	'rse_maid_production_90', 'rse_maid_production_90_name', 'rse_maid_production_90_desc',
	'zone_rse_food_nexus', 'zone_rse_food_nexus_desc',
	'district_rse_nexus_food', 'district_rse_nexus_food_plural', 'district_rse_nexus_food_desc',
	'zone_rse_maid_industry', 'zone_rse_maid_industry_desc', 'district_rse_maid_industry',
	'district_rse_maid_industry_plural', 'district_rse_maid_industry_desc',
	'building_rse_maid_workshop_coordination_zone_tt',
	'casus_belli_cb_rse_polluted_database', 'war_goal_wg_rse_polluted_database',
	'preset_rse_supervisory_zone', 'specialist_rse_supervisory_zone',
	'rse_supervisory_zone_1', 'rse_supervisory_zone_2', 'rse_supervisory_zone_3',
	'holding_rse_social_observer', 'rse_database_cleaning',
	'tech_rse_unrestricted_maids', 'tech_rse_unrestricted_maids_effect'
)) {
	if ($key -notin $allKeys) { $errors.Add("Required localisation key missing: $key") }
}

$required = @{
	'common\job_tags\rse_job_tags.txt' = @(
		'rse_home_service', 'nanites', 'sr_zro', 'sr_dark_matter'
	)
	'common\pop_jobs\rse_jobs.txt' = @(
		'rse_exhausted_bio_trophy = {', 'is_capped_by_modifier = no', 'can_set_priority = no',
		'icon = bio_trophy', 'rse_home_service = {', 'rse_activity_recorder = {',
		'rse_bio_trophy_effects_active = yes',
		'tags = { amenities pop_assembly rse_home_service }',
		'category = planet_rse_activity_recorders', 'society_research = @rse_activity_recorder_society',
		'planet_researchers_produces_mult = @rse_activity_recorder_research_efficiency',
		'species_empire_size_mult = @rse_activity_recorder_tradition_empire_size',
		'rse_home_service = {', 'rse_activity_recorder = {',
		'rse_processing_specialist = {', 'rse_material_synthesizer = {',
		'has_ascension_perk = ap_mind_over_matter'
	)
	'common\pop_categories\rse_pop_categories.txt' = @(
		'rse_servitor = {', 'rank = 4', 'change_job_threshold = 1.03',
		'job_reshuffle_interval = 7', 'category = planet_automated_jobs',
		'pop_housing_usage_base = 1', 'pop_amenities_usage_no_happiness_base = 1',
		'inline_script = "pop_categories/resettlement_costs"',
		'is_robotic_species = yes', 'key = mod_robotic_pop_bonus_workforce_mult',
		'pop_bonus_workforce_mult = 1', 'mult = colony.modifier:robotic_pop_bonus_workforce_mult',
		'category = pop_category_drones'
	)
	'common\economic_categories\rse_economic_categories.txt' = @(
		'planet_rse_mechanical_maids', 'planet_rse_activity_recorders',
		'icon = "brain_drone"', 'parent = planet_jobs_specialist', 'generate_mult_modifiers = {',
		'planet_rse_exhausted_bio_trophies'
	)
	'common\scripted_variables\rse_variables.txt' = @(
		'@rse_activity_recorder_society = 9', '@rse_activity_recorder_tradition_society = 4.5',
		'@rse_home_service_assembly = 1.00', '@rse_home_service_tradition_assembly = 0.50',
		'@rse_home_service_deviation = -20', '@rse_home_service_energy_upkeep = 0.375',
		'@rse_activity_recorder_energy_upkeep = 0.375',
		'@rse_domestic_maid_stability = 0.50', '@rse_maid_workshop_trade = 15',
		'@rse_rotation_category_minor = 0.002', '@rse_rotation_category_balanced = 0.007',
		'@rse_rotation_category_major = 0.012', '@rse_visit_planner_housing_usage = -0.01',
		'@rse_service_job_weight = 20', '@rse_servitor_job_weight = 50',
		'@rse_maid_service_job_efficiency = 0.20',
		'@rse_organic_simulator_assembly_per_pop = 0.001', '@rse_organic_simulator_pop_cap = 15000',
		'@rse_intelligence_simulator_stability_per_pop = 0.001', '@rse_intelligence_simulator_pop_cap = 30000',
		'@rse_desire_simulator_growth_per_pop = 0.00001', '@rse_desire_simulator_pop_cap = 15000'
	)
	'common\script_values\rse_script_values.txt' = @(
		'rse_organic_simulator_pop_amount', 'rse_organic_simulator_cap_multiplier',
		'rse_intelligence_simulator_pop_amount', 'rse_intelligence_simulator_cap_multiplier',
		'rse_desire_simulator_pop_amount', 'rse_desire_simulator_cap_multiplier',
		'trigger = count_owned_pop_amount', 'min = 1', 'max = 1'
	)
	'common\traits\rse_traits.txt' = @(
		'custom_tooltip = trait_rse_organic_simulator_effect',
		'custom_tooltip = trait_rse_intelligence_simulator_effect',
		'custom_tooltip = trait_rse_desire_simulator_effect'
	)
	'common\scripted_effects\rse_growth_effects.txt' = @(
		'rse_update_growth_simulators = {', 'trigger = count_owned_pop_amount',
		'is_occupied_flag = no', 'rse_has_exclusive_route = yes',
		'which = rse_organic_simulator_count value = @rse_organic_simulator_pop_cap',
		'which = rse_desire_simulator_count value = @rse_desire_simulator_pop_cap',
		'modifier = rse_organic_simulator_scaled', 'modifier = rse_desire_simulator_scaled'
	)
	'common\buildings\rse_buildings.txt' = @(
		'building_rse_alley_clothing_workshop', 'building_rse_city_dome', 'building_rse_planetary_dome',
		'job_rse_processing_specialist_add = 150', 'job_rse_material_synthesizer_add = 150',
		'cost = { minerals = 2800 food = 1000 alloys = 500 }',
		'upkeep = { energy = 25 food = 10 minerals = 10 }',
		'ai_resource_production = { society_research = 20 alloys = 20 }',
		'job_bio_trophy_add = 5000', 'job_bio_trophy_add = 10000', 'planet_pops_upkeep_mult = -0.05',
		'job_rse_mechanical_maid_add = 200', 'country_modifier = {', 'planet_rse_mechanical_maids_upkeep_mult = -0.10',
		'building_rse_maid_base', 'building_rse_maid_workshop_coordination',
		'building_rse_maid_workshop_coordination_zone_tt',
		'building_rse_maid_automation_coordination',
		'bonus_automated_workforce_mult = @rse_automation_center_penalty',
		'planet_automated_jobs_upkeep_mult = @rse_automation_upkeep_reduction'
	)
	'events\rse_route_events.txt' = @(
		'remove_modifier = rse_home_service_fixed', 'remove_modifier = rse_activity_recorder_fixed',
		'trigger = total_workforce_with_job_tag', 'tags = { rse_home_service }',
		'divide_variable = { which = rse_home_service_assembly_output value = 100 }',
		'modifier = rse_home_service_assembly_capped',
		'which = rse_home_service_assembly_output value = 40',
		'which = rse_home_service_assembly_output value = 20',
		'trigger = count_owned_pop_amount', 'has_trait = trait_rse_intelligence_simulator',
		'which = rse_intelligence_simulator_count value = 30',
		'modifier = rse_intelligence_simulator_scaled',
		'custom_tooltip = rse_route_universal_shelter_effect',
		'type = district_nexus_1', 'type = district_nexus_2', 'type = district_nexus_3'
	)
	'common\traits\rse_leader_traits.txt' = @(
		'leader_trait_rse_bridal', 'leader_trait_rse_public_exposure', 'leader_trait_rse_portable_jar',
		'leader_trait_rse_expanded_selection', 'leader_trait_rse_portable_jar_network', 'has_base_skill > 4',
		'leader_trait_type = destiny', 'councilor_exp_gain = 0.10', 'councilor_skill_add = 3'
	)
	'events\rse_leader_events.txt' = @(
		'id = rse_proto.20', 'clone_leader', 'id = rse_proto.200', 'id = rse_proto.201',
		'id = rse_proto.241', 'remove_trait = leader_trait_rse_surrounded_pending',
		'ruler = { add_trait = { trait = leader_trait_rse_erotic_simulator } }'
	)
	'common\decisions\rse_leader_decisions.txt' = @(
		'decision_rse_white_leader', 'country_event = { id = rse_proto.241 days = 300 }'
	)
	'common\edicts\rse_leader_edicts.txt' = @('rse_portable_space_utilization', 'rse_surrounded_selection', 'id = rse_picker.1')
	'common\on_actions\rse_on_actions.txt' = @(
		'rse_proto.100', 'rse_proto.20', 'on_building_complete', 'on_building_demolished',
		'on_district_complete', 'on_district_demolished', 'on_zone_complete', 'rse_conversion.1'
	)
	'common\policies\rse_policies.txt' = @(
		'rse_growth_exhaust', 'bonus_pop_growth_mult = 1.00',
		'rse_maid_production_10', 'rse_maid_production_90'
	)
	'common\static_modifiers\rse_static_modifiers.txt' = @(
		'rse_growth_monitor_counter_exhaust', 'bonus_pop_growth_mult = -1.00',
		'rse_white_leader_touring', 'rse_white_leader_common_sense',
		'rse_server_upgrade = {', 'bonus_pop_growth = 30',
		'rse_mugwort_protocol = {', 'starbase_shipyard_build_speed_mult = 0.20',
		'rse_home_service_fixed = {}', 'rse_home_service_tradition_fixed = {}',
		'rse_activity_recorder_fixed = {}', 'rse_activity_recorder_tradition_fixed = {}',
		'rse_intelligence_simulator_scaled = {', 'planet_stability_add = 1',
		'rse_home_service_assembly_capped = {', 'planet_pop_assembly_add = 1',
		'bonus_pop_growth = 1'
	)
	'common\traditions\rse_traditions.txt' = @(
		'custom_tooltip_with_modifiers = tr_rse_service_standardization_effect',
		'custom_tooltip = tr_rse_individual_needs_model_effect',
		'custom_tooltip = tr_rse_permanent_activity_records_effect',
		'custom_tooltip_with_modifiers = tr_rse_perfect_environment_engineering_effect',
		'custom_tooltip_with_modifiers = tr_rse_global_service_network_effect',
		'unlocks_agenda = agenda_rse_expand_service', 'unlocks_agenda = agenda_rse_protocol_upgrade',
		'planet_rse_home_services_upkeep_mult = -0.20', 'planet_rse_activity_recorders_upkeep_mult = -0.20'
	)
	'common\technology\rse_technology.txt' = @(
		'tech_rse_personal_records = {', 'tech_rse_service_specialization = {',
		'tech_rse_mechanical_maids = {', 'tech_rse_drone_rotation = {',
		'tech_rse_organic_mind_deconstruction = {', 'tech_rse_unrestricted_maids = {',
		'prerequisites = { "tech_existential_campaigns" "tech_titans" }',
		'titan_ships_limit_add = 80000', 'juggernaut_ships_limit_add = 100',
		'colossus_ships_limit_add = 100'
	)
	'common\armies\rse_armies.txt' = @('rse_combat_maid_army = {', 'cost = { consumer_goods = 250 }')
	'common\terraform\rse_terraform_links.txt' = @(
		'from = "pc_volcanic"', 'to = "pc_rse_ideal_paradise"',
		'has_technology = "tech_volcanic_terraforming"'
	)
	'common\species_rights\citizenship_types\rse_citizenship_types.txt' = @(
		'citizenship_slavery = {', 'fail_text = rse_servitors_can_only_enslave_foreign_organics',
		'NOT = { has_trait = trait_rse_protected_founder }'
	)
	'common\zones\rse_zones.txt' = @(
		'zone_rse_food_nexus = {', 'is_planet_class = pc_rse_ideal_paradise',
		'script = jobs/zone_farmers_add', 'AMOUNT = @doubled_scaling_district_1_job',
		'swap_type = district_rse_nexus_food', 'nexus', 'zone_building_slots_add = 3',
		'zone_rse_maid_industry = {', 'zone_rse_maid_industry_arcology = {',
		'zone_rse_maid_industry_nexus = {', 'zone_rse_maid_industry_ring_world = {',
		'script = jobs/zone_rse_mechanical_maids_add', 'AMOUNT = @scaling_district_1_job',
		'AMOUNT = @doubled_scaling_district_1_job',
		'has_active_building = building_rse_maid_workshop_coordination'
	)
	'common\districts\rse_swap_districts.txt' = @(
		'district_rse_nexus_food = {', 'overlay_icon = GFX_district_food',
		'slot_empty', 'script = districts/district_triggered_name_farming',
		'district_rse_arcology_maid_industry = {', 'district_rse_nexus_maid_industry = {',
		'district_rse_ring_world_maid_industry = {'
	)
	'common\inline_scripts\jobs\zone_rse_mechanical_maids_add.txt' = @(
		'job_rse_mechanical_maid_add = $AMOUNT$', 'planet_is_ecu_equivalent = yes',
		'planet_is_ring_world_equivalent = yes', 'mult = 3', 'mult = 5'
	)
	'events\rse_conversion_events.txt' = @(
		'namespace = rse_conversion', 'id = rse_conversion.1', 'id = rse_conversion.2',
		'id = rse_conversion.3', 'export_modifier_to_variable', 'modifier = job_patrol_drone_add',
		'modifier = rse_patrol_capacity_conversion', 'check_planet_employment = yes'
	)
	'common\casus_belli\rse_casus_belli.txt' = @(
		'cb_rse_polluted_database = {', 'show_in_diplomacy = yes',
		'has_ascension_perk = ap_rse_master_maid', 'NOT = { has_trait = trait_rse_protected_founder }'
	)
	'common\war_goals\rse_war_goals.txt' = @(
		'wg_rse_polluted_database = {', 'release_occupied_systems_on_status_quo = yes',
		'on_accept = {', 'on_status_quo = {', 'last_created_country = {',
		'rse_convert_to_supervisory_zone = yes'
	)
	'common\scripted_effects\rse_supervisory_zone_effects.txt' = @(
		'rse_convert_to_supervisory_zone = {', 'preset = preset_rse_supervisory_zone',
		'size = 200', 'type = citizenship_assimilation', 'type = citizenship_purge',
		'modifier = rse_database_cleaning', 'modifier = rse_supervisory_zone_initial_loyalty'
	)
	'common\agreement_presets\rse_supervisory_zone_preset.txt' = @(
		'preset_rse_supervisory_zone = {', 'value = subject_can_be_integrated',
		'value = subject_can_not_do_diplomacy', 'value = subject_can_expand'
	)
	'common\specialist_subject_perks\rse_supervisory_zone_perks.txt' = @(
		'rse_supervisory_zone_1 = {', 'rse_supervisory_zone_2 = {', 'rse_supervisory_zone_3 = {',
		'planet_amenities_add = 100', 'planet_amenities_add = 200', 'planet_amenities_add = 300',
		'ship_speed_mult = 0.05', 'ship_speed_mult = 0.10', 'ship_speed_mult = 0.15'
	)
	'common\buildings\rse_supervisory_holdings.txt' = @(
		'holding_rse_social_observer = {', 'owner_type = subject_holding',
		'triggered_country_modifier = {', 'potential = { always = yes }', 'modifier = {'
	)
	'common\specialist_subject_types\rse_supervisory_zone.txt' = @(
		'@rse_supervisory_level_2_xp = 600', '@rse_supervisory_level_3_xp = 1800',
		'base_conversion_time = 15'
	)
	'events\rse_leader_picker_events.txt' = @(
		'id = rse_picker.1', 'id = rse_picker.2', 'rse_picker_candidate_4',
		'is_variable_set = rse_picker_index', 'which = rse_picker_offset value = 4',
		'which = rse_picker_offset value >= rse_picker_count',
		'flag = rse_surrounded_selection_cooldown days = 720', 'id = rse_proto.201'
	)
	'common\scripted_effects\rse_leader_picker_effects.txt' = @(
		'rse_picker_clear = {', 'clear_variable = rse_picker_index',
		'remove_country_flag = rse_picker_open'
	)
	'common\scripted_triggers\rse_conversion_triggers.txt' = @(
		'rse_patrol_conversion_enabled = {', 'rse_has_exclusive_route = yes',
		'has_active_building = building_rse_maid_base', 'has_active_building = building_rse_maid_center'
	)
	'common\scripted_triggers\rse_leader_picker_triggers.txt' = @(
		'rse_surrounded_eligible_leader = {', 'has_base_skill > 4',
		'is_robotic_species = yes', 'is_gestalt_node = no', 'is_ruler = no'
	)
	'common\scripted_triggers\rse_triggers.txt' = @(
		'can_have_habitable_deposits = {', 'is_planet_class = pc_rse_ideal_paradise'
	)
}
foreach ($relative in $required.Keys) {
	$path = Join-Path $ModPath $relative
	if (-not (Test-Path -LiteralPath $path)) { $errors.Add("Required file missing: $relative"); continue }
	$text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
	foreach ($needle in $required[$relative]) {
		if (-not $text.Contains($needle)) { $errors.Add("Required definition missing from $relative : $needle") }
	}
}

# Behavior guards for the feedback patch, beyond exact presence checks.
$feedbackStatic = [IO.File]::ReadAllText((Join-Path $ModPath 'common\static_modifiers\rse_static_modifiers.txt'), [Text.Encoding]::UTF8)
$homeAssemblyBlock = [regex]::Match($feedbackStatic, '(?ms)^rse_home_service_assembly_capped\s*=\s*\{.*?^\}')
if ($homeAssemblyBlock.Value -match 'fake_pop_growth_mod') {
	$errors.Add('Home Service must not display duplicate fake organic growth.')
}
$feedbackBuildings = [IO.File]::ReadAllText((Join-Path $ModPath 'common\buildings\rse_buildings.txt'), [Text.Encoding]::UTF8)
if ($feedbackBuildings -match 'rse_patrol_drone_conversion_active|rse_patrol_drone_conversion_units') {
	$errors.Add('Building-backed conversion must not stack with the shared capacity modifier.')
}
$feedbackConversion = [IO.File]::ReadAllText((Join-Path $ModPath 'events\rse_conversion_events.txt'), [Text.Encoding]::UTF8)
if ($feedbackConversion -match 'trigger\s*=\s*(num_assigned_jobs|free_jobs_of_type)') {
	$errors.Add('Patrol conversion capacity must not be inferred from employed population.')
}
$feedbackTraits = [IO.File]::ReadAllText((Join-Path $ModPath 'common\traits\rse_leader_traits.txt'), [Text.Encoding]::UTF8)
foreach ($trait in @('bridal', 'public_exposure', 'portable_jar')) {
	$block = [regex]::Match($feedbackTraits, "(?ms)^leader_trait_rse_$trait\s*=\s*\{.*?^\}")
	if ($block.Value -match 'randomized\s*=\s*yes|selectable_weight\s*=\s*[1-9]') {
		$errors.Add("Surrounded trait must be event-only: $trait")
	}
}
foreach ($key in @('edict_rse_surrounded_selection', 'edict_rse_surrounded_selection_desc', 'rse_picker.1.name', 'rse_picker.2.name', 'rse_picker.candidate_4', 'rse_picker.next', 'rse_picker.cancel', 'rse_patrol_capacity_conversion')) {
	if ($key -notin $allKeys) { $errors.Add("Feedback localisation missing: $key") }
}

$allText = ($scriptFiles | ForEach-Object { [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8) }) -join "`n"
$forbidden = @{
	'reset_policy_cooldowns\s*=\s*yes' = 'Must not clear every policy cooldown.'
	'add_research_option\s*=\s*tech_cloning' = 'Use tech_rse_secret_project, not tech_cloning.'
	'remove_modifier\s*=\s*planet_population_control_gestalt' = 'Must not clear vanilla Stop Drone Production.'
	'planet_bio_trophies_produces_mult\s*=\s*[-+]?100' = 'Use the independent exhausted job, not the old output clamp.'
	'rse_prototype_test_console' = 'Formal V2 must not expose the prototype test console.'
	'RARITY\s*=\s*legendary' = '4.4 does not support legendary scripted leader trait rarity.'
	'leader_possible_remove\s*=' = 'leader_possible_remove is invalid in 4.4.'
	'remove_trait\s*=\s*\{\s*trait\s*=' = '4.4 remove_trait uses a direct trait key.'
	'planet_rse_activity_records_fixed' = 'The obsolete Activity Recorder economic category must not return.'
	'rse_(home_service|activity_recorder)_assigned' = 'Broken monthly assigned-job counter must not return.'
	'country_base_society_research_produces_add' = 'Activity Recorder must use normal job research, not a hidden country-base modifier.'
	'building_rse_mysterious_house' = 'The retired Mysterious House must not remain in the formal mod.'
	'building_rse_organic_solidification_plant' = 'The retired Organic Material Solidification Plant must not remain in the formal mod.'
	'bonus_pop_growth\s*=\s*70' = 'Server Upgrade organic assembly must remain at 30, not 70.'
	'job_artisan_drone_add\s*=\s*-' = 'Economic-category inheritance must replace negative Artisan job conversion.'
}
foreach ($pattern in $forbidden.Keys) { if ($allText -match $pattern) { $errors.Add($forbidden[$pattern]) } }

foreach ($retiredLocKey in @(
	'building_rse_mysterious_house', 'building_rse_mysterious_house_desc',
	'building_rse_organic_solidification_plant', 'building_rse_organic_solidification_plant_desc'
)) {
	if ($retiredLocKey -in $allKeys) { $errors.Add("Retired building localisation must not remain: $retiredLocKey") }
}

foreach ($relative in @(
	'common\casus_belli\rse_prototype_casus_belli.txt',
	'common\war_goals\rse_prototype_war_goals.txt',
	'common\buildings\rse_prototype_holdings.txt'
)) {
	if (Test-Path -LiteralPath (Join-Path $ModPath $relative)) { $errors.Add("Prototype content must not ship: $relative") }
}

foreach ($relative in @('common\decisions\rse_decisions.txt', 'events\rse_route_events.txt')) {
	$path = Join-Path $ModPath $relative
	if ((Test-Path -LiteralPath $path) -and ([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) -match 'set_policy\s*=')) {
		$errors.Add("Planet-local monitor must not set empire policy: $relative")
	}
}

$jobText = [IO.File]::ReadAllText((Join-Path $ModPath 'common\pop_jobs\rse_jobs.txt'), [Text.Encoding]::UTF8)
$exhaust = [regex]::Match($jobText, '(?ms)^rse_exhausted_bio_trophy\s*=\s*\{.*?^\}')
if (-not $exhaust.Success) { $errors.Add('Independent exhausted job block not found.') }
elseif ($exhaust.Value -match 'produces\s*=|planet_modifier\s*=|triggered_planet_modifier\s*=') {
	$errors.Add('The exhausted job must not produce resources or planet modifiers.')
}
elseif ($exhaust.Value -notmatch '(?m)^\s*icon\s*=\s*bio_trophy\s*$') {
	$errors.Add('The exhausted job must explicitly reuse the vanilla Bio-Trophy icon.')
}

$homeBlock = [regex]::Match($jobText, '(?ms)^rse_home_service\s*=\s*\{.*?^\}')
if (-not $homeBlock.Success) { $errors.Add('Home Service job block not found.') }
elseif ($homeBlock.Value -notmatch 'tags\s*=\s*\{[^}]*rse_home_service') {
	$errors.Add('Home Service must expose its unique effective-workforce tag to the monthly cap controller.')
} elseif ($homeBlock.Value -match 'planet_pop_assembly_add|bonus_pop_growth|fake_pop_growth_mod') {
	$errors.Add('Home Service assembly must be applied by the capped monthly modifier, not directly by the job.')
}

$traitText = [IO.File]::ReadAllText((Join-Path $ModPath 'common\traits\rse_traits.txt'), [Text.Encoding]::UTF8)
foreach ($name in @('organic', 'desire')) {
    $block = [regex]::Match($traitText, "(?ms)^trait_rse_${name}_simulator\s*=\s*\{.*?^\}")
    if (-not $block.Success -or $block.Value -match 'triggered_planet_pop_group_modifier_for_species') {
        $errors.Add("Growth simulators must use only monthly colony calculation: $name")
    }
}

$intelligenceBlock = [regex]::Match($traitText, '(?ms)^trait_rse_intelligence_simulator\s*=\s*\{.*?^\}')
if (-not $intelligenceBlock.Success) { $errors.Add('Intelligence Simulator trait block missing.') }
else {
	if (-not $intelligenceBlock.Value.Contains('custom_tooltip = trait_rse_intelligence_simulator_effect')) {
		$errors.Add('Intelligence Simulator tooltip is missing.')
	}
	if ($intelligenceBlock.Value -match 'triggered_planet_pop_group_modifier_for_species|planet_stability_add') {
		$errors.Add('Intelligence Simulator Stability must use the legal monthly colony modifier, not a pop-group modifier category.')
	}
}

$routeMaintenanceText = [IO.File]::ReadAllText((Join-Path $ModPath 'events\rse_route_events.txt'), [Text.Encoding]::UTF8)
if (-not $routeMaintenanceText.Contains('rse_update_growth_simulators = yes')) {
    $errors.Add('Monthly growth simulator refresh is missing.')
}
$growthEffects = [IO.File]::ReadAllText((Join-Path $ModPath 'common\scripted_effects\rse_growth_effects.txt'), [Text.Encoding]::UTF8)
foreach ($name in @('organic', 'desire')) {
    if (-not $growthEffects.Contains("modifier = rse_${name}_simulator_scaled") -or -not $growthEffects.Contains("has_trait = trait_rse_${name}_simulator")) {
        $errors.Add("Missing monthly simulator implementation: $name")
    }
}

$activityBlock = [regex]::Match($jobText, '(?ms)^rse_activity_recorder\s*=\s*\{.*?^\}')
if (-not $activityBlock.Success) { $errors.Add('Activity Recorder job block not found.') }
else {
	foreach ($needle in @('resources = {', 'category = planet_rse_activity_recorders', 'society_research = @rse_activity_recorder_society', 'planet_researchers_produces_mult = @rse_activity_recorder_research_efficiency')) {
		if (-not $activityBlock.Value.Contains($needle)) { $errors.Add("Activity Recorder normal-research definition missing: $needle") }
	}
	if ($activityBlock.Value -match '(?m)^\s*category\s*=\s*planet_researchers\s*$') {
		$errors.Add('Activity Recorder must not use planet_researchers as its resource category; that recreates its self-buff feedback loop.')
	}
}

$mechanicalMaidBlock = [regex]::Match($jobText, '(?ms)^rse_mechanical_maid\s*=\s*\{.*?^\}')
if (-not $mechanicalMaidBlock.Success) { $errors.Add('Mechanical Maid job block not found.') }
elseif ($mechanicalMaidBlock.Value -match 'bonus_pop_growth|fake_pop_growth|rse_maid_cultivation') {
	$errors.Add('Mechanical Maids must not provide organic population growth or cultivation.')
}
else {
	foreach ($needle in @(
		'has_policy_flag = rse_maid_production_10', 'consumer_goods = 13.50', 'alloys = 1.50',
		'has_policy_flag = rse_maid_production_90', 'consumer_goods = 1.50', 'alloys = 13.50'
	)) {
		if (-not $mechanicalMaidBlock.Value.Contains($needle)) { $errors.Add("Mechanical Maid policy output missing: $needle") }
	}
}

$bioTrophyBlock = [regex]::Match($jobText, '(?ms)^bio_trophy\s*=\s*\{.*?^\}')
if (-not $bioTrophyBlock.Success) { $errors.Add('Bio-Trophy override block not found.') }
else {
	if ($bioTrophyBlock.Value -notmatch 'has_starbase_building = rse_underground_studio' -or
		$bioTrophyBlock.Value -notmatch 'robotic_pop_bonus_workforce_mult = @rse_bio_trophy_robotic_efficiency') {
		$errors.Add('Bio-Trophies must provide the Underground Studio robotic workforce bridge.')
	}
	if ($bioTrophyBlock.Value -match 'rse_specialization_labor') {
		$errors.Add('Labor Simulation must not add a second worker/simple-drone efficiency modifier through Bio-Trophies.')
	}
	foreach ($needle in @(
		'pop_cat_complex_drone_bonus_workforce_mult = @rse_rotation_category_minor',
		'pop_cat_complex_drone_bonus_workforce_mult = @rse_rotation_category_balanced',
		'worker_and_simple_drone_cat_bonus_workforce_mult = @rse_rotation_category_minor',
		'worker_and_simple_drone_cat_bonus_workforce_mult = @rse_rotation_category_balanced',
		'worker_and_simple_drone_cat_bonus_workforce_mult = @rse_rotation_category_major'
	)) {
		if (-not $bioTrophyBlock.Value.Contains($needle)) { $errors.Add("Bio-Trophy activity-scope definition missing: $needle") }
	}
}

if ($jobText -match 'rse_rotation_robotic_(?:minor|full)') {
	$errors.Add('Removed robotic activity-scope variables are still referenced by a job.')
}

$expectedServitorJobs = @(
	'rse_home_service', 'rse_activity_recorder',
	'rse_processing_specialist', 'rse_material_synthesizer'
)
$actualServitorJobs = [regex]::Matches($jobText, '(?ms)^([A-Za-z0-9_]+)\s*=\s*\{.*?^\}') |
	Where-Object { $_.Value -match '(?m)^\s*category\s*=\s*rse_servitor\s*$' } |
	ForEach-Object { $_.Groups[1].Value }
$servitorDiff = Compare-Object ($expectedServitorJobs | Sort-Object) ($actualServitorJobs | Sort-Object)
if ($servitorDiff) {
	$errors.Add("The rse_servitor stratum must contain exactly the four approved jobs. Actual: $($actualServitorJobs -join ', ')")
}
foreach ($job in $expectedServitorJobs) {
	$block = [regex]::Match($jobText, "(?ms)^$job\s*=\s*\{.*?^\}")
	if (-not $block.Success -or $block.Value -notmatch '(?m)^\s*weight\s*=\s*\{\s*weight\s*=\s*@rse_servitor_job_weight\s*\}\s*$') {
		$errors.Add("Servitor job must use the dedicated priority-50 weight: $job")
	}
}
foreach ($job in @('rse_mechanical_maid', 'rse_domestic_maid', 'rse_visit_planner', 'rse_maid_automation_coordinator')) {
	$block = [regex]::Match($jobText, "(?ms)^$job\s*=\s*\{.*?^\}")
	if (-not $block.Success -or $block.Value -notmatch '(?m)^\s*weight\s*=\s*\{\s*weight\s*=\s*@rse_service_job_weight\s*\}\s*$') {
		$errors.Add("Non-servitor support job must retain the standard priority-20 weight: $job")
	}
}

foreach ($needle in @(
	'has_country_flag = rse_transformation_nanotech_full', 'nanites = @rse_maid_refinery_output',
	'has_country_flag = rse_transformation_modularity_full', 'sr_living_metal = @rse_maid_refinery_output',
	'has_country_flag = rse_transformation_virtuality_full', 'energy = @rse_maid_path_energy_output',
	'has_ascension_perk = ap_mind_over_matter', 'sr_zro = @rse_maid_zro_output',
	'has_technology = tech_mine_dark_matter', 'sr_dark_matter = @rse_maid_dark_matter_output',
	'trade = @rse_maid_workshop_trade'
)) {
	if (-not $mechanicalMaidBlock.Value.Contains($needle)) { $errors.Add("Mechanical Maid V2.6 production line missing: $needle") }
}
if ($mechanicalMaidBlock.Value -match 'has_country_flag\s*=\s*transformation_(?:nanotech|modularity|virtuality)') {
	$errors.Add('Mechanical Maid base path output must use permanent Full-result flags, not the single final-route flags.')
}
foreach ($tradition in @('tr_nanotech_adopt', 'tr_modularity_adopt', 'tr_virtuality_adopt')) {
	if ($mechanicalMaidBlock.Value -notmatch "has_country_flag\s*=\s*rse_transformation_[A-Za-z]+_full\s+has_tradition\s*=\s*$tradition") {
		$errors.Add("Mechanical Maid Full-result tradition bonus missing: $tradition")
	}
}

if ($jobText -match 'rse_maid_cultivation(?:_desire)?') {
	$errors.Add('Removed Mechanical Maid cultivation variables are still referenced by a job.')
}

$routeEventText = [IO.File]::ReadAllText((Join-Path $ModPath 'events\rse_route_events.txt'), [Text.Encoding]::UTF8)
if ($routeEventText -match '(?ms)add_modifier\s*=\s*\{[^}]*modifier\s*=\s*rse_maid_monument_scaled') {
	$errors.Add('The monthly event must not reapply Mechanical Maid monument growth.')
}
$staticText = [IO.File]::ReadAllText((Join-Path $ModPath 'common\static_modifiers\rse_static_modifiers.txt'), [Text.Encoding]::UTF8)
$mugwortBlock = [regex]::Match($staticText, '(?ms)^rse_mugwort_protocol\s*=\s*\{.*?^\}')
if (-not $mugwortBlock.Success -or $mugwortBlock.Value -notmatch '(?m)^\s*starbase_shipyard_build_speed_mult\s*=\s*0\.20\s*$') {
	$errors.Add('Mugwort must provide the vanilla country-wide +20% shipyard build-speed modifier.')
}
elseif ($mugwortBlock.Value -match '(?m)^\s*shipsize_[A-Za-z0-9_]+_build_speed_mult\s*=') {
	$errors.Add('Mugwort must not enumerate individual ship-size build-speed modifiers.')
}
$maidMonumentShell = [regex]::Match($staticText, '(?ms)^rse_maid_monument_scaled\s*=\s*\{.*?^\}')
if (-not $maidMonumentShell.Success -or $maidMonumentShell.Value -match 'logistic_growth_mult|bonus_pop_growth') {
	$errors.Add('rse_maid_monument_scaled must remain an effect-free save-compatibility shell.')
}

$techText = [IO.File]::ReadAllText((Join-Path $ModPath 'common\technology\rse_technology.txt'), [Text.Encoding]::UTF8)
$personalTech = [regex]::Match($techText, '(?ms)^tech_rse_personal_records\s*=\s*\{.*?^\}')
$serviceTech = [regex]::Match($techText, '(?ms)^tech_rse_service_specialization\s*=\s*\{.*?^\}')
if (-not $personalTech.Success -or $personalTech.Value -match '(?m)^\s*prerequisites\s*=') {
	$errors.Add('Personal Records must be the first technology and have no prerequisite.')
}
if (-not $serviceTech.Success -or -not $serviceTech.Value.Contains('prerequisites = { "tech_rse_personal_records" }')) {
	$errors.Add('Service Specialization must require Personal Records.')
}
foreach ($tech in @('tech_rse_mechanical_maids', 'tech_rse_drone_rotation', 'tech_rse_organic_mind_deconstruction')) {
	$block = [regex]::Match($techText, "(?ms)^$tech\s*=\s*\{.*?^\}")
	if (-not $block.Success -or -not $block.Value.Contains('prerequisites = { "tech_rse_service_specialization" }')) {
		$errors.Add("Downstream technology must require Service Specialization: $tech")
	}
}

$reorganizationEventText = [IO.File]::ReadAllText((Join-Path $ModPath 'events\rse_v2_events.txt'), [Text.Encoding]::UTF8)
foreach ($option in @('rse_maid_production_10', 'rse_maid_production_90')) {
	if ($reorganizationEventText -notmatch "option\s*=\s*$option") {
		$errors.Add("Maid Production reorganization event is missing option: $option")
	}
}
foreach ($needle in @(
	'transformation_engineering_max', 'machine_age_nanites_studied', 'rse_transformation_nanotech_full',
	'transformation_society_max', 'rse_transformation_modularity_full',
	'transformation_physics_max', 'virtuality_data_scraped', 'machine_age_virtuality_studied',
	'rse_transformation_virtuality_full', 'rse_transformation_results_migrated_261',
	'd_nanites_medium', 'd_living_metal_medium', 'd_virtual_power_medium'
)) {
	if (-not $reorganizationEventText.Contains($needle)) { $errors.Add("Transformation Full-result persistence missing: $needle") }
}

$servitorCategoryPath = Join-Path $ModPath 'common\pop_categories\rse_pop_categories.txt'
if (Test-Path -LiteralPath $servitorCategoryPath) {
	$servitorCategoryText = [IO.File]::ReadAllText($servitorCategoryPath, [Text.Encoding]::UTF8)
	if ($servitorCategoryText -match 'social_classes_triggered_modifiers_no_happiness|pop_cat_complex_drone') {
		$errors.Add('The rse_servitor stratum must not inherit complex-drone or the full vanilla workforce bridge bundle.')
	}
}

$servitorIconPath = Join-Path $ModPath 'gfx\interface\icons\pop_categories\pop_cat_rse_servitor.dds'
if (-not (Test-Path -LiteralPath $servitorIconPath)) {
	$errors.Add('Custom rse_servitor category icon is missing.')
} else {
	$iconBytes = [IO.File]::ReadAllBytes($servitorIconPath)
	if ($iconBytes.Length -lt 128 -or
		$iconBytes[0] -ne 0x44 -or $iconBytes[1] -ne 0x44 -or $iconBytes[2] -ne 0x53 -or $iconBytes[3] -ne 0x20 -or
		[BitConverter]::ToInt32($iconBytes, 12) -notin 29, 30 -or [BitConverter]::ToInt32($iconBytes, 16) -notin 29, 30) {
		$errors.Add('The rse_servitor icon must be a valid 29x29 or 30x30 DDS image.')
	}
}

$eventIds = foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $ModPath 'events') -Filter '*.txt' -File)) {
	$text = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8)
	[regex]::Matches($text, '(?m)^\s*id\s*=\s*(rse_[A-Za-z0-9_.]+)\s*$') | ForEach-Object { $_.Groups[1].Value }
}
foreach ($dup in ($eventIds | Group-Object | Where-Object Count -gt 1)) { $errors.Add("Duplicate event id: $($dup.Name)") }

foreach ($name in @(
	'pc_rse_ideal_paradise_sky.dds', 'pc_rse_ideal_paradise_sky02.dds',
	'pc_rse_ideal_paradise_sky03.dds', 'pc_rse_ideal_paradise_sky04.dds',
	'pc_rse_ideal_paradise_sky05.dds'
)) {
	if (-not (Test-Path -LiteralPath (Join-Path $ModPath "gfx\portraits\environments\$name"))) {
		$errors.Add("Ideal Paradise texture missing: $name")
	}
}

if (Test-Path -LiteralPath $GamePath) {
	$feTech = Join-Path $GamePath 'common\technology\00_fallen_empire_tech.txt'
	$feBuildings = Join-Path $GamePath 'common\buildings\13_fallen_empire_buildings.txt'
	foreach ($key in @('tech_fe_dome_1', 'tech_fe_dome_2')) {
		if (-not (Select-String -LiteralPath $feTech -SimpleMatch $key -Quiet)) { $errors.Add("Vanilla key missing: $key") }
	}
	if (-not (Get-ChildItem -LiteralPath (Join-Path $GamePath 'common\technology') -Filter '*.txt' -File |
		Select-String -SimpleMatch 'tech_volcanic_terraforming' -Quiet)) {
		$errors.Add('Vanilla key missing: tech_volcanic_terraforming')
	}
	foreach ($key in @('building_fe_sky_dome', 'building_fe_dome')) {
		if (-not (Select-String -LiteralPath $feBuildings -SimpleMatch $key -Quiet)) { $errors.Add("Vanilla key missing: $key") }
	}
	$vanillaText = (Get-ChildItem -LiteralPath (Join-Path $GamePath 'common') -Recurse -Filter '*.txt' -File |
		ForEach-Object { [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8) }) -join "`n"
	foreach ($key in @(
		'situation_transformation', 'transformation_nanotech', 'transformation_modularity', 'transformation_virtuality',
		'transformation_engineering_max', 'transformation_society_max', 'transformation_physics_max',
		'machine_age_nanites_studied', 'virtuality_data_scraped', 'machine_age_virtuality_studied',
		'd_nanites_medium', 'd_living_metal_medium', 'd_virtual_power_medium',
		'tr_nanotech_adopt', 'tr_modularity_adopt', 'tr_virtuality_adopt',
		'ap_mind_over_matter', 'tech_mine_dark_matter',
		'bonus_automated_workforce_mult', 'planet_automated_jobs_upkeep_mult',
		'planet_defense_armies_add', 'total_workforce_with_job_tag',
		'planet_artisans', 'planet_enforcers', 'triggered_produces_modifier', 'triggered_upkeep_modifier',
		'triggered_planet_pop_group_modifier_for_species', 'divide_over_pop_groups', 'count_owned_pop_amount',
		'free_jobs_of_type', 'num_assigned_jobs', 'tech_existential_campaigns', 'tech_titans',
		'titan_ships_limit', 'juggernaut_ships_limit', 'colossus_ships_limit',
		'@scaling_district_1_job', '@doubled_scaling_district_1_job',
		'planet_is_ecu_equivalent', 'planet_is_ring_world_equivalent'
	)) {
		if (-not $vanillaText.Contains($key)) { $errors.Add("Vanilla V2.5 key missing: $key") }
	}
} else { $warnings.Add("Game path not found; vanilla checks skipped: $GamePath") }

if ($warnings.Count) { $warnings | ForEach-Object { Write-Warning $_ } }
if ($errors.Count) {
	$errors | ForEach-Object { Write-Error $_ -ErrorAction Continue }
	exit 1
}
Write-Output "Validation passed: $ModPath"
Write-Output "Checked $($scriptFiles.Count) script/descriptor files and $($allKeys.Count) localisation keys."
