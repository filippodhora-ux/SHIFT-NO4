class_name PumpState
extends ComponentState

var definition: PumpDefinition
var enabled: bool
var available: bool
var efficiency: float
var effective_flow_units_per_second: float = 0.0
var vibration_units: float = 0.0
var bearing_temperature_c: float = 0.0
var current_proxy: float = 0.0


func _init(
	pump_device_id: StringName,
	pump_definition: PumpDefinition,
	initial_enabled: bool,
	initial_available: bool
) -> void:
	assert(pump_definition != null, "PumpState requires PumpDefinition")
	super(pump_device_id, pump_definition.definition_id)
	definition = pump_definition
	reset(initial_enabled, initial_available)


func update_performance() -> void:
	efficiency = definition.efficiency_for_condition(condition)
	if condition <= 0.0:
		available = false
	set_operational_state(_derive_operational_state())


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	set_operational_state(_derive_operational_state())
	revision += 1


func set_available(value: bool) -> void:
	if available == value:
		return
	available = value
	set_operational_state(_derive_operational_state())
	revision += 1


func update_flow(step_seconds: float, flow_ramp_units_per_second_squared: float) -> void:
	var target_flow := 0.0
	if enabled and available:
		target_flow = definition.rated_flow_units_per_second * efficiency

	effective_flow_units_per_second = move_toward(
		effective_flow_units_per_second,
		target_flow,
		flow_ramp_units_per_second_squared * step_seconds
	)
	effective_flow_units_per_second = clampf(
		effective_flow_units_per_second,
		0.0,
		definition.rated_flow_units_per_second * efficiency
	)


func reset(initial_enabled: bool, initial_available: bool) -> void:
	reset_component()
	enabled = initial_enabled
	available = initial_available
	efficiency = definition.nominal_efficiency
	effective_flow_units_per_second = 0.0
	vibration_units = 0.0
	bearing_temperature_c = 0.0
	current_proxy = 0.0
	set_operational_state(_derive_operational_state())
	revision = 0


func to_dictionary() -> Dictionary:
	var result := super.to_dictionary()
	result.merge({
		"enabled": enabled,
		"available": available,
		"efficiency": efficiency,
		"effective_flow_units_per_second": effective_flow_units_per_second,
		"vibration_units": vibration_units,
		"bearing_temperature_c": bearing_temperature_c,
		"current_proxy": current_proxy,
	}, true)
	return result


func _derive_operational_state() -> StringName:
	if not enabled or not available:
		return STATE_OFF if condition > 0.0 else STATE_FAILED
	if condition <= 0.0:
		return STATE_FAILED
	if condition < definition.failing_below_condition:
		return STATE_FAILING
	if condition < definition.degraded_below_condition:
		return STATE_DEGRADED
	return STATE_RUNNING
