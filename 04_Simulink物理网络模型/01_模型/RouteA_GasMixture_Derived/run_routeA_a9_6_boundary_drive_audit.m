% Route A A9.6 boundary-drive and gas-path audit.
% First pass is read-only: no structural edit and no model save.

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = [model '.slx'];
oldDir = pwd;
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);
end
routeA_a9_6_cleanup = onCleanup(@() restoreFolderAndModel(oldDir, model, modelFile));

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
mw = get_param(model, 'ModelWorkspace');
varRefs = Simulink.findVars(model);

audit = struct();
audit.model = model;
audit.phase = "A9.6";
audit.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
audit.scope = "read-only boundary-drive and gas-path audit";
audit.generated = false;
audit.preflight = runPreflight(mw);
audit.variableReferences = unique(string({varRefs.Name})).';
audit.boundaryInventory = buildBoundaryInventory(mw, audit.variableReferences);
audit.gasPathMap = buildGasPathMap();
audit.interfaceGaps = buildInterfaceGaps();
audit.caseDefinitions = buildCaseDefinitions();
audit.caseEvidence = repmat(emptyCaseEvidence(), ...
    numel(audit.caseDefinitions), 1);

fprintf('\nRoute A A9.6 boundary-drive audit\n');
fprintf('  model=%s\n', model);
fprintf('  timestamp=%s\n', audit.timestamp);
fprintf('  preflight passed=%d\n', audit.preflight.passed);

if audit.preflight.passed
    for idx = 1:numel(audit.caseDefinitions)
        audit.caseEvidence(idx) = runEvidenceCase(model, modelFile, ...
            audit.caseDefinitions(idx));
    end
end

audit.generated = audit.preflight.passed && all([audit.caseEvidence.passed]);
audit.passed = audit.generated;
assignin('base', 'routeA_a9_6_boundary_drive_audit', audit);
dispAudit(audit);

function result = runPreflight(mw)
result = struct( ...
    'passed', false, ...
    'layerOk', false, ...
    'externalCaseDisabled', false, ...
    'errorId', "", ...
    'errorMessage', "");
try
    layer = string(getWorkspaceValue(mw, 'routeA_parameter_layer', ""));
    externalEnabled = logical(getWorkspaceValue(mw, ...
        'routeA_external_case_enabled', true));
    result.layerOk = layer == "platform_default";
    result.externalCaseDisabled = ~externalEnabled;
    result.passed = result.layerOk && result.externalCaseDisabled;
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
end
end

function inventory = buildBoundaryInventory(mw, varNames)
items = [
    boundaryItem("drive_cycle_time", "electric_load", "external_input", ...
        "model_workspace_parameter", "open", ...
        "Load command time vector used by the official power command chain")
    boundaryItem("drive_cycle_power", "electric_load", "external_input", ...
        "model_workspace_parameter", "open", ...
        "Power command vector; current density is not a direct model input")
    boundaryItem("env_yO2", "gas_composition", "external_input", ...
        "model_workspace_parameter", "open", ...
        "Fresh-air oxygen mole fraction")
    boundaryItem("env_yH20", "gas_composition", "derived_parameter", ...
        "model_workspace_parameter", "open_via_env_RH_env_T_env_p", ...
        "Fresh-air water mole fraction derived from RH and saturation pressure")
    boundaryItem("env_T", "gas_state", "external_input", ...
        "model_workspace_parameter", "limited", ...
        "Environment/source temperature, not a dedicated cathode inlet controller")
    boundaryItem("env_p", "gas_state", "external_input", ...
        "model_workspace_parameter", "limited", ...
        "Environment/source pressure and several initial pressure references")
    boundaryItem("tank_p", "gas_state", "external_input", ...
        "model_workspace_parameter", "open", ...
        "Hydrogen tank/source pressure")
    boundaryItem("tank_yH2", "gas_composition", "external_input", ...
        "model_workspace_parameter", "open", ...
        "Hydrogen source mole fraction")
    boundaryItem("cegr_valve_area_closed", "gas_mass_flow", "device_parameter", ...
        "model_workspace_parameter", "open", ...
        "Near-closed cEGR valve area; mass flow is solved by network")
    boundaryItem("cegr_valve_area_low", "gas_mass_flow", "device_parameter", ...
        "model_workspace_parameter", "open", ...
        "Small cEGR valve area; not a target EGR-ratio controller")
    boundaryItem("cegr_valve_max_area", "gas_mass_flow", "device_parameter", ...
        "model_workspace_parameter", "open", ...
        "A9 upper sanity cEGR valve area")
    boundaryItem("routeA_cathode_humidifier_gain", "gas_state", ...
        "external_input", "model_workspace_parameter", "open", ...
        "Humidifier active/bypass gain used by A8/A9 tests")
    boundaryItem("comp_mdot_corr_TLU", "gas_mass_flow", "device_parameter", ...
        "model_workspace_parameter", "profile", ...
        "Compressor map; contributes to solved flow, not a direct mdot input")
    boundaryItem("comp_p_ratio_TLU", "gas_pressure_flow", "device_parameter", ...
        "model_workspace_parameter", "profile", ...
        "Compressor pressure-ratio map")
    boundaryItem("intercooler_dp_nominal", "gas_pressure_flow", ...
        "device_parameter", "model_workspace_parameter", "open", ...
        "L2 intercooler pressure-drop parameter")
    boundaryItem("cathode_separator_dp_nominal", "gas_pressure_flow", ...
        "device_parameter", "model_workspace_parameter", "open", ...
        "L2 cathode separator pressure-drop parameter")
    boundaryItem("cathode_separator_mdot_nominal", "gas_mass_flow", ...
        "device_parameter", "model_workspace_parameter", "open", ...
        "Nominal separator flow for pressure-drop scaling, not a flow command")
    boundaryItem("cegr_outlet_chamber_p0", "gas_state", "initial_condition", ...
        "model_workspace_parameter", "not_runtime_control", ...
        "Initial pressure for cathode outlet chamber")
    boundaryItem("cegr_pipe_p0", "gas_state", "initial_condition", ...
        "model_workspace_parameter", "not_runtime_control", ...
        "Initial pressure for cEGR pipe")
    boundaryItem("intercooler_T0", "gas_state", "initial_condition", ...
        "model_workspace_parameter", "not_runtime_control", ...
        "Initial temperature for L2 intercooler interface")
    ];

name = strings(numel(items), 1);
category = strings(numel(items), 1);
role = strings(numel(items), 1);
source = strings(numel(items), 1);
openness = strings(numel(items), 1);
referenced = false(numel(items), 1);
value = strings(numel(items), 1);
note = strings(numel(items), 1);
for idx = 1:numel(items)
    item = items(idx);
    name(idx) = item.name;
    category(idx) = item.category;
    role(idx) = item.role;
    source(idx) = item.source;
    openness(idx) = item.openness;
    referenced(idx) = any(varNames == item.name);
    value(idx) = valueToString(getWorkspaceValue(mw, char(item.name), []));
    note(idx) = item.note;
end
inventory = table(name, category, role, source, openness, referenced, ...
    value, note);
end

function item = boundaryItem(name, category, role, source, openness, note)
item = struct('name', string(name), 'category', string(category), ...
    'role', string(role), 'source', string(source), ...
    'openness', string(openness), 'note', string(note));
end

function gasPathMap = buildGasPathMap()
node = [
    "fresh_air_environment"
    "compressor_inlet_mixer"
    "compressor_and_map"
    "intercooler_l2_interface"
    "cathode_humidifier_or_bypass"
    "cathode_gas_channels"
    "cathode_outlet_chamber"
    "cathode_separator_and_split"
    "exhaust_branch"
    "cegr_valve_pipe_return"
    "hydrogen_tank_source"
    "anode_gas_channels"
    "anode_recirculation_separator"
    ];
functionRole = [
    "fresh gas composition and state source"
    "mixes fresh air and cEGR return gas"
    "raises pressure and drives solved cathode flow"
    "L2 pressure-drop and charge-air-cooler placeholder"
    "sets humidified/bypassed cathode feed behavior"
    "stack cathode reaction and gas transport"
    "outlet inventory and pressure state"
    "L2 water-separator interface and exhaust/cEGR split"
    "discharges non-recycled cathode exhaust"
    "sets cEGR restriction and return pressure-flow relation"
    "anode hydrogen composition and pressure source"
    "stack anode reaction and gas transport"
    "anode recycle L2 separator/recirculation path"
    ];
controlledBy = [
    "env_yO2, env_yH20, env_p, env_T"
    "physical network; no target mix controller"
    "comp_* maps and physical network"
    "intercooler_* parameters"
    "routeA_cathode_humidifier_gain"
    "stack load and FC component physics"
    "cegr_outlet_chamber_* initial state and network solution"
    "cathode_separator_* and downstream restrictions"
    "network pressure-flow solution"
    "EGRValveRestriction.restriction_area and cegr_pipe_*"
    "tank_p, tank_yH2"
    "stack load and FC component physics"
    "anode_separator_* and recirculation component"
    ];
measuredBy = [
    "workspace values"
    "routeA_p_comp_inlet, routeA_T_comp_inlet, routeA_yi_comp_inlet, routeA_mdot_comp_inlet"
    "simlog and downstream pressure/flow signals"
    "not directly unified as A9.6 KPI"
    "routeA_RH_ca_in"
    "simlog stack power/heat; outlet composition downstream"
    "routeA_p_outlet, routeA_T_outlet, routeA_yi_outlet"
    "routeA_cegr_mdot, routeA_exhaust_mdot, routeA_m_water_sep"
    "routeA_exhaust_mdot"
    "routeA_p_egr_valve_up/down, routeA_cegr_mdot"
    "workspace values"
    "not directly unified as A9.6 KPI"
    "not directly unified as A9.6 KPI"
    ];
openIssue = [
    "fresh-air source only; not a full inlet-condition controller"
    "target EGR ratio controller not exposed"
    "target cathode mdot/stoch controller not exposed"
    "thermal boundary is L2 placeholder"
    "pre-humidifier RH/temperature map incomplete"
    "stack inlet p/T KPI not unified"
    "liquid water only simplified KPI"
    "separator is L2 interface, not calibrated water management"
    "none for A9.6"
    "valve area is input, target EGR is not"
    "anode stoich controller not exposed"
    "anode inlet/outlet KPI not unified"
    "anode recycle control not productized"
    ];
gasPathMap = table(node, functionRole, controlledBy, measuredBy, openIssue);
end

function gaps = buildInterfaceGaps()
gap = [
    "direct_current_or_current_density_load_input"
    "target_egr_ratio_controller"
    "cathode_total_mdot_or_stoich_controller"
    "anode_stoich_controller"
    "cathode_stack_inlet_pT_unified_KPI"
    "anode_boundary_pT_mdot_unified_KPI"
    "real_inlet_temperature_pressure_control"
    "liquid_water_physics"
    ];
severity = [
    "medium"
    "high"
    "high"
    "medium"
    "high"
    "medium"
    "medium"
    "deferred"
    ];
currentStatus = [
    "Power command exists; current density only used to derive target power in scripts"
    "Valve area can be set; target ratio requires iteration or controller"
    "No direct cathode mdot/stoch input found in model variable references"
    "No direct anode lambda input found in model variable references"
    "Some compressor inlet and outlet p/T signals exist; stack inlet p/T not unified"
    "Anode path exists but A9 scripts do not yet summarize p/T/mdot"
    "env_p/env_T are source/environment parameters and initial-state references"
    "Only RH and separated/condensed water KPI are retained in A9"
    ];
nextAction = [
    "A9.7 decide whether to add current-command wrapper"
    "A9.7 implement target-ratio valve-area search before A10/A11"
    "A9.7 define cathode oxygen-sufficiency and stoich postprocessing first"
    "A9.7 define anode hydrogen excess/purge assumptions"
    "Add read-only probes if existing model signals cannot expose these values"
    "Extend boundary audit or add minimal read-only anode evidence pass"
    "Do not repurpose initial conditions as runtime controllers"
    "Keep simplified until gas-path boundary and EGR control are stable"
    ];
gaps = table(gap, severity, currentStatus, nextAction);
end

function defs = buildCaseDefinitions()
defs = [
    evidenceCase("no_egr_nominal_load", "cegr_valve_area_closed")
    evidenceCase("mid_egr_nominal_load", "2e-3*cegr_pipe_area")
    ];
end

function c = evidenceCase(caseId, restrictionArea)
c = struct('caseId', string(caseId), ...
    'targetPowerKW', 50.96, ...
    'restrictionArea', string(restrictionArea), ...
    'stopTime', 30);
end

function result = runEvidenceCase(model, modelFile, c)
result = emptyCaseEvidence();
result.caseId = c.caseId;
result.targetPowerKW = c.targetPowerKW;
result.restrictionArea = c.restrictionArea;
result.stopTime = c.stopTime;
fprintf('\nA9.6 evidence case: %s target=%.4g kW area=%s\n', ...
    result.caseId, result.targetPowerKW, result.restrictionArea);
try
    resetModelFromDisk(model, modelFile);
    refreshModelWorkspace(model);
    markAuditSignals(model);
    simIn = Simulink.SimulationInput(model);
    simIn = simIn.setModelParameter( ...
        'StopTime', sprintf('%.16g', c.stopTime), ...
        'SignalLogging', 'on', ...
        'SignalLoggingName', 'logsout', ...
        'ReturnWorkspaceOutputs', 'on', ...
        'SimscapeLogType', 'all');
    simIn = simIn.setVariable('drive_cycle_time', [0; 5; c.stopTime], ...
        'Workspace', model);
    simIn = simIn.setVariable('drive_cycle_power', ...
        [0; c.targetPowerKW; c.targetPowerKW], 'Workspace', model);
    simIn = simIn.setVariable('routeA_cathode_humidifier_gain', 1);
    simIn = simIn.setBlockParameter([model '/EGRValveRestriction'], ...
        'restriction_area', char(c.restrictionArea));
    simOut = sim(simIn);
    result.simCompleted = true;
    result = collectEvidence(simOut, result, model);
    result.passed = result.simCompleted && result.kpiFiniteOk;
    fprintf('  PASS=%d power=%.4g kW egr=%.4g split=%.4g comp_mdot=%.4g kg/s\n', ...
        result.passed, result.actualPowerKW, result.egrRatioCompIn, ...
        result.egrSplitRatioOut, result.compInletMdotKgS);
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
    fprintf('  FAIL %s: %s\n', result.errorId, result.errorMessage);
end
resetModelFromDisk(model, modelFile);
end

function result = emptyCaseEvidence()
result = struct( ...
    'caseId', "", ...
    'passed', false, ...
    'simCompleted', false, ...
    'errorId', "", ...
    'errorMessage', "", ...
    'targetPowerKW', NaN, ...
    'actualPowerKW', NaN, ...
    'stackHeatKW', NaN, ...
    'restrictionArea', "", ...
    'stopTime', NaN, ...
    'pOutletPa', NaN, ...
    'tOutletK', NaN, ...
    'yiOutlet', NaN(1, 4), ...
    'pCompInletPa', NaN, ...
    'tCompInletK', NaN, ...
    'yiCompInlet', NaN(1, 4), ...
    'pEgrValveUpPa', NaN, ...
    'pEgrValveDownPa', NaN, ...
    'egrMdotKgS', NaN, ...
    'compInletMdotKgS', NaN, ...
    'freshInletMdotKgS', NaN, ...
    'exhaustMdotKgS', NaN, ...
    'egrRatioCompIn', NaN, ...
    'egrSplitRatioOut', NaN, ...
    'rhCaIn', NaN, ...
    'rhCaOut', NaN, ...
    'mWaterSep', NaN, ...
    'kpiFiniteOk', false);
end

function result = collectEvidence(simOut, result, model)
logsout = simOut.logsout;
result.pOutletPa = scalarLastOrNaN(logsout, "routeA_p_outlet");
result.tOutletK = scalarLastOrNaN(logsout, "routeA_T_outlet");
result.yiOutlet = vectorLastOrNaN(logsout, "routeA_yi_outlet", 4);
result.pCompInletPa = scalarLastOrNaN(logsout, "routeA_p_comp_inlet");
result.tCompInletK = scalarLastOrNaN(logsout, "routeA_T_comp_inlet");
result.yiCompInlet = vectorLastOrNaN(logsout, "routeA_yi_comp_inlet", 4);
result.pEgrValveUpPa = scalarLastOrNaN(logsout, "routeA_p_egr_valve_up");
result.pEgrValveDownPa = scalarLastOrNaN(logsout, "routeA_p_egr_valve_down");
result.egrMdotKgS = scalarLastOrNaN(logsout, "routeA_cegr_mdot");
result.compInletMdotKgS = scalarLastOrNaN(logsout, ...
    "routeA_mdot_comp_inlet");
result.exhaustMdotKgS = scalarLastOrNaN(logsout, ...
    "routeA_exhaust_mdot");
if ~isfinite(result.exhaustMdotKgS)
    result.exhaustMdotKgS = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_exhaust_mdot_ts");
end
result.rhCaIn = scalarLastOrNaN(logsout, "routeA_RH_ca_in");
if ~isfinite(result.rhCaIn)
    result.rhCaIn = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_RH_ca_in_ts");
end
result.rhCaOut = scalarLastOrNaN(logsout, "routeA_RH_ca_out");
if ~isfinite(result.rhCaOut)
    result.rhCaOut = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_RH_ca_out_ts");
end
result.mWaterSep = scalarLastOrNaN(logsout, "routeA_m_water_sep");
if ~isfinite(result.mWaterSep)
    result.mWaterSep = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_m_water_sep_ts");
end
result.egrRatioCompIn = safeDivide(result.egrMdotKgS, ...
    result.compInletMdotKgS);
result.egrSplitRatioOut = safeDivide(max(result.egrMdotKgS, 0), ...
    max(result.egrMdotKgS, 0) + max(result.exhaustMdotKgS, 0));
result.freshInletMdotKgS = result.compInletMdotKgS - result.egrMdotKgS;
[result.actualPowerKW, result.stackHeatKW] = collectSimscapePower(simOut, model);
result.kpiFiniteOk = all(isfinite([result.actualPowerKW, ...
    result.pOutletPa, result.tOutletK, result.pCompInletPa, ...
    result.tCompInletK, result.egrMdotKgS, result.compInletMdotKgS, ...
    result.egrRatioCompIn, result.egrSplitRatioOut, result.rhCaIn, ...
    result.rhCaOut, result.mWaterSep]));
end

function [powerKW, heatKW] = collectSimscapePower(simOut, model)
powerKW = NaN;
heatKW = NaN;
try
    simlog = simOut.get(['simlog_' model]);
    powerData = simlog.Membrane_Electrode_Assembly.power_elec.series.values('kW');
    powerKW = powerData(end);
catch
end
try
    simlog = simOut.get(['simlog_' model]);
    heatData = simlog.Membrane_Electrode_Assembly.power_dissipated.series.values('kW');
    heatKW = heatData(end);
catch
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

function value = vectorLastOrNaN(logsout, signalName, n)
value = lastLoggedValueOrNaN(logsout, signalName);
if isempty(value)
    value = NaN(1, n);
elseif numel(value) < n
    value = [value(:).' NaN(1, n - numel(value))];
else
    value = value(1:n);
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

function markAuditSignals(model)
nameLineFromBlockOut([model '/Oxygen Source/PS-Simulink Converter'], ...
    'routeA_mdot_comp_inlet');
nameLineFromBlockOut([model '/Exhaust_mdot_Converter'], ...
    'routeA_exhaust_mdot');
nameLineFromBlockOut([model '/Cathode Humidifier/PS-Simulink Converter2'], ...
    'routeA_RH_ca_in');
nameLineFromBlockOut([model '/OutletRH_Converter'], ...
    'routeA_RH_ca_out');
nameLineFromBlockOut([model '/SeparatorOrCondensation'], ...
    'routeA_m_water_sep');
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

function value = getWorkspaceValue(modelWorkspace, name, fallback)
value = fallback;
try
    value = modelWorkspace.getVariable(name);
catch
end
end

function txt = valueToString(value)
if isempty(value)
    txt = "";
elseif isnumeric(value) || islogical(value)
    if isscalar(value)
        txt = string(sprintf('%.12g', value));
    else
        flat = value(:).';
        n = min(numel(flat), 6);
        pieces = strings(1, n);
        for idx = 1:n
            pieces(idx) = string(sprintf('%.6g', flat(idx)));
        end
        if numel(flat) > n
            txt = "[" + strjoin(pieces, ", ") + ", ...]";
        else
            txt = "[" + strjoin(pieces, ", ") + "]";
        end
    end
elseif isstring(value) || ischar(value)
    txt = string(value);
else
    txt = string(class(value));
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
fprintf('\nA9.6 result\n');
fprintf('  generated=%d passed=%d cases=%d/%d\n', audit.generated, ...
    audit.passed, nnz([audit.caseEvidence.passed]), ...
    numel(audit.caseEvidence));
fprintf('  boundary_items=%d gas_path_nodes=%d gaps=%d\n', ...
    height(audit.boundaryInventory), height(audit.gasPathMap), ...
    height(audit.interfaceGaps));
for idx = 1:numel(audit.caseEvidence)
    c = audit.caseEvidence(idx);
    fprintf('  %-22s passed=%d power=%.4g kW egr=%.4g comp_mdot=%.4g kg/s RH_in=%.4g RH_out=%.4g\n', ...
        c.caseId, c.passed, c.actualPowerKW, c.egrRatioCompIn, ...
        c.compInletMdotKgS, c.rhCaIn, c.rhCaOut);
end
end
