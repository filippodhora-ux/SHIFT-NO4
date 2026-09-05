extends SceneTree

const DEFAULT_TUNING := preload("res://data/plant/default_plant_tuning.tres")
const ABSOLUTE_TOLERANCE: float = 1.0e-7
const SOAK_TICKS: int = 100_000

var _passed_count: int = 0
var _failed_count: int = 0


func _initialize() -> void:
	print("[TEST] SHIFT №4 M3 local playable slice")

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
	_run_test("sensor_pipeline_supports_normal_biased_frozen_delayed", _test_sensor_modes)
	_run_test("overload_degrades_p_b_faster_than_normal", _test_overload_degradation)
	_run_test("p_b_condition_reduces_efficiency_and_flow", _test_condition_performance)
	_run_test("p_b_failure_timeline_has_ordered_phases_and_symptoms", _test_failure_timeline)
	_run_test("lying_valve_sensor_does_not_change_physical_flow", _test_lying_valve_sensor)
	_run_test("local_pg_a_can_disagree_with_central_telemetry", _test_local_gauge_divergence)
	_run_test("open_breaker_stops_export_not_internal_simulation", _test_breaker_disconnect)
	_run_test("alarm_acknowledge_keeps_active_cause", _test_alarm_acknowledge)
	_run_test("alarm_hysteresis_prevents_chatter", _test_alarm_hysteresis)
	_run_test("central_alarm_uses_reported_sensor_value", _test_alarm_uses_reported_value)
	_run_test("bearing_choices_have_distinct_consequences", _test_bearing_choices)
	_run_test("device_ids_and_commands_are_specific", _test_device_ids_and_commands)
	_run_test("m2_failure_soak_stays_finite_and_bounded", _test_m2_failure_soak)
	_run_test("operator_view_filters_hidden_authoritative_state", _test_operator_view_filter)
	_run_test("technician_view_filters_global_operator_state", _test_technician_view_filter)
	_run_test("role_views_split_global_and_local_bearing_symptoms", _test_role_specific_bearing_symptoms)
	_run_test("world_model_prompt_operator_and_debug_share_device_ids", _test_shared_device_ids)
	_run_test("technician_stop_updates_authority_flow_and_operator_view", _test_field_action_flow)
	_run_test("lying_sensor_splits_operator_report_and_technician_truth", _test_lying_sensor_role_split)
	_run_test("operator_acknowledge_keeps_physical_cause", _test_operator_view_model_acknowledge)
	_run_test("p_b_service_requires_stop_and_restores_performance", _test_service_prerequisites_and_result)

	print("[TEST] SUMMARY passed=%d failed=%d" % [_passed_count, _failed_count])
	quit(0 if _failed_count == 0 else 1)


func _run_test(test_name: String, test_callable: Callable) -> void:
	var raw_result: Variant = test_callable.call()
	var failure_message := ""
	if raw_result == null:
		failure_message = "test aborted without returning a String result"
	elif not raw_result is String:
		failure_message = "test returned unexpected type %s" % type_string(typeof(raw_result))
	else:
		failure_message = raw_result

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
		if tick_index == 35:
			first_simulation.execute_command(&"V-A", &"set_position", {"position": 0.6})
			second_simulation.execute_command(&"V-A", &"set_position", {"position": 0.6})
		if tick_index == 105:
			first_simulation.set_sensor_mode(&"S-COOLANT-FLOW", SensorState.Mode.DELAYED, 0.0, 4)
			second_simulation.set_sensor_mode(&"S-COOLANT-FLOW", SensorState.Mode.DELAYED, 0.0, 4)
		if tick_index == 145:
			first_simulation.execute_command(&"BR-A", &"open")
			second_simulation.execute_command(&"BR-A", &"open")
		if tick_index == 180:
			first_simulation.execute_command(&"BR-A", &"reset")
			second_simulation.execute_command(&"BR-A", &"reset")
		first_clock.step_once()
		second_clock.step_once()

	var first_snapshot := first_simulation.create_snapshot()
	var second_snapshot := second_simulation.create_snapshot()

	if not first_snapshot.is_equal_approx_to(second_snapshot, ABSOLUTE_TOLERANCE):
		return "identical command replays produced different snapshots"
	if first_snapshot.deterministic_hash() != second_snapshot.deterministic_hash():
		return "full M2 snapshot hashes differ"
	print("[METRIC] replay_hash=%s" % first_snapshot.deterministic_hash())

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


func _test_sensor_modes() -> String:
	var sensor := SensorState.new(&"S-TEST", &"TEST-SOURCE")
	sensor.update(10.0)
	if not _is_close(sensor.actual_value, 10.0) or not _is_close(sensor.reported_value, 10.0):
		return "NORMAL sensor did not report its measured value"

	sensor.configure(SensorState.Mode.BIASED, 2.5)
	sensor.update(10.0)
	if not _is_close(sensor.reported_value, 12.5):
		return "BIASED sensor did not apply deterministic bias"

	sensor.configure(SensorState.Mode.FROZEN)
	sensor.update(20.0)
	if not _is_close(sensor.actual_value, 20.0) or not _is_close(sensor.reported_value, 12.5):
		return "FROZEN sensor did not separate actual and reported values"

	sensor.configure(SensorState.Mode.DELAYED, 0.0, 2)
	sensor.update(1.0)
	sensor.update(2.0)
	sensor.update(3.0)
	if not _is_close(sensor.reported_value, 1.0):
		return "DELAYED sensor did not report the bounded two-tick history"

	return ""


func _test_overload_degradation() -> String:
	var normal_simulation := _create_simulation()
	var overload_simulation := _create_simulation()
	var normal_clock := SimulationClock.new(normal_simulation)
	var overload_clock := SimulationClock.new(overload_simulation)
	normal_simulation.set_requested_load(0.75)
	overload_simulation.set_requested_load(1.0)
	normal_clock.run_ticks(1500)
	overload_clock.run_ticks(1500)
	var normal_snapshot := normal_simulation.create_snapshot()
	var overload_snapshot := overload_simulation.create_snapshot()
	var normal_pump: Dictionary = normal_snapshot.components["P-B"]
	var overload_pump: Dictionary = overload_snapshot.components["P-B"]

	if not overload_snapshot.produced_mwh > normal_snapshot.produced_mwh:
		return "overload did not produce more short-term MWh"
	if not float(overload_pump["wear"]) > float(normal_pump["wear"]) * 3.0:
		return "overload wear was not meaningfully faster than normal wear"
	if not overload_snapshot.plant_stress > normal_snapshot.plant_stress:
		return "overload did not create more plant stress"

	var first_tick_simulation := _create_simulation()
	first_tick_simulation.set_requested_load(1.0)
	first_tick_simulation.step(first_tick_simulation.get_tuning().simulation_step_seconds)
	if first_tick_simulation.create_snapshot().bearing_failure["phase"] == "FAILED":
		return "bearing incident jumped from healthy to failed in one tick"
	print(
		"[METRIC] overload normal_mwh=%.3f overload_mwh=%.3f normal_wear=%.6f overload_wear=%.6f normal_stress=%.3f overload_stress=%.3f"
		% [
			normal_snapshot.produced_mwh,
			overload_snapshot.produced_mwh,
			float(normal_pump["wear"]),
			float(overload_pump["wear"]),
			normal_snapshot.plant_stress,
			overload_snapshot.plant_stress,
		]
	)

	return ""


func _test_condition_performance() -> String:
	var healthy_tuning := _create_tuning()
	var degraded_tuning := _create_tuning()
	healthy_tuning.bearing_failure_definition.base_wear_per_sim_hour = 0.0
	degraded_tuning.bearing_failure_definition.base_wear_per_sim_hour = 0.0
	var healthy_simulation := PlantSimulation.new(healthy_tuning)
	var degraded_simulation := PlantSimulation.new(degraded_tuning)
	healthy_simulation.set_requested_load(0.75)
	degraded_simulation.set_requested_load(0.75)
	degraded_simulation.debug_set_component_condition(&"P-B", 0.5)
	SimulationClock.new(healthy_simulation).run_ticks(100)
	SimulationClock.new(degraded_simulation).run_ticks(100)
	var healthy_pump: Dictionary = healthy_simulation.create_snapshot().components["P-B"]
	var degraded_pump: Dictionary = degraded_simulation.create_snapshot().components["P-B"]

	if not float(degraded_pump["efficiency"]) < float(healthy_pump["efficiency"]):
		return "lower condition did not reduce P-B efficiency"
	if not float(degraded_pump["effective_flow_units_per_second"]) < float(healthy_pump["effective_flow_units_per_second"]):
		return "lower condition did not reduce P-B effective flow"

	return ""


func _test_failure_timeline() -> String:
	var tuning := _create_tuning()
	tuning.bearing_failure_definition.base_wear_per_sim_hour = 0.12
	var simulation := PlantSimulation.new(tuning)
	var clock := SimulationClock.new(simulation)
	simulation.set_requested_load(1.0)
	clock.run_ticks(10)
	var seen_phases: Array[String] = []
	var phase_samples: Dictionary = {}
	var initial_snapshot := simulation.create_snapshot()
	seen_phases.append(initial_snapshot.bearing_failure["phase"])
	phase_samples[initial_snapshot.bearing_failure["phase"]] = initial_snapshot.to_dictionary()

	for _tick_index in range(5000):
		clock.step_once()
		var snapshot := simulation.create_snapshot()
		var phase: String = snapshot.bearing_failure["phase"]
		if phase != seen_phases.back():
			seen_phases.append(phase)
			phase_samples[phase] = snapshot.to_dictionary()
		if phase == "FAILED":
			break

	var expected_phases: Array[String] = ["HEALTHY", "LATENT", "WORN", "DEGRADED", "FAILING", "FAILED"]
	if seen_phases != expected_phases:
		return "unexpected phase timeline: %s" % seen_phases

	var healthy_pump: Dictionary = phase_samples["HEALTHY"]["components"]["P-B"]
	var worn_pump: Dictionary = phase_samples["WORN"]["components"]["P-B"]
	var degraded_pump: Dictionary = phase_samples["DEGRADED"]["components"]["P-B"]
	var failing_snapshot: Dictionary = phase_samples["FAILING"]
	if not float(worn_pump["vibration_units"]) > float(healthy_pump["vibration_units"]):
		return "mechanical vibration did not rise across the failure timeline"
	if not float(worn_pump["bearing_temperature_c"]) > float(healthy_pump["bearing_temperature_c"]):
		return "bearing temperature did not rise across the failure timeline"
	if not float(degraded_pump["efficiency"]) < float(worn_pump["efficiency"]):
		return "efficiency did not decline across failure phases"
	if not float(degraded_pump["effective_flow_units_per_second"]) < float(worn_pump["effective_flow_units_per_second"]):
		return "effective flow did not decline across failure phases"
	if not float(failing_snapshot["plant_stress"]) > float(phase_samples["HEALTHY"]["plant_stress"]):
		return "system stress did not emerge by FAILING phase"
	var phase_ticks: Array[String] = []
	for phase in expected_phases:
		phase_ticks.append("%s@%d" % [phase, phase_samples[phase]["tick"]])
	print("[METRIC] bearing_timeline %s" % ", ".join(phase_ticks))

	return ""


func _test_lying_valve_sensor() -> String:
	var tuning := _create_tuning()
	tuning.bearing_failure_definition.base_wear_per_sim_hour = 0.0
	var simulation := PlantSimulation.new(tuning)
	var clock := SimulationClock.new(simulation)
	simulation.set_requested_load(0.8)
	clock.run_ticks(100)
	var open_flow := simulation.create_snapshot().coolant_flow_units_per_second
	if not simulation.debug_set_valve_mismatch(&"V-A", 0.0, 1.0):
		return "debug mismatch command was rejected"
	clock.run_ticks(100)
	var snapshot := simulation.create_snapshot()
	var operator_snapshot := simulation.create_operator_snapshot()
	var inspection := simulation.inspect_device(&"V-A")

	if not snapshot.coolant_flow_units_per_second < open_flow * 0.75:
		return "physical flow did not use V-A actual CLOSED position"
	if not _is_close(operator_snapshot["reported_valve_positions"]["V-A"], 1.0):
		return "operator report did not retain reported OPEN position"
	if not _is_close(inspection["actual_position"], 0.0):
		return "local inspection did not expose actual CLOSED position"

	return ""


func _test_local_gauge_divergence() -> String:
	var simulation := _create_simulation()
	var clock := SimulationClock.new(simulation)
	simulation.set_requested_load(0.75)
	if not simulation.set_sensor_mode(&"S-COOLANT-FLOW", SensorState.Mode.BIASED, 10.0):
		return "central flow sensor mode was rejected"
	clock.run_ticks(20)
	var snapshot := simulation.create_snapshot()
	var central_report: float = simulation.create_operator_snapshot()["reported_sensors"]["S-COOLANT-FLOW"]
	var local_report: float = simulation.inspect_device(&"PG-A")["reported_flow_units_per_second"]

	if not _is_close(central_report, snapshot.coolant_flow_units_per_second + 10.0):
		return "central bias did not derive from actual flow"
	if not _is_close(local_report, snapshot.coolant_flow_units_per_second):
		return "PG-A did not independently report local actual flow"
	if _is_close(central_report, local_report):
		return "central and local sensor pipelines could not disagree"

	return ""


func _test_breaker_disconnect() -> String:
	var simulation := _create_simulation()
	var clock := SimulationClock.new(simulation)
	simulation.set_requested_load(0.75)
	clock.run_ticks(200)
	var before := simulation.create_snapshot()
	var command := simulation.execute_command(&"BR-A", &"open")
	if not command["accepted"]:
		return "BR-A open command was rejected"
	clock.run_ticks(100)
	var after := simulation.create_snapshot()

	if not _is_close(after.actual_power_mw, 0.0):
		return "open BR-A did not zero exported MW"
	if not _is_close(after.produced_mwh, before.produced_mwh):
		return "MWh increased while BR-A was open"
	if not after.generated_power_mw > 0.0 or not after.coolant_flow_units_per_second > 0.0:
		return "internal plant simulation stopped with the output breaker"
	if after.tick != before.tick + 100:
		return "authoritative simulation tick stopped with the output breaker"

	return ""


func _test_alarm_acknowledge() -> String:
	var simulation := _create_simulation()
	simulation.debug_set_component_condition(&"P-B", 0.5)
	simulation.set_requested_load(1.0)
	SimulationClock.new(simulation).run_ticks(10)
	var before := simulation.create_snapshot()
	var alarm := _find_alarm(before.alarms, "P-B-CURRENT-HIGH", true)
	if alarm.is_empty():
		return "degraded P-B did not activate symptomatic current alarm"
	for alarm_snapshot in before.alarms:
		if "BEARING" in String(alarm_snapshot["message_key"]):
			return "alarm revealed the hidden bearing diagnosis"
	var condition_before: float = before.components["P-B"]["condition"]
	if not simulation.acknowledge_alarm(StringName(alarm["alarm_instance_id"])):
		return "active alarm acknowledge was rejected"
	var after := simulation.create_snapshot()
	var acknowledged_alarm := _find_alarm(after.alarms, "P-B-CURRENT-HIGH", true)

	if acknowledged_alarm.is_empty() or not acknowledged_alarm["acknowledged"]:
		return "acknowledge did not update alarm state"
	if not acknowledged_alarm["active"]:
		return "acknowledge incorrectly cleared an active symptom"
	if not _is_close(after.components["P-B"]["condition"], condition_before):
		return "acknowledge changed the physical bearing cause"

	return ""


func _test_alarm_hysteresis() -> String:
	var rule := _create_tuning().pump_current_alarm_rule
	var rules: Array[AlarmRuleDefinition] = [rule]
	var alarm_system := AlarmSystem.new(rules)
	alarm_system.evaluate({rule.sensor_id: 1.01}, 1)
	alarm_system.evaluate({rule.sensor_id: 0.98}, 2)
	alarm_system.evaluate({rule.sensor_id: 1.02}, 3)
	var history := alarm_system.get_history_snapshot()
	if history.size() != 1 or not history[0]["active"]:
		return "alarm chattered while value remained inside hysteresis band"
	alarm_system.evaluate({rule.sensor_id: 0.89}, 4)
	alarm_system.evaluate({rule.sensor_id: 0.95}, 5)
	if alarm_system.get_history_snapshot().size() != 1:
		return "cleared alarm reactivated below activation threshold"
	alarm_system.evaluate({rule.sensor_id: 1.01}, 6)
	if alarm_system.get_history_snapshot().size() != 2:
		return "alarm did not create a new instance after a real clear and crossing"

	return ""


func _test_alarm_uses_reported_value() -> String:
	var simulation := _create_simulation()
	simulation.set_sensor_mode(&"S-P-B-CURRENT", SensorState.Mode.FROZEN)
	simulation.debug_set_component_condition(&"P-B", 0.4)
	simulation.set_requested_load(1.0)
	SimulationClock.new(simulation).run_ticks(20)
	var snapshot := simulation.create_snapshot()
	var current_sensor: Dictionary = snapshot.sensors["S-P-B-CURRENT"]

	if not float(current_sensor["actual_value"]) > simulation.get_tuning().pump_current_alarm_rule.activate_threshold:
		return "test setup did not create high actual P-B current"
	if not float(current_sensor["reported_value"]) < simulation.get_tuning().pump_current_alarm_rule.clear_threshold:
		return "frozen report did not remain below the current alarm threshold"
	if not _find_alarm(snapshot.alarms, "P-B-CURRENT-HIGH", false).is_empty():
		return "central alarm used actual value instead of reported telemetry"

	return ""


func _test_bearing_choices() -> String:
	var reduce := _run_bearing_choice("reduce")
	var switch_pump := _run_bearing_choice("switch")
	var continue_risk := _run_bearing_choice("continue")
	var reduce_pump: Dictionary = reduce.components["P-B"]
	var switch_pump_state: Dictionary = switch_pump.components["P-B"]
	var continue_pump: Dictionary = continue_risk.components["P-B"]

	if not continue_risk.produced_mwh > reduce.produced_mwh:
		return "continue/risk did not trade more short-term MWh for damage"
	if not float(continue_pump["wear"]) > float(reduce_pump["wear"]):
		return "continue/risk did not create more P-B wear than reduced load"
	if not float(reduce_pump["wear"]) > float(switch_pump_state["wear"]):
		return "switching off P-B did not slow its operating wear"
	if not reduce.plant_stress < continue_risk.plant_stress:
		return "reduced load did not lower plant stress"
	if _is_close(switch_pump.coolant_flow_units_per_second, continue_risk.coolant_flow_units_per_second, 0.01):
		return "switch-pump and continue branches ended with the same flow"
	print(
		"[METRIC] choices reduce={mwh=%.3f wear=%.6f stress=%.3f flow=%.3f} switch={mwh=%.3f wear=%.6f stress=%.3f flow=%.3f} continue={mwh=%.3f wear=%.6f stress=%.3f flow=%.3f}"
		% [
			reduce.produced_mwh,
			float(reduce_pump["wear"]),
			reduce.plant_stress,
			reduce.coolant_flow_units_per_second,
			switch_pump.produced_mwh,
			float(switch_pump_state["wear"]),
			switch_pump.plant_stress,
			switch_pump.coolant_flow_units_per_second,
			continue_risk.produced_mwh,
			float(continue_pump["wear"]),
			continue_risk.plant_stress,
			continue_risk.coolant_flow_units_per_second,
		]
	)

	return ""


func _test_device_ids_and_commands() -> String:
	var simulation := _create_simulation()
	var expected_ids: Array[String] = ["P-A", "P-B", "V-A", "V-B", "BR-A", "PG-A"]
	var snapshot := simulation.create_snapshot()
	for device_id in expected_ids:
		if not snapshot.components.has(device_id):
			return "authoritative snapshot is missing stable device ID %s" % device_id
		if snapshot.components[device_id]["device_id"] != device_id:
			return "component snapshot changed stable device ID %s" % device_id

	if not simulation.execute_command(&"P-B", &"stop")["accepted"]:
		return "device-specific P-B stop command failed"
	if not simulation.execute_command(&"P-B", &"start")["accepted"]:
		return "device-specific P-B start command failed"
	if not simulation.execute_command(&"P-B", &"inspect")["accepted"]:
		return "device-specific P-B inspect command failed"
	if not simulation.execute_command(&"V-B", &"set_position", {"position": 0.4})["accepted"]:
		return "device-specific V-B position command failed"
	if not simulation.execute_command(&"BR-A", &"open")["accepted"]:
		return "device-specific BR-A open command failed"
	if not simulation.execute_command(&"BR-A", &"reset")["accepted"]:
		return "device-specific BR-A reset command failed"
	if simulation.execute_command(&"P-B", &"repair")["accepted"]:
		return "generic repair action was incorrectly accepted"
	if not simulation.debug_set_component_condition(&"P-A", 0.8):
		return "debug condition path did not support P-A"
	if not simulation.debug_set_component_wear(&"P-A", 0.1):
		return "debug wear path did not support P-A"

	simulation.debug_set_component_condition(&"P-B", 0.4)
	simulation.set_requested_load(1.0)
	SimulationClock.new(simulation).run_ticks(20)
	var updated := simulation.create_snapshot()
	if not simulation.create_operator_snapshot()["reported_valve_positions"].has("V-A"):
		return "operator report did not retain stable V-A ID"
	for alarm in updated.alarms:
		if String(alarm["alarm_rule_id"]).begins_with("P-B-") and alarm["source_device_id"] != "P-B":
			return "P-B alarm did not retain stable source device ID"

	return ""


func _test_m2_failure_soak() -> String:
	var simulation := _create_simulation()
	var clock := SimulationClock.new(simulation)
	simulation.set_requested_load(1.0)
	clock.run_ticks(SOAK_TICKS)
	var snapshot := simulation.create_snapshot()
	var bounds_error := _snapshot_bounds_error(snapshot, simulation.get_tuning())
	if not bounds_error.is_empty():
		return bounds_error
	if snapshot.bearing_failure["phase"] != "FAILED":
		return "overload soak did not reach the causal terminal bearing phase"
	if not snapshot.components["P-B"]["wear"] <= 1.0:
		return "P-B wear escaped normalized bounds"

	return ""


func _test_operator_view_filter() -> String:
	var simulation := _create_simulation()
	simulation.debug_set_component_condition(&"P-B", 0.42)
	simulation.set_requested_load(1.0)
	SimulationClock.new(simulation).run_ticks(20)
	var view_model := OperatorViewModel.new(simulation)
	view_model.refresh()
	var view := view_model.get_view()
	var forbidden_keys: Array[String] = [
		"condition",
		"wear",
		"failure_id",
		"phase",
		"severity",
		"actual_value",
		"actual_position",
		"local_reading",
		"service_active",
	]
	var leaked_key := _find_forbidden_key(view, forbidden_keys)
	if not leaked_key.is_empty():
		return "operator view leaked forbidden key %s" % leaked_key
	if not view.has("coolant_flow_units_per_second") or not view.has("equipment") or not view.has("alarms"):
		return "operator view is missing allowed global telemetry"
	if view["reported_sensors"].has("PG-A"):
		return "operator view leaked the Technician-only local PG-A channel"
	return ""


func _test_technician_view_filter() -> String:
	var simulation := _create_simulation()
	var view_model := TechnicianViewModel.new(simulation)
	var combined_views: Array = [view_model.create_hud_view()]
	for device_id in simulation.get_device_ids():
		combined_views.append(view_model.get_focus_view(device_id))
	var forbidden_keys: Array[String] = [
		"requested_load",
		"actual_power_mw",
		"produced_mwh",
		"plant_stress",
		"alarms",
		"quota",
		"condition",
		"wear",
		"failure_id",
		"phase",
	]
	var leaked_key := _find_forbidden_key(combined_views, forbidden_keys)
	if not leaked_key.is_empty():
		return "technician HUD/focus view leaked forbidden key %s" % leaked_key
	if view_model.get_focus_view(&"P-B")["device_id"] != "P-B":
		return "technician focus did not retain stable P-B ID"
	return ""


func _test_role_specific_bearing_symptoms() -> String:
	var simulation := _create_simulation()
	simulation.debug_set_component_condition(&"P-B", 0.4)
	simulation.set_requested_load(1.0)
	SimulationClock.new(simulation).run_ticks(20)
	var operator_view_model := OperatorViewModel.new(simulation)
	operator_view_model.refresh()
	var operator_view := operator_view_model.get_view()
	var symptom_alarm := _find_alarm(operator_view["alarms"], "P-B-CURRENT-HIGH", true)
	if symptom_alarm.is_empty():
		return "operator did not receive the global P-B current symptom"
	var technician_view_model := TechnicianViewModel.new(simulation)
	var inspection := technician_view_model.perform_action(&"P-B", &"inspect")
	var local_text := String(inspection["feedback"])
	if "vibration" not in local_text.to_lower() and "mechanical" not in local_text.to_lower():
		return "technician inspection did not add a local mechanical symptom"
	if "BEARING" in String(symptom_alarm["message_key"]):
		return "operator alarm diagnosed the hidden bearing cause"
	return ""


func _test_shared_device_ids() -> String:
	var simulation := _create_simulation()
	var expected_ids: Array[String] = []
	for device_id in simulation.get_device_ids():
		expected_ids.append(str(device_id))
	expected_ids.sort()

	var level_scene := load("res://levels/local_slice.tscn") as PackedScene
	if level_scene == null:
		return "local slice scene could not be loaded"
	var level := level_scene.instantiate()
	var presenter_ids: Array[String] = []
	_collect_presenter_ids(level, presenter_ids)
	level.free()
	presenter_ids.sort()
	if presenter_ids != expected_ids:
		return "world presenter IDs %s did not match model IDs %s" % [presenter_ids, expected_ids]

	var snapshot := simulation.create_snapshot()
	var technician_view_model := TechnicianViewModel.new(simulation)
	for device_id in expected_ids:
		if not snapshot.components.has(device_id):
			return "debug snapshot is missing %s" % device_id
		var prompt := technician_view_model.get_focus_view(StringName(device_id))
		if prompt.is_empty() or prompt["device_id"] != device_id:
			return "interaction prompt changed device ID %s" % device_id
	var operator_equipment: Dictionary = simulation.create_operator_snapshot()["equipment"]
	for operator_device_id in ["P-A", "P-B", "V-A", "V-B", "BR-A"]:
		if not operator_equipment.has(operator_device_id):
			return "operator telemetry is missing relevant ID %s" % operator_device_id
	return ""


func _test_field_action_flow() -> String:
	var simulation := _create_simulation()
	var clock := SimulationClock.new(simulation)
	simulation.set_requested_load(0.8)
	clock.run_ticks(120)
	var operator_view_model := OperatorViewModel.new(simulation)
	operator_view_model.refresh()
	var flow_before: float = operator_view_model.get_view()["coolant_flow_units_per_second"]
	var technician_view_model := TechnicianViewModel.new(simulation)
	var command := technician_view_model.perform_action(&"P-B", &"stop")
	if not command["accepted"]:
		return "technician P-B stop command was rejected"
	clock.run_ticks(100)
	operator_view_model.refresh()
	var snapshot := simulation.create_snapshot()
	var flow_after: float = operator_view_model.get_view()["coolant_flow_units_per_second"]
	if snapshot.components["P-B"]["enabled"]:
		return "field command did not change authoritative P-B state"
	if not flow_after < flow_before * 0.75:
		return "P-B stop did not propagate through flow to operator telemetry"
	if not snapshot.tick == 220:
		return "field action used a different or reset simulation"
	return ""


func _test_lying_sensor_role_split() -> String:
	var simulation := _create_simulation()
	if not simulation.debug_set_valve_mismatch(&"V-A", 0.0, 1.0):
		return "V-A mismatch setup was rejected"
	SimulationClock.new(simulation).run_ticks(2)
	var operator_view_model := OperatorViewModel.new(simulation)
	operator_view_model.refresh()
	var operator_valve: Dictionary = operator_view_model.get_view()["equipment"]["V-A"]
	var technician_view_model := TechnicianViewModel.new(simulation)
	var inspection := technician_view_model.perform_action(&"V-A", &"inspect")
	if operator_valve["reported_position_state"] != "OPEN":
		return "operator did not see the frozen reported OPEN state"
	if inspection["result"]["physical_state"] != "CLOSED":
		return "technician did not see the physical CLOSED state"
	if _find_forbidden_key(operator_view_model.get_view(), ["actual_position"]) != "":
		return "operator could directly reveal the actual valve position"
	return ""


func _test_operator_view_model_acknowledge() -> String:
	var simulation := _create_simulation()
	simulation.debug_set_component_condition(&"P-B", 0.4)
	simulation.set_requested_load(1.0)
	SimulationClock.new(simulation).run_ticks(20)
	var view_model := OperatorViewModel.new(simulation)
	view_model.refresh()
	var alarm := _find_alarm(view_model.get_view()["alarms"], "P-B-CURRENT-HIGH", true)
	if alarm.is_empty():
		return "test setup did not activate a P-B symptom alarm"
	var condition_before: float = simulation.create_snapshot().components["P-B"]["condition"]
	if not view_model.request_acknowledge(StringName(alarm["alarm_instance_id"])):
		return "operator view model acknowledge was rejected"
	view_model.refresh()
	var acknowledged := _find_alarm(view_model.get_view()["alarms"], "P-B-CURRENT-HIGH", true)
	if acknowledged.is_empty() or not acknowledged["acknowledged"]:
		return "operator view did not update acknowledge state"
	if not _is_close(simulation.create_snapshot().components["P-B"]["condition"], condition_before):
		return "operator acknowledge changed physical P-B condition"
	return ""


func _test_service_prerequisites_and_result() -> String:
	var simulation := _create_simulation()
	var clock := SimulationClock.new(simulation)
	simulation.debug_set_component_condition(&"P-B", 0.4)
	simulation.set_requested_load(0.7)
	clock.run_ticks(40)
	var degraded_flow: float = simulation.create_snapshot().components["P-B"]["effective_flow_units_per_second"]
	var technician_view_model := TechnicianViewModel.new(simulation)
	var rejected := technician_view_model.perform_action(&"P-B", &"service_bearing")
	if rejected["accepted"] or rejected["reason"] != "PUMP_MUST_BE_STOPPED":
		return "P-B service did not reject the running pump prerequisite"
	if not technician_view_model.perform_action(&"P-B", &"stop")["accepted"]:
		return "P-B stop prerequisite command failed"
	var condition_before: float = simulation.create_snapshot().components["P-B"]["condition"]
	var accepted := technician_view_model.perform_action(&"P-B", &"service_bearing")
	if not accepted["accepted"]:
		return "P-B service was rejected after the pump stopped"
	var service_focus := technician_view_model.get_focus_view(&"P-B")
	if not service_focus.has("local_status") or "SERVICE IN PROGRESS" not in service_focus["local_status"]:
		return "Technician focus did not expose local timed-service progress"
	for action in service_focus["actions"]:
		if action["action_id"] == "start":
			return "Technician focus offered restart while service was active"
	if technician_view_model.perform_action(&"P-B", &"service_bearing")["reason"] != "SERVICE_IN_PROGRESS":
		return "duplicate P-B service did not report SERVICE_IN_PROGRESS"
	var service_ticks := ceili(
		simulation.get_tuning().bearing_failure_definition.service_duration_seconds
		/ simulation.get_tuning().simulation_step_seconds
	) + 1
	clock.run_ticks(service_ticks)
	var serviced_snapshot := simulation.create_snapshot()
	if not float(serviced_snapshot.components["P-B"]["condition"]) > condition_before:
		return "completed service did not improve authoritative P-B condition"
	if serviced_snapshot.bearing_failure["service_active"]:
		return "completed service remained active"
	if serviced_snapshot.bearing_failure["completed_service_count"] != 1:
		return "completed service was not recorded exactly once"
	if not technician_view_model.perform_action(&"P-B", &"start")["accepted"]:
		return "P-B could not restart after service"
	clock.run_ticks(40)
	var restored_flow: float = simulation.create_snapshot().components["P-B"]["effective_flow_units_per_second"]
	if not restored_flow > degraded_flow:
		return "service condition improvement did not restore P-B performance"
	return ""


func _run_bearing_choice(choice: String) -> PlantSnapshot:
	var simulation := _create_simulation()
	var clock := SimulationClock.new(simulation)
	simulation.debug_set_component_condition(&"P-B", 0.55)
	simulation.set_requested_load(1.0)
	match choice:
		"reduce":
			simulation.set_requested_load(0.55)
		"switch":
			simulation.execute_command(&"P-B", &"stop")
	clock.run_ticks(800)
	return simulation.create_snapshot()


func _find_alarm(history: Array[Dictionary], rule_id: String, active_only: bool) -> Dictionary:
	for alarm in history:
		if alarm["alarm_rule_id"] == rule_id and (not active_only or alarm["active"]):
			return alarm
	return {}


func _find_forbidden_key(value: Variant, forbidden_keys: Array[String]) -> String:
	if value is Dictionary:
		for key in value:
			if str(key) in forbidden_keys:
				return str(key)
			var nested_key := _find_forbidden_key(value[key], forbidden_keys)
			if not nested_key.is_empty():
				return nested_key
	elif value is Array:
		for item in value:
			var nested_key := _find_forbidden_key(item, forbidden_keys)
			if not nested_key.is_empty():
				return nested_key
	return ""


func _collect_presenter_ids(node: Node, result: Array[String]) -> void:
	if node is WorldDevicePresenter:
		result.append(str((node as WorldDevicePresenter).device_id))
	for child in node.get_children():
		_collect_presenter_ids(child, result)


func _run_soak_configuration(configuration: Dictionary) -> String:
	var tuning := _create_tuning()
	tuning.bearing_failure_definition.base_wear_per_sim_hour = 0.0
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
	var maximum_flow: float = (
		tuning.pump_a_definition.rated_flow_units_per_second * tuning.pump_a_definition.nominal_efficiency
		+ tuning.pump_b_definition.rated_flow_units_per_second * tuning.pump_b_definition.nominal_efficiency
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
	var tuning := DEFAULT_TUNING.duplicate(true) as PlantTuning
	tuning.pump_a_definition = DEFAULT_TUNING.pump_a_definition.duplicate(true) as PumpDefinition
	tuning.pump_b_definition = DEFAULT_TUNING.pump_b_definition.duplicate(true) as PumpDefinition
	tuning.valve_a_definition = DEFAULT_TUNING.valve_a_definition.duplicate(true) as ComponentDefinition
	tuning.valve_b_definition = DEFAULT_TUNING.valve_b_definition.duplicate(true) as ComponentDefinition
	tuning.breaker_a_definition = DEFAULT_TUNING.breaker_a_definition.duplicate(true) as ComponentDefinition
	tuning.local_gauge_definition = DEFAULT_TUNING.local_gauge_definition.duplicate(true) as ComponentDefinition
	tuning.bearing_failure_definition = DEFAULT_TUNING.bearing_failure_definition.duplicate(true) as BearingFailureDefinition
	tuning.pump_vibration_alarm_rule = DEFAULT_TUNING.pump_vibration_alarm_rule.duplicate(true) as AlarmRuleDefinition
	tuning.pump_temperature_alarm_rule = DEFAULT_TUNING.pump_temperature_alarm_rule.duplicate(true) as AlarmRuleDefinition
	tuning.pump_current_alarm_rule = DEFAULT_TUNING.pump_current_alarm_rule.duplicate(true) as AlarmRuleDefinition
	tuning.coolant_flow_alarm_rule = DEFAULT_TUNING.coolant_flow_alarm_rule.duplicate(true) as AlarmRuleDefinition
	tuning.coolant_temperature_alarm_rule = DEFAULT_TUNING.coolant_temperature_alarm_rule.duplicate(true) as AlarmRuleDefinition
	return tuning


func _is_close(actual: float, expected: float, tolerance: float = ABSOLUTE_TOLERANCE) -> bool:
	return absf(actual - expected) <= tolerance
