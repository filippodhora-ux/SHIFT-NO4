class_name NetworkTuning
extends Resource

@export_range(1024, 65535, 1) var default_port: int = 7004
@export_range(0.05, 1.0, 0.01, "suffix:s") var snapshot_interval_seconds: float = 0.1
@export_range(1.0, 10.0, 0.1, "suffix:m/s") var technician_max_speed_meters_per_second: float = 5.0
@export_range(0.0, 2.0, 0.05, "suffix:m") var movement_tolerance_meters: float = 0.75
@export_range(1.0, 6.0, 0.05, "suffix:m") var interaction_range_meters: float = 3.75
@export_range(2.0, 20.0, 0.1, "suffix:m") var field_visibility_range_meters: float = 8.0
@export_range(5.0, 120.0, 1.0, "suffix:s") var end_shift_confirmation_seconds: float = 30.0
@export var technician_spawn_position: Vector3 = Vector3(0.0, 1.0, 7.0)
@export var movement_minimum_bounds: Vector3 = Vector3(-5.0, 0.0, -12.0)
@export var movement_maximum_bounds: Vector3 = Vector3(5.0, 2.5, 9.0)


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if default_port < 1024 or default_port > 65535:
		errors.append("default_port must be between 1024 and 65535")
	if snapshot_interval_seconds <= 0.0:
		errors.append("snapshot_interval_seconds must be positive")
	if technician_max_speed_meters_per_second <= 0.0:
		errors.append("technician_max_speed_meters_per_second must be positive")
	if interaction_range_meters <= 0.0:
		errors.append("interaction_range_meters must be positive")
	if field_visibility_range_meters < interaction_range_meters:
		errors.append("field_visibility_range_meters must cover interaction range")
	if end_shift_confirmation_seconds <= 0.0:
		errors.append("end_shift_confirmation_seconds must be positive")
	if movement_minimum_bounds.x >= movement_maximum_bounds.x:
		errors.append("movement x bounds are invalid")
	if movement_minimum_bounds.y >= movement_maximum_bounds.y:
		errors.append("movement y bounds are invalid")
	if movement_minimum_bounds.z >= movement_maximum_bounds.z:
		errors.append("movement z bounds are invalid")
	return errors
