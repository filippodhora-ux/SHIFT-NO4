class_name ComponentState
extends RefCounted

const STATE_OFF: StringName = &"OFF"
const STATE_RUNNING: StringName = &"RUNNING"
const STATE_DEGRADED: StringName = &"DEGRADED"
const STATE_FAILING: StringName = &"FAILING"
const STATE_FAILED: StringName = &"FAILED"

var device_id: StringName
var definition_id: StringName
var operational_state: StringName = STATE_OFF
var condition: float = 1.0
var wear: float = 0.0
var revision: int = 0


func _init(component_device_id: StringName, component_definition_id: StringName) -> void:
	assert(not component_device_id.is_empty(), "ComponentState requires device_id")
	assert(not component_definition_id.is_empty(), "ComponentState requires definition_id")
	device_id = component_device_id
	definition_id = component_definition_id


func set_condition(value: float) -> bool:
	if is_nan(value) or is_inf(value):
		return false

	var next_condition := clampf(value, 0.0, 1.0)
	var next_wear := 1.0 - next_condition
	if condition == next_condition and wear == next_wear:
		return true

	condition = next_condition
	wear = next_wear
	revision += 1
	return true


func set_wear(value: float) -> bool:
	if is_nan(value) or is_inf(value):
		return false
	return set_condition(1.0 - clampf(value, 0.0, 1.0))


func add_wear(wear_delta: float) -> bool:
	if is_nan(wear_delta) or is_inf(wear_delta) or wear_delta < 0.0:
		return false
	return set_wear(wear + wear_delta)


func set_operational_state(value: StringName) -> void:
	if operational_state == value:
		return
	operational_state = value
	revision += 1


func reset_component() -> void:
	condition = 1.0
	wear = 0.0
	operational_state = STATE_OFF
	revision = 0


func to_dictionary() -> Dictionary:
	return {
		"device_id": str(device_id),
		"definition_id": str(definition_id),
		"operational_state": str(operational_state),
		"condition": condition,
		"wear": wear,
		"revision": revision,
	}
