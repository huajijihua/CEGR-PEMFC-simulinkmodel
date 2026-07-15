function P = PEMFC_cEGR_params_v01(scenarioName)
%PEMFC_CEGR_PARAMS_V01 Initial parameter set for the PEMFC-cEGR core model.
%   P = PEMFC_cEGR_params_v01() returns a single structured parameter
%   object for the first Simulink/Simscape physical-network model.
%
%   The values below are startup defaults for model construction and smoke
%   tests. They are not a calibrated 10 kW data fit and are not universal
%   limits for future stack scaling.

arguments
    scenarioName (1,1) string = "no_egr_base"
end

P = struct();
P.meta.model_name = "PEMFC_cEGR_Core_Physical_v01";
P.meta.model_file = "04_Simulink物理网络模型/01_模型/PEMFC_cEGR_Core_Physical_v01.slx";
P.meta.created_for = "Phase 0/1 Simulink-Simscape physical network setup";
P.meta.source_policy = "example/default first; bench data only for smoke-test sanity checks";

P.units.current = "A";
P.units.pressure = "Pa";
P.units.temperature = "K";
P.units.mass_flow = "kg/s";
P.units.area = "m^2";
P.units.volume = "m^3";
P.units.humidity = "kg_H2O_per_kg_dry_air or mass fraction, depending on source block";

P.config.solver_type = "Variable-step";
P.config.solver = "VariableStepAuto";
P.config.stop_time_s = 500;
P.config.rel_tol = 1e-3;

P.stack.N_cell = 80;
P.stack.active_area_m2 = 2.8e-2;
P.stack.membrane_thickness_m = 1.25e-4;
P.stack.nominal_cell_voltage_V = 0.70;
P.stack.limiting_current_density_A_m2 = 2.0e4;
P.stack.exchange_current_density_A_m2 = 1.0e-3;
P.stack.thermal_mass_J_K = 1.5e4;
P.stack.initial_temperature_K = 333.15;
P.stack.source = "MathWorks FuelCell example plus engineering startup defaults";
P.stack.confidence = "low_until_smoke_tested";

P.cathode.inlet_volume_m3 = 5.0e-4;
P.cathode.outlet_volume_m3 = 5.0e-4;
P.cathode.pipe_length_m = 0.5;
P.cathode.pipe_diameter_m = 0.025;
P.cathode.outlet_equiv_area_m2 = 1.0e-3;
P.cathode.outlet_equiv_Cd = 0.8;
P.cathode.initial_pressure_Pa = 150e3;
P.cathode.initial_temperature_K = 333.15;
P.cathode.initial_xO2 = 0.21;
P.cathode.initial_xH2O = 0.02;
P.cathode.source = "FuelCell chamber/pipe defaults, to be replaced by geometry when available";

P.egr.Cd = 0.7;
P.egr.A_min_m2 = 1.0e-8;
P.egr.A_max_m2 = 8.0e-5;
P.egr.max_mdot_kg_s = 2.0e-3;
P.egr.cmd_min = 0.0;
P.egr.cmd_max = 1.0;
P.egr.pipe_length_m = 0.7;
P.egr.pipe_diameter_m = 0.018;
P.egr.ratio_definition = "egr_mdot / total_cathode_inlet_mdot";
P.egr.source = "Local Restriction (FC) startup range; not a calibrated valve map";

P.exhaust.p_exhaust_Pa = 101325;
P.exhaust.bp_valve_cmd = 0.5;
P.exhaust.Cd = 0.7;
P.exhaust.A_min_m2 = 1.0e-8;
P.exhaust.A_max_m2 = 1.0e-4;
P.exhaust.source = "Pressure relief/back-pressure structure reference";

P.separator.enabled = true;
P.separator.efficiency = 0.5;
P.separator.dp_nominal_Pa = 500;
P.separator.source = "equivalent first-version separator placeholder";

P.anode.h2_supply_pressure_Pa = 170e3;
P.anode.h2_supply_temperature_K = 333.15;
P.anode.h2_supply_mdot_kg_s = 2.0e-4;
P.anode.channel_volume_m3 = 3.0e-4;
P.anode.exhaust_pressure_Pa = 110e3;
P.anode.exhaust_Cd = 0.7;
P.anode.exhaust_area_m2 = 5.0e-5;
P.anode.source = "minimal hydrogen boundary for cathode-cEGR first version";

P.cooling.coolant_temperature_K = 333.15;
P.cooling.coolant_mdot_kg_s = 0.15;
P.cooling.UA_W_K = 250;
P.cooling.thermal_boundary_mode = "equivalent";
P.cooling.source = "simplified heat boundary; liquid loop deferred";

P.load.i_cmd_A = 100;
P.load.mode = "controlled_current";
P.load.source = "representative medium-current smoke-test input";

P.scenario = buildScenarios(P);
if ~isfield(P.scenario, scenarioName)
    validNames = string(fieldnames(P.scenario));
    error("PEMFC_cEGR_params_v01:UnknownScenario", ...
        "Unknown scenario '%s'. Valid scenarios: %s", ...
        scenarioName, strjoin(validNames, ", "));
end
P.active_scenario_name = scenarioName;
P.active = P.scenario.(scenarioName);
end

function scenario = buildScenarios(P)
base = struct();
base.i_cmd_A = P.load.i_cmd_A;
base.air_mdot_in_kg_s = 6.0e-3;
base.air_T_in_K = 333.15;
base.air_p_in_Pa = 150e3;
base.air_humidity_in = 0.02;
base.bp_valve_cmd = P.exhaust.bp_valve_cmd;
base.p_exhaust_Pa = P.exhaust.p_exhaust_Pa;
base.coolant_T_K = P.cooling.coolant_temperature_K;
base.coolant_mdot_kg_s = P.cooling.coolant_mdot_kg_s;
base.h2_supply_p_Pa = P.anode.h2_supply_pressure_Pa;
base.h2_supply_T_K = P.anode.h2_supply_temperature_K;
base.h2_supply_mdot_kg_s = P.anode.h2_supply_mdot_kg_s;

scenario.no_egr_base = base;
scenario.no_egr_base.egr_valve_cmd = 0.0;
scenario.no_egr_base.purpose = "baseline oxygen consumption, water generation, voltage, heat";

scenario.egr_low = base;
scenario.egr_low.egr_valve_cmd = 0.2;
scenario.egr_low.purpose = "check recirculation direction and mild cathode dilution";

scenario.egr_mid = base;
scenario.egr_mid.egr_valve_cmd = 0.5;
scenario.egr_mid.purpose = "check egr_mdot and egr_ratio monotonic response";

scenario.bp_sensitivity = base;
scenario.bp_sensitivity.egr_valve_cmd = 0.5;
scenario.bp_sensitivity.p_exhaust_Pa = 130e3;
scenario.bp_sensitivity.purpose = "check back-pressure effect on cEGR flow and cathode pressure";
end
