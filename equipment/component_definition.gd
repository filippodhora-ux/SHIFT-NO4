class_name ComponentDefinition
extends Resource

@export var definition_id: StringName = &""
@export var display_name: String = ""
@export var component_type: StringName = &""


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if definition_id.is_empty():
		errors.append("definition_id must not be empty")
	if display_name.is_empty():
		errors.append("display_name must not be empty")
	if component_type.is_empty():
		errors.append("component_type must not be empty")

	return errors
