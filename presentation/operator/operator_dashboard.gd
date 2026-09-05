class_name OperatorDashboard
extends Control

@onready var _load_slider: HSlider = %LoadSlider
@onready var _requested_load_label: Label = %RequestedLoad
@onready var _actual_power_label: Label = %ActualPower
@onready var _produced_mwh_label: Label = %ProducedMwh
@onready var _flow_label: Label = %CoolantFlow
@onready var _temperature_label: Label = %CoolantTemperature
@onready var _stress_label: Label = %PlantStress
@onready var _trend_label: Label = %ProcessTrend
@onready var _pump_a_label: Label = %PumpAStatus
@onready var _pump_b_label: Label = %PumpBStatus
@onready var _valve_a_label: Label = %ValveAStatus
@onready var _valve_b_label: Label = %ValveBStatus
@onready var _breaker_label: Label = %BreakerStatus
@onready var _alarm_list: ItemList = %AlarmList
@onready var _alarm_history_label: Label = %AlarmHistory
@onready var _acknowledge_button: Button = %AcknowledgeButton

var _view_model: OperatorViewModel
var _visible_alarm_ids: Array[StringName] = []
var _updating_slider: bool = false


func _ready() -> void:
	_load_slider.value_changed.connect(_on_load_value_changed)
	_load_slider.drag_ended.connect(_on_load_drag_ended)
	_acknowledge_button.pressed.connect(_on_acknowledge_pressed)


func bind(view_model: OperatorViewModel) -> void:
	_view_model = view_model
	refresh_from_authority()


func set_role_active(value: bool) -> void:
	visible = value


func refresh_from_authority() -> void:
	if _view_model == null:
		return
	_view_model.refresh()
	var view := _view_model.get_view()
	_updating_slider = true
	_load_slider.value = float(view["requested_load"])
	_updating_slider = false
	_requested_load_label.text = "REQUESTED LOAD  %3d%%" % roundi(float(view["requested_load"]) * 100.0)
	_actual_power_label.text = "ACTUAL EXPORT  %7.1f MW" % float(view["actual_power_mw"])
	_produced_mwh_label.text = "PRODUCED       %7.2f MWh" % float(view["produced_mwh"])
	_flow_label.text = "COOLANT FLOW   %6.1f units/s" % float(view["coolant_flow_units_per_second"])
	_temperature_label.text = "COOLANT TEMP   %6.1f °C" % float(view["coolant_temperature_c"])
	_stress_label.text = "PLANT STRESS   %6.1f %%" % (float(view["plant_stress"]) * 100.0)
	_trend_label.text = "RECENT FLOW  %s\nRECENT TEMP  %s\nRECENT STRESS %s" % [
		_trend_text(view["flow_history"], 0),
		_trend_text(view["temperature_history"], 0),
		_trend_text(view["stress_history"], 2),
	]
	var equipment: Dictionary = view["equipment"]
	_pump_a_label.text = _reported_status_text(equipment["P-A"])
	_pump_b_label.text = _reported_status_text(equipment["P-B"])
	_valve_a_label.text = "V-A  REPORTED %s" % equipment["V-A"]["reported_position_state"]
	_valve_b_label.text = "V-B  REPORTED %s" % equipment["V-B"]["reported_position_state"]
	_breaker_label.text = "BR-A REPORTED %s" % equipment["BR-A"]["reported_status"]
	_refresh_alarms(view["alarms"])


func _on_load_value_changed(value: float) -> void:
	if _updating_slider:
		return
	_requested_load_label.text = "REQUESTED LOAD  %3d%% (pending)" % roundi(value * 100.0)


func _on_load_drag_ended(_value_changed: bool) -> void:
	if _view_model == null:
		return
	_view_model.request_set_load(_load_slider.value)
	refresh_from_authority()


func _on_acknowledge_pressed() -> void:
	if _view_model == null or _visible_alarm_ids.is_empty():
		return
	var selected := _alarm_list.get_selected_items()
	var selected_index := selected[0] if not selected.is_empty() else 0
	_view_model.request_acknowledge(_visible_alarm_ids[selected_index])
	refresh_from_authority()


func _refresh_alarms(alarms: Array) -> void:
	_alarm_list.clear()
	_visible_alarm_ids.clear()
	var history_lines: Array[String] = []
	for alarm in alarms:
		var status := "ACTIVE" if alarm["active"] else "CLEARED"
		var ack := "A" if alarm["acknowledged"] else "U"
		var line := "P%d  %s  %s  %s" % [
			int(alarm["priority"]) + 1,
			alarm["source_device_id"],
			alarm["message_key"],
			ack,
		]
		if alarm["active"]:
			_alarm_list.add_item(line)
			_visible_alarm_ids.append(StringName(alarm["alarm_instance_id"]))
		history_lines.append("T%04d %s %s" % [alarm["authoritative_tick"], status, alarm["message_key"]])
	while history_lines.size() > 6:
		history_lines.pop_front()
	_alarm_history_label.text = "HISTORY\n%s" % ("\n".join(history_lines) if not history_lines.is_empty() else "No alarm history")
	_acknowledge_button.disabled = _visible_alarm_ids.is_empty()


func _reported_status_text(status: Dictionary) -> String:
	return "%s  REPORTED %s" % [status["device_id"], status["reported_status"]]


func _trend_text(history: Array, decimals: int) -> String:
	var samples: Array[String] = []
	var start := maxi(0, history.size() - 6)
	for index in range(start, history.size()):
		samples.append(("%.2f" if decimals == 2 else "%.0f") % float(history[index]))
	return "  ".join(samples)
