class_name PlantSimulation
extends RefCounted

const PUMP_A_ID: StringName = &"P-A"
const PUMP_B_ID: StringName = &"P-B"

var _tuning: PlantTuning
var _pump_a: PumpState
var _pump_b: PumpState
var _tick: int = 0
var _requested_load: float = 0.0
var _actual_power_mw: float = 0.0
var _produced_mwh: float = 0.0
var _thermal_demand_units: float = 0.0
var _coolant_flow_units_per_second: float = 0.0
var _cooling_capacity_units: float = 0.0
var _coolant_temperature_c: float = 0.0
var _plant_stress: float = 0.0
var _steam_availability: float = 0.0
var _available_power_mw: float = 0.0


func _init(plant_tuning: PlantTuning) -> void:
	assert(plant_tuning != null, "PlantSimulation requires PlantTuning")

	var tuning_errors := plant_tuning.validation_errors()
	assert(
		tuning_errors.is_empty(),
		"PlantSimulation received invalid tuning: %s" % "; ".join(tuning_errors)
	)

	_tuning = plant_tuning
	_pump_a = PumpState.new(
		PUMP_A_ID,
		_tuning.pump_a_rated_flow_units_per_second,
		_tuning.pump_a_efficiency,
		_tuning.pump_a_enabled_on_reset,
		_tuning.pump_a_available_on_reset
	)
	_pump_b = PumpState.new(
		PUMP_B_ID,
		_tuning.pump_b_rated_flow_units_per_second,
		_tuning.pump_b_efficiency,
		_tuning.pump_b_enabled_on_reset,
		_tuning.pump_b_available_on_reset
	)
	reset()


func set_requested_load(value: float) -> bool:
	if is_nan(value) or is_inf(value):
		push_error("requested_load must be finite")
		return false

	var clamped_value := clampf(
		value,
		_tuning.minimum_requested_load,
		_tuning.maximum_requested_load
	)
	if not is_equal_approx(value, clamped_value):
		push_warning(
			"requested_load %f was clamped to the configured range as %f"
			% [value, clamped_value]
		)

	_requested_load = clamped_value
	return true


func set_pump_enabled(device_id: StringName, enabled: bool) -> bool:
	var pump := _find_pump(device_id)
	if pump == null:
		push_error("Unknown pump device_id: %s" % device_id)
		return false

	pump.enabled = enabled
	return true


func set_pump_available(device_id: StringName, available: bool) -> bool:
	var pump := _find_pump(device_id)
	if pump == null:
		push_error("Unknown pump device_id: %s" % device_id)
		return false

	pump.available = available
	return true


func step(step_seconds: float) -> void:
	assert(
		is_equal_approx(step_seconds, _tuning.simulation_step_seconds),
		"PlantSimulation must be advanced with the configured fixed step"
	)

	_update_thermal_demand()
	_update_pump_flows(step_seconds)
	_update_cooling_state()
	_update_coolant_temperature(step_seconds)
	_update_plant_stress(step_seconds)
	_update_downstream_output(step_seconds)
	_integrate_energy(step_seconds)
	_tick += 1


func reset() -> void:
	_tick = 0
	_requested_load = _tuning.minimum_requested_load
	_actual_power_mw = 0.0
	_produced_mwh = 0.0
	_thermal_demand_units = 0.0
	_coolant_flow_units_per_second = 0.0
	_cooling_capacity_units = 0.0
	_coolant_temperature_c = _tuning.nominal_coolant_temperature_c
	_plant_stress = 0.0
	_steam_availability = 0.0
	_available_power_mw = 0.0
	_pump_a.reset(
		_tuning.pump_a_enabled_on_reset,
		_tuning.pump_a_available_on_reset
	)
	_pump_b.reset(
		_tuning.pump_b_enabled_on_reset,
		_tuning.pump_b_available_on_reset
	)


func create_snapshot() -> PlantSnapshot:
	return PlantSnapshot.new(
		_tick,
		_requested_load,
		_actual_power_mw,
		_produced_mwh,
		_thermal_demand_units,
		_pump_a,
		_pump_b,
		_coolant_flow_units_per_second,
		_cooling_capacity_units,
		_coolant_temperature_c,
		_plant_stress,
		_steam_availability,
		_available_power_mw
	)


func get_tuning() -> PlantTuning:
	return _tuning


func _update_thermal_demand() -> void:
	_thermal_demand_units = _tuning.nominal_thermal_demand_units * _requested_load


func _update_pump_flows(step_seconds: float) -> void:
	_pump_a.update_flow(step_seconds, _tuning.pump_flow_ramp_units_per_second_squared)
	_pump_b.update_flow(step_seconds, _tuning.pump_flow_ramp_units_per_second_squared)


func _update_cooling_state() -> void:
	_coolant_flow_units_per_second = (
		_pump_a.effective_flow_units_per_second
		+ _pump_b.effective_flow_units_per_second
	)
	_cooling_capacity_units = (
		_coolant_flow_units_per_second * _tuning.cooling_capacity_per_flow_unit
	)


func _update_coolant_temperature(step_seconds: float) -> void:
	var cooling_deficit_ratio := _calculate_cooling_deficit_ratio()
	var target_temperature_c := (
		_tuning.nominal_coolant_temperature_c
		+ cooling_deficit_ratio * _tuning.temperature_rise_at_full_deficit_c
	)
	target_temperature_c = clampf(
		target_temperature_c,
		_tuning.minimum_coolant_temperature_c,
		_tuning.maximum_coolant_temperature_c
	)

	var response_rate_c_per_second := _tuning.coolant_cooling_rate_c_per_second
	if target_temperature_c > _coolant_temperature_c:
		response_rate_c_per_second = _tuning.coolant_heating_rate_c_per_second

	_coolant_temperature_c = move_toward(
		_coolant_temperature_c,
		target_temperature_c,
		response_rate_c_per_second * step_seconds
	)
	_coolant_temperature_c = clampf(
		_coolant_temperature_c,
		_tuning.minimum_coolant_temperature_c,
		_tuning.maximum_coolant_temperature_c
	)


func _update_plant_stress(step_seconds: float) -> void:
	var cooling_deficit_ratio := _calculate_cooling_deficit_ratio()
	var temperature_stress_ratio := clampf(
		inverse_lerp(
			_tuning.nominal_coolant_temperature_c,
			_tuning.maximum_coolant_temperature_c,
			_coolant_temperature_c
		),
		0.0,
		1.0
	)
	var target_stress := clampf(
		cooling_deficit_ratio * _tuning.cooling_deficit_stress_weight
		+ temperature_stress_ratio * _tuning.temperature_stress_weight,
		0.0,
		1.0
	)
	var response_rate_per_second := _tuning.stress_recovery_per_second
	if target_stress > _plant_stress:
		response_rate_per_second = _tuning.stress_rise_per_second

	_plant_stress = move_toward(
		_plant_stress,
		target_stress,
		response_rate_per_second * step_seconds
	)
	_plant_stress = clampf(_plant_stress, 0.0, 1.0)


func _update_downstream_output(step_seconds: float) -> void:
	var cooling_support := _calculate_cooling_support_ratio()
	var temperature_derate_ratio := clampf(
		inverse_lerp(
			_tuning.temperature_derate_start_c,
			_tuning.maximum_coolant_temperature_c,
			_coolant_temperature_c
		),
		0.0,
		1.0
	)
	var temperature_output_factor := lerpf(
		1.0,
		_tuning.minimum_temperature_output_factor,
		temperature_derate_ratio
	)
	var stress_output_factor := lerpf(
		1.0,
		_tuning.minimum_stress_output_factor,
		_plant_stress
	)
	var downstream_support := minf(
		cooling_support,
		minf(temperature_output_factor, stress_output_factor)
	)
	var target_steam_availability := _requested_load * downstream_support

	_steam_availability = move_toward(
		_steam_availability,
		target_steam_availability,
		_tuning.steam_response_per_second * step_seconds
	)
	_steam_availability = clampf(
		_steam_availability,
		0.0,
		_tuning.maximum_requested_load
	)

	_available_power_mw = _tuning.nominal_electrical_power_mw * _steam_availability
	var maximum_power_mw := (
		_tuning.nominal_electrical_power_mw * _tuning.maximum_requested_load
	)
	_actual_power_mw = move_toward(
		_actual_power_mw,
		_available_power_mw,
		_tuning.power_ramp_mw_per_second * step_seconds
	)
	_actual_power_mw = clampf(_actual_power_mw, 0.0, maximum_power_mw)


func _integrate_energy(step_seconds: float) -> void:
	var simulated_hours := step_seconds * _tuning.simulated_hours_per_real_second
	_produced_mwh += _actual_power_mw * simulated_hours


func _calculate_cooling_deficit_ratio() -> float:
	var deficit_units := maxf(0.0, _thermal_demand_units - _cooling_capacity_units)
	return clampf(deficit_units / _tuning.nominal_thermal_demand_units, 0.0, 1.0)


func _calculate_cooling_support_ratio() -> float:
	if is_zero_approx(_thermal_demand_units):
		return 1.0

	return clampf(_cooling_capacity_units / _thermal_demand_units, 0.0, 1.0)


func _find_pump(device_id: StringName) -> PumpState:
	if device_id == PUMP_A_ID:
		return _pump_a
	if device_id == PUMP_B_ID:
		return _pump_b

	return null
