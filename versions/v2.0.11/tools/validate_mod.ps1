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
	@($descriptorPath, 'version="2.0.11"', 'supported_version="4.4.*"'),
	@($launcherPath, 'version="2.0.11"', 'path="mod/rogue_servitor_enhanced_v2"')
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
	'planet_rse_activity_recorders', 'mod_planet_rse_activity_recorders_produces_mult',
	'edict_rse_portable_space_utilization', 'edict_rse_portable_space_utilization_desc',
	'edict_rse_growth_plan_reorganization_act', 'edict_rse_growth_plan_reorganization_act_desc',
	'edict_rse_recruit_trophy_leader', 'edict_rse_recruit_trophy_leader_desc',
	'pop_cat_rse_servitor', 'pop_cat_rse_servitor_plural', 'pop_cat_rse_servitor_desc',
	'planet_jobs_rse_servitor', 'mod_pop_cat_rse_servitor_bonus_workforce_mult',
	'rse_route_universal_shelter_effect', 'rse_servitors_can_only_enslave_foreign_organics',
	'rse_maid_production_10', 'rse_maid_production_10_name', 'rse_maid_production_10_desc',
	'rse_maid_production_90', 'rse_maid_production_90_name', 'rse_maid_production_90_desc',
	'zone_rse_food_nexus', 'zone_rse_food_nexus_desc',
	'district_rse_nexus_food', 'district_rse_nexus_food_plural', 'district_rse_nexus_food_desc'
)) {
	if ($key -notin $allKeys) { $errors.Add("Required localisation key missing: $key") }
}

$required = @{
	'common\pop_jobs\rse_jobs.txt' = @(
		'rse_exhausted_bio_trophy = {', 'is_capped_by_modifier = no', 'can_set_priority = no',
		'icon = bio_trophy', 'rse_home_service = {', 'rse_activity_recorder = {',
		'rse_bio_trophy_effects_active = yes',
		'planet_pop_assembly_add = @rse_home_service_assembly',
		'bonus_pop_growth = @rse_home_service_assembly',
		'category = planet_rse_activity_recorders', 'society_research = @rse_activity_recorder_society',
		'planet_researchers_produces_mult = @rse_activity_recorder_research_efficiency',
		'species_empire_size_mult = @rse_activity_recorder_tradition_empire_size',
		'rse_home_service = {', 'rse_activity_recorder = {',
		'rse_processing_specialist = {', 'rse_material_synthesizer = {'
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
		'@rse_home_service_assembly = 0.10', '@rse_home_service_tradition_assembly = 0.05',
		'@rse_rotation_category_minor = 0.002', '@rse_rotation_category_balanced = 0.007',
		'@rse_rotation_category_major = 0.012', '@rse_visit_planner_housing_usage = -0.01',
		'@rse_service_job_weight = 20', '@rse_servitor_job_weight = 50',
		'@rse_maid_service_job_efficiency = 0.20'
	)
	'common\buildings\rse_buildings.txt' = @(
		'building_rse_alley_clothing_workshop', 'building_rse_city_dome', 'building_rse_planetary_dome',
		'job_rse_processing_specialist_add = 150', 'job_rse_material_synthesizer_add = 150',
		'cost = { minerals = 2800 food = 1000 alloys = 500 }',
		'upkeep = { energy = 25 food = 10 minerals = 10 }',
		'ai_resource_production = { society_research = 20 alloys = 20 }',
		'job_bio_trophy_add = 5000', 'job_bio_trophy_add = 10000', 'planet_pops_upkeep_mult = -0.05',
		'job_rse_mechanical_maid_add = 200', 'country_modifier = {', 'planet_rse_mechanical_maids_upkeep_mult = -0.10'
	)
	'events\rse_route_events.txt' = @(
		'remove_modifier = rse_home_service_fixed', 'remove_modifier = rse_activity_recorder_fixed',
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
	'common\edicts\rse_leader_edicts.txt' = @('rse_portable_space_utilization')
	'common\on_actions\rse_on_actions.txt' = @('rse_proto.100', 'rse_proto.20')
	'common\policies\rse_policies.txt' = @(
		'rse_growth_exhaust', 'bonus_pop_growth_mult = 1.00',
		'rse_maid_production_10', 'rse_maid_production_90'
	)
	'common\static_modifiers\rse_static_modifiers.txt' = @(
		'rse_growth_monitor_counter_exhaust', 'bonus_pop_growth_mult = -1.00',
		'rse_white_leader_touring', 'rse_white_leader_common_sense',
		'rse_server_upgrade = {', 'bonus_pop_growth = 30',
		'rse_mugwort_protocol = {', 'ship_build_speed_mult = 0.20',
		'rse_home_service_fixed = {}', 'rse_home_service_tradition_fixed = {}',
		'rse_activity_recorder_fixed = {}', 'rse_activity_recorder_tradition_fixed = {}'
	)
	'common\traditions\rse_traditions.txt' = @(
		'custom_tooltip_with_modifiers = tr_rse_service_standardization_effect',
		'custom_tooltip = tr_rse_individual_needs_model_effect',
		'custom_tooltip = tr_rse_permanent_activity_records_effect',
		'custom_tooltip_with_modifiers = tr_rse_perfect_environment_engineering_effect',
		'custom_tooltip_with_modifiers = tr_rse_global_service_network_effect'
	)
	'common\technology\rse_technology.txt' = @(
		'tech_rse_personal_records = {', 'tech_rse_service_specialization = {',
		'tech_rse_mechanical_maids = {', 'tech_rse_drone_rotation = {',
		'tech_rse_organic_mind_deconstruction = {'
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
		'swap_type = district_rse_nexus_food', 'nexus', 'zone_building_slots_add = 3'
	)
	'common\districts\rse_swap_districts.txt' = @(
		'district_rse_nexus_food = {', 'overlay_icon = GFX_district_food',
		'slot_empty', 'script = districts/district_triggered_name_farming'
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
	'common\agreement_presets\rse_supervisory_zone_preset.txt',
	'common\specialist_subject_types\rse_supervisory_zone.txt',
	'common\buildings\rse_prototype_holdings.txt'
)) {
	if (Test-Path -LiteralPath (Join-Path $ModPath $relative)) { $errors.Add("Pending content must not ship: $relative") }
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
elseif ($homeBlock.Value -notmatch 'planet_modifier\s*=|triggered_planet_pop_group_modifier_for_all\s*=') {
	$errors.Add('Home Service must use the last-known-good embedded planet and pop-group modifiers.')
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
	if ($bioTrophyBlock.Value -match 'robotic_pop_bonus_workforce_mult') {
		$errors.Add('Bio-Trophies must not provide robotic-pop workforce efficiency.')
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
foreach ($job in @('rse_mechanical_maid', 'rse_domestic_maid', 'rse_visit_planner')) {
	$block = [regex]::Match($jobText, "(?ms)^$job\s*=\s*\{.*?^\}")
	if (-not $block.Success -or $block.Value -notmatch '(?m)^\s*weight\s*=\s*\{\s*weight\s*=\s*@rse_service_job_weight\s*\}\s*$') {
		$errors.Add("Non-servitor support job must retain the standard priority-20 weight: $job")
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
if (-not $mugwortBlock.Success -or $mugwortBlock.Value -notmatch '(?m)^\s*ship_build_speed_mult\s*=\s*0\.20\s*$') {
	$errors.Add('Mugwort must provide the generic national +20% ship build speed modifier.')
}
elseif ($mugwortBlock.Value -match '(?m)^\s*[A-Za-z0-9_]+_ship_build_speed_mult\s*=') {
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
		[BitConverter]::ToInt32($iconBytes, 12) -ne 30 -or [BitConverter]::ToInt32($iconBytes, 16) -ne 30) {
		$errors.Add('The rse_servitor icon must be a valid 30x30 DDS image.')
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
} else { $warnings.Add("Game path not found; vanilla checks skipped: $GamePath") }

if ($warnings.Count) { $warnings | ForEach-Object { Write-Warning $_ } }
if ($errors.Count) {
	$errors | ForEach-Object { Write-Error $_ -ErrorAction Continue }
	exit 1
}
Write-Output "Validation passed: $ModPath"
Write-Output "Checked $($scriptFiles.Count) script/descriptor files and $($allKeys.Count) localisation keys."
