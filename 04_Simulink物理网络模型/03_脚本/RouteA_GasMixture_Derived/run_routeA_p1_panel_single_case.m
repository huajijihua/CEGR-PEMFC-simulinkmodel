function result = run_routeA_p1_panel_single_case(boundaryType, command, options)
% Run exactly one P1 panel/model validation case.
%
% This entry point intentionally accepts one electrical boundary and one
% command only. Research matrices and Cartesian products remain outside P1.

if nargin < 3 || isempty(options)
    options = struct();
end
if ~isstruct(options) || ~isscalar(options)
    error('RouteA:P1SingleCaseOptions', ...
        'options must be a scalar struct.');
end

boundaryType = string(boundaryType);
if ~isscalar(boundaryType) || ...
        ~any(boundaryType == ["Current", "Power", "Voltage"])
    error('RouteA:P1SingleCaseBoundary', ...
        'boundaryType must be Current, Power, or Voltage.');
end
validateattributes(command, {'numeric'}, ...
    {'real', 'finite', 'nonempty'});

defaults = struct( ...
    'caseId', "", ...
    'stopTime_s', 600, ...
    'rampDuration_s', [], ...
    'targetOer', [], ...
    'airControlMode', [], ...
    'targetMdot_kg_s', [], ...
    'directCommand', [], ...
    'sourcePressure_MPa_abs', [], ...
    'sourceTemperature_C', [], ...
    'outletPressure_MPa_abs', [], ...
    'humidifierRH', [], ...
    'humidifierEnabled', [], ...
    'o2MoleFraction', [], ...
    'h2oMoleFraction', [], ...
    'stackTemperatureSet_C', [], ...
    'cegrEnabled', false, ...
    'cegrRatio', 0, ...
    'valveMode', [], ...
    'controlMode', [], ...
    'targetInputMode', [], ...
    'solver', [], ...
    'relTol', [], ...
    'absTol', [], ...
    'maxStep_s', [], ...
    'voltageController', [], ...
    'outputFile', "");
names = fieldnames(options);
for idx = 1:numel(names)
    if ~isfield(defaults, names{idx})
        error('RouteA:P1SingleCaseOption', ...
            'Unsupported single-case option: %s.', names{idx});
    end
    defaults.(names{idx}) = options.(names{idx});
end

validateattributes(defaults.stopTime_s, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
if isempty(defaults.rampDuration_s)
    defaults.rampDuration_s = min(60, 0.1 * defaults.stopTime_s);
end
validateattributes(defaults.rampDuration_s, {'numeric'}, ...
    {'scalar', 'nonnegative', 'finite'});
if defaults.rampDuration_s >= defaults.stopTime_s
    error('RouteA:P1SingleCaseRamp', ...
        'rampDuration_s must be less than stopTime_s.');
end
validateattributes(defaults.cegrRatio, {'numeric'}, ...
    {'scalar', 'nonnegative', 'finite'});
defaults.cegrEnabled = logical(defaults.cegrEnabled);

if strlength(string(defaults.caseId)) == 0
    defaults.caseId = "P1_single_" + lower(boundaryType);
else
    defaults.caseId = string(defaults.caseId);
end

simCase = routeA_simCase_template();
simCase.caseId = defaults.caseId;
simCase.controls.electrical.mode = char(boundaryType);
simCase.controls.electrical.profile = command;
if ~isempty(defaults.voltageController)
    simCase.controls.electrical.voltageController = defaults.voltageController;
end
if ~isempty(defaults.airControlMode)
    simCase.controls.cathode.airControlMode = defaults.airControlMode;
end
if ~isempty(defaults.targetMdot_kg_s)
    simCase.controls.cathode.targetMdot_kg_s = defaults.targetMdot_kg_s;
end
if ~isempty(defaults.directCommand)
    simCase.controls.cathode.directCommand = defaults.directCommand;
end
if ~isempty(defaults.sourcePressure_MPa_abs)
    simCase.controls.cathode.sourcePressure_MPa_abs = ...
        defaults.sourcePressure_MPa_abs;
end
if ~isempty(defaults.sourceTemperature_C)
    simCase.controls.cathode.sourceTemperature_C = ...
        defaults.sourceTemperature_C;
end
if ~isempty(defaults.outletPressure_MPa_abs)
    simCase.controls.cathode.outletPressure_MPa_abs = ...
        defaults.outletPressure_MPa_abs;
end
if ~isempty(defaults.humidifierRH)
    simCase.controls.cathode.humidifierRH = defaults.humidifierRH;
end
if ~isempty(defaults.humidifierEnabled)
    simCase.controls.cathode.humidifierEnabled = defaults.humidifierEnabled;
end
if ~isempty(defaults.o2MoleFraction)
    simCase.controls.cathode.o2MoleFraction = defaults.o2MoleFraction;
end
if ~isempty(defaults.h2oMoleFraction)
    simCase.controls.cathode.h2oMoleFraction = defaults.h2oMoleFraction;
end
simCase.controls.cegr.enabled = defaults.cegrEnabled;
simCase.controls.cegr.targetRatio = defaults.cegrRatio;
if ~isempty(defaults.valveMode)
    simCase.controls.cegr.valveMode = defaults.valveMode;
end
if ~isempty(defaults.controlMode)
    simCase.controls.cegr.controlMode = defaults.controlMode;
end
if ~isempty(defaults.targetInputMode)
    simCase.controls.cegr.targetInputMode = defaults.targetInputMode;
end
if ~isempty(defaults.targetOer)
    simCase.controls.cathode.targetOer = defaults.targetOer;
end
if ~isempty(defaults.stackTemperatureSet_C)
    validateattributes(defaults.stackTemperatureSet_C, {'numeric'}, ...
        {'scalar', 'real', 'finite'});
    simCase.controls.thermal.stackTemperatureSet_C = ...
        defaults.stackTemperatureSet_C;
end
simCase.solver.stopTime_s = defaults.stopTime_s;
if ~isempty(defaults.solver)
    simCase.solver.solver = defaults.solver;
end
if ~isempty(defaults.relTol)
    simCase.solver.relTol = defaults.relTol;
end
if ~isempty(defaults.absTol)
    simCase.solver.absTol = defaults.absTol;
end
if ~isempty(defaults.maxStep_s)
    simCase.solver.maxStep_s = defaults.maxStep_s;
end

[simIn, context] = routeA_panel_build_simulation_input( ...
    simCase, defaults.rampDuration_s);
out = sim(simIn);
result = routeA_panel_extract_results(out, simCase, context);
result.panelValidation = struct( ...
    'scope', "P1_single_case", ...
    'boundaryType', boundaryType, ...
    'matrixExecuted', false, ...
    'cEGREnabled', defaults.cegrEnabled, ...
    'runEntry', "routeA_panel_build_simulation_input", ...
    'parameterSnapshot', simCase, ...
    'modelAndTopology', result.modelAndTopology, ...
    'failureStack', result.failureStack, ...
    'exportReadback', struct('passed', false, 'file', ""));
if strlength(string(defaults.outputFile)) > 0
    [result, readback] = routeA_panel_export_result(result, defaults.outputFile);
    result.panelValidation.exportReadback = readback;
end
end
