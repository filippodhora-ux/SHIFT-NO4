class_name BreakerState
extends ComponentState

const CLOSED: StringName = &"CLOSED"
const OPEN: StringName = &"OPEN"
const TRIPPED: StringName = &"TRIPPED"

var breaker_position: StringName = CLOSED


func _init(breaker_device_id: StringName, breaker_definition_id: StringName) -> void:
	super(breaker_device_id, breaker_definition_id)
	reset_breaker()


func open() -> void:
	_set_position(OPEN)


func trip() -> void:
	_set_position(TRIPPED)


func reset_closed() -> void:
	_set_position(CLOSED)


func is_closed() -> bool:
	return breaker_position == CLOSED


func reset_breaker() -> void:
	breaker_position = CLOSED
	operational_state = STATE_RUNNING
	revision = 0


func to_dictionary() -> Dictionary:
	var result := super.to_dictionary()
	result["breaker_position"] = str(breaker_position)
	result["connected"] = is_closed()
	return result


func _set_position(value: StringName) -> void:
	if breaker_position == value:
		return
	breaker_position = value
	set_operational_state(STATE_RUNNING if value == CLOSED else STATE_OFF)
	revision += 1
