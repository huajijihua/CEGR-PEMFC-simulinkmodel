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
results.warnings = warnings;
results.observationReport = observationReport;
results.model = string(paths.modelName);
results.modelFile = string(paths.modelFile);
results.modelVersion = context.initialStateMetadata.modelVersion;
results.topologyHash = string(context.initialStateMetadata.topologyHash);
results.parameterLayer = string(context.initialStateMetadata.parameterLayer);
results.externalCaseEnabled = logical(context.initialStateMetadata.externalCaseEnabled);
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
