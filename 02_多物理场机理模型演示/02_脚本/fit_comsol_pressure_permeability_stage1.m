function result = fit_comsol_pressure_permeability_stage1(opts)
%FIT_COMSOL_PRESSURE_PERMEABILITY_STAGE1
% Stage-1 COMSOL/LiveLink calibration for channel permeability and cooling UA.
%
% This script reads experiment metadata in MATLAB only. It does not attach
% CSV, tables, or temporary files to the COMSOL model.

if nargin < 1
    opts = struct();
end

opts = apply_defaults(opts);

addpath(opts.comsolMliPath);
ensure_mph_connection(opts.serverHost, opts.serverPort);

import com.comsol.model.util.*
model = get_live_model(opts.modelTag);
if opts.configureStage1Study
    configure_stage1_study(model, opts);
end
if ~isempty(opts.initialParams)
    set_stage1_params(model, opts.initialParams);
end

data = readtable(opts.dataCsv, 'VariableNamingRule', 'preserve');
validate_case_indices(opts.caseIdx, height(data));
print_case_set(data, opts.caseIdx);

baseParams = read_stage1_params(model);
fprintf('\nInitial stage-1 parameters:\n');
print_params(baseParams);

baseEval = evaluate_case_set(model, opts.caseIdx, opts);
fprintf('\nInitial objective = %.6g\n', baseEval.objective);
print_case_eval(baseEval);

if opts.evaluateOnly
    result = struct();
    result.mode = "evaluateOnly";
    result.caseIdx = opts.caseIdx;
    result.initialParams = baseParams;
    result.initialEval = baseEval;
    return
end

x0 = log([baseParams.K_CH_a_m2, baseParams.K_CH_c_m2, baseParams.UA_cool_stack_W_K]);
lb = log([opts.bounds.K_CH_a_m2(1), opts.bounds.K_CH_c_m2(1), opts.bounds.UA_cool_stack_W_K(1)]);
ub = log([opts.bounds.K_CH_a_m2(2), opts.bounds.K_CH_c_m2(2), opts.bounds.UA_cool_stack_W_K(2)]);

evalCounter = 0;
objective = @(x) bounded_objective(x);

optimOpts = optimset( ...
    'Display', 'iter', ...
    'MaxIter', opts.maxIter, ...
    'MaxFunEvals', opts.maxFunEvals, ...
    'TolX', opts.tolX, ...
    'TolFun', opts.tolFun);

[xBest, fBest, exitflag, output] = fminsearch(objective, x0, optimOpts);
xBest = min(max(xBest, lb), ub);
bestParams = params_from_log(xBest);
set_stage1_params(model, bestParams);
bestEval = evaluate_case_set(model, opts.caseIdx, opts);
if ~opts.applyBestToModel
    set_stage1_params(model, baseParams);
end

fprintf('\nBest stage-1 parameters:\n');
print_params(bestParams);
fprintf('Best objective = %.6g, exitflag = %d\n', fBest, exitflag);
print_case_eval(bestEval);
if opts.applyBestToModel
    fprintf('\nBest parameters were applied to the live COMSOL session.\n');
else
    fprintf('\nLive COMSOL session was restored to initial stage-1 parameters.\n');
end
fprintf('Model was not saved. Inspect the live COMSOL session before saving in GUI.\n');

result = struct();
result.mode = "fit";
result.caseIdx = opts.caseIdx;
result.initialParams = baseParams;
result.initialEval = baseEval;
result.bestParams = bestParams;
result.bestEval = bestEval;
result.exitflag = exitflag;
result.output = output;

    function f = bounded_objective(x)
        evalCounter = evalCounter + 1;
        if any(x < lb) || any(x > ub)
            f = opts.boundPenalty + sum((max(lb - x, 0) + max(x - ub, 0)).^2);
            fprintf('Eval %03d: out of bounds penalty %.6g\n', evalCounter, f);
            return
        end

        trialParams = params_from_log(x);
        set_stage1_params(model, trialParams);
        ev = evaluate_case_set(model, opts.caseIdx, opts);
        f = ev.objective;
        fprintf('Eval %03d: obj %.6g, K_a %.4g, K_c %.4g, UA %.4g\n', ...
            evalCounter, f, trialParams.K_CH_a_m2, trialParams.K_CH_c_m2, ...
            trialParams.UA_cool_stack_W_K);
    end
end

function opts = apply_defaults(opts)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));

defaults = struct();
defaults.serverHost = '127.0.0.1';
defaults.serverPort = 2036;
defaults.modelTag = '';
defaults.comsolMliPath = 'D:\COMSOL63\Multiphysics\mli';
defaults.dataCsv = fullfile(root, '01_自吸方案', '03_台架测试_10kW_简化版', ...
    '00_输入参数', '实验数据', 'combined_noegr_cegr_fit_points.csv');
defaults.caseIdx = [1, 5, 9, 12, 18];
defaults.evaluateOnly = true;
defaults.initialParams = [];
defaults.maxIter = 10;
defaults.maxFunEvals = 20;
defaults.tolX = 0.05;
defaults.tolFun = 0.05;
defaults.boundPenalty = 1e12;
defaults.failurePenalty = 1e9;
defaults.stopOnFailure = false;
defaults.maxConsecutiveFailures = 3;
defaults.includeCathodePressure = true;
defaults.includeAnodePressure = true;
defaults.includeTemperature = true;
defaults.configureStage1Study = true;
defaults.applyBestToModel = true;
defaults.studyTag = 'std1';
defaults.stage1InitStepTags = {'cdi', 'cdi2'};
defaults.stage1GasHeatStepTag = 'stat';
defaults.stage1FinalStepTag = 'stat2';
defaults.stage1StudyStepTag = 'stat2';
defaults.fcPhysicsTag = 'fc';
defaults.heatPhysicsTag = 'ge_heat';
defaults.cathodeFlowPhysicsTag = 'br';
defaults.anodeFlowPhysicsTag = 'br2';

defaults.bounds = struct();
defaults.bounds.K_CH_a_m2 = [1e-11, 1e-7];
defaults.bounds.K_CH_c_m2 = [1e-11, 1e-7];
defaults.bounds.UA_cool_stack_W_K = [20, 5000];

names = fieldnames(defaults);
for i = 1:numel(names)
    name = names{i};
    if ~isfield(opts, name) || isempty(opts.(name))
        opts.(name) = defaults.(name);
    end
end

if ~isfield(opts, 'bounds') || isempty(opts.bounds)
    opts.bounds = defaults.bounds;
else
    bnames = fieldnames(defaults.bounds);
    for i = 1:numel(bnames)
        name = bnames{i};
        if ~isfield(opts.bounds, name) || isempty(opts.bounds.(name))
            opts.bounds.(name) = defaults.bounds.(name);
        end
    end
end
end

function model = get_live_model(modelTag)
import com.comsol.model.util.*

if ~isempty(modelTag)
    model = ModelUtil.model(modelTag);
    return
end

tags = cell(ModelUtil.tags);
if isempty(tags)
    error('No model is loaded in the connected COMSOL Server session.');
end
if numel(tags) > 1
    error(['Multiple models are loaded in the connected COMSOL Server session (%s). ' ...
        'Set opts.modelTag explicitly before running the fitting script.'], ...
        strjoin(string(tags), ', '));
end
model = ModelUtil.model(tags{1});
fprintf('Using COMSOL model tag: %s\n', tags{1});
end

function ensure_mph_connection(serverHost, serverPort)
try
    mphstart(serverHost, serverPort);
catch ME
    if contains(string(ME.message), "Already connected to a server")
        fprintf('MATLAB LiveLink is already connected to a COMSOL server. Reusing current session.\n');
    else
        rethrow(ME);
    end
end
end

function validate_case_indices(caseIdx, nRows)
if any(caseIdx < 1) || any(caseIdx > nRows)
    error('caseIdx contains index outside experiment table range 1..%d.', nRows);
end
end

function print_case_set(data, caseIdx)
fprintf('\nStage-1 representative cases:\n');
fprintf('%6s  %-18s %8s %8s %8s %8s %8s %8s\n', ...
    'idx', 'case_id', 'I_A', 'egr', 'dp_c', 'dp_a', 'Tin', 'Tout');
for i = 1:numel(caseIdx)
    r = data(caseIdx(i), :);
    dpA = r.anode_in_p_kPa - r.anode_out_p_kPa;
    fprintf('%6d  %-18s %8.3g %8.3g %8.3g %8.3g %8.3g %8.3g\n', ...
        caseIdx(i), string(r.case_id), r.current_A, r.egr_fraction_model, ...
        r.cathode_dp_kPa, dpA, r.stack_in_T_C, r.stack_out_T_C);
end
end

function configure_stage1_study(model, opts)
study = model.study(opts.studyTag);
featureTags = cell(study.feature().tags());
expectedTags = [opts.stage1InitStepTags(:); {opts.stage1GasHeatStepTag; opts.stage1FinalStepTag}];
missingTags = setdiff(expectedTags, featureTags);
if ~isempty(missingTags)
    error('Stage-1 study step(s) not found in %s: %s', opts.studyTag, strjoin(missingTags, ', '));
end

for i = 1:numel(featureTags)
    tag = featureTags{i};
    feature = study.feature(featureTags{i});
    isInitStep = any(strcmp(tag, opts.stage1InitStepTags));
    isGasHeatStep = strcmp(tag, opts.stage1GasHeatStepTag);
    isFinalStep = strcmp(tag, opts.stage1FinalStepTag);
    isStage1Step = isInitStep || isGasHeatStep || isFinalStep;
    feature.active(isStage1Step);
    if isInitStep
        feature.set('activate', { ...
            opts.fcPhysicsTag, 'on', ...
            opts.heatPhysicsTag, 'off', ...
            opts.cathodeFlowPhysicsTag, 'off', ...
            opts.anodeFlowPhysicsTag, 'off', ...
            'frame:spatial1', 'on', ...
            'frame:material1', 'on'});
    elseif isGasHeatStep
        feature.set('activate', { ...
            opts.fcPhysicsTag, 'off', ...
            opts.heatPhysicsTag, 'on', ...
            opts.cathodeFlowPhysicsTag, 'on', ...
            opts.anodeFlowPhysicsTag, 'on', ...
            'frame:spatial1', 'on', ...
            'frame:material1', 'on'});
    elseif isFinalStep
        feature.set('activate', { ...
            opts.fcPhysicsTag, 'on', ...
            opts.heatPhysicsTag, 'on', ...
            opts.cathodeFlowPhysicsTag, 'on', ...
            opts.anodeFlowPhysicsTag, 'on', ...
            'frame:spatial1', 'on', ...
            'frame:material1', 'on'});
    end
end

fprintf('Configured stage-1 study: %s: init=%s fc-only, gas+heat=%s, final=%s all-on\n', ...
    opts.studyTag, strjoin(opts.stage1InitStepTags, ','), ...
    opts.stage1GasHeatStepTag, opts.stage1FinalStepTag);
end

function params = read_stage1_params(model)
params = struct();
params.K_CH_a_m2 = model.param.evaluate('K_CH_a');
params.K_CH_c_m2 = model.param.evaluate('K_CH_c');
params.UA_cool_stack_W_K = model.param.evaluate('UA_cool_stack');
end

function params = params_from_log(x)
params = struct();
params.K_CH_a_m2 = exp(x(1));
params.K_CH_c_m2 = exp(x(2));
params.UA_cool_stack_W_K = exp(x(3));
end

function set_stage1_params(model, params)
model.param.set('K_CH_a', sprintf('%.16g[m^2]', params.K_CH_a_m2));
model.param.set('K_CH_c', sprintf('%.16g[m^2]', params.K_CH_c_m2));
model.param.set('UA_cool_stack', sprintf('%.16g[W/K]', params.UA_cool_stack_W_K));
end

function print_params(params)
fprintf('  K_CH_a        = %.6g m^2\n', params.K_CH_a_m2);
fprintf('  K_CH_c        = %.6g m^2\n', params.K_CH_c_m2);
fprintf('  UA_cool_stack = %.6g W/K\n', params.UA_cool_stack_W_K);
end

function ev = evaluate_case_set(model, caseIdx, opts)
rows = repmat(empty_eval_row(), numel(caseIdx), 1);
objective = 0;
consecutiveFailures = 0;

for i = 1:numel(caseIdx)
        rows(i).caseIdx = caseIdx(i);
    try
        model.param.set('case_idx', num2str(caseIdx(i)));
        model.study(opts.studyTag).run;

        rows(i).dp_c_residual = mphglobal(model, 'dp_c_residual', 'unit', 'Pa');
        rows(i).dp_a_residual = mphglobal(model, 'dp_a_residual', 'unit', 'Pa');
        rows(i).T_residual = mphglobal(model, 'T_cool_out_residual', 'unit', 'K');
        rows(i).V_residual = mphglobal(model, 'V_cell_residual', 'unit', 'V');
        rows(i).dp_c_model = mphglobal(model, 'dp_c_model', 'unit', 'Pa');
        rows(i).dp_a_model = mphglobal(model, 'dp_a_model', 'unit', 'Pa');
        rows(i).T_cool_out_model = mphglobal(model, 'T_cool_out_model', 'unit', 'K');
        rows(i).ok = true;
        consecutiveFailures = 0;

        residuals = [];
        if opts.includeCathodePressure
            residuals(end + 1) = rows(i).dp_c_residual / 1000; %#ok<AGROW>
        end
        if opts.includeAnodePressure
            residuals(end + 1) = rows(i).dp_a_residual / 1000; %#ok<AGROW>
        end
        if opts.includeTemperature
            residuals(end + 1) = rows(i).T_residual; %#ok<AGROW>
        end
        rows(i).objective = sum(residuals .^ 2);
        objective = objective + rows(i).objective;
    catch ME
        rows(i).ok = false;
        rows(i).message = string(ME.message);
        rows(i).objective = opts.failurePenalty;
        objective = objective + opts.failurePenalty;
        fprintf('case_idx %d failed: %s\n', caseIdx(i), ME.message);
        consecutiveFailures = consecutiveFailures + 1;
        if opts.stopOnFailure || consecutiveFailures >= opts.maxConsecutiveFailures
            rethrow(ME);
        end
    end
end

ev = struct();
ev.objective = objective;
ev.rows = rows;
end

function row = empty_eval_row()
row = struct();
row.caseIdx = NaN;
row.ok = false;
row.message = "";
row.dp_c_residual = NaN;
row.dp_a_residual = NaN;
row.T_residual = NaN;
row.V_residual = NaN;
row.dp_c_model = NaN;
row.dp_a_model = NaN;
row.T_cool_out_model = NaN;
row.objective = NaN;
end

function print_case_eval(ev)
fprintf('%6s %4s %12s %12s %12s %12s\n', ...
    'idx', 'ok', 'dpc_res_Pa', 'dpa_res_Pa', 'T_res_K', 'obj');
for i = 1:numel(ev.rows)
    r = ev.rows(i);
    fprintf('%6d %4d %12.4g %12.4g %12.4g %12.4g\n', ...
        r.caseIdx, r.ok, r.dp_c_residual, r.dp_a_residual, ...
        r.T_residual, r.objective);
end
end
