extends SceneTree

const DEFAULT_TUNING := preload("res://data/plant/default_plant_tuning.tres")
const ABSOLUTE_TOLERANCE: float = 1.0e-7
const SOAK_TICKS: int = 100_000

var _passed_count: int = 0
var _failed_count: int = 0


func _initialize() -> void:
	print("[TEST] SHIFT №4 M1 headless plant simulation")

	_run_test("zero_load_produces_zero_power_and_energy", _test_zero_load)
	_run_test("higher_load_produces_higher_settled_power", _test_higher_load)
	_run_test("pump_flow_combines_enabled_available_pumps", _test_pump_flow)
	_run_test("pump_loss_causes_downstream_cascade", _test_pump_loss_cascade)
	_run_test("no_cooling_extreme_stays_bounded", _test_no_cooling_boundary)
	_run_test("mwh_uses_power_times_simulated_hours", _test_mwh_math)
	_run_test("deterministic_replay_matches_snapshot", _test_deterministic_replay)
	_run_test("requested_load_boundaries_are_clamped", _test_requested_load_boundaries)
	_run_test("long_soak_stays_finite_and_bounded", _test_long_soak)
	_run_test("clock_advances_only_fixed_steps", _test_fixed_step_clock)
	_run_test("reset_clears_clock_and_simulation", _test_reset)

	print("[TEST] SUMMARY passed=%d failed=%d" % [_passed_count, _failed_count])
	quit(0 if _failed_count == 0 else 1)


func _run_test(test_name: String, test_callable: Callable) -> void:
	var failure_message := str(test_callable.call())

	if failure_message.is_empty():
		_passed_count += 1
		print("[TEST] PASS %s" % test_name)
	else:
		_failed_count += 1
		printerr("[TEST] FAIL %s: %s" % [test_name, failure_message])


func _test_zero_load() -> String:
	var simulation := _create_simulation()
	var clock := SimulationClock.new(simulation)
	simulation.set_requested_load(0.0)
	clock.run_ticks(200)
	var snapshot := simulation.create_snapshot()

	if not _is_close(snapshot.actual_power_mw, 0.0):
		return "expected 0 MW, got %f" % snapshot.actual_power_mw
	if not _is_close(snapshot.produced_mwh, 0.0):
		return "expected 0 MWh, got %f" % snapshot.produced_mwh

	return ""


func _test_higher_load() -> String:
	var low_simulation := _create_simulation()
	var high_simulation := _create_simulation()
	var low_clock := SimulationClock.new(low_simulation)
	var high_clock := SimulationClock.new(high_simulation)
	low_simulation.set_requested_load(0.25)
	high_simulation.set_requested_load(0.75)
	low_clock.run_ticks(200)
	high_clock.run_ticks(200)
	var low_snapshot := low_simulation.create_snapshot()
	var high_snapshot := high_simulation.create_snapshot()
	var nominal_power := low_simulation.get_tuning().nominal_electrical_power_mw

	if not high_snapshot.actual_power_mw > low_snapshot.actual_power_mw:
		return "higher load did not produce higher settled power"
	if not _is_close(low_snapshot.actual_power_mw, nominal_power * 0.25):
		return "low-load power did not settle at its target"
	if not _is_close(high_snapshot.actual_power_mw, nominal_power * 0.75):
		return "high-load power did not settle at its target"

	return ""


func _test_mwh_math() -> String:
	var tuning := _create_tuning()
	tuning.nominal_electrical_power_mw = 100.0
	tuning.power_ramp_mw_per_second = 10000.0
	tuning.pump_flow_ramp_units_per_second_squared = 10000.0
	tuning.steam_response_per_second = 100.0
	tuning.simulated_hours_per_real_second = 0.01
	var simulation := PlantSimulation.new(tuning)
	var clock := SimulationClock.new(simulation)
	simulation.set_requested_load(1.0)
	clock.run_ticks(10)
	var snapshot := simulation.create_snapshot()
	var simulated_hours := tuning.simulation_step_seconds * tuning.simulated_hours_per_real_second * 10.0
	var expected_mwh := tuning.nominal_electrical_power_mw * simulated_hours

	if not _is_close(snapshot.actual_power_mw, tuning.nominal_electrical_power_mw):
		return "test setup did not reach nominal power"
	if not _is_close(snapshot.produced_mwh, expected_mwh):
		return "expected %f MWh, got %f" % [expected_mwh, snapshot.produced_mwh]

	return ""


func _test_deterministic_replay() -> String:
	var first_simulation := _create_simulation()
	var second_simulation := _create_simulation()
	var first_clock := SimulationClock.new(first_simulation)
	var second_clock := SimulationClock.new(second_simulation)
	var commands := {
		0: 0.2,
		25: 0.8,
		75: 0.35,
		120: 1.0,
		160: 0.0,
	}
	var pump_commands := {
		50: [&"P-B", false],
		90: [&"P-B", true],
		130: [&"P-A", false],
		175: [&"P-A", true],
	}

	for tick_index in range(220):
		if commands.has(tick_index):
			first_simulation.set_requested_load(commands[tick_index])
			second_simulation.set_requested_load(commands[tick_index])
		if pump_commands.has(tick_index):
			var pump_command: Array = pump_commands[tick_index]
			first_simulation.set_pump_enabled(pump_command[0], pump_command[1])
			second_simulation.set_pump_enabled(pump_command[0], pump_command[1])
		first_clock.step_once()
		second_clock.step_once()

	var first_snapshot := first_simulation.create_snapshot()
	var second_snapshot := second_simulation.create_snapshot()

	if not first_snapshot.is_equal_approx_to(second_snapshot, ABSOLUTE_TOLERANCE):
		return "identical command replays produced different snapshots"

	return ""


func _test_requested_load_boundaries() -> String:
	var simulation := _create_simulation()
	var clock := SimulationClock.new(simulation)
	var tuning := simulation.get_tuning()
	simulation.set_requested_load(-10.0)

	if not _is_close(simulation.create_snapshot().requested_load, tuning.minimum_requested_load):
		return "requested load was not clamped to its minimum"

	simulation.set_requested_load(10.0)
	clock.run_ticks(200)
	var snapshot := simulation.create_snapshot()
	var expected_maximum_power := tuning.nominal_electrical_power_mw * tuning.maximum_requested_load

	if not _is_close(snapshot.requested_load, tuning.maximum_requested_load):
		return "requested load was not clamped to its maximum"
	if snapshot.actual_power_mw < 0.0 or snapshot.actual_power_mw > expected_maximum_power:
		return "actual power escaped its explicit bounds"
	if not _is_close(snapshot.actual_power_mw, expected_maximum_power):
		return "maximum requested load did not settle at maximum supported power"

	return ""


func _test_long_soak() -> String:
	var configurations := [
		{"name": "both_pumps", "load": 1.0, "pump_a": true, "pump_b": true, "power": 1000.0},
		{"name": "single_pump", "load": 0.5, "pump_a": true, "pump_b": false, "power": 500.0},
		{"name": "no_cooling", "load": 1.0, "pump_a": false, "pump_b": false, "power": 0.0},
	]

	for configuration in configurations:
		var failure := _run_soak_configuration(configuration)
		if not failure.is_empty():
			return "%s: %s" % [configuration["name"], failure]

	return ""


func _test_fixed_step_clock() -> String:
	var simulation := _create_simulation()
	var clock := SimulationClock.new(simulation)
	simulation.set_requested_load(0.5)

	if clock.advance(0.04) != 0:
		return "clock stepped before one fixed interval accumulated"
	if clock.advance(0.06) != 1:
		return "clock did not step after one fixed interval accumulated"
	if clock.advance(0.35) != 3:
		return "clock did not execute the expected number of fixed steps"
	if simulation.create_snapshot().tick != 4:
		return "simulation tick count does not match clock steps"

	return ""


func _test_reset() -> String:
	var simulation := _create_simulation()
	var clock := SimulationClock.new(simulation)
	simulation.set_requested_load(1.0)
	clock.run_ticks(50)
	clock.reset()
	var snapshot := simulation.create_snapshot()

	if snapshot.tick != 0:
		return "reset did not clear tick"
	if not _is_close(snapshot.requested_load, simulation.get_tuning().minimum_requested_load):
		return "reset did not restore minimum requested load"
	if not _is_close(snapshot.actual_power_mw, 0.0):
		return "reset did not clear actual power"
	if not _is_close(snapshot.produced_mwh, 0.0):
		return "reset did not clear produced energy"
	if not _is_close(clock.get_pending_seconds(), 0.0):
		return "reset did not clear clock accumulator"
	if not snapshot.pump_a_enabled or not snapshot.pump_a_available:
		return "reset did not restore P-A command/availability defaults"
	if not snapshot.pump_b_enabled or not snapshot.pump_b_available:
		return "reset did not restore P-B command/availability defaults"
	if not _is_close(snapshot.coolant_flow_units_per_second, 0.0):
		return "reset did not clear coolant flow"
	if not _is_close(snapshot.coolant_temperature_c, simulation.get_tuning().nominal_coolant_temperature_c):
		return "reset did not restore nominal coolant temperature"
	if not _is_close(snapshot.plant_stress, 0.0):
		return "reset did not clear plant stress"

	return ""


func _test_pump_flow() -> String:
	var both_simulation := _create_simulation()
	var one_enabled_simulation := _create_simulation()
	var one_available_simulation := _create_simulation()
	var both_clock := SimulationClock.new(both_simulation)
	var one_enabled_clock := SimulationClock.new(one_enabled_simulation)
	var one_available_clock := SimulationClock.new(one_available_simulation)
	one_enabled_simulation.set_pump_enabled(&"P-B", false)
	one_available_simulation.set_pump_available(&"P-B", false)
	both_clock.run_ticks(100)
	one_enabled_clock.run_ticks(100)
	one_available_clock.run_ticks(100)
	var both_snapshot := both_simulation.create_snapshot()
	var one_enabled_snapshot := one_enabled_simulation.create_snapshot()
	var one_available_snapshot := one_available_simulation.create_snapshot()

	if both_snapshot.pump_a_device_id != &"P-A" or both_snapshot.pump_b_device_id != &"P-B":
		return "pump device IDs are not stable P-A/P-B"
	if not both_snapshot.coolant_flow_units_per_second > one_enabled_snapshot.coolant_flow_units_per_second:
		return "two enabled pumps did not provide more flow than one enabled pump"
	if not _is_close(
		one_enabled_snapshot.coolant_flow_units_per_second,
		one_available_snapshot.coolant_flow_units_per_second
	):
		return "disabled and unavailable P-B did not consistently remove its flow"
	if not _is_close(
		both_snapshot.coolant_flow_units_per_second,
		both_snapshot.pump_a_effective_flow_units_per_second
		+ both_snapshot.pump_b_effective_flow_units_per_second
	):
		return "total coolant flow is not the sum of pump effective flows"

	return ""


func _test_pump_loss_cascade() -> String:
	var simulation := _create_simulation()
	var clock := SimulationClock.new(simulation)
	simulation.set_requested_load(0.8)
	clock.run_ticks(200)
	var healthy_snapshot := simulation.create_snapshot()
	simulation.set_pump_enabled(&"P-B", false)
	clock.step_once()
	var immediate_snapshot := simulation.create_snapshot()

	if not immediate_snapshot.coolant_flow_units_per_second < healthy_snapshot.coolant_flow_units_per_second:
		return "P-B shutdown did not reduce coolant flow first"
	if not _is_close(immediate_snapshot.actual_power_mw, healthy_snapshot.actual_power_mw):
		return "P-B shutdown applied an immediate direct MW penalty despite sufficient cooling"

	clock.run_ticks(100)
	var degraded_snapshot := simulation.create_snapshot()

	if not degraded_snapshot.coolant_temperature_c > healthy_snapshot.coolant_temperature_c:
		return "reduced cooling did not raise coolant temperature"
	if not degraded_snapshot.plant_stress > healthy_snapshot.plant_stress:
		return "reduced cooling did not raise plant stress"
	if not degraded_snapshot.available_power_mw < healthy_snapshot.available_power_mw:
		return "cooling/temperature/stress did not reduce downstream available power"
	if not degraded_snapshot.actual_power_mw < healthy_snapshot.actual_power_mw:
		return "downstream limitation did not reduce actual electrical power"

	return ""


func _test_no_cooling_boundary() -> String:
	var simulation := _create_simulation()
	var clock := SimulationClock.new(simulation)
	simulation.set_pump_enabled(&"P-A", false)
	simulation.set_pump_enabled(&"P-B", false)
	simulation.set_requested_load(1.0)
	clock.run_ticks(2000)
	var snapshot := simulation.create_snapshot()
	var bounds_error := _snapshot_bounds_error(snapshot, simulation.get_tuning())

	if not bounds_error.is_empty():
		return bounds_error
	if not _is_close(snapshot.coolant_flow_units_per_second, 0.0):
		return "no-cooling scenario retained coolant flow"
	if not snapshot.coolant_temperature_c > simulation.get_tuning().nominal_coolant_temperature_c:
		return "no-cooling scenario did not increase coolant temperature"
	if not snapshot.plant_stress > 0.0:
		return "no-cooling scenario did not increase plant stress"
	if not _is_close(snapshot.actual_power_mw, 0.0):
		return "no-cooling scenario did not constrain electrical power to zero"
	if not _is_close(snapshot.produced_mwh, 0.0):
		return "zero-power no-cooling scenario accumulated MWh"

	return ""


func _run_soak_configuration(configuration: Dictionary) -> String:
	var tuning := _create_tuning()
	tuning.power_ramp_mw_per_second = 100000.0
	tuning.pump_flow_ramp_units_per_second_squared = 100000.0
	tuning.steam_response_per_second = 1000.0
	var simulation := PlantSimulation.new(tuning)
	var clock := SimulationClock.new(simulation)
	simulation.set_pump_enabled(&"P-A", configuration["pump_a"])
	simulation.set_pump_enabled(&"P-B", configuration["pump_b"])
	simulation.set_requested_load(configuration["load"])
	clock.run_ticks(SOAK_TICKS)
	var snapshot := simulation.create_snapshot()
	var bounds_error := _snapshot_bounds_error(snapshot, tuning)
	if not bounds_error.is_empty():
		return bounds_error

	var expected_power_mw: float = configuration["power"]
	if not _is_close(snapshot.actual_power_mw, expected_power_mw, 0.001):
		return "power drifted: expected %f, got %f" % [expected_power_mw, snapshot.actual_power_mw]
	var simulated_hours := (
		tuning.simulation_step_seconds
		* tuning.simulated_hours_per_real_second
		* float(SOAK_TICKS)
	)
	var expected_mwh := expected_power_mw * simulated_hours
	if not _is_close(snapshot.produced_mwh, expected_mwh, 0.01):
		return "energy drifted: expected %f, got %f" % [expected_mwh, snapshot.produced_mwh]

	return ""


func _snapshot_bounds_error(snapshot: PlantSnapshot, tuning: PlantTuning) -> String:
	var maximum_power_mw := tuning.nominal_electrical_power_mw * tuning.maximum_requested_load
	var maximum_flow := (
		tuning.pump_a_rated_flow_units_per_second * tuning.pump_a_efficiency
		+ tuning.pump_b_rated_flow_units_per_second * tuning.pump_b_efficiency
	)

	if not snapshot.has_finite_values():
		return "snapshot contains NaN or INF"
	if snapshot.actual_power_mw < 0.0 or snapshot.actual_power_mw > maximum_power_mw:
		return "actual power escaped configured bounds"
	if snapshot.available_power_mw < 0.0 or snapshot.available_power_mw > maximum_power_mw:
		return "available power escaped configured bounds"
	if snapshot.coolant_flow_units_per_second < 0.0 or snapshot.coolant_flow_units_per_second > maximum_flow:
		return "coolant flow escaped configured bounds"
	if snapshot.coolant_temperature_c < tuning.minimum_coolant_temperature_c or snapshot.coolant_temperature_c > tuning.maximum_coolant_temperature_c:
		return "coolant temperature escaped configured bounds"
	if snapshot.plant_stress < 0.0 or snapshot.plant_stress > 1.0:
		return "plant stress escaped normalized bounds"
	if snapshot.steam_availability < 0.0 or snapshot.steam_availability > tuning.maximum_requested_load:
		return "steam availability escaped configured bounds"
	if snapshot.produced_mwh < 0.0:
		return "produced MWh became negative"

	return ""


func _create_simulation() -> PlantSimulation:
	return PlantSimulation.new(_create_tuning())


func _create_tuning() -> PlantTuning:
	return DEFAULT_TUNING.duplicate(true) as PlantTuning


func _is_close(actual: float, expected: float, tolerance: float = ABSOLUTE_TOLERANCE) -> bool:
	return absf(actual - expected) <= tolerance
