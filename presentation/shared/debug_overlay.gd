class_name DebugOverlay
extends PanelContainer

@onready var _state_label: Label = %StateLabel

var _simulation: PlantSimulation
var _network_session: NetworkSessionManager


func bind(simulation: PlantSimulation) -> void:
	_simulation = simulation
	_network_session = null
	refresh_from_authority()


func bind_network(network_session: NetworkSessionManager) -> void:
	_network_session = network_session
	refresh_from_authority()


func refresh_from_authority() -> void:
	if not visible:
		return
	if _network_session != null:
		var network_view := _network_session.get_debug_view()
		var network_text := (
			"NETWORK DEBUG — NOT ROLE UI\n"
			+ "peer=%d  mode=%s  connection=%s  role=%s\n"
			+ "host_tick=%d  latest_snapshot_revision=%d\n"
			+ "latest_command=%s  result=%s"
		) % [
			network_view["peer_id"],
			network_view["network_role"],
			network_view["connection_state"],
			network_view["assigned_role"],
			network_view["simulation_tick"],
			network_view["latest_snapshot_revision"],
			network_view["latest_command_id"],
			network_view["latest_command_result"],
		]
		var gateway := _network_session.get_gateway()
		_simulation = gateway.get_simulation() if gateway != null else null
		if _simulation == null:
			_state_label.text = network_text
			return
		_state_label.text = network_text + "\n\n" + _authoritative_text()
		return
	if _simulation == null:
		return
	_state_label.text = _authoritative_text()


func _authoritative_text() -> String:
	var snapshot := _simulation.create_snapshot()
	var pump_b: Dictionary = snapshot.components["P-B"]
	var valve_a: Dictionary = snapshot.components["V-A"]
	var valve_sensor: Dictionary = snapshot.sensors["S-V-A-POS"]
	return (
		"DEVELOPER AUTHORITATIVE STATE — NOT ROLE UI\n"
		+ "tick=%d  load=%.2f  MW=%.1f  MWh=%.2f\n"
		+ "flow=%.1f  temp=%.1f  stress=%.3f\n"
		+ "P-B condition=%.4f wear=%.4f phase=%s\n"
		+ "P-B service=%s remaining=%.1fs\n"
		+ "V-A actual=%.2f reported=%.2f sensor=%s\n"
		+ "F4: set P-B degraded  F5: toggle V-A mismatch  F6: reset player"
	) % [
		snapshot.tick,
		snapshot.requested_load,
		snapshot.actual_power_mw,
		snapshot.produced_mwh,
		snapshot.coolant_flow_units_per_second,
		snapshot.coolant_temperature_c,
		snapshot.plant_stress,
		pump_b["condition"],
		pump_b["wear"],
		snapshot.bearing_failure["phase"],
		snapshot.bearing_failure["service_active"],
		snapshot.bearing_failure["service_remaining_seconds"],
		valve_a["actual_position"],
		valve_sensor["reported_value"],
		valve_sensor["mode"],
	]
