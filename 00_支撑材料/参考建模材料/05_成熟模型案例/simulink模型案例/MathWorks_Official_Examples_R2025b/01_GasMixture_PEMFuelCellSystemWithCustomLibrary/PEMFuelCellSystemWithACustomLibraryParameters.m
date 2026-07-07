%% Code to define parameters for PEMFuelCellSystemWithACustomLibrary
% Open Model Workspace in the Model Explorer to view and modify parameter
% values. Click 'Reinitialize from Source' to reset to the parameter values
% in this script.

% Copyright 2020 The MathWorks, Inc.

load PEMFuelCellSystemWithACustomLibraryDriveCycle.mat

% Environment conditions
env_p = 0.101325; % [MPa] Pressure
env_T = 20; % [degC] Temperature
env_yO2 = 0.21; % [-] Oxygen mole fraction
env_RH = 0.5; % [-] Relative humidity
% Calculate equivalent water mole fraction
Gas_properties_block= 'PEMFuelCellSystemWithACustomLibrary/Gas Mixture Properties';
T_TLU= eval( get_param(Gas_properties_block, 'T_LUT') ); % Temperature table [K]
pSat_TLU= eval( get_param(Gas_properties_block, 'pSat') ); % Saturation pressures table [kPa]
pSat_H2O_TLU= pSat_TLU(4,:); % [MPa] Water saturation table
env_pSat_H2O = interp1(T_TLU, pSat_H2O_TLU, env_T + 273.15) * 1e-3; % [MPa]
env_yH20 = env_RH * env_pSat_H2O / env_p; % [-] Water mole fraction

% Hydrogen fuel
tank_p = 70; % [MPa] Fuel tank pressure
tank_yH2 = 1 - 3e-4; % [-] Hydrogen mole fraction
tank_V = 120; % [l] Fuel tank volume

% Fuel cell stack
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

anode_tube_D = 0.01; % [m] Hydrogen tube diameter
cathode_tube_D = 0.05; % [m] Air tube diameter

% Coolant system
coolant_w_channels = 1; % [cm] Coolant channel width/height
coolant_num_passes = 12; % [-] Number of coolant channel passes per layer
coolant_num_layers = 20; % [-] Number of coolant layers in stack
coolant_tube_D = 0.05; % [m] Coolant tube diameter

% Radiator dimensions
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

radiator_gap_H = (radiator_H - radiator_N_tubes*radiator_tube_H) / (radiator_N_tubes - 1); % [m] Height between coolant tubes
radiator_air_area_primary = 2 * (radiator_N_tubes - 1) * radiator_W * (radiator_L + radiator_gap_H); % [m^2] Primary air heat transfer surface area
radiator_N_fins = (radiator_N_tubes - 1) * radiator_L / radiator_fin_spacing; % [-] Total number of fins
radiator_air_area_fins = 2 * radiator_N_fins * radiator_W * radiator_gap_H; % [m^2] Total fin surface area
radiator_tube_Leq = 2*(radiator_H + 20*radiator_tube_H*radiator_N_tubes); % [m] Additional equivalent tube length for losses due to manifold and splits

% Compressor map
comp_p_ratio_TLU = [1; 1.25; 1.5; 1.75; 2]; % [-] Pressure ratio vector
comp_rpm_TLU = [0, 1800, 3600]; % [rpm] Shaft speed vector
comp_mdot_corr_TLU = [
    0, 0.05,   0.1;
    0, 0.0375, 0.075;
    0, 0.025,  0.05;
    0, 0.0125, 0.025;
    0, 0,      0] * 4; % [kg/s] Corrected mass flow rate table
