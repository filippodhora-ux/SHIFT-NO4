class_name AlarmSystem
extends RefCounted

var _rules: Array[AlarmRuleDefinition] = []
var _active_by_rule: Dictionary = {}
var _history: Array[AlarmInstance] = []
var _next_instance_number: int = 1


func _init(rules: Array[AlarmRuleDefinition]) -> void:
	_rules.assign(rules)


func evaluate(reported_values: Dictionary, tick: int) -> void:
	for rule in _rules:
		if not reported_values.has(rule.sensor_id):
			continue
		var value: float = reported_values[rule.sensor_id]
		var active_alarm: AlarmInstance = _active_by_rule.get(rule.alarm_rule_id)
		if active_alarm == null and rule.should_activate(value):
			_create_alarm(rule, tick)
		elif active_alarm != null and rule.should_clear(value):
			active_alarm.clear(tick)
			_active_by_rule.erase(rule.alarm_rule_id)


func acknowledge(alarm_instance_id: StringName) -> bool:
	for alarm in _history:
		if alarm.alarm_instance_id == alarm_instance_id:
			alarm.acknowledge()
			return true
	return false


func get_active_alarms() -> Array[AlarmInstance]:
	var result: Array[AlarmInstance] = []
	for alarm in _history:
		if alarm.active:
			result.append(alarm)
	return result


func get_history_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for alarm in _history:
		result.append(alarm.to_dictionary())
	return result


func reset() -> void:
	_active_by_rule.clear()
	_history.clear()
	_next_instance_number = 1


func _create_alarm(rule: AlarmRuleDefinition, tick: int) -> void:
	var instance_id := StringName("%s-%04d" % [rule.alarm_rule_id, _next_instance_number])
	_next_instance_number += 1
	var alarm := AlarmInstance.new(instance_id, rule, tick)
	_history.append(alarm)
	_active_by_rule[rule.alarm_rule_id] = alarm
