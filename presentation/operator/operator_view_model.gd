class_name OperatorViewModel
extends RefCounted

const TREND_CAPACITY: int = 24

var _simulation: PlantSimulation
var _snapshot_store: RoleSnapshotStore
var _command_sender: Callable
var _latest_view: Dictionary = {}
var _flow_history: Array[float] = []
var _temperature_history: Array[float] = []
var _stress_history: Array[float] = []


func _init(source: Variant, command_sender: Callable = Callable()) -> void:
	assert(source is PlantSimulation or source is RoleSnapshotStore, "OperatorViewModel requires a simulation or role snapshot store")
	if source is PlantSimulation:
		_simulation = source as PlantSimulation
	else:
		_snapshot_store = source as RoleSnapshotStore
	_command_sender = command_sender
	refresh()


func refresh() -> void:
	_latest_view = (
		_simulation.create_operator_snapshot()
		if _simulation != null
		else _snapshot_store.get_operator_snapshot()
	)
	if _latest_view.is_empty():
		return
	_append_trend(_flow_history, float(_latest_view["coolant_flow_units_per_second"]))
	_append_trend(_temperature_history, float(_latest_view["coolant_temperature_c"]))
	_append_trend(_stress_history, float(_latest_view["plant_stress"]))


func get_view() -> Dictionary:
	var result := _latest_view.duplicate(true)
	result["flow_history"] = _flow_history.duplicate()
	result["temperature_history"] = _temperature_history.duplicate()
	result["stress_history"] = _stress_history.duplicate()
	return result


func request_set_load(requested_load: float) -> Variant:
	if _simulation != null:
		return _simulation.set_requested_load(requested_load)
	return _command_sender.call(
		AuthorityGateway.TARGET_PLANT,
		&"set_requested_load",
		{"requested_load": requested_load}
	)


func request_acknowledge(alarm_instance_id: StringName) -> Variant:
	if _simulation != null:
		return _simulation.acknowledge_alarm(alarm_instance_id)
	return _command_sender.call(
		AuthorityGateway.TARGET_ALARMS,
		&"acknowledge_alarm",
		{"alarm_instance_id": str(alarm_instance_id)}
	)


func request_end_shift() -> Variant:
	if _simulation != null:
		return false
	return _command_sender.call(AuthorityGateway.TARGET_SESSION, &"request_end_shift", {})


func _append_trend(history: Array[float], value: float) -> void:
	history.append(value)
	while history.size() > TREND_CAPACITY:
		history.pop_front()
