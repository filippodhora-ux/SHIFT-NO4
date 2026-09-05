class_name DebugOverlay
extends PanelContainer

@onready var _state_label: Label = %StateLabel

var _simulation: PlantSimulation


func bind(simulation: PlantSimulation) -> void:
	_simulation = simulation
	refresh_from_authority()


func refresh_from_authority() -> void:
	if _simulation == null or not visible:
		return
	var snapshot := _simulation.create_snapshot()
	var pump_b: Dictionary = snapshot.components["P-B"]
	var valve_a: Dictionary = snapshot.components["V-A"]
	var valve_sensor: Dictionary = snapshot.sensors["S-V-A-POS"]
	_state_label.text = (
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

