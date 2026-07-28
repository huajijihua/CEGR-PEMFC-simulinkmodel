function simIn = routeA_panel_build_simulation_input(simCase, rampDuration_s)
% Build SimulationInput from validated simCase (panel helper function)
%
% Inputs:
%   simCase         - validated simCase struct from routeA_validate_case
%   rampDuration_s  - startup ramp duration [s]
%
% Output:
%   simIn           - Simulink.SimulationInput ready for sim() or parsim()
%
% This function is extracted from the panel logic to enable independent
% testing. It implements the assembly chain:
%   simCase -> assemble_command_profile -> SimulationInput
%
% See also: routeA_panel_extract_results, routeA_assemble_command_profile

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', ...
    '01_模型', 'RouteA_GasMixture_Derived');
modelFile = fullfile(modelDir, [model '.slx']);
if ~bdIsLoaded(model)
    load_system(modelFile);
end
paths = routeA_block_paths(model);

validateattributes(rampDuration_s, {'numeric'}, ...
    {'scalar', 'real', 'nonnegative', 'finite'});
validateattributes(simCase.solver.stopTime_s, {'numeric'}, ...
    {'scalar', 'real', 'positive', 'finite'});
if rampDuration_s >= simCase.solver.stopTime_s
    error('RouteA:PanelRampDuration', ...
        'Ramp duration must be less than the simulation stop time.');
end
requiredPaths = {paths.electricalLoad, paths.currentCommand, ...
    paths.powerCommand, paths.voltageReference, paths.voltagePI, ...
    paths.voltageCurrentCommand};
for idx = 1:numel(requiredPaths)
    if getSimulinkBlockHandle(requiredPaths{idx}) < 0
        error('RouteA:PanelBlockPath', ...
            'Required Route A block path does not exist: %s', ...
            requiredPaths{idx});
    end
end

%% 1. Build command profile
study = struct(...
    'researchDuration_s', simCase.solver.stopTime_s, ...
    'commandStartOffset_s', 0.5, ...
    'startupRampDuration_s', rampDuration_s);

profile = routeA_assemble_command_profile(simCase.controls, study);

% The electrical branches use independent time/value FromWorkspace blocks.
% Keep the command profile in the model workspace as the common gas/control
% input, while setting the active electrical branch explicitly below.
electrical = simCase.controls.electrical;
electricalOptions = struct( ...
    'duration_s', simCase.solver.stopTime_s, ...
    'commandStartOffset_s', 0.5, ...
    'startupRampDuration_s', rampDuration_s, ...
    'initialValue', startupValue(electrical.mode), ...
    'label', "electrical_" + lower(string(electrical.mode)));
boundary = routeA_normalize_electrical_profile( ...
    electrical.profile, electrical.mode, electricalOptions);

%% 2. Create SimulationInput
simIn = Simulink.SimulationInput(model);

% Set command profile
simIn = simIn.setVariable('routeA_command_profile', profile.workspaceValue, ...
    'Workspace', model);
simIn = simIn.setVariable(paths.referenceTimeVariable, boundary.time_s, ...
    'Workspace', model);

% The current model keeps the fresh-air Reservoir composition on its
% compile-time y0 expression (env_yO2/env_yH20). The corresponding profile
% diagnostic signals terminate inside Oxygen Source, so explicitly override
% these model-workspace variables for fixed-composition cases.
simIn = simIn.setVariable('env_yO2', ...
    simCase.controls.cathode.o2MoleFraction, 'Workspace', model);
simIn = simIn.setVariable('env_yH20', ...
    simCase.controls.cathode.h2oMoleFraction, 'Workspace', model);

%% 3. Set electrical boundary mode (Variant Subsystem)
simIn = simIn.setBlockParameter(paths.electricalLoad, 'input_type', ...
    simCase.controls.electrical.mode);

%% 4. Set electrical boundary command
switch simCase.controls.electrical.mode
    case 'Current'
        simIn = simIn.setVariable(paths.currentReferenceVariable, ...
            boundary.value, 'Workspace', model);

    case 'Power'
        simIn = simIn.setVariable(paths.powerReferenceVariable, ...
            boundary.value, 'Workspace', model);

    case 'Voltage'
        simIn = simIn.setVariable(paths.voltageReferenceVariable, ...
            boundary.value, 'Workspace', model);

        vc = simCase.controls.electrical.voltageController;
        simIn = simIn.setVariable('routeA_voltage_pi_Kp', vc.Kp_A_V, ...
            'Workspace', model);
        simIn = simIn.setVariable('routeA_voltage_pi_Ki', vc.Ki_A_V_s, ...
            'Workspace', model);
        simIn = simIn.setVariable('routeA_voltage_current_min_A', ...
            vc.currentMin_A, 'Workspace', model);
        simIn = simIn.setVariable('routeA_voltage_current_max_A', ...
            vc.currentMax_A, 'Workspace', model);
end

%% 5. Set air and cEGR control variables explicitly
simIn = simIn.setVariable('routeA_air_control_mode_id', ...
    simCase.controls.cathode.airControlMode, 'Workspace', model);
simIn = simIn.setVariable('routeA_cegr_enabled', ...
    logical(simCase.controls.cegr.enabled), 'Workspace', model);
simIn = simIn.setVariable('routeA_cegr_valve_mode_id', ...
    simCase.controls.cegr.valveMode, 'Workspace', model);
simIn = simIn.setVariable('routeA_egr_control_mode_id', ...
    simCase.controls.cegr.controlMode, 'Workspace', model);
simIn = simIn.setVariable('routeA_egr_target_input_mode_id', ...
    simCase.controls.cegr.targetInputMode, 'Workspace', model);

%% 7. Set solver configuration
simIn = simIn.setModelParameter('StopTime', num2str(simCase.solver.stopTime_s));
simIn = simIn.setModelParameter('StartTime', '0', ...
    'SolverType', 'Variable-step', ...
    'LoadInitialState', 'off', ...
    'ReturnWorkspaceOutputs', simCase.solver.returnWorkspaceOutputs);
simIn = simIn.setModelParameter('Solver', simCase.solver.solver);
simIn = simIn.setModelParameter('RelTol', num2str(simCase.solver.relTol));
simIn = simIn.setModelParameter('AbsTol', num2str(simCase.solver.absTol));
simIn = simIn.setModelParameter('MaxStep', num2str(simCase.solver.maxStep_s));
simIn = simIn.setModelParameter('SignalLogging', simCase.solver.signalLogging);
simIn = simIn.setModelParameter('SignalLoggingName', simCase.solver.signalLoggingName);

%% 8. Set Simscape logging
simIn = simIn.setModelParameter('SimscapeLogType', simCase.solver.simscapeLogType);

end

function value = startupValue(mode)
params = routeA_platform_default_parameters();
switch string(mode)
    case "Current"
        value = params.controls.current_startup_A.value;
    case "Power"
        value = params.controls.power_startup_kW.value;
    case "Voltage"
        value = params.controls.voltage_startup_ref_V.value;
    otherwise
        error('RouteA:PanelElectricalMode', ...
            'Unsupported electrical mode: %s.', string(mode));
end
end
