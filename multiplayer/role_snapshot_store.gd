class_name RoleSnapshotStore
extends RefCounted

var _latest_revision: int = -1
var _role: StringName = &""
var _snapshot: Dictionary = {}
var _inspection_results: Dictionary = {}


func reset() -> void:
	_latest_revision = -1
	_role = &""
	_snapshot.clear()
	_inspection_results.clear()


func apply_snapshot(snapshot: Dictionary) -> bool:
	if not snapshot.has("revision") or not snapshot["revision"] is int:
		return false
	var revision := int(snapshot["revision"])
	if revision <= _latest_revision:
		return false
	if not snapshot.has("role"):
		return false
	var role := StringName(snapshot["role"])
	if role != AuthorityGateway.ROLE_OPERATOR and role != AuthorityGateway.ROLE_TECHNICIAN:
		return false
	_latest_revision = revision
	_role = role
	_snapshot = snapshot.duplicate(true)
	return true


func apply_command_result(command_result: Dictionary) -> void:
	if not bool(command_result.get("accepted", false)):
		return
	if String(command_result.get("action_id", "")) != "inspect":
		return
	var target_device_id := String(command_result.get("target_device_id", ""))
	var result: Dictionary = command_result.get("result", {})
	if not target_device_id.is_empty() and not result.is_empty():
		_inspection_results[target_device_id] = result.duplicate(true)


func get_latest_revision() -> int:
	return _latest_revision


func get_role() -> StringName:
	return _role


func get_authoritative_tick() -> int:
	return int(_snapshot.get("tick", 0))


func get_operator_snapshot() -> Dictionary:
	if _role != AuthorityGateway.ROLE_OPERATOR:
		return {}
	return _snapshot.duplicate(true)


func get_technician_snapshot() -> Dictionary:
	if _role != AuthorityGateway.ROLE_TECHNICIAN:
		return {}
	return _snapshot.duplicate(true)


func get_technician_device_view(device_id: StringName) -> Dictionary:
	if _role != AuthorityGateway.ROLE_TECHNICIAN:
		return {}
	var world_devices: Dictionary = _snapshot.get("world_devices", {})
	return Dictionary(world_devices.get(str(device_id), {})).duplicate(true)


func get_inspection_result(device_id: StringName) -> Dictionary:
	return Dictionary(_inspection_results.get(str(device_id), {})).duplicate(true)
