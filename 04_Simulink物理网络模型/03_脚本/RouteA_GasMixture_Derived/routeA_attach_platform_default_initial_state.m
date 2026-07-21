function [in, metadata] = routeA_attach_platform_default_initial_state( ...
    in, model, modelDir, initialStateFile, loadInputType)
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
if nargin < 5 || strlength(string(loadInputType)) == 0
    loadInputType = "Step";
end
loadInputType = string(loadInputType);
if ~isscalar(loadInputType) || ...
        ~any(loadInputType == ["Step", "Drive cycle", "Voltage"])
    error('RouteA:InitialStateLoadInputType', ...
        'loadInputType must be Step, Drive cycle, or Voltage.');
end
if ~isfile(initialStateFile)
    error('RouteA:MissingPlatformDefaultInitialState', ...
        ['The required platform_default initial state is missing: %s. ', ...
        'Run routeA_generate_platform_default_initial_state first.'], ...
        initialStateFile);
end
loaded = load(initialStateFile);
[initialState, metadata] = selectLoadVariant(loaded, loadInputType);
if ~isa(initialState, 'Simulink.op.ModelOperatingPoint')
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
if ~isfield(metadata, 'cegrValveMaxArea_m2')
    error('RouteA:InitialStateParameterMetadata', ...
        ['The platform_default initial state does not record ', ...
        'cegrValveMaxArea_m2. Regenerate the formal initial state.']);
end
stateValveArea_m2 = metadata.cegrValveMaxArea_m2;
currentValveArea_m2 = mw.getVariable('cegr_valve_max_area');
validateattributes(stateValveArea_m2, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(currentValveArea_m2, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
if abs(stateValveArea_m2 - currentValveArea_m2) > ...
        1e-12 * max(1, abs(currentValveArea_m2))
    error('RouteA:InitialStateParameterMismatch', ...
        ['The platform_default initial state and model workspace disagree ', ...
        'on cegr_valve_max_area. Regenerate the formal initial state.']);
end
mw.assignin('routeA_cegr_enabled', true);
mw.assignin('routeA_cegr_valve_mode_id', 1);
loadPath = Simulink.ID.getFullName([model ':368']);
set_param(loadPath, 'input_type', char(loadInputType));
set_param(model, 'SimulationCommand', 'update');
% The ModelOperatingPoint was created through SimulationInput with this
% variant mask override. Preserve that override on the caller's input so
% the operating-point checksum is evaluated against the same active branch.
in = in.setBlockParameter(loadPath, 'input_type', char(loadInputType));
in = in.setInitialState(initialState);
end

function [initialState, metadata] = selectLoadVariant(loaded, loadInputType)
if loadInputType == "Step"
    stateField = 'routeA_initial_state';
    metadataField = 'routeA_initial_metadata';
elseif loadInputType == "Drive cycle"
    stateField = 'routeA_initial_state_drive_cycle';
    metadataField = 'routeA_initial_metadata_drive_cycle';
else
    stateField = 'routeA_initial_state_voltage';
    metadataField = 'routeA_initial_metadata_voltage';
end
isStandaloneCandidate = false;
if isfield(loaded, stateField) && isfield(loaded, metadataField)
    initialState = loaded.(stateField);
    metadata = loaded.(metadataField);
elseif isfield(loaded, 'routeA_initial_state') && ...
        isfield(loaded, 'routeA_initial_metadata')
    % Generators write a single generic pair before the atomic bundle
    % promotion. Accept it only when its explicit mode matches the caller.
    initialState = loaded.routeA_initial_state;
    metadata = loaded.routeA_initial_metadata;
    isStandaloneCandidate = true;
else
    error('RouteA:MissingPlatformDefaultLoadVariant', ...
        ['The platform_default initial-state file does not contain the ', ...
        'required %s operating point.'], loadInputType);
end
if (loadInputType ~= "Step" || isStandaloneCandidate) && ...
        (~isfield(metadata, 'loadInputType') || ...
        string(metadata.loadInputType) ~= loadInputType)
    error('RouteA:PlatformDefaultLoadVariantMetadata', ...
        'The selected operating point is not marked as %s compatible.', ...
        loadInputType);
end
end
