class_name SensorState
extends ComponentState

enum Mode {
	NORMAL,
	BIASED,
	FROZEN,
	DELAYED,
}

var source_device_id: StringName
var mode: Mode = Mode.NORMAL
var bias: float = 0.0
var delay_ticks: int = 0
var actual_value: float = 0.0
var reported_value: float = 0.0
var _frozen_value: float = 0.0
var _history: Array[float] = []


func _init(
	sensor_id: StringName,
	sensor_source_device_id: StringName,
	sensor_definition_id: StringName = &"sensor.numeric"
) -> void:
	super(sensor_id, sensor_definition_id)
	source_device_id = sensor_source_device_id
	set_operational_state(STATE_RUNNING)


func configure(next_mode: Mode, next_bias: float = 0.0, next_delay_ticks: int = 0) -> bool:
	if is_nan(next_bias) or is_inf(next_bias) or next_delay_ticks < 0:
		return false

	if next_mode == Mode.FROZEN and mode != Mode.FROZEN:
		_frozen_value = reported_value
	mode = next_mode
	bias = next_bias
	delay_ticks = next_delay_ticks
	_trim_history()
	revision += 1
	return true


func update(actual: float) -> void:
	assert(not is_nan(actual) and not is_inf(actual), "Sensor actual value must be finite")
	actual_value = actual
	_history.append(actual)
	_trim_history()

	var next_reported := actual
	match mode:
		Mode.BIASED:
			next_reported = actual + bias
		Mode.FROZEN:
			next_reported = _frozen_value
		Mode.DELAYED:
			var delayed_index := maxi(0, _history.size() - 1 - delay_ticks)
			next_reported = _history[delayed_index]
		_:
			next_reported = actual

	if reported_value != next_reported:
		reported_value = next_reported
		revision += 1


func debug_freeze_at(value: float) -> bool:
	if is_nan(value) or is_inf(value):
		return false
	mode = Mode.FROZEN
	_frozen_value = value
	reported_value = value
	revision += 1
	return true


func reset_sensor(initial_value: float = 0.0) -> void:
	mode = Mode.NORMAL
	bias = 0.0
	delay_ticks = 0
	actual_value = initial_value
	reported_value = initial_value
	_frozen_value = initial_value
	_history.clear()
	revision = 0
	operational_state = STATE_RUNNING


func to_dictionary() -> Dictionary:
	var result := super.to_dictionary()
	result.merge({
		"source_device_id": str(source_device_id),
		"mode": mode_name(mode),
		"bias": bias,
		"delay_ticks": delay_ticks,
		"actual_value": actual_value,
		"reported_value": reported_value,
	}, true)
	return result


static func mode_from_name(value: String) -> int:
	match value.to_upper():
		"NORMAL":
			return Mode.NORMAL
		"BIASED":
			return Mode.BIASED
		"FROZEN":
			return Mode.FROZEN
		"DELAYED":
			return Mode.DELAYED
		_:
			return -1


static func mode_name(value: Mode) -> String:
	return Mode.keys()[value]


func _trim_history() -> void:
	var capacity := maxi(1, delay_ticks + 1)
	while _history.size() > capacity:
		_history.pop_front()
