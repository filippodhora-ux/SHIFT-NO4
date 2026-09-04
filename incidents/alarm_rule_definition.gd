class_name AlarmRuleDefinition
extends Resource

enum Direction {
	HIGH,
	LOW,
}

enum Priority {
	ADVISORY,
	WARNING,
	CRITICAL,
}

@export var alarm_rule_id: StringName = &""
@export var message_key: StringName = &""
@export var source_device_id: StringName = &""
@export var sensor_id: StringName = &""
@export var direction: Direction = Direction.HIGH
@export var priority: Priority = Priority.WARNING
@export var activate_threshold: float = 1.0
@export var clear_threshold: float = 0.9


func should_activate(value: float) -> bool:
	return value >= activate_threshold if direction == Direction.HIGH else value <= activate_threshold


func should_clear(value: float) -> bool:
	return value <= clear_threshold if direction == Direction.HIGH else value >= clear_threshold


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if alarm_rule_id.is_empty() or message_key.is_empty():
		errors.append("alarm rule IDs must not be empty")
	if source_device_id.is_empty() or sensor_id.is_empty():
		errors.append("alarm rule source and sensor IDs must not be empty")
	if is_nan(activate_threshold) or is_inf(activate_threshold) or is_nan(clear_threshold) or is_inf(clear_threshold):
		errors.append("alarm thresholds must be finite")
	elif direction == Direction.HIGH and clear_threshold >= activate_threshold:
		errors.append("high alarm clear threshold must be below activation")
	elif direction == Direction.LOW and clear_threshold <= activate_threshold:
		errors.append("low alarm clear threshold must be above activation")
	return errors
