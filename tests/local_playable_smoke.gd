extends SceneTree

const MAIN_SCENE := preload("res://main.tscn")
const OUTPUT_DIRECTORY := "res://.godot/m3_visual_smoke"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var local_slice := MAIN_SCENE.instantiate() as LocalSliceRoot
	get_root().add_child(local_slice)
	await process_frame
	await process_frame
	var absolute_output_directory := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	DirAccess.make_dir_recursive_absolute(absolute_output_directory)

	local_slice.debug_set_pump_b_degraded()
	local_slice.debug_toggle_valve_mismatch()
	local_slice.run_simulation_ticks(20)
	var simulation := local_slice.get_simulation()
	var operator_view_model := local_slice.get_operator_view_model()
	operator_view_model.refresh()
	var operator_view := operator_view_model.get_view()
	_expect(operator_view["equipment"]["V-A"]["reported_position_state"] == "OPEN", "Operator did not see V-A reported OPEN")
	_expect(not operator_view.has("condition"), "Operator root view exposed condition")
	await _send_action("role_operator")
	_expect(local_slice.get_local_role() == LocalSliceRoot.ROLE_OPERATOR, "F1 role action did not select Operator")
	await _save_frame("operator_role.png")

	await _send_action("role_technician")
	_expect(local_slice.get_local_role() == LocalSliceRoot.ROLE_TECHNICIAN, "F2 role action did not select Technician")
	var technician := local_slice.get_node("TechnicianController") as TechnicianController
	var movement_start_z := technician.position.z
	Input.action_press("technician_move_forward")
	for _frame in range(40):
		await physics_frame
	Input.action_release("technician_move_forward")
	print("[SMOKE] movement start_z=%.3f end_z=%.3f role=%s" % [movement_start_z, technician.position.z, local_slice.get_local_role()])
	_expect(technician.position.z < movement_start_z - 0.5, "Technician movement did not advance through the control room")
	technician.position = Vector3(-1.0, 1.0, -7.0)
	technician.rotation.y = -atan2(-2.35, 2.1)
	var technician_camera := technician.get_node("%TechnicianCamera") as Camera3D
	technician_camera.rotation.x = -0.16
	await physics_frame
	await physics_frame
	_expect(technician.get_focused_device_id() == &"V-A", "Interaction ray did not focus V-A")
	await _save_frame("technician_valve_mismatch.png")

	technician.position = Vector3(1.0, 1.0, -4.9)
	technician.rotation.y = -atan2(2.35, 1.2)
	technician_camera.rotation.x = -0.16
	await physics_frame
	await physics_frame
	_expect(technician.get_focused_device_id() == &"P-B", "Interaction ray did not focus P-B")
	var technician_view_model := local_slice.get_technician_view_model()
	var valve_inspection := technician_view_model.perform_action(&"V-A", &"inspect")
	_expect(valve_inspection["accepted"], "Technician V-A inspection was rejected")
	_expect(valve_inspection["result"]["physical_state"] == "CLOSED", "Technician did not see V-A physical CLOSED")
	var pump_inspection := technician_view_model.perform_action(&"P-B", &"inspect")
	_expect(pump_inspection["accepted"], "Technician P-B inspection was rejected")
	_expect("vibration" in String(pump_inspection["feedback"]).to_lower(), "Technician P-B inspection lacked local vibration symptom")
	await _save_frame("technician_field_role.png")

	var flow_before: float = simulation.create_operator_snapshot()["coolant_flow_units_per_second"]
	_expect(technician_view_model.perform_action(&"P-B", &"stop")["accepted"], "Technician P-B stop failed")
	_expect(technician_view_model.perform_action(&"P-B", &"service_bearing")["accepted"], "Technician P-B service failed")
	var service_ticks := ceili(
		simulation.get_tuning().bearing_failure_definition.service_duration_seconds
		/ simulation.get_tuning().simulation_step_seconds
	) + 1
	local_slice.run_simulation_ticks(service_ticks)
	_expect(technician_view_model.perform_action(&"P-B", &"start")["accepted"], "Technician P-B restart failed")
	local_slice.run_simulation_ticks(100)
	operator_view_model.refresh()
	var flow_after: float = operator_view_model.get_view()["coolant_flow_units_per_second"]
	_expect(flow_after > flow_before, "Serviced P-B did not improve reported plant flow")
	await _send_action("role_operator")
	await _save_frame("operator_after_field_action.png")

	if _failures.is_empty():
		print("[SMOKE] PASS local role swap, lying sensor, inspect, stop, service, restart and operator response")
		print("[SMOKE] captures=%s" % absolute_output_directory)
		quit(0)
	else:
		for failure in _failures:
			printerr("[SMOKE] FAIL %s" % failure)
		quit(1)


func _save_frame(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	var output_path := "%s/%s" % [ProjectSettings.globalize_path(OUTPUT_DIRECTORY), file_name]
	var error := image.save_png(output_path)
	_expect(error == OK, "Could not save visual smoke capture %s" % file_name)


func _send_action(action_name: StringName) -> void:
	var pressed_event := InputEventAction.new()
	pressed_event.action = action_name
	pressed_event.pressed = true
	Input.parse_input_event(pressed_event)
	await process_frame
	var released_event := InputEventAction.new()
	released_event.action = action_name
	released_event.pressed = false
	Input.parse_input_event(released_event)
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
