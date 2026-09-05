class_name PlantSimulation
extends RefCounted

var _tuning: PlantTuning
var _equipment: EquipmentSystem
var _bearing_incident: BearingIncidentSystem
var _alarm_system: AlarmSystem

var _tick: int = 0
var _requested_load: float = 0.0
var _actual_power_mw: float = 0.0
var _generated_power_mw: float = 0.0
var _produced_mwh: float = 0.0
var _thermal_demand_units: float = 0.0
var _coolant_flow_units_per_second: float = 0.0
var _cooling_capacity_units: float = 0.0
var _coolant_temperature_c: float = 0.0
var _plant_stress: float = 0.0
var _system_stress: float = 0.0
var _steam_availability: float = 0.0
var _available_power_mw: float = 0.0


func _init(plant_tuning: PlantTuning) -> void:
	assert(plant_tuning != null, "PlantSimulation requires PlantTuning")
	var tuning_errors := plant_tuning.validation_errors()
	assert(tuning_errors.is_empty(), "PlantSimulation received invalid tuning: %s" % "; ".join(tuning_errors))
	_tuning = plant_tuning
	_equipment = EquipmentSystem.new(_tuning)
	_bearing_incident = BearingIncidentSystem.new(_tuning.bearing_failure_definition)
	_alarm_system = AlarmSystem.new(_tuning.get_alarm_rules())
	reset()


func set_requested_load(value: float) -> bool:
	if is_nan(value) or is_inf(value):
		push_error("requested_load must be finite")
		return false
	var clamped_value := clampf(value, _tuning.minimum_requested_load, _tuning.maximum_requested_load)
	if not is_equal_approx(value, clamped_value):
		push_warning("requested_load %f was clamped to the configured range as %f" % [value, clamped_value])
	_requested_load = clamped_value
	return true


func set_pump_enabled(device_id: StringName, enabled: bool) -> bool:
	var accepted := _equipment.set_pump_enabled(device_id, enabled)
	if not accepted:
		push_error("Unknown pump device_id: %s" % device_id)
	return accepted


func set_pump_available(device_id: StringName, available: bool) -> bool:
	var accepted := _equipment.set_pump_available(device_id, available)
	if not accepted:
		push_error("Unknown pump device_id: %s" % device_id)
	return accepted


func execute_command(target_device_id: StringName, action_id: StringName, parameters: Dictionary = {}) -> Dictionary:
	if target_device_id == EquipmentSystem.PUMP_B_ID and action_id == &"service_bearing":
		return _execute_bearing_service_command()
	if (
		target_device_id == EquipmentSystem.PUMP_B_ID
		and action_id == &"start"
		and _bearing_incident.service_active
	):
		return _command_result(false, target_device_id, action_id, "SERVICE_IN_PROGRESS")
	var result := _equipment.execute_command(target_device_id, action_id, parameters)
	if result["accepted"] and target_device_id == EquipmentSystem.BREAKER_A_ID:
		_actual_power_mw = _generated_power_mw if _equipment.breaker_a.is_closed() else 0.0
	return result


func acknowledge_alarm(alarm_instance_id: StringName) -> bool:
	return _alarm_system.acknowledge(alarm_instance_id)


func set_sensor_mode(sensor_id: StringName, mode: int, bias: float = 0.0, delay_ticks: int = 0) -> bool:
	return _equipment.set_sensor_mode(sensor_id, mode, bias, delay_ticks)


func debug_set_component_condition(device_id: StringName, condition: float) -> bool:
	if not _equipment.debug_set_component_condition(device_id, condition):
		return false
	_refresh_equipment_performance()
	return true


func debug_set_component_wear(device_id: StringName, wear: float) -> bool:
	if not _equipment.debug_set_component_wear(device_id, wear):
		return false
	_refresh_equipment_performance()
	return true


func debug_set_failure_phase(phase: int) -> bool:
	if not _bearing_incident.debug_set_phase(_equipment.pump_b, phase, _tick):
		return false
	_refresh_equipment_performance()
	return true


func debug_set_valve_mismatch(
	device_id: StringName,
	actual_position: float,
	reported_position: float
) -> bool:
	return _equipment.debug_set_valve_mismatch(device_id, actual_position, reported_position)


func debug_trip_breaker() -> void:
	_equipment.breaker_a.trip()
	_actual_power_mw = 0.0


func step(step_seconds: float) -> void:
	assert(
		is_equal_approx(step_seconds, _tuning.simulation_step_seconds),
		"PlantSimulation must be advanced with the configured fixed step"
	)
	_update_thermal_demand()
	_bearing_incident.update_service(_equipment.pump_b, step_seconds, _tick)
	_update_bearing_wear(step_seconds)
	_refresh_equipment_performance()
	_update_pump_flows(step_seconds)
	_update_cooling_state()
	_update_coolant_temperature(step_seconds)
	_update_plant_stress(step_seconds)
	_update_downstream_output(step_seconds)
	_update_sensors()
	_alarm_system.evaluate(_equipment.reported_sensor_values(), _tick)
	_integrate_energy(step_seconds)
	_tick += 1


func reset() -> void:
	_tick = 0
	_requested_load = _tuning.minimum_requested_load
	_actual_power_mw = 0.0
	_generated_power_mw = 0.0
	_produced_mwh = 0.0
	_thermal_demand_units = 0.0
	_coolant_flow_units_per_second = 0.0
	_cooling_capacity_units = 0.0
	_coolant_temperature_c = _tuning.nominal_coolant_temperature_c
	_plant_stress = 0.0
	_system_stress = 0.0
	_steam_availability = 0.0
	_available_power_mw = 0.0
	_equipment.reset(_tuning)
	_bearing_incident.reset()
	_alarm_system.reset()
	_refresh_equipment_performance()
	_update_sensors()


func create_snapshot() -> PlantSnapshot:
	return PlantSnapshot.new(
		_tick,
		_requested_load,
		_actual_power_mw,
		_generated_power_mw,
		_produced_mwh,
		_thermal_demand_units,
		_equipment.pump_a,
		_equipment.pump_b,
		_coolant_flow_units_per_second,
		_cooling_capacity_units,
		_coolant_temperature_c,
		_plant_stress,
		_steam_availability,
		_available_power_mw,
		_equipment.breaker_a.breaker_position,
		_equipment.component_snapshot(),
		_equipment.sensor_snapshot(),
		_bearing_incident.to_dictionary(),
		_alarm_system.get_history_snapshot()
	)


func create_operator_snapshot() -> Dictionary:
	return {
		"tick": _tick,
		"requested_load": _requested_load,
		"actual_power_mw": _actual_power_mw,
		"produced_mwh": _produced_mwh,
		"coolant_flow_units_per_second": _equipment.reported_coolant_flow(),
		"coolant_temperature_c": _equipment.reported_coolant_temperature(),
		"plant_stress": _plant_stress,
		"equipment": _equipment.operator_equipment_snapshot(),
		"reported_valve_positions": _equipment.reported_valve_positions(),
		"reported_sensors": _equipment.operator_sensor_snapshot(),
		"breaker_position": str(_equipment.breaker_a.breaker_position),
		"alarms": _alarm_system.get_history_snapshot(),
	}


func create_technician_device_view(device_id: StringName) -> Dictionary:
	var view := _equipment.world_device_view(device_id)
	if device_id == EquipmentSystem.PUMP_B_ID:
		view.merge(_bearing_incident.service_state_dictionary(), true)
	return view


func inspect_device(device_id: StringName) -> Dictionary:
	return _equipment.inspect_device(device_id)


func get_alarm_history() -> Array[Dictionary]:
	return _alarm_system.get_history_snapshot()


func get_tuning() -> PlantTuning:
	return _tuning


func get_device_ids() -> Array[StringName]:
	return EquipmentSystem.mvp_device_ids()


func _execute_bearing_service_command() -> Dictionary:
	var service_result := _bearing_incident.begin_service(_equipment.pump_b, _tick)
	return _command_result(
		service_result["accepted"],
		EquipmentSystem.PUMP_B_ID,
		&"service_bearing",
		service_result["reason"],
		_equipment.pump_b.revision,
		_bearing_incident.service_state_dictionary()
	)


func _command_result(
	accepted: bool,
	target_device_id: StringName,
	action_id: StringName,
	reason: String,
	revision: int = -1,
	result: Dictionary = {}
) -> Dictionary:
	return {
		"accepted": accepted,
		"target_device_id": str(target_device_id),
		"action_id": str(action_id),
		"reason": reason,
		"revision": revision,
		"result": result.duplicate(true),
	}


func _update_thermal_demand() -> void:
	_thermal_demand_units = _tuning.nominal_thermal_demand_units * _requested_load


func _update_bearing_wear(step_seconds: float) -> void:
	_bearing_incident.update_wear(
		_equipment.pump_b,
		_requested_load,
		_tuning.maximum_requested_load,
		_coolant_temperature_c,
		_tuning.nominal_coolant_temperature_c,
		_tuning.maximum_coolant_temperature_c,
		_plant_stress,
		step_seconds,
		_tuning.simulated_hours_per_real_second,
		_tick
	)


func _refresh_equipment_performance() -> void:
	_bearing_incident.refresh(
		_equipment.pump_b,
		_requested_load,
		_coolant_temperature_c,
		_tuning.nominal_coolant_temperature_c,
		_tick
	)
	_equipment.update_pump_performance(_bearing_incident.is_failed())


func _update_pump_flows(step_seconds: float) -> void:
	_equipment.update_pump_flows(step_seconds, _tuning.pump_flow_ramp_units_per_second_squared)


func _update_cooling_state() -> void:
	_coolant_flow_units_per_second = _equipment.actual_coolant_flow()
	_cooling_capacity_units = _coolant_flow_units_per_second * _tuning.cooling_capacity_per_flow_unit


func _update_coolant_temperature(step_seconds: float) -> void:
	var cooling_deficit_ratio := _calculate_cooling_deficit_ratio()
	var target_temperature_c := clampf(
		_tuning.nominal_coolant_temperature_c
		+ cooling_deficit_ratio * _tuning.temperature_rise_at_full_deficit_c,
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
	var load_stress := clampf(
		inverse_lerp(
			_tuning.bearing_failure_definition.normal_load_ratio,
			_tuning.maximum_requested_load,
			_requested_load
		),
		0.0,
		1.0
	) * _tuning.overload_plant_stress_weight
	var target_system_stress := clampf(
		cooling_deficit_ratio * _tuning.cooling_deficit_stress_weight
		+ temperature_stress_ratio * _tuning.temperature_stress_weight,
		0.0,
		1.0
	)
	var response_rate_per_second := _tuning.stress_recovery_per_second
	if target_system_stress > _system_stress:
		response_rate_per_second = _tuning.stress_rise_per_second
	_system_stress = move_toward(
		_system_stress,
		target_system_stress,
		response_rate_per_second * step_seconds
	)
	_system_stress = clampf(_system_stress, 0.0, 1.0)
	_plant_stress = clampf(_system_stress + load_stress, 0.0, 1.0)


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
		_system_stress
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
	var maximum_power_mw := _tuning.nominal_electrical_power_mw * _tuning.maximum_requested_load
	_generated_power_mw = move_toward(
		_generated_power_mw,
		_available_power_mw,
		_tuning.power_ramp_mw_per_second * step_seconds
	)
	_generated_power_mw = clampf(_generated_power_mw, 0.0, maximum_power_mw)
	_actual_power_mw = _generated_power_mw if _equipment.breaker_a.is_closed() else 0.0


func _update_sensors() -> void:
	_equipment.update_sensors(_coolant_flow_units_per_second, _coolant_temperature_c)


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
