function result = fit_comsol_pressure_permeability_stage1(userCfg)
%FIT_COMSOL_PRESSURE_PERMEABILITY_STAGE1 Fit channel permeabilities by pressure drop.
%
% Stage 1 calibration scope:
%   - MATLAB owns the optimizer.
%   - COMSOL solves the current 2D PEMFC/cEGR model.
%   - Heat equation is disabled in the pressure-only study path.
%   - Cell temperature is fixed to the experimental proxy T_cell_exp.
%   - Only K_CH_c and K_CH_a are estimated from cathode/anode pressure drops.
%
% The script updates the model in the connected COMSOL Server session only.
% It does not save the .mph file unless cfg.saveModel is explicitly true.

if nargin < 1
    userCfg = struct();
end
cfg = localDefaultConfig();
cfg = localMergeStruct(cfg, userCfg);

[model, modelTag] = localConnectOrLoadModel(cfg);
fprintf('COMSOL_MODEL_TAG=%s\n', modelTag);

allData = localLoadPressureData(cfg);
[fitData, validationData] = localSplitFitValidationData(allData, cfg);
fprintf('PRESSURE_FIT_CASES=%d\n', height(fitData));
fprintf('PRESSURE_VALIDATION_CASES=%d\n', height(validationData));

localConfigurePressureOnlyModel(model, cfg);
localDeactivateComsolOptimizationArtifacts(model, cfg);

if cfg.validateOnly
    best = localGetPermeability(model);
    residualBest = [];
    resnorm = NaN;
    exitflag = NaN;
    output = struct('message', 'Validation only; optimizer was not run.');
else
    x0 = log10([cfg.initial.K_CH_c_m2; cfg.initial.K_CH_a_m2]);
    lb = log10([cfg.bounds.K_CH_c_m2(1); cfg.bounds.K_CH_a_m2(1)]);
    ub = log10([cfg.bounds.K_CH_c_m2(2); cfg.bounds.K_CH_a_m2(2)]);

    objective = @(x) localPressureResidual(model, fitData, cfg, x);

    if exist('lsqnonlin', 'file') == 2
        opts = optimoptions('lsqnonlin', ...
            'Display', cfg.optimizerDisplay, ...
            'MaxIterations', cfg.maxIterations, ...
            'MaxFunctionEvaluations', cfg.maxFunctionEvaluations, ...
            'FiniteDifferenceType', 'central', ...
            'FunctionTolerance', cfg.functionTolerance, ...
            'StepTolerance', cfg.stepTolerance);
        [xBest, residualBest, resnorm, exitflag, output] = lsqnonlin(objective, x0, lb, ub, opts);
    else
        warning('Optimization Toolbox not found. Falling back to fminsearch with bounded transform.');
        z0 = localXToZ(x0, lb, ub);
        scalarObjective = @(z) sum(objective(localZToX(z, lb, ub)).^2);
        opts = optimset('Display', cfg.optimizerDisplay, ...
            'MaxIter', cfg.maxIterations, ...
            'MaxFunEvals', cfg.maxFunctionEvaluations, ...
            'TolFun', cfg.functionTolerance, ...
            'TolX', cfg.stepTolerance);
        [zBest, resnorm, exitflag, output] = fminsearch(scalarObjective, z0, opts);
        xBest = localZToX(zBest, lb, ub);
        residualBest = objective(xBest);
    end

    best.K_CH_c_m2 = 10.^xBest(1);
    best.K_CH_a_m2 = 10.^xBest(2);
    localSetPermeability(model, best.K_CH_c_m2, best.K_CH_a_m2);
end

prediction = localEvaluateCases(model, fitData, cfg);
metrics = localBuildMetrics(prediction);
if cfg.validateOnly
    validationPrediction = prediction;
    validationMetrics = metrics;
else
    validationPrediction = localEvaluateCases(model, validationData, cfg);
    validationMetrics = localBuildMetrics(validationPrediction);
end

fprintf('K_CH_c_BEST=%.9g m^2\n', best.K_CH_c_m2);
fprintf('K_CH_a_BEST=%.9g m^2\n', best.K_CH_a_m2);
fprintf('CATHODE_DP_RMSE=%.6g Pa\n', metrics.dp_c_rmse_Pa);
fprintf('ANODE_DP_RMSE=%.6g Pa\n', metrics.dp_a_rmse_Pa);
fprintf('VALIDATION_CATHODE_DP_RMSE=%.6g Pa\n', validationMetrics.dp_c_rmse_Pa);
fprintf('VALIDATION_ANODE_DP_RMSE=%.6g Pa\n', validationMetrics.dp_a_rmse_Pa);
fprintf('VALIDATION_CATHODE_DP_MAXABS=%.6g Pa\n', validationMetrics.dp_c_max_abs_Pa);
fprintf('VALIDATION_ANODE_DP_MAXABS=%.6g Pa\n', validationMetrics.dp_a_max_abs_Pa);

if cfg.writeOutputs
    resultFile = localWriteOutputs(cfg, prediction, metrics, best);
else
    resultFile = "";
end

if cfg.saveModel
    mphsave(model, cfg.modelFile);
end

result = struct();
result.modelTag = modelTag;
result.best = best;
result.residual = residualBest;
result.resnorm = resnorm;
result.exitflag = exitflag;
result.output = output;
result.prediction = prediction;
result.metrics = metrics;
result.validationPrediction = validationPrediction;
result.validationMetrics = validationMetrics;
result.resultFile = resultFile;
end

function cfg = localDefaultConfig()
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fileparts(scriptDir);
projectRoot = fileparts(modelDir);

cfg = struct();
cfg.projectRoot = projectRoot;
cfg.comsolHost = '127.0.0.1';
cfg.comsolPort = 2036;
cfg.comsolMliPath = 'D:\COMSOL63\Multiphysics\mli';
cfg.modelFile = fullfile(modelDir, '20260624-结构简化燃料电池-阴极尾气循环.mph');
cfg.modelNameContains = '20260624-结构简化燃料电池-阴极尾气循环';
cfg.modelLoadTag = 'pemfc_cegr_2d';

cfg.componentTag = 'comp1';
cfg.studyTag = 'std1';
cfg.pressureStepTag = 'stat2';
cfg.heatPhysicsTag = 'ge_heat';
cfg.fcPhysicsTag = 'fc';
cfg.cathodeFlowPhysicsTag = 'br';
cfg.anodeFlowPhysicsTag = 'br2';
cfg.globalVariableTag = 'var75';

cfg.dataFile = fullfile(projectRoot, '01_自吸方案', '03_台架测试_10kW_简化版', ...
    '00_输入参数', '实验数据', 'combined_noegr_cegr_fit_points.csv');
cfg.caseRows = [];       % Backward-compatible alias for fitCaseRows.
cfg.fitCaseRows = [];    % [] means all rows with valid cathode/anode pressure data.
cfg.validationCaseRows = []; % [] means all valid rows not used for fitting.
cfg.maxCases = [];       % Set a small integer for a smoke test.

cfg.modelExpressions = {'dp_c_model', 'dp_a_model'};
cfg.pressureScale = [1000; 1000]; % Pa. Residuals are roughly in kPa units.
cfg.failedResidual = 1e6;

cfg.initial.K_CH_c_m2 = 1e-9;
cfg.initial.K_CH_a_m2 = 1e-9;
cfg.bounds.K_CH_c_m2 = [1e-10, 1e-8];
cfg.bounds.K_CH_a_m2 = [1e-10, 1e-8];

cfg.maxIterations = 20;
cfg.maxFunctionEvaluations = 120;
cfg.functionTolerance = 1e-3;
cfg.stepTolerance = 1e-3;
cfg.optimizerDisplay = 'iter';

cfg.applyBestToModel = true;
cfg.writeOutputs = false;
cfg.outputDir = fullfile(modelDir, '04_标定结果');
cfg.saveModel = false;
cfg.deactivateComsolOptimization = true;
cfg.validateOnly = false;
cfg.progressEnabled = true;
end

function cfg = localMergeStruct(cfg, userCfg)
names = fieldnames(userCfg);
for i = 1:numel(names)
    name = names{i};
    if isstruct(userCfg.(name)) && isfield(cfg, name) && isstruct(cfg.(name))
        cfg.(name) = localMergeStruct(cfg.(name), userCfg.(name));
    else
        cfg.(name) = userCfg.(name);
    end
end
end

function [model, modelTag] = localConnectOrLoadModel(cfg)
if exist('mphstart', 'file') == 0 && isfolder(cfg.comsolMliPath)
    addpath(cfg.comsolMliPath);
end
assert(exist('mphstart', 'file') ~= 0, ...
    'COMSOL LiveLink mphstart was not found. Check cfg.comsolMliPath.');

import com.comsol.model.*
import com.comsol.model.util.*

try
    tags = localJavaStringArrayToCell(ModelUtil.tags());
catch
    mphstart(cfg.comsolHost, cfg.comsolPort);
    tags = localJavaStringArrayToCell(ModelUtil.tags());
end

model = [];
modelTag = '';
for i = 1:numel(tags)
    candidate = ModelUtil.model(tags{i});
    label = char(candidate.label());
    if contains(label, cfg.modelNameContains) || contains(tags{i}, cfg.modelNameContains)
        model = candidate;
        modelTag = tags{i};
        break;
    end
end

if isempty(model)
    assert(isfile(cfg.modelFile), 'COMSOL model file not found: %s', cfg.modelFile);
    model = mphload(cfg.modelFile, cfg.modelLoadTag);
    modelTag = cfg.modelLoadTag;
end
end

function cells = localJavaStringArrayToCell(values)
cells = cell(1, numel(values));
for i = 1:numel(values)
    cells{i} = char(values(i));
end
end

function data = localLoadPressureData(cfg)
opts = detectImportOptions(cfg.dataFile, 'TextType', 'string');
raw = readtable(cfg.dataFile, opts);
raw.case_idx = (1:height(raw)).';
raw.dp_c_exp_Pa = raw.cathode_dp_kPa * 1000;
raw.dp_a_exp_Pa = (raw.anode_in_p_kPa - raw.anode_out_p_kPa) * 1000;
raw.T_cell_ref_K = localBuildTemperatureProxy(raw);

mask = isfinite(raw.dp_c_exp_Pa) & isfinite(raw.dp_a_exp_Pa) & ...
    raw.dp_c_exp_Pa > 0 & raw.dp_a_exp_Pa > 0;
data = raw(mask, :);

if ~isempty(cfg.maxCases)
    data = data(1:min(height(data), cfg.maxCases), :);
end

assert(~isempty(data), 'No valid pressure calibration cases were found.');
end

function [fitData, validationData] = localSplitFitValidationData(allData, cfg)
fitRows = cfg.fitCaseRows;
if isempty(fitRows) && ~isempty(cfg.caseRows)
    fitRows = cfg.caseRows;
end

if isempty(fitRows)
    fitData = allData;
else
    fitData = allData(ismember(allData.case_idx, fitRows), :);
end
assert(~isempty(fitData), 'No pressure calibration cases matched fitCaseRows.');

if isempty(cfg.validationCaseRows)
    validationData = allData(~ismember(allData.case_idx, fitData.case_idx), :);
else
    validationData = allData(ismember(allData.case_idx, cfg.validationCaseRows), :);
end

if isempty(validationData)
    validationData = fitData;
end
end

function T = localBuildTemperatureProxy(raw)
T = nan(height(raw), 1);
hasCoolant = ismember('coolant_in_T_C', raw.Properties.VariableNames) && ...
    ismember('coolant_out_T_C', raw.Properties.VariableNames);
if hasCoolant
    valid = isfinite(raw.coolant_in_T_C) & isfinite(raw.coolant_out_T_C);
    T(valid) = 0.5 * (raw.coolant_in_T_C(valid) + raw.coolant_out_T_C(valid)) + 273.15;
end

hasStackGas = ismember('stack_in_T_C', raw.Properties.VariableNames) && ...
    ismember('stack_out_T_C', raw.Properties.VariableNames);
missing = ~isfinite(T);
if hasStackGas
    valid = missing & isfinite(raw.stack_in_T_C) & isfinite(raw.stack_out_T_C);
    T(valid) = 0.5 * (raw.stack_in_T_C(valid) + raw.stack_out_T_C(valid)) + 273.15;
    missing = ~isfinite(T);
    valid = missing & isfinite(raw.stack_in_T_C);
    T(valid) = raw.stack_in_T_C(valid) + 273.15;
end

missing = ~isfinite(T);
if ismember('anode_in_T_C', raw.Properties.VariableNames)
    valid = missing & isfinite(raw.anode_in_T_C);
    T(valid) = raw.anode_in_T_C(valid) + 273.15;
end

T(~isfinite(T)) = 333.15;
end

function localConfigurePressureOnlyModel(model, cfg)
comp = model.component(cfg.componentTag);

assert(localHasPhysics(comp, cfg.heatPhysicsTag), 'Missing physics: %s', cfg.heatPhysicsTag);
assert(localHasPhysics(comp, cfg.cathodeFlowPhysicsTag), 'Missing physics: %s', cfg.cathodeFlowPhysicsTag);
assert(localHasPhysics(comp, cfg.anodeFlowPhysicsTag), 'Missing physics: %s', cfg.anodeFlowPhysicsTag);

vars = comp.variable(cfg.globalVariableTag);
    vars.set('T_fc', 'T_cell_fit');
    vars.set('T_stack_0d', 'T_cell_fit');

comp.probe('mid_c_in_p').set('expr', 'br.pA');
comp.probe('mid_c_out_p').set('expr', 'br.pA');
comp.probe('mid_a_in_p').set('expr', 'br2.pA');
comp.probe('mid_a_out_p').set('expr', 'br2.pA');

study = model.study(cfg.studyTag);
featureTags = localJavaStringArrayToCell(study.feature().tags());
for i = 1:numel(featureTags)
    feature = study.feature(featureTags{i});
    if strcmp(featureTags{i}, cfg.pressureStepTag)
        feature.active(true);
        localSetActivation(feature, cfg, true);
    else
        feature.active(false);
    end
end
end

function localDeactivateComsolOptimizationArtifacts(model, cfg)
if ~cfg.deactivateComsolOptimization
    return;
end

try
    opt = model.opt();
    try
        opt.active(false);
    catch
    end

    try
        objectiveTags = localJavaStringArrayToCell(opt.objective().tags());
        for i = 1:numel(objectiveTags)
            objective = opt.objective(objectiveTags{i});
            try
                objective.active(false);
            catch
            end
        end
    catch
    end
catch
end
end

function tf = localHasPhysics(comp, tag)
tags = localJavaStringArrayToCell(comp.physics().tags());
tf = any(strcmp(tags, tag));
end

function localSetActivation(feature, cfg, pressureOnly)
if pressureOnly
    activation = { ...
        cfg.fcPhysicsTag, 'off', ...
        cfg.heatPhysicsTag, 'off', ...
        cfg.cathodeFlowPhysicsTag, 'on', ...
        cfg.anodeFlowPhysicsTag, 'on', ...
        'frame:spatial1', 'on', ...
        'frame:material1', 'on'};
else
    activation = { ...
        cfg.fcPhysicsTag, 'on', ...
        cfg.heatPhysicsTag, 'off', ...
        cfg.cathodeFlowPhysicsTag, 'on', ...
        cfg.anodeFlowPhysicsTag, 'on', ...
        'frame:spatial1', 'on', ...
        'frame:material1', 'on'};
end
feature.set('activate', activation);
end

function residual = localPressureResidual(model, data, cfg, x)
K = 10.^x(:);
try
    localSetPermeability(model, K(1), K(2));
    prediction = localEvaluateCases(model, data, cfg);
    residual = [ ...
        (prediction.dp_c_model_Pa - prediction.dp_c_exp_Pa) ./ cfg.pressureScale(1); ...
        (prediction.dp_a_model_Pa - prediction.dp_a_exp_Pa) ./ cfg.pressureScale(2)];
    bad = ~isfinite(residual);
    residual(bad) = cfg.failedResidual;
catch ME
    fprintf('COMSOL_SOLVE_FAILED: K_CH_c=%.4g, K_CH_a=%.4g, %s\n', K(1), K(2), ME.message);
    residual = cfg.failedResidual * ones(2 * height(data), 1);
end
end

function localSetPermeability(model, K_CH_c_m2, K_CH_a_m2)
model.param.set('K_CH_c', sprintf('%.15g[m^2]', K_CH_c_m2));
model.param.set('K_CH_a', sprintf('%.15g[m^2]', K_CH_a_m2));
end

function best = localGetPermeability(model)
best = struct();
Kc = double(mphglobal(model, 'K_CH_c'));
Ka = double(mphglobal(model, 'K_CH_a'));
best.K_CH_c_m2 = Kc(1);
best.K_CH_a_m2 = Ka(1);
end

function prediction = localEvaluateCases(model, data, cfg)
n = height(data);
prediction = table('Size', [n 7], ...
    'VariableTypes', {'double', 'string', 'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'case_idx', 'case_id', 'dp_c_exp_Pa', 'dp_a_exp_Pa', ...
    'dp_c_model_Pa', 'dp_a_model_Pa', 'T_cell_ref_K'});

for i = 1:n
    if cfg.progressEnabled
        fprintf('COMSOL_PRESSURE_CASE %d/%d case_idx=%d case_id=%s start\n', ...
            i, n, data.case_idx(i), data.case_id(i));
    end
    localApplyCaseInputs(model, data(i, :));
    model.study(cfg.studyTag).run();
    dpC = double(mphglobal(model, cfg.modelExpressions{1}));
    dpA = double(mphglobal(model, cfg.modelExpressions{2}));

    prediction.case_idx(i) = data.case_idx(i);
    prediction.case_id(i) = string(data.case_id(i));
    prediction.dp_c_exp_Pa(i) = data.dp_c_exp_Pa(i);
    prediction.dp_a_exp_Pa(i) = data.dp_a_exp_Pa(i);
    prediction.dp_c_model_Pa(i) = dpC(1);
    prediction.dp_a_model_Pa(i) = dpA(1);
    prediction.T_cell_ref_K(i) = data.T_cell_ref_K(i);
    if cfg.progressEnabled
        fprintf('COMSOL_PRESSURE_CASE %d/%d case_idx=%d done dpc_err=%.4g kPa dpa_err=%.4g kPa\n', ...
            i, n, data.case_idx(i), ...
            (prediction.dp_c_model_Pa(i) - prediction.dp_c_exp_Pa(i)) / 1000, ...
            (prediction.dp_a_model_Pa(i) - prediction.dp_a_exp_Pa(i)) / 1000);
    end
end

function localApplyCaseInputs(model, row)
atmPa = 101325;
model.param.set('case_idx', sprintf('%d', row.case_idx));

pCInPa = atmPa + 1000 * row.stack_in_p_kPa;
pCOutPa = atmPa + 1000 * row.stack_out_p_kPa;
pAInPa = atmPa + 1000 * row.anode_in_p_kPa;
pAOutPa = atmPa + 1000 * row.anode_out_p_kPa;

model.param.set('p_c_in', sprintf('%.15g[Pa]', pCInPa));
model.param.set('p_c_out', sprintf('%.15g[Pa]', pCOutPa));
model.param.set('p_a_in', sprintf('%.15g[Pa]', pAInPa));
model.param.set('p_a_out', sprintf('%.15g[Pa]', pAOutPa));

model.param.set('I_fc', sprintf('%.15g[A/m^2]', row.current_density_A_cm2 * 1e4));
model.param.set('W_c_stack_in', sprintf('rho_air_std*%.15g[L/min]', row.stack_in_flow_meter_SLPM));
model.param.set('W_c_in', 'W_c_stack_in/N_cell');
model.param.set('alpha_cyc', sprintf('%.15g', row.egr_fraction_model));
model.param.set('lam_a', sprintf('%.15g', row.anode_stoich));

model.param.set('RH_c_in', sprintf('%.15g', row.stack_in_RH_pct / 100));
model.param.set('RH_a_in', sprintf('%.15g', row.anode_in_RH_pct / 100));
model.param.set('T_c_in', sprintf('%.15g[degC]', row.stack_in_T_C));
model.param.set('T_a_in', sprintf('%.15g[degC]', row.anode_in_T_C));
model.param.set('T_cell_fit', sprintf('%.15g[K]', row.T_cell_ref_K));
end
end

function metrics = localBuildMetrics(prediction)
metrics = struct();
metrics.dp_c_rmse_Pa = localRmse(prediction.dp_c_model_Pa - prediction.dp_c_exp_Pa);
metrics.dp_a_rmse_Pa = localRmse(prediction.dp_a_model_Pa - prediction.dp_a_exp_Pa);
metrics.dp_c_max_abs_Pa = max(abs(prediction.dp_c_model_Pa - prediction.dp_c_exp_Pa), [], 'omitnan');
metrics.dp_a_max_abs_Pa = max(abs(prediction.dp_a_model_Pa - prediction.dp_a_exp_Pa), [], 'omitnan');
end

function value = localRmse(x)
value = sqrt(mean(x.^2, 'omitnan'));
end

function resultFile = localWriteOutputs(cfg, prediction, metrics, best)
if ~isfolder(cfg.outputDir)
    mkdir(cfg.outputDir);
end
stamp = char(datetime("now", "Format", "yyyyMMdd_HHmmss"));
resultFile = fullfile(cfg.outputDir, "comsol_pressure_stage1_" + stamp + ".mat");
save(resultFile, 'prediction', 'metrics', 'best', 'cfg');
end

function z = localXToZ(x, lb, ub)
y = (x - lb) ./ (ub - lb);
y = min(max(y, 1e-6), 1 - 1e-6);
z = log(y ./ (1 - y));
end

function x = localZToX(z, lb, ub)
y = 1 ./ (1 + exp(-z));
x = lb + y .* (ub - lb);
end
