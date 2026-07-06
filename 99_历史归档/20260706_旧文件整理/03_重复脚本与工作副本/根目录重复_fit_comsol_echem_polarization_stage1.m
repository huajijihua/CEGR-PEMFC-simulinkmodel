function result = fit_comsol_echem_polarization_stage1(opts)
%FIT_COMSOL_ECHEM_POLARIZATION_STAGE1
% Minimal representative-case COMSOL/LiveLink calibration for steady
% polarization. The COMSOL model stays the source of truth; MATLAB only
% drives case_idx, reads voltage, and fits the selected electrochemical
% parameters. This script runs the specified study tag directly; the
% current default is research study std1.

if nargin < 1
    opts = struct();
end

opts = apply_defaults(opts);

addpath(opts.comsolMliPath);
ensure_mph_connection(opts.serverHost, opts.serverPort);

import com.comsol.model.util.*
model = get_live_model(opts.modelTag, opts.modelFile);
audit_study_configuration(model, opts);

data = readtable(opts.dataCsv, 'VariableNamingRule', 'preserve');
validate_case_indices(opts.fitCaseIdx, height(data));
validate_case_indices(opts.validationCaseIdx, height(data));

fitData = attach_case_index(data, opts.fitCaseIdx);
validationData = attach_case_index(data, opts.validationCaseIdx);
print_case_sets(fitData, validationData);

baseParams = read_echem_params(model);
if ~isempty(opts.initialParams)
    initParams = merge_full_echem_params(baseParams, opts.initialParams);
    set_echem_params(model, initParams, opts);
    baseParams = read_echem_params(model);
end
opts = finalize_param_config(opts, baseParams);
spec = param_spec(opts);
runTimer = tic;
fprintf('\n=== COMSOL polarization fit run ===\n');
fprintf('Study tag: %s\n', opts.studyTag);
fprintf('Evaluate only: %d\n', opts.evaluateOnly);
fprintf('Model file: %s\n', opts.modelFile);
fprintf('Fit cases: %s\n', mat2str(opts.fitCaseIdx));
fprintf('Validation cases: %s\n', mat2str(opts.validationCaseIdx));
fprintf('Active parameters: %s\n', strjoin(string({spec.name}), ', '));
fprintf('Voltage expressions: %s\n', strjoin(string(opts.voltageExpressions), ', '));
fprintf('\nInitial electrochemical parameters (fit + fixed):\n');
print_params(baseParams, spec);

if ~isempty(opts.preflightCaseIdx)
    run_preflight_case(model, data, opts);
    if opts.preflightOnly
        result = struct();
        result.mode = "preflightOnly";
        result.preflightCaseIdx = opts.preflightCaseIdx;
        result.initialParams = baseParams;
        return
    end
end

baseFit = evaluate_case_set(model, fitData, opts);
fprintf('\nInitial fit-set objective = %.6g\n', baseFit.objective);
print_case_eval(baseFit, "fit");

baseVal = evaluate_case_set(model, validationData, opts);
fprintf('\nInitial validation-set objective = %.6g\n', baseVal.objective);
print_case_eval(baseVal, "validation");

result = struct();
result.mode = "evaluateOnly";
result.fitCaseIdx = opts.fitCaseIdx;
result.validationCaseIdx = opts.validationCaseIdx;
result.initialParams = baseParams;
result.initialFit = baseFit;
result.initialValidation = baseVal;

restoreParams = baseParams;
cleanup = []; %#ok<NASGU>
if opts.restoreParamsOnExit
    cleanup = struct('token', onCleanup(@() restore_live_model()));
    touch_cleanup(cleanup);
end

if opts.evaluateOnly
    return
end

x0 = physical_to_unit(pack_params(baseParams, spec), spec);
lb = lower_search_bounds(spec);
ub = upper_search_bounds(spec);

evalCounter = 0;
evalElapsedTotal_s = 0;
objective = @(z) bounded_objective(z);
optimOpts = optimset( ...
    'Display', 'iter', ...
    'MaxIter', opts.maxIter, ...
    'MaxFunEvals', opts.maxFunEvals, ...
    'TolX', opts.tolX, ...
    'TolFun', opts.tolFun, ...
    'OutputFcn', @report_optim_state);

[zBest, fBest, exitflag, output] = fminsearch(objective, x0, optimOpts);
zBest = min(max(zBest, lb), ub);
[bestParams, ~] = params_from_unit(zBest, spec, baseParams, opts.failurePenalty);
set_echem_params(model, bestParams, opts);
bestFit = evaluate_case_set(model, fitData, opts);
bestVal = evaluate_case_set(model, validationData, opts);

if opts.applyBestToModel
    restoreParams = bestParams;
else
    restoreParams = baseParams;
    set_echem_params(model, baseParams, opts);
end

fprintf('\nBest electrochemical parameters:\n');
print_params(bestParams, spec);
fprintf('Best objective = %.6g, exitflag = %d\n', fBest, exitflag);
fprintf('Best fit-set RMSE = %.6g V\n', rmse(bestFit.err_V));
fprintf('Best validation-set RMSE = %.6g V\n', rmse(bestVal.err_V));
print_case_eval(bestFit, "fit");
print_case_eval(bestVal, "validation");
fprintf('Total wall time = %.1f s\n', toc(runTimer));
fprintf('Model was not saved. Inspect the live COMSOL session before saving in GUI.\n');

result = struct();
result.mode = "fit";
result.fitCaseIdx = opts.fitCaseIdx;
result.validationCaseIdx = opts.validationCaseIdx;
result.initialParams = baseParams;
result.initialFit = baseFit;
result.initialValidation = baseVal;
result.bestParams = bestParams;
result.bestFit = bestFit;
result.bestValidation = bestVal;
result.exitflag = exitflag;
result.output = output;

    function f = bounded_objective(z)
        evalTimer = tic;
        evalCounter = evalCounter + 1;
        if any(~isfinite(z))
            f = opts.failurePenalty;
            fprintf('Eval %03d: non-finite parameter vector penalty %.6g\n', evalCounter, f);
            return
        end

        [trialParams, boundPenalty] = params_from_unit(z, spec, baseParams, opts.failurePenalty);
        if ~isfinite(boundPenalty) || boundPenalty > 0
            f = opts.failurePenalty + boundPenalty;
            fprintf('Eval %03d: bound penalty %.6g\n', evalCounter, f);
            return
        end
        if opts.showEvalProgress
            fprintf('\n[%s] Eval %03d/%03d starting\n', stamp_now(), evalCounter, opts.maxFunEvals);
            print_params(trialParams, spec);
        end
        set_echem_params(model, trialParams, opts);
        fitEv = evaluate_case_set(model, fitData, opts);
        f = fitEv.objective + boundPenalty;
        if opts.validationWeight > 0
            valEv = evaluate_case_set(model, validationData, opts);
            f = f + opts.validationWeight * valEv.objective;
        end
        evalElapsed_s = toc(evalTimer);
        evalElapsedTotal_s = evalElapsedTotal_s + evalElapsed_s;
        if opts.showEvalProgress
            fprintf('Eval %03d: obj %.6g | %s', ...
                evalCounter, f, format_param_summary(trialParams, spec));
            fprintf(', eval_time %.1f s, total_eval_time %.1f s\n', evalElapsed_s, evalElapsedTotal_s);
        end
    end

    function stop = report_optim_state(x, optimValues, state)
        stop = false;
        switch string(state)
            case "init"
                fprintf('\nOptimizer started at %s\n', stamp_now());
            case "iter"
                [paramsNow, ~] = params_from_unit(x, spec, baseParams, opts.failurePenalty);
                fprintf(['Iter %02d | fcount %03d | wall %.1f s | f=%.6g | %s\n'], ...
                    optimValues.iteration, optimValues.funccount, toc(runTimer), ...
                    optimValues.fval, format_param_summary(paramsNow, spec));
            case "done"
                fprintf('Optimizer finished at %s, wall %.1f s\n', stamp_now(), toc(runTimer));
        end
    end

    function restore_live_model()
        try
            set_echem_params(model, restoreParams, opts);
        catch ME
            warning('fit_comsol_echem_polarization_stage1:RestoreFailed', ...
                'Failed to restore live COMSOL parameters: %s', ME.message);
        end
    end

    function touch_cleanup(~)
    end
end

function opts = apply_defaults(opts)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));

defaults = struct();
defaults.serverHost = '127.0.0.1';
defaults.serverPort = 2036;
defaults.modelTag = '';
defaults.modelFile = fullfile(root, '02_多物理场机理模型演示', '20260629-结构简化燃料电池-阴极尾气循环-codex构建.mph');
defaults.comsolMliPath = 'D:\COMSOL63\Multiphysics\mli';
defaults.dataCsv = fullfile(root, '01_自吸方案', '03_台架测试_10kW_简化版', ...
    '00_输入参数', '实验数据', 'combined_noegr_cegr_fit_points.csv');
defaults.fitCaseIdx = [1, 5, 9, 13, 19];
defaults.validationCaseIdx = [3, 11, 16];
defaults.evaluateOnly = false;
defaults.initialParams = [];
defaults.maxIter = 16;
defaults.maxFunEvals = 48;
defaults.tolX = 0.02;
defaults.tolFun = 0.02;
defaults.failurePenalty = 1e9;
defaults.applyBestToModel = true;
defaults.restoreParamsOnExit = false;
defaults.validationWeight = 0;
defaults.showWaitbar = false;
defaults.showCaseProgress = false;
defaults.showEvalProgress = false;
defaults.showFailureDetail = false;
defaults.studyTag = 'std1';
defaults.rejectActiveStudySweep = true;
defaults.voltageExpressions = {'fc.phis0_ec1'};
defaults.preflightCaseIdx = [];
defaults.preflightOnly = false;
defaults.activeParams = {'i0_ref_c', 'alpha_a_c', 'R_contact_c_area'};
defaults.paramBounds = struct();
defaults.paramBounds.i0_ref_c = [];
defaults.paramBounds.alpha_a_c = [];
defaults.paramBounds.R_contact_c_area = [];

names = fieldnames(defaults);
allowExplicitEmpty = ["fitCaseIdx", "validationCaseIdx", "preflightCaseIdx", "initialParams"];
for i = 1:numel(names)
    name = names{i};
    if ~isfield(opts, name)
        opts.(name) = defaults.(name);
    elseif isempty(opts.(name)) && ~any(allowExplicitEmpty == string(name))
        opts.(name) = defaults.(name);
    end
end
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

function model = get_live_model(modelTag, modelFile)
import com.comsol.model.util.*

if ~isempty(modelTag)
    model = ModelUtil.model(modelTag);
    return
end

tags = cell(ModelUtil.tags);
if isempty(tags)
    if strlength(string(modelFile)) == 0
        error('No model is loaded in the connected COMSOL Server session, and opts.modelFile is empty.');
    end
    fprintf('No live model found in server session. Loading from file: %s\n', modelFile);
    model = mphopen(modelFile);
    return
end
if numel(tags) > 1
    error(['Multiple models are loaded in the connected COMSOL Server session (%s). ' ...
        'Set opts.modelTag explicitly before running the fitting script.'], ...
        strjoin(string(tags), ', '));
end
model = ModelUtil.model(tags{1});
fprintf('Using COMSOL model tag: %s\n', tags{1});
end

function audit_study_configuration(model, opts)
study = model.study(opts.studyTag);
featureTags = cell(study.feature.tags);

if opts.showEvalProgress
    fprintf('\nStudy audit for %s:\n', opts.studyTag);
end
for i = 1:numel(featureTags)
    tag = featureTags{i};
    feat = study.feature(tag);

    label = "";
    try
        label = string(char(feat.label()));
    catch
    end

    pname = read_feature_string(feat, 'pname');
    plist = read_feature_string(feat, 'plist');
    plistarr = strjoin(read_feature_string_array(feat, 'plistarr'), ' | ');
    useparam = read_feature_boolean(feat, 'useparam');

    if opts.showEvalProgress
        fprintf('  %-8s  useparam=%d', tag, useparam);
        if strlength(label) > 0
            fprintf('  label=%s', label);
        end
        if strlength(pname) > 0
            fprintf('  pname=%s', pname);
        end
        if strlength(plist) > 0
            fprintf('  plist=%s', plist);
        end
        if strlength(plistarr) > 0
            fprintf('  plistarr=%s', plistarr);
        end
        fprintf('\n');
    end

    hasSweepDefinition = strlength(pname) > 0 || strlength(plist) > 0 || strlength(plistarr) > 0;
    if useparam && hasSweepDefinition && opts.rejectActiveStudySweep
        error(['Active study sweep detected in %s/%s: pname=%s, plist=%s, plistarr=%s. ' ...
            'Disable the sweep in COMSOL GUI or set a dedicated clean study before fitting.'], ...
            opts.studyTag, tag, pname, plist, plistarr);
    elseif hasSweepDefinition && opts.showEvalProgress
        fprintf('  Warning: sweep definition residue detected in %s/%s.\n', opts.studyTag, tag);
    end
end
if opts.showEvalProgress
    fprintf('\n');
end
end

function out = read_feature_string(feat, key)
out = "";
try
    out = string(char(feat.getString(key)));
catch
end
end

function out = read_feature_string_array(feat, key)
out = strings(0, 1);
try
    out = string(cell(feat.getStringArray(key)));
    out = out(:);
    out(out == "") = [];
catch
end
end

function out = read_feature_boolean(feat, key)
out = false;
try
    out = feat.getBoolean(key);
catch
end
end

function validate_case_indices(caseIdx, nRows)
if any(caseIdx < 1) || any(caseIdx > nRows)
    error('caseIdx contains index outside experiment table range 1..%d.', nRows);
end
end

function print_case_sets(fitData, validationData)
if isempty(fitData) && isempty(validationData)
    return
end
fprintf('\nRepresentative cases:\n');
fprintf('%-12s %6s  %-18s %8s %8s %10s\n', 'role', 'idx', 'case_id', 'j', 'egr', 'V_exp');
for i = 1:height(fitData)
    r = fitData(i, :);
    fprintf('%-12s %6d  %-18s %8.3g %8.3g %10.6f\n', 'fit', ...
        r.case_idx, string(r.case_id), r.current_density_A_cm2, r.egr_fraction_model, r.cell_voltage_V);
end
for i = 1:height(validationData)
    r = validationData(i, :);
    fprintf('%-12s %6d  %-18s %8.3g %8.3g %10.6f\n', 'validate', ...
        r.case_idx, string(r.case_id), r.current_density_A_cm2, r.egr_fraction_model, r.cell_voltage_V);
end
end

function subset = attach_case_index(data, idx)
subset = data(idx, :);
subset.case_idx = idx(:);
subset = movevars(subset, "case_idx", "Before", 1);
end

function spec = param_spec(opts)
allSpecs = struct('name', {}, 'unit', {}, 'lower', {}, 'upper', {}, 'scale', {}, 'active', {});
allSpecs(end + 1) = make_spec('i0_ref_c', '[A/m^2]', opts.paramBounds.i0_ref_c, 'log10', true);
allSpecs(end + 1) = make_spec('alpha_a_c', '', opts.paramBounds.alpha_a_c, 'linear', true);
allSpecs(end + 1) = make_spec('R_contact_c_area', '[ohm*m^2]', opts.paramBounds.R_contact_c_area, 'log10', true);

activeNames = string(opts.activeParams);
spec = allSpecs(ismember(string({allSpecs.name}), activeNames));
end

function s = make_spec(name, unit, bounds, scale, active)
s = struct();
s.name = name;
s.unit = unit;
s.lower = bounds(1);
s.upper = bounds(2);
s.scale = scale;
s.active = active;
end

function params = read_echem_params(model)
params = struct();
params.i0_ref_c = model.param.evaluate('i0_ref_c');
params.alpha_a_c = model.param.evaluate('alpha_a_c');
params.Av_c = model.param.evaluate('Av_c');
params.R_contact_c_area = model.param.evaluate('R_contact_c_area');
end

function merged = merge_full_echem_params(baseParams, overrideParams)
merged = baseParams;
names = fieldnames(overrideParams);
for i = 1:numel(names)
    merged.(names{i}) = overrideParams.(names{i});
end
end

function set_echem_params(model, params, opts)
model.param.set('i0_ref_c', sprintf('%.16g[A/m^2]', params.i0_ref_c));
model.param.set('alpha_a_c', sprintf('%.16g', params.alpha_a_c));
model.param.set('Av_c', sprintf('%.16g[1/m]', params.Av_c));
model.param.set('R_contact_c_area', sprintf('%.16g[ohm*m^2]', params.R_contact_c_area));
end

function [params, boundPenalty] = params_from_unit(z, spec, baseParams, failurePenalty)
if nargin < 4
    failurePenalty = inf;
end
[vals, boundPenalty] = physical_from_unit(z(:), spec, failurePenalty);
params = baseParams;
for i = 1:numel(spec)
    params.(spec(i).name) = vals(i);
end
end

function v = pack_params(params, spec)
v = zeros(numel(spec), 1);
for i = 1:numel(spec)
    v(i) = params.(spec(i).name);
end
end

function z = physical_to_unit(x, spec)
x = x(:);
z = zeros(size(x));
for i = 1:numel(spec)
    lb = spec(i).lower;
    ub = spec(i).upper;
    xi = min(max(x(i), lb), ub);
    if spec(i).scale == "log10"
        z(i) = log10(xi);
    else
        z(i) = xi;
    end
end
end

function [x, boundPenalty] = physical_from_unit(z, spec, failurePenalty)
z = z(:);
x = zeros(size(z));
boundPenalty = 0;
for i = 1:numel(spec)
    lb = spec(i).lower;
    ub = spec(i).upper;
    if spec(i).scale == "log10"
        lo = log10(lb);
        hi = log10(ub);
        zi = z(i);
        if zi < lo
            boundPenalty = boundPenalty + failurePenalty * (lo - zi);
            zi = lo;
        elseif zi > hi
            boundPenalty = boundPenalty + failurePenalty * (zi - hi);
            zi = hi;
        end
        x(i) = 10 .^ zi;
    else
        zi = z(i);
        if zi < lb
            boundPenalty = boundPenalty + failurePenalty * (lb - zi);
            zi = lb;
        elseif zi > ub
            boundPenalty = boundPenalty + failurePenalty * (zi - ub);
            zi = ub;
        end
        x(i) = zi;
    end
end
end

function lb = lower_search_bounds(spec)
lb = zeros(numel(spec), 1);
for i = 1:numel(spec)
    if spec(i).scale == "log10"
        lb(i) = log10(spec(i).lower);
    else
        lb(i) = spec(i).lower;
    end
end
end

function ub = upper_search_bounds(spec)
ub = zeros(numel(spec), 1);
for i = 1:numel(spec)
    if spec(i).scale == "log10"
        ub(i) = log10(spec(i).upper);
    else
        ub(i) = spec(i).upper;
    end
end
end

function ev = evaluate_case_set(model, data, opts)
n = height(data);
rows = repmat(empty_eval_row(), n, 1);
objective = 0;
setName = infer_set_name(data);
progress = create_progress_tracker(opts, setName, n);
cleanup = onCleanup(@() close_progress(progress));
setTimer = tic;

for i = 1:n
    rows(i).caseIdx = data.case_idx(i);
    caseLabel = string(data.case_id(i));
    caseTimer = tic;
    update_progress(progress, i - 1, sprintf('%s: case_idx=%d (%s) starting', ...
        setName, data.case_idx(i), caseLabel));
    if opts.showCaseProgress
        fprintf('[%s %d/%d] case_idx=%d  case_id=%s  starting...\n', ...
            setName, i, n, data.case_idx(i), caseLabel);
    end
    try
        model.param.set('case_idx', num2str(data.case_idx(i)));
        model.study(opts.studyTag).run;
        rows(i).V_sim = read_voltage(model, opts);
        rows(i).V_exp = data.cell_voltage_V(i);
        rows(i).err_V = rows(i).V_sim - rows(i).V_exp;
        rows(i).ok = true;
        rows(i).objective = rows(i).err_V.^2;
        objective = objective + rows(i).objective;
        rows(i).elapsed_s = toc(caseTimer);
        setElapsed_s = toc(setTimer);
        eta_s = estimate_eta(setElapsed_s, i, n);
        update_progress(progress, i, sprintf(['%s: case_idx=%d done, |err|=%.6f V, ' ...
            'case %.1f s, elapsed %.1f s, eta %.1f s'], ...
            setName, data.case_idx(i), abs(rows(i).err_V), rows(i).elapsed_s, setElapsed_s, eta_s));
        if opts.showCaseProgress
            fprintf(['[%s %d/%d] case_idx=%d  done  V_exp=%.6f  V_sim=%.6f  err=%.6f V  ' ...
                'case=%.1f s  elapsed=%.1f s  eta=%.1f s\n'], ...
                setName, i, n, data.case_idx(i), rows(i).V_exp, rows(i).V_sim, rows(i).err_V, ...
                rows(i).elapsed_s, setElapsed_s, eta_s);
        end
    catch ME
        rows(i).ok = false;
        rows(i).message = string(ME.message);
        rows(i).objective = opts.failurePenalty;
        objective = objective + opts.failurePenalty;
        rows(i).elapsed_s = toc(caseTimer);
        setElapsed_s = toc(setTimer);
        eta_s = estimate_eta(setElapsed_s, i, n);
        update_progress(progress, i, sprintf('%s: case_idx=%d failed after %.1f s', ...
            setName, data.case_idx(i), rows(i).elapsed_s));
        if opts.showFailureDetail
            fprintf('case_idx %d failed after %.1f s (set elapsed %.1f s, eta %.1f s): %s\n', ...
                data.case_idx(i), rows(i).elapsed_s, setElapsed_s, eta_s, ME.message);
        elseif opts.showCaseProgress || opts.showEvalProgress
            fprintf('case_idx %d failed after %.1f s (set elapsed %.1f s, eta %.1f s)\n', ...
                data.case_idx(i), rows(i).elapsed_s, setElapsed_s, eta_s);
        end
    end
end

ev = struct();
ev.objective = objective;
ev.rows = rows;
ev.V_exp = transpose([rows.V_exp]);
ev.V_sim = transpose([rows.V_sim]);
ev.err_V = transpose([rows.err_V]);
ev.elapsed_s = toc(setTimer);
end

function V = read_voltage(model, opts)
for i = 1:numel(opts.voltageExpressions)
    expr = opts.voltageExpressions{i};
    try
        val = mphglobal(model, expr);
        if isscalar(val) && isfinite(val)
            V = val;
            return
        end
    catch
    end
end
try
    vExp = mphglobal(model, 'V_cell_exp');
    vResidual = mphglobal(model, 'V_cell_residual');
    if isscalar(vExp) && isfinite(vExp) && isscalar(vResidual) && isfinite(vResidual)
        V = vExp + vResidual;
        return
    end
catch
end
error('Unable to evaluate a voltage expression from the model. Tried: %s', strjoin(string(opts.voltageExpressions), ', '));
end

function row = empty_eval_row()
row = struct();
row.caseIdx = NaN;
row.ok = false;
row.message = "";
row.V_exp = NaN;
row.V_sim = NaN;
row.err_V = NaN;
row.objective = NaN;
row.elapsed_s = NaN;
end

function print_case_eval(ev, roleName)
fprintf('%-12s %6s %12s %12s %12s %10s\n', 'role', 'idx', 'V_exp', 'V_sim', 'err_V', 'time_s');
for i = 1:numel(ev.rows)
    r = ev.rows(i);
    fprintf('%-12s %6d %12.6f %12.6f %12.6f %10.2f\n', roleName, r.caseIdx, r.V_exp, r.V_sim, r.err_V, r.elapsed_s);
end
end

function print_params(params, spec)
activeNames = string({spec.name});
print_one_param('i0_ref_c', params.i0_ref_c, 'A/m^2', any(activeNames == "i0_ref_c"));
print_one_param('alpha_a_c', params.alpha_a_c, '', any(activeNames == "alpha_a_c"));
print_one_param('Av_c', params.Av_c, '1/m', any(activeNames == "Av_c"));
print_one_param('R_contact_c_area', params.R_contact_c_area, 'ohm*m^2', any(activeNames == "R_contact_c_area"));
end

function opts = finalize_param_config(opts, baseParams)
validNames = ["i0_ref_c", "alpha_a_c", "R_contact_c_area"];
activeNames = string(opts.activeParams);
activeNames = activeNames(:).';

if isempty(activeNames)
    error('opts.activeParams must contain at least one parameter name.');
end
if any(~ismember(activeNames, validNames))
    badNames = activeNames(~ismember(activeNames, validNames));
    error('Unsupported parameter name(s) in opts.activeParams: %s', strjoin(badNames, ', '));
end
if numel(unique(activeNames)) ~= numel(activeNames)
    error('opts.activeParams contains duplicated parameter names.');
end
if any(activeNames == "Av_c")
    error(['Av_c has been removed from the polarization fitting parameter set because it is ' ...
        'strongly coupled with current scaling. Keep Av_c fixed in the COMSOL model and only fit ' ...
        'i0_ref_c, alpha_a_c, and R_contact_c_area here.']);
end

opts.activeParams = cellstr(activeNames);
opts.paramBounds.i0_ref_c = resolve_param_bound(opts.paramBounds.i0_ref_c, baseParams.i0_ref_c, [1e-6, 1e2], 'log10');
opts.paramBounds.alpha_a_c = resolve_param_bound(opts.paramBounds.alpha_a_c, baseParams.alpha_a_c, [1.0, 6.0], 'linear');
opts.paramBounds.R_contact_c_area = resolve_param_bound(opts.paramBounds.R_contact_c_area, baseParams.R_contact_c_area, [1e-9, 1e-5], 'log10');
end

function bounds = resolve_param_bound(bounds, baseValue, hardBounds, scale)
if ~isempty(bounds)
    return
end

switch scale
    case 'log10'
        bounds = adaptive_log_bounds(baseValue, hardBounds, 1.0);
    case 'linear'
        bounds = adaptive_linear_bounds(baseValue, hardBounds, 0.75);
    otherwise
        error('Unsupported bound scale: %s', scale);
end
end

function bounds = adaptive_log_bounds(baseValue, hardBounds, halfWidthDec)
if ~isfinite(baseValue) || baseValue <= 0
    bounds = hardBounds;
    return
end

lo = max(hardBounds(1), baseValue ./ 10.^halfWidthDec);
hi = min(hardBounds(2), baseValue .* 10.^halfWidthDec);
if ~(isfinite(lo) && isfinite(hi)) || lo >= hi
    bounds = hardBounds;
else
    bounds = [lo, hi];
end
end

function bounds = adaptive_linear_bounds(baseValue, hardBounds, halfWidth)
if ~isfinite(baseValue)
    bounds = hardBounds;
    return
end

lo = max(hardBounds(1), baseValue - halfWidth);
hi = min(hardBounds(2), baseValue + halfWidth);
if ~(isfinite(lo) && isfinite(hi)) || lo >= hi
    bounds = hardBounds;
else
    bounds = [lo, hi];
end
end

function print_one_param(name, value, unit, isActive)
status = "fixed";
if isActive
    status = "fit";
end
if strlength(unit) > 0
    fprintf('  %-18s = %.6g %s  [%s]\n', name, value, unit, status);
else
    fprintf('  %-18s = %.6g  [%s]\n', name, value, status);
end
end

function s = format_param_summary(params, spec)
parts = strings(1, numel(spec));
for i = 1:numel(spec)
    parts(i) = sprintf('%s=%.4g', spec(i).name, params.(spec(i).name));
end
s = strjoin(parts, ' ');
end

function r = rmse(x)
x = x(:);
x = x(isfinite(x));
if isempty(x)
    r = NaN;
else
    r = sqrt(mean(x.^2));
end
end

function setName = infer_set_name(data)
if isempty(data)
    setName = "empty";
    return
end
caseIdx = data.case_idx(:);
if all(ismember(caseIdx, [1 5 9 13 19]))
    setName = "fit";
elseif all(ismember(caseIdx, [3 11 16]))
    setName = "validation";
else
    setName = "cases";
end
end

function progress = create_progress_tracker(opts, setName, totalCount)
progress = struct('enabled', false, 'handle', [], 'setName', setName, 'totalCount', totalCount);
if ~opts.showWaitbar || totalCount <= 0 || ~usejava('desktop')
    return
end
try
    progress.handle = waitbar(0, sprintf('%s: waiting to start...', setName), ...
        'Name', sprintf('COMSOL %s progress', setName));
    progress.enabled = true;
catch
    progress.handle = [];
    progress.enabled = false;
end
end

function update_progress(progress, completedCount, message)
if ~progress.enabled
    return
end
try
    frac = completedCount / max(progress.totalCount, 1);
    frac = min(max(frac, 0), 1);
    if isgraphics(progress.handle)
        waitbar(frac, progress.handle, char(message));
    end
catch
end
end

function close_progress(progress)
if ~progress.enabled
    return
end
try
    if isgraphics(progress.handle)
        close(progress.handle);
    end
catch
end
end

function eta_s = estimate_eta(elapsed_s, completedCount, totalCount)
if completedCount <= 0
    eta_s = NaN;
    return
end
avg_s = elapsed_s / completedCount;
eta_s = max(totalCount - completedCount, 0) * avg_s;
end

function run_preflight_case(model, data, opts)
validate_case_indices(opts.preflightCaseIdx, height(data));
preflightData = attach_case_index(data, opts.preflightCaseIdx(:));
fprintf('\n=== Preflight cases ===\n');
print_case_sets(preflightData, data([],:));
preflightEv = evaluate_case_set(model, preflightData, opts);
fprintf('Preflight objective = %.6g, elapsed = %.1f s\n', preflightEv.objective, preflightEv.elapsed_s);
print_case_eval(preflightEv, "preflight");
end

function s = stamp_now()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
