class_name TechnicianController
extends CharacterBody3D

@export_range(0.1, 20.0, 0.1, "or_greater", "suffix:m/s") var move_speed_meters_per_second: float = 4.0
@export_range(0.0001, 0.02, 0.0001) var mouse_sensitivity: float = 0.0025

@onready var _camera: Camera3D = %TechnicianCamera
@onready var _interaction_ray: RayCast3D = %InteractionRay
@onready var _hud: Control = %TechnicianHud
@onready var _prompt_label: Label = %InteractionPrompt
@onready var _feedback_label: Label = %FieldFeedback

var _view_model: TechnicianViewModel
var _active: bool = false
var _focused_device_id: StringName = &""
var _start_transform: Transform3D


func _ready() -> void:
	_start_transform = global_transform
	_prompt_label.text = ""
	_feedback_label.text = "FIELD CHANNEL — local information only"


func bind(view_model: TechnicianViewModel) -> void:
	_view_model = view_model
	_refresh_feedback()


func set_role_active(value: bool) -> void:
	_active = value
	_hud.visible = value
	_camera.current = value
	velocity = Vector3.ZERO
	if value:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func teleport_to_start() -> void:
	global_transform = _start_transform
	velocity = Vector3.ZERO


func get_focused_device_id() -> StringName:
	return _focused_device_id


func _physics_process(_delta: float) -> void:
	if not _active:
		return
	var input_vector := Input.get_vector(
		"technician_move_left",
		"technician_move_right",
		"technician_move_forward",
		"technician_move_back"
	)
	var direction := (_camera.global_basis * Vector3(input_vector.x, 0.0, input_vector.y))
	direction.y = 0.0
	direction = direction.normalized()
	velocity.x = direction.x * move_speed_meters_per_second
	velocity.z = direction.z * move_speed_meters_per_second
	move_and_slide()
	_refresh_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_camera.rotation.x = clampf(
			_camera.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(-82.0),
			deg_to_rad(82.0)
		)
	elif event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("technician_inspect"):
		_try_interaction("technician_inspect")
	elif event.is_action_pressed("technician_operate"):
		_try_interaction("technician_operate")
	elif event.is_action_pressed("technician_service"):
		_try_interaction("technician_service")


func _refresh_focus() -> void:
	_focused_device_id = &""
	_interaction_ray.force_raycast_update()
	if not _interaction_ray.is_colliding() or _view_model == null:
		_prompt_label.text = ""
		return
	var current: Node = _interaction_ray.get_collider()
	while current != null and not current.has_method("get_device_id"):
		current = current.get_parent()
	if current == null:
		_prompt_label.text = ""
		return

	_focused_device_id = current.get_device_id()
	var focus_view := _view_model.get_focus_view(_focused_device_id)
	if focus_view.is_empty():
		_prompt_label.text = ""
		return
	var action_labels: Array[String] = []
	for action in focus_view["actions"]:
		action_labels.append("[%s] %s" % [action["key_label"], action["label"]])
	var status_line := ""
	if focus_view.has("local_status"):
		status_line = "\n%s" % focus_view["local_status"]
	_prompt_label.text = "%s — %s%s\n%s" % [
		focus_view["device_id"],
		focus_view["display_name"],
		status_line,
		"   ".join(action_labels),
	]


func _try_interaction(input_action: StringName) -> void:
	if _view_model == null or _focused_device_id.is_empty():
		_feedback_label.text = "No device in reach."
		return
	var result := _view_model.perform_input_action(_focused_device_id, input_action)
	_feedback_label.text = String(result["feedback"])
	_refresh_focus()


func _refresh_feedback() -> void:
	if _view_model == null:
		return
	_feedback_label.text = String(_view_model.create_hud_view()["feedback"])
