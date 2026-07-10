% Route A A10 main-model and reusable-entrypoint closure audit.
% Checks that Route A has a clear daily runner, model-facing FCU/BoP
% interfaces, and a compact regression path without moving legacy audits.

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = [model '.slx'];
oldDir = pwd;
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);
end
routeA_a10_cleanup = onCleanup(@() restoreFolderAndModel(oldDir, model, modelFile));

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
mw = get_param(model, 'ModelWorkspace');

a10Audit = struct();
a10Audit.model = model;
a10Audit.phase = "A10";
a10Audit.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
a10Audit.scope = "main model and reusable entrypoint closure";
a10Audit.preflight = runPreflight(model, mw);
a10Audit.demo = runDemoEntry();
a10Audit.a98 = runA98MinimalRegression();
a10Audit.a99 = runA99MinimalRegression();
a10Audit.generated = a10Audit.preflight.passed && ...
    a10Audit.demo.passed && a10Audit.a98.passed && a10Audit.a99.passed;
a10Audit.passed = a10Audit.generated;

assignin('base', 'routeA_a10_entrypoint_audit', a10Audit);
dispAudit(a10Audit);

function result = runPreflight(model, mw)
result = struct('passed', false, 'layerOk', false, ...
    'externalCaseDisabled', false, 'fcuExists', false, ...
    'airControlExists', false, 'backpressureTargeted', false, ...
    'operatorAnnotations', false, 'demoScriptExists', false, ...
    'docExists', false, 'requiredVariablesOk', false, ...
    'errorId', "", 'errorMessage', "");
try
    layer = string(getWorkspaceValue(mw, 'routeA_parameter_layer', ""));
    externalEnabled = logical(getWorkspaceValue(mw, ...
        'routeA_external_case_enabled', true));
    vars = ["routeA_air_control_mode_id", ...
        "routeA_target_mdot_comp_inlet", "routeA_target_oer", ...
        "routeA_egr_control_mode_id", "routeA_target_egr_ratio_comp_in", ...
        "routeA_target_p_ca_out_MPa", "routeA_cathode_humidifier_gain"];
    varOk = true(size(vars));
    for idx = 1:numel(vars)
        varOk(idx) = ~isempty(getWorkspaceValue(mw, vars(idx), []));
    end
    result.layerOk = layer == "platform_default";
    result.externalCaseDisabled = ~externalEnabled;
    result.fcuExists = getSimulinkBlockHandle([model '/FCU_BoP_Control']) ~= -1;
    result.airControlExists = getSimulinkBlockHandle([model ...
        '/Oxygen Source/Compressor Control/A98_CompressorCmd_ModeSwitch']) ~= -1;
    result.backpressureTargeted = contains(string(get_param([model ...
        '/Cathode Exhaust/Stack Pressure'], 'Value')), ...
        "routeA_target_p_ca_out_MPa");
    result.operatorAnnotations = hasOperatorVisuals(model);
    result.demoScriptExists = isfile('run_routeA_platform_demo.m');
    result.docExists = isfile('RouteA_A10_主模型与复用入口收口_v01.md');
    result.requiredVariablesOk = all(varOk);
    result.passed = result.layerOk && result.externalCaseDisabled && ...
        result.fcuExists && result.airControlExists && ...
        result.backpressureTargeted && result.operatorAnnotations && ...
        result.demoScriptExists && result.docExists && ...
        result.requiredVariablesOk;
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
end
end

function tf = hasOperatorVisuals(model)
tf = false;
try
    anns = find_system(model, 'FindAll', 'on', 'Type', 'annotation');
    for idx = 1:numel(anns)
        txt = string(get_param(anns(idx), 'PlainText'));
        if contains(txt, "RouteA Operator") && contains(txt, "FCU-BoP")
            tf = true;
            return;
        end
    end
catch
end
try
    requiredDisplays = ["RouteA_Display_EGR_Ratio", ...
        "RouteA_Display_EGR_Area", "RouteA_Display_P_Ca_Out", ...
        "RouteA_Display_Water_Sep"];
    displayOk = true(size(requiredDisplays));
    for idx = 1:numel(requiredDisplays)
        displayOk(idx) = getSimulinkBlockHandle([model '/' ...
            char(requiredDisplays(idx))]) ~= -1;
    end
    tf = all(displayOk);
catch
end
end

function result = runDemoEntry()
result = struct('passed', false, 'simCompleted', false, ...
    'finiteKpi', false, 'errorId', "", 'errorMessage', "");
try
    evalin('base', "run('run_routeA_platform_demo.m')");
    summary = evalin('base', 'routeA_platform_demo_summary');
    result.simCompleted = summary.simCompleted;
    result.finiteKpi = summary.kpiFiniteOk;
    result.passed = summary.passed;
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
end
end

function result = runA98MinimalRegression()
result = struct('passed', false, 'completedCases', 0, ...
    'requiredCases', 3, 'errorId', "", 'errorMessage', "");
try
    filters = ["mdot_0.045", "egr_ratio_0.020", "nominal_50p96kW"];
    baseVarCleanup = onCleanup(@() cleanupBaseA98Controls());
    allPassed = true;
    completed = 0;
    for idx = 1:numel(filters)
        assignin('base', 'routeA_a9_8_case_filter', filters(idx));
        assignin('base', 'routeA_a9_8_stop_time_override', 8);
        evalin('base', "run('run_routeA_a9_8_fcu_bop_control_audit.m')");
        a98 = evalin('base', 'routeA_a9_8_fcu_bop_control_audit');
        completed = completed + nnz([a98.caseResults.simCompleted]);
        allPassed = allPassed && a98.generated && ...
            all([a98.caseResults.simCompleted]) && ...
            all([a98.caseResults.kpiFiniteOk]);
    end
    result.completedCases = completed;
    result.passed = allPassed && completed == result.requiredCases;
    clear baseVarCleanup
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
end
end

function cleanupBaseA98Controls()
evalin('base', 'clear routeA_a9_8_case_filter routeA_a9_8_stop_time_override');
end

function result = runA99MinimalRegression()
result = struct('passed', false, 'errorId', "", 'errorMessage', "");
try
    evalin('base', "run('run_routeA_a9_9_backpressure_control_audit.m')");
    a99 = evalin('base', 'routeA_a9_9_backpressure_control_audit');
    nominalTarget = 0.101325 + 0.06;
    targets = [a99.caseResults.targetPCaOutMPa];
    [~, idx] = min(abs(targets - nominalTarget));
    result.passed = a99.generated && ~isempty(idx) && ...
        a99.caseResults(idx).passed;
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
end
end

function value = getWorkspaceValue(modelWorkspace, name, fallback)
value = fallback;
try
    value = modelWorkspace.getVariable(char(name));
catch
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

function refreshModelWorkspace(model)
modelWorkspace = get_param(model, 'ModelWorkspace');
if strcmp(modelWorkspace.DataSource, 'MATLAB File')
    modelWorkspace.reload;
end
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

function dispAudit(audit)
fprintf('\nRoute A A10 entrypoint audit\n');
fprintf('  generated=%d passed=%d\n', audit.generated, audit.passed);
fprintf('  preflight=%d demo=%d a98=%d a99=%d\n', ...
    audit.preflight.passed, audit.demo.passed, ...
    audit.a98.passed, audit.a99.passed);
fprintf('  A9.8 completed cases=%d/%d\n', ...
    audit.a98.completedCases, audit.a98.requiredCases);
end
