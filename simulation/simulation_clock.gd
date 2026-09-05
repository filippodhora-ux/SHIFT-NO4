class_name SimulationClock
extends RefCounted

const ACCUMULATOR_EPSILON_SECONDS: float = 1.0e-9

var _simulation: PlantSimulation
var _fixed_step_seconds: float
var _max_catch_up_steps: int
var _accumulator_seconds: float = 0.0


func _init(simulation: PlantSimulation) -> void:
	assert(simulation != null, "SimulationClock requires PlantSimulation")

	_simulation = simulation
	_fixed_step_seconds = simulation.get_tuning().simulation_step_seconds
	_max_catch_up_steps = simulation.get_tuning().max_catch_up_steps


func advance(real_delta_seconds: float, before_step: Callable = Callable()) -> int:
	if is_nan(real_delta_seconds) or is_inf(real_delta_seconds) or real_delta_seconds < 0.0:
		push_error("real_delta_seconds must be finite and non-negative")
		return 0

	_accumulator_seconds += real_delta_seconds
	var completed_steps := 0

	while (
		_accumulator_seconds + ACCUMULATOR_EPSILON_SECONDS >= _fixed_step_seconds
		and completed_steps < _max_catch_up_steps
	):
		if before_step.is_valid():
			before_step.call()
		step_once()
		_accumulator_seconds -= _fixed_step_seconds
		completed_steps += 1

	if absf(_accumulator_seconds) <= ACCUMULATOR_EPSILON_SECONDS:
		_accumulator_seconds = 0.0

	if _accumulator_seconds >= _fixed_step_seconds:
		push_warning("SimulationClock reached max_catch_up_steps; backlog is retained")

	return completed_steps


func step_once() -> void:
	_simulation.step(_fixed_step_seconds)


func run_ticks(tick_count: int) -> void:
	assert(tick_count >= 0, "tick_count must be non-negative")

	for _tick_index in range(tick_count):
		step_once()


func reset() -> void:
	_accumulator_seconds = 0.0
	_simulation.reset()


func get_pending_seconds() -> float:
	return _accumulator_seconds
