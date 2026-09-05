extends SceneTree

const DEFAULT_PLANT_TUNING := preload("res://data/plant/default_plant_tuning.tres")
const DEFAULT_NETWORK_TUNING := preload("res://data/network/default_network_tuning.tres")

var _passed_count: int = 0
var _failed_count: int = 0


func _initialize() -> void:
	print("[NET-TEST] SHIFT №4 M4 authority and replication")
	_run_test("unique_role_assignment_starts_two_player_shift", _test_role_assignment)
	_run_test("host_is_only_authoritative_simulation_owner", _test_authority_owner)
	_run_test("technician_in_range_command_is_accepted", _test_command_accept)
	_run_test("technician_out_of_range_command_is_rejected", _test_range_rejection)
	_run_test("movement_is_server_validated_for_speed_and_order", _test_movement_validation)
	_run_test("operator_field_command_is_rejected", _test_role_rejection)
	_run_test("duplicate_command_id_applies_at_most_once", _test_duplicate_command)
	_run_test("same_tick_commands_follow_server_sequence", _test_command_ordering)
	_run_test("stale_snapshot_cannot_overwrite_newer_revision", _test_stale_revision)
	_run_test("snapshot_store_reset_accepts_new_session_revision", _test_snapshot_store_reset)
	_run_test("stale_component_revision_is_rejected", _test_stale_component_revision)
	_run_test("role_payloads_are_filtered_before_serialization", _test_payload_filter)
	_run_test("lying_sensor_network_payload_preserves_split_truth", _test_lying_sensor_network)
	_run_test("technician_stop_cascades_to_operator_snapshot", _test_authoritative_cascade)
	_run_test("prerequisite_rejection_does_not_change_state_revision", _test_prerequisite_rejection)
	_run_test("coordinated_end_shift_requires_both_roles", _test_end_shift_confirmation)
	_run_test("disconnect_clears_pending_end_shift_and_stops_session", _test_disconnect)
	print("[NET-TEST] SUMMARY passed=%d failed=%d" % [_passed_count, _failed_count])
	quit(0 if _failed_count == 0 else 1)


func _run_test(test_name: String, test_callable: Callable) -> void:
	var raw_result: Variant = test_callable.call()
	var failure: String = raw_result if raw_result is String else "test did not return String"
	if String(failure).is_empty():
		_passed_count += 1
		print("[NET-TEST] PASS %s" % test_name)
	else:
		_failed_count += 1
		printerr("[NET-TEST] FAIL %s: %s" % [test_name, failure])


func _test_role_assignment() -> String:
	var gateway := _create_gateway(false)
	if not gateway.register_peer(1)["accepted"] or not gateway.register_peer(2)["accepted"]:
		return "could not register host and client"
	if not gateway.request_role(1, AuthorityGateway.ROLE_OPERATOR)["accepted"]:
		return "Operator assignment was rejected"
	var duplicate := gateway.request_role(2, AuthorityGateway.ROLE_OPERATOR)
	if duplicate["accepted"] or duplicate["reason"] != "ROLE_TAKEN":
		return "duplicate Operator role was not rejected"
	if not gateway.request_role(2, AuthorityGateway.ROLE_TECHNICIAN)["accepted"]:
		return "Technician assignment was rejected"
	gateway.set_ready(1, true)
	if gateway.get_session_state() != AuthorityGateway.SESSION_LOBBY:
		return "shift started before both peers were ready"
	gateway.set_ready(2, true)
	if gateway.get_session_state() != AuthorityGateway.SESSION_IN_SHIFT:
		return "valid unique ready roles did not start the shift"
	return ""


func _test_authority_owner() -> String:
	var gateway := _create_gateway()
	var client_store := RoleSnapshotStore.new()
	if gateway.get_simulation() == null:
		return "host did not create its authoritative PlantSimulation"
	gateway.run_ticks(12)
	var snapshots := gateway.create_role_snapshots()
	if not client_store.apply_snapshot(snapshots[2]):
		return "client snapshot store did not accept Technician payload"
	if gateway.get_simulation_tick() != 12:
		return "host simulation did not execute exactly 12 steps"
	if client_store.get_technician_snapshot()["tick"] != 12:
		return "client did not observe the host tick"
	if "simulation" in client_store:
		return "client snapshot store unexpectedly owns a simulation"
	return ""


func _test_command_accept() -> String:
	var gateway := _create_gateway()
	gateway.debug_set_player_position_for_test(2, AuthorityGateway.device_positions()[EquipmentSystem.PUMP_B_ID])
	var revision_before := gateway.get_state_revision()
	var queued := gateway.submit_command(2, _command("accept-stop", 2, AuthorityGateway.ROLE_TECHNICIAN, &"P-B", &"stop"))
	if not queued["accepted"] or not queued["queued"]:
		return "in-range stop was not queued"
	gateway.run_ticks(1)
	var result := _result_for(gateway.take_completed_results(), "accept-stop")
	if result.is_empty() or not result["accepted"]:
		return "in-range stop was rejected at apply"
	if gateway.get_simulation().create_snapshot().components["P-B"]["enabled"]:
		return "accepted command did not stop authoritative P-B"
	if gateway.get_state_revision() <= revision_before:
		return "accepted mutation did not advance state revision"
	return ""


func _test_range_rejection() -> String:
	var gateway := _create_gateway()
	var revision_before := gateway.get_state_revision()
	var enabled_before: bool = gateway.get_simulation().create_snapshot().components["P-B"]["enabled"]
	var result := gateway.submit_command(2, _command("far-stop", 2, AuthorityGateway.ROLE_TECHNICIAN, &"P-B", &"stop"))
	if result["accepted"] or result["reason"] != "OUT_OF_RANGE":
		return "out-of-range stop was not rejected with OUT_OF_RANGE"
	if gateway.get_state_revision() != revision_before:
		return "range rejection changed state revision"
	if gateway.get_simulation().create_snapshot().components["P-B"]["enabled"] != enabled_before:
		return "range rejection changed authoritative P-B"
	return ""


func _test_movement_validation() -> String:
	var gateway := _create_gateway()
	var spawn := gateway.get_player_position(2)
	var too_fast := gateway.update_player_position(2, spawn + Vector3(4.0, 0.0, 0.0), 1)
	if too_fast["accepted"] or too_fast["reason"] != "MOVEMENT_TOO_FAST":
		return "implausible movement was not rejected"
	var valid := gateway.update_player_position(2, spawn + Vector3(0.5, 0.0, 0.0), 1)
	if not valid["accepted"]:
		return "bounded movement was rejected"
	var stale := gateway.update_player_position(2, spawn + Vector3(0.6, 0.0, 0.0), 1)
	if stale["accepted"] or stale["reason"] != "STALE_MOVEMENT":
		return "out-of-order movement was not rejected"
	var operator_move := gateway.update_player_position(1, spawn, 1)
	if operator_move["accepted"] or operator_move["reason"] != "ROLE_NOT_AUTHORIZED":
		return "Operator movement update was not rejected"
	return ""


func _test_role_rejection() -> String:
	var gateway := _create_gateway()
	var result := gateway.submit_command(1, _command("operator-stop", 1, AuthorityGateway.ROLE_OPERATOR, &"P-B", &"stop"))
	if result["accepted"] or result["reason"] != "ROLE_NOT_AUTHORIZED":
		return "Operator field action was not rejected by role"
	return ""


func _test_duplicate_command() -> String:
	var gateway := _create_gateway()
	gateway.debug_set_player_position_for_test(2, AuthorityGateway.device_positions()[EquipmentSystem.PUMP_B_ID])
	var command := _command("same-id", 2, AuthorityGateway.ROLE_TECHNICIAN, &"P-B", &"stop")
	var first := gateway.submit_command(2, command)
	var second := gateway.submit_command(2, command)
	if not first["accepted"] or second["accepted"] or second["reason"] != "DUPLICATE_COMMAND_ID":
		return "duplicate ID contract was not enforced"
	gateway.run_ticks(1)
	var accepted_count := 0
	for result in gateway.take_completed_results():
		if result["command_id"] == "same-id" and result["accepted"]:
			accepted_count += 1
	if accepted_count != 1:
		return "duplicate command applied %d accepted mutations" % accepted_count
	return ""


func _test_command_ordering() -> String:
	var gateway := _create_gateway()
	gateway.debug_set_player_position_for_test(2, AuthorityGateway.device_positions()[EquipmentSystem.PUMP_B_ID])
	var stop_result := gateway.submit_command(2, _command("ordered-stop", 2, AuthorityGateway.ROLE_TECHNICIAN, &"P-B", &"stop"))
	var start_result := gateway.submit_command(2, _command("ordered-start", 2, AuthorityGateway.ROLE_TECHNICIAN, &"P-B", &"start"))
	if int(stop_result["server_received_tick"]) != int(start_result["server_received_tick"]):
		return "test commands did not share a receipt tick"
	if int(stop_result["server_sequence"]) >= int(start_result["server_sequence"]):
		return "server sequence was not monotonic"
	gateway.run_ticks(1)
	if not gateway.get_simulation().create_snapshot().components["P-B"]["enabled"]:
		return "same-tick commands did not apply by ascending server_sequence"
	return ""


func _test_stale_revision() -> String:
	var store := RoleSnapshotStore.new()
	var newer := {"revision": 12, "role": "OPERATOR", "tick": 12, "actual_power_mw": 700.0}
	var older := {"revision": 11, "role": "OPERATOR", "tick": 11, "actual_power_mw": 100.0}
	if not store.apply_snapshot(newer):
		return "newer revision was rejected"
	if store.apply_snapshot(older):
		return "older revision was accepted"
	if store.get_latest_revision() != 12 or store.get_operator_snapshot()["actual_power_mw"] != 700.0:
		return "older payload overwrote revision 12"
	return ""


func _test_snapshot_store_reset() -> String:
	var store := RoleSnapshotStore.new()
	store.apply_snapshot({"revision": 50, "role": "OPERATOR", "tick": 50})
	store.reset()
	if not store.apply_snapshot({"revision": 1, "role": "TECHNICIAN", "tick": 0, "world_devices": {}}):
		return "new session revision was rejected after reset"
	if store.get_latest_revision() != 1 or store.get_role() != AuthorityGateway.ROLE_TECHNICIAN:
		return "snapshot store reset left stale session state"
	return ""


func _test_stale_component_revision() -> String:
	var gateway := _create_gateway()
	gateway.debug_set_player_position_for_test(2, AuthorityGateway.device_positions()[EquipmentSystem.PUMP_B_ID])
	var current_revision: int = gateway.get_simulation().create_snapshot().components["P-B"]["revision"]
	var result := gateway.submit_command(
		2,
		_command("stale-component", 2, AuthorityGateway.ROLE_TECHNICIAN, &"P-B", &"stop", {}, current_revision + 1)
	)
	if result["accepted"] or result["reason"] != "STALE_TARGET_REVISION":
		return "stale component revision was not rejected"
	return ""


func _test_payload_filter() -> String:
	var gateway := _create_gateway()
	gateway.debug_set_player_position_for_test(2, AuthorityGateway.device_positions()[EquipmentSystem.PUMP_B_ID])
	var snapshots := gateway.create_role_snapshots()
	var operator_payload: Dictionary = snapshots[1]
	var technician_payload: Dictionary = snapshots[2]
	var operator_forbidden := _find_forbidden_key(operator_payload, [
		"condition", "wear", "bearing_condition", "bearing_failure", "failure_id", "phase", "actual_position", "actual_value",
	])
	if not operator_forbidden.is_empty():
		return "Operator serialized payload exposed %s" % operator_forbidden
	var technician_forbidden := _find_forbidden_key(technician_payload, [
		"actual_power_mw", "produced_mwh", "plant_stress", "alarms", "reported_sensors", "coolant_temperature_c",
	])
	if not technician_forbidden.is_empty():
		return "Technician common payload exposed %s" % technician_forbidden
	var serialized_operator := JSON.stringify(operator_payload)
	if "condition" in serialized_operator or "bearing_failure" in serialized_operator:
		return "serialized Operator payload leaked hidden failure data"
	return ""


func _test_lying_sensor_network() -> String:
	var gateway := _create_gateway()
	var simulation := gateway.get_simulation()
	simulation.debug_set_valve_mismatch(&"V-A", 0.0, 1.0)
	gateway.debug_set_player_position_for_test(2, AuthorityGateway.device_positions()[EquipmentSystem.VALVE_A_ID])
	var snapshots := gateway.create_role_snapshots()
	var operator_payload: Dictionary = snapshots[1]
	var technician_payload: Dictionary = snapshots[2]
	if operator_payload["equipment"]["V-A"]["reported_position_state"] != "OPEN":
		return "Operator payload did not report V-A OPEN"
	if operator_payload["equipment"]["V-A"].has("actual_position"):
		return "Operator payload contained V-A actual position"
	if technician_payload["world_devices"]["V-A"]["physical_state"] != "CLOSED":
		return "nearby Technician world payload did not show physical CLOSED"
	return ""


func _test_authoritative_cascade() -> String:
	var gateway := _create_gateway()
	var simulation := gateway.get_simulation()
	simulation.set_requested_load(0.8)
	gateway.run_ticks(100)
	var flow_before: float = simulation.create_operator_snapshot()["coolant_flow_units_per_second"]
	gateway.debug_set_player_position_for_test(2, AuthorityGateway.device_positions()[EquipmentSystem.PUMP_B_ID])
	gateway.submit_command(2, _command("cascade-stop", 2, AuthorityGateway.ROLE_TECHNICIAN, &"P-B", &"stop"))
	gateway.run_ticks(100)
	var flow_after: float = simulation.create_operator_snapshot()["coolant_flow_units_per_second"]
	var snapshots := gateway.create_role_snapshots()
	if not flow_after < flow_before:
		return "host flow did not change after P-B stop"
	if not float(snapshots[1]["coolant_flow_units_per_second"]) < flow_before:
		return "Operator payload did not receive the authoritative flow cascade"
	if snapshots[1]["equipment"]["P-B"]["reported_status"] != "OFF":
		return "Operator payload did not receive P-B OFF"
	return ""


func _test_prerequisite_rejection() -> String:
	var gateway := _create_gateway()
	gateway.debug_set_player_position_for_test(2, AuthorityGateway.device_positions()[EquipmentSystem.PUMP_B_ID])
	gateway.get_simulation().debug_set_component_condition(&"P-B", 0.4)
	var revision_before := gateway.get_state_revision()
	gateway.submit_command(2, _command("service-running", 2, AuthorityGateway.ROLE_TECHNICIAN, &"P-B", &"service_bearing"))
	gateway.run_ticks(1)
	var result := _result_for(gateway.take_completed_results(), "service-running")
	if result.is_empty() or result["accepted"] or result["reason"] != "PUMP_MUST_BE_STOPPED":
		return "running-pump service prerequisite was not rejected"
	if gateway.get_state_revision() != revision_before:
		return "prerequisite rejection changed state revision"
	return ""


func _test_end_shift_confirmation() -> String:
	var gateway := _create_gateway()
	gateway.submit_command(1, _command("end-request", 1, AuthorityGateway.ROLE_OPERATOR, AuthorityGateway.TARGET_SESSION, &"request_end_shift"))
	gateway.run_ticks(1)
	if gateway.get_session_state() != AuthorityGateway.SESSION_IN_SHIFT:
		return "single Operator request ended the shift"
	var operator_snapshot: Dictionary = gateway.create_role_snapshots()[1]
	if operator_snapshot["session"]["end_shift_requester_peer_id"] != 1:
		return "pending end-shift requester was not replicated"
	gateway.submit_command(2, _command("end-confirm", 2, AuthorityGateway.ROLE_TECHNICIAN, AuthorityGateway.TARGET_SESSION, &"confirm_end_shift"))
	gateway.run_ticks(1)
	if gateway.get_session_state() != AuthorityGateway.SESSION_ENDED:
		return "second role confirmation did not end the shift"
	return ""


func _test_disconnect() -> String:
	var gateway := _create_gateway()
	gateway.submit_command(1, _command("disconnect-end", 1, AuthorityGateway.ROLE_OPERATOR, AuthorityGateway.TARGET_SESSION, &"request_end_shift"))
	gateway.run_ticks(1)
	gateway.disconnect_peer(2)
	if gateway.get_session_state() != AuthorityGateway.SESSION_DISCONNECTED:
		return "disconnect did not stop the active session"
	var session_view: Dictionary = gateway.create_role_snapshots()[1]["session"]
	if session_view["end_shift_requester_peer_id"] != 0 or not session_view["end_shift_confirmed_peer_ids"].is_empty():
		return "disconnect left an end-shift confirmation pending"
	var tick_before := gateway.get_simulation_tick()
	gateway.advance(1.0)
	if gateway.get_simulation_tick() != tick_before:
		return "simulation kept ticking after disconnect"
	return ""


func _create_gateway(start_shift: bool = true) -> AuthorityGateway:
	var plant_tuning := DEFAULT_PLANT_TUNING.duplicate(true) as PlantTuning
	var network_tuning := DEFAULT_NETWORK_TUNING.duplicate(true) as NetworkTuning
	var gateway := AuthorityGateway.new(plant_tuning, network_tuning)
	if start_shift:
		gateway.register_peer(1)
		gateway.register_peer(2)
		gateway.request_role(1, AuthorityGateway.ROLE_OPERATOR)
		gateway.request_role(2, AuthorityGateway.ROLE_TECHNICIAN)
		gateway.set_ready(1, true)
		gateway.set_ready(2, true)
	return gateway


func _command(
	command_id: String,
	peer_id: int,
	role: StringName,
	target: StringName,
	action: StringName,
	parameters: Dictionary = {},
	target_revision: int = -1
) -> Dictionary:
	return NetworkCommand.create(command_id, peer_id, role, target, action, parameters, 0, target_revision)


func _result_for(results: Array[Dictionary], command_id: String) -> Dictionary:
	for result in results:
		if result["command_id"] == command_id:
			return result
	return {}


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
