class_name AlarmInstance
extends RefCounted

var alarm_instance_id: StringName
var alarm_rule_id: StringName
var source_device_id: StringName
var authoritative_tick: int
var priority: int
var message_key: StringName
var active: bool = true
var acknowledged: bool = false
var cleared_at_tick: int = -1
var revision: int = 0


func _init(instance_id: StringName, rule: AlarmRuleDefinition, tick: int) -> void:
	alarm_instance_id = instance_id
	alarm_rule_id = rule.alarm_rule_id
	source_device_id = rule.source_device_id
	authoritative_tick = tick
	priority = rule.priority
	message_key = rule.message_key


func acknowledge() -> void:
	if acknowledged:
		return
	acknowledged = true
	revision += 1


func clear(tick: int) -> void:
	if not active:
		return
	active = false
	cleared_at_tick = tick
	revision += 1


func to_dictionary() -> Dictionary:
	return {
		"alarm_instance_id": str(alarm_instance_id),
		"alarm_rule_id": str(alarm_rule_id),
		"source_device_id": str(source_device_id),
		"authoritative_tick": authoritative_tick,
		"priority": priority,
		"message_key": str(message_key),
		"active": active,
		"acknowledged": acknowledged,
		"cleared_at_tick": cleared_at_tick,
		"revision": revision,
	}
