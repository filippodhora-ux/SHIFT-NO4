class_name PlantTuning
extends Resource

@export_category("Simulation")
@export_range(0.001, 1.0, 0.001, "or_greater") var simulation_step_seconds: float = 0.1
@export_range(1, 128, 1, "or_greater") var max_catch_up_steps: int = 8
@export_range(0.000001, 1.0, 0.000001, "or_greater") var simulated_hours_per_real_second: float = 0.01

@export_category("Load")
@export_range(0.0, 1.0, 0.01) var minimum_requested_load: float = 0.0
@export_range(0.0, 2.0, 0.01, "or_greater") var maximum_requested_load: float = 1.0

@export_category("Electrical output")
@export_range(0.0, 10000.0, 1.0, "or_greater", "suffix:MW") var nominal_electrical_power_mw: float = 1000.0
@export_range(0.001, 100000.0, 1.0, "or_greater", "suffix:MW/s") var power_ramp_mw_per_second: float = 250.0

@export_category("Cooling pumps")
@export var pump_a_enabled_on_reset: bool = true
@export var pump_b_enabled_on_reset: bool = true
@export var pump_a_available_on_reset: bool = true
@export var pump_b_available_on_reset: bool = true
@export_range(0.0, 1000.0, 0.1, "or_greater", "suffix:flow/s") var pump_a_rated_flow_units_per_second: float = 60.0
@export_range(0.0, 1000.0, 0.1, "or_greater", "suffix:flow/s") var pump_b_rated_flow_units_per_second: float = 60.0
@export_range(0.0, 1.0, 0.01) var pump_a_efficiency: float = 1.0
@export_range(0.0, 1.0, 0.01) var pump_b_efficiency: float = 1.0
@export_range(0.001, 10000.0, 0.1, "or_greater", "suffix:flow/s²") var pump_flow_ramp_units_per_second_squared: float = 120.0

@export_category("Thermal and cooling")
@export_range(0.001, 10000.0, 0.1, "or_greater", "suffix:thermal units") var nominal_thermal_demand_units: float = 100.0
@export_range(0.001, 100.0, 0.01, "or_greater") var cooling_capacity_per_flow_unit: float = 1.0
@export_range(-100.0, 500.0, 0.1, "suffix:°C") var minimum_coolant_temperature_c: float = 20.0
@export_range(-100.0, 500.0, 0.1, "suffix:°C") var nominal_coolant_temperature_c: float = 60.0
@export_range(-100.0, 500.0, 0.1, "suffix:°C") var maximum_coolant_temperature_c: float = 180.0
@export_range(0.0, 500.0, 0.1, "or_greater", "suffix:°C") var temperature_rise_at_full_deficit_c: float = 100.0
@export_range(0.001, 100.0, 0.01, "or_greater", "suffix:°C/s") var coolant_heating_rate_c_per_second: float = 5.0
@export_range(0.001, 100.0, 0.01, "or_greater", "suffix:°C/s") var coolant_cooling_rate_c_per_second: float = 2.5

@export_category("Plant stress")
@export_range(0.0, 10.0, 0.01, "or_greater") var cooling_deficit_stress_weight: float = 0.75
@export_range(0.0, 10.0, 0.01, "or_greater") var temperature_stress_weight: float = 0.5
@export_range(0.001, 10.0, 0.01, "or_greater", "suffix:/s") var stress_rise_per_second: float = 0.2
@export_range(0.001, 10.0, 0.01, "or_greater", "suffix:/s") var stress_recovery_per_second: float = 0.1

@export_category("Downstream output")
@export_range(-100.0, 500.0, 0.1, "suffix:°C") var temperature_derate_start_c: float = 80.0
@export_range(0.0, 1.0, 0.01) var minimum_temperature_output_factor: float = 0.25
@export_range(0.0, 1.0, 0.01) var minimum_stress_output_factor: float = 0.1
@export_range(0.001, 100.0, 0.01, "or_greater", "suffix:/s") var steam_response_per_second: float = 0.5


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if not _is_finite_positive(simulation_step_seconds):
		errors.append("simulation_step_seconds must be finite and greater than zero")
	if max_catch_up_steps <= 0:
		errors.append("max_catch_up_steps must be greater than zero")
	if not _is_finite_positive(simulated_hours_per_real_second):
		errors.append("simulated_hours_per_real_second must be finite and greater than zero")
	if not _is_finite_number(minimum_requested_load) or minimum_requested_load < 0.0:
		errors.append("minimum_requested_load must be finite and non-negative")
	if not _is_finite_number(maximum_requested_load) or maximum_requested_load < minimum_requested_load:
		errors.append("maximum_requested_load must be finite and at least minimum_requested_load")
	if not _is_finite_number(nominal_electrical_power_mw) or nominal_electrical_power_mw < 0.0:
		errors.append("nominal_electrical_power_mw must be finite and non-negative")
	if not _is_finite_positive(power_ramp_mw_per_second):
		errors.append("power_ramp_mw_per_second must be finite and greater than zero")
	if not _is_finite_non_negative(pump_a_rated_flow_units_per_second):
		errors.append("pump_a_rated_flow_units_per_second must be finite and non-negative")
	if not _is_finite_non_negative(pump_b_rated_flow_units_per_second):
		errors.append("pump_b_rated_flow_units_per_second must be finite and non-negative")
	if not _is_normalized(pump_a_efficiency):
		errors.append("pump_a_efficiency must be finite and between zero and one")
	if not _is_normalized(pump_b_efficiency):
		errors.append("pump_b_efficiency must be finite and between zero and one")
	if not _is_finite_positive(pump_flow_ramp_units_per_second_squared):
		errors.append("pump_flow_ramp_units_per_second_squared must be finite and greater than zero")
	if not _is_finite_positive(nominal_thermal_demand_units):
		errors.append("nominal_thermal_demand_units must be finite and greater than zero")
	if not _is_finite_positive(cooling_capacity_per_flow_unit):
		errors.append("cooling_capacity_per_flow_unit must be finite and greater than zero")
	if not _temperatures_are_ordered():
		errors.append("coolant temperatures must be finite and ordered minimum <= nominal < maximum")
	if not _is_finite_non_negative(temperature_rise_at_full_deficit_c):
		errors.append("temperature_rise_at_full_deficit_c must be finite and non-negative")
	if not _is_finite_positive(coolant_heating_rate_c_per_second):
		errors.append("coolant_heating_rate_c_per_second must be finite and greater than zero")
	if not _is_finite_positive(coolant_cooling_rate_c_per_second):
		errors.append("coolant_cooling_rate_c_per_second must be finite and greater than zero")
	if not _is_finite_non_negative(cooling_deficit_stress_weight):
		errors.append("cooling_deficit_stress_weight must be finite and non-negative")
	if not _is_finite_non_negative(temperature_stress_weight):
		errors.append("temperature_stress_weight must be finite and non-negative")
	if not _is_finite_positive(stress_rise_per_second):
		errors.append("stress_rise_per_second must be finite and greater than zero")
	if not _is_finite_positive(stress_recovery_per_second):
		errors.append("stress_recovery_per_second must be finite and greater than zero")
	if not _is_finite_number(temperature_derate_start_c) or temperature_derate_start_c >= maximum_coolant_temperature_c:
		errors.append("temperature_derate_start_c must be finite and below maximum_coolant_temperature_c")
	if not _is_normalized(minimum_temperature_output_factor):
		errors.append("minimum_temperature_output_factor must be finite and between zero and one")
	if not _is_normalized(minimum_stress_output_factor):
		errors.append("minimum_stress_output_factor must be finite and between zero and one")
	if not _is_finite_positive(steam_response_per_second):
		errors.append("steam_response_per_second must be finite and greater than zero")

	return errors


func _is_finite_positive(value: float) -> bool:
	return _is_finite_number(value) and value > 0.0


func _is_finite_non_negative(value: float) -> bool:
	return _is_finite_number(value) and value >= 0.0


func _is_normalized(value: float) -> bool:
	return _is_finite_number(value) and value >= 0.0 and value <= 1.0


func _temperatures_are_ordered() -> bool:
	return (
		_is_finite_number(minimum_coolant_temperature_c)
		and _is_finite_number(nominal_coolant_temperature_c)
		and _is_finite_number(maximum_coolant_temperature_c)
		and minimum_coolant_temperature_c <= nominal_coolant_temperature_c
		and nominal_coolant_temperature_c < maximum_coolant_temperature_c
	)


func _is_finite_number(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
