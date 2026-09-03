param(
	[string]$ModPath = (Split-Path -Parent $PSScriptRoot),
	[string]$GamePath = 'D:\Steam\steamapps\common\Stellaris'
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$keys = @()

if (-not (Test-Path -LiteralPath $ModPath)) {
	throw "Mod path not found: $ModPath"
}

$scriptFiles = Get-ChildItem -LiteralPath $ModPath -Recurse -File |
	Where-Object { $_.Extension -in '.txt', '.gfx', '.mod' }

foreach ($file in $scriptFiles) {
	$text = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8)
	$clean = [regex]::Replace($text, '"(?:\\.|[^"\\])*"', '""')
	$clean = [regex]::Replace($clean, '(?m)#.*$', '')
	$depth = 0
	foreach ($char in $clean.ToCharArray()) {
		if ($char -eq '{') { $depth++ }
		elseif ($char -eq '}') {
			$depth--
			if ($depth -lt 0) {
				$errors.Add("Closing brace without opener: $($file.FullName)")
				break
			}
		}
	}
	if ($depth -ne 0) {
		$errors.Add("Unbalanced braces ($depth): $($file.FullName)")
	}
}

$descriptor = Join-Path $ModPath 'descriptor.mod'
if (-not (Test-Path -LiteralPath $descriptor)) {
	$errors.Add('descriptor.mod is missing.')
} else {
	$descriptorText = [IO.File]::ReadAllText($descriptor, [Text.Encoding]::UTF8)
	if ($descriptorText -notmatch 'version="1\.0"') { $errors.Add('descriptor.mod version is not 1.0.') }
	if ($descriptorText -notmatch 'supported_version="4\.4\.\*"') { $errors.Add('supported_version is not 4.4.*.') }
	if ($descriptorText -match 'replace_path') { $errors.Add('replace_path must not be used.') }
}

$launcherDescriptor = Join-Path $ModPath 'launcher\rogue_servitor_enhanced.mod'
if (-not (Test-Path -LiteralPath $launcherDescriptor)) {
	$errors.Add('Launcher descriptor is missing.')
} else {
	$launcherText = [IO.File]::ReadAllText($launcherDescriptor, [Text.Encoding]::UTF8)
	if ($launcherText -notmatch 'version="1\.0"') { $errors.Add('Launcher descriptor version is not 1.0.') }
	if ($launcherText -notmatch 'supported_version="4\.4\.\*"') { $errors.Add('Launcher supported_version is not 4.4.*.') }
	if ($launcherText -notmatch 'path="mod/rogue_servitor_enhanced"') { $errors.Add('Launcher descriptor path is invalid.') }
}

$locFile = Join-Path $ModPath 'localisation\simp_chinese\rse_l_simp_chinese.yml'
if (-not (Test-Path -LiteralPath $locFile)) {
	$errors.Add('Simplified Chinese localisation is missing.')
} else {
	$bytes = [IO.File]::ReadAllBytes($locFile)
	if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
		$errors.Add('Localisation must be UTF-8 with BOM.')
	}
	$locText = [IO.File]::ReadAllText($locFile, [Text.Encoding]::UTF8)
	if ($locText -notmatch '^l_simp_chinese:') { $errors.Add('Invalid localisation language header.') }
	if ($locText -match '活体陈设') { $errors.Add('Use the requested display term 活體陳設 consistently.') }
	$keys = [regex]::Matches($locText, '(?m)^\s+([A-Za-z0-9_.-]+):\d+\s') |
		ForEach-Object { $_.Groups[1].Value }
	$duplicates = $keys | Group-Object | Where-Object Count -gt 1
	foreach ($duplicate in $duplicates) {
		$errors.Add("Duplicate localisation key: $($duplicate.Name)")
	}

	$requiredLocalisationKeys = @(
		'rse_route.2.name',
		'trait_rse_master_maid_desc',
		'job_rse_home_service_desc',
		'job_rse_activity_recorder_desc',
		'job_rse_mechanical_maid_desc',
		'tech_rse_secret_project_effect',
		'building_rse_maid_service_hall_desc',
		'sm_ring_rse_maid_drop_protocol_desc',
		'policy_rse_maid_production_policy_desc',
		'decision_rse_disable_maid_refining_desc',
		'edict_rse_maid_production_reorganization_act_desc',
		'tr_rse_individual_needs_model_effect',
		'tr_rse_permanent_activity_records_effect',
		'ap_rse_master_maid_tooltip',
		'pc_rse_ideal_paradise_desc',
		'planet_rse_mechanical_maids'
	)
	foreach ($requiredKey in $requiredLocalisationKeys) {
		if ($requiredKey -notin $keys) {
			$errors.Add("Required localisation key is missing: $requiredKey")
		}
	}
}

$requiredDefinitions = @{
	'common\technology\rse_technology.txt' = @(
		'tech_rse_service_specialization', 'tech_rse_secret_project',
		'tech_rse_personal_records', 'tech_rse_mechanical_maids', 'tech_rse_service_project'
	)
	'common\buildings\rse_buildings.txt' = @(
		'building_rse_maid_service_hall', 'building_rse_simulated_maid_hall',
		'building_rse_maid_center', 'building_rse_maid_monument'
	)
	'common\pop_jobs\rse_jobs.txt' = @(
		'rse_home_service', 'rse_activity_recorder', 'rse_mechanical_maid',
		'planet_researchers_produces_mult = @rse_activity_recorder_research_efficiency',
		'has_ascension_perk = ap_rse_master_maid',
		'sr_living_metal = @rse_maid_refinery_output',
		'has_carrier_flag = rse_maid_refining_disabled',
		'consumer_goods = 11.25', 'alloys = 11.25'
	)
	'common\scripted_variables\rse_variables.txt' = @(
		'@rse_maid_minerals_upkeep = 10', '@rse_maid_food_upkeep = 5',
		'@rse_maid_consumer_goods = 15', '@rse_maid_refinery_minerals_upkeep = 2.5',
		'@rse_maid_refinery_output = 0.5', '@rse_maid_center_unity = 1.25',
		'@rse_maid_technology_efficiency = 0.10', '@rse_maid_orbital_efficiency = 0.20'
	)
	'common\starbase_buildings\rse_orbital_ring_buildings.txt' = @(
		'ring_rse_maid_drop_protocol',
		'pop_rse_mechanical_maid_bonus_workforce_mult = @rse_maid_orbital_efficiency'
	)
	'common\policies\rse_policies.txt' = @(
		'rse_maid_production_0', 'rse_maid_production_25', 'rse_maid_production_50',
		'rse_maid_production_75', 'rse_maid_production_100'
	)
	'common\on_actions\rse_on_actions.txt' = @('on_policy_changed', 'rse_maintenance.5')
	'events\rse_route_events.txt' = @(
		'rse_maid_production_always_available_initialized',
		'last_changed_policy = rse_maid_production_policy',
		'reset_policy_cooldowns = yes'
	)
	'common\decisions\rse_decisions.txt' = @(
		'decision_rse_disable_maid_refining', 'decision_rse_enable_maid_refining'
	)
	'common\edicts\rse_edicts.txt' = @('rse_maid_production_reorganization_act', 'always = no')
	'common\ascension_perks\rse_ascension_perks.txt' = @(
		'ap_rse_master_maid', 'MACHINE_species_trait_picks_add = 3', 'ROBOT_species_trait_picks_add = 3'
	)
	'common\planet_classes\rse_planet_classes.txt' = @(
		'pc_rse_ideal_paradise', 'picture = pc_city', 'planet_max_districts_mult = 0.50'
	)
}

$technologyPath = Join-Path $ModPath 'common\technology\rse_technology.txt'
if (Test-Path -LiteralPath $technologyPath) {
	$technologyText = [IO.File]::ReadAllText($technologyPath, [Text.Encoding]::UTF8)
	$maidTechnologyBonusCount = [regex]::Matches(
		$technologyText,
		'pop_rse_mechanical_maid_bonus_workforce_mult\s*=\s*@rse_maid_technology_efficiency'
	).Count
	if ($maidTechnologyBonusCount -ne 2) {
		$errors.Add("Mechanical Maid and Service Project must each grant the +10% maid bonus; found $maidTechnologyBonusCount definitions.")
	}
}
foreach ($relativePath in $requiredDefinitions.Keys) {
	$definitionPath = Join-Path $ModPath $relativePath
	if (-not (Test-Path -LiteralPath $definitionPath)) {
		$errors.Add("Required v1.0 file is missing: $relativePath")
		continue
	}
	$definitionText = [IO.File]::ReadAllText($definitionPath, [Text.Encoding]::UTF8)
	foreach ($requiredText in $requiredDefinitions[$relativePath]) {
		if (-not $definitionText.Contains($requiredText)) {
			$errors.Add("Required v1.0 definition is missing from ${relativePath}: $requiredText")
		}
	}
}

$allModText = ($scriptFiles | ForEach-Object {
	[IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
}) -join "`n"
if ($allModText -match 'add_research_option\s*=\s*tech_cloning') {
	$errors.Add('The inaccessible vanilla tech_cloning research option must not be used; use tech_rse_secret_project.')
}
if ($allModText -match '(has|set|remove)_planet_flag\s*=\s*rse_(maid_refining_disabled|ideal_paradise_prepared)') {
	$errors.Add('Colony state must use 4.4 carrier flags instead of planet-only flags.')
}

$maintenanceEvent = Join-Path $ModPath 'events\rse_route_events.txt'
if (Test-Path -LiteralPath $maintenanceEvent) {
	$maintenanceText = [IO.File]::ReadAllText($maintenanceEvent, [Text.Encoding]::UTF8)
	if ($maintenanceText -notmatch 'set_carrier_flag\s*=\s*rse_ideal_paradise_prepared') {
		$errors.Add('Ideal Paradise preparation carrier flag is missing.')
	}
}

$paradiseEnvironmentFiles = @(
	'pc_rse_ideal_paradise_sky.dds',
	'pc_rse_ideal_paradise_sky02.dds',
	'pc_rse_ideal_paradise_sky03.dds',
	'pc_rse_ideal_paradise_sky04.dds',
	'pc_rse_ideal_paradise_sky05.dds'
)
foreach ($environmentFile in $paradiseEnvironmentFiles) {
	$environmentPath = Join-Path $ModPath "gfx\portraits\environments\$environmentFile"
	if (-not (Test-Path -LiteralPath $environmentPath)) {
		$errors.Add("Ideal Paradise environment texture is missing: $environmentFile")
	}
}

$eventIds = foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $ModPath 'events') -Filter '*.txt' -File)) {
	$text = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8)
	[regex]::Matches($text, '(?m)^\s*id\s*=\s*(rse_[A-Za-z0-9_.]+)\s*$') |
		ForEach-Object { $_.Groups[1].Value }
}
foreach ($duplicate in ($eventIds | Group-Object | Where-Object Count -gt 1)) {
	$errors.Add("Duplicate event id: $($duplicate.Name)")
}

if (Test-Path -LiteralPath $GamePath) {
	$gfxText = Get-ChildItem -LiteralPath (Join-Path $GamePath 'interface') -Filter '*.gfx' -File -Recurse |
		ForEach-Object { [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8) }
	if (($gfxText -join "`n") -notmatch 'name\s*=\s*"GFX_evt_metropolis"') {
		$errors.Add('Vanilla event picture GFX_evt_metropolis was not found.')
	}
	$rawTextures = [regex]::Matches(
		[IO.File]::ReadAllText((Join-Path $ModPath 'interface\rse_icons.gfx'), [Text.Encoding]::UTF8),
		'texture[Ff]ile\s*=\s*"([^"]+)"'
	) | ForEach-Object { $_.Groups[1].Value }
	foreach ($texture in $rawTextures) {
		if (-not (Test-Path -LiteralPath (Join-Path $GamePath ($texture -replace '/', '\')))) {
			$errors.Add("Missing vanilla texture: $texture")
		}
	}
} else {
	$warnings.Add("Game path not found; vanilla asset checks skipped: $GamePath")
}

if ($warnings.Count -gt 0) {
	$warnings | ForEach-Object { Write-Warning $_ }
}
if ($errors.Count -gt 0) {
	$errors | ForEach-Object { Write-Error $_ -ErrorAction Continue }
	exit 1
}

Write-Output "Validation passed: $ModPath"
Write-Output "Checked $($scriptFiles.Count) script/descriptor files and $($keys.Count) localisation keys."
