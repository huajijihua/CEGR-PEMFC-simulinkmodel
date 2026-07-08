%% Route A external_case 10 kW bench sanity run
% This is not the Route A A7 main entry. A7 is now the platform-parameter
% isolation and default-matching check. This script remains only as an
% explicitly enabled external_case replay for legacy 10 kW bench data.
%
% The Route A default model must stay isolated from bench/company/product
% data. Enable this script only when intentionally replaying the external
% case, after confirming it will not be treated as platform-default evidence:
%   routeA_enable_external_case_bench_10kw = true;

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = [model '.slx'];
scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(fileparts(scriptDir)));
dataFile = fullfile(projectRoot, '01_自吸方案', '03_台架测试_10kW_简化版', ...
    '00_输入参数', '实验数据', 'combined_noegr_cegr_fit_points.csv');
oldDir = pwd;
routeA_a7_cleanup = onCleanup(@() restoreFolderAndModel(oldDir, model, modelFile));
cd(scriptDir);

if ~evalin('base', ['exist(''routeA_enable_external_case_bench_10kw'', ''var'') ', ...
        '&& routeA_enable_external_case_bench_10kw'])
    error('RouteA:ExternalCase:Disabled', ...
        ['10 kW bench replay is an external_case and is disabled by default. ', ...
        'It is not the A7 platform-default path. Set ', ...
        'routeA_enable_external_case_bench_10kw = true only for explicit ', ...
        'legacy bench sanity replay.']);
end

if bdIsLoaded(model) && strcmp(get_param(model, 'Dirty'), 'on')
    error('RouteA:A7:DirtyModel', ...
        ['Model %s has unsaved changes. Save or discard them before ', ...
        'running external_case bench sanity.'], model);
end
if ~isfile(dataFile)
    error('RouteA:ExternalCase:MissingData', 'Cannot find bench data file: %s', dataFile);
end

caseIds = ["cegr0608_001", "cegr0608_002", "cegr0608_013", "cegr0608_014"];
caseTable = readtable(dataFile, 'TextType', 'string');
rows = selectCases(caseTable, caseIds);

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
stackNumCells = getModelWorkspaceValue(model, 'stack_num_cells', 400);
results = repmat(emptyBenchResult(), numel(caseIds), 1);
for k = 1:numel(caseIds)
    results(k) = runBenchCase(model, modelFile, rows(k, :), stackNumCells);
end

assignin('base', 'routeA_a7_bench_sanity_results', results);
dispBenchResults(results);

function rows = selectCases(T, caseIds)
if ~ismember("case_id", string(T.Properties.VariableNames))
    error('RouteA:A7:BadDataTable', 'Data table has no case_id column.');
end
rows = T([], :);
for k = 1:numel(caseIds)
    match = T(string(T.case_id) == caseIds(k), :);
    if height(match) ~= 1
        error('RouteA:A7:BadCaseSelection', ...
            'Expected exactly one row for %s, found %d.', caseIds(k), height(match));
    end
    rows = [rows; match]; %#ok<AGROW>
end
end

function result = emptyBenchResult()
result = struct( ...
    'caseId', "", ...
    'isNoEgr', NaN, ...
    'currentA', NaN, ...
    'targetEgrRatio', NaN, ...
    'valveAreaFraction', NaN, ...
    'valveAreaWasCapped', false, ...
    'stackInFlowTargetKgS', NaN, ...
    'stackInPAbsMPa', NaN, ...
    'stackInTC', NaN, ...
    'stackInRH', NaN, ...
    'stackOutPBackMPa', NaN, ...
    'passed', false, ...
    'failureClass', "", ...
    'errorId', "", ...
    'errorMessage', "", ...
    'egrMdot', NaN, ...
    'exhaustMdot', NaN, ...
    'compInletMdot', NaN, ...
    'egrRatioCompIn', NaN, ...
    'egrSplitRatioOut', NaN, ...
    'ratioErrorVsTarget', NaN, ...
    'pOutlet', NaN, ...
    'pEgrValveUp', NaN, ...
    'pEgrValveDown', NaN, ...
    'pCompInlet', NaN, ...
    'yO2Outlet', NaN, ...
    'yH2OOutlet', NaN, ...
    'yO2CompInlet', NaN, ...
    'yH2OCompInlet', NaN, ...
    'pressureChainOk', false, ...
    'flowMappingStatus', "target_recorded_actual_from_model");
end

function result = runBenchCase(model, modelFile, row, stackNumCells)
result = emptyBenchResult();
result.caseId = string(row.case_id);
result.isNoEgr = double(row.is_no_egr);
result.currentA = requireFinite(row, "current_A");
result.targetEgrRatio = requireFinite(row, "egr_fraction_model");
result.stackInFlowTargetKgS = slpmAirToKgS(requireFinite(row, "stack_in_flow_meter_SLPM"));
result.stackInPAbsMPa = (requireFinite(row, "stack_in_p_kPa") + 101.325) / 1000;
result.stackInTC = requireFinite(row, "stack_in_T_C");
result.stackInRH = percentToFraction(requireFinite(row, "stack_in_RH_pct"));
result.stackOutPBackMPa = requireFinite(row, "stack_out_p_kPa") / 1000;
cellVoltage = requireFinite(row, "cell_voltage_V");
targetPowerW = result.currentA * cellVoltage * stackNumCells;
targetY = humidAirMoleFractions(result.stackInPAbsMPa * 1000, result.stackInTC, result.stackInRH);
areaChoice = egrTargetToValveAreaFraction(result.targetEgrRatio);
result.valveAreaFraction = areaChoice.areaFraction;
result.valveAreaWasCapped = areaChoice.wasCapped;

fprintf('\nRoute A external_case bench case: %s targetEGR=%.5g areaFrac=%.5g\n', ...
    result.caseId, result.targetEgrRatio, result.valveAreaFraction);
try
    resetModelFromDisk(model, modelFile);
    refreshModelWorkspace(model);
    markAuditSignals(model);

    simIn = Simulink.SimulationInput(model);
    simIn = simIn.setModelParameter( ...
        'StopTime', '30', ...
        'SignalLogging', 'on', ...
        'SignalLoggingName', 'logsout', ...
        'ReturnWorkspaceOutputs', 'on', ...
        'SimscapeLogType', 'none');
    simIn = simIn.setVariable('drive_cycle_time', [0; 5; 30], 'Workspace', model);
    simIn = simIn.setVariable('drive_cycle_power', [0; targetPowerW; targetPowerW], 'Workspace', model);
    simIn = simIn.setBlockParameter([model '/Oxygen Source/Air Intake'], ...
        'p0', sprintf('%.12g', result.stackInPAbsMPa));
    simIn = simIn.setBlockParameter([model '/Oxygen Source/Air Intake'], ...
        'T0', sprintf('%.12g', result.stackInTC));
    simIn = simIn.setBlockParameter([model '/Oxygen Source/Air Intake'], ...
        'y0', sprintf('[%.16g; %.16g; %.16g; %.16g]', targetY(1), targetY(2), targetY(3), targetY(4)));
    simIn = simIn.setBlockParameter([model '/Cathode Exhaust/Stack Pressure'], ...
        'Value', sprintf('%.12g', result.stackOutPBackMPa));
    simIn = simIn.setBlockParameter([model '/EGRValveRestriction'], ...
        'restriction_area', sprintf('%.16g*cegr_pipe_area', result.valveAreaFraction));

    simOut = sim(simIn);
    result.passed = true;
    result = collectBenchResult(simOut, result);
    result.pressureChainOk = checkPressureChain(result);
    result.ratioErrorVsTarget = result.egrRatioCompIn - result.targetEgrRatio;
    if ~result.pressureChainOk
        result.passed = false;
        result.failureClass = "pressure_chain_reversed";
    elseif ~isfinite(result.egrRatioCompIn) || ~isfinite(result.egrSplitRatioOut)
        result.passed = false;
        result.failureClass = "output_missing";
    end
    if result.passed
        fprintf('  PASS ratio=%.5g split=%.5g p_out=%.5g\n', ...
            result.egrRatioCompIn, result.egrSplitRatioOut, result.pOutlet);
    else
        fprintf('  FAIL %s ratio=%.5g split=%.5g\n', ...
            result.failureClass, result.egrRatioCompIn, result.egrSplitRatioOut);
    end
catch ME
    result.passed = false;
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
    result.failureClass = classifyFailure(ME, result);
    fprintf('  FAIL %s %s: %s\n', result.failureClass, result.errorId, result.errorMessage);
end
resetModelFromDisk(model, modelFile);
end

function choice = egrTargetToValveAreaFraction(targetRatio)
closedFrac = 1e-6;
maxFrac = 5e-3;
baseFrac = 5e-4;
baseRatio = 0.016789707; % A6 low-EGR smoke at 30 s
if targetRatio <= 0
    raw = closedFrac;
else
    raw = targetRatio / baseRatio * baseFrac;
end
choice.areaFraction = min(max(raw, closedFrac), maxFrac);
choice.wasCapped = abs(choice.areaFraction - raw) > 10 * eps(max(abs(raw), 1));
end

function result = collectBenchResult(simOut, result)
logsout = simOut.logsout;
result.egrMdot = scalarLastOrNaN(logsout, "routeA_cegr_mdot");
result.exhaustMdot = scalarLastOrNaN(logsout, "routeA_exhaust_mdot");
if ~isfinite(result.exhaustMdot)
    result.exhaustMdot = scalarLastFromSimOutOrNaN(simOut, "routeA_exhaust_mdot_ts");
end
result.compInletMdot = scalarLastOrNaN(logsout, "routeA_mdot_comp_inlet");
result.egrRatioCompIn = safeDivide(result.egrMdot, result.compInletMdot);
outletTotalMdot = max(result.egrMdot, 0) + max(result.exhaustMdot, 0);
result.egrSplitRatioOut = safeDivide(max(result.egrMdot, 0), outletTotalMdot);
result.pOutlet = scalarLastOrNaN(logsout, "routeA_p_outlet");
result.pEgrValveUp = scalarLastOrNaN(logsout, "routeA_p_egr_valve_up");
result.pEgrValveDown = scalarLastOrNaN(logsout, "routeA_p_egr_valve_down");
result.pCompInlet = scalarLastOrNaN(logsout, "routeA_p_comp_inlet");
outletYi = lastLoggedValueOrNaN(logsout, "routeA_yi_outlet");
inletYi = lastLoggedValueOrNaN(logsout, "routeA_yi_comp_inlet");
result.yO2Outlet = pickSpecies(outletYi, 2);
result.yH2OOutlet = pickSpecies(outletYi, 4);
result.yO2CompInlet = pickSpecies(inletYi, 2);
result.yH2OCompInlet = pickSpecies(inletYi, 4);
end

function markAuditSignals(model)
nameLineFromBlockOut([model '/Oxygen Source/PS-Simulink Converter'], ...
    'routeA_mdot_comp_inlet');
nameLineFromBlockOut([model '/Exhaust_mdot_Converter'], ...
    'routeA_exhaust_mdot');
end

function nameLineFromBlockOut(blockPath, signalName)
if getSimulinkBlockHandle(blockPath) == -1
    return;
end
ph = get_param(blockPath, 'PortHandles');
if isempty(ph.Outport)
    return;
end
lineHandle = get_param(ph.Outport(1), 'Line');
if lineHandle ~= -1
    set_param(lineHandle, 'Name', signalName);
end
end

function ok = checkPressureChain(result)
tol = 10;
ok = isfinite(result.pOutlet) && isfinite(result.pEgrValveUp) && ...
    isfinite(result.pEgrValveDown) && isfinite(result.pCompInlet) && ...
    result.pOutlet + tol >= result.pEgrValveUp && ...
    result.pEgrValveUp + tol >= result.pEgrValveDown && ...
    result.pEgrValveDown + tol >= result.pCompInlet;
end

function failureClass = classifyFailure(ME, result)
msg = lower(string(ME.message));
identifier = lower(string(ME.identifier));
if contains(msg, "initial") || contains(msg, "initial condition") || ...
        contains(msg, "ic") || contains(identifier, "ic_failure")
    failureClass = "initialization";
elseif result.valveAreaWasCapped
    failureClass = "valve_area_capped";
elseif contains(msg, "variable") || contains(msg, "parameter") || contains(msg, "block")
    failureClass = "boundary_mapping_gap";
else
    failureClass = "simulation_error";
end
end

function dispBenchResults(results)
fprintf('\nRoute A external_case bench sanity summary\n');
fprintf(['%-14s %-5s %-7s %-9s %-10s %-6s %11s %11s %11s ', ...
    '%11s %11s %11s %11s %10s %10s %-24s %s\n'], ...
    'case', 'noEGR', 'I_A', 'target', 'areaFrac', 'pass', ...
    'mdot_egr', 'mdot_exh', 'mdot_comp', 'ratio_in', 'split_out', ...
    'p_out', 'p_comp', 'yO2_out', 'yO2_in', 'failure', 'error');
for k = 1:numel(results)
    r = results(k);
    fprintf(['%-14s %-5.0f %-7.1f %-9.4g %-10.4g %-6s %11.4g %11.4g %11.4g ', ...
        '%11.4g %11.4g %11.4g %11.4g %10.4g %10.4g %-24s %s\n'], ...
        r.caseId, r.isNoEgr, r.currentA, r.targetEgrRatio, ...
        r.valveAreaFraction, string(r.passed), r.egrMdot, r.exhaustMdot, ...
        r.compInletMdot, r.egrRatioCompIn, r.egrSplitRatioOut, ...
        r.pOutlet, r.pCompInlet, r.yO2Outlet, r.yO2CompInlet, ...
        r.failureClass, r.errorId);
end
end

function y = humidAirMoleFractions(pAbsKPa, tC, rh)
pH2O = min(max(rh, 0) * satKPa(tC), 0.98 * pAbsKPa);
yH2O = min(max(pH2O / max(pAbsKPa, 1e-9), 0), 0.98);
yO2 = (1 - yH2O) * 0.21;
yN2 = max(1 - yH2O - yO2, 0);
y = [yN2; yO2; 0; yH2O];
end

function p = satKPa(T)
Tc = min(max(T, -40), 120);
p = 0.61121 * exp((18.678 - Tc / 234.5) * (Tc / (257.14 + Tc)));
end

function f = percentToFraction(v)
f = v;
if isfinite(f) && abs(f) > 1
    f = f / 100;
end
end

function v = requireFinite(row, name)
v = double(row.(name));
if ~isfinite(v)
    error('RouteA:A7:MissingRequiredValue', ...
        'Missing required numeric value "%s" for case %s.', name, string(row.case_id));
end
end

function m = slpmAirToKgS(slpm)
m = slpm * 1.293 / 60000;
end

function value = getModelWorkspaceValue(model, name, fallback)
value = fallback;
try
    modelWorkspace = get_param(model, 'ModelWorkspace');
    value = modelWorkspace.getVariable(name);
catch
end
end

function refreshModelWorkspace(model)
modelWorkspace = get_param(model, 'ModelWorkspace');
if strcmp(modelWorkspace.DataSource, 'MATLAB File')
    modelWorkspace.reload;
end
end

function value = scalarLastOrNaN(logsout, signalName)
value = lastLoggedValueOrNaN(logsout, signalName);
if isempty(value)
    value = NaN;
else
    value = value(1);
end
end

function value = scalarLastFromSimOutOrNaN(simOut, variableName)
value = NaN;
try
    signal = simOut.get(char(variableName));
catch
    return;
end
if isempty(signal)
    return;
end
try
    data = signal.Data;
    value = data(end);
catch
    try
        value = signal(end);
    catch
        value = NaN;
    end
end
end

function value = lastLoggedValueOrNaN(logsout, signalName)
value = NaN;
signalElement = findLoggedElement(logsout, signalName);
if isempty(signalElement)
    return;
end
signal = signalElement.Values;
data = signal.Data;
nTime = numel(signal.Time);
if isvector(data)
    value = data(end);
elseif size(data, 1) == nTime
    value = squeeze(data(end, :));
elseif size(data, ndims(data)) == nTime
    reshaped = reshape(data, [], nTime);
    value = reshaped(:, end).';
else
    value = squeeze(data(end, :));
end
value = value(:).';
end

function signalElement = findLoggedElement(logsout, signalName)
signalElement = [];
for idx = 1:logsout.numElements
    candidate = logsout.get(idx);
    if string(candidate.Name) == signalName
        signalElement = candidate;
        return;
    end
end
end

function value = pickSpecies(vectorValue, speciesIndex)
if numel(vectorValue) >= speciesIndex
    value = vectorValue(speciesIndex);
else
    value = NaN;
end
end

function out = safeDivide(num, den)
if isfinite(num) && isfinite(den) && abs(den) > eps
    out = num / den;
else
    out = NaN;
end
end

function txt = firstLine(txt)
parts = splitlines(txt);
txt = parts(1);
end

function resetModelFromDisk(model, modelFile)
if bdIsLoaded(model)
    close_system(model, 0);
end
load_system(modelFile);
end

function restoreFolderAndModel(oldDir, model, modelFile)
cd(oldDir);
if bdIsLoaded(model)
    close_system(model, 0);
end
if exist(modelFile, 'file')
    load_system(modelFile);
end
end
