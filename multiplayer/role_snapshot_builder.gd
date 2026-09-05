class_name RoleSnapshotBuilder
extends RefCounted


static func operator_snapshot(
	simulation: PlantSimulation,
	revision: int,
	session_view: Dictionary,
	player_positions: Dictionary
) -> Dictionary:
	var payload := simulation.create_operator_snapshot()
	payload["revision"] = revision
	payload["role"] = str(AuthorityGateway.ROLE_OPERATOR)
	payload["session"] = session_view.duplicate(true)
	payload["player_positions"] = _serialized_positions(player_positions)
	return payload


static func technician_snapshot(
	simulation: PlantSimulation,
	revision: int,
	session_view: Dictionary,
	position: Vector3,
	device_positions: Dictionary,
	visibility_range_meters: float,
	player_positions: Dictionary
) -> Dictionary:
	var world_devices: Dictionary = {}
	for device_id_variant in device_positions:
		var device_id := StringName(device_id_variant)
		var device_position: Vector3 = device_positions[device_id_variant]
		if position.distance_to(device_position) <= visibility_range_meters:
			world_devices[str(device_id)] = simulation.create_technician_device_view(device_id)
	return {
		"revision": revision,
		"role": str(AuthorityGateway.ROLE_TECHNICIAN),
		"tick": simulation.create_snapshot().tick,
		"session": session_view.duplicate(true),
		"world_devices": world_devices,
		"player_positions": _serialized_positions(player_positions),
	}


static func _serialized_positions(player_positions: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for peer_id in player_positions:
		var position: Vector3 = player_positions[peer_id]
		result[str(peer_id)] = {"x": position.x, "y": position.y, "z": position.z}
	return result
