class_name OperatorViewModel
extends RefCounted

const TREND_CAPACITY: int = 24

var _simulation: PlantSimulation
var _latest_view: Dictionary = {}
var _flow_history: Array[float] = []
var _temperature_history: Array[float] = []
var _stress_history: Array[float] = []


func _init(simulation: PlantSimulation) -> void:
	assert(simulation != null, "OperatorViewModel requires PlantSimulation")
	_simulation = simulation
	refresh()


func refresh() -> void:
	_latest_view = _simulation.create_operator_snapshot()
	_append_trend(_flow_history, float(_latest_view["coolant_flow_units_per_second"]))
	_append_trend(_temperature_history, float(_latest_view["coolant_temperature_c"]))
	_append_trend(_stress_history, float(_latest_view["plant_stress"]))


func get_view() -> Dictionary:
	var result := _latest_view.duplicate(true)
	result["flow_history"] = _flow_history.duplicate()
	result["temperature_history"] = _temperature_history.duplicate()
	result["stress_history"] = _stress_history.duplicate()
	return result


func request_set_load(requested_load: float) -> bool:
	return _simulation.set_requested_load(requested_load)


func request_acknowledge(alarm_instance_id: StringName) -> bool:
	return _simulation.acknowledge_alarm(alarm_instance_id)


func _append_trend(history: Array[float], value: float) -> void:
	history.append(value)
	while history.size() > TREND_CAPACITY:
		history.pop_front()
