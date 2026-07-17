function [in, metadata] = routeA_attach_platform_default_initial_state( ...
    in, model, modelDir, initialStateFile)
% Attach a validated mode-1 platform_default operating point to a simulation.
%
% This function restores only the saved physical/controller state and checks
% model/topology compatibility. Metadata records the state provenance; it
% does not prescribe any study command. The caller owns current/power,
% air/OER, cEGR, pressure/backpressure, humidity, and thermal-control
% commands after choosing the initial state.

if nargin < 4 || strlength(string(initialStateFile)) == 0
    initialStateFile = fullfile(modelDir, ...
        'RouteA_platform_default_initial_state.mat');
end
if ~isfile(initialStateFile)
    error('RouteA:MissingPlatformDefaultInitialState', ...
        ['The required platform_default initial state is missing: %s. ', ...
        'Run routeA_generate_platform_default_initial_state first.'], ...
        initialStateFile);
end
loaded = load(initialStateFile, 'routeA_initial_state', ...
    'routeA_initial_metadata');
if ~isfield(loaded, 'routeA_initial_state') || ...
        ~isfield(loaded, 'routeA_initial_metadata')
    error('RouteA:InvalidPlatformDefaultInitialState', ...
        'The initial-state file does not contain the required variables.');
end
metadata = loaded.routeA_initial_metadata;
if ~isa(loaded.routeA_initial_state, 'Simulink.op.ModelOperatingPoint')
    error('RouteA:InitialStateClassMismatch', ...
        'The platform_default initial state must be a ModelOperatingPoint.');
end
if ~isfield(metadata, 'model') || string(metadata.model) ~= string(model)
    error('RouteA:InitialStateModelMismatch', ...
        'The saved platform_default state belongs to another model.');
end
if ~isfield(metadata, 'cegrTopologyEnabled') || ...
        ~metadata.cegrTopologyEnabled
    error('RouteA:InitialStateTopologyMismatch', ...
        ['The saved state is not for the CEGR-enabled zero-recirculation ', ...
        'topology required by Route A dynamic studies.']);
end
requiredModeFields = {'cegrValveModeId', 'egrReferenceKind'};
if ~builtin('all', isfield(metadata, requiredModeFields)) || ...
        metadata.cegrValveModeId ~= 1 || ...
        string(metadata.egrReferenceKind) ~= "mode1_zero_target_near_zero"
    error('RouteA:InitialStateModeMismatch', ...
        ['The saved state is not a mode-1 zero-target near-zero cEGR ', ...
        'platform_default operating point.']);
end
if ~bdIsLoaded(model)
    error('RouteA:ModelNotLoaded', ...
        'Load the Route A model before attaching its initial state.');
end
mw = get_param(model, 'ModelWorkspace');
mw.assignin('routeA_cegr_enabled', true);
mw.assignin('routeA_cegr_valve_mode_id', 1);
set_param(model, 'SimulationCommand', 'update');
in = in.setInitialState(loaded.routeA_initial_state);
end
