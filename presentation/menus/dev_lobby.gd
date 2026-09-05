class_name DevLobby
extends PanelContainer

@onready var _address: LineEdit = %Address
@onready var _port: SpinBox = %Port
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _operator_button: Button = %OperatorButton
@onready var _technician_button: Button = %TechnicianButton
@onready var _ready_button: CheckButton = %ReadyButton
@onready var _status: Label = %Status
@onready var _crew: Label = %Crew

var _session: NetworkSessionManager
var _updating_ready: bool = false


func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_operator_button.pressed.connect(_on_role_pressed.bind(AuthorityGateway.ROLE_OPERATOR))
	_technician_button.pressed.connect(_on_role_pressed.bind(AuthorityGateway.ROLE_TECHNICIAN))
	_ready_button.toggled.connect(_on_ready_toggled)


func bind(session: NetworkSessionManager) -> void:
	_session = session
	_port.value = session.DEFAULT_NETWORK_TUNING.default_port
	session.connection_state_changed.connect(_on_connection_state_changed)
	session.lobby_state_changed.connect(_on_lobby_state_changed)
	session.lobby_action_result.connect(_on_lobby_action_result)
	session.session_state_changed.connect(_on_session_state_changed)
	_refresh()


func set_session_visible(value: bool) -> void:
	visible = value


func show_message(message: String) -> void:
	_status.text = message


func _on_host_pressed() -> void:
	var result := _session.host(roundi(_port.value))
	if not bool(result["accepted"]):
		_status.text = "HOST REJECTED — %s" % result["reason"]


func _on_join_pressed() -> void:
	var result := _session.join(_address.text, roundi(_port.value))
	if not bool(result["accepted"]):
		_status.text = "JOIN REJECTED — %s" % result["reason"]


func _on_role_pressed(role: StringName) -> void:
	var result := _session.choose_role(role)
	if not bool(result["accepted"]):
		_status.text = "ROLE REJECTED — %s" % result["reason"]


func _on_ready_toggled(ready: bool) -> void:
	if _updating_ready:
		return
	var result := _session.set_ready(ready)
	if not bool(result["accepted"]):
		_status.text = "READY REJECTED — %s" % result["reason"]
		_updating_ready = true
		_ready_button.button_pressed = false
		_updating_ready = false


func _on_connection_state_changed(_state: String, _detail: String) -> void:
	_refresh()


func _on_lobby_state_changed(_snapshot: Dictionary) -> void:
	_refresh()


func _on_lobby_action_result(action: String, result: Dictionary) -> void:
	if not bool(result.get("accepted", false)):
		_status.text = "%s REJECTED — %s" % [action.to_upper(), result.get("reason", "UNKNOWN")]


func _on_session_state_changed(state: String) -> void:
	visible = state != str(AuthorityGateway.SESSION_IN_SHIFT)
	_refresh()


func _refresh() -> void:
	if _session == null:
		return
	_status.text = "%s — %s" % [_session.get_connection_state(), _session.get_connection_detail()]
	var lines: Array[String] = []
	var lobby := _session.get_lobby_snapshot()
	var peers: Dictionary = lobby.get("peers", {})
	for peer_id_text in peers:
		var peer: Dictionary = peers[peer_id_text]
		lines.append("peer %s  role=%s  ready=%s" % [peer_id_text, peer.get("role", "—"), peer.get("ready", false)])
	_crew.text = "CREW\n%s" % ("\n".join(lines) if not lines.is_empty() else "Waiting for host...")
	var connected := _session.get_connection_state() in ["LISTENING", "CONNECTED"]
	_operator_button.disabled = not connected
	_technician_button.disabled = not connected
	_ready_button.disabled = not connected or _session.get_assigned_role().is_empty()
	var own_peer: Dictionary = peers.get(str(_session.multiplayer.get_unique_id()), {})
	_updating_ready = true
	_ready_button.button_pressed = bool(own_peer.get("ready", false))
	_updating_ready = false
