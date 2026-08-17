function result = routeA_panel_failure_result(ME, simCase, context)
% Build a failure result that follows the P1 result contract.
%
% This path is independent of SimulationOutput so validation, model
% assembly, solver, and observation failures remain auditable in the panel.

if nargin < 2 || isempty(simCase) || ~isstruct(simCase) || ~isscalar(simCase)
    simCase = routeA_simCase_template();
end
if nargin < 3 || ~isstruct(context) || ~isscalar(context)
    context = struct();
end

paths = routeA_project_paths();
caseId = string(getFieldOr(simCase, 'caseId', "unknown"));
errorId = string(ME.identifier);
errorMessage = string(ME.message);
failureStack = failureReport(ME);
failureCategory = classifyFailure(errorId, errorMessage);
modelVersion = fileVersion(paths.modelFile);
initialStateMode = getNestedFieldOr(simCase, ...
    {'initialState', 'mode'}, "cold");

result = struct();
result.resultContractVersion = "RouteA_Panel_Result_v03";
result.caseId = caseId;
result.status = "failed";
result.warningOnly = false;
result.passed = false;
result.simCompleted = false;
result.failureCategory = failureCategory;
result.errorId = errorId;
result.errorMessage = errorMessage;
result.errors = [errorMessage; failureStack];
result.failureStack = failureStack;
result.warnings = strings(0, 1);
result.model = string(paths.modelName);
result.modelFile = string(paths.modelFile);
result.modelVersion = modelVersion;
result.topologyHash = "not_available_until_simulation";
result.parameterLayer = "platform_default";
result.externalCaseEnabled = false;
result.case = simCase;
result.parameterSnapshot = simCase;
result.modelAndTopology = struct( ...
    'model', result.model, ...
    'modelFile', result.modelFile, ...
    'modelVersion', modelVersion, ...
    'topologyHash', result.topologyHash, ...
    'status', "not_read_back_before_failure");
result.solverAndInitialization = struct( ...
    'solver', getFieldOr(simCase, 'solver', struct()), ...
    'initialState', getFieldOr(context, 'initialStateMetadata', struct()), ...
    'selection', getFieldOr(context, 'initialStateSelection', struct()), ...
    'policy', getFieldOr(context, 'initializationPolicy', "cold_start_only"));
result.initialStateMode = string(initialStateMode);
result.initializationPolicy = string(getFieldOr(context, ...
    'initializationPolicy', "cold_start_only"));
result.requestedCegrEnabled = logical(getNestedFieldOr(simCase, ...
    {'controls', 'cegr', 'enabled'}, false));
result.requestedCegrRatio = double(getNestedFieldOr(simCase, ...
    {'controls', 'cegr', 'targetRatio'}, 0)) * ...
    double(result.requestedCegrEnabled);
result.researchStartTime_s = NaN;
result.researchDuration_s = getNestedFieldOr(simCase, ...
    {'solver', 'stopTime_s'}, NaN);
result.tailLogicalWindow_s = [NaN, NaN];
result.tailModelWindow_s = [NaN, NaN];
result.outputLevel = "compact_panel";
result.observationReport = failureObservationReport(paths, errorMessage);
result.signalManifest = failureSignalManifest(paths);
result.waterCapability = l2WaterCapability();
result.acceptance = struct( ...
    'passed', false, ...
    'status', result.status, ...
    'failureCategory', result.failureCategory, ...
    'waterCapability', result.waterCapability);
result.domains = struct( ...
    'stack', domainUnavailable("stack"), ...
    'cathode', domainUnavailable("cathode"), ...
    'cegr', domainUnavailable("cegr"), ...
    'thermal', domainUnavailable("thermal"), ...
    'water', result.waterCapability);
result.full = struct( ...
    'compact', removeFullField(result), ...
    'signalManifest', result.signalManifest);
end

function category = classifyFailure(identifier, message)
id = lower(string(identifier));
msg = lower(string(message));
if any(contains(id, ["observation", "missing_signal", "empty_signal"]))
    category = "observation_contract";
elseif any(contains(id, ["export", "result_export"]))
    category = "export";
elseif any(contains(id, ["simulation", "simulink", "solver"]))
    category = "simulation";
elseif any(contains(id, ["validate", "input", "range", "case", "aircontrol", ...
        "cegr", "ramp", "boundary", "voltagecontroller"])) || ...
        any(contains(msg, ["must be", "requires", "invalid", "unsupported"]))
    category = "input_validation";
else
    category = "panel_runtime";
end
end

function text = failureReport(ME)
try
    text = string(getReport(ME, 'extended', 'hyperlinks', 'off'));
catch
    text = string(ME.message);
end
end

function value = getFieldOr(parent, fieldName, fallback)
value = fallback;
if isstruct(parent) && isscalar(parent) && isfield(parent, fieldName)
    value = parent.(fieldName);
end
end

function value = getNestedFieldOr(parent, names, fallback)
value = parent;
for idx = 1:numel(names)
    if isstruct(value) && isscalar(value) && isfield(value, names{idx})
        value = value.(names{idx});
    else
        value = fallback;
        return;
    end
end
end

function version = fileVersion(fileName)
info = dir(fileName);
if isempty(info)
    version = struct('fileName', string(fileName), 'modified', "missing", ...
        'bytes', NaN);
else
    version = struct('fileName', string(info.name), ...
        'modified', string(info.date), 'bytes', double(info.bytes));
end
end

function report = failureObservationReport(paths, message)
registry = routeA_observation_registry(paths);
required = registry.entries([registry.entries.required]);
report = struct( ...
    'passed', false, ...
    'required', string({required.signalName}), ...
    'present', strings(0, 1), ...
    'missing', string({required.signalName}), ...
    'warnings', strings(0, 1), ...
    'errors', string(message));
end

function manifest = failureSignalManifest(paths)
registry = routeA_observation_registry(paths);
template = struct( ...
    'canonicalName', "", 'signalName', "", 'unit', "", ...
    'sourceType', "", 'producerPath', "", 'timeRange_s', [NaN, NaN], ...
    'status', "", 'acceptanceAllowed', false, 'shape', "", 'notes', "");
manifest = repmat(template, registry.count, 1);
for idx = 1:registry.count
    entry = registry.entries(idx);
    manifest(idx).canonicalName = entry.canonicalName;
    manifest(idx).signalName = entry.signalName;
    manifest(idx).unit = entry.unit;
    manifest(idx).sourceType = entry.sourceType;
    manifest(idx).producerPath = entry.producerPath;
    manifest(idx).shape = entry.shape;
    manifest(idx).status = "not_available_due_to_failure";
    manifest(idx).notes = "No completed SimulationOutput was available.";
    if entry.status == "unresolved"
        manifest(idx).status = "not_observable";
        manifest(idx).notes = entry.unsupportedReason;
    end
end
end

function value = domainUnavailable(domain)
value = struct('domain', string(domain), 'status', "not_available", ...
    'reason', "No completed SimulationOutput was available.");
end

function capability = l2WaterCapability()
capability = struct( ...
    'level', "L2", ...
    'liquidWaterInventoryClosed', false, ...
    'liquidWaterTransportClosed', false, ...
    'liquidDrainClosed', false, ...
    'separatorEfficiencyClosed', false, ...
    'fullWaterBalanceClosed', false, ...
    'liquidWaterConclusionAllowed', false, ...
    'status', "L2_not_closed", ...
    'scope', "gas-phase and condensation-flux evidence only", ...
    'warnings', "Liquid-water closure is not available; do not interpret this result as a full liquid-water balance.");
end

function value = removeFullField(result)
value = result;
if isfield(value, 'full')
    value = rmfield(value, 'full');
end
end
