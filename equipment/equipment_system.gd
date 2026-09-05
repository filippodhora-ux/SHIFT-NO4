class_name EquipmentSystem
extends RefCounted

const PUMP_A_ID: StringName = &"P-A"
const PUMP_B_ID: StringName = &"P-B"
const VALVE_A_ID: StringName = &"V-A"
const VALVE_B_ID: StringName = &"V-B"
const BREAKER_A_ID: StringName = &"BR-A"
const LOCAL_GAUGE_ID: StringName = &"PG-A"
const COOLANT_LOOP_ID: StringName = &"COOLANT-LOOP"

const SENSOR_PUMP_B_VIBRATION: StringName = &"S-P-B-VIB"
const SENSOR_PUMP_B_TEMPERATURE: StringName = &"S-P-B-TEMP"
const SENSOR_PUMP_B_CURRENT: StringName = &"S-P-B-CURRENT"
const SENSOR_COOLANT_FLOW: StringName = &"S-COOLANT-FLOW"
const SENSOR_COOLANT_TEMPERATURE: StringName = &"S-COOLANT-TEMP"

var pump_a: PumpState
var pump_b: PumpState
var valve_a: ValveState
var valve_b: ValveState
var breaker_a: BreakerState

var _pump_b_vibration_sensor: SensorState
var _pump_b_temperature_sensor: SensorState
var _pump_b_current_sensor: SensorState
var _coolant_flow_sensor: SensorState
var _coolant_temperature_sensor: SensorState
var _local_gauge: SensorState
var _definitions_by_device_id: Dictionary = {}


func _init(tuning: PlantTuning) -> void:
	_definitions_by_device_id = {
		PUMP_A_ID: tuning.pump_a_definition,
		PUMP_B_ID: tuning.pump_b_definition,
		VALVE_A_ID: tuning.valve_a_definition,
		VALVE_B_ID: tuning.valve_b_definition,
		BREAKER_A_ID: tuning.breaker_a_definition,
		LOCAL_GAUGE_ID: tuning.local_gauge_definition,
	}
	pump_a = PumpState.new(
		PUMP_A_ID,
		tuning.pump_a_definition,
		tuning.pump_a_definition.enabled_on_reset,
		tuning.pump_a_definition.available_on_reset
	)
	pump_b = PumpState.new(
		PUMP_B_ID,
		tuning.pump_b_definition,
		tuning.pump_b_definition.enabled_on_reset,
		tuning.pump_b_definition.available_on_reset
	)
	valve_a = ValveState.new(VALVE_A_ID, tuning.valve_a_definition.definition_id)
	valve_b = ValveState.new(VALVE_B_ID, tuning.valve_b_definition.definition_id)
	breaker_a = BreakerState.new(BREAKER_A_ID, tuning.breaker_a_definition.definition_id)
	_pump_b_vibration_sensor = SensorState.new(SENSOR_PUMP_B_VIBRATION, PUMP_B_ID)
	_pump_b_temperature_sensor = SensorState.new(SENSOR_PUMP_B_TEMPERATURE, PUMP_B_ID)
	_pump_b_current_sensor = SensorState.new(SENSOR_PUMP_B_CURRENT, PUMP_B_ID)
	_coolant_flow_sensor = SensorState.new(SENSOR_COOLANT_FLOW, COOLANT_LOOP_ID)
	_coolant_temperature_sensor = SensorState.new(SENSOR_COOLANT_TEMPERATURE, COOLANT_LOOP_ID)
	_local_gauge = SensorState.new(
		LOCAL_GAUGE_ID,
		COOLANT_LOOP_ID,
		tuning.local_gauge_definition.definition_id
	)


func reset(tuning: PlantTuning) -> void:
	pump_a.reset(tuning.pump_a_definition.enabled_on_reset, tuning.pump_a_definition.available_on_reset)
	pump_b.reset(tuning.pump_b_definition.enabled_on_reset, tuning.pump_b_definition.available_on_reset)
	valve_a.reset_valve()
	valve_b.reset_valve()
	breaker_a.reset_breaker()
	for sensor in _numeric_sensors():
		sensor.reset_sensor()
	valve_a.position_sensor.reset_sensor(1.0)
	valve_b.position_sensor.reset_sensor(1.0)


func set_pump_enabled(device_id: StringName, enabled: bool) -> bool:
	var pump := find_pump(device_id)
	if pump == null:
		return false
	pump.set_enabled(enabled)
	return true


func set_pump_available(device_id: StringName, available: bool) -> bool:
	var pump := find_pump(device_id)
	if pump == null:
		return false
	pump.set_available(available)
	return true


func execute_command(target_device_id: StringName, action_id: StringName, parameters: Dictionary = {}) -> Dictionary:
	if target_device_id == PUMP_A_ID or target_device_id == PUMP_B_ID:
		return _execute_pump_command(target_device_id, action_id)
	if target_device_id == VALVE_A_ID or target_device_id == VALVE_B_ID:
		return _execute_valve_command(target_device_id, action_id, parameters)
	if target_device_id == BREAKER_A_ID:
		return _execute_breaker_command(action_id)
	if target_device_id == LOCAL_GAUGE_ID and action_id == &"inspect":
		return _command_result(true, target_device_id, action_id, "", -1, inspect_device(target_device_id))
	return _command_result(false, target_device_id, action_id, "UNKNOWN_TARGET")


func set_sensor_mode(sensor_id: StringName, mode: int, bias: float, delay_ticks: int) -> bool:
	var sensor := find_sensor(sensor_id)
	if sensor == null or mode < SensorState.Mode.NORMAL or mode > SensorState.Mode.DELAYED:
		return false
	return sensor.configure(mode as SensorState.Mode, bias, delay_ticks)


func debug_set_component_condition(device_id: StringName, condition: float) -> bool:
	var pump := find_pump(device_id)
	return pump != null and pump.set_condition(condition)


func debug_set_component_wear(device_id: StringName, wear: float) -> bool:
	var pump := find_pump(device_id)
	return pump != null and pump.set_wear(wear)


func debug_set_valve_mismatch(device_id: StringName, actual: float, reported: float) -> bool:
	var valve := find_valve(device_id)
	return valve != null and valve.debug_set_mismatch(actual, reported)


func update_pump_performance(pump_b_failed: bool) -> void:
	pump_a.update_performance()
	pump_b.update_performance()
	if pump_b_failed:
		pump_b.efficiency *= 0.05
		pump_b.set_operational_state(ComponentState.STATE_FAILED)


func update_pump_flows(step_seconds: float, ramp_units_per_second_squared: float) -> void:
	pump_a.update_flow(step_seconds, ramp_units_per_second_squared)
	pump_b.update_flow(step_seconds, ramp_units_per_second_squared)


func actual_coolant_flow() -> float:
	return (
		pump_a.effective_flow_units_per_second * valve_a.actual_position
		+ pump_b.effective_flow_units_per_second * valve_b.actual_position
	)


func update_sensors(coolant_flow: float, coolant_temperature_c: float) -> void:
	_pump_b_vibration_sensor.update(pump_b.vibration_units)
	_pump_b_temperature_sensor.update(pump_b.bearing_temperature_c)
	_pump_b_current_sensor.update(pump_b.current_proxy)
	_coolant_flow_sensor.update(coolant_flow)
	_coolant_temperature_sensor.update(coolant_temperature_c)
	_local_gauge.update(coolant_flow)
	valve_a.update_sensor()
	valve_b.update_sensor()


func inspect_device(device_id: StringName) -> Dictionary:
	if device_id == VALVE_A_ID or device_id == VALVE_B_ID:
		var valve := find_valve(device_id)
		return {
			"device_id": str(device_id),
			"display_name": display_name_for_device(device_id),
			"actual_position": valve.actual_position,
			"physical_state": _position_state(valve.actual_position),
			"inspection_text": "Handle indicates %s." % _position_state(valve.actual_position),
		}
	if device_id == BREAKER_A_ID:
		return {
			"device_id": str(device_id),
			"display_name": display_name_for_device(device_id),
			"physical_state": str(breaker_a.breaker_position),
			"inspection_text": "Physical indicator: %s." % breaker_a.breaker_position,
		}
	if device_id == LOCAL_GAUGE_ID:
		return {
			"device_id": str(LOCAL_GAUGE_ID),
			"display_name": display_name_for_device(device_id),
			"reported_flow_units_per_second": _local_gauge.reported_value,
			"inspection_text": "Local gauge reads %.1f flow units/s." % _local_gauge.reported_value,
		}
	if device_id == PUMP_A_ID or device_id == PUMP_B_ID:
		var pump := find_pump(device_id)
		var vibration := _qualitative_vibration(pump.vibration_units)
		var temperature := _qualitative_temperature(pump.bearing_temperature_c)
		return {
			"device_id": str(device_id),
			"display_name": display_name_for_device(device_id),
			"operational_state": str(pump.operational_state),
			"vibration": vibration,
			"temperature": temperature,
			"inspection_text": _pump_inspection_text(device_id, vibration, temperature, pump.enabled),
			"sound_caption": _pump_sound_caption(vibration, pump.enabled),
		}
	return {}


func world_device_view(device_id: StringName) -> Dictionary:
	if device_id == PUMP_A_ID or device_id == PUMP_B_ID:
		var pump := find_pump(device_id)
		var vibration := _qualitative_vibration(pump.vibration_units)
		return {
			"device_id": str(device_id),
			"display_name": display_name_for_device(device_id),
			"device_type": "PUMP",
			"operational_state": str(pump.operational_state),
			"enabled": pump.enabled,
			"vibration": vibration,
			"temperature": _qualitative_temperature(pump.bearing_temperature_c),
			"sound_caption": _pump_sound_caption(vibration, pump.enabled),
		}
	if device_id == VALVE_A_ID or device_id == VALVE_B_ID:
		var valve := find_valve(device_id)
		return {
			"device_id": str(device_id),
			"display_name": display_name_for_device(device_id),
			"device_type": "VALVE",
			"actual_position": valve.actual_position,
			"physical_state": _position_state(valve.actual_position),
		}
	if device_id == BREAKER_A_ID:
		return {
			"device_id": str(device_id),
			"display_name": display_name_for_device(device_id),
			"device_type": "BREAKER",
			"physical_state": str(breaker_a.breaker_position),
		}
	if device_id == LOCAL_GAUGE_ID:
		return {
			"device_id": str(device_id),
			"display_name": display_name_for_device(device_id),
			"device_type": "GAUGE",
			"local_reading": _local_gauge.reported_value,
			"physical_state": "READ LOCAL",
		}
	return {}


func operator_equipment_snapshot() -> Dictionary:
	return {
		str(PUMP_A_ID): {"device_id": str(PUMP_A_ID), "reported_status": str(pump_a.operational_state)},
		str(PUMP_B_ID): {"device_id": str(PUMP_B_ID), "reported_status": str(pump_b.operational_state)},
		str(VALVE_A_ID): {
			"device_id": str(VALVE_A_ID),
			"reported_position": valve_a.position_sensor.reported_value,
			"reported_position_state": _position_state(valve_a.position_sensor.reported_value),
		},
		str(VALVE_B_ID): {
			"device_id": str(VALVE_B_ID),
			"reported_position": valve_b.position_sensor.reported_value,
			"reported_position_state": _position_state(valve_b.position_sensor.reported_value),
		},
		str(BREAKER_A_ID): {"device_id": str(BREAKER_A_ID), "reported_status": str(breaker_a.breaker_position)},
	}


func operator_sensor_snapshot() -> Dictionary:
	return {
		str(SENSOR_COOLANT_FLOW): _coolant_flow_sensor.reported_value,
		str(SENSOR_COOLANT_TEMPERATURE): _coolant_temperature_sensor.reported_value,
	}


func reported_coolant_flow() -> float:
	return _coolant_flow_sensor.reported_value


func reported_coolant_temperature() -> float:
	return _coolant_temperature_sensor.reported_value


func display_name_for_device(device_id: StringName) -> String:
	var definition: ComponentDefinition = _definitions_by_device_id.get(device_id)
	return definition.display_name if definition != null else str(device_id)


static func mvp_device_ids() -> Array[StringName]:
	return [PUMP_A_ID, PUMP_B_ID, VALVE_A_ID, VALVE_B_ID, BREAKER_A_ID, LOCAL_GAUGE_ID]


func component_snapshot() -> Dictionary:
	return {
		str(PUMP_A_ID): pump_a.to_dictionary(),
		str(PUMP_B_ID): pump_b.to_dictionary(),
		str(VALVE_A_ID): valve_a.to_dictionary(),
		str(VALVE_B_ID): valve_b.to_dictionary(),
		str(BREAKER_A_ID): breaker_a.to_dictionary(),
		str(LOCAL_GAUGE_ID): _local_gauge.to_dictionary(),
	}


func sensor_snapshot() -> Dictionary:
	var result := {}
	for sensor in all_sensors():
		result[str(sensor.device_id)] = sensor.to_dictionary()
	return result


func reported_sensor_values() -> Dictionary:
	var result := {}
	for sensor in all_sensors():
		result[sensor.device_id] = sensor.reported_value
	return result


func reported_sensor_snapshot() -> Dictionary:
	var result := {}
	for sensor in all_sensors():
		result[str(sensor.device_id)] = sensor.reported_value
	return result


func reported_valve_positions() -> Dictionary:
	return {
		str(VALVE_A_ID): valve_a.position_sensor.reported_value,
		str(VALVE_B_ID): valve_b.position_sensor.reported_value,
	}


func all_sensors() -> Array[SensorState]:
	var result := _numeric_sensors()
	result.append(valve_a.position_sensor)
	result.append(valve_b.position_sensor)
	return result


func find_pump(device_id: StringName) -> PumpState:
	if device_id == PUMP_A_ID:
		return pump_a
	if device_id == PUMP_B_ID:
		return pump_b
	return null


func find_valve(device_id: StringName) -> ValveState:
	if device_id == VALVE_A_ID:
		return valve_a
	if device_id == VALVE_B_ID:
		return valve_b
	return null


func find_sensor(sensor_id: StringName) -> SensorState:
	for sensor in all_sensors():
		if sensor.device_id == sensor_id:
			return sensor
	return null


func _execute_pump_command(device_id: StringName, action_id: StringName) -> Dictionary:
	var pump := find_pump(device_id)
	match action_id:
		&"start":
			pump.set_enabled(true)
			return _command_result(true, device_id, action_id, "", pump.revision)
		&"stop":
			pump.set_enabled(false)
			return _command_result(true, device_id, action_id, "", pump.revision)
		&"inspect":
			return _command_result(true, device_id, action_id, "", pump.revision, inspect_device(device_id))
		_:
			return _command_result(false, device_id, action_id, "UNSUPPORTED_ACTION", pump.revision)


func _execute_valve_command(device_id: StringName, action_id: StringName, parameters: Dictionary) -> Dictionary:
	var valve := find_valve(device_id)
	if action_id == &"inspect":
		return _command_result(true, device_id, action_id, "", valve.revision, inspect_device(device_id))
	if action_id != &"set_position":
		return _command_result(false, device_id, action_id, "UNSUPPORTED_ACTION", valve.revision)
	if not parameters.has("position") or not (parameters["position"] is float or parameters["position"] is int):
		return _command_result(false, device_id, action_id, "INVALID_PARAMETERS", valve.revision)
	if not valve.set_position(float(parameters["position"])):
		return _command_result(false, device_id, action_id, "INVALID_PARAMETERS", valve.revision)
	return _command_result(true, device_id, action_id, "", valve.revision)


func _execute_breaker_command(action_id: StringName) -> Dictionary:
	match action_id:
		&"inspect":
			return _command_result(
				true,
				BREAKER_A_ID,
				action_id,
				"",
				breaker_a.revision,
				inspect_device(BREAKER_A_ID)
			)
		&"open":
			breaker_a.open()
		&"reset":
			breaker_a.reset_closed()
		_:
			return _command_result(false, BREAKER_A_ID, action_id, "UNSUPPORTED_ACTION", breaker_a.revision)
	return _command_result(true, BREAKER_A_ID, action_id, "", breaker_a.revision)


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


func _numeric_sensors() -> Array[SensorState]:
	return [
		_pump_b_vibration_sensor,
		_pump_b_temperature_sensor,
		_pump_b_current_sensor,
		_coolant_flow_sensor,
		_coolant_temperature_sensor,
		_local_gauge,
	]


func _qualitative_vibration(value: float) -> String:
	if value >= 0.8:
		return "SEVERE"
	if value >= 0.45:
		return "HIGH"
	if value >= 0.25:
		return "ROUGH"
	return "NORMAL"


func _qualitative_temperature(value: float) -> String:
	if value >= 95.0:
		return "VERY_HOT"
	if value >= 72.0:
		return "HOT"
	if value >= 58.0:
		return "WARM"
	return "NORMAL"


func _position_state(position: float) -> String:
	if position <= 0.05:
		return "CLOSED"
	if position >= 0.95:
		return "OPEN"
	return "PARTIAL %d%%" % roundi(position * 100.0)


func _pump_inspection_text(device_id: StringName, vibration: String, temperature: String, enabled: bool) -> String:
	if not enabled:
		return (
			"Pump is stopped. Housing is ready for local service."
			if device_id == PUMP_B_ID
			else "Pump is stopped. No operating vibration."
		)
	match vibration:
		"SEVERE":
			return "Severe vibration and abnormal noise. Housing feels %s." % temperature.to_lower()
		"HIGH":
			return "Strong vibration. Housing feels %s." % temperature.to_lower()
		"ROUGH":
			return "Slight vibration. Housing feels %s." % temperature.to_lower()
		_:
			return "Smooth operation. Housing temperature feels %s." % temperature.to_lower()


func _pump_sound_caption(vibration: String, enabled: bool) -> String:
	if not enabled:
		return "[pump silent]"
	match vibration:
		"SEVERE":
			return "[violent mechanical rattling]"
		"HIGH":
			return "[loud mechanical rattling]"
		"ROUGH":
			return "[uneven mechanical hum]"
		_:
			return "[steady mechanical hum]"
