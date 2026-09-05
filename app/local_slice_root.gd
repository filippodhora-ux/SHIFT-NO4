class_name LocalSliceRoot
extends Node3D

const DEFAULT_TUNING := preload("res://data/plant/default_plant_tuning.tres")
const ROLE_OPERATOR: StringName = AuthorityGateway.ROLE_OPERATOR
const ROLE_TECHNICIAN: StringName = AuthorityGateway.ROLE_TECHNICIAN

@export var local_dev_override: bool = false

@onready var _operator_camera: Camera3D = %OperatorCamera
@onready var _operator_dashboard: OperatorDashboard = %OperatorDashboard
@onready var _technician_controller: TechnicianController = %TechnicianController
@onready var _debug_overlay: DebugOverlay = %DebugOverlay
@onready var _role_status: Label = %RoleStatus
@onready var _network_session: NetworkSessionManager = %NetworkSession
@onready var _dev_lobby: DevLobby = %DevLobby

var _simulation: PlantSimulation
var _clock: SimulationClock
var _operator_view_model: OperatorViewModel
var _technician_view_model: TechnicianViewModel
var _role: StringName = &""
var _valve_mismatch_enabled: bool = false
var _presenters: Array[WorldDevicePresenter] = []
var _local_dev_active: bool = false
var _movement_send_accumulator_seconds: float = 0.0
var _movement_client_tick: int = 0
var _pending_cli_role: StringName = &""
var _pending_cli_ready: bool = false


func _ready() -> void:
	_ensure_input_actions()
	for node in get_tree().get_nodes_in_group("world_devices"):
		if node is WorldDevicePresenter:
			_presenters.append(node as WorldDevicePresenter)
	_network_session.role_snapshot_received.connect(_on_role_snapshot_received)
	_network_session.command_result_received.connect(_on_command_result_received)
	_network_session.lobby_state_changed.connect(_on_lobby_state_changed)
	_network_session.connection_state_changed.connect(_on_connection_state_changed)
	_network_session.session_state_changed.connect(_on_session_state_changed)
	_dev_lobby.bind(_network_session)
	_debug_overlay.bind_network(_network_session)
	_operator_dashboard.set_role_active(false)
	_technician_controller.set_role_active(false)
	_role_status.text = "M4 DEV LOBBY — choose Host or Join"
	if local_dev_override or OS.get_cmdline_user_args().has("--local-dev"):
		_start_local_dev_slice()
	else:
		_apply_command_line_network_options()


func _physics_process(real_delta_seconds: float) -> void:
	if _local_dev_active:
		if _clock != null and _clock.advance(real_delta_seconds) > 0:
			_refresh_presentations()
		return
	if _role != ROLE_TECHNICIAN or _network_session.get_session_state() != AuthorityGateway.SESSION_IN_SHIFT:
		return
	_movement_send_accumulator_seconds += real_delta_seconds
	if _movement_send_accumulator_seconds >= 0.1:
		_movement_send_accumulator_seconds = fmod(_movement_send_accumulator_seconds, 0.1)
		_movement_client_tick += 1
		_network_session.send_technician_position(_technician_controller.global_position, _movement_client_tick)


func _unhandled_input(event: InputEvent) -> void:
	if _local_dev_active and event.is_action_pressed("role_operator"):
		set_local_role(ROLE_OPERATOR)
	elif _local_dev_active and event.is_action_pressed("role_technician"):
		set_local_role(ROLE_TECHNICIAN)
	elif event.is_action_pressed("toggle_debug_state"):
		_debug_overlay.visible = not _debug_overlay.visible
		_debug_overlay.refresh_from_authority()
	elif event.is_action_pressed("debug_degrade_pump_b") and _has_host_authority():
		debug_set_pump_b_degraded()
	elif event.is_action_pressed("debug_toggle_valve_mismatch") and _has_host_authority():
		debug_toggle_valve_mismatch()
	elif event.is_action_pressed("debug_reset_player") and _role == ROLE_TECHNICIAN:
		_technician_controller.teleport_to_start()
	elif event.is_action_pressed("technician_confirm_end_shift") and _role == ROLE_TECHNICIAN:
		_network_session.submit_gameplay_command(AuthorityGateway.TARGET_SESSION, &"confirm_end_shift")


func set_local_role(role: StringName) -> void:
	if not _local_dev_active:
		push_warning("F1/F2 role switching is disabled outside explicit --local-dev mode")
		return
	_apply_role(role, true)


func get_local_role() -> StringName:
	return _role


func get_simulation() -> PlantSimulation:
	if _simulation != null:
		return _simulation
	var gateway := _network_session.get_gateway()
	return gateway.get_simulation() if gateway != null else null


func get_operator_view_model() -> OperatorViewModel:
	return _operator_view_model


func get_technician_view_model() -> TechnicianViewModel:
	return _technician_view_model


func get_network_session() -> NetworkSessionManager:
	return _network_session


func run_simulation_ticks(tick_count: int) -> void:
	if _local_dev_active:
		_clock.run_ticks(tick_count)
	else:
		var gateway := _network_session.get_gateway()
		if gateway != null:
			gateway.run_ticks(tick_count)
	_refresh_presentations()


func debug_set_pump_b_degraded() -> void:
	var simulation := get_simulation()
	if simulation == null:
		return
	simulation.debug_set_component_condition(&"P-B", 0.52)
	simulation.set_requested_load(1.0)
	_network_session.force_snapshot_for_test()
	_refresh_presentations()


func debug_toggle_valve_mismatch() -> void:
	var simulation := get_simulation()
	if simulation == null:
		return
	_valve_mismatch_enabled = not _valve_mismatch_enabled
	if _valve_mismatch_enabled:
		simulation.debug_set_valve_mismatch(&"V-A", 0.0, 1.0)
	else:
		simulation.execute_command(&"V-A", &"set_position", {"position": 1.0})
		simulation.set_sensor_mode(&"S-V-A-POS", SensorState.Mode.NORMAL)
	_network_session.force_snapshot_for_test()
	_refresh_presentations()


func _start_local_dev_slice() -> void:
	_local_dev_active = true
	_dev_lobby.set_session_visible(false)
	var tuning := DEFAULT_TUNING.duplicate(true) as PlantTuning
	_simulation = PlantSimulation.new(tuning)
	_clock = SimulationClock.new(_simulation)
	_operator_view_model = OperatorViewModel.new(_simulation)
	_technician_view_model = TechnicianViewModel.new(_simulation)
	_operator_dashboard.bind(_operator_view_model)
	_technician_controller.bind(_technician_view_model)
	_debug_overlay.bind(_simulation)
	for presenter in _presenters:
		presenter.bind(_simulation)
	_apply_role(ROLE_OPERATOR, true)
	_refresh_presentations()


func _on_role_snapshot_received(_snapshot: Dictionary) -> void:
	if _local_dev_active:
		return
	var store := _network_session.get_snapshot_store()
	var assigned_role := _network_session.get_assigned_role()
	if assigned_role == ROLE_OPERATOR and _operator_view_model == null:
		_operator_view_model = OperatorViewModel.new(store, _send_network_command)
		_operator_dashboard.bind(_operator_view_model)
	elif assigned_role == ROLE_TECHNICIAN and _technician_view_model == null:
		_technician_view_model = TechnicianViewModel.new(store, _send_network_command)
		_technician_controller.bind(_technician_view_model)
		for presenter in _presenters:
			presenter.bind(store)
	_apply_role(assigned_role, false)
	_refresh_presentations()
	_update_remote_technician_presentation()


func _on_command_result_received(command_result: Dictionary) -> void:
	if _technician_view_model != null:
		_technician_view_model.apply_command_result(command_result)
	_role_status.text = "%s COMMAND %s — %s" % [
		"ACCEPTED" if command_result["accepted"] else "REJECTED",
		command_result.get("command_id", ""),
		command_result.get("reason", "OK") if not command_result["accepted"] else "OK",
	]
	_refresh_presentations()


func _on_lobby_state_changed(_snapshot: Dictionary) -> void:
	_try_apply_pending_cli_role()


func _on_connection_state_changed(state: String, _detail: String) -> void:
	if state == "CONNECTED":
		_try_apply_pending_cli_role()


func _on_session_state_changed(state: String) -> void:
	if state == str(AuthorityGateway.SESSION_IN_SHIFT):
		_dev_lobby.set_session_visible(false)
		_apply_role(_network_session.get_assigned_role(), false)
	elif state == str(AuthorityGateway.SESSION_ENDED):
		_operator_dashboard.set_role_active(false)
		_technician_controller.set_role_active(false)
		_dev_lobby.set_session_visible(true)
		_dev_lobby.show_message("SHIFT ENDED BY BOTH PLAYERS — host may start a new M4 session.")
	elif state == str(AuthorityGateway.SESSION_DISCONNECTED):
		_operator_dashboard.set_role_active(false)
		_technician_controller.set_role_active(false)
		_dev_lobby.set_session_visible(true)
		_dev_lobby.show_message("PEER DISCONNECTED — SESSION STOPPED SAFELY.")


func _apply_role(role: StringName, local_dev: bool) -> void:
	if role != ROLE_OPERATOR and role != ROLE_TECHNICIAN:
		return
	_role = role
	var operator_active := role == ROLE_OPERATOR
	_operator_camera.current = operator_active
	_operator_dashboard.set_role_active(operator_active)
	_technician_controller.set_role_active(not operator_active)
	_technician_controller.set_remote_avatar_visible(operator_active and not local_dev)
	if local_dev:
		_role_status.text = "LOCAL DEV ROLE: %s  |  F1/F2 enabled  F3 Developer state" % role
	else:
		var technician_hint := "  G Confirm End Shift" if role == ROLE_TECHNICIAN else ""
		_role_status.text = "NETWORK ROLE: %s  |  locked for session  F3 Network debug%s" % [role, technician_hint]


func _refresh_presentations() -> void:
	if _operator_view_model != null:
		_operator_dashboard.refresh_from_authority()
	for presenter in _presenters:
		presenter.refresh_from_authority()
	_debug_overlay.refresh_from_authority()


func _update_remote_technician_presentation() -> void:
	if _role != ROLE_OPERATOR:
		return
	var snapshot := _network_session.get_snapshot_store().get_operator_snapshot()
	var peers: Dictionary = snapshot.get("player_positions", {})
	var lobby_peers: Dictionary = _network_session.get_lobby_snapshot().get("peers", {})
	for peer_id_text in lobby_peers:
		if StringName(lobby_peers[peer_id_text].get("role", "")) != ROLE_TECHNICIAN:
			continue
		var position: Dictionary = peers.get(peer_id_text, {})
		if not position.is_empty():
			_technician_controller.global_position = Vector3(position["x"], position["y"], position["z"])


func _send_network_command(target: StringName, action: StringName, parameters: Dictionary) -> Dictionary:
	return _network_session.submit_gameplay_command(target, action, parameters)


func _has_host_authority() -> bool:
	return _local_dev_active or _network_session.get_gateway() != null


func _apply_command_line_network_options() -> void:
	var arguments := OS.get_cmdline_user_args()
	var port := int(_network_session.DEFAULT_NETWORK_TUNING.default_port)
	var join_address := ""
	var should_host := false
	for argument in arguments:
		if argument == "--host":
			should_host = true
		elif argument.begins_with("--join="):
			join_address = argument.trim_prefix("--join=")
		elif argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
		elif argument.begins_with("--role="):
			_pending_cli_role = StringName(argument.trim_prefix("--role=").to_upper())
		elif argument == "--ready":
			_pending_cli_ready = true
	if should_host:
		_network_session.host(port)
		_try_apply_pending_cli_role()
	elif not join_address.is_empty():
		_network_session.join(join_address, port)


func _try_apply_pending_cli_role() -> void:
	if _pending_cli_role.is_empty() or _network_session.get_connection_state() not in ["LISTENING", "CONNECTED"]:
		return
	if _network_session.get_assigned_role().is_empty():
		_network_session.choose_role(_pending_cli_role)
		return
	if _pending_cli_ready:
		var own_peer: Dictionary = _network_session.get_lobby_snapshot().get("peers", {}).get(str(multiplayer.get_unique_id()), {})
		if not bool(own_peer.get("ready", false)):
			_network_session.set_ready(true)


func _ensure_input_actions() -> void:
	var bindings: Dictionary = {
		&"technician_move_forward": KEY_W,
		&"technician_move_back": KEY_S,
		&"technician_move_left": KEY_A,
		&"technician_move_right": KEY_D,
		&"technician_inspect": KEY_E,
		&"technician_operate": KEY_F,
		&"technician_service": KEY_R,
		&"technician_confirm_end_shift": KEY_G,
		&"release_mouse": KEY_ESCAPE,
		&"role_operator": KEY_F1,
		&"role_technician": KEY_F2,
		&"toggle_debug_state": KEY_F3,
		&"debug_degrade_pump_b": KEY_F4,
		&"debug_toggle_valve_mismatch": KEY_F5,
		&"debug_reset_player": KEY_F6,
	}
	for action_name: StringName in bindings:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var keycode: Key = bindings[action_name] as Key
		var already_bound := false
		for existing_event in InputMap.action_get_events(action_name):
			if existing_event is InputEventKey and existing_event.physical_keycode == keycode:
				already_bound = true
				break
		if not already_bound:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycode
			InputMap.action_add_event(action_name, key_event)
