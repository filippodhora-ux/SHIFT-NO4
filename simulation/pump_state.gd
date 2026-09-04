class_name PumpState
extends RefCounted

var device_id: StringName
var enabled: bool
var available: bool
var rated_flow_units_per_second: float
var efficiency: float
var effective_flow_units_per_second: float = 0.0


func _init(
	pump_device_id: StringName,
	pump_rated_flow_units_per_second: float,
	pump_efficiency: float,
	initial_enabled: bool,
	initial_available: bool
) -> void:
	device_id = pump_device_id
	rated_flow_units_per_second = pump_rated_flow_units_per_second
	efficiency = pump_efficiency
	reset(initial_enabled, initial_available)


func update_flow(step_seconds: float, flow_ramp_units_per_second_squared: float) -> void:
	var target_flow := 0.0
	if enabled and available:
		target_flow = rated_flow_units_per_second * efficiency

	effective_flow_units_per_second = move_toward(
		effective_flow_units_per_second,
		target_flow,
		flow_ramp_units_per_second_squared * step_seconds
	)
	effective_flow_units_per_second = clampf(
		effective_flow_units_per_second,
		0.0,
		rated_flow_units_per_second * efficiency
	)


func reset(initial_enabled: bool, initial_available: bool) -> void:
	enabled = initial_enabled
	available = initial_available
	effective_flow_units_per_second = 0.0

