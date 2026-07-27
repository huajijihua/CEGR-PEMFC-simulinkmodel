function matrix = run_routeA_stage1_constant_current_multiload_matrix(studyCfg)
% Compatibility wrapper for the generic Current boundary study.
%
% The historical public function name is retained. All simulation and output
% assessment now live in run_routeA_electrical_boundary_study.

if nargin < 1 || isempty(studyCfg)
    studyCfg = struct();
end
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', ...
    'RouteA_GasMixture_Derived');
model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = fullfile(modelDir, [model '.slx']);
[stackAreaCm2, valveArea] = readPlatformDefaults(model, modelFile);
defaults = struct( ...
    'researchDuration_s', 600, ...
    'tailLogicalWindow_s', [540, 600], ...
    'studyMaxStep_s', 5, ...
    'caseIds', strings(1, 0), ...
    'runWaterLedger', true, ...
    'executionMode', "parallel", ...
    'parallelWorkers', 2, ...
    'showProgress', true, ...
    'resultFile', "");
userNames = fieldnames(studyCfg);
for idx = 1:numel(userNames)
    name = userNames{idx};
    if ~isfield(defaults, name)
        error('RouteA:CurrentWrapperConfigField', ...
            'Unsupported current wrapper field: %s.', name);
    end
    defaults.(name) = studyCfg.(name);
end
loads = [loadDefinition("low", 0.2, 4, stackAreaCm2); ...
    loadDefinition("nominal", 0.7, 3, stackAreaCm2); ...
    loadDefinition("high", 1.2, 2, stackAreaCm2)];
ratios = [0, 0.10, 0.30];
cases = struct([]);
for loadIdx = 1:numel(loads)
    for ratioIdx = 1:numel(ratios)
        load = loads(loadIdx);
        ratio = ratios(ratioIdx);
        item = struct();
        item.caseId = load.id + "_cegr_" + ratioText(ratio);
        item.loadId = load.id;
        item.currentDensity_A_cm2 = load.currentDensity_A_cm2;
        item.boundary = struct('type', "Current", ...
            'profile', load.targetCurrentA);
        item.cegr = ratio;
        item.air = struct('modeId', 2, 'targetOer', load.targetAirEquivalentOer);
        item.acceptance = struct('currentAbsoluteTolerance_A', 5e-3);
        if isempty(cases)
            cases = item;
        else
            cases(end + 1) = item; %#ok<AGROW>
        end
    end
end
if ~isempty(defaults.caseIds)
    requested = string(defaults.caseIds);
    keep = ismember(string({cases.caseId}), requested);
    if ~builtin('any', keep)
        error('RouteA:CurrentWrapperCaseSelection', ...
            'None of the requested caseIds is available.');
    end
    cases = cases(keep);
end
genericCfg = struct( ...
    'initialStateFile', fullfile(modelDir, ...
        'RouteA_platform_default_initial_state.mat'), ...
    'researchDuration_s', defaults.researchDuration_s, ...
    'tailLogicalWindow_s', defaults.tailLogicalWindow_s, ...
    'studyMaxStep_s', defaults.studyMaxStep_s, ...
    'commandStartOffset_s', 0.5, ...
    'runWaterLedger', logical(defaults.runWaterLedger), ...
    'executionMode', defaults.executionMode, ...
    'parallelWorkers', defaults.parallelWorkers, ...
    'showProgress', logical(defaults.showProgress), ...
    'resultFile', defaults.resultFile, ...
    'cases', cases);
study = run_routeA_electrical_boundary_study(genericCfg);
matrix = study;
matrix.wrapper = "constant_current_multiload";
matrix.cegrValveMaxArea_m2 = valveArea;
matrix.targetRatios = ratios;
matrix.loads = loads;
matrix.loadGroups = buildLoadGroups(study.cases);
assignin('base', 'routeA_stage1_constant_current_multiload_matrix', matrix);
assignin('base', 'routeA_stage1_constant_current_multiload_summary', ...
    matrix.summaryTable);
assignin('base', 'routeA_stage1_constant_current_multiload_water_ledger', ...
    matrix.waterLedger);
end

function load = loadDefinition(id, density, oer, area)
load = struct('id', string(id), ...
    'currentDensity_A_cm2', density, ...
    'targetCurrentA', density * area, ...
    'targetAirEquivalentOer', oer);
end

function [area, valveArea] = readPlatformDefaults(model, modelFile)
wasLoaded = bdIsLoaded(model);
if ~wasLoaded
    load_system(modelFile);
end
cleanup = onCleanup(@() closeIfOwned(model, wasLoaded));
mw = get_param(model, 'ModelWorkspace');
area = mw.getVariable('stack_area');
valveArea = mw.getVariable('cegr_valve_max_area');
validateattributes(area, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(valveArea, {'numeric'}, {'scalar', 'positive', 'finite'});
clear cleanup;
end

function closeIfOwned(model, wasLoaded)
if ~wasLoaded && bdIsLoaded(model)
    close_system(model, 0);
end
end

function groups = buildLoadGroups(cases)
ids = unique(string({cases.loadId}), 'stable');
groups = repmat(struct('loadId', "", 'cases', struct([]), ...
    'passed', false), numel(ids), 1);
for idx = 1:numel(ids)
    mask = string({cases.loadId}) == ids(idx);
    groups(idx).loadId = ids(idx);
    groups(idx).cases = cases(mask);
    groups(idx).passed = builtin('all', [groups(idx).cases.passed]);
end
end

function text = ratioText(ratio)
text = replace(string(sprintf('%.2f', ratio)), '.', 'p');
end
