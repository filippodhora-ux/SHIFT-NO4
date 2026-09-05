extends SceneTree

const DEFAULT_PORT: int = 17004
const TIMEOUT_SECONDS: float = 60.0

var _session: NetworkSessionManager
var _mode: String = ""
var _port: int = DEFAULT_PORT
var _elapsed_seconds: float = 0.0
var _last_frame_msec: int = 0
var _results: Dictionary = {}
var _all_results: Array[Dictionary] = []
var _failures: Array[String] = []

var _host_initialized: bool = false
var _host_load_sent: bool = false
var _host_end_requested: bool = false
var _host_flow_before: float = 0.0
var _host_flow_after: float = INF
var _host_initial_tick: int = 0
var _host_initial_condition: float = 0.0
var _host_finished_shift: bool = false
var _host_reported_pump_off: bool = false

var _client_role_sent: bool = false
var _client_ready_sent: bool = false
var _client_rejections_sent: bool = false
var _client_motion_target: Vector3 = Vector3.ZERO
var _client_motion_stage: String = ""
var _client_position: Vector3 = Vector3(0.0, 1.0, 7.0)
var _client_movement_tick: int = 0
var _client_move_accumulator: float = 0.0
var _client_valve_inspect_sent: bool = false
var _client_pump_inspect_sent: bool = false
var _client_stop_sent: bool = false
var _client_confirm_sent: bool = false
var _client_observed_pump_off: bool = false
var _last_reported_state: String = ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			_mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--port="):
			_port = int(argument.trim_prefix("--port="))
	if _mode not in ["host", "client"]:
		printerr("[TWO-PROCESS] FAIL use --mode=host|client")
		quit(2)
		return
	call_deferred("_run")


func _run() -> void:
	_session = NetworkSessionManager.new()
	_session.name = "NetworkSession"
	get_root().add_child(_session)
	_session.command_result_received.connect(_on_command_result)
	_last_frame_msec = Time.get_ticks_msec()
	if _mode == "host":
		var host_result := _session.host(_port)
		if not host_result["accepted"]:
			_fail("host create failed: %s" % host_result["reason"])
		else:
			_session.choose_role(AuthorityGateway.ROLE_OPERATOR)
			_session.set_ready(true)
	else:
		var join_result := _session.join("127.0.0.1", _port)
		if not join_result["accepted"]:
			_fail("client create failed: %s" % join_result["reason"])

	while _elapsed_seconds < TIMEOUT_SECONDS and _failures.is_empty():
		await process_frame
		var now_msec := Time.get_ticks_msec()
		var delta := float(now_msec - _last_frame_msec) / 1000.0
		_last_frame_msec = now_msec
		_elapsed_seconds += delta
		if _mode == "host":
			_drive_host()
		else:
			_drive_client(delta)
		if _should_finish():
			await create_timer(0.25).timeout
			_finish_success()
			return

	if _failures.is_empty():
		_fail("timed out after %.1f seconds in mode %s" % [TIMEOUT_SECONDS, _mode])
	for failure in _failures:
		printerr("[TWO-PROCESS] FAIL %s: %s" % [_mode, failure])
	_session.shutdown()
	quit(1)


func _drive_host() -> void:
	var gateway := _session.get_gateway()
	_report_state("host:%s:%s" % [_session.get_connection_state(), gateway.get_session_state() if gateway != null else "NO_GATEWAY"])
	if gateway == null or gateway.get_session_state() != AuthorityGateway.SESSION_IN_SHIFT:
		if gateway != null and gateway.get_session_state() == AuthorityGateway.SESSION_ENDED:
			_host_finished_shift = true
		return
	if not _host_initialized:
		_host_initialized = true
		var simulation := gateway.get_simulation()
		_host_initial_tick = gateway.get_simulation_tick()
		simulation.debug_set_component_condition(&"P-B", 0.52)
		_host_initial_condition = simulation.create_snapshot().components["P-B"]["condition"]
		simulation.debug_set_valve_mismatch(&"V-A", 0.0, 1.0)
		_session.force_snapshot_for_test()
	if not _host_load_sent:
		_host_load_sent = true
		_session.submit_gameplay_command(AuthorityGateway.TARGET_PLANT, &"set_requested_load", {"requested_load": 1.0})

	var operator_snapshot := _session.get_snapshot_store().get_operator_snapshot()
	if not operator_snapshot.is_empty():
		_host_flow_before = maxf(_host_flow_before, float(operator_snapshot["coolant_flow_units_per_second"]))
		if operator_snapshot["equipment"]["P-B"]["reported_status"] == "OFF":
			_host_flow_after = minf(_host_flow_after, float(operator_snapshot["coolant_flow_units_per_second"]))
			if not _host_reported_pump_off:
				_host_reported_pump_off = true
				print("[TWO-PROCESS] host observed P-B OFF flow_before=%.2f flow_now=%.2f" % [_host_flow_before, _host_flow_after])
		if (
			not _host_end_requested
			and _host_flow_before > 30.0
			and _host_flow_after < _host_flow_before - 10.0
		):
			_host_end_requested = true
			_session.submit_gameplay_command(AuthorityGateway.TARGET_SESSION, &"request_end_shift")


func _drive_client(delta: float) -> void:
	_report_state("client:%s:%s" % [_session.get_connection_state(), _session.get_session_state()])
	if _session.get_connection_state() in ["ERROR", "SERVER_DISCONNECTED"]:
		_fail("connection ended before smoke completed: %s" % _session.get_connection_state())
		return
	if _session.get_connection_state() != "CONNECTED":
		return
	if _session.get_connection_state() == "CONNECTED" and not _client_role_sent:
		_client_role_sent = true
		print("[TWO-PROCESS] client requesting TECHNICIAN")
		_session.choose_role(AuthorityGateway.ROLE_TECHNICIAN)
	var own_peer: Dictionary = _session.get_lobby_snapshot().get("peers", {}).get(str(_session.multiplayer.get_unique_id()), {})
	if _client_role_sent and not _client_ready_sent and own_peer.get("role", "") == "TECHNICIAN":
		_client_ready_sent = true
		print("[TWO-PROCESS] client READY")
		_session.set_ready(true)
	if _session.get_session_state() != AuthorityGateway.SESSION_IN_SHIFT:
		return
	if _session.get_gateway() != null:
		_fail("client process unexpectedly owns AuthorityGateway/PlantSimulation")
		return
	if not _client_rejections_sent:
		_client_rejections_sent = true
		_session.submit_gameplay_command(&"P-B", &"stop")
		_session.submit_gameplay_command(AuthorityGateway.TARGET_PLANT, &"set_requested_load", {"requested_load": 0.1})
		return
	if not (_has_rejection("OUT_OF_RANGE") and _has_rejection("ROLE_NOT_AUTHORIZED")):
		return

	if _client_motion_stage.is_empty():
		_client_motion_stage = "TO_VALVE"
		_client_motion_target = AuthorityGateway.device_positions()[EquipmentSystem.VALVE_A_ID]
	if _client_motion_stage == "TO_VALVE":
		_move_client_toward(delta, _client_motion_target)
		if _client_position.distance_to(_client_motion_target) < 0.05 and not _client_valve_inspect_sent:
			_client_valve_inspect_sent = true
			_session.submit_gameplay_command(&"V-A", &"inspect")
		if _results.has("client-inspect-valve"):
			_client_motion_stage = "TO_PUMP"
			_client_motion_target = AuthorityGateway.device_positions()[EquipmentSystem.PUMP_B_ID]
	elif _client_motion_stage == "TO_PUMP":
		_move_client_toward(delta, _client_motion_target)
		if _client_position.distance_to(_client_motion_target) < 0.05 and not _client_pump_inspect_sent:
			_client_pump_inspect_sent = true
			_session.submit_gameplay_command(&"P-B", &"inspect")
		if _results.has("client-inspect-pump") and not _client_stop_sent:
			_client_stop_sent = true
			var peer_id := _session.multiplayer.get_unique_id()
			var duplicate := NetworkCommand.create(
				"transport-duplicate",
				peer_id,
				AuthorityGateway.ROLE_TECHNICIAN,
				&"P-B",
				&"stop",
				{},
				_session.get_snapshot_store().get_authoritative_tick()
			)
			_session.submit_raw_command(duplicate)
			_session.submit_raw_command(duplicate)

	var technician_snapshot := _session.get_snapshot_store().get_technician_snapshot()
	if not technician_snapshot.is_empty():
		var forbidden := _find_forbidden_key(technician_snapshot, ["actual_power_mw", "produced_mwh", "plant_stress", "alarms"])
		if not forbidden.is_empty():
			_fail("Technician transport payload exposed %s" % forbidden)
			return
		var pump_view: Dictionary = technician_snapshot.get("world_devices", {}).get("P-B", {})
		if pump_view.get("operational_state", "") == "OFF":
			_client_observed_pump_off = true
		var session_view: Dictionary = technician_snapshot.get("session", {})
		if int(session_view.get("end_shift_requester_peer_id", 0)) != 0 and not _client_confirm_sent:
			_client_confirm_sent = true
			_session.submit_gameplay_command(AuthorityGateway.TARGET_SESSION, &"confirm_end_shift")


func _move_client_toward(delta: float, target: Vector3) -> void:
	_client_move_accumulator += delta
	if _client_move_accumulator < 0.08:
		return
	_client_move_accumulator = 0.0
	_client_position = _client_position.move_toward(target, 0.35)
	_client_movement_tick += 1
	_session.send_technician_position(_client_position, _client_movement_tick)


func _on_command_result(command_result: Dictionary) -> void:
	var command_id := String(command_result.get("command_id", ""))
	_results[command_id] = command_result.duplicate(true)
	_all_results.append(command_result.duplicate(true))
	print("[TWO-PROCESS] %s result id=%s action=%s accepted=%s reason=%s" % [
		_mode,
		command_id,
		command_result.get("action_id", ""),
		command_result.get("accepted", false),
		command_result.get("reason", ""),
	])
	if _mode != "client":
		return
	var action := String(command_result.get("action_id", ""))
	var target := String(command_result.get("target_device_id", ""))
	if action == "inspect" and target == "V-A" and command_result["accepted"]:
		if command_result["result"].get("physical_state", "") != "CLOSED":
			_fail("V-A local inspect did not return physical CLOSED")
		else:
			_results["client-inspect-valve"] = command_result
	elif action == "inspect" and target == "P-B" and command_result["accepted"]:
		var inspection_text := String(command_result["result"].get("inspection_text", "")).to_lower()
		if "vibration" not in inspection_text:
			_fail("P-B inspect lacked local vibration symptom")
		else:
			_results["client-inspect-pump"] = command_result


func _has_rejection(reason: String) -> bool:
	for result in _all_results:
		if not bool(result.get("accepted", false)) and result.get("reason", "") == reason:
			return true
	return false


func _should_finish() -> bool:
	if _mode == "client":
		return (
			_session.get_session_state() == AuthorityGateway.SESSION_ENDED
			and _results.has("transport-duplicate")
			and _has_rejection("DUPLICATE_COMMAND_ID")
			and _client_observed_pump_off
		)
	if not _host_finished_shift:
		return false
	var gateway := _session.get_gateway()
	var simulation := gateway.get_simulation()
	var operator_payload := _session.get_snapshot_store().get_operator_snapshot()
	if gateway.get_simulation_tick() <= _host_initial_tick:
		_fail("host simulation did not tick")
	if simulation.create_snapshot().produced_mwh <= 0.0:
		_fail("host did not integrate MWh")
	if float(simulation.create_snapshot().components["P-B"]["condition"]) >= _host_initial_condition:
		_fail("host did not progress P-B wear")
	if operator_payload["equipment"]["V-A"]["reported_position_state"] != "OPEN":
		_fail("Operator transport payload did not report lying V-A as OPEN")
	if operator_payload["equipment"]["V-A"].has("actual_position"):
		_fail("Operator transport payload leaked actual V-A position")
	var found_pump_symptom := false
	for alarm in operator_payload["alarms"]:
		if alarm.get("source_device_id", "") == "P-B":
			found_pump_symptom = true
			break
	if not found_pump_symptom:
		_fail("Operator did not receive a P-B symptom alarm")
	if not _host_flow_after < _host_flow_before:
		_fail("Operator did not receive P-B stop flow cascade")
	return _failures.is_empty()


func _finish_success() -> void:
	if _mode == "client":
		_session.shutdown()
	print(
		"[TWO-PROCESS] PASS mode=%s tick=%d snapshot_revision=%d commands=%d"
		% [
			_mode,
			_session.get_gateway().get_simulation_tick() if _session.get_gateway() != null else _session.get_snapshot_store().get_authoritative_tick(),
			_session.get_snapshot_store().get_latest_revision(),
			_results.size(),
		]
	)
	if _mode == "host":
		_session.shutdown()
	quit(0)


func _find_forbidden_key(value: Variant, forbidden_keys: Array[String]) -> String:
	if value is Dictionary:
		for key in value:
			if str(key) in forbidden_keys:
				return str(key)
			var nested := _find_forbidden_key(value[key], forbidden_keys)
			if not nested.is_empty():
				return nested
	elif value is Array:
		for item in value:
			var nested := _find_forbidden_key(item, forbidden_keys)
			if not nested.is_empty():
				return nested
	return ""


func _fail(message: String) -> void:
	if message not in _failures:
		_failures.append(message)


func _report_state(state: String) -> void:
	if state == _last_reported_state:
		return
	_last_reported_state = state
	print("[TWO-PROCESS] state %s" % state)
