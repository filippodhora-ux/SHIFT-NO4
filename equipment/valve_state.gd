class_name ValveState
extends ComponentState

var actual_position: float = 1.0
var target_position: float = 1.0
var position_sensor: SensorState


func _init(valve_device_id: StringName, valve_definition_id: StringName) -> void:
	super(valve_device_id, valve_definition_id)
	position_sensor = SensorState.new(StringName("S-%s-POS" % valve_device_id), valve_device_id)
	reset_valve()


func set_position(value: float) -> bool:
	if is_nan(value) or is_inf(value):
		return false
	var clamped_position := clampf(value, 0.0, 1.0)
	target_position = clamped_position
	actual_position = clamped_position
	set_operational_state(STATE_RUNNING if actual_position > 0.0 else STATE_OFF)
	revision += 1
	return true


func update_sensor() -> void:
	position_sensor.update(actual_position)


func debug_set_mismatch(next_actual_position: float, next_reported_position: float) -> bool:
	if not set_position(next_actual_position):
		return false
	return position_sensor.debug_freeze_at(clampf(next_reported_position, 0.0, 1.0))


func reset_valve() -> void:
	actual_position = 1.0
	target_position = 1.0
	revision = 0
	operational_state = STATE_RUNNING
	position_sensor.reset_sensor(1.0)


func to_dictionary() -> Dictionary:
	var result := super.to_dictionary()
	result.merge({
		"actual_position": actual_position,
		"target_position": target_position,
		"reported_position": position_sensor.reported_value,
	}, true)
	return result
