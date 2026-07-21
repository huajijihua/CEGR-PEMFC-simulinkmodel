function study = run_routeA_stage1_constant_voltage_cegr_matrix(studyCfg)
% Route A Stage 1 nominal stack-terminal constant-voltage cEGR matrix.
%
% The Voltage Electrical Load branch regulates stack-terminal voltage by
% changing load current. Air mode 2 remains the established current-linked
% total compressor-flow path based on fresh-air-equivalent OER; actual
% cathode-inlet lambda is an audited result, not a controlled variable.

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
[cases, caseOutputs] = runVoltageCases(model, modelFile, modelDir, cfg);
cases = finalizeCases(cases);
[waterLedger, waterLedgerPassed] = runSharedWaterLedger( ...
    caseOutputs, cfg, model);

study = struct();
study.timestamp = string(datetime('now', 'Format', ...
    'yyyy-MM-dd HH:mm:ss'));
study.model = string(model);
study.parameterLayer = cfg.parameterLayer;
study.externalCaseEnabled = cfg.externalCaseEnabled;
study.loadInputType = "Voltage";
study.controlBoundary = "stack_terminal_voltage";
study.targetVoltage_V = cfg.targetVoltage_V;
study.initialVoltage_V = cfg.initialVoltage_V;
study.targetAirEquivalentOer = cfg.targetAirEquivalentOer;
study.airControlBasis = cfg.airControlBasis;
study.airControlTargetDefinition = ...
    ['targetAirEquivalentOer derives total compressor mass flow from ', ...
    'stack current using fresh-air oxygen content; lambda_ca_in remains ', ...
    'an audited result under cEGR'];
study.pi = struct('Kp_A_V', cfg.piKp_A_V, ...
    'Ki_A_V_s', cfg.piKi_A_V_s, ...
    'currentMin_A', cfg.currentMin_A, ...
    'currentMax_A', cfg.currentMax_A, ...
    'antiWindup', "internal_clamping");
study.cegrValveMaxArea_m2 = cfg.cegrValveMaxArea_m2;
study.initialState = cfg.initialStateMetadata;
study.initialStateKind = "formal_platform_default_voltage";
study.researchDuration_s = cfg.researchDuration_s;
study.tailLogicalWindow_s = cfg.tailLogicalWindow_s;
study.studyMaxStep_s = cfg.studyMaxStep_s;
study.targetRatios = cfg.targetRatios;
study.commandStepOffset_s = cfg.commandStepOffset_s;
study.cases = cases;
study.summaryTable = buildSummaryTable(cases);
study.allSimulationsCompleted = builtin('all', [cases.simCompleted]);
study.allVoltageControlPassed = builtin('all', [cases.voltageControlPassed]);
study.allGasClosuresPassed = builtin('all', [cases.gasClosurePassed]);
study.allCasesPassed = builtin('all', [cases.localPassed]);
study.waterLedgerRequired = cfg.runWaterLedger;
study.waterLedger = waterLedger;
study.waterLedgerPassed = waterLedgerPassed;
study.passed = study.allSimulationsCompleted && ...
    study.allVoltageControlPassed && study.allGasClosuresPassed && ...
    study.allCasesPassed && study.waterLedgerPassed;
assignin('base', 'routeA_stage1_constant_voltage_cegr_matrix', study);
assignin('base', 'routeA_stage1_constant_voltage_summary', study.summaryTable);
assignin('base', 'routeA_stage1_constant_voltage_water_ledger', ...
    study.waterLedger);
displayStudy(study);

clear caseOutputs cleanup;
end

function cfg = studyConfig(model, modelDir, studyCfg)
studyCfg = normalizeStudyConfig(studyCfg);
initialStateFile = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state.mat');
loaded = load(initialStateFile, 'routeA_initial_metadata_voltage');
if ~isfield(loaded, 'routeA_initial_metadata_voltage')
    error('RouteA:ConstantVoltageInitialState', ...
        'The formal Voltage platform_default initial-state metadata is unavailable.');
end
metadata = loaded.routeA_initial_metadata_voltage;
requiredMetadata = {'snapshotTimeS', 'targetVoltage_V', ...
    'cegrTopologyEnabled', 'cegrValveModeId', 'egrReferenceKind', ...
    'loadInputType', 'cegrValveMaxArea_m2'};
if ~builtin('all', isfield(metadata, requiredMetadata)) || ...
        ~metadata.cegrTopologyEnabled || metadata.cegrValveModeId ~= 1 || ...
        string(metadata.egrReferenceKind) ~= "mode1_zero_target_near_zero" || ...
        string(metadata.loadInputType) ~= "Voltage"
    error('RouteA:ConstantVoltageInitialStateMetadata', ...
        'The formal Voltage state is not the required mode-1 zero-cEGR state.');
end

mw = get_param(model, 'ModelWorkspace');
if strcmp(mw.DataSource, 'MATLAB File')
    mw.reload;
end
parameterLayer = string(mw.getVariable('routeA_parameter_layer'));
externalCaseEnabled = logical(mw.getVariable('routeA_external_case_enabled'));
if parameterLayer ~= "platform_default" || externalCaseEnabled
    error('RouteA:ConstantVoltageParameterBoundary', ...
        ['The constant-voltage matrix requires platform_default with ', ...
        'external_case disabled.']);
end

stackCells = mw.getVariable('stack_num_cells');
stackAreaCm2 = mw.getVariable('stack_area');
stackIL_A_cm2 = mw.getVariable('stack_iL');
maxValveArea = mw.getVariable('cegr_valve_max_area');
rpmTable = mw.getVariable('comp_rpm_TLU');
defaultKp = mw.getVariable('routeA_voltage_pi_Kp');
defaultKi = mw.getVariable('routeA_voltage_pi_Ki');
currentMin = mw.getVariable('routeA_voltage_current_min_A');
currentMax = mw.getVariable('routeA_voltage_current_max_A');
validateattributes(stackCells, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(stackAreaCm2, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(stackIL_A_cm2, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(maxValveArea, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(rpmTable, {'numeric'}, {'vector', 'nonempty', 'finite'});
validateattributes(defaultKp, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(defaultKi, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(currentMin, {'numeric'}, {'scalar', 'nonnegative', 'finite'});
validateattributes(currentMax, {'numeric'}, {'scalar', 'positive', 'finite'});
modelCurrentMax = stackAreaCm2 * stackIL_A_cm2;
if abs(currentMin) > 1e-12 || ...
        abs(currentMax - modelCurrentMax) > 1e-12 * max(1, modelCurrentMax)
    error('RouteA:ConstantVoltageCurrentLimit', ...
        ['Voltage current limits must be 0 and stack_iL * stack_area ', ...
        '(%.16g A).'], modelCurrentMax);
end

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
cfg.initialVoltage_V = metadata.targetVoltage_V;
cfg.targetVoltage_V = studyCfg.targetVoltage_V;
cfg.targetAirEquivalentOer = studyCfg.targetAirEquivalentOer;
cfg.researchDuration_s = studyCfg.researchDuration_s;
cfg.tailLogicalWindow_s = studyCfg.tailLogicalWindow_s;
cfg.studyMaxStep_s = studyCfg.studyMaxStep_s;
cfg.targetRatios = studyCfg.targetRatios;
cfg.runWaterLedger = studyCfg.runWaterLedger;
cfg.piKp_A_V = chooseGain(studyCfg.piKp_A_V, defaultKp, 'piKp_A_V');
cfg.piKi_A_V_s = chooseGain(studyCfg.piKi_A_V_s, defaultKi, 'piKi_A_V_s');
cfg.currentMin_A = currentMin;
cfg.currentMax_A = currentMax;
cfg.commandStepOffset_s = 0.5;
cfg.voltageTrackingRelativeTolerance = 0.005;
cfg.voltageTailSpanFraction = 0.005;
cfg.currentSaturationTailFractionLimit = 0.01;
cfg.currentSaturationTolerance_A = 1e-6 * max(1, currentMax - currentMin);
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
cfg.airControlBasis = ...
    "target_total_compressor_mdot_from_fresh_air_equivalent_oer";
cfg = assignRuntimeWindows(cfg, metadata);
end

function value = chooseGain(override, defaultValue, name)
if isnan(override)
    value = defaultValue;
else
    value = override;
end
validateattributes(value, {'numeric'}, {'scalar', 'positive', 'finite'}, ...
    mfilename, name);
end

function studyCfg = normalizeStudyConfig(studyCfg)
if ~isstruct(studyCfg) || numel(studyCfg) ~= 1
    error('RouteA:ConstantVoltageStudyConfig', ...
        'The study configuration must be a scalar struct.');
end
defaults = struct( ...
    'targetVoltage_V', 394.9, ...
    'targetAirEquivalentOer', 3, ...
    'researchDuration_s', 600, ...
    'tailLogicalWindow_s', [540, 600], ...
    'studyMaxStep_s', 5, ...
    'targetRatios', [0, 0.10, 0.30], ...
    'piKp_A_V', NaN, ...
    'piKi_A_V_s', NaN, ...
    'runWaterLedger', true);
names = fieldnames(studyCfg);
for idx = 1:numel(names)
    name = names{idx};
    if ~isfield(defaults, name)
        error('RouteA:ConstantVoltageStudyConfigField', ...
            'Unsupported study configuration field: %s.', name);
    end
    defaults.(name) = studyCfg.(name);
end
validateattributes(defaults.targetVoltage_V, {'numeric'}, ...
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
    error('RouteA:ConstantVoltageTailWindow', ...
        'The logical tail window must be increasing and within the study duration.');
end
validateattributes(defaults.studyMaxStep_s, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(defaults.targetRatios, {'numeric'}, ...
    {'vector', 'nonempty', 'nonnegative', 'finite'});
defaults.targetRatios = defaults.targetRatios(:).';
if numel(unique(defaults.targetRatios)) ~= numel(defaults.targetRatios)
    error('RouteA:ConstantVoltageTargetRatios', ...
        'targetRatios must not contain duplicate targets.');
end
validateattributes(defaults.piKp_A_V, {'numeric'}, {'scalar', 'real'});
validateattributes(defaults.piKi_A_V_s, {'numeric'}, {'scalar', 'real'});
if ~isnan(defaults.piKp_A_V)
    validateattributes(defaults.piKp_A_V, {'numeric'}, ...
        {'scalar', 'positive', 'finite'});
end
if ~isnan(defaults.piKi_A_V_s)
    validateattributes(defaults.piKi_A_V_s, {'numeric'}, ...
        {'scalar', 'positive', 'finite'});
end
validateattributes(defaults.runWaterLedger, {'logical', 'numeric'}, ...
    {'scalar'});
defaults.runWaterLedger = logical(defaults.runWaterLedger);
studyCfg = defaults;
end

function cfg = assignRuntimeWindows(cfg, metadata)
cfg.researchStartTime_s = metadata.snapshotTimeS;
cfg.commandStepTime_s = cfg.researchStartTime_s + cfg.commandStepOffset_s;
cfg.modelStopTime_s = cfg.researchStartTime_s + cfg.researchDuration_s;
cfg.tailWindow_s = cfg.researchStartTime_s + cfg.tailLogicalWindow_s;
cfg.voltageTrackingWindow_s = cfg.tailWindow_s;
cfg.lambdaTransitionDiagnosticWindow_s = [ ...
    cfg.commandStepTime_s + 0.5, cfg.tailWindow_s(1)];
end

function [cases, caseOutputs] = runVoltageCases(model, modelFile, modelDir, cfg)
count = numel(cfg.targetRatios);
cases = repmat(emptyCaseResult(), count, 1);
caseOutputs = repmat(emptyCaseOutput(), count, 1);
for idx = 1:count
    [cases(idx), caseOutputs(idx)] = runCase( ...
        model, modelFile, modelDir, cfg, cfg.targetRatios(idx));
end
end

function [result, caseOutput] = runCase( ...
    model, modelFile, modelDir, cfg, targetRatio)
result = initializeCase(cfg, targetRatio);
caseOutput = emptyCaseOutput();
caseOutput.caseId = result.caseId;
caseOutput.targetRatio = targetRatio;
caseOutput.modeId = 1;
try
    resetModelFromDisk(model, modelFile);
    refreshModelWorkspace(model);
    in = Simulink.SimulationInput(model);
    [in, initialStateMetadata] = routeA_attach_platform_default_initial_state( ...
        in, model, modelDir, cfg.initialStateFile, "Voltage");
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
        cfg.commandStepTime_s; cfg.modelStopTime_s], 'Workspace', model);
    in = in.setVariable('drive_cycle_voltage', ...
        [cfg.initialVoltage_V; cfg.initialVoltage_V; ...
        cfg.targetVoltage_V; cfg.targetVoltage_V], 'Workspace', model);
    in = in.setVariable('routeA_voltage_pi_Kp', cfg.piKp_A_V, ...
        'Workspace', model);
    in = in.setVariable('routeA_voltage_pi_Ki', cfg.piKi_A_V_s, ...
        'Workspace', model);
    in = in.setVariable('routeA_voltage_current_min_A', cfg.currentMin_A, ...
        'Workspace', model);
    in = in.setVariable('routeA_voltage_current_max_A', cfg.currentMax_A, ...
        'Workspace', model);
    in = in.setVariable('routeA_air_control_mode_id', 2, 'Workspace', model);
    in = in.setVariable('routeA_target_oer', cfg.targetAirEquivalentOer, ...
        'Workspace', model);
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
    if exist('out', 'var') && isa(out, 'Simulink.SimulationOutput')
        caseOutput.out = out;
    end
    result.errorId = string(ME.identifier);
    result.errorMessage = string(ME.message);
    if ~isempty(ME.stack)
        result.errorLocation = string(ME.stack(1).name) + ":" + ...
            string(ME.stack(1).line);
    end
end
end

function result = initializeCase(cfg, targetRatio)
result = emptyCaseResult();
result.caseId = "voltage_cegr_" + ...
    replace(sprintf('%.2f', targetRatio), '.', 'p');
result.targetRatio = targetRatio;
result.targetVoltage_V = cfg.targetVoltage_V;
result.initialVoltage_V = cfg.initialVoltage_V;
result.targetAirEquivalentOer = cfg.targetAirEquivalentOer;
result.piKp_A_V = cfg.piKp_A_V;
result.piKi_A_V_s = cfg.piKi_A_V_s;
result.currentMin_A = cfg.currentMin_A;
result.currentMax_A = cfg.currentMax_A;
result.cegrValveMaxArea_m2 = cfg.cegrValveMaxArea_m2;
result.researchStartModelTime_s = cfg.researchStartTime_s;
result.researchDuration_s = cfg.researchDuration_s;
result.tailLogicalWindow_s = cfg.tailLogicalWindow_s;
result.tailModelWindow_s = cfg.tailWindow_s;
result.voltageTrackingWindow_s = cfg.voltageTrackingWindow_s;
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
simlog = out.get(get_param(model, 'SimscapeLogName'));
mea = routeA_simscape_log_mea(simlog);
stackCurrent = timeseries(mea.Icell.series.values('A'), ...
    mea.Icell.series.time);
stackVoltage = timeseries(mea.Vstack.series.values('V'), ...
    mea.Vstack.series.time);
stackPower = timeseries(mea.power_elec.series.values('kW'), ...
    mea.power_elec.series.time);
stackTemperature = timeseries(mea.T_stack.series.values('degC'), ...
    mea.T_stack.series.time);
voltageReference = loggedTimeseries(logsout, 'routeA_voltage_ref_V');
voltageError = loggedTimeseries(logsout, 'routeA_voltage_control_error_V');
rawCurrent = loggedTimeseries(logsout, 'routeA_voltage_current_cmd_raw_A');
limitedCurrent = loggedTimeseries(logsout, ...
    'routeA_voltage_current_cmd_limited_A');
appliedCurrent = loggedTimeseries(logsout, 'routeA_voltage_current_cmd_A');
saturationStatus = loggedTimeseries(logsout, ...
    'routeA_voltage_current_saturated');
speciesMdot = out.get('routeA_mdot_species_ca_in_ts');
[~, inletTotal, inletMassFraction] = inletSpeciesMetrics(speciesMdot);
inletTotalMdot = timeseries(inletTotal, speciesMdot.Time);
inletO2MassFraction = timeseries(inletMassFraction(:, 2), speciesMdot.Time);
lambdaCaIn = inletOxygenStoich(speciesMdot, stackCurrent, cfg.stackCells);
egrAtCompressor = interpolate(egrMdot.Time, egrMdot.Data, compMdot.Time);
freshAirApprox = timeseries(compMdot.Data - egrAtCompressor, compMdot.Time);
airMdotSetAtCompressor = interpolate(airMdotSet.Time, airMdotSet.Data, ...
    compMdot.Time);
compressorMdotTrackingError = timeseries(compMdot.Data - ...
    airMdotSetAtCompressor, compMdot.Time);
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
tail.voltageReference_V = windowStats(voltageReference, cfg.tailWindow_s);
tail.voltageControlError_V = windowStats(voltageError, cfg.tailWindow_s);
tail.voltageCurrentRaw_A = windowStats(rawCurrent, cfg.tailWindow_s);
tail.voltageCurrentLimited_A = windowStats(limitedCurrent, cfg.tailWindow_s);
tail.voltageCurrentApplied_A = windowStats(appliedCurrent, cfg.tailWindow_s);
tail.voltageSaturationStatus = heldWindowStats( ...
    saturationStatus, cfg.tailWindow_s);
tail.compressorMdot_kg_s = windowStats(compMdot, cfg.tailWindow_s);
tail.compressorMdotSet_kg_s = heldWindowStats( ...
    airMdotSet, cfg.tailWindow_s);
tail.compressorMdotTrackingError_kg_s = windowStats( ...
    compressorMdotTrackingError, cfg.tailWindow_s);
tail.airControlError_kg_s = windowStats(airControlError, cfg.tailWindow_s);
tail.compressorPressure_Pa = windowStats(compP, cfg.tailWindow_s);
tail.compressorTemperature_K = windowStats(compT, cfg.tailWindow_s);
tail.compressorCommand = windowStats(compCmd, cfg.tailWindow_s);
tail.compressorRpm = windowStats(compRpm, cfg.tailWindow_s);
tail.egrValveDeltaP_MPa = windowStats(pressureDeltaMPa, cfg.tailWindow_s);
tail.egrValveAreaFraction = windowStats(areaFraction, cfg.tailWindow_s);
tail.lambdaCaIn = windowStats(lambdaCaIn, cfg.tailWindow_s);
tail.inletO2MassFraction = windowStats(inletO2MassFraction, cfg.tailWindow_s);

voltageData = windowData(stackVoltage, cfg.voltageTrackingWindow_s, ...
    'stack voltage');
referenceData = windowData(voltageReference, cfg.voltageTrackingWindow_s, ...
    'voltage reference');
lambdaTransition = windowData(lambdaCaIn, ...
    cfg.lambdaTransitionDiagnosticWindow_s, 'lambda_ca_in');
compressorMdotTrackingData = windowData(compressorMdotTrackingError, ...
    cfg.tailWindow_s, 'compressor mass-flow tracking error');
gasClosure = routeA_stage1_cathode_gas_closure_from_outputs(out, model, cfg);
purge = purgeStats(out, model, cfg);
[boundFraction, statusFraction] = saturationFractions( ...
    limitedCurrent, saturationStatus, cfg);

result.simCompleted = true;
result.tail = tail;
result.actualRatio = tail.egrRatio.mean;
result.targetError = result.actualRatio - result.targetRatio;
result.targetTolerance = targetTolerance(result.targetRatio);
result.voltageReferenceTailMeanError_V = ...
    abs(mean(referenceData) - result.targetVoltage_V);
result.voltageTailMeanRelativeError = ...
    abs(mean(voltageData) - result.targetVoltage_V) / ...
    max(abs(result.targetVoltage_V), 1e-6);
result.voltageTailSpanTolerance_V = ...
    cfg.voltageTailSpanFraction * result.targetVoltage_V;
result.compressorMdotTrackingMaxAbsError_kg_s = ...
    max(abs(compressorMdotTrackingData));
result.compressorMdotTrackingTolerance_kg_s = max( ...
    cfg.airMdotTrackingRelativeTolerance * ...
    abs(tail.compressorMdotSet_kg_s.mean), ...
    cfg.airMdotTrackingAbsoluteTolerance_kg_s);
result.lambdaTailMin = tail.lambdaCaIn.minimum;
result.lambdaTransitionMin = finiteMinimum(lambdaTransition);
result.currentSaturationTailFraction = boundFraction;
result.saturationStatusTailFraction = statusFraction;
result.finiteTail = tailFinite(tail);
result.referenceProfilePassed = result.voltageReferenceTailMeanError_V <= ...
    1e-9 * max(1, abs(result.targetVoltage_V));
result.voltageTrackingPassed = result.voltageTailMeanRelativeError <= ...
    cfg.voltageTrackingRelativeTolerance;
result.voltageTailSpanPassed = tail.stackVoltage_V.span <= ...
    result.voltageTailSpanTolerance_V;
result.currentSaturationPassed = result.currentSaturationTailFraction <= ...
    cfg.currentSaturationTailFractionLimit;
result.voltageControlPassed = result.referenceProfilePassed && ...
    result.voltageTrackingPassed && result.voltageTailSpanPassed && ...
    result.currentSaturationPassed;
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
result.localPassed = result.finiteTail && result.voltageControlPassed && ...
    result.trackingPassed && result.compressorMdotTrackingPassed && ...
    result.lambdaPassed && result.pressureDirectionPassed && ...
    result.areaPassed && result.compressorRpmLookupPassed && ...
    result.gasClosurePassed && result.tailPurgeFree;
result.failureCategory = failureCategory(result);
end

function [boundFraction, statusFraction] = saturationFractions( ...
    limitedCurrent, saturationStatus, cfg)
limited = normalizeScalarData(limitedCurrent.Time, limitedCurrent.Data, ...
    'limited voltage current command');
atBound = abs(limited - cfg.currentMin_A) <= ...
    cfg.currentSaturationTolerance_A | ...
    abs(limited - cfg.currentMax_A) <= cfg.currentSaturationTolerance_A;
boundFraction = booleanTimeFraction(limitedCurrent.Time, atBound, ...
    cfg.tailWindow_s);
status = normalizeScalarData(saturationStatus.Time, saturationStatus.Data, ...
    'voltage saturation status') ~= 0;
statusFraction = booleanTimeFraction(saturationStatus.Time, status, ...
    cfg.tailWindow_s);
end

function fraction = booleanTimeFraction(time, logicalData, window)
time = time(:);
logicalData = logical(logicalData(:));
if numel(time) ~= numel(logicalData)
    error('RouteA:ConstantVoltageSaturationShape', ...
        'Saturation time and data lengths do not match.');
end
sampleTime = unique([window(1); time(time > window(1) & time < window(2)); ...
    window(2)]);
if numel(sampleTime) < 2
    error('RouteA:ConstantVoltageSaturationWindow', ...
        'The saturation window does not contain two time samples.');
end
if isscalar(time)
    sampled = repmat(double(logicalData), numel(sampleTime), 1);
else
    sampled = interp1(time, double(logicalData), sampleTime, 'previous', ...
        'extrap');
end
fraction = trapz(sampleTime, sampled) / (window(2) - window(1));
end

function cases = finalizeCases(cases)
zeroIndex = find(abs([cases.targetRatio]) < eps, 1);
if isempty(zeroIndex) || ~cases(zeroIndex).simCompleted
    return;
end
reference = cases(zeroIndex);
for idx = 1:numel(cases)
    if cases(idx).simCompleted
        cases(idx).deltaToZeroTarget = deltaToReference(cases(idx), reference);
    end
end
end

function delta = deltaToReference(item, reference)
delta = struct();
names = {'stackVoltage_V', 'stackCurrent_A', 'stackPower_kW', ...
    'compressorMdot_kg_s', 'freshAirApprox_kg_s', 'egrMdot_kg_s', ...
    'inletO2MassFraction', 'lambdaCaIn', 'compressorCommand', ...
    'compressorRpm', 'egrValveDeltaP_MPa', 'egrValveAreaFraction'};
for idx = 1:numel(names)
    name = names{idx};
    delta.(name) = item.tail.(name).mean - reference.tail.(name).mean;
end
end

function [ledger, passed] = runSharedWaterLedger(caseOutputs, cfg, model)
if ~cfg.runWaterLedger
    ledger = struct('attempted', false, 'auditPassed', true, ...
        'skipReason', "disabled_for_gain_tuning", 'cases', struct([]));
    passed = true;
    return;
end
requiredRatios = [0, 0.30];
selected = repmat(emptyCaseOutput(), numel(requiredRatios), 1);
for idx = 1:numel(requiredRatios)
    match = find(abs([caseOutputs.targetRatio] - requiredRatios(idx)) < eps);
    if numel(match) ~= 1 || ...
            ~isa(caseOutputs(match).out, 'Simulink.SimulationOutput')
        ledger = struct( ...
            'attempted', false, ...
            'auditPassed', false, ...
            'skipReason', "missing_constant_voltage_shared_output", ...
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
waterCfg.loadTrackingMode = "constant_voltage";
waterCfg.voltageTrackingWindow_s = cfg.voltageTrackingWindow_s;
waterCfg.targetVoltage_V = cfg.targetVoltage_V;
waterCfg.voltageTrackingRelativeTolerance = ...
    cfg.voltageTrackingRelativeTolerance;
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

function summary = buildSummaryTable(cases)
count = numel(cases);
caseId = strings(count, 1);
targetRatio = NaN(count, 1);
actualRatio = NaN(count, 1);
vRef = NaN(count, 1);
vStack = NaN(count, 1);
voltageMeanRelativeError = NaN(count, 1);
voltageSpan = NaN(count, 1);
current = NaN(count, 1);
power = NaN(count, 1);
compressorMdot = NaN(count, 1);
freshAir = NaN(count, 1);
egrMdot = NaN(count, 1);
inletO2 = NaN(count, 1);
lambda = NaN(count, 1);
valveDeltaP = NaN(count, 1);
valveArea = NaN(count, 1);
compressorCmd = NaN(count, 1);
compressorRpm = NaN(count, 1);
saturatedFraction = NaN(count, 1);
voltageControlPassed = false(count, 1);
gasClosurePassed = false(count, 1);
passed = false(count, 1);
for idx = 1:count
    item = cases(idx);
    caseId(idx) = item.caseId;
    targetRatio(idx) = item.targetRatio;
    actualRatio(idx) = item.actualRatio;
    vRef(idx) = tailMean(item, 'voltageReference_V');
    vStack(idx) = tailMean(item, 'stackVoltage_V');
    voltageMeanRelativeError(idx) = item.voltageTailMeanRelativeError;
    voltageSpan(idx) = tailSpan(item, 'stackVoltage_V');
    current(idx) = tailMean(item, 'stackCurrent_A');
    power(idx) = tailMean(item, 'stackPower_kW');
    compressorMdot(idx) = tailMean(item, 'compressorMdot_kg_s');
    freshAir(idx) = tailMean(item, 'freshAirApprox_kg_s');
    egrMdot(idx) = tailMean(item, 'egrMdot_kg_s');
    inletO2(idx) = tailMean(item, 'inletO2MassFraction');
    lambda(idx) = tailMinimum(item, 'lambdaCaIn');
    valveDeltaP(idx) = tailMean(item, 'egrValveDeltaP_MPa');
    valveArea(idx) = tailMean(item, 'egrValveAreaFraction');
    compressorCmd(idx) = tailMean(item, 'compressorCommand');
    compressorRpm(idx) = tailMean(item, 'compressorRpm');
    saturatedFraction(idx) = item.currentSaturationTailFraction;
    voltageControlPassed(idx) = item.voltageControlPassed;
    gasClosurePassed(idx) = item.gasClosurePassed;
    passed(idx) = item.localPassed;
end
summary = table(caseId, targetRatio, actualRatio, vRef, vStack, ...
    voltageMeanRelativeError, voltageSpan, current, power, compressorMdot, ...
    freshAir, egrMdot, inletO2, lambda, valveDeltaP, valveArea, ...
    compressorCmd, compressorRpm, saturatedFraction, voltageControlPassed, ...
    gasClosurePassed, passed);
end

function value = tailMean(item, name)
value = NaN;
if isfield(item, 'tail') && isfield(item.tail, name)
    value = item.tail.(name).mean;
end
end

function value = tailMinimum(item, name)
value = NaN;
if isfield(item, 'tail') && isfield(item.tail, name)
    value = item.tail.(name).minimum;
end
end

function value = tailSpan(item, name)
value = Inf;
if isfield(item, 'tail') && isfield(item.tail, name)
    value = item.tail.(name).span;
end
end

function result = emptyCaseResult()
result = struct( ...
    'caseId', "", ...
    'targetRatio', NaN, ...
    'actualRatio', NaN, ...
    'targetError', NaN, ...
    'targetTolerance', NaN, ...
    'targetVoltage_V', NaN, ...
    'initialVoltage_V', NaN, ...
    'targetAirEquivalentOer', NaN, ...
    'piKp_A_V', NaN, ...
    'piKi_A_V_s', NaN, ...
    'currentMin_A', NaN, ...
    'currentMax_A', NaN, ...
    'cegrValveMaxArea_m2', NaN, ...
    'initialState', struct(), ...
    'researchStartModelTime_s', NaN, ...
    'researchDuration_s', NaN, ...
    'tailLogicalWindow_s', NaN(1, 2), ...
    'tailModelWindow_s', NaN(1, 2), ...
    'voltageTrackingWindow_s', NaN(1, 2), ...
    'simCompleted', false, ...
    'errorId', "", ...
    'errorMessage', "", ...
    'errorLocation', "", ...
    'tail', struct(), ...
    'deltaToZeroTarget', struct(), ...
    'voltageReferenceTailMeanError_V', Inf, ...
    'voltageTailMeanRelativeError', Inf, ...
    'voltageTailSpanTolerance_V', NaN, ...
    'compressorMdotTrackingMaxAbsError_kg_s', Inf, ...
    'compressorMdotTrackingTolerance_kg_s', NaN, ...
    'lambdaTailMin', NaN, ...
    'lambdaTransitionMin', NaN, ...
    'currentSaturationTailFraction', Inf, ...
    'saturationStatusTailFraction', Inf, ...
    'finiteTail', false, ...
    'referenceProfilePassed', false, ...
    'voltageTrackingPassed', false, ...
    'voltageTailSpanPassed', false, ...
    'currentSaturationPassed', false, ...
    'voltageControlPassed', false, ...
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
    'localPassed', false, ...
    'failureCategory', "");
end

function output = emptyCaseOutput()
output = struct( ...
    'caseId', "", ...
    'targetRatio', NaN, ...
    'out', [], ...
    'initialState', struct(), ...
    'modeId', NaN);
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
    error('RouteA:ConstantVoltageInletSpecies', ...
        'Cathode inlet species total is nonpositive or nonfinite.');
end
massFraction = species ./ total;
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

function stats = heldWindowStats(signal, window)
mask = signal.Time >= window(1) & signal.Time < window(2);
if any(mask)
    stats = windowStats(signal, window);
    return;
end
data = normalizeScalarData(signal.Time, signal.Data, 'held signal');
if isempty(data) || any(~isfinite(data))
    error('RouteA:ConstantVoltageHeldSignal', ...
        'The held diagnostic signal is unavailable or nonfinite.');
end
if isscalar(signal.Time)
    value = data(1);
else
    value = interp1(signal.Time(:), data, mean(window), 'previous', ...
        'extrap');
end
stats = struct('mean', value, 'std', 0, 'span', 0, ...
    'minimum', value, 'maximum', value, 'sampleCount', 1, ...
    'nonfiniteCount', 0);
end

function values = windowData(signal, window, signalName)
mask = signal.Time >= window(1) & signal.Time < window(2);
values = signal.Data(mask);
values = values(:);
if isempty(values)
    error('RouteA:ConstantVoltageEmptyWindow', ...
        'No samples were found for %s.', signalName);
end
end

function signal = loggedTimeseries(logsout, name)
element = logsout.get(name);
if isempty(element) || isempty(element.Values)
    error('RouteA:ConstantVoltageMissingSignal', ...
        'The required logged signal is unavailable: %s.', name);
end
signal = element.Values;
end

function signal = magnitudeTimeseries(signal)
signal = timeseries(abs(signal.Data), signal.Time);
end

function values = interpolate(time, data, targetTime)
if isscalar(time)
    values = repmat(data(1), numel(targetTime), 1);
else
    values = interp1(time, data(:), targetTime, 'linear', 'extrap');
end
values = values(:);
if any(~isfinite(values))
    error('RouteA:ConstantVoltageInterpolation', ...
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
    error('RouteA:ConstantVoltageSeriesShape', ...
        'Unexpected signal shape for %s.', signalName);
end
end

function data = normalizeScalarData(time, data, label)
data = squeeze(data);
if isscalar(time)
    data = data(:);
elseif isvector(data)
    data = data(:);
elseif size(data, 1) ~= numel(time) && size(data, 2) == numel(time)
    data = data.';
end
if ~isvector(data) || numel(data) ~= numel(time)
    error('RouteA:ConstantVoltageScalarShape', ...
        'Unexpected scalar signal shape for %s.', label);
end
data = data(:);
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

function tolerance = targetTolerance(targetRatio)
if targetRatio == 0
    tolerance = 1e-4;
else
    tolerance = max(0.002, 0.10 * targetRatio);
end
end

function category = failureCategory(result)
reasons = strings(1, 0);
if ~result.simCompleted
    reasons(end + 1) = "simulation";
end
if ~result.voltageControlPassed
    reasons(end + 1) = "voltage_control";
end
if ~result.trackingPassed
    reasons(end + 1) = "cegr_tracking";
end
if ~result.compressorMdotTrackingPassed
    reasons(end + 1) = "compressor_flow";
end
if ~result.lambdaPassed
    reasons(end + 1) = "oxygen_supply";
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
fprintf('\nRoute A Stage 1 constant-voltage cEGR matrix\n');
fprintf(['  V_ref=%.6g V | source V=%.6g V | OER=%.6g | ', ...
    'duration=%.0f s | tail=[%.0f,%.0f) s | MaxStep=%.6g s\n'], ...
    study.targetVoltage_V, study.initialVoltage_V, ...
    study.targetAirEquivalentOer, study.researchDuration_s, ...
    study.tailLogicalWindow_s(1), study.tailLogicalWindow_s(2), ...
    study.studyMaxStep_s);
fprintf('  PI Kp=%.6g A/V Ki=%.6g A/(V*s) | limits=[%.6g, %.6g] A\n', ...
    study.pi.Kp_A_V, study.pi.Ki_A_V_s, study.pi.currentMin_A, ...
    study.pi.currentMax_A);
fprintf('  cases=%d voltage=%d gas=%d water=%d overall=%d\n', ...
    numel(study.cases), study.allVoltageControlPassed, ...
    study.allGasClosuresPassed, study.waterLedgerPassed, study.passed);
disp(study.summaryTable);
end
