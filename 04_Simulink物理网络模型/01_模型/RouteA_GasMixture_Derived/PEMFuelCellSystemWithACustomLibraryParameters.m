%% Route A platform-default parameters
% Open Model Workspace in the Model Explorer to view and modify parameter
% values. Click 'Reinitialize from Source' to reset to the parameter values
% in this script.
%
% Route A parameter policy:
% - The default initialization chain is isolated from company, bench, DQ60,
%   10 kW workbook, and legacy calibration data.
% - Default values come from the MathWorks official example, literature-scale
%   ranges, and engineering-order matching between stack, BoP, and cEGR loop.
% - Bench or product data may only be loaded by explicit external_case scripts.
% - A10/A10.1 daily users should set routeA_* controls rather than editing
%   physical block parameters directly.

% Copyright 2020 The MathWorks, Inc.

%% Model and official example base
routeA_parameter_layer = "platform_default";
routeA_external_case_enabled = false;

load PEMFuelCellSystemWithACustomLibraryDriveCycle.mat

routeA_current_system = get_param(0, 'CurrentSystem');
if isempty(routeA_current_system)
    routeA_current_model = bdroot;
else
    routeA_current_model = bdroot(routeA_current_system);
end
if isempty(routeA_current_model) || strcmp(routeA_current_model, 'simulink')
    routeA_loaded_models = find_system(0, 'SearchDepth', 0, ...
        'Type', 'block_diagram');
    routeA_loaded_models = getfullname(routeA_loaded_models);
    routeA_loaded_models = routeA_loaded_models(contains( ...
        string(routeA_loaded_models), 'PEMFuelCellSystem_GasMixture'));
    if isempty(routeA_loaded_models)
        error('RouteA:MissingModelContext', ...
            'No loaded Route A model was found for parameter initialization.');
    end
    routeA_current_model = routeA_loaded_models{1};
end
Gas_properties_candidates = find_system( ...
    routeA_current_model, ...
    'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
    'MatchFilter', @Simulink.match.allVariants, ...
    'Name', 'Gas Mixture Properties');
if isempty(Gas_properties_candidates)
    error('RouteA:MissingGasProperties', ...
        'Gas Mixture Properties block was not found in the model.');
end
Gas_properties_block = Gas_properties_candidates{1};
T_TLU = eval(get_param(Gas_properties_block, 'T_LUT')); % [K] Temperature table
pSat_TLU = eval(get_param(Gas_properties_block, 'pSat')); % [kPa] Saturation pressures
pSat_H2O_TLU = pSat_TLU(4,:); % [MPa] Water saturation table

%% Environment boundary
env_p = 0.101325; % [MPa] Pressure
env_T = 20; % [degC] Temperature
env_yO2 = 0.21; % [-] Oxygen mole fraction
env_RH = 0.5; % [-] Relative humidity
env_pSat_H2O = interp1(T_TLU, pSat_H2O_TLU, env_T + 273.15) * 1e-3; % [MPa]
env_yH20 = env_RH * env_pSat_H2O / env_p; % [-] Water mole fraction

%% Stack and MEA
stack_num_cells = 400; % [-] Number cells
stack_area = 280; % [cm^2] Cell area
stack_t_membrane = 125; % [um] Membrane thickness
stack_t_gdl = 250; % [um] Gas diffusion layer thickness
stack_w_channels = 1; % [cm] Gas channel width/height
stack_num_channels = 8; % [-] Number of gas channels per cell
stack_io = 1e-04; % [A/cm^2] Exchange current density
stack_iL = 1.4; % [A/cm^2] Limiting current density
stack_alpha = 0.7; % [-] Charge transfer coefficient
stack_mea_rho = 1800; % [kg/s] Overall density of membrane electrode assembly
stack_mea_cp = 870; % [J/(kg*K)] Overall specific heat of membrane electrode assembly

%% Air supply and compressor
% Profile: platform_default / A11-A12 override candidate.
% The default air path keeps the official compressor source/map structure.
% routeA_air_control_mode_id selects the command semantics; compressor map
% values remain platform-scale placeholders unless replaced by a later
% vehicle or bench configuration profile.
cathode_tube_D = 0.05; % [m] Air tube diameter
comp_inlet_mixer_V = 0.1; % [l] Compressor inlet mixer volume
cegr_comp_map_t_denom_epsilon = 1e-9; % [-] Compressor map denominator guard

comp_p_ratio_TLU = [1; 1.25; 1.5; 1.75; 2]; % [-] Pressure ratio vector
comp_rpm_TLU = [0, 1800, 3600]; % [rpm] Shaft speed vector
comp_mdot_corr_TLU = [
    0, 0.05,   0.1;
    0, 0.0375, 0.075;
    0, 0.025,  0.05;
    0, 0.0125, 0.025;
    0, 0,      0] * 4; % [kg/s] Corrected mass flow rate table

intercooler_length = 0.25; % [m] Equivalent charge-air cooler gas path length
intercooler_extra_length = 0.05; % [m] Equivalent fitting/manifold length
intercooler_Dh = cathode_tube_D; % [m] Equivalent hydraulic diameter
intercooler_area = pi*intercooler_Dh^2/4; % [m^2] Equivalent flow area
intercooler_roughness = 15e-6; % [m] Equivalent wall roughness
intercooler_cond_tau = 1; % [s] First-order condensation time constant
intercooler_p0 = env_p; % [MPa] Initial pressure target
intercooler_T0 = env_T; % [degC] Initial temperature target
intercooler_dp_nominal = 0.001; % [MPa] Equivalent nominal pressure drop
intercooler_mdot_nominal = 0.1; % [kg/s] Equivalent nominal cathode flow
intercooler_laminar_fraction = 1e-3; % [-] Flow resistance smoothing fraction

%% Cathode cEGR loop
% Profile: platform_default / A11-A12 override candidate.
% The first cEGR implementation returns cathode exhaust to the compressor
% inlet mixer through an equivalent valve and pipe. Water removal uses
% explicit FuelCell_lib FC-domain separator interfaces plus chamber/pipe
% condensation dynamics, with a separate KPI observer for drainage estimates.
% routeA_target_egr_ratio_comp_in is defined against total compressor inlet
% mass flow, not fresh-air-only flow.
cathode_outlet_chamber_V = 0.2; % [l] Cathode outlet chamber volume
cegr_pipe_D = cathode_tube_D; % [m] cEGR pipe hydraulic diameter
cegr_pipe_area = pi*cegr_pipe_D^2/4; % [m^2] cEGR pipe cross-sectional area
cegr_pipe_length = 0.5; % [m] cEGR pipe length
cegr_pipe_extra_length = 0.1; % [m] Additional equivalent cEGR pipe length
cegr_pipe_roughness = 15e-6; % [m] cEGR pipe roughness
cegr_cond_tau = 1; % [s] First-order condensation time constant
cegr_outlet_chamber_p0 = env_p; % [MPa] Initial cathode outlet pressure target
cegr_pipe_p0 = env_p; % [MPa] Initial cEGR pipe pressure target
cegr_inlet_mixer_p0 = env_p; % [MPa] Initial compressor inlet mixer pressure target
% Direct physical upper opening area for the active platform configuration.
% No-cEGR selects the closed valve Variant; studies that assess capacity set
% this one parameter to an explicit alternative area in m^2.
cegr_valve_max_area = 1.96349540849e-4; % [m^2]
cegr_valve_open_min_area = 1e-10; % [m^2] Positive lower bound for the open Local Restriction only

%% Backpressure and cathode exhaust
% Profile: platform_default / A11-A12 override candidate.
% The current backpressure regulator reuses the official Pressure Relief
% Valve as a target outlet-pressure interface; it is not yet a valve-opening
% PI controller or product-calibrated exhaust valve model.
routeA_backpressure_control_mode_id = 1; % 1 target_p_ca_out through pressure relief valve
routeA_target_p_ca_out_MPa = env_p + 0.06; % [MPa] Cathode outlet pressure target

%% Humidification and water-management interfaces
% These platform-default L2 interface values make equipment explicit without
% binding the platform to bench or vehicle hardware.
% Intercooler_L2_Interface and separator blocks represent pressure-drop and
% KPI interfaces. SeparatorOrCondensation estimates separated/condensed water
% for audit only and does not rewrite gas composition in the physical network.
separator_condensation_enabled = true; % [-] A8 outlet water-management interface flag
separator_l2_efficiency = 0.5; % [-] First-version separated-water KPI efficiency
separator_l2_source = "l2_saturation_excess_estimator";

cathode_separator_D = cegr_pipe_D; % [m] Cathode EGR water separator hydraulic diameter
cathode_separator_area = pi*cathode_separator_D^2/4; % [m^2] Cathode EGR separator flow area
cathode_separator_length = 0.15; % [m] Equivalent cathode EGR separator gas path length
cathode_separator_extra_length = 0.05; % [m] Equivalent cathode separator manifold length
cathode_separator_roughness = cegr_pipe_roughness; % [m] Equivalent cathode separator roughness
cathode_separator_p0 = env_p; % [MPa] Initial cathode separator pressure target
cathode_separator_T0 = env_T; % [degC] Initial cathode separator temperature target
cathode_separator_dp_nominal = 0.0005; % [MPa] L2 cathode separator nominal pressure drop
cathode_separator_mdot_nominal = 0.10; % [kg/s] L2 cathode separator nominal gas flow
cathode_separator_laminar_fraction = 1e-3; % [-] L2 cathode separator smoothing fraction

routeA_cathode_humidifier_gain = 1; % [-] 1 active, 0 bypass
humidifier_bypass_mode = "command_gain";

%% Anode and hydrogen supply
% Profile: platform_default / simplified relative to cathode-cEGR work.
% The official anode supply and recycle structure is retained for system
% consistency; anode lambda and purge control are deferred beyond A10.1.
tank_p = 70; % [MPa] Fuel tank pressure
tank_yH2 = 1 - 3e-4; % [-] Hydrogen mole fraction
tank_V = 120; % [l] Fuel tank volume
anode_tube_D = 0.02; % [m] Hydrogen tube diameter, A9 second-round 50 kW baseline

anode_separator_D = anode_tube_D; % [m] Anode recycle water separator hydraulic diameter
anode_separator_area = pi*anode_separator_D^2/4; % [m^2] Anode separator flow area
anode_separator_length = 0.12; % [m] Equivalent anode separator gas path length
anode_separator_extra_length = 0.04; % [m] Equivalent anode separator manifold length
anode_separator_roughness = 15e-6; % [m] Equivalent anode separator roughness
anode_separator_p0 = env_p; % [MPa] Initial anode separator pressure target
anode_separator_T0 = env_T; % [degC] Initial anode separator temperature target
anode_separator_dp_nominal = 0.0005; % [MPa] L2 anode separator nominal pressure drop
anode_separator_mdot_nominal = 0.01; % [kg/s] L2 anode separator nominal gas flow
anode_separator_laminar_fraction = 1e-3; % [-] L2 anode separator smoothing fraction

%% Cooling system
% Profile: platform_default / simplified thermal support.
% routeA_stack_temperature_set_C exposes the existing coolant controller
% setpoint. Full thermal-management FCU logic is deferred beyond A10.1.
routeA_stack_temperature_set_C = 80; % [degC] Existing coolant controller setpoint interface
coolant_w_channels = 1; % [cm] Coolant channel width/height
coolant_num_passes = 12; % [-] Number of coolant channel passes per layer
coolant_num_layers = 20; % [-] Number of coolant layers in stack
coolant_tube_D = 0.05; % [m] Coolant tube diameter

radiator_L = 1; % [m] Overall radiator length
radiator_W = 0.025; % [m] Overall radiator width
radiator_H = 0.5; % [m] Overal radiator height
radiator_N_tubes = 25; % [-] Number of coolant tubes
radiator_tube_H = 0.0015; % [m] Height of each coolant tube
radiator_fin_spacing = 0.002; % [-] Fin spacing
radiator_eta_fin = 0.7; % [-] Fin efficiency
radiator_t_wall = 1e-4; % [m] Material thickness
radiator_rho = 2700; % [kg/s] Radiator material density
radiator_cp = 910; % [J/(kg*K)] Radiator material specific heat
radiator_gap_H = (radiator_H - radiator_N_tubes*radiator_tube_H) / (radiator_N_tubes - 1); % [m]
radiator_air_area_primary = 2 * (radiator_N_tubes - 1) * radiator_W * (radiator_L + radiator_gap_H); % [m^2]
radiator_N_fins = (radiator_N_tubes - 1) * radiator_L / radiator_fin_spacing; % [-]
radiator_air_area_fins = 2 * radiator_N_fins * radiator_W * radiator_gap_H; % [m^2]
radiator_tube_Leq = 2*(radiator_H + 20*radiator_tube_H*radiator_N_tubes); % [m]

%% FCU-BoP control interfaces
% Profile: platform_default operational interface.
% Mode 2 derives a total compressor-flow target from current and a
% fresh-air-equivalent OER. With cEGR enabled it does not control the
% actual stack-inlet lambda, which remains a measured/audited quantity.
routeA_air_control_mode_id = 1; % 1 target_total_mdot, 2 target_total_mdot_from_air_equiv_oer, 3 direct_cmd
routeA_target_mdot_comp_inlet = 0.045; % [kg/s] Total compressor-flow target
routeA_target_oer = 2.5; % [-] Model input: fresh-air-equivalent OER for mode 2, not actual lambda_ca_in under cEGR
routeA_compressor_cmd_direct = 0.5; % [-] Open-loop compressor command fraction
routeA_air_pid_Kp = 5; % [-/(kg/s)] First-version mass-flow PI proportional gain
routeA_air_pid_Ki = 0.5; % [-/(kg/s*s)] First-version mass-flow PI integral gain

% cEGR topology is selected at update-diagram time by cEGR_Mode_Selector.
% Keep the full recirculation network installed as the platform default.
% routeA_cegr_enabled=false remains the ZT topology-only regression.
routeA_cegr_enabled = true;
routeA_cegr_valve_mode_id = 0; % 0 closed, 1 open; compile-time EGRValveRestriction Variant
routeA_egr_control_mode_id = 1; % 1 target_ratio, 2 direct_area
routeA_target_egr_ratio_comp_in = 0.02; % [-] abs(cEGR mdot)/abs(compressor inlet mdot)
routeA_egr_target_input_mode_id = 0; % 0 scalar target, 1 workspace profile
routeA_target_egr_ratio_comp_in_profile = [ ...
    0, routeA_target_egr_ratio_comp_in; ...
    2501, routeA_target_egr_ratio_comp_in]; % [s, -] held over platform model horizon
routeA_egr_valve_area_direct = 2e-3 * cegr_pipe_area; % [m^2] Open-loop cEGR valve area
routeA_egr_control_Kp_area = 0.1 * cegr_pipe_area; % [m^2] Area command per ratio error
routeA_egr_control_Ki_area = 0.02 * cegr_pipe_area; % [m^2/s] Area integral gain per ratio error
routeA_egr_valve_actuator_tau = 0.5; % [s] First-order cEGR valve-area actuator lag

%% A10 demo default operating point
routeA_demo_stop_time = 10; % [s] Daily demo stop time
routeA_demo_power_kW = 50.96; % [kW] Nominal platform demo power
routeA_demo_target_mdot_comp_inlet = routeA_target_mdot_comp_inlet; % [kg/s]
routeA_demo_target_egr_ratio_comp_in = routeA_target_egr_ratio_comp_in; % [-]
routeA_demo_target_p_ca_out_MPa = routeA_target_p_ca_out_MPa; % [MPa]

%% External-case guard
% Keep external case data outside the platform-default chain. Scripts that
% intentionally replay legacy bench data must require their own explicit
% enable switch and must not modify the defaults above.
