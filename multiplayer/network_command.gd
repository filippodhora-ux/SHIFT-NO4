class_name NetworkCommand
extends RefCounted


static func create(
	command_id: String,
	actor_peer_id: int,
	actor_role: StringName,
	target_device_id: StringName,
	action_id: StringName,
	parameters: Dictionary,
	requested_tick: int,
	target_revision: int = -1
) -> Dictionary:
	return {
		"command_id": command_id,
		"actor_peer_id": actor_peer_id,
		"actor_role": str(actor_role),
		"target_device_id": str(target_device_id),
		"action_id": str(action_id),
		"parameters": parameters.duplicate(true),
		"requested_tick": requested_tick,
		"target_revision": target_revision,
	}


static func structure_error(command: Dictionary) -> String:
	var required_fields: Array[String] = [
		"command_id",
		"actor_peer_id",
		"actor_role",
		"target_device_id",
		"action_id",
		"parameters",
		"requested_tick",
	]
	for field_name in required_fields:
		if not command.has(field_name):
			return "MISSING_%s" % field_name.to_upper()
	if not command["command_id"] is String or String(command["command_id"]).is_empty():
		return "INVALID_COMMAND_ID"
	if not command["actor_peer_id"] is int or int(command["actor_peer_id"]) <= 0:
		return "INVALID_ACTOR_PEER_ID"
	if not command["actor_role"] is String or String(command["actor_role"]).is_empty():
		return "INVALID_ACTOR_ROLE"
	if not command["target_device_id"] is String or String(command["target_device_id"]).is_empty():
		return "INVALID_TARGET_DEVICE_ID"
	if not command["action_id"] is String or String(command["action_id"]).is_empty():
		return "INVALID_ACTION_ID"
	if not command["parameters"] is Dictionary:
		return "INVALID_PARAMETERS"
	if not command["requested_tick"] is int or int(command["requested_tick"]) < 0:
		return "INVALID_REQUESTED_TICK"
	if command.has("target_revision") and not command["target_revision"] is int:
		return "INVALID_TARGET_REVISION"
	return ""
