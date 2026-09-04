class_name BearingFailureRuntime
extends RefCounted

enum Phase {
	HEALTHY,
	LATENT,
	WORN,
	DEGRADED,
	FAILING,
	FAILED,
}

var failure_id: StringName
var target_device_id: StringName
var phase: Phase = Phase.HEALTHY
var severity: float = 0.0
var activated_tick: int = -1
var revision: int = 0


func _init(initial_failure_id: StringName, initial_target_device_id: StringName) -> void:
	failure_id = initial_failure_id
	target_device_id = initial_target_device_id


func update_from_condition(condition: float, tick: int, definition: BearingFailureDefinition) -> void:
	var next_phase: Phase = definition.phase_for_condition(condition) as Phase
	var next_severity := clampf(1.0 - condition, 0.0, 1.0)
	var changed := false
	if next_phase != phase:
		phase = next_phase
		changed = true
		if activated_tick < 0 and phase != Phase.HEALTHY:
			activated_tick = tick
	if severity != next_severity:
		severity = next_severity
		changed = true
	if changed:
		revision += 1


func reset_failure() -> void:
	phase = Phase.HEALTHY
	severity = 0.0
	activated_tick = -1
	revision = 0


func phase_name() -> String:
	return Phase.keys()[phase]


func to_dictionary() -> Dictionary:
	return {
		"failure_id": str(failure_id),
		"target_device_id": str(target_device_id),
		"phase": phase_name(),
		"severity": severity,
		"activated_tick": activated_tick,
		"revision": revision,
	}


static func phase_from_name(value: String) -> int:
	var phase_index := Phase.keys().find(value.to_upper())
	return phase_index
