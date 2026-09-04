class_name PumpDefinition
extends ComponentDefinition

@export_range(0.0, 1000.0, 0.1, "or_greater", "suffix:flow/s") var rated_flow_units_per_second: float = 60.0
@export_range(0.0, 1.0, 0.01) var nominal_efficiency: float = 1.0
@export_range(0.0, 1.0, 0.01) var minimum_condition_efficiency_factor: float = 0.05
@export_range(0.01, 8.0, 0.01, "or_greater") var condition_efficiency_exponent: float = 0.7
@export_range(0.0, 1.0, 0.01) var degraded_below_condition: float = 0.72
@export_range(0.0, 1.0, 0.01) var failing_below_condition: float = 0.32
@export var enabled_on_reset: bool = true
@export var available_on_reset: bool = true


func efficiency_for_condition(condition: float) -> float:
	var normalized_condition := clampf(condition, 0.0, 1.0)
	var condition_factor := lerpf(
		minimum_condition_efficiency_factor,
		1.0,
		pow(normalized_condition, condition_efficiency_exponent)
	)
	return nominal_efficiency * condition_factor


func validation_errors() -> PackedStringArray:
	var errors := super.validation_errors()

	if not _is_finite_non_negative(rated_flow_units_per_second):
		errors.append("rated_flow_units_per_second must be finite and non-negative")
	if not _is_normalized(nominal_efficiency):
		errors.append("nominal_efficiency must be finite and normalized")
	if not _is_normalized(minimum_condition_efficiency_factor):
		errors.append("minimum_condition_efficiency_factor must be finite and normalized")
	if not _is_finite_number(condition_efficiency_exponent) or condition_efficiency_exponent <= 0.0:
		errors.append("condition_efficiency_exponent must be finite and positive")
	if not (
		_is_normalized(degraded_below_condition)
		and _is_normalized(failing_below_condition)
		and failing_below_condition < degraded_below_condition
	):
		errors.append("pump operational condition thresholds must be ordered")

	return errors


func _is_normalized(value: float) -> bool:
	return _is_finite_number(value) and value >= 0.0 and value <= 1.0


func _is_finite_non_negative(value: float) -> bool:
	return _is_finite_number(value) and value >= 0.0


func _is_finite_number(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
