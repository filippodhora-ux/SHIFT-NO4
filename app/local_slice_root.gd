class_name LocalSliceRoot
extends Node3D

const DEFAULT_TUNING := preload("res://data/plant/default_plant_tuning.tres")
const ROLE_OPERATOR: StringName = &"OPERATOR"
const ROLE_TECHNICIAN: StringName = &"TECHNICIAN"

@onready var _operator_camera: Camera3D = %OperatorCamera
@onready var _operator_dashboard: OperatorDashboard = %OperatorDashboard
@onready var _technician_controller: TechnicianController = %TechnicianController
@onready var _debug_overlay: DebugOverlay = %DebugOverlay
@onready var _role_status: Label = %RoleStatus

var _simulation: PlantSimulation
var _clock: SimulationClock
var _operator_view_model: OperatorViewModel
var _technician_view_model: TechnicianViewModel
var _role: StringName = ROLE_OPERATOR
var _valve_mismatch_enabled: bool = false
var _presenters: Array[WorldDevicePresenter] = []


func _ready() -> void:
	_ensure_input_actions()
	var tuning := DEFAULT_TUNING.duplicate(true) as PlantTuning
	_simulation = PlantSimulation.new(tuning)
	_clock = SimulationClock.new(_simulation)
	_operator_view_model = OperatorViewModel.new(_simulation)
	_technician_view_model = TechnicianViewModel.new(_simulation)
	_operator_dashboard.bind(_operator_view_model)
	_technician_controller.bind(_technician_view_model)
	_debug_overlay.bind(_simulation)
	for node in get_tree().get_nodes_in_group("world_devices"):
		if node is WorldDevicePresenter:
			var presenter := node as WorldDevicePresenter
			presenter.bind(_simulation)
			_presenters.append(presenter)
	set_local_role(ROLE_OPERATOR)
	_refresh_presentations()


func _physics_process(real_delta_seconds: float) -> void:
	if _clock == null:
		return
	if _clock.advance(real_delta_seconds) > 0:
		_refresh_presentations()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("role_operator"):
		set_local_role(ROLE_OPERATOR)
	elif event.is_action_pressed("role_technician"):
		set_local_role(ROLE_TECHNICIAN)
	elif event.is_action_pressed("toggle_debug_state"):
		_debug_overlay.visible = not _debug_overlay.visible
		_debug_overlay.refresh_from_authority()
	elif event.is_action_pressed("debug_degrade_pump_b"):
		debug_set_pump_b_degraded()
	elif event.is_action_pressed("debug_toggle_valve_mismatch"):
		debug_toggle_valve_mismatch()
	elif event.is_action_pressed("debug_reset_player"):
		_technician_controller.teleport_to_start()


func set_local_role(role: StringName) -> void:
	if role != ROLE_OPERATOR and role != ROLE_TECHNICIAN:
		push_error("Unknown local role: %s" % role)
		return
	_role = role
	var operator_active := role == ROLE_OPERATOR
	_operator_camera.current = operator_active
	_operator_dashboard.set_role_active(operator_active)
	_technician_controller.set_role_active(not operator_active)
	_role_status.text = "LOCAL ROLE: %s  |  F1 Operator  F2 Technician  F3 Developer state" % role


func get_local_role() -> StringName:
	return _role


func get_simulation() -> PlantSimulation:
	return _simulation


func get_operator_view_model() -> OperatorViewModel:
	return _operator_view_model


func get_technician_view_model() -> TechnicianViewModel:
	return _technician_view_model


func run_simulation_ticks(tick_count: int) -> void:
	_clock.run_ticks(tick_count)
	_refresh_presentations()


func debug_set_pump_b_degraded() -> void:
	_simulation.debug_set_component_condition(&"P-B", 0.52)
	_simulation.set_requested_load(1.0)
	_refresh_presentations()


func debug_toggle_valve_mismatch() -> void:
	_valve_mismatch_enabled = not _valve_mismatch_enabled
	if _valve_mismatch_enabled:
		_simulation.debug_set_valve_mismatch(&"V-A", 0.0, 1.0)
	else:
		_simulation.execute_command(&"V-A", &"set_position", {"position": 1.0})
		_simulation.set_sensor_mode(&"S-V-A-POS", SensorState.Mode.NORMAL)
	_refresh_presentations()


func _refresh_presentations() -> void:
	_operator_dashboard.refresh_from_authority()
	for presenter in _presenters:
		presenter.refresh_from_authority()
	_debug_overlay.refresh_from_authority()


func _ensure_input_actions() -> void:
	var bindings: Dictionary = {
		&"technician_move_forward": KEY_W,
		&"technician_move_back": KEY_S,
		&"technician_move_left": KEY_A,
		&"technician_move_right": KEY_D,
		&"technician_inspect": KEY_E,
		&"technician_operate": KEY_F,
		&"technician_service": KEY_R,
		&"release_mouse": KEY_ESCAPE,
		&"role_operator": KEY_F1,
		&"role_technician": KEY_F2,
		&"toggle_debug_state": KEY_F3,
		&"debug_degrade_pump_b": KEY_F4,
		&"debug_toggle_valve_mismatch": KEY_F5,
		&"debug_reset_player": KEY_F6,
	}
	for action_name: StringName in bindings:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var keycode: Key = bindings[action_name] as Key
		var already_bound := false
		for existing_event in InputMap.action_get_events(action_name):
			if existing_event is InputEventKey and existing_event.physical_keycode == keycode:
				already_bound = true
				break
		if not already_bound:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycode
			InputMap.action_add_event(action_name, key_event)
