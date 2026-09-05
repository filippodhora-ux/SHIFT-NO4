class_name NetworkSessionManager
extends Node

signal connection_state_changed(state: String, detail: String)
signal lobby_state_changed(lobby_snapshot: Dictionary)
signal lobby_action_result(action: String, result: Dictionary)
signal role_snapshot_received(snapshot: Dictionary)
signal command_result_received(command_result: Dictionary)
signal session_state_changed(state: String)

const DEFAULT_PLANT_TUNING := preload("res://data/plant/default_plant_tuning.tres")
const DEFAULT_NETWORK_TUNING := preload("res://data/network/default_network_tuning.tres")

var _gateway: AuthorityGateway
var _snapshot_store := RoleSnapshotStore.new()
var _connection_state: String = "OFFLINE"
var _connection_detail: String = "Choose Host or Join."
var _lobby_snapshot: Dictionary = {}
var _command_counter: int = 0
var _snapshot_accumulator_seconds: float = 0.0
var _latest_command_id: String = ""
var _latest_command_accepted: bool = false
var _last_session_state: String = ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	set_process(true)


func _process(delta: float) -> void:
	if _gateway == null or not multiplayer.is_server():
		return
	_gateway.advance(delta)
	_dispatch_completed_results()
	_snapshot_accumulator_seconds += delta
	var interval := _gateway.get_network_tuning().snapshot_interval_seconds
	if _snapshot_accumulator_seconds >= interval:
		_snapshot_accumulator_seconds = fmod(_snapshot_accumulator_seconds, interval)
		_broadcast_role_snapshots()
	_emit_session_state_if_changed()


func host(port: int) -> Dictionary:
	shutdown()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 1)
	if error != OK:
		_set_connection_state("ERROR", "Host failed on port %d: %s" % [port, error_string(error)])
		return {"accepted": false, "reason": "HOST_CREATE_FAILED", "error": error}
	multiplayer.multiplayer_peer = peer
	var plant_tuning := DEFAULT_PLANT_TUNING.duplicate(true) as PlantTuning
	var network_tuning := DEFAULT_NETWORK_TUNING.duplicate(true) as NetworkTuning
	_gateway = AuthorityGateway.new(plant_tuning, network_tuning)
	_gateway.register_peer(multiplayer.get_unique_id())
	_set_connection_state("LISTENING", "Listening on UDP port %d." % port)
	_broadcast_lobby_state()
	return {"accepted": true, "reason": ""}


func join(address: String, port: int) -> Dictionary:
	shutdown()
	if address.strip_edges().is_empty():
		return {"accepted": false, "reason": "ADDRESS_REQUIRED"}
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port)
	if error != OK:
		_set_connection_state("ERROR", "Join failed: %s" % error_string(error))
		return {"accepted": false, "reason": "CLIENT_CREATE_FAILED", "error": error}
	multiplayer.multiplayer_peer = peer
	_set_connection_state("CONNECTING", "Connecting to %s:%d..." % [address.strip_edges(), port])
	return {"accepted": true, "reason": ""}


func shutdown() -> void:
	var current_peer := multiplayer.multiplayer_peer
	if current_peer != null and not (current_peer is OfflineMultiplayerPeer):
		current_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_gateway = null
	_lobby_snapshot.clear()
	_snapshot_store.reset()
	_command_counter = 0
	_latest_command_id = ""
	_latest_command_accepted = false
	_snapshot_accumulator_seconds = 0.0
	_last_session_state = ""
	_set_connection_state("OFFLINE", "Choose Host or Join.")


func choose_role(role: StringName) -> Dictionary:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return {"accepted": false, "reason": "NOT_CONNECTED"}
	if multiplayer.is_server():
		var result := _gateway.request_role(multiplayer.get_unique_id(), role)
		_broadcast_lobby_state()
		lobby_action_result.emit("choose_role", result.duplicate(true))
		return result
	_server_request_role.rpc_id(1, str(role))
	return {"accepted": true, "queued": true, "reason": ""}


func set_ready(ready: bool) -> Dictionary:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return {"accepted": false, "reason": "NOT_CONNECTED"}
	if multiplayer.is_server():
		var result := _gateway.set_ready(multiplayer.get_unique_id(), ready)
		_broadcast_lobby_state()
		_broadcast_role_snapshots()
		_emit_session_state_if_changed()
		lobby_action_result.emit("set_ready", result.duplicate(true))
		return result
	_server_set_ready.rpc_id(1, ready)
	return {"accepted": true, "queued": true, "reason": ""}


func submit_gameplay_command(
	target_device_id: StringName,
	action_id: StringName,
	parameters: Dictionary = {},
	target_revision: int = -1
) -> Dictionary:
	var peer_id := multiplayer.get_unique_id()
	var role := get_assigned_role()
	if peer_id <= 0 or role.is_empty():
		return {"accepted": false, "queued": false, "reason": "ROLE_NOT_ASSIGNED", "command_id": ""}
	_command_counter += 1
	var command_id := "%d:%d" % [peer_id, _command_counter]
	var command := NetworkCommand.create(
		command_id,
		peer_id,
		role,
		target_device_id,
		action_id,
		parameters,
		_snapshot_store.get_authoritative_tick(),
		target_revision
	)
	return submit_raw_command(command)


func submit_raw_command(command: Dictionary) -> Dictionary:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return {"accepted": false, "queued": false, "reason": "NOT_CONNECTED", "command_id": String(command.get("command_id", ""))}
	if multiplayer.is_server():
		var result := _gateway.submit_command(multiplayer.get_unique_id(), command)
		_dispatch_completed_results()
		return result
	_server_receive_command.rpc_id(1, command)
	return {
		"accepted": true,
		"queued": true,
		"reason": "",
		"command_id": String(command.get("command_id", "")),
	}


func send_technician_position(position: Vector3, client_tick: int) -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	if multiplayer.is_server():
		_gateway.update_player_position(multiplayer.get_unique_id(), position, client_tick)
	else:
		_server_receive_movement.rpc_id(1, position, client_tick)


func force_snapshot_for_test() -> void:
	if _gateway != null and multiplayer.is_server():
		_broadcast_role_snapshots()


func get_snapshot_store() -> RoleSnapshotStore:
	return _snapshot_store


func get_gateway() -> AuthorityGateway:
	return _gateway


func get_connection_state() -> String:
	return _connection_state


func get_connection_detail() -> String:
	return _connection_detail


func get_assigned_role() -> StringName:
	var peer_id := multiplayer.get_unique_id()
	if _gateway != null and multiplayer.is_server():
		return _gateway.get_peer_role(peer_id)
	var peers: Dictionary = _lobby_snapshot.get("peers", {})
	var peer: Dictionary = peers.get(str(peer_id), {})
	return StringName(peer.get("role", ""))


func get_session_state() -> StringName:
	if _gateway != null and multiplayer.is_server():
		return _gateway.get_session_state()
	return StringName(_lobby_snapshot.get("session_state", AuthorityGateway.SESSION_LOBBY))


func get_lobby_snapshot() -> Dictionary:
	return _lobby_snapshot.duplicate(true)


func get_debug_view() -> Dictionary:
	return {
		"peer_id": multiplayer.get_unique_id(),
		"network_role": "HOST" if _gateway != null and multiplayer.is_server() else "CLIENT",
		"assigned_role": str(get_assigned_role()),
		"connection_state": _connection_state,
		"simulation_tick": _gateway.get_simulation_tick() if _gateway != null else 0,
		"latest_snapshot_revision": _snapshot_store.get_latest_revision(),
		"latest_command_id": _latest_command_id,
		"latest_command_result": "ACCEPT" if _latest_command_accepted else "REJECT",
	}


@rpc("any_peer", "call_remote", "reliable")
func _server_request_role(role_text: String) -> void:
	if not multiplayer.is_server() or _gateway == null:
		return
	var sender_peer_id := multiplayer.get_remote_sender_id()
	var result := _gateway.request_role(sender_peer_id, StringName(role_text))
	_client_receive_lobby_action_result.rpc_id(sender_peer_id, "choose_role", result)
	_broadcast_lobby_state()


@rpc("any_peer", "call_remote", "reliable")
func _server_set_ready(ready: bool) -> void:
	if not multiplayer.is_server() or _gateway == null:
		return
	var sender_peer_id := multiplayer.get_remote_sender_id()
	var result := _gateway.set_ready(sender_peer_id, ready)
	_client_receive_lobby_action_result.rpc_id(sender_peer_id, "set_ready", result)
	_broadcast_lobby_state()
	_broadcast_role_snapshots()
	_emit_session_state_if_changed()


@rpc("any_peer", "call_remote", "reliable")
func _server_receive_command(command: Dictionary) -> void:
	if not multiplayer.is_server() or _gateway == null:
		return
	var sender_peer_id := multiplayer.get_remote_sender_id()
	_gateway.submit_command(sender_peer_id, command)
	_dispatch_completed_results()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _server_receive_movement(position: Vector3, client_tick: int) -> void:
	if not multiplayer.is_server() or _gateway == null:
		return
	_gateway.update_player_position(multiplayer.get_remote_sender_id(), position, client_tick)


@rpc("authority", "call_remote", "reliable")
func _client_receive_lobby_state(snapshot: Dictionary) -> void:
	_lobby_snapshot = snapshot.duplicate(true)
	lobby_state_changed.emit(get_lobby_snapshot())
	_emit_session_state_if_changed()


@rpc("authority", "call_remote", "reliable")
func _client_receive_role_snapshot(snapshot: Dictionary) -> void:
	if _snapshot_store.apply_snapshot(snapshot):
		var session_view: Dictionary = snapshot.get("session", {})
		if session_view.has("state"):
			_lobby_snapshot["session_state"] = String(session_view["state"])
		role_snapshot_received.emit(snapshot.duplicate(true))
		_emit_session_state_if_changed()


@rpc("authority", "call_remote", "reliable")
func _client_receive_command_result(command_result: Dictionary) -> void:
	_receive_command_result(command_result)


@rpc("authority", "call_remote", "reliable")
func _client_receive_lobby_action_result(action: String, result: Dictionary) -> void:
	lobby_action_result.emit(action, result.duplicate(true))


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server() or _gateway == null:
		return
	var result := _gateway.register_peer(peer_id)
	if not bool(result["accepted"]):
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	_set_connection_state("CONNECTED", "Client %d connected." % peer_id)
	_broadcast_lobby_state()


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server() or _gateway == null:
		return
	_gateway.disconnect_peer(peer_id)
	_set_connection_state("PEER_DISCONNECTED", "Peer %d disconnected; session stopped." % peer_id)
	_broadcast_lobby_state()
	_emit_session_state_if_changed()


func _on_connected_to_server() -> void:
	_set_connection_state("CONNECTED", "Connected to host as peer %d." % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	_set_connection_state("ERROR", "Could not connect to host.")


func _on_server_disconnected() -> void:
	_set_connection_state("SERVER_DISCONNECTED", "Host disconnected; session stopped.")
	_lobby_snapshot["session_state"] = str(AuthorityGateway.SESSION_DISCONNECTED)
	_emit_session_state_if_changed()


func _broadcast_lobby_state() -> void:
	if _gateway == null:
		return
	_lobby_snapshot = _gateway.get_lobby_snapshot()
	lobby_state_changed.emit(get_lobby_snapshot())
	for peer_id_text in _lobby_snapshot["peers"]:
		var peer_id := int(peer_id_text)
		if peer_id != multiplayer.get_unique_id():
			_client_receive_lobby_state.rpc_id(peer_id, _lobby_snapshot)


func _broadcast_role_snapshots() -> void:
	if _gateway == null or _gateway.get_simulation() == null:
		return
	var snapshots := _gateway.create_role_snapshots()
	for peer_id in snapshots:
		var snapshot: Dictionary = snapshots[peer_id]
		if int(peer_id) == multiplayer.get_unique_id():
			if _snapshot_store.apply_snapshot(snapshot):
				role_snapshot_received.emit(snapshot.duplicate(true))
		else:
			_client_receive_role_snapshot.rpc_id(int(peer_id), snapshot)


func _dispatch_completed_results() -> void:
	if _gateway == null:
		return
	var completed_results := _gateway.take_completed_results()
	if completed_results.is_empty():
		return
	for command_result in completed_results:
		var peer_id := int(command_result["actor_peer_id"])
		if peer_id == multiplayer.get_unique_id():
			_receive_command_result(command_result)
		elif multiplayer.get_peers().has(peer_id):
			_client_receive_command_result.rpc_id(peer_id, command_result)
	_broadcast_role_snapshots()


func _receive_command_result(command_result: Dictionary) -> void:
	_latest_command_id = String(command_result.get("command_id", ""))
	_latest_command_accepted = bool(command_result.get("accepted", false))
	_snapshot_store.apply_command_result(command_result)
	command_result_received.emit(command_result.duplicate(true))


func _emit_session_state_if_changed() -> void:
	var current_state := str(get_session_state())
	if current_state == _last_session_state:
		return
	_last_session_state = current_state
	session_state_changed.emit(current_state)


func _set_connection_state(state: String, detail: String) -> void:
	_connection_state = state
	_connection_detail = detail
	connection_state_changed.emit(state, detail)
