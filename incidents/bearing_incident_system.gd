class_name BearingIncidentSystem
extends RefCounted

var definition: BearingFailureDefinition
var runtime: BearingFailureRuntime
var service_active: bool = false
var service_remaining_seconds: float = 0.0
var service_started_tick: int = -1
var completed_service_count: int = 0


func _init(failure_definition: BearingFailureDefinition) -> void:
	definition = failure_definition
	runtime = BearingFailureRuntime.new(definition.failure_id, definition.target_device_id)


func reset() -> void:
	runtime.reset_failure()
	service_active = false
	service_remaining_seconds = 0.0
	service_started_tick = -1
	completed_service_count = 0


func begin_service(pump: PumpState, tick: int) -> Dictionary:
	if service_active:
		return {"accepted": false, "reason": "SERVICE_IN_PROGRESS"}
	if pump.enabled:
		return {"accepted": false, "reason": "PUMP_MUST_BE_STOPPED"}
	if pump.condition >= 1.0:
		return {"accepted": false, "reason": "NO_SERVICE_NEEDED"}

	service_active = true
	service_remaining_seconds = definition.service_duration_seconds
	service_started_tick = tick
	return {"accepted": true, "reason": ""}


func update_service(pump: PumpState, step_seconds: float, tick: int) -> bool:
	if not service_active:
		return false
	if pump.enabled:
		service_active = false
		service_remaining_seconds = 0.0
		return false

	service_remaining_seconds = maxf(0.0, service_remaining_seconds - step_seconds)
	if service_remaining_seconds > 0.0:
		return false

	pump.set_condition(minf(1.0, pump.condition + definition.service_condition_restore))
	if pump.condition > 0.0:
		pump.set_available(true)
	runtime.update_from_condition(pump.condition, tick, definition)
	service_active = false
	service_started_tick = -1
	completed_service_count += 1
	return true


func update_wear(
	pump: PumpState,
	requested_load: float,
	maximum_load: float,
	coolant_temperature_c: float,
	nominal_coolant_temperature_c: float,
	maximum_coolant_temperature_c: float,
	plant_stress: float,
	step_seconds: float,
	simulated_hours_per_real_second: float,
	tick: int
) -> void:
	var simulated_hours := step_seconds * simulated_hours_per_real_second
	var load_factor := definition.load_multiplier(requested_load, maximum_load)
	var temperature_ratio := clampf(
		inverse_lerp(nominal_coolant_temperature_c, maximum_coolant_temperature_c, coolant_temperature_c),
		0.0,
		1.0
	)
	var temperature_factor := lerpf(1.0, definition.maximum_temperature_multiplier, temperature_ratio)
	var stress_factor := lerpf(1.0, definition.maximum_stress_multiplier, plant_stress)
	var damage_factor := 1.0 + pump.wear * definition.existing_damage_extra_multiplier
	var operating_factor := 1.0 if pump.enabled and pump.available else definition.stopped_wear_factor
	var wear_delta := (
		definition.base_wear_per_sim_hour
		* load_factor
		* temperature_factor
		* stress_factor
		* damage_factor
		* operating_factor
		* simulated_hours
	)
	pump.add_wear(wear_delta)
	runtime.update_from_condition(pump.condition, tick, definition)


func refresh(
	pump: PumpState,
	requested_load: float,
	coolant_temperature_c: float,
	nominal_coolant_temperature_c: float,
	tick: int
) -> void:
	runtime.update_from_condition(pump.condition, tick, definition)
	var damage := clampf(1.0 - pump.condition, 0.0, 1.0)
	var operating_factor := 1.0 if pump.enabled and pump.available else 0.0
	var coolant_excess_c := maxf(0.0, coolant_temperature_c - nominal_coolant_temperature_c)
	pump.vibration_units = operating_factor * (
		definition.healthy_vibration_units
		+ requested_load * definition.load_vibration_units
		+ damage * definition.failed_vibration_units
	)
	pump.bearing_temperature_c = definition.healthy_bearing_temperature_c + operating_factor * (
		requested_load * definition.load_temperature_rise_c
		+ damage * definition.failed_temperature_rise_c
		+ coolant_excess_c * definition.coolant_temperature_coupling
	)
	pump.current_proxy = operating_factor * (
		definition.idle_current_proxy
		+ requested_load * definition.load_current_proxy
		+ damage * definition.failed_current_proxy
	)


func debug_set_phase(pump: PumpState, phase: int, tick: int) -> bool:
	if phase < BearingFailureRuntime.Phase.HEALTHY or phase > BearingFailureRuntime.Phase.FAILED:
		return false
	if not pump.set_condition(definition.condition_for_phase(phase as BearingFailureRuntime.Phase)):
		return false
	runtime.update_from_condition(pump.condition, tick, definition)
	return true


func is_failed() -> bool:
	return runtime.phase == BearingFailureRuntime.Phase.FAILED


func to_dictionary() -> Dictionary:
	var result := runtime.to_dictionary()
	result.merge(service_state_dictionary(), true)
	return result


func service_state_dictionary() -> Dictionary:
	return {
		"service_active": service_active,
		"service_remaining_seconds": service_remaining_seconds,
		"service_duration_seconds": definition.service_duration_seconds,
		"completed_service_count": completed_service_count,
	}
