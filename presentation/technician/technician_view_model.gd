class_name TechnicianViewModel
extends RefCounted

var _simulation: PlantSimulation
var _snapshot_store: RoleSnapshotStore
var _command_sender: Callable
var _last_feedback: String = "Field channel ready."


func _init(source: Variant, command_sender: Callable = Callable()) -> void:
	assert(source is PlantSimulation or source is RoleSnapshotStore, "TechnicianViewModel requires a simulation or role snapshot store")
	if source is PlantSimulation:
		_simulation = source as PlantSimulation
	else:
		_snapshot_store = source as RoleSnapshotStore
	_command_sender = command_sender


func create_hud_view() -> Dictionary:
	return {
		"role": "TECHNICIAN",
		"feedback": _last_feedback,
	}


func get_focus_view(device_id: StringName) -> Dictionary:
	var device_view := (
		_simulation.create_technician_device_view(device_id)
		if _simulation != null
		else _snapshot_store.get_technician_device_view(device_id)
	)
	if device_view.is_empty():
		return {}
	var focus_view := {
		"device_id": str(device_id),
		"display_name": device_view["display_name"],
		"actions": _available_actions(device_id, device_view),
	}
	if bool(device_view.get("service_active", false)):
		focus_view["local_status"] = "SERVICE IN PROGRESS — %.1fs" % float(device_view["service_remaining_seconds"])
	return focus_view


func perform_input_action(device_id: StringName, input_action: StringName) -> Dictionary:
	var focus_view := get_focus_view(device_id)
	if focus_view.is_empty():
		return _feedback_result(false, "UNKNOWN_TARGET", "No supported device in focus.")
	for action in focus_view["actions"]:
		if action["input_action"] == input_action:
			return perform_action(device_id, StringName(action["action_id"]), action.get("parameters", {}))
	return _feedback_result(false, "ACTION_NOT_AVAILABLE", "That action is not available now.")


func perform_action(
	device_id: StringName,
	action_id: StringName,
	parameters: Dictionary = {}
) -> Dictionary:
	var command_result: Dictionary
	if _simulation != null:
		command_result = _simulation.execute_command(device_id, action_id, parameters)
	else:
		command_result = _command_sender.call(device_id, action_id, parameters)
	if bool(command_result.get("queued", false)):
		_last_feedback = "%s command sent to host." % device_id
		command_result["feedback"] = _last_feedback
		return command_result
	if not command_result["accepted"]:
		_last_feedback = _reason_text(String(command_result["reason"]))
		command_result["feedback"] = _last_feedback
		return command_result

	if action_id == &"inspect":
		var inspection: Dictionary = command_result["result"]
		_last_feedback = String(inspection.get("inspection_text", "Inspection complete."))
		if inspection.has("sound_caption"):
			_last_feedback += "  %s" % inspection["sound_caption"]
	else:
		_last_feedback = _accepted_text(device_id, action_id)
	command_result["feedback"] = _last_feedback
	return command_result


func apply_command_result(command_result: Dictionary) -> void:
	if not bool(command_result.get("accepted", false)):
		_last_feedback = _reason_text(String(command_result.get("reason", "REJECTED")))
		return
	var action_id := StringName(command_result.get("action_id", ""))
	var device_id := StringName(command_result.get("target_device_id", ""))
	if action_id == &"inspect":
		var inspection: Dictionary = command_result.get("result", {})
		_last_feedback = String(inspection.get("inspection_text", "Inspection complete."))
		if inspection.has("sound_caption"):
			_last_feedback += "  %s" % inspection["sound_caption"]
	else:
		_last_feedback = _accepted_text(device_id, action_id)


func _available_actions(device_id: StringName, device_view: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	actions.append(_action("technician_inspect", "E", "Inspect", &"inspect"))
	match String(device_view["device_type"]):
		"PUMP":
			if bool(device_view.get("service_active", false)):
				return actions
			if bool(device_view["enabled"]):
				actions.append(_action("technician_operate", "F", "Stop", &"stop"))
			else:
				actions.append(_action("technician_operate", "F", "Start", &"start"))
			if device_id == EquipmentSystem.PUMP_B_ID and not bool(device_view["enabled"]):
				actions.append(_action("technician_service", "R", "Service pump assembly", &"service_bearing"))
		"VALVE":
			var next_position := 1.0 if float(device_view["actual_position"]) < 0.5 else 0.0
			var label := "Open" if next_position > 0.5 else "Close"
			actions.append(_action("technician_operate", "F", label, &"set_position", {"position": next_position}))
		"BREAKER":
			if device_view["physical_state"] == "CLOSED":
				actions.append(_action("technician_operate", "F", "Open", &"open"))
			else:
				actions.append(_action("technician_operate", "F", "Reset", &"reset"))
		_:
			pass
	return actions


func _action(
	input_action: String,
	key_label: String,
	label: String,
	action_id: StringName,
	parameters: Dictionary = {}
) -> Dictionary:
	return {
		"input_action": input_action,
		"key_label": key_label,
		"label": label,
		"action_id": str(action_id),
		"parameters": parameters.duplicate(true),
	}


func _feedback_result(accepted: bool, reason: String, feedback: String) -> Dictionary:
	_last_feedback = feedback
	return {"accepted": accepted, "reason": reason, "feedback": feedback}


func _accepted_text(device_id: StringName, action_id: StringName) -> String:
	match action_id:
		&"start":
			return "%s start command accepted." % device_id
		&"stop":
			return "%s stop command accepted." % device_id
		&"set_position":
			return "%s physical position changed." % device_id
		&"open":
			return "%s opened." % device_id
		&"reset":
			return "%s reset." % device_id
		&"service_bearing":
			return "%s service started. Keep the pump stopped." % device_id
		_:
			return "%s action accepted." % device_id


func _reason_text(reason: String) -> String:
	match reason:
		"PUMP_MUST_BE_STOPPED":
			return "Service rejected: stop P-B first."
		"SERVICE_IN_PROGRESS":
			return "Service is already in progress."
		"OUT_OF_RANGE":
			return "Action rejected by host: device is out of physical range."
		"ROLE_NOT_AUTHORIZED":
			return "Action rejected by host: role is not authorized."
		"STALE_TARGET_REVISION":
			return "Action rejected by host: device state changed; inspect again."
		"DUPLICATE_COMMAND_ID":
			return "Duplicate command ignored by host."
		"NO_SERVICE_NEEDED":
			return "Service rejected: no measurable service need."
		"UNSUPPORTED_ACTION":
			return "This device does not support that action."
		_:
			return "Action rejected: %s." % reason
