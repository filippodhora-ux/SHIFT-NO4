extends SceneTree

const DEFAULT_TUNING := preload("res://data/plant/default_plant_tuning.tres")


func _initialize() -> void:
	var requested_load := 0.75
	var tick_count := 100
	var after_tick_count := 100
	var pump_a_enabled := true
	var pump_b_enabled := true
	var disable_after: StringName = &""
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
		elif argument == "--reset" or argument == "--reset-after-run":
			reset_after_run = true
		elif argument == "--help":
			print(
				"Usage: -- --load=<float> --ticks=<int> "
				+ "[--pump-a=on|off] [--pump-b=on|off] "
				+ "[--disable-after=P-A|P-B --after-ticks=<int>] [--reset]"
			)
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
	if not simulation.set_pump_enabled(&"P-A", pump_a_enabled):
		_fail("P-A command was rejected")
		return
	if not simulation.set_pump_enabled(&"P-B", pump_b_enabled):
		_fail("P-B command was rejected")
		return

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

	if reset_after_run:
		clock.reset()
		_print_snapshot("after_reset", simulation.create_snapshot())

	quit(0)


func _print_snapshot(label: String, snapshot: PlantSnapshot) -> void:
	print("[SIM] %s %s" % [label, JSON.stringify(snapshot.to_dictionary())])


func _fail(message: String) -> void:
	printerr("[SIM] ERROR %s" % message)
	quit(2)
