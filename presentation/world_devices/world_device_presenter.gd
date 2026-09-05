class_name WorldDevicePresenter
extends Node3D

@export var device_id: StringName = &""
@export var display_name: String = "Device"
@export_enum("PUMP", "VALVE", "BREAKER", "GAUGE") var device_type: String = "PUMP"

@onready var _body: MeshInstance3D = %Body
@onready var _indicator: MeshInstance3D = %Indicator
@onready var _id_label: Label3D = %IdLabel
@onready var _state_label: Label3D = %StateLabel

var _simulation: PlantSimulation
var _last_state_key: String = ""


func _ready() -> void:
	add_to_group("world_devices")
	_id_label.text = "%s\n%s" % [device_id, display_name]


func bind(simulation: PlantSimulation) -> void:
	_simulation = simulation
	refresh_from_authority()


func get_device_id() -> StringName:
	return device_id


func refresh_from_authority() -> void:
	if _simulation == null:
		return
	var view := _simulation.create_technician_device_view(device_id)
	if view.is_empty():
		_state_label.text = "UNBOUND ID"
		_set_body_color(Color(0.75, 0.15, 0.15))
		return

	match device_type:
		"PUMP":
			_apply_pump_view(view)
		"VALVE":
			_apply_valve_view(view)
		"BREAKER":
			_apply_breaker_view(view)
		"GAUGE":
			_apply_gauge_view(view)


func _process(_delta: float) -> void:
	if _simulation == null or device_type != "PUMP":
		return
	var view := _simulation.create_technician_device_view(device_id)
	var vibration := String(view.get("vibration", "NORMAL"))
	var amplitude := 0.0
	var frequency := 0.0
	match vibration:
		"ROUGH":
			amplitude = 0.01
			frequency = 9.0
		"HIGH":
			amplitude = 0.025
			frequency = 13.0
		"SEVERE":
			amplitude = 0.05
			frequency = 18.0
		_:
			amplitude = 0.003 if bool(view.get("enabled", false)) else 0.0
			frequency = 5.0
	_body.rotation.z = sin(Time.get_ticks_msec() * 0.001 * frequency) * amplitude


func _apply_pump_view(view: Dictionary) -> void:
	var operational_state := String(view["operational_state"])
	var vibration := String(view["vibration"])
	var service_text := ""
	if bool(view.get("service_active", false)):
		service_text = "\nSERVICE %.1fs" % float(view["service_remaining_seconds"])
	_state_label.text = "%s | VIB %s\n%s%s" % [
		operational_state,
		vibration,
		view["sound_caption"],
		service_text,
	]
	var state_key := "%s:%s:%s" % [operational_state, vibration, bool(view.get("service_active", false))]
	if state_key == _last_state_key:
		return
	_last_state_key = state_key
	match vibration:
		"SEVERE":
			_set_body_color(Color(0.82, 0.18, 0.12))
		"HIGH":
			_set_body_color(Color(0.92, 0.48, 0.08))
		"ROUGH":
			_set_body_color(Color(0.85, 0.72, 0.12))
		_:
			_set_body_color(Color(0.15, 0.62, 0.38) if bool(view["enabled"]) else Color(0.28, 0.32, 0.34))


func _apply_valve_view(view: Dictionary) -> void:
	var position := float(view["actual_position"])
	var state := String(view["physical_state"])
	_state_label.text = "PHYSICAL: %s" % state
	_indicator.rotation.z = lerpf(0.0, -PI * 0.5, position)
	_set_body_color(Color(0.16, 0.5, 0.72) if position > 0.5 else Color(0.34, 0.37, 0.4))


func _apply_breaker_view(view: Dictionary) -> void:
	var state := String(view["physical_state"])
	_state_label.text = "PHYSICAL: %s" % state
	_indicator.rotation.z = -0.65 if state == "CLOSED" else 0.65
	_set_body_color(Color(0.18, 0.6, 0.35) if state == "CLOSED" else Color(0.78, 0.25, 0.13))


func _apply_gauge_view(view: Dictionary) -> void:
	_state_label.text = "LOCAL: %.1f FLOW" % float(view["local_reading"])
	_indicator.rotation.z = lerpf(1.9, -1.0, clampf(float(view["local_reading"]) / 120.0, 0.0, 1.0))
	_set_body_color(Color(0.12, 0.42, 0.48))


func _set_body_color(color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.35
	material.roughness = 0.6
	_body.material_override = material

