% Route A single-model full-operating-case cEGR study.
%
% The root cEGR_Mode_Selector is a Simscape Variant Subsystem. It is
% selected before each independent simulation at update-diagram time:
%   routeA_cegr_enabled = true  -> physical cEGR connection
%   routeA_cegr_enabled = false -> Infinite Flow Resistance (FC) isolation
% No-cEGR cases therefore do not depend on a numerically near-zero valve.

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', 'RouteA_GasMixture_Derived');
model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
addpath(modelDir);
cd(modelDir);
cleanup = onCleanup(@() restoreModelAndFolder(model, modelFile, oldDir));

cfg = studyConfig(model, modelFile);
cases = buildStudyCases(cfg);
results = repmat(emptyResult(), numel(cases), 1);
nominalGatePassed = true;

fprintf('\nRoute A single-model full-operating-case cEGR study\n');
fprintf('  model=%s, stopTime=%.0f s, cases=%d\n', model, cfg.stopTime, numel(cases));
for idx = 1:numel(cases)
    c = cases(idx);
    if c.requiresNominalGate && ~nominalGatePassed
        results(idx) = skippedResult(c, "nominal_gate_failed");
    else
        results(idx) = runCase(c, cfg, model, modelFile);
        if c.isNominalGate
            nominalGatePassed = casePassed(results(idx));
        end
    end
    displayCase(results(idx));
end

study = struct();
study.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
study.model = string(model);
study.stopTime_s = cfg.stopTime;
study.matrix = cases;
study.results = results;
study.nominalGatePassed = nominalGatePassed;
study.monotonicEgrChecks = checkEgrOrdering(results);
study.summaryTable = resultTable(results);
study.passed = builtin('all', [results.passed]) && ...
    builtin('all', [study.monotonicEgrChecks.passed]);
assignin('base', 'routeA_fullcase_study', study);
assignin('base', 'routeA_fullcase_summary', study.summaryTable);

fprintf('\nRoute A full-case study summary\n');
disp(study.summaryTable);
fprintf('  nominalGatePassed=%d orderingPassed=%d overallPassed=%d\n', ...
    study.nominalGatePassed, ...
    builtin('all', [study.monotonicEgrChecks.passed]), study.passed);

function cfg = studyConfig(model, modelFile)
resetModelFromDisk(model, modelFile);
mw = get_param(model, 'ModelWorkspace');
if strcmp(mw.DataSource, 'MATLAB File')
    mw.reload;
end
cfg = struct();
cfg.model = string(model);
cfg.stopTime = 120;
cfg.tailSeconds = 10;
cfg.stackAreaCm2 = getWorkspaceValue(mw, 'stack_area', NaN);
cfg.stackCells = getWorkspaceValue(mw, 'stack_num_cells', NaN);
cfg.mO2 = 0.0319988; % [kg/mol]
cfg.faraday = 96485.33212; % [C/mol]
cfg.powerTailSpanLimitKW = 1e-3;
cfg.powerTrackingTolerance = 0.05;
cfg.egrSteadySpanLimit = 1e-3;
cfg.noCegrTolerance = 1e-8;
cfg.lambdaLowerBound = 1;
if ~isfinite(cfg.stackAreaCm2) || ~isfinite(cfg.stackCells)
    error('RouteA:MissingStackParameters', ...
        'Model workspace must define stack_area and stack_num_cells.');
end
end

function cases = buildStudyCases(cfg)
loads = [ ...
    loadDef("low", 0.2, 0.78, 4); ...
    loadDef("nominal", 0.7, 0.65, 3); ...
    loadDef("high", 1.2, 0.58, 2)];
topologies = [ ...
    topologyDef("noCEGR", false, 0); ...
    topologyDef("withCEGR_010", true, 0.10); ...
    topologyDef("withCEGR_030", true, 0.30)];

% Nominal cases are the physical/numerical gate before low/high expansion.
order = [2 1 3];
cases = repmat(caseDef(), 9, 1);
idx = 0;
for iLoad = order
    for iTopology = 1:numel(topologies)
        idx = idx + 1;
        cases(idx) = makeCase(loads(iLoad), topologies(iTopology), cfg);
    end
end
end

function load = loadDef(id, currentDensity, referenceVoltage, targetOer)
load = struct('id', string(id), 'currentDensity_A_cm2', currentDensity, ...
    'referenceVoltage_V', referenceVoltage, 'targetOer', targetOer);
end

function topology = topologyDef(id, cegrEnabled, targetEgr)
topology = struct('id', string(id), 'cegrEnabled', logical(cegrEnabled), ...
    'targetEgrRatio', targetEgr);
end

function c = caseDef()
c = struct('caseId', "", 'loadId', "", 'topologyId', "", ...
    'cegrEnabled', false, 'targetEgrRatio', NaN, 'targetOer', NaN, ...
    'targetPowerKW', NaN, 'isNominalGate', false, ...
    'requiresNominalGate', false);
end

function c = makeCase(load, topology, cfg)
c = caseDef();
c.caseId = load.id + "_" + topology.id;
c.loadId = load.id;
c.topologyId = topology.id;
c.cegrEnabled = topology.cegrEnabled;
c.targetEgrRatio = topology.targetEgrRatio;
c.targetOer = load.targetOer;
c.targetPowerKW = load.currentDensity_A_cm2 * cfg.stackAreaCm2 * ...
    cfg.stackCells * load.referenceVoltage_V / 1000;
c.isNominalGate = load.id == "nominal";
c.requiresNominalGate = load.id ~= "nominal";
end

function r = emptyResult()
r = struct('caseId', "", 'loadId', "", 'topologyId', "", ...
    'cegrEnabled', false, 'targetPowerKW', NaN, 'targetOer', NaN, ...
    'targetEgrRatio', NaN, 'simCompleted', false, 'skipped', false, ...
    'finiteOk', false, 'powerSteady', false, 'powerTracking', false, ...
    'egrValid', false, 'lambdaValid', false, 'passed', false, ...
    'errorId', "", 'errorMessage', "", 'actualPowerKW', NaN, ...
    'powerTailSpanKW', NaN, 'egrRatio', NaN, 'egrTailSpan', NaN, ...
    'exhaustMdotKgS', NaN, 'lambdaCaInTailMin', NaN, ...
    'lambdaCaInTailMax', NaN, 'stopTime_s', NaN);
end

function r = skippedResult(c, reason)
r = populateCase(emptyResult(), c);
r.skipped = true;
r.errorId = string(reason);
r.errorMessage = "Case was not run because the nominal gate did not pass.";
end

function r = runCase(c, cfg, model, modelFile)
r = populateCase(emptyResult(), c);
r.stopTime_s = cfg.stopTime;
try
    if ~c.cegrEnabled && c.targetEgrRatio ~= 0
        error('RouteA:NoCEGRNonzeroTarget', ...
            'No-cEGR topology requires routeA_target_egr_ratio_comp_in = 0.');
    end

    resetModelFromDisk(model, modelFile);
    mw = get_param(model, 'ModelWorkspace');
    if strcmp(mw.DataSource, 'MATLAB File')
        mw.reload;
    end
    mw.assignin('routeA_cegr_enabled', c.cegrEnabled);
    set_param(model, 'SimulationCommand', 'update');

    in = simulationInput(c, cfg, model);
    out = sim(in);
    r.simCompleted = true;
    r = collectKpis(r, out, cfg, model);
    r = evaluateCase(r, cfg);
catch ME
    r.errorId = string(ME.identifier);
    r.errorMessage = firstLine(string(ME.message));
end
resetModelFromDisk(model, modelFile);
end

function in = simulationInput(c, cfg, model)
in = Simulink.SimulationInput(model);
in = in.setModelParameter('StopTime', sprintf('%.16g', cfg.stopTime), ...
    'ReturnWorkspaceOutputs', 'on', 'SimscapeLogType', 'all');
in = in.setVariable('drive_cycle_time', [0; 0.5; cfg.stopTime], 'Workspace', model);
in = in.setVariable('drive_cycle_power', ...
    [0; c.targetPowerKW; c.targetPowerKW], 'Workspace', model);
in = in.setVariable('routeA_air_control_mode_id', 2, 'Workspace', model);
in = in.setVariable('routeA_target_oer', c.targetOer, 'Workspace', model);
in = in.setVariable('routeA_egr_control_mode_id', 1, 'Workspace', model);
in = in.setVariable('routeA_target_egr_ratio_comp_in', ...
    c.targetEgrRatio, 'Workspace', model);
end

function r = collectKpis(r, out, cfg, model)
simlog = out.get(get_param(model, 'SimscapeLogName'));
mea = routeA_simscape_log_mea(simlog);
power = mea.power_elec.series.values('kW');
egr = out.get('routeA_egr_ratio_comp_in_ts');
exhaust = out.get('routeA_exhaust_mdot_ts');
speciesMdot = out.get('routeA_mdot_species_ca_in_ts');
stackCurrent = out.get('routeA_stack_current_A_ts');
lambda = inletOxygenStoich(speciesMdot, stackCurrent, cfg);

r.actualPowerKW = power(end);
r.powerTailSpanKW = tailSpan(power);
r.egrRatio = egr.Data(end);
r.egrTailSpan = timeTailSpan(egr, cfg.tailSeconds);
r.exhaustMdotKgS = exhaust.Data(end);
r.lambdaCaInTailMin = tailMinimum(lambda, cfg.tailSeconds);
r.lambdaCaInTailMax = tailMaximum(lambda, cfg.tailSeconds);
r.finiteOk = builtin('all', isfinite([r.actualPowerKW, r.powerTailSpanKW, ...
    r.egrRatio, r.egrTailSpan, r.exhaustMdotKgS, ...
    r.lambdaCaInTailMin, r.lambdaCaInTailMax]));
end

function lambda = inletOxygenStoich(speciesMdot, stackCurrent, cfg)
species = squeeze(speciesMdot.Data).';
if size(species, 1) ~= numel(speciesMdot.Time)
    error('RouteA:SpeciesMdotShape', 'Unexpected cathode inlet species-flow data shape.');
end
if size(species, 2) < 2
    error('RouteA:SpeciesOrder', 'Cathode inlet measurement does not expose the O2 component.');
end
current = stackCurrent.Data(:);
currentAtSpeciesTime = interp1(stackCurrent.Time, current, speciesMdot.Time, ...
    'linear', 'extrap');
o2SupplyMolS = abs(species(:, 2)) / cfg.mO2;
o2ConsumptionMolS = cfg.stackCells * abs(currentAtSpeciesTime) / (4 * cfg.faraday);
lambda = timeseries(o2SupplyMolS ./ o2ConsumptionMolS, speciesMdot.Time);
end

function r = evaluateCase(r, cfg)
r.powerSteady = r.powerTailSpanKW <= cfg.powerTailSpanLimitKW;
r.powerTracking = abs(r.actualPowerKW - r.targetPowerKW) <= ...
    cfg.powerTrackingTolerance * max(r.targetPowerKW, 1e-6);
r.lambdaValid = r.lambdaCaInTailMin > cfg.lambdaLowerBound;
if r.cegrEnabled
    egrTolerance = max(0.01, 0.10 * r.targetEgrRatio);
    r.egrValid = abs(r.egrRatio - r.targetEgrRatio) <= egrTolerance && ...
        r.egrTailSpan <= cfg.egrSteadySpanLimit;
else
    r.egrValid = abs(r.egrRatio) <= cfg.noCegrTolerance && ...
        r.egrTailSpan <= cfg.noCegrTolerance;
end
r.passed = r.simCompleted && r.finiteOk && r.powerSteady && ...
    r.powerTracking && r.egrValid && r.lambdaValid;
end

function r = populateCase(r, c)
r.caseId = c.caseId;
r.loadId = c.loadId;
r.topologyId = c.topologyId;
r.cegrEnabled = c.cegrEnabled;
r.targetPowerKW = c.targetPowerKW;
r.targetOer = c.targetOer;
r.targetEgrRatio = c.targetEgrRatio;
end

function value = tailSpan(values)
values = values(:);
count = max(3, ceil(0.1 * numel(values)));
tail = values(end-count+1:end);
value = max(tail) - min(tail);
end

function value = timeTailSpan(signal, seconds)
tail = signal.Time >= signal.Time(end) - seconds;
data = signal.Data(tail);
value = max(data) - min(data);
end

function value = tailMinimum(signal, seconds)
tail = signal.Time >= signal.Time(end) - seconds;
value = min(signal.Data(tail));
end

function value = tailMaximum(signal, seconds)
tail = signal.Time >= signal.Time(end) - seconds;
value = max(signal.Data(tail));
end

function checks = checkEgrOrdering(results)
loads = unique([results.loadId]);
checks = repmat(struct('loadId', "", 'available', false, 'passed', false, ...
    'message', ""), numel(loads), 1);
for idx = 1:numel(loads)
    loadId = loads(idx);
    subset = results([results.loadId] == loadId);
    checks(idx).loadId = loadId;
    if numel(subset) ~= 3 || any([subset.skipped]) || ...
            ~builtin('all', [subset.passed])
        checks(idx).message = "All three passing topology cases are required.";
        continue;
    end
    noEgr = subset([subset.targetEgrRatio] == 0).egrRatio;
    egr010 = subset(abs([subset.targetEgrRatio] - 0.10) < eps).egrRatio;
    egr030 = subset(abs([subset.targetEgrRatio] - 0.30) < eps).egrRatio;
    checks(idx).available = true;
    checks(idx).passed = noEgr < egr010 && egr010 < egr030;
    checks(idx).message = "Expected noCEGR < 0.10 < 0.30 actual cEGR ratio.";
end
end

function t = resultTable(results)
t = struct2table(results);
t = t(:, {'caseId', 'cegrEnabled', 'targetPowerKW', 'targetOer', ...
    'targetEgrRatio', 'simCompleted', 'skipped', 'actualPowerKW', ...
    'powerTailSpanKW', 'egrRatio', 'egrTailSpan', 'exhaustMdotKgS', ...
    'lambdaCaInTailMin', 'finiteOk', 'powerSteady', 'powerTracking', ...
    'egrValid', 'lambdaValid', 'passed', 'errorId'});
end

function tf = casePassed(r)
tf = r.passed;
end

function txt = firstLine(txt)
parts = splitlines(txt);
txt = parts(1);
end

function value = getWorkspaceValue(modelWorkspace, name, fallback)
value = fallback;
try
    value = modelWorkspace.getVariable(name);
catch
end
end

function resetModelFromDisk(model, modelFile)
if bdIsLoaded(model)
    close_system(model, 0);
end
load_system(modelFile);
end

function restoreModelAndFolder(model, modelFile, oldDir)
if bdIsLoaded(model)
    close_system(model, 0);
end
load_system(modelFile);
cd(oldDir);
end

function displayCase(r)
if r.skipped
    fprintf('  %-24s SKIPPED (%s)\n', r.caseId, r.errorId);
    return;
end
fprintf(['  %-24s pass=%d P=%.6g kW egr=%.6g lambdaMin=%.6g ', ...
    'exhaust=%.6g kg/s\n'], r.caseId, r.passed, r.actualPowerKW, ...
    r.egrRatio, r.lambdaCaInTailMin, r.exhaustMdotKgS);
if strlength(r.errorId) > 0
    fprintf('    %s: %s\n', r.errorId, r.errorMessage);
end
end
