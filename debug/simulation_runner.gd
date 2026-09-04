extends SceneTree

const DEFAULT_TUNING := preload("res://data/plant/default_plant_tuning.tres")


func _initialize() -> void:
	var requested_load := 0.75
	var tick_count := 100
	var after_tick_count := 100
	var pump_a_enabled := true
	var pump_b_enabled := true
	var disable_after: StringName = &""
	var condition_commands: Array[Dictionary] = []
	var wear_commands: Array[Dictionary] = []
	var sensor_commands: Array[Dictionary] = []
	var valve_mismatch_commands: Array[Dictionary] = []
	var failure_phase := -1
	var breaker_action := ""
	var alarm_to_acknowledge: StringName = &""
	var print_alarms := false
	var reset_after_run := false

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--load="):
			var load_text := argument.trim_prefix("--load=")
			if not load_text.is_valid_float():
				_fail("Invalid --load value: %s" % load_text)
				return
			requested_load = load_text.to_float()
		elif argument.begins_with("--ticks="):
			var ticks_text := argument.trim_prefix("--ticks=")
			if not ticks_text.is_valid_int():
				_fail("Invalid --ticks value: %s" % ticks_text)
				return
			tick_count = ticks_text.to_int()
		elif argument.begins_with("--after-ticks="):
			var after_ticks_text := argument.trim_prefix("--after-ticks=")
			if not after_ticks_text.is_valid_int():
				_fail("Invalid --after-ticks value: %s" % after_ticks_text)
				return
			after_tick_count = after_ticks_text.to_int()
		elif argument.begins_with("--pump-a="):
			var pump_a_text := argument.trim_prefix("--pump-a=").to_lower()
			if pump_a_text != "on" and pump_a_text != "off":
				_fail("--pump-a must be on or off")
				return
			pump_a_enabled = pump_a_text == "on"
		elif argument.begins_with("--pump-b="):
			var pump_b_text := argument.trim_prefix("--pump-b=").to_lower()
			if pump_b_text != "on" and pump_b_text != "off":
				_fail("--pump-b must be on or off")
				return
			pump_b_enabled = pump_b_text == "on"
		elif argument.begins_with("--disable-after="):
			var pump_id := argument.trim_prefix("--disable-after=").to_upper()
			if pump_id != "P-A" and pump_id != "P-B":
				_fail("--disable-after must be P-A or P-B")
				return
			disable_after = StringName(pump_id)
		elif argument.begins_with("--condition="):
			var parsed_condition := _parse_device_float(argument.trim_prefix("--condition="))
			if parsed_condition.is_empty():
				_fail("--condition must be P-A|P-B:<0..1>")
				return
			condition_commands.append(parsed_condition)
		elif argument.begins_with("--wear="):
			var parsed_wear := _parse_device_float(argument.trim_prefix("--wear="))
			if parsed_wear.is_empty():
				_fail("--wear must be P-A|P-B:<0..1>")
				return
			wear_commands.append(parsed_wear)
		elif argument.begins_with("--failure-phase="):
			failure_phase = BearingFailureRuntime.phase_from_name(argument.trim_prefix("--failure-phase="))
			if failure_phase < 0:
				_fail("Unknown --failure-phase")
				return
		elif argument.begins_with("--sensor="):
			var parsed_sensor := _parse_sensor(argument.trim_prefix("--sensor="))
			if parsed_sensor.is_empty():
				_fail("--sensor must be ID:NORMAL|BIASED|FROZEN|DELAYED[:bias][:delay_ticks]")
				return
			sensor_commands.append(parsed_sensor)
		elif argument.begins_with("--valve-mismatch="):
			var parsed_mismatch := _parse_valve_mismatch(argument.trim_prefix("--valve-mismatch="))
			if parsed_mismatch.is_empty():
				_fail("--valve-mismatch must be V-A|V-B:<actual>:<reported>")
				return
			valve_mismatch_commands.append(parsed_mismatch)
		elif argument.begins_with("--breaker="):
			breaker_action = argument.trim_prefix("--breaker=").to_lower()
			if breaker_action not in ["open", "trip", "reset"]:
				_fail("--breaker must be open, trip or reset")
				return
		elif argument.begins_with("--ack-alarm="):
			alarm_to_acknowledge = StringName(argument.trim_prefix("--ack-alarm="))
		elif argument == "--alarms":
			print_alarms = true
		elif argument == "--reset" or argument == "--reset-after-run":
			reset_after_run = true
		elif argument == "--help":
			_print_help()
			quit(0)
			return
		else:
			_fail("Unknown argument: %s" % argument)
			return

	if tick_count < 0 or after_tick_count < 0:
		_fail("--ticks and --after-ticks must be non-negative")
		return

	var tuning := DEFAULT_TUNING.duplicate(true) as PlantTuning
	var simulation := PlantSimulation.new(tuning)
	var clock := SimulationClock.new(simulation)
	if not simulation.set_requested_load(requested_load):
		_fail("requested_load was rejected")
		return
	if not simulation.set_pump_enabled(&"P-A", pump_a_enabled) or not simulation.set_pump_enabled(&"P-B", pump_b_enabled):
		_fail("Pump command was rejected")
		return

	for command in condition_commands:
		if not simulation.debug_set_component_condition(command["device_id"], command["value"]):
			_fail("Condition command was rejected for %s" % command["device_id"])
			return
	for command in wear_commands:
		if not simulation.debug_set_component_wear(command["device_id"], command["value"]):
			_fail("Wear command was rejected for %s" % command["device_id"])
			return
	if failure_phase >= 0 and not simulation.debug_set_failure_phase(failure_phase):
		_fail("Failure phase command was rejected")
		return
	for command in sensor_commands:
		if not simulation.set_sensor_mode(command["sensor_id"], command["mode"], command["bias"], command["delay_ticks"]):
			_fail("Sensor command was rejected for %s" % command["sensor_id"])
			return
	for command in valve_mismatch_commands:
		if not simulation.debug_set_valve_mismatch(command["device_id"], command["actual"], command["reported"]):
			_fail("Valve mismatch command was rejected for %s" % command["device_id"])
			return
	if breaker_action == "open":
		simulation.execute_command(&"BR-A", &"open")
	elif breaker_action == "trip":
		simulation.debug_trip_breaker()
	elif breaker_action == "reset":
		simulation.execute_command(&"BR-A", &"reset")

	clock.run_ticks(tick_count)
	if disable_after.is_empty():
		_print_snapshot("result", simulation.create_snapshot())
	else:
		_print_snapshot("before_change", simulation.create_snapshot())
		if not simulation.set_pump_enabled(disable_after, false):
			_fail("Pump shutdown command was rejected")
			return
		clock.run_ticks(after_tick_count)
		_print_snapshot("after_change", simulation.create_snapshot())

	if not alarm_to_acknowledge.is_empty():
		if not simulation.acknowledge_alarm(alarm_to_acknowledge):
			_fail("Alarm acknowledge was rejected: %s" % alarm_to_acknowledge)
			return
		_print_snapshot("after_acknowledge", simulation.create_snapshot())
	if print_alarms:
		print("[ALARM] history %s" % JSON.stringify(simulation.get_alarm_history()))
	if reset_after_run:
		clock.reset()
		_print_snapshot("after_reset", simulation.create_snapshot())

	quit(0)


func _parse_device_float(value: String) -> Dictionary:
	var parts := value.split(":")
	if parts.size() != 2 or parts[0].to_upper() not in ["P-A", "P-B"] or not parts[1].is_valid_float():
		return {}
	var parsed_value := parts[1].to_float()
	if parsed_value < 0.0 or parsed_value > 1.0:
		return {}
	return {"device_id": StringName(parts[0].to_upper()), "value": parsed_value}


func _parse_sensor(value: String) -> Dictionary:
	var parts := value.split(":")
	if parts.size() < 2 or parts.size() > 4:
		return {}
	var mode := SensorState.mode_from_name(parts[1])
	if mode < 0:
		return {}
	var parsed_bias := 0.0
	var parsed_delay := 0
	if parts.size() >= 3:
		if not parts[2].is_valid_float():
			return {}
		parsed_bias = parts[2].to_float()
	if parts.size() == 4:
		if not parts[3].is_valid_int() or parts[3].to_int() < 0:
			return {}
		parsed_delay = parts[3].to_int()
	return {
		"sensor_id": StringName(parts[0].to_upper()),
		"mode": mode,
		"bias": parsed_bias,
		"delay_ticks": parsed_delay,
	}


func _parse_valve_mismatch(value: String) -> Dictionary:
	var parts := value.split(":")
	if (
		parts.size() != 3
		or parts[0].to_upper() not in ["V-A", "V-B"]
		or not parts[1].is_valid_float()
		or not parts[2].is_valid_float()
	):
		return {}
	var actual := parts[1].to_float()
	var reported := parts[2].to_float()
	if actual < 0.0 or actual > 1.0 or reported < 0.0 or reported > 1.0:
		return {}
	return {
		"device_id": StringName(parts[0].to_upper()),
		"actual": actual,
		"reported": reported,
	}


func _print_snapshot(label: String, snapshot: PlantSnapshot) -> void:
	print("[SIM] %s %s" % [label, JSON.stringify(snapshot.to_dictionary())])


func _print_help() -> void:
	print(
		"Usage: -- --load=<float> --ticks=<int> [--pump-a=on|off] [--pump-b=on|off] "
		+ "[--disable-after=P-A|P-B --after-ticks=<int>] [--condition=P-B:0.5] "
		+ "[--wear=P-B:0.5] [--failure-phase=DEGRADED] "
		+ "[--sensor=ID:MODE:bias:delay_ticks] [--valve-mismatch=V-A:0:1] "
		+ "[--breaker=open|trip|reset] [--ack-alarm=ID] [--alarms] [--reset]"
	)


func _fail(message: String) -> void:
	printerr("[SIM] ERROR %s" % message)
	quit(2)
