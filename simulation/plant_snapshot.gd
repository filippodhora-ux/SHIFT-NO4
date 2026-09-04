class_name PlantSnapshot
extends RefCounted

var tick: int
var requested_load: float
var actual_power_mw: float
var produced_mwh: float
var thermal_demand_units: float
var pump_a_device_id: StringName
var pump_a_enabled: bool
var pump_a_available: bool
var pump_a_effective_flow_units_per_second: float
var pump_b_device_id: StringName
var pump_b_enabled: bool
var pump_b_available: bool
var pump_b_effective_flow_units_per_second: float
var coolant_flow_units_per_second: float
var cooling_capacity_units: float
var coolant_temperature_c: float
var plant_stress: float
var steam_availability: float
var available_power_mw: float


func _init(
	initial_tick: int,
	initial_requested_load: float,
	initial_actual_power_mw: float,
	initial_produced_mwh: float,
	initial_thermal_demand_units: float,
	initial_pump_a: PumpState,
	initial_pump_b: PumpState,
	initial_coolant_flow_units_per_second: float,
	initial_cooling_capacity_units: float,
	initial_coolant_temperature_c: float,
	initial_plant_stress: float,
	initial_steam_availability: float,
	initial_available_power_mw: float
) -> void:
	tick = initial_tick
	requested_load = initial_requested_load
	actual_power_mw = initial_actual_power_mw
	produced_mwh = initial_produced_mwh
	thermal_demand_units = initial_thermal_demand_units
	pump_a_device_id = initial_pump_a.device_id
	pump_a_enabled = initial_pump_a.enabled
	pump_a_available = initial_pump_a.available
	pump_a_effective_flow_units_per_second = initial_pump_a.effective_flow_units_per_second
	pump_b_device_id = initial_pump_b.device_id
	pump_b_enabled = initial_pump_b.enabled
	pump_b_available = initial_pump_b.available
	pump_b_effective_flow_units_per_second = initial_pump_b.effective_flow_units_per_second
	coolant_flow_units_per_second = initial_coolant_flow_units_per_second
	cooling_capacity_units = initial_cooling_capacity_units
	coolant_temperature_c = initial_coolant_temperature_c
	plant_stress = initial_plant_stress
	steam_availability = initial_steam_availability
	available_power_mw = initial_available_power_mw


func to_dictionary() -> Dictionary:
	return {
		"tick": tick,
		"requested_load": requested_load,
		"thermal_demand_units": thermal_demand_units,
		"pumps": {
			str(pump_a_device_id): {
				"enabled": pump_a_enabled,
				"available": pump_a_available,
				"effective_flow_units_per_second": pump_a_effective_flow_units_per_second,
			},
			str(pump_b_device_id): {
				"enabled": pump_b_enabled,
				"available": pump_b_available,
				"effective_flow_units_per_second": pump_b_effective_flow_units_per_second,
			},
		},
		"coolant_flow_units_per_second": coolant_flow_units_per_second,
		"cooling_capacity_units": cooling_capacity_units,
		"coolant_temperature_c": coolant_temperature_c,
		"plant_stress": plant_stress,
		"steam_availability": steam_availability,
		"available_power_mw": available_power_mw,
		"actual_power_mw": actual_power_mw,
		"produced_mwh": produced_mwh,
	}


func has_finite_values() -> bool:
	return (
		_is_finite_number(requested_load)
		and _is_finite_number(actual_power_mw)
		and _is_finite_number(produced_mwh)
		and _is_finite_number(thermal_demand_units)
		and _is_finite_number(pump_a_effective_flow_units_per_second)
		and _is_finite_number(pump_b_effective_flow_units_per_second)
		and _is_finite_number(coolant_flow_units_per_second)
		and _is_finite_number(cooling_capacity_units)
		and _is_finite_number(coolant_temperature_c)
		and _is_finite_number(plant_stress)
		and _is_finite_number(steam_availability)
		and _is_finite_number(available_power_mw)
	)


func is_equal_approx_to(other: PlantSnapshot, tolerance: float) -> bool:
	return (
		other != null
		and tick == other.tick
		and pump_a_device_id == other.pump_a_device_id
		and pump_a_enabled == other.pump_a_enabled
		and pump_a_available == other.pump_a_available
		and pump_b_device_id == other.pump_b_device_id
		and pump_b_enabled == other.pump_b_enabled
		and pump_b_available == other.pump_b_available
		and _is_close(requested_load, other.requested_load, tolerance)
		and _is_close(actual_power_mw, other.actual_power_mw, tolerance)
		and _is_close(produced_mwh, other.produced_mwh, tolerance)
		and _is_close(thermal_demand_units, other.thermal_demand_units, tolerance)
		and _is_close(
			pump_a_effective_flow_units_per_second,
			other.pump_a_effective_flow_units_per_second,
			tolerance
		)
		and _is_close(
			pump_b_effective_flow_units_per_second,
			other.pump_b_effective_flow_units_per_second,
			tolerance
		)
		and _is_close(
			coolant_flow_units_per_second,
			other.coolant_flow_units_per_second,
			tolerance
		)
		and _is_close(cooling_capacity_units, other.cooling_capacity_units, tolerance)
		and _is_close(coolant_temperature_c, other.coolant_temperature_c, tolerance)
		and _is_close(plant_stress, other.plant_stress, tolerance)
		and _is_close(steam_availability, other.steam_availability, tolerance)
		and _is_close(available_power_mw, other.available_power_mw, tolerance)
	)


func _is_close(first: float, second: float, tolerance: float) -> bool:
	return absf(first - second) <= tolerance


func _is_finite_number(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
