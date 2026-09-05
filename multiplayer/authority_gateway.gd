class_name AuthorityGateway
extends RefCounted

const ROLE_OPERATOR: StringName = &"OPERATOR"
const ROLE_TECHNICIAN: StringName = &"TECHNICIAN"

const SESSION_LOBBY: StringName = &"LOBBY"
const SESSION_IN_SHIFT: StringName = &"IN_SHIFT"
const SESSION_ENDED: StringName = &"ENDED"
const SESSION_DISCONNECTED: StringName = &"DISCONNECTED"

const TARGET_PLANT: StringName = &"PLANT"
const TARGET_ALARMS: StringName = &"ALARMS"
const TARGET_SESSION: StringName = &"SESSION"

var _plant_tuning: PlantTuning
var _network_tuning: NetworkTuning
var _simulation: PlantSimulation
var _clock: SimulationClock
var _session_state: StringName = SESSION_LOBBY
var _peers: Dictionary = {}
var _player_positions: Dictionary = {}
var _movement_ticks: Dictionary = {}
var _movement_server_ticks: Dictionary = {}
var _processed_command_ids: Dictionary = {}
var _command_queue: Array[Dictionary] = []
var _completed_results: Array[Dictionary] = []
var _server_sequence: int = 0
var _state_revision: int = 0
var _snapshot_revision: int = 0
var _lobby_revision: int = 0
var _end_shift_requester_peer_id: int = 0
var _end_shift_confirmations: Dictionary = {}
var _end_shift_remaining_seconds: float = 0.0


func _init(plant_tuning: PlantTuning, network_tuning: NetworkTuning) -> void:
	assert(plant_tuning != null, "AuthorityGateway requires PlantTuning")
	assert(network_tuning != null, "AuthorityGateway requires NetworkTuning")
	assert(network_tuning.validation_errors().is_empty(), "AuthorityGateway received invalid NetworkTuning")
	_plant_tuning = plant_tuning
	_network_tuning = network_tuning


func register_peer(peer_id: int) -> Dictionary:
	if peer_id <= 0:
		return _result(false, "", "INVALID_PEER_ID")
	if _session_state != SESSION_LOBBY:
		return _result(false, "", "SESSION_ALREADY_STARTED")
	if _peers.has(peer_id):
		return _result(true, "", "")
	if _peers.size() >= 2:
		return _result(false, "", "SESSION_FULL")
	_peers[peer_id] = {"role": "", "ready": false}
	_player_positions[peer_id] = _network_tuning.technician_spawn_position
	_movement_ticks[peer_id] = 0
	_movement_server_ticks[peer_id] = 0
	_lobby_revision += 1
	return _result(true, "", "")


func disconnect_peer(peer_id: int) -> void:
	if not _peers.has(peer_id):
		return
	_peers.erase(peer_id)
	_player_positions.erase(peer_id)
	_movement_ticks.erase(peer_id)
	_movement_server_ticks.erase(peer_id)
	_end_shift_confirmations.erase(peer_id)
	_lobby_revision += 1
	if _session_state == SESSION_IN_SHIFT:
		_session_state = SESSION_DISCONNECTED
		_end_shift_requester_peer_id = 0
		_end_shift_confirmations.clear()
		_end_shift_remaining_seconds = 0.0
		_state_revision += 1


func request_role(peer_id: int, role: StringName) -> Dictionary:
	if _session_state != SESSION_LOBBY:
		return _result(false, "", "SESSION_ALREADY_STARTED")
	if not _peers.has(peer_id):
		return _result(false, "", "UNKNOWN_PEER")
	if role != ROLE_OPERATOR and role != ROLE_TECHNICIAN:
		return _result(false, "", "INVALID_ROLE")
	for other_peer_id in _peers:
		if int(other_peer_id) != peer_id and StringName(_peers[other_peer_id]["role"]) == role:
			return _result(false, "", "ROLE_TAKEN")
	var peer: Dictionary = _peers[peer_id]
	peer["role"] = str(role)
	peer["ready"] = false
	_peers[peer_id] = peer
	_lobby_revision += 1
	return _result(true, "", "")


func set_ready(peer_id: int, ready: bool) -> Dictionary:
	if _session_state != SESSION_LOBBY:
		return _result(false, "", "SESSION_ALREADY_STARTED")
	if not _peers.has(peer_id):
		return _result(false, "", "UNKNOWN_PEER")
	var peer: Dictionary = _peers[peer_id]
	if String(peer["role"]).is_empty():
		return _result(false, "", "ROLE_REQUIRED")
	peer["ready"] = ready
	_peers[peer_id] = peer
	_lobby_revision += 1
	_try_start_shift()
	return _result(true, "", "")


func submit_command(sender_peer_id: int, command: Dictionary) -> Dictionary:
	var structure_error := NetworkCommand.structure_error(command)
	if not structure_error.is_empty():
		return _reject_immediately(sender_peer_id, command, structure_error)
	var command_id := String(command["command_id"])
	if _processed_command_ids.has(command_id):
		return _reject_immediately(sender_peer_id, command, "DUPLICATE_COMMAND_ID")
	_processed_command_ids[command_id] = true
	var validation_error := _validation_error(sender_peer_id, command)
	if not validation_error.is_empty():
		return _reject_immediately(sender_peer_id, command, validation_error)
	_server_sequence += 1
	var queued_command := command.duplicate(true)
	queued_command["server_sequence"] = _server_sequence
	queued_command["server_received_tick"] = get_simulation_tick()
	queued_command["sender_peer_id"] = sender_peer_id
	_command_queue.append(queued_command)
	return {
		"accepted": true,
		"queued": true,
		"command_id": command_id,
		"server_sequence": _server_sequence,
		"server_received_tick": get_simulation_tick(),
	}


func advance(real_delta_seconds: float) -> int:
	if _session_state != SESSION_IN_SHIFT or _clock == null:
		return 0
	if _end_shift_requester_peer_id != 0:
		_end_shift_remaining_seconds = maxf(0.0, _end_shift_remaining_seconds - real_delta_seconds)
		if is_zero_approx(_end_shift_remaining_seconds):
			_end_shift_requester_peer_id = 0
			_end_shift_confirmations.clear()
			_state_revision += 1
	return _clock.advance(real_delta_seconds, _process_commands_for_next_tick)


func run_ticks(tick_count: int) -> void:
	if _session_state != SESSION_IN_SHIFT or _clock == null:
		return
	for _index in range(tick_count):
		_process_commands_for_next_tick.call()
		_clock.step_once()


func update_player_position(peer_id: int, position: Vector3, client_tick: int) -> Dictionary:
	if _session_state != SESSION_IN_SHIFT:
		return _result(false, "", "SHIFT_NOT_RUNNING")
	if not _peers.has(peer_id):
		return _result(false, "", "UNKNOWN_PEER")
	if StringName(_peers[peer_id]["role"]) != ROLE_TECHNICIAN:
		return _result(false, "", "ROLE_NOT_AUTHORIZED")
	if not position.is_finite():
		return _result(false, "", "INVALID_POSITION")
	if not _position_in_bounds(position):
		return _result(false, "", "POSITION_OUT_OF_BOUNDS")
	var previous_tick := int(_movement_ticks.get(peer_id, 0))
	if client_tick <= previous_tick:
		return _result(false, "", "STALE_MOVEMENT")
	var previous_server_tick := int(_movement_server_ticks.get(peer_id, get_simulation_tick()))
	var elapsed_ticks := maxi(1, get_simulation_tick() - previous_server_tick)
	var maximum_distance := (
		_network_tuning.technician_max_speed_meters_per_second
		* _plant_tuning.simulation_step_seconds
		* float(elapsed_ticks)
		+ _network_tuning.movement_tolerance_meters
	)
	var previous_position: Vector3 = _player_positions[peer_id]
	if previous_position.distance_to(position) > maximum_distance:
		return _result(false, "", "MOVEMENT_TOO_FAST")
	_player_positions[peer_id] = position
	_movement_ticks[peer_id] = client_tick
	_movement_server_ticks[peer_id] = get_simulation_tick()
	return _result(true, "", "")


func create_role_snapshots() -> Dictionary:
	if _simulation == null:
		return {}
	_snapshot_revision += 1
	var session_view := _session_view()
	var result: Dictionary = {}
	for peer_id in _peers:
		var role := StringName(_peers[peer_id]["role"])
		if role == ROLE_OPERATOR:
			result[peer_id] = RoleSnapshotBuilder.operator_snapshot(
				_simulation,
				_snapshot_revision,
				session_view,
				_player_positions
			)
		elif role == ROLE_TECHNICIAN:
			result[peer_id] = RoleSnapshotBuilder.technician_snapshot(
				_simulation,
				_snapshot_revision,
				session_view,
				_player_positions[peer_id],
				device_positions(),
				_network_tuning.field_visibility_range_meters,
				_player_positions
			)
	return result


func take_completed_results() -> Array[Dictionary]:
	var results := _completed_results.duplicate(true)
	_completed_results.clear()
	return results


func get_lobby_snapshot() -> Dictionary:
	var serialized_peers: Dictionary = {}
	for peer_id in _peers:
		serialized_peers[str(peer_id)] = Dictionary(_peers[peer_id]).duplicate(true)
	return {
		"revision": _lobby_revision,
		"session_state": str(_session_state),
		"peers": serialized_peers,
	}


func get_session_state() -> StringName:
	return _session_state


func get_simulation() -> PlantSimulation:
	return _simulation


func get_simulation_tick() -> int:
	return _simulation.create_snapshot().tick if _simulation != null else 0


func get_state_revision() -> int:
	return _state_revision


func get_latest_snapshot_revision() -> int:
	return _snapshot_revision


func get_peer_role(peer_id: int) -> StringName:
	if not _peers.has(peer_id):
		return &""
	return StringName(_peers[peer_id]["role"])


func get_player_position(peer_id: int) -> Vector3:
	return _player_positions.get(peer_id, Vector3.ZERO)


func get_network_tuning() -> NetworkTuning:
	return _network_tuning


func debug_set_player_position_for_test(peer_id: int, position: Vector3, client_tick: int = 1) -> void:
	assert(_peers.has(peer_id), "Test position requires a registered peer")
	_player_positions[peer_id] = position
	_movement_ticks[peer_id] = client_tick
	_movement_server_ticks[peer_id] = get_simulation_tick()


static func device_positions() -> Dictionary:
	return {
		EquipmentSystem.PUMP_A_ID: Vector3(-3.35, 1.0, -6.1),
		EquipmentSystem.PUMP_B_ID: Vector3(3.35, 1.0, -6.1),
		EquipmentSystem.VALVE_A_ID: Vector3(-3.35, 1.0, -9.1),
		EquipmentSystem.VALVE_B_ID: Vector3(3.35, 1.0, -9.1),
		EquipmentSystem.BREAKER_A_ID: Vector3(-1.35, 1.0, -11.0),
		EquipmentSystem.LOCAL_GAUGE_ID: Vector3(1.35, 1.0, -11.0),
	}


func _try_start_shift() -> void:
	if _peers.size() != 2:
		return
	var roles: Array[String] = []
	for peer_id in _peers:
		var peer: Dictionary = _peers[peer_id]
		if not bool(peer["ready"]):
			return
		roles.append(String(peer["role"]))
	if not roles.has(str(ROLE_OPERATOR)) or not roles.has(str(ROLE_TECHNICIAN)):
		return
	var tuning := _plant_tuning.duplicate(true) as PlantTuning
	_simulation = PlantSimulation.new(tuning)
	_clock = SimulationClock.new(_simulation)
	_session_state = SESSION_IN_SHIFT
	_state_revision += 1
	_lobby_revision += 1


func _process_commands_for_next_tick() -> void:
	if _command_queue.is_empty():
		return
	_command_queue.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		if int(first["server_received_tick"]) != int(second["server_received_tick"]):
			return int(first["server_received_tick"]) < int(second["server_received_tick"])
		return int(first["server_sequence"]) < int(second["server_sequence"])
	)
	var commands := _command_queue.duplicate(true)
	_command_queue.clear()
	for command in commands:
		_completed_results.append(_apply_command(command))


func _apply_command(command: Dictionary) -> Dictionary:
	var sender_peer_id := int(command["sender_peer_id"])
	var validation_error := _validation_error(sender_peer_id, command, true)
	if not validation_error.is_empty():
		return _command_result(command, false, validation_error)

	var target_device_id := StringName(command["target_device_id"])
	var action_id := StringName(command["action_id"])
	var parameters: Dictionary = command["parameters"]
	var domain_result: Dictionary
	if target_device_id == TARGET_PLANT and action_id == &"set_requested_load":
		if not parameters.has("requested_load") or not (parameters["requested_load"] is float or parameters["requested_load"] is int):
			return _command_result(command, false, "INVALID_PARAMETERS")
		var accepted := _simulation.set_requested_load(float(parameters["requested_load"]))
		domain_result = {"accepted": accepted, "reason": "" if accepted else "INVALID_PARAMETERS", "revision": -1, "result": {}}
	elif target_device_id == TARGET_ALARMS and action_id == &"acknowledge_alarm":
		var alarm_instance_id := StringName(parameters.get("alarm_instance_id", ""))
		var accepted := not alarm_instance_id.is_empty() and _simulation.acknowledge_alarm(alarm_instance_id)
		domain_result = {"accepted": accepted, "reason": "" if accepted else "ALARM_NOT_FOUND", "revision": -1, "result": {}}
	elif target_device_id == TARGET_SESSION and action_id == &"request_end_shift":
		domain_result = _request_end_shift(sender_peer_id)
	elif target_device_id == TARGET_SESSION and action_id == &"confirm_end_shift":
		domain_result = _confirm_end_shift(sender_peer_id)
	else:
		domain_result = _simulation.execute_command(target_device_id, action_id, parameters)

	if bool(domain_result["accepted"]):
		if action_id != &"inspect":
			_state_revision += 1
	return _command_result(
		command,
		bool(domain_result["accepted"]),
		String(domain_result.get("reason", "")),
		int(domain_result.get("revision", -1)),
		Dictionary(domain_result.get("result", {}))
	)


func _validation_error(sender_peer_id: int, command: Dictionary, applying: bool = false) -> String:
	if _session_state != SESSION_IN_SHIFT:
		return "SHIFT_NOT_RUNNING"
	if not _peers.has(sender_peer_id):
		return "UNKNOWN_PEER"
	if int(command["actor_peer_id"]) != sender_peer_id:
		return "ACTOR_PEER_MISMATCH"
	var assigned_role := StringName(_peers[sender_peer_id]["role"])
	if StringName(command["actor_role"]) != assigned_role:
		return "ACTOR_ROLE_MISMATCH"
	var target_device_id := StringName(command["target_device_id"])
	var action_id := StringName(command["action_id"])
	if not _role_allows_action(assigned_role, target_device_id, action_id):
		return "ROLE_NOT_AUTHORIZED"
	if not _known_target(target_device_id):
		return "UNKNOWN_TARGET"
	if assigned_role == ROLE_TECHNICIAN and target_device_id not in [TARGET_SESSION]:
		var player_position: Vector3 = _player_positions[sender_peer_id]
		var target_position: Vector3 = device_positions().get(target_device_id, Vector3.INF)
		if not target_position.is_finite() or player_position.distance_to(target_position) > _network_tuning.interaction_range_meters:
			return "OUT_OF_RANGE"
	var expected_revision := int(command.get("target_revision", -1))
	if expected_revision >= 0 and target_device_id in EquipmentSystem.mvp_device_ids():
		var components: Dictionary = _simulation.create_snapshot().components
		if not components.has(str(target_device_id)) or int(components[str(target_device_id)]["revision"]) != expected_revision:
			return "STALE_TARGET_REVISION"
	if applying and _session_state != SESSION_IN_SHIFT:
		return "SHIFT_NOT_RUNNING"
	return ""


func _role_allows_action(role: StringName, target: StringName, action: StringName) -> bool:
	if role == ROLE_OPERATOR:
		return (
			(target == TARGET_PLANT and action == &"set_requested_load")
			or (target == TARGET_ALARMS and action == &"acknowledge_alarm")
			or (target == TARGET_SESSION and action == &"request_end_shift")
		)
	if role != ROLE_TECHNICIAN:
		return false
	if target == TARGET_SESSION:
		return action == &"confirm_end_shift"
	if target == EquipmentSystem.PUMP_A_ID:
		return action in [&"inspect", &"start", &"stop"]
	if target == EquipmentSystem.PUMP_B_ID:
		return action in [&"inspect", &"start", &"stop", &"service_bearing"]
	if target == EquipmentSystem.VALVE_A_ID or target == EquipmentSystem.VALVE_B_ID:
		return action in [&"inspect", &"set_position"]
	if target == EquipmentSystem.BREAKER_A_ID:
		return action in [&"inspect", &"open", &"reset"]
	if target == EquipmentSystem.LOCAL_GAUGE_ID:
		return action == &"inspect"
	return false


func _known_target(target_device_id: StringName) -> bool:
	return (
		target_device_id in EquipmentSystem.mvp_device_ids()
		or target_device_id in [TARGET_PLANT, TARGET_ALARMS, TARGET_SESSION]
	)


func _request_end_shift(peer_id: int) -> Dictionary:
	if _end_shift_requester_peer_id != 0:
		return {"accepted": false, "reason": "END_SHIFT_ALREADY_PENDING", "revision": -1, "result": {}}
	_end_shift_requester_peer_id = peer_id
	_end_shift_confirmations = {peer_id: true}
	_end_shift_remaining_seconds = _network_tuning.end_shift_confirmation_seconds
	return {"accepted": true, "reason": "", "revision": -1, "result": {}}


func _confirm_end_shift(peer_id: int) -> Dictionary:
	if _end_shift_requester_peer_id == 0:
		return {"accepted": false, "reason": "NO_END_SHIFT_REQUEST", "revision": -1, "result": {}}
	_end_shift_confirmations[peer_id] = true
	if _end_shift_confirmations.size() == _peers.size():
		_session_state = SESSION_ENDED
		_end_shift_remaining_seconds = 0.0
	return {"accepted": true, "reason": "", "revision": -1, "result": {}}


func _session_view() -> Dictionary:
	return {
		"state": str(_session_state),
		"state_revision": _state_revision,
		"end_shift_requester_peer_id": _end_shift_requester_peer_id,
		"end_shift_confirmed_peer_ids": _end_shift_confirmations.keys(),
		"end_shift_remaining_seconds": _end_shift_remaining_seconds,
	}


func _reject_immediately(sender_peer_id: int, command: Dictionary, reason: String) -> Dictionary:
	var result := {
		"accepted": false,
		"queued": false,
		"command_id": String(command.get("command_id", "")),
		"actor_peer_id": sender_peer_id,
		"target_device_id": String(command.get("target_device_id", "")),
		"action_id": String(command.get("action_id", "")),
		"reason": reason,
		"revision": -1,
		"state_revision": _state_revision,
		"server_sequence": -1,
		"applied_tick": get_simulation_tick(),
		"result": {},
	}
	_completed_results.append(result)
	return result


func _command_result(
	command: Dictionary,
	accepted: bool,
	reason: String,
	revision: int = -1,
	result: Dictionary = {}
) -> Dictionary:
	return {
		"accepted": accepted,
		"queued": false,
		"command_id": String(command.get("command_id", "")),
		"actor_peer_id": int(command.get("actor_peer_id", 0)),
		"target_device_id": String(command.get("target_device_id", "")),
		"action_id": String(command.get("action_id", "")),
		"reason": reason,
		"revision": revision,
		"state_revision": _state_revision,
		"server_sequence": int(command.get("server_sequence", -1)),
		"applied_tick": get_simulation_tick(),
		"result": result.duplicate(true),
	}


func _result(accepted: bool, command_id: String, reason: String) -> Dictionary:
	return {"accepted": accepted, "command_id": command_id, "reason": reason}


func _position_in_bounds(position: Vector3) -> bool:
	return (
		position.x >= _network_tuning.movement_minimum_bounds.x
		and position.x <= _network_tuning.movement_maximum_bounds.x
		and position.y >= _network_tuning.movement_minimum_bounds.y
		and position.y <= _network_tuning.movement_maximum_bounds.y
		and position.z >= _network_tuning.movement_minimum_bounds.z
		and position.z <= _network_tuning.movement_maximum_bounds.z
	)
