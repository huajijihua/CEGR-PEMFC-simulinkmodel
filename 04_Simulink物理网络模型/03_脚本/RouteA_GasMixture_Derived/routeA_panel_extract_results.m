function results = routeA_panel_extract_results(out, simCase, context)
% Extract the panel result contract from one completed cold-start simulation.
%
% The panel uses the same electrical-boundary assessor as the formal runner.
% This helper only adds panel-facing aliases, provenance, warning status, and
% the explicit L2 water-capability boundary; it does not create a second KPI
% calculation path.

if nargin < 3 || ~isstruct(context) || ~isscalar(context)
    error('RouteA:PanelResultContext', ...
        'The panel result extractor requires the unified runner context.');
end
if ~isa(out, 'Simulink.SimulationOutput')
    error('RouteA:PanelResultOutputType', ...
        'The panel result extractor requires a Simulink.SimulationOutput.');
end
if strlength(string(out.ErrorMessage)) > 0
    error('RouteA:PanelSimulationFailed', '%s', out.ErrorMessage);
end
requiredContext = {'model', 'caseCfg', 'initialStateMetadata', ...
    'initialStateSelection', 'initializationPolicy', 'tailWindow_s'};
if ~builtin('all', isfield(context, requiredContext))
    error('RouteA:PanelResultContext', ...
        'The unified runner context is missing panel result fields.');
end

paths = routeA_project_paths();
observationReport = routeA_validate_observation_output(out, ...
    routeA_observation_registry(paths));
if ~observationReport.passed
    error('RouteA:ObservationContractFailed', '%s', ...
        strjoin(cellstr(observationReport.errors), newline));
end

audit = routeA_assess_electrical_boundary_outputs( ...
    out, char(context.model), context, context.caseCfg);
logsout = out.get('logsout');
vTs = requiredLoggedTimeseries(logsout, 'routeA_stack_voltage_V');
iTs = requiredLoggedTimeseries(logsout, 'routeA_stack_current_A');
pTs = routeA_stack_electrical_power_timeseries(logsout);
pTs.Name = 'Stack Power';
pTs.DataInfo.Units = 'kW';

waterCapability = l2WaterCapability();
signalManifest = buildSignalManifest(out, paths, observationReport);
warnings = [string(observationReport.warnings(:)); waterCapability.warnings(:)];
failureCategory = string(audit.failureCategory);
if strlength(failureCategory) == 0 && ~audit.passed
    failureCategory = "acceptance_failed";
end
warningOnly = audit.passed && ~isempty(warnings);
if warningOnly
    status = "passed_with_warnings";
elseif audit.passed
    status = "passed";
elseif contains(failureCategory, "not_steady")
    status = "completed_not_steady";
elseif contains(failureCategory, "gas_closure")
    status = "completed_gas_closure_failed";
elseif contains(failureCategory, "electrical_boundary")
    status = "completed_boundary_failed";
else
    status = "completed_acceptance_failed";
end

results = struct();
results.caseId = string(simCase.caseId);
results.status = status;
results.warningOnly = warningOnly;
results.passed = logical(audit.passed);
results.simCompleted = true;
results.failureCategory = failureCategory;
results.errorId = "";
results.errorMessage = "";
results.errors = string(observationReport.errors(:));
results.failureStack = strings(0, 1);
results.warnings = warnings;
results.observationReport = observationReport;
results.signalManifest = signalManifest;
results.model = string(paths.modelName);
results.modelFile = string(paths.modelFile);
results.modelVersion = context.initialStateMetadata.modelVersion;
results.topologyHash = string(context.initialStateMetadata.topologyHash);
results.parameterLayer = string(context.initialStateMetadata.parameterLayer);
results.externalCaseEnabled = logical(context.initialStateMetadata.externalCaseEnabled);
results.case = simCase;
results.parameterSnapshot = simCase;
results.modelAndTopology = struct( ...
    'model', results.model, ...
    'modelFile', results.modelFile, ...
    'modelVersion', results.modelVersion, ...
    'topologyHash', results.topologyHash);
results.solverAndInitialization = struct( ...
    'solver', simCase.solver, ...
    'initialState', context.initialStateMetadata, ...
    'selection', context.initialStateSelection, ...
    'policy', context.initializationPolicy);
results.initialState = context.initialStateMetadata;
results.initialStateSelection = context.initialStateSelection;
results.initialStateMode = string(context.initialStateSelection.mode);
results.initializationPolicy = string(context.initializationPolicy);
results.requestedCegrEnabled = logical(context.requestedCegrEnabled);
results.researchStartTime_s = context.researchStartTime_s;
results.researchDuration_s = context.researchDuration_s;
results.tailLogicalWindow_s = context.tailLogicalWindow_s;
results.tailModelWindow_s = context.tailWindow_s;
results.voltage_V = audit.tail.stackVoltage_V.mean;
results.current_A = audit.tail.stackCurrent_A.mean;
results.power_kW = audit.tail.stackPower_kW.mean;
results.oer = simCase.controls.cathode.targetOer;
results.target_cegr_ratio = context.requestedCegrRatio;
results.cegr_ratio = context.requestedCegrRatio;
results.actual_cegr_ratio = audit.actualRatio;
results.target_command = tailCommand(context);
results.power_source = 'logged_routeA_stack_power_kW';
results.voltage_ts = vTs;
results.current_ts = iTs;
results.power_ts = pTs;
results.tail = audit.tail;
results.steady = audit.steady;
results.steadyPassed = audit.steadyPassed;
results.steadyStrictPassed = audit.steadyStrictPassed;
results.steadyEngineeringPassed = audit.steadyEngineeringPassed;
results.boundary = audit.boundary;
results.boundaryPassed = audit.boundaryPassed;
results.cegr = audit.cegr;
results.cegrPassed = audit.cegrPassed;
results.saturation = audit.saturation;
results.saturationPassed = audit.saturationPassed;
results.gasClosure = audit.gasClosure;
results.gasClosurePassed = audit.gasClosurePassed;
results.purge = audit.purge;
results.tailPurgeFree = audit.tailPurgeFree;
results.lambdaPassed = audit.lambdaPassed;
results.waterCapability = waterCapability;
results.acceptance = struct( ...
    'passed', results.passed, ...
    'status', results.status, ...
    'failureCategory', results.failureCategory, ...
    'waterCapability', waterCapability);
results.resultContractVersion = "RouteA_Panel_Result_v02";
results.outputLevel = "compact_panel";
results.full = struct( ...
    'timeSeries', struct('voltage_V', vTs, 'current_A', iTs, 'power_kW', pTs), ...
    'signalManifest', signalManifest);
results.domains = struct( ...
    'stack', struct( ...
        'voltage_V', results.voltage_V, ...
        'current_A', results.current_A, ...
        'power_kW', results.power_kW, ...
        'temperature_C', audit.tail.stackTemperature_C, ...
        'tail', struct( ...
            'voltage_V', audit.tail.stackVoltage_V, ...
            'current_A', audit.tail.stackCurrent_A, ...
            'power_kW', audit.tail.stackPower_kW, ...
            'temperature_C', audit.tail.stackTemperature_C)), ...
    'cathode', struct( ...
        'compressorInletMassFlow_kg_s', audit.tail.compressorMdot_kg_s, ...
        'compressorInletPressure_Pa', audit.tail.compressorPressure_Pa, ...
         'compressorInletTemperature_K', audit.tail.compressorTemperature_K, ...
         'cathodeOutletTemperature_K', audit.tail.cathodeOutletTemperature_K, ...
         'cathodeOutletPressure_MPa', audit.tail.cathodeOutletPressure_MPa, ...
         'inletRelativeHumidity', audit.tail.rhCaIn, ...
         'outletRelativeHumidity', audit.tail.rhCaOut, ...
         'inletComposition', compositionFields( ...
             audit.gasClosure.inletMassFraction), ...
         'outletComposition', compositionFields( ...
             audit.gasClosure.outletMassFraction), ...
         'inletCompositionMassFraction', audit.gasClosure.inletMassFraction, ...
         'outletCompositionMassFraction', audit.gasClosure.outletMassFraction, ...
         'inletSpeciesMassFlow_kg_s', audit.gasClosure.inletSpeciesMdot_kg_s, ...
         'outletSpeciesMassFlow_kg_s', audit.gasClosure.outletSpeciesMdot_kg_s, ...
         'waterSeparationRate_kg_s', audit.tail.waterSeparator, ...
        'inletOxygenStoich', audit.tail.lambdaCaIn, ...
        'gasClosure', audit.gasClosure), ...
    'cegr', struct( ...
        'targetRatio', context.requestedCegrRatio, ...
        'actualRatio', audit.actualRatio, ...
         'massFlow_kg_s', audit.tail.egrMdot_kg_s, ...
         'valveArea_m2', audit.tail.egrValveArea_m2, ...
         'valveAreaFraction', audit.tail.egrValveAreaFraction, ...
         'valveAreaLimit_m2', context.cegrValveMaxArea_m2, ...
         'valveUpstreamPressure_Pa', audit.tail.egrValveUpstreamPressure_Pa, ...
         'valveDownstreamPressure_Pa', audit.tail.egrValveDownstreamPressure_Pa, ...
         'valveDeltaP_MPa', audit.tail.egrValveDeltaP_MPa, ...
         'abilityStatus', cegrAbilityStatus(audit), ...
         'controlMode', cegrControlField(context, 'controlMode', 1), ...
         'valveMode', cegrControlField(context, 'valveMode', 1), ...
         'targetInputMode', cegrControlField(context, 'targetInputMode', 1), ...
         'upstreamTemperature', notObservable('K', ...
             'No cEGR valve upstream temperature signal is registered.'), ...
         'downstreamTemperature', notObservable('K', ...
             'No cEGR valve downstream temperature signal is registered.'), ...
         'control', audit.cegr, ...
        'saturation', audit.saturation), ...
     'thermal', struct( ...
         'stackTemperature_C', audit.tail.stackTemperature_C, ...
         'cathodeOutletTemperature_K', audit.tail.cathodeOutletTemperature_K, ...
         'status', "stack_temperature_observed"), ...
    'water', waterCapability);
end

function signal = requiredLoggedTimeseries(logsout, name)
if ~any(strcmp(logsout.getElementNames, name))
    error('RouteA:PanelMissingSignal', ...
        'Required logged signal %s is unavailable.', name);
end
element = logsout.get(name);
if isempty(element) || isempty(element.Values) || ...
        ~isa(element.Values, 'timeseries')
    error('RouteA:PanelEmptySignal', ...
        'Required logged signal %s is empty or not a timeseries.', name);
end
signal = element.Values;
end

function value = tailCommand(context)
profile = context.boundaryProfile;
mask = profile.time_s >= context.tailLogicalWindow_s(1) & ...
    profile.time_s < context.tailLogicalWindow_s(2);
if any(mask)
    value = mean(profile.value(mask));
else
    value = profile.value(end);
end
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
    'gapReason', [ ...
        "No explicit liquid-water inventory, liquid transport, drain, or "; ...
        "separator-efficiency model is exposed by the current cathode-cEGR "; ...
        "network; condensed species are removed from gas volumes immediately."], ...
    'warnings', "Liquid-water closure is not available; do not interpret this result as a full liquid-water balance.");
end

function manifest = buildSignalManifest(out, paths, observationReport)
registry = routeA_observation_registry(paths);
template = struct( ...
    'canonicalName', "", 'signalName', "", 'unit', "", ...
    'sourceType', "", 'producerPath', "", 'timeRange_s', [NaN, NaN], ...
    'status', "", 'acceptanceAllowed', false, 'shape', "", 'notes', "");
manifest = repmat(template, registry.count, 1);
present = string(observationReport.present(:));
for idx = 1:registry.count
    entry = registry.entries(idx);
    manifest(idx).canonicalName = entry.canonicalName;
    manifest(idx).signalName = entry.signalName;
    manifest(idx).unit = entry.unit;
    manifest(idx).sourceType = entry.sourceType;
    manifest(idx).producerPath = entry.producerPath;
    manifest(idx).shape = entry.shape;
    manifest(idx).acceptanceAllowed = entry.panelExposure == "result";
    if entry.status == "unresolved"
        manifest(idx).status = "not_observable";
        manifest(idx).acceptanceAllowed = false;
        manifest(idx).notes = entry.unsupportedReason;
        continue;
    end
    available = any(present == entry.signalName) || ...
        outputContains(out, entry.signalName);
    if available
        manifest(idx).status = entry.status;
        manifest(idx).timeRange_s = signalTimeRange(out, entry);
    else
        manifest(idx).status = "missing";
        manifest(idx).acceptanceAllowed = false;
        manifest(idx).notes = "Registered signal was not present in this SimulationOutput.";
    end
end
end

function present = outputContains(out, signalName)
present = false;
try
    if isprop(out, char(signalName))
        present = true;
        return;
    end
catch
end
try
    value = out.get(char(signalName));
    present = ~isempty(value);
catch
end
end

function range = signalTimeRange(out, entry)
range = [NaN, NaN];
try
    value = [];
    if entry.sourceType == "logsout"
        logsout = out.get('logsout');
        element = logsout.get(char(entry.signalName));
        if ~isempty(element)
            value = element.Values;
        end
    else
        value = out.get(char(entry.signalName));
    end
    if isa(value, 'timeseries') && ~isempty(value.Time)
        range = [min(value.Time(:)), max(value.Time(:))];
    elseif isstruct(value) && isfield(value, 'Time') && ~isempty(value.Time)
        range = [min(value.Time(:)), max(value.Time(:))];
    end
catch
end
end

function status = cegrAbilityStatus(audit)
if ~isfield(audit, 'cegr') || ~isfield(audit.cegr, 'targetValue')
    status = "not_observable";
    return;
end
if abs(audit.cegr.targetValue) < eps
    status = "disabled_or_zero_target";
elseif audit.cegr.passed && audit.saturationPassed
    status = "tracking_verified";
elseif ~audit.saturationPassed
    status = "capacity_or_limit";
else
    status = "control_not_tracking";
end
end

function value = cegrControlField(context, field, fallback)
value = fallback;
if isfield(context, 'cegrControls') && isstruct(context.cegrControls) && ...
        isfield(context.cegrControls, field)
    value = context.cegrControls.(field);
end
end

function value = notObservable(unit, reason)
value = struct('value', NaN, 'unit', string(unit), ...
    'status', "not_observable", 'reason', string(reason));
end

function composition = compositionFields(values)
values = double(values(:).');
if numel(values) ~= 4
    composition = struct('N2', NaN, 'O2', NaN, 'H2', NaN, 'H2O', NaN);
    return;
end
% Route A gas ordering is [N2 O2 H2 H2O], read from context.gas and the
% shared platform molar-mass ordering used by the gas-closure assessor.
composition = struct('N2', values(1), 'O2', values(2), ...
    'H2', values(3), 'H2O', values(4));
end
