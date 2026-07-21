function study = run_routeA_stage1_constant_power_cegr_matrix(studyCfg)
% Route A Stage 1 nominal constant-power cEGR capability matrix.
%
% The Electrical Load Drive cycle variant converts the requested stack power
% to a controlled-current command using P/v. This runner separates two
% physical interpretations of that load command:
%   1) air mode 2 lets total compressor flow follow the resulting stack current;
%   2) air mode 1 holds total compressor flow at the zero-cEGR mode-2 reference.
% A passing power command alone is not reported as oxygen-supply capability.

if nargin < 1 || isempty(studyCfg)
    studyCfg = struct();
end

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', ...
    'RouteA_GasMixture_Derived');
model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
addpath(modelDir);
cd(modelDir);
cleanup = onCleanup(@() routeA_restore_model_and_folder( ...
    model, modelFile, oldDir));

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
cfg = studyConfig(model, modelDir, studyCfg);

[adaptiveCases, adaptiveOutputs] = runAirModeCases( ...
    model, modelFile, modelDir, cfg, 2, NaN, ...
    "current_linked_total_mdot");
adaptiveGroup = finalizeAirModeGroup(adaptiveCases, cfg, ...
    "current_linked_total_mdot", NaN);

fixedMdotTarget_kg_s = adaptiveGroup.zeroTargetCompressorMdot_kg_s;
validateattributes(fixedMdotTarget_kg_s, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
[fixedCases, ~] = runAirModeCases( ...
    model, modelFile, modelDir, cfg, 1, fixedMdotTarget_kg_s, ...
    "fixed_total_mdot");
fixedGroup = finalizeAirModeGroup(fixedCases, cfg, ...
    "fixed_total_mdot", fixedMdotTarget_kg_s);

[waterLedger, waterLedgerPassed] = runAdaptiveWaterLedger( ...
    adaptiveOutputs, cfg, model);

study = struct();
study.timestamp = string(datetime('now', 'Format', ...
    'yyyy-MM-dd HH:mm:ss'));
study.model = string(model);
study.parameterLayer = cfg.parameterLayer;
study.externalCaseEnabled = cfg.externalCaseEnabled;
study.targetPower_kW = cfg.targetPower_kW;
study.targetAirEquivalentOer = cfg.targetAirEquivalentOer;
study.cegrValveMaxArea_m2 = cfg.cegrValveMaxArea_m2;
study.initialState = adaptiveGroup.cases(1).initialState;
study.initialStateSource = cfg.initialStateMetadata;
study.initialStateKind = "formal_platform_default_drive_cycle";
study.researchDuration_s = cfg.researchDuration_s;
study.tailLogicalWindow_s = cfg.tailLogicalWindow_s;
study.studyMaxStep_s = cfg.studyMaxStep_s;
study.targetRatios = cfg.targetRatios;
study.adaptiveAir = adaptiveGroup;
study.fixedTotalFlow = fixedGroup;
study.fixedTotalFlowTarget_kg_s = fixedMdotTarget_kg_s;
study.waterLedger = waterLedger;
study.waterLedgerPassed = waterLedgerPassed;
study.adaptivePowerAndOxygenClosurePassed = adaptiveGroup.passed;
study.fixedFlowDiagnosticCompleted = fixedGroup.diagnosticCompleted;
study.fixedFlowOxygenFeasible = fixedGroup.oxygenFeasible;
study.fixedFlowPowerCommandMaintained = fixedGroup.powerCommandMaintained;
study.passed = study.adaptivePowerAndOxygenClosurePassed && ...
    study.fixedFlowDiagnosticCompleted && study.waterLedgerPassed;
study.summaryTable = buildSummaryTable(adaptiveGroup.cases, fixedGroup.cases);
assignin('base', 'routeA_stage1_constant_power_cegr_matrix', study);
assignin('base', 'routeA_stage1_constant_power_summary', study.summaryTable);
assignin('base', 'routeA_stage1_constant_power_water_ledger', ...
    study.waterLedger);
displayStudy(study);

clear adaptiveOutputs cleanup;
end

function cfg = studyConfig(model, modelDir, studyCfg)
studyCfg = normalizeStudyConfig(studyCfg);
initialStateFile = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state.mat');
loaded = load(initialStateFile, 'routeA_initial_metadata_drive_cycle');
if ~isfield(loaded, 'routeA_initial_metadata_drive_cycle')
    error('RouteA:ConstantPowerInitialState', ...
        ['The Drive cycle platform_default initial-state metadata is ', ...
        'unavailable.']);
end
metadata = loaded.routeA_initial_metadata_drive_cycle;
requiredMetadata = {'snapshotTimeS', 'targetPower_kW', ...
    'cegrTopologyEnabled', 'cegrValveModeId', 'egrReferenceKind'};
if ~builtin('all', isfield(metadata, requiredMetadata))
    error('RouteA:ConstantPowerInitialStateMetadata', ...
        'The platform_default initial-state metadata is incomplete.');
end
if ~metadata.cegrTopologyEnabled || metadata.cegrValveModeId ~= 1 || ...
        string(metadata.egrReferenceKind) ~= "mode1_zero_target_near_zero"
    error('RouteA:ConstantPowerInitialStateMode', ...
        'The constant-power matrix requires the formal mode-1 zero-target state.');
end
if ~isfield(metadata, 'loadInputType') || ...
        string(metadata.loadInputType) ~= "Drive cycle"
    error('RouteA:ConstantPowerInitialStateLoadVariant', ...
        ['The constant-power matrix requires the formal Drive cycle ', ...
        'operating point.']);
end

mw = get_param(model, 'ModelWorkspace');
if strcmp(mw.DataSource, 'MATLAB File')
    mw.reload;
end
parameterLayer = string(mw.getVariable('routeA_parameter_layer'));
externalCaseEnabled = logical(mw.getVariable('routeA_external_case_enabled'));
if parameterLayer ~= "platform_default" || externalCaseEnabled
    error('RouteA:ConstantPowerParameterBoundary', ...
        ['The constant-power matrix requires platform_default with ', ...
        'external_case disabled.']);
end

stackCells = mw.getVariable('stack_num_cells');
maxValveArea = mw.getVariable('cegr_valve_max_area');
rpmTable = mw.getVariable('comp_rpm_TLU');
initialPower_kW = metadata.targetPower_kW;
validateattributes(stackCells, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(maxValveArea, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(rpmTable, {'numeric'}, {'vector', 'nonempty', 'finite'});
validateattributes(initialPower_kW, {'numeric'}, {'scalar', 'positive', 'finite'});

cfg = struct();
cfg.model = string(model);
cfg.modelDir = modelDir;
cfg.initialStateFile = initialStateFile;
cfg.initialStateMetadata = metadata;
cfg.parameterLayer = parameterLayer;
cfg.externalCaseEnabled = externalCaseEnabled;
cfg.stackCells = stackCells;
cfg.cegrValveMaxArea_m2 = maxValveArea;
cfg.compressorRpmLookupBounds = [min(rpmTable), max(rpmTable)];
cfg.initialPower_kW = initialPower_kW;
cfg.targetPower_kW = studyCfg.targetPower_kW;
cfg.targetAirEquivalentOer = studyCfg.targetAirEquivalentOer;
cfg.researchDuration_s = studyCfg.researchDuration_s;
cfg.tailLogicalWindow_s = studyCfg.tailLogicalWindow_s;
cfg.studyMaxStep_s = studyCfg.studyMaxStep_s;
cfg.commandStepOffset_s = 0.5;
cfg.powerTrackingStartOffset_s = 1.0;
cfg.targetRatios = [0, 0.10, 0.30];
cfg.powerTrackingRelativeTolerance = studyCfg.powerTrackingRelativeTolerance;
cfg.powerSpanAbsoluteTolerance_kW = ...
    studyCfg.powerSpanAbsoluteTolerance_kW;
cfg.powerSpanRelativeTolerance = ...
    studyCfg.powerSpanRelativeTolerance;
cfg.airMdotTrackingRelativeTolerance = 0.02;
cfg.airMdotTrackingAbsoluteTolerance_kg_s = 5e-4;
cfg.lambdaLowerBound = 1;
cfg.purgeDropSlope_1_s = -0.02;
cfg.faradayConstant_C_mol = 96485.33212;
cfg.molarMass_kg_mol = [0.0280134, 0.0319988, 0.00201588, 0.01801528];
cfg.gas = struct( ...
    'n2Index', 1, ...
    'o2Index', 2, ...
    'h2oIndex', 4, ...
    'absoluteResidualTolerance_kg_s', 5e-4, ...
    'relativeResidualTolerance', 0.05);
cfg = assignRuntimeWindows(cfg, metadata);
cfg.electricalLoadPath = Simulink.ID.getFullName([char(cfg.model) ':368']);
end

function studyCfg = normalizeStudyConfig(studyCfg)
if ~isstruct(studyCfg) || numel(studyCfg) ~= 1
    error('RouteA:ConstantPowerStudyConfig', ...
        'The study configuration must be a scalar struct.');
end
defaults = struct( ...
    'targetPower_kW', 77.408, ...
    'targetAirEquivalentOer', 3, ...
    'researchDuration_s', 600, ...
    'tailLogicalWindow_s', [540, 600], ...
    'studyMaxStep_s', 5, ...
    'powerTrackingRelativeTolerance', 0.005, ...
    'powerSpanAbsoluteTolerance_kW', 0.05, ...
    'powerSpanRelativeTolerance', 0.005);
names = fieldnames(studyCfg);
for idx = 1:numel(names)
    name = names{idx};
    if ~isfield(defaults, name)
        error('RouteA:ConstantPowerStudyConfigField', ...
            'Unsupported study configuration field: %s.', name);
    end
    defaults.(name) = studyCfg.(name);
end
validateattributes(defaults.targetPower_kW, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(defaults.targetAirEquivalentOer, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(defaults.researchDuration_s, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(defaults.tailLogicalWindow_s, {'numeric'}, ...
    {'vector', 'numel', 2, 'nonnegative', 'finite'});
defaults.tailLogicalWindow_s = defaults.tailLogicalWindow_s(:).';
if defaults.tailLogicalWindow_s(2) <= defaults.tailLogicalWindow_s(1) || ...
        defaults.tailLogicalWindow_s(2) > defaults.researchDuration_s
    error('RouteA:ConstantPowerTailWindow', ...
        'The logical tail window must be increasing and within the study duration.');
end
validateattributes(defaults.studyMaxStep_s, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(defaults.powerTrackingRelativeTolerance, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(defaults.powerSpanAbsoluteTolerance_kW, {'numeric'}, ...
    {'scalar', 'nonnegative', 'finite'});
validateattributes(defaults.powerSpanRelativeTolerance, {'numeric'}, ...
    {'scalar', 'nonnegative', 'finite'});
studyCfg = defaults;
end

function cfg = assignRuntimeWindows(cfg, metadata)
cfg.researchStartTime_s = metadata.snapshotTimeS;
cfg.commandStepTime_s = cfg.researchStartTime_s + cfg.commandStepOffset_s;
cfg.modelStopTime_s = cfg.researchStartTime_s + cfg.researchDuration_s;
cfg.tailWindow_s = cfg.researchStartTime_s + cfg.tailLogicalWindow_s;
cfg.powerTrackingWindow_s = cfg.tailWindow_s;
cfg.lambdaTransitionDiagnosticWindow_s = [ ...
    cfg.researchStartTime_s + cfg.powerTrackingStartOffset_s, ...
    cfg.tailWindow_s(1)];
end

function [cases, caseOutputs] = runAirModeCases( ...
    model, modelFile, modelDir, cfg, airModeId, fixedMdotTarget_kg_s, airMode)
cases = repmat(emptyCaseResult(), numel(cfg.targetRatios), 1);
caseOutputs = repmat(emptyCaseOutput(), numel(cfg.targetRatios), 1);
for idx = 1:numel(cfg.targetRatios)
    targetRatio = cfg.targetRatios(idx);
    [cases(idx), caseOutputs(idx)] = runCase( ...
        model, modelFile, modelDir, cfg, airModeId, ...
        fixedMdotTarget_kg_s, airMode, targetRatio);
end
end

function [result, caseOutput] = runCase( ...
    model, modelFile, modelDir, cfg, airModeId, fixedMdotTarget_kg_s, ...
    airMode, targetRatio)
result = initializeCase(cfg, airModeId, fixedMdotTarget_kg_s, ...
    airMode, targetRatio);
caseOutput = emptyCaseOutput();
caseOutput.caseId = result.caseId;
caseOutput.targetRatio = targetRatio;
caseOutput.modeId = 1;
caseOutput.airModeId = airModeId;

try
    resetModelFromDisk(model, modelFile);
    refreshModelWorkspace(model);
    in = Simulink.SimulationInput(model);
    [in, initialStateMetadata] = routeA_attach_platform_default_initial_state( ...
        in, model, modelDir, cfg.initialStateFile, "Drive cycle");
    routeA_mark_observability_signals(model);
    in = in.setModelParameter( ...
        'StopTime', sprintf('%.16g', cfg.modelStopTime_s), ...
        'MaxStep', sprintf('%.16g', cfg.studyMaxStep_s), ...
        'SignalLogging', 'on', ...
        'SignalLoggingName', 'logsout', ...
        'ReturnWorkspaceOutputs', 'on', ...
        'SimscapeLogType', 'all');
    in = in.setVariable('drive_cycle_time', ...
        [cfg.researchStartTime_s; ...
        cfg.commandStepTime_s - 1e-3; ...
        cfg.commandStepTime_s; cfg.modelStopTime_s], ...
        'Workspace', model);
    in = in.setVariable('drive_cycle_power', ...
        [cfg.initialPower_kW; cfg.initialPower_kW; ...
        cfg.targetPower_kW; cfg.targetPower_kW], 'Workspace', model);
    in = in.setVariable('routeA_air_control_mode_id', airModeId, ...
        'Workspace', model);
    in = in.setVariable('routeA_target_oer', cfg.targetAirEquivalentOer, ...
        'Workspace', model);
    if airModeId == 1
        in = in.setVariable('routeA_target_mdot_comp_inlet', ...
            fixedMdotTarget_kg_s, 'Workspace', model);
    end
    in = in.setVariable('routeA_egr_control_mode_id', 1, ...
        'Workspace', model);
    in = in.setVariable('routeA_cegr_valve_mode_id', 1, ...
        'Workspace', model);
    in = in.setVariable('routeA_egr_target_input_mode_id', 1, ...
        'Workspace', model);
    in = in.setVariable('routeA_target_egr_ratio_comp_in', targetRatio, ...
        'Workspace', model);
    in = in.setVariable('routeA_target_egr_ratio_comp_in_profile', ...
        [cfg.researchStartTime_s, 0; ...
        cfg.commandStepTime_s - 1e-3, 0; ...
        cfg.commandStepTime_s, targetRatio; ...
        cfg.modelStopTime_s, targetRatio], 'Workspace', model);

    out = sim(in);
    result = collectCaseResult(out, model, cfg, result);
    result.initialState = initialStateMetadata;
    caseOutput.out = out;
    caseOutput.initialState = initialStateMetadata;
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = string(ME.message);
    if ~isempty(ME.stack)
        result.errorLocation = string(ME.stack(1).name) + ":" + ...
            string(ME.stack(1).line);
    end
end
end

function result = initializeCase( ...
    cfg, airModeId, fixedMdotTarget_kg_s, airMode, targetRatio)
result = emptyCaseResult();
result.caseId = string(airMode) + "_cegr_" + ...
    replace(sprintf('%.2f', targetRatio), '.', 'p');
result.airMode = string(airMode);
result.airModeId = airModeId;
result.fixedMdotTarget_kg_s = fixedMdotTarget_kg_s;
result.targetRatio = targetRatio;
result.targetPower_kW = cfg.targetPower_kW;
result.targetAirEquivalentOer = cfg.targetAirEquivalentOer;
result.cegrValveMaxArea_m2 = cfg.cegrValveMaxArea_m2;
result.researchStartModelTime_s = cfg.researchStartTime_s;
result.researchDuration_s = cfg.researchDuration_s;
result.tailLogicalWindow_s = cfg.tailLogicalWindow_s;
result.tailModelWindow_s = cfg.tailWindow_s;
result.powerTrackingWindow_s = cfg.powerTrackingWindow_s;
result.lambdaTransitionDiagnosticWindow_s = ...
    cfg.lambdaTransitionDiagnosticWindow_s;
end

function result = collectCaseResult(out, model, cfg, result)
logsout = out.logsout;
ratio = loggedTimeseries(logsout, 'routeA_egr_ratio_comp_in');
area = loggedTimeseries(logsout, 'routeA_egr_valve_area_cmd');
pUp = loggedTimeseries(logsout, 'routeA_p_egr_valve_up');
pDown = loggedTimeseries(logsout, 'routeA_p_egr_valve_down');
compMdot = magnitudeTimeseries(loggedTimeseries(logsout, ...
    'routeA_mdot_comp_inlet'));
compP = loggedTimeseries(logsout, 'routeA_p_comp_inlet');
compT = loggedTimeseries(logsout, 'routeA_T_comp_inlet');
compCmd = loggedTimeseries(logsout, 'routeA_compressor_cmd');
compRpm = loggedTimeseries(logsout, 'routeA_compressor_rpm');
airMdotSet = magnitudeTimeseries(loggedTimeseries(logsout, ...
    'routeA_air_mdot_set'));
airControlError = loggedTimeseries(logsout, 'routeA_air_control_error');
egrMdot = magnitudeTimeseries(loggedTimeseries(logsout, 'routeA_egr_mdot'));
stackCurrent = loggedTimeseries(logsout, 'routeA_stack_current_A');
stackVoltage = loggedTimeseries(logsout, 'routeA_stack_voltage_V');
stackPower = routeA_stack_electrical_power_timeseries(logsout);
stackTemperature = loggedTimeseries(logsout, 'routeA_stack_temperature_C');
rhIn = waterRelativeHumidity(outputTimeseries(out, logsout, ...
    'routeA_RH_ca_in', 'routeA_RH_ca_in_ts'), 'routeA_RH_ca_in');
rhOut = waterRelativeHumidity(outputTimeseries(out, logsout, ...
    'routeA_RH_ca_out', 'routeA_RH_ca_out_ts'), 'routeA_RH_ca_out');
waterSeparator = outputTimeseries(out, logsout, 'routeA_m_water_sep', ...
    'routeA_m_water_sep_ts');
speciesMdot = out.get('routeA_mdot_species_ca_in_ts');
[~, speciesTotal, speciesMassFraction] = inletSpeciesMetrics(speciesMdot);
inletTotalMdot = timeseries(speciesTotal, speciesMdot.Time);
inletO2MassFraction = timeseries(speciesMassFraction(:, 2), ...
    speciesMdot.Time);
lambdaCaIn = inletOxygenStoich(speciesMdot, stackCurrent, cfg.stackCells);
egrAtCompressorTime = interpolate(egrMdot.Time, egrMdot.Data, ...
    compMdot.Time);
freshAirApprox = timeseries(compMdot.Data - egrAtCompressorTime, ...
    compMdot.Time);
airMdotSetAtCompressorTime = interpolate(airMdotSet.Time, ...
    airMdotSet.Data, compMdot.Time);
compressorMdotTrackingError = timeseries(compMdot.Data - ...
    airMdotSetAtCompressorTime, compMdot.Time);
pDownAtUp = interpolate(pDown.Time, pDown.Data, pUp.Time);
pressureDeltaMPa = timeseries((pUp.Data - pDownAtUp) * 1e-6, pUp.Time);
areaFraction = timeseries(area.Data / cfg.cegrValveMaxArea_m2, area.Time);

tail = struct();
tail.egrRatio = windowStats(ratio, cfg.tailWindow_s);
tail.egrMdot_kg_s = windowStats(egrMdot, cfg.tailWindow_s);
tail.freshAirApprox_kg_s = windowStats(freshAirApprox, cfg.tailWindow_s);
tail.inletTotalMdot_kg_s = windowStats(inletTotalMdot, cfg.tailWindow_s);
tail.stackCurrent_A = windowStats(stackCurrent, cfg.tailWindow_s);
tail.stackVoltage_V = windowStats(stackVoltage, cfg.tailWindow_s);
tail.stackPower_kW = windowStats(stackPower, cfg.tailWindow_s);
tail.stackTemperature_C = windowStats(stackTemperature, cfg.tailWindow_s);
tail.compressorMdot_kg_s = windowStats(compMdot, cfg.tailWindow_s);
tail.compressorMdotSet_kg_s = windowStats(airMdotSet, cfg.tailWindow_s);
tail.compressorMdotTrackingError_kg_s = windowStats( ...
    compressorMdotTrackingError, cfg.tailWindow_s);
tail.airControlError_kg_s = windowStats(airControlError, cfg.tailWindow_s);
tail.compressorPressure_Pa = windowStats(compP, cfg.tailWindow_s);
tail.compressorTemperature_K = windowStats(compT, cfg.tailWindow_s);
tail.compressorCommand = windowStats(compCmd, cfg.tailWindow_s);
tail.compressorRpm = windowStats(compRpm, cfg.tailWindow_s);
tail.egrValveDeltaP_MPa = windowStats(pressureDeltaMPa, cfg.tailWindow_s);
tail.egrValveAreaFraction = windowStats(areaFraction, cfg.tailWindow_s);
tail.rhCaIn = windowStats(rhIn, cfg.tailWindow_s);
tail.rhCaOut = windowStats(rhOut, cfg.tailWindow_s);
tail.waterSeparator = windowStats(waterSeparator, cfg.tailWindow_s);
tail.lambdaCaIn = windowStats(lambdaCaIn, cfg.tailWindow_s);
tail.inletO2MassFraction = windowStats(inletO2MassFraction, ...
    cfg.tailWindow_s);

powerData = windowData(stackPower, cfg.powerTrackingWindow_s, ...
    'stack power');
powerRelativeError = max(abs(powerData - result.targetPower_kW)) / ...
    max(abs(result.targetPower_kW), 1e-6);
lambdaTransition = windowData(lambdaCaIn, ...
    cfg.lambdaTransitionDiagnosticWindow_s, 'lambda_ca_in');
compressorMdotTrackingData = windowData(compressorMdotTrackingError, ...
    cfg.tailWindow_s, 'compressor mass-flow tracking error');
gasClosure = routeA_stage1_cathode_gas_closure_from_outputs(out, model, cfg);
purge = purgeStats(out, model, cfg);

result.simCompleted = true;
result.tail = tail;
result.actualRatio = tail.egrRatio.mean;
result.targetError = result.actualRatio - result.targetRatio;
result.targetTolerance = targetTolerance(result.targetRatio);
result.powerTrackingMaxRelativeError = powerRelativeError;
result.powerTailMeanRelativeError = abs(tail.stackPower_kW.mean - ...
    result.targetPower_kW) / max(abs(result.targetPower_kW), 1e-6);
result.powerTailSpanTolerance_kW = tailPowerSpanTolerance(tail, cfg);
result.compressorMdotTrackingMaxAbsError_kg_s = ...
    max(abs(compressorMdotTrackingData));
result.compressorMdotTrackingTolerance_kg_s = max( ...
    cfg.airMdotTrackingRelativeTolerance * ...
    abs(tail.compressorMdotSet_kg_s.mean), ...
    cfg.airMdotTrackingAbsoluteTolerance_kg_s);
result.lambdaTailMin = tail.lambdaCaIn.minimum;
result.lambdaTransitionMin = finiteMinimum(lambdaTransition);
result.finiteTail = tailFinite(tail);
result.powerTrackingPassed = ...
    result.powerTrackingMaxRelativeError <= cfg.powerTrackingRelativeTolerance;
result.powerTailSpanPassed = tail.stackPower_kW.span <= ...
    result.powerTailSpanTolerance_kW;
result.powerCommandMaintained = result.powerTrackingPassed && ...
    result.powerTailSpanPassed;
result.trackingPassed = abs(result.targetError) <= result.targetTolerance;
result.compressorMdotTrackingPassed = ...
    result.compressorMdotTrackingMaxAbsError_kg_s <= ...
    result.compressorMdotTrackingTolerance_kg_s;
result.lambdaPassed = tail.lambdaCaIn.nonfiniteCount == 0 && ...
    result.lambdaTailMin > cfg.lambdaLowerBound;
result.pressureDirectionPassed = result.targetRatio == 0 || ...
    tail.egrValveDeltaP_MPa.mean > 0;
result.areaPassed = tail.egrValveAreaFraction.minimum >= 0 && ...
    tail.egrValveAreaFraction.maximum < 1 - 1e-6;
result.compressorRpmLookupPassed = ...
    tail.compressorRpm.minimum >= cfg.compressorRpmLookupBounds(1) - 1e-9 && ...
    tail.compressorRpm.maximum <= cfg.compressorRpmLookupBounds(2) + 1e-9;
result.gasClosure = gasClosure;
result.gasClosurePassed = gasClosure.passed;
result.purge = purge;
result.tailPurgeFree = purge.tailEventCount == 0;
result.localPassed = result.finiteTail && result.powerCommandMaintained && ...
    result.trackingPassed && result.compressorMdotTrackingPassed && ...
    result.lambdaPassed && result.pressureDirectionPassed && ...
    result.areaPassed && result.compressorRpmLookupPassed && ...
    result.gasClosurePassed && result.tailPurgeFree;
result.diagnosticPassed = result.finiteTail && ...
    result.powerCommandMaintained && result.trackingPassed && ...
    result.compressorMdotTrackingPassed && result.pressureDirectionPassed && ...
    result.areaPassed && result.compressorRpmLookupPassed && ...
    result.gasClosurePassed && result.tailPurgeFree;
result.failureCategory = failureCategory(result);
end

function group = finalizeAirModeGroup(cases, cfg, airMode, fixedMdotTarget_kg_s)
targetRatios = [cases.targetRatio];
zeroIndex = find(abs(targetRatios) < eps, 1);
if isempty(zeroIndex)
    error('RouteA:ConstantPowerZeroReference', ...
        'The zero-target cEGR case is missing for %s.', airMode);
end
reference = cases(zeroIndex);
if ~reference.simCompleted
    error('RouteA:ConstantPowerZeroReference', ...
        ['The zero-target cEGR case failed for %s: %s at %s. ', ...
        '%s'], airMode, reference.errorId, reference.errorLocation, ...
        reference.errorMessage);
end
for idx = 1:numel(cases)
    if cases(idx).simCompleted
        cases(idx).deltaToZeroTarget = deltaToReference(cases(idx), reference);
    end
end

group = struct();
group.airMode = string(airMode);
group.airModeId = cases(1).airModeId;
group.fixedMdotTarget_kg_s = fixedMdotTarget_kg_s;
group.zeroTargetCompressorMdotSet_kg_s = ...
    reference.tail.compressorMdotSet_kg_s.mean;
group.zeroTargetCompressorMdot_kg_s = ...
    reference.tail.compressorMdot_kg_s.mean;
group.cases = cases;
group.allSimulationsCompleted = builtin('all', [cases.simCompleted]);
group.powerCommandMaintained = builtin('all', [cases.powerCommandMaintained]);
group.diagnosticCompleted = builtin('all', [cases.diagnosticPassed]);
group.oxygenFeasible = builtin('all', [cases.lambdaPassed]);
group.passed = builtin('all', [cases.localPassed]);
if isfinite(fixedMdotTarget_kg_s)
    setpoints = arrayfun(@(item) item.tail.compressorMdotSet_kg_s.mean, cases);
    group.fixedTotalFlowSetpointMaxError_kg_s = max(abs(setpoints - ...
        fixedMdotTarget_kg_s));
    group.fixedTotalFlowSetpointPassed = ...
        group.fixedTotalFlowSetpointMaxError_kg_s <= max( ...
        cfg.airMdotTrackingRelativeTolerance * fixedMdotTarget_kg_s, ...
        cfg.airMdotTrackingAbsoluteTolerance_kg_s);
    group.diagnosticCompleted = group.diagnosticCompleted && ...
        group.fixedTotalFlowSetpointPassed;
else
    group.fixedTotalFlowSetpointMaxError_kg_s = NaN;
    group.fixedTotalFlowSetpointPassed = true;
end
end

function [ledger, passed] = runAdaptiveWaterLedger(caseOutputs, cfg, model)
requiredRatios = [0, 0.30];
selected = repmat(emptyCaseOutput(), numel(requiredRatios), 1);
for idx = 1:numel(requiredRatios)
    match = find(abs([caseOutputs.targetRatio] - requiredRatios(idx)) < eps);
    if numel(match) ~= 1 || ...
            ~isa(caseOutputs(match).out, 'Simulink.SimulationOutput')
        ledger = struct( ...
            'attempted', false, ...
            'auditPassed', false, ...
            'skipReason', "missing_adaptive_constant_power_output", ...
            'cases', struct([]));
        passed = false;
        return;
    end
    selected(idx) = caseOutputs(match);
end

waterCfg = struct();
waterCfg.model = model;
waterCfg.initialStateMetadata = selected(1).initialState;
waterCfg.targetRatios = requiredRatios;
waterCfg.researchStartTime_s = cfg.researchStartTime_s;
waterCfg.researchDuration_s = cfg.researchDuration_s;
waterCfg.modelStopTime_s = cfg.modelStopTime_s;
waterCfg.tailLogicalWindow_s = cfg.tailLogicalWindow_s;
waterCfg.tailWindow_s = cfg.tailWindow_s;
waterCfg.loadTrackingMode = "constant_power";
waterCfg.powerTrackingWindow_s = cfg.powerTrackingWindow_s;
waterCfg.targetPower_kW = cfg.targetPower_kW;
waterCfg.powerTrackingRelativeTolerance = cfg.powerTrackingRelativeTolerance;
waterCfg.targetAirEquivalentOer = cfg.targetAirEquivalentOer;
waterCfg.meaClosureTolerance_kg_s = 1e-6;
waterCfg.localGasBalanceAbsTolerance_kg = 1e-6;
waterCfg.localGasBalanceRelativeTolerance = 1e-3;
waterCfg.systemGasBalanceAbsTolerance_kg = 5e-6;
waterCfg.systemGasBalanceRelativeTolerance = 5e-5;
waterCfg.species = struct('n2', 1, 'o2', 2, 'h2', 3, 'h2o', 4);
try
    ledger = routeA_stage1_water_ledger_from_outputs(selected, waterCfg);
    ledger.attempted = true;
    passed = ledger.auditPassed;
catch ME
    errorLocation = "";
    if ~isempty(ME.stack)
        errorLocation = string(ME.stack(1).name) + ":" + ...
            string(ME.stack(1).line);
    end
    ledger = struct( ...
        'attempted', true, ...
        'auditPassed', false, ...
        'errorId', string(ME.identifier), ...
        'errorMessage', string(ME.message), ...
        'errorLocation', errorLocation, ...
        'cases', struct([]));
    passed = false;
end
end

function summary = buildSummaryTable(adaptiveCases, fixedCases)
cases = [adaptiveCases(:); fixedCases(:)];
count = numel(cases);
airMode = strings(count, 1);
targetRatio = NaN(count, 1);
actualRatio = NaN(count, 1);
power = NaN(count, 1);
powerError = NaN(count, 1);
current = NaN(count, 1);
voltage = NaN(count, 1);
compressorMdot = NaN(count, 1);
compressorMdotSet = NaN(count, 1);
freshAir = NaN(count, 1);
egrMdot = NaN(count, 1);
lambdaTailMin = NaN(count, 1);
inletO2MassFraction = NaN(count, 1);
powerCommandMaintained = false(count, 1);
lambdaPassed = false(count, 1);
gasClosurePassed = false(count, 1);
diagnosticPassed = false(count, 1);
passed = false(count, 1);
for idx = 1:count
    item = cases(idx);
    airMode(idx) = item.airMode;
    targetRatio(idx) = item.targetRatio;
    actualRatio(idx) = item.actualRatio;
    power(idx) = item.tail.stackPower_kW.mean;
    powerError(idx) = item.powerTailMeanRelativeError;
    current(idx) = item.tail.stackCurrent_A.mean;
    voltage(idx) = item.tail.stackVoltage_V.mean;
    compressorMdot(idx) = item.tail.compressorMdot_kg_s.mean;
    compressorMdotSet(idx) = item.tail.compressorMdotSet_kg_s.mean;
    freshAir(idx) = item.tail.freshAirApprox_kg_s.mean;
    egrMdot(idx) = item.tail.egrMdot_kg_s.mean;
    lambdaTailMin(idx) = item.lambdaTailMin;
    inletO2MassFraction(idx) = item.tail.inletO2MassFraction.mean;
    powerCommandMaintained(idx) = item.powerCommandMaintained;
    lambdaPassed(idx) = item.lambdaPassed;
    gasClosurePassed(idx) = item.gasClosurePassed;
    diagnosticPassed(idx) = item.diagnosticPassed;
    passed(idx) = item.localPassed;
end
summary = table(airMode, targetRatio, actualRatio, power, powerError, ...
    current, voltage, compressorMdot, compressorMdotSet, freshAir, egrMdot, ...
    lambdaTailMin, inletO2MassFraction, powerCommandMaintained, lambdaPassed, ...
    gasClosurePassed, diagnosticPassed, passed);
end

function delta = deltaToReference(item, reference)
delta = struct();
names = {'stackPower_kW', 'stackCurrent_A', 'stackVoltage_V', ...
    'compressorMdot_kg_s', 'compressorMdotSet_kg_s', ...
    'freshAirApprox_kg_s', 'egrMdot_kg_s', 'lambdaCaIn', ...
    'inletO2MassFraction'};
for idx = 1:numel(names)
    name = names{idx};
    delta.(name) = item.tail.(name).mean - reference.tail.(name).mean;
end
end

function tolerance_kW = tailPowerSpanTolerance(tail, cfg)
tolerance_kW = max(cfg.powerSpanAbsoluteTolerance_kW, ...
    cfg.powerSpanRelativeTolerance * abs(tail.stackPower_kW.mean));
end

function tolerance = targetTolerance(targetRatio)
if targetRatio == 0
    tolerance = 1e-4;
else
    tolerance = max(0.002, 0.10 * targetRatio);
end
end

function result = emptyCaseResult()
result = struct( ...
    'caseId', "", ...
    'airMode', "", ...
    'airModeId', NaN, ...
    'fixedMdotTarget_kg_s', NaN, ...
    'targetRatio', NaN, ...
    'actualRatio', NaN, ...
    'targetError', NaN, ...
    'targetTolerance', NaN, ...
    'targetPower_kW', NaN, ...
    'targetAirEquivalentOer', NaN, ...
    'cegrValveMaxArea_m2', NaN, ...
    'initialState', struct(), ...
    'researchStartModelTime_s', NaN, ...
    'researchDuration_s', NaN, ...
    'tailLogicalWindow_s', NaN(1, 2), ...
    'tailModelWindow_s', NaN(1, 2), ...
    'powerTrackingWindow_s', NaN(1, 2), ...
    'lambdaTransitionDiagnosticWindow_s', NaN(1, 2), ...
    'simCompleted', false, ...
    'errorId', "", ...
    'errorMessage', "", ...
    'errorLocation', "", ...
    'tail', struct(), ...
    'deltaToZeroTarget', struct(), ...
    'powerTrackingMaxRelativeError', Inf, ...
    'powerTailMeanRelativeError', Inf, ...
    'powerTailSpanTolerance_kW', NaN, ...
    'compressorMdotTrackingMaxAbsError_kg_s', Inf, ...
    'compressorMdotTrackingTolerance_kg_s', NaN, ...
    'lambdaTailMin', NaN, ...
    'lambdaTransitionMin', NaN, ...
    'finiteTail', false, ...
    'powerTrackingPassed', false, ...
    'powerTailSpanPassed', false, ...
    'powerCommandMaintained', false, ...
    'trackingPassed', false, ...
    'compressorMdotTrackingPassed', false, ...
    'lambdaPassed', false, ...
    'pressureDirectionPassed', false, ...
    'areaPassed', false, ...
    'compressorRpmLookupPassed', false, ...
    'gasClosure', struct(), ...
    'gasClosurePassed', false, ...
    'purge', struct(), ...
    'tailPurgeFree', false, ...
    'diagnosticPassed', false, ...
    'localPassed', false, ...
    'failureCategory', "");
end

function output = emptyCaseOutput()
output = struct( ...
    'caseId', "", ...
    'targetRatio', NaN, ...
    'out', [], ...
    'initialState', struct(), ...
    'modeId', NaN, ...
    'airModeId', NaN);
end

function purge = purgeStats(out, model, cfg)
simlog = out.get(get_param(model, 'SimscapeLogName'));
mea = routeA_simscape_log_mea(simlog);
time = mea.x_i_anode.series.time;
anode = seriesMatrix(mea.x_i_anode.series.values('1'), time, ...
    'anode composition');
slope = diff(anode(:, 1)) ./ diff(time(:));
candidate = find(slope < cfg.purgeDropSlope_1_s);
if isempty(candidate)
    eventTimes = zeros(0, 1);
else
    eventIndices = candidate([true; diff(candidate) > 1]) + 1;
    eventTimes = time(eventIndices);
end
tailEvents = eventTimes(eventTimes >= cfg.tailWindow_s(1) & ...
    eventTimes < cfg.tailWindow_s(2));
purge = struct('eventTimesModel_s', eventTimes(:).', ...
    'tailEventTimesModel_s', tailEvents(:).', ...
    'tailEventCount', numel(tailEvents));
end

function lambda = inletOxygenStoich(speciesMdot, stackCurrent, stackCells)
species = abs(seriesMatrix(speciesMdot.Data, speciesMdot.Time, ...
    'cathode inlet species mass flow'));
current = interpolate(stackCurrent.Time, stackCurrent.Data, ...
    speciesMdot.Time);
o2SupplyMolS = species(:, 2) / 0.0319988;
o2ConsumptionMolS = stackCells * abs(current) / (4 * 96485.33212);
lambda = timeseries(o2SupplyMolS ./ o2ConsumptionMolS, speciesMdot.Time);
end

function [species, total, massFraction] = inletSpeciesMetrics(speciesMdot)
species = abs(seriesMatrix(speciesMdot.Data, speciesMdot.Time, ...
    'cathode inlet species mass flow'));
total = sum(species, 2);
if any(total <= 0) || any(~isfinite(total))
    error('RouteA:ConstantPowerInletSpecies', ...
        'Cathode inlet species total is nonpositive or nonfinite.');
end
massFraction = species ./ total;
end

function rh = waterRelativeHumidity(signal, signalName)
data = seriesMatrix(signal.Data, signal.Time, signalName);
if size(data, 2) < 4
    error('RouteA:ConstantPowerHumidityShape', ...
        'Relative-humidity signal does not contain the water component.');
end
rh = timeseries(data(:, 4), signal.Time);
end

function stats = windowStats(signal, window)
values = windowData(signal, window, 'windowed signal');
finiteValues = values(isfinite(values));
stats = struct('mean', NaN, 'std', NaN, 'span', Inf, ...
    'minimum', NaN, 'maximum', NaN, 'sampleCount', numel(values), ...
    'nonfiniteCount', sum(~isfinite(values)));
if ~isempty(finiteValues)
    stats.mean = mean(finiteValues);
    stats.std = std(finiteValues);
    stats.span = max(finiteValues) - min(finiteValues);
    stats.minimum = min(finiteValues);
    stats.maximum = max(finiteValues);
end
end

function values = windowData(signal, window, label)
mask = signal.Time >= window(1) & signal.Time < window(2);
values = signal.Data(mask);
values = values(:);
if isempty(values)
    error('RouteA:ConstantPowerEmptyWindow', ...
        'No samples were found for %s.', label);
end
end

function signal = loggedTimeseries(logsout, name)
element = logsout.get(name);
if isempty(element) || isempty(element.Values)
    error('RouteA:ConstantPowerMissingSignal', ...
        'The required logged signal is unavailable: %s.', name);
end
signal = element.Values;
end

function signal = outputTimeseries(out, logsout, logName, outputName)
if datasetHasElement(logsout, logName)
    element = logsout.get(logName);
    if ~isempty(element) && ~isempty(element.Values)
        signal = element.Values;
        return;
    end
end
signal = out.get(outputName);
end

function present = datasetHasElement(dataset, name)
present = false;
try
    present = any(strcmp(dataset.getElementNames, name));
catch
end
end

function signal = magnitudeTimeseries(signal)
signal = timeseries(abs(signal.Data), signal.Time);
end

function values = interpolate(time, data, targetTime)
values = interp1(time, data(:), targetTime, 'linear', 'extrap');
values = values(:);
if any(~isfinite(values))
    error('RouteA:ConstantPowerInterpolation', ...
        'Could not align time bases.');
end
end

function data = seriesMatrix(data, time, signalName)
data = squeeze(data);
if isvector(data)
    if isscalar(time)
        data = reshape(data, 1, []);
    else
        data = data(:);
    end
end
if size(data, 1) ~= numel(time)
    data = data.';
end
if size(data, 1) ~= numel(time)
    error('RouteA:ConstantPowerSeriesShape', ...
        'Unexpected signal shape for %s.', signalName);
end
end

function passed = tailFinite(tail)
names = fieldnames(tail);
passed = true;
for idx = 1:numel(names)
    if tail.(names{idx}).nonfiniteCount ~= 0
        passed = false;
        return;
    end
end
end

function value = finiteMinimum(values)
values = values(isfinite(values));
if isempty(values)
    value = NaN;
else
    value = min(values);
end
end

function category = failureCategory(result)
reasons = strings(1, 0);
if ~result.simCompleted
    reasons(end + 1) = "simulation";
end
if ~result.powerCommandMaintained
    reasons(end + 1) = "power_command";
end
if ~result.lambdaPassed
    reasons(end + 1) = "oxygen_supply";
end
if ~result.trackingPassed
    reasons(end + 1) = "cegr_tracking";
end
if ~result.gasClosurePassed
    reasons(end + 1) = "gas_closure";
end
if ~result.tailPurgeFree
    reasons(end + 1) = "tail_purge";
end
category = strjoin(reasons, ";");
end

function resetModelFromDisk(model, modelFile)
if bdIsLoaded(model)
    close_system(model, 0);
end
load_system(modelFile);
end

function refreshModelWorkspace(model)
mw = get_param(model, 'ModelWorkspace');
if strcmp(mw.DataSource, 'MATLAB File')
    mw.reload;
end
end

function displayStudy(study)
fprintf('\nRoute A Stage 1 constant-power cEGR matrix\n');
fprintf(['  P_ref=%.4g kW | OER=%.4g | duration=%.0f s | ', ...
    'tail=[%.0f,%.0f) s | MaxStep=%.4g s\n'], ...
    study.targetPower_kW, study.targetAirEquivalentOer, ...
    study.researchDuration_s, study.tailLogicalWindow_s(1), ...
    study.tailLogicalWindow_s(2), study.studyMaxStep_s);
fprintf(['  adaptive air passed=%d | fixed-flow diagnostic=%d | ', ...
    'fixed-flow oxygen feasible=%d | water=%d | study=%d\n'], ...
    study.adaptivePowerAndOxygenClosurePassed, ...
    study.fixedFlowDiagnosticCompleted, study.fixedFlowOxygenFeasible, ...
    study.waterLedgerPassed, study.passed);
fprintf('  fixed total compressor-flow reference=%.4g kg/s\n', ...
    study.fixedTotalFlowTarget_kg_s);
disp(study.summaryTable);
end
