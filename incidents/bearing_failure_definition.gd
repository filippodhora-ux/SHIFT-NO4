class_name BearingFailureDefinition
extends Resource

@export var failure_id: StringName = &"P-B-BEARING-DEGRADATION"
@export var target_device_id: StringName = &"P-B"

@export_category("Wear")
@export_range(0.0, 1.0, 0.0001) var base_wear_per_sim_hour: float = 0.014
@export_range(0.0, 10.0, 0.01) var idle_load_multiplier: float = 0.05
@export_range(0.0, 10.0, 0.01) var normal_load_multiplier: float = 0.75
@export_range(0.0, 20.0, 0.01) var overload_load_multiplier: float = 5.0
@export_range(0.01, 8.0, 0.01, "or_greater") var load_curve_exponent: float = 1.5
@export_range(0.0, 1.0, 0.01) var normal_load_ratio: float = 0.75
@export_range(1.0, 10.0, 0.01, "or_greater") var maximum_temperature_multiplier: float = 2.0
@export_range(1.0, 10.0, 0.01, "or_greater") var maximum_stress_multiplier: float = 2.5
@export_range(0.0, 10.0, 0.01, "or_greater") var existing_damage_extra_multiplier: float = 1.5
@export_range(0.0, 1.0, 0.01) var stopped_wear_factor: float = 0.02

@export_category("Failure phase condition minimums")
@export_range(0.0, 1.0, 0.01) var healthy_min_condition: float = 0.97
@export_range(0.0, 1.0, 0.01) var latent_min_condition: float = 0.90
@export_range(0.0, 1.0, 0.01) var worn_min_condition: float = 0.72
@export_range(0.0, 1.0, 0.01) var degraded_min_condition: float = 0.45
@export_range(0.0, 1.0, 0.01) var failing_min_condition: float = 0.12

@export_category("Symptoms")
@export_range(0.0, 10.0, 0.01, "or_greater") var healthy_vibration_units: float = 0.1
@export_range(0.0, 10.0, 0.01, "or_greater") var load_vibration_units: float = 0.15
@export_range(0.0, 10.0, 0.01, "or_greater") var failed_vibration_units: float = 1.2
@export_range(-100.0, 500.0, 0.1, "suffix:°C") var healthy_bearing_temperature_c: float = 45.0
@export_range(0.0, 200.0, 0.1, "or_greater", "suffix:°C") var load_temperature_rise_c: float = 10.0
@export_range(0.0, 300.0, 0.1, "or_greater", "suffix:°C") var failed_temperature_rise_c: float = 75.0
@export_range(0.0, 5.0, 0.01, "or_greater") var coolant_temperature_coupling: float = 0.2
@export_range(0.0, 10.0, 0.01, "or_greater") var idle_current_proxy: float = 0.35
@export_range(0.0, 10.0, 0.01, "or_greater") var load_current_proxy: float = 0.45
@export_range(0.0, 10.0, 0.01, "or_greater") var failed_current_proxy: float = 0.9

@export_category("Field service")
@export_range(0.1, 60.0, 0.1, "or_greater", "suffix:s") var service_duration_seconds: float = 3.0
@export_range(0.01, 1.0, 0.01) var service_condition_restore: float = 0.35


func load_multiplier(requested_load: float, maximum_load: float) -> float:
	var normalized_load := clampf(requested_load / maxf(maximum_load, 0.000001), 0.0, 1.0)
	if normalized_load <= normal_load_ratio:
		var normal_t := normalized_load / maxf(normal_load_ratio, 0.000001)
		return lerpf(idle_load_multiplier, normal_load_multiplier, pow(normal_t, load_curve_exponent))

	var overload_t := (
		(normalized_load - normal_load_ratio)
		/ maxf(1.0 - normal_load_ratio, 0.000001)
	)
	return lerpf(
		normal_load_multiplier,
		overload_load_multiplier,
		pow(overload_t, load_curve_exponent)
	)


func phase_for_condition(condition: float) -> int:
	if condition >= healthy_min_condition:
		return BearingFailureRuntime.Phase.HEALTHY
	if condition >= latent_min_condition:
		return BearingFailureRuntime.Phase.LATENT
	if condition >= worn_min_condition:
		return BearingFailureRuntime.Phase.WORN
	if condition >= degraded_min_condition:
		return BearingFailureRuntime.Phase.DEGRADED
	if condition >= failing_min_condition:
		return BearingFailureRuntime.Phase.FAILING
	return BearingFailureRuntime.Phase.FAILED


func condition_for_phase(phase: BearingFailureRuntime.Phase) -> float:
	match phase:
		BearingFailureRuntime.Phase.HEALTHY:
			return 1.0
		BearingFailureRuntime.Phase.LATENT:
			return (healthy_min_condition + latent_min_condition) * 0.5
		BearingFailureRuntime.Phase.WORN:
			return (latent_min_condition + worn_min_condition) * 0.5
		BearingFailureRuntime.Phase.DEGRADED:
			return (worn_min_condition + degraded_min_condition) * 0.5
		BearingFailureRuntime.Phase.FAILING:
			return (degraded_min_condition + failing_min_condition) * 0.5
		_:
			return failing_min_condition * 0.5


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if failure_id.is_empty() or target_device_id.is_empty():
		errors.append("bearing failure IDs must not be empty")
	if not _finite_non_negative(base_wear_per_sim_hour):
		errors.append("base_wear_per_sim_hour must be finite and non-negative")
	if not _phase_thresholds_are_ordered():
		errors.append("bearing phase thresholds must be normalized and strictly descending")
	if normal_load_ratio <= 0.0 or normal_load_ratio >= 1.0:
		errors.append("normal_load_ratio must be between zero and one")
	if load_curve_exponent <= 0.0 or is_nan(load_curve_exponent) or is_inf(load_curve_exponent):
		errors.append("load_curve_exponent must be finite and positive")
	if overload_load_multiplier < normal_load_multiplier or normal_load_multiplier < idle_load_multiplier:
		errors.append("load wear multipliers must be ordered idle <= normal <= overload")
	if maximum_temperature_multiplier < 1.0 or maximum_stress_multiplier < 1.0:
		errors.append("temperature and stress maximum multipliers must be at least one")
	if service_duration_seconds <= 0.0 or is_nan(service_duration_seconds) or is_inf(service_duration_seconds):
		errors.append("service_duration_seconds must be finite and positive")
	if service_condition_restore <= 0.0 or service_condition_restore > 1.0 or is_nan(service_condition_restore) or is_inf(service_condition_restore):
		errors.append("service_condition_restore must be finite and normalized above zero")
	return errors


func _phase_thresholds_are_ordered() -> bool:
	return (
		healthy_min_condition <= 1.0
		and healthy_min_condition > latent_min_condition
		and latent_min_condition > worn_min_condition
		and worn_min_condition > degraded_min_condition
		and degraded_min_condition > failing_min_condition
		and failing_min_condition > 0.0
	)


func _finite_non_negative(value: float) -> bool:
	return not is_nan(value) and not is_inf(value) and value >= 0.0
