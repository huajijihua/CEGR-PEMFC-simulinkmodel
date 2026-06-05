function results = run_vehicle_10kw_gzs60_v3_condition_extension(runMode)
%RUN_VEHICLE_10KW_GZS60_V3_CONDITION_EXTENSION
% No-EGR baseline freeze and next-stage operating-condition exploration.
%
% Operating conditions are driven by MATLAB variables so the frozen Simulink
% structure remains unchanged. EGR studies here are qualitative trend checks.

if nargin < 1 || strlength(string(runMode)) == 0
    runMode = "baseline";
else
    runMode = string(runMode);
end

P0 = init_vehicle_10kw_gzs60_v3("current");
rootDir = P0.rootDir;
dataFile = fullfile(rootDir, '00_输入参数', '全电流段极化标定', 'full_range_polarization_data.csv');
outDir = fullfile(rootDir, '04_验证结果');
docDir = fullfile(rootDir, '03_说明');
model = P0.modelName;

if ~isfile(dataFile)
    error('Missing bench data: %s', dataFile);
end
if ~isfile(P0.modelFile)
    error('Missing Simulink model: %s', P0.modelFile);
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
if ~exist(docDir, 'dir')
    mkdir(docDir);
end

B = readtable(dataFile, 'TextType', 'string');
B = B(logical(B.use_for_fit), :);
open_system(P0.modelFile);

baselineFile = fullfile(outDir, 'no_egr_frozen_baseline_reference.csv');
cvFile = fullfile(outDir, 'condition_extension_constant_voltage_scan.csv');
egrFile = fullfile(outDir, 'condition_extension_egr_ratio_scan.csv');
po2File = fullfile(outDir, 'condition_extension_constant_pO2_scan.csv');
summaryFile = fullfile(outDir, 'condition_extension_summary.md');
docFile = fullfile(docDir, '下一阶段工况扩展实施说明.md');

results = struct();
switch runMode
    case "baseline"
        baseline = runNoEgrTable(P0, B, model);
        writetable(baseline, baselineFile);
        writeConditionSummary(summaryFile, baseline, table(), table(), table(), runMode);
        writeConditionDoc(docFile);
        results.baseline = baseline;
    case "constant_voltage"
        baseline = ensureBaseline(P0, B, model, baselineFile);
        cv = runConstantVoltageScan(P0, B, model);
        writetable(cv, cvFile);
        writeConditionSummary(summaryFile, baseline, cv, table(), table(), runMode);
        writeConditionDoc(docFile);
        results.baseline = baseline;
        results.constant_voltage = cv;
    case "egr_ratio"
        baseline = ensureBaseline(P0, B, model, baselineFile);
        egr = runEgrRatioScan(P0, B, model);
        writetable(egr, egrFile);
        writeConditionSummary(summaryFile, baseline, table(), egr, table(), runMode);
        writeConditionDoc(docFile);
        results.baseline = baseline;
        results.egr_ratio = egr;
    case "constant_pO2"
        baseline = ensureBaseline(P0, B, model, baselineFile);
        po2 = runConstantPO2Scan(P0, B, model, baseline);
        writetable(po2, po2File);
        writeConditionSummary(summaryFile, baseline, table(), table(), po2, runMode);
        writeConditionDoc(docFile);
        results.baseline = baseline;
        results.constant_pO2 = po2;
    case "all"
        baseline = runNoEgrTable(P0, B, model);
        cv = runConstantVoltageScan(P0, B, model);
        egr = runEgrRatioScan(P0, B, model);
        po2 = runConstantPO2Scan(P0, B, model, baseline);
        writetable(baseline, baselineFile);
        writetable(cv, cvFile);
        writetable(egr, egrFile);
        writetable(po2, po2File);
        writeConditionSummary(summaryFile, baseline, cv, egr, po2, runMode);
        writeConditionDoc(docFile);
        results.baseline = baseline;
        results.constant_voltage = cv;
        results.egr_ratio = egr;
        results.constant_pO2 = po2;
    otherwise
        error('Unknown runMode "%s". Use baseline, constant_voltage, egr_ratio, constant_pO2, or all.', runMode);
end

fprintf('Condition-extension run "%s" complete. Summary: %s\n', runMode, summaryFile);
end

function T = runNoEgrTable(P0, B, model)
rows = cell(height(B), 1);
for k = 1:height(B)
    P = configureBenchLikeCase(P0, B(k, :));
    row = runOperatingCase(P, B(k, :), model, 0.0, "no_egr_frozen_baseline", B(k, :).pO2_caIn_kPa);
    rows{k} = struct2table(row);
end
T = vertcat(rows{:});
end

function T = runConstantVoltageScan(P0, B, model)
targets = [0.90; 0.85; 0.80; 0.75; 0.70];
rows = {};
for t = 1:numel(targets)
    targetV = targets(t);
    [~, idx] = min(abs(B.cell_voltage_from_stack_V - targetV));
    ref = B(idx, :);
    currentGrid = unique(max(10, min(760, round(linspace(0.75, 1.25, 17)' * ref.current_A, 1))));
    best = [];
    bestAbs = inf;
    for k = 1:numel(currentGrid)
        trial = ref;
        trial.current_A = currentGrid(k);
        trial.current_density_A_cm2 = currentGrid(k) / P0.A_cell_cm2;
        P = configureBenchLikeCase(P0, trial);
        row = runOperatingCase(P, trial, model, 0.0, "constant_voltage_no_egr_scan", ref.pO2_caIn_kPa);
        row.V_cell_target = targetV;
        row.target_error_V = row.V_cell_sim - targetV;
        row.reference_case_id = string(ref.case_id);
        row.reference_current_A = ref.current_A;
        if abs(row.target_error_V) < bestAbs
            bestAbs = abs(row.target_error_V);
            best = row;
        end
    end
    rows{end + 1, 1} = struct2table(best); %#ok<AGROW>
end
T = vertcat(rows{:});
end

function T = runEgrRatioScan(P0, B, model)
ratios = [0; 0.1; 0.2; 0.3; 0.4];
lowLoadMask = B.cell_voltage_from_stack_V >= 0.70 & B.cell_voltage_from_stack_V <= 0.90;
if any(lowLoadMask)
    D = B(lowLoadMask, :);
else
    D = B(1:min(5, height(B)), :);
end
rows = {};
for i = 1:height(D)
    for r = 1:numel(ratios)
        P = configureBenchLikeCase(P0, D(i, :));
        row = runOperatingCase(P, D(i, :), model, ratios(r), "same_current_egr_ratio_qualitative", D(i, :).pO2_caIn_kPa);
        row.egr_ratio_cmd = ratios(r);
        row.severe_oxygen_starvation = row.lambda_O2_actual < 1.0;
        rows{end + 1, 1} = struct2table(row); %#ok<AGROW>
    end
end
T = vertcat(rows{:});
end

function T = runConstantPO2Scan(P0, B, model, baseline)
ratios = [0.1; 0.2; 0.3; 0.4];
rows = {};
for i = 1:height(B)
    targetPO2 = baseline.pO2_ca_in_kPa(i);
    for r = 1:numel(ratios)
        Pbase = configureBenchLikeCase(P0, B(i, :));
        [Pbest, bestRow] = tuneStoichForPO2(Pbase, B(i, :), model, ratios(r), targetPO2);
        bestRow.condition = "same_current_egr_constant_pO2_qualitative";
        bestRow.egr_ratio_cmd = ratios(r);
        bestRow.pO2_target_kPa = targetPO2;
        bestRow.oxygen_stoich_cmd = Pbest.oxygen_stoich;
        bestRow.severe_oxygen_starvation = bestRow.lambda_O2_actual < 1.0;
        rows{end + 1, 1} = struct2table(bestRow); %#ok<AGROW>
    end
end
T = vertcat(rows{:});
end

function [Pbest, bestRow] = tuneStoichForPO2(Pbase, dataRow, model, egrRatio, targetPO2)
baseLambda = max(Pbase.oxygen_stoich, 0.3);
lambdaGrid = unique([ ...
    linspace(0.5, 1.5, 11) * baseLambda, ...
    linspace(1.6, 3.0, 8) * baseLambda]);
bestErr = inf;
Pbest = Pbase;
bestRow = [];
for k = 1:numel(lambdaGrid)
        P = Pbase;
        P.oxygen_stoich = max(lambdaGrid(k), 0.2);
        P = updateModuleParamVectors(P);
        row = runOperatingCase(P, dataRow, model, egrRatio, "pO2_tuning_trial", targetPO2);
    err = abs(row.pO2_ca_in_kPa - targetPO2);
    if err < bestErr
        bestErr = err;
        Pbest = P;
        bestRow = row;
    end
end
bestRow.pO2_error_kPa = bestRow.pO2_ca_in_kPa - targetPO2;
end

function baseline = ensureBaseline(P0, B, model, baselineFile)
if isfile(baselineFile)
    baseline = readtable(baselineFile, 'TextType', 'string');
else
    baseline = runNoEgrTable(P0, B, model);
    writetable(baseline, baselineFile);
end
end

function P = configureBenchLikeCase(P, row)
P.I_stack_default_A = row.current_A;
P.oxygen_stoich = flowDerivedLambda(row, P);
P.anode_stoich = row.anode_stoich;
P.RH_an_in = row.anode_RH;
P.p_anode_in_kPa = row.anode_pressure_kPa_abs;
P.p_anode_back_kPa = row.anode_outlet_pressure_kPa_g + P.p_amb_kPa;
P.p_cathode_back_kPa = row.cathode_outlet_pressure_kPa_g + P.p_amb_kPa;
P.T_cool_C = row.coolant_inlet_temp_C;
P.coolant_flow_L_min = row.coolant_flow_L_min;
P.intercooler_T_C = row.cathode_inlet_temp_C;
P.EnvParam(6) = max(row.cathode_inlet_temp_C - P.compressor_dT_C, -20);
P.EnvParam(11) = P.oxygen_stoich;
P.IntercoolerParam(5) = P.intercooler_T_C;
dryDp = estimateHumidifierDryDp(P, row.current_A);
P.compressor_dp_kPa = max(row.cathode_pressure_kPa_abs - P.p_amb_kPa + P.intercooler_dp_kPa + dryDp, 1.0);
P = updateModuleParamVectors(P);
P.stack_initial_state_audit = buildStackInitialAudit(P, row.cathode_pressure_kPa_abs, P.p_anode_back_kPa, row.stack_temperature_est_C);
P.wet_initial_node = [0 0 0 0 row.cathode_outlet_temp_C P.p_cathode_back_kPa 0]';
end

function row = runOperatingCase(P, dataRow, model, egrFraction, condition, pO2Ref)
stopTime = 120;
out = runOneSim(P, model, stopTime, egrFraction);
row = parseOutput(out, P, dataRow, model, stopTime, egrFraction, condition, pO2Ref);
if ~row.is_steady
    stopTime = 300;
    out = runOneSim(P, model, stopTime, egrFraction);
    row = parseOutput(out, P, dataRow, model, stopTime, egrFraction, condition, pO2Ref);
end
end

function out = runOneSim(P, model, stopTime, egrFraction)
in = Simulink.SimulationInput(model);
in = in.setModelParameter('StopTime', num2str(stopTime));
in = in.setVariable('EnvParam_v2', P.EnvParam, 'Workspace', model);
in = in.setVariable('CompressorParam_v2', P.CompressorParam, 'Workspace', model);
in = in.setVariable('IntercoolerParam_v2', P.IntercoolerParam, 'Workspace', model);
in = in.setVariable('HumidifierParam_v2', P.HumidifierParam, 'Workspace', model);
in = in.setVariable('StackParam_v2', P.StackParam, 'Workspace', model);
in = in.setVariable('I_stack_cmd_A', P.I_stack_default_A, 'Workspace', model);
in = in.setVariable('egr_fraction_cmd', egrFraction, 'Workspace', model);
in = in.setVariable('stack_initial_state_audit', P.stack_initial_state_audit, 'Workspace', model);
in = in.setVariable('egr_initial_node', P.egr_initial_node, 'Workspace', model);
in = in.setVariable('wet_initial_node', P.wet_initial_node, 'Workspace', model);
simOut = sim(in);
out.summary_vector = simOut.summary_vector;
out.humidifier_dry_node = simOut.humidifier_dry_node;
out.humidifier_wet_node = simOut.humidifier_wet_node;
end

function row = parseOutput(out, P, dataRow, model, stopTime, egrFraction, condition, pO2Ref)
fields = summaryFields();
s = summaryStruct(vectorAt(out.summary_vector, numel(fields), "final"), fields);
dry = nodeStruct(vectorAt(out.humidifier_dry_node, 7, "final"), P);
wet = nodeStruct(vectorAt(out.humidifier_wet_node, 7, "final"), P);
steady = steadyCheck(out, stopTime);

row = struct();
row.case_id = string(dataRow.case_id);
row.condition = string(condition);
row.stop_time_s = stopTime;
row.is_steady = steady.is_steady;
row.egr_ratio_cmd = egrFraction;
row.current_A = dataRow.current_A;
row.current_density_A_cm2 = dataRow.current_A / P.A_cell_cm2;
row.V_cell_meas = dataRow.cell_voltage_from_stack_V;
row.V_cell_sim = s.V_cell;
row.V_cell_err = s.V_cell - dataRow.cell_voltage_from_stack_V;
row.V_stack_sim = P.N_cell * s.V_cell;
row.pO2_ref_no_egr_kPa = pO2Ref;
row.pO2_ca_in_kPa = s.pO2_ca_in_kPa;
row.pH2O_caIn_kPa = dry.pH2O_kPa;
row.RH_ca_in = dry.RH;
row.T_ca_in_C = dry.T_C;
row.T_stack_sim_C = s.T_stack_C;
row.lambda_O2_actual = s.lambda_O2_actual;
row.pressure_order_ok = dry.p_kPa > s.pCa_kPa && s.pCa_kPa > P.p_cathode_back_kPa;
row.p_ca_in_sim_kPa = dry.p_kPa;
row.p_stack_internal_kPa = s.pCa_kPa;
row.p_ca_out_boundary_kPa = P.p_cathode_back_kPa;
row.Q_gen_W = s.Q_gen_W;
row.Q_cool_W = s.Q_cool_W;
row.hum_transfer_kg_s = s.mH2O_hum_transfer_kg_s;
row.RH_hum_wet_out = wet.RH;
row.pH2O_hum_wet_out_kPa = wet.pH2O_kPa;
row.oxygen_stoich_cmd = P.oxygen_stoich;
row.dV_cell_30s = steady.dV_cell;
row.dT_stack_30s_C = steady.dT_stack;
row.dRH_ca_in_30s = steady.dRH_ca_in;
row.model_name = string(model);
end

function lambda = flowDerivedLambda(row, P)
flow_m3_s = row.cathode_flow_nlpm / 60000;
nTotal = flow_m3_s / 0.022414;
nO2 = P.xO2_dry * nTotal;
nO2Need = row.current_A * P.N_cell / (4 * P.F_C_mol);
lambda = nO2 / max(nO2Need, 1e-12);
end

function dryDp = estimateHumidifierDryDp(P, I)
scale = max(I / max(P.I_stack_default_A, 1.0), 0.2);
dryDp = P.hum_dry_dp_ref_kPa * scale ^ P.hum_dp_exp;
end

function P = updateModuleParamVectors(P)
% Keep full vectors from init_vehicle_10kw_gzs60_v3 and only overwrite
% operating-condition entries used by scenario sweeps.
P.EnvParam(11) = P.oxygen_stoich;
P.CompressorParam(1) = P.compressor_dp_kPa;
P.CompressorParam(2) = P.compressor_dT_C;
P.IntercoolerParam(5) = P.intercooler_T_C;
P.IntercoolerParam(6) = P.intercooler_dp_kPa;
P.HumidifierParam(5) = P.intercooler_T_C;
P.StackParam(15) = P.p_cathode_back_kPa;
P.StackParam(16) = P.p_anode_back_kPa;
P.StackParam(20) = P.T_cool_C;
P.StackParam(33) = P.anode_stoich;
P.StackParam(34) = P.RH_an_in;
P.StackParam(37) = P.p_anode_in_kPa;
P.StackParam(44) = P.coolant_flow_L_min;
end

function x0 = buildStackInitialAudit(P, pCaKPa, pAnKPa, T_C)
TK = T_C + 273.15;
pSat = saturationPressureKPa(T_C);
pH2Oca = min(0.60 * pSat, pCaKPa - 1e-6);
pDryCa = max(pCaKPa - pH2Oca, 1e-6);
pO2 = 0.21 * pDryCa;
pN2 = 0.79 * pDryCa;
pH2Oan = min(P.RH_an_in * pSat, pAnKPa - 1e-6);
pH2 = max(pAnKPa - pH2Oan, 1e-6);
x0 = [
    pO2 * 1000 * P.V_ca_m3 * P.M_O2_kg_mol / (P.R_J_molK * TK)
    pN2 * 1000 * P.V_ca_m3 * P.M_N2_kg_mol / (P.R_J_molK * TK)
    pH2Oca * 1000 * P.V_ca_m3 * P.M_H2O_kg_mol / (P.R_J_molK * TK)
    pH2 * 1000 * P.V_an_m3 * P.M_H2_kg_mol / (P.R_J_molK * TK)
    pH2Oan * 1000 * P.V_an_m3 * P.M_H2O_kg_mol / (P.R_J_molK * TK)
    T_C
    ];
end

function fields = summaryFields()
fields = [
    "I_stack_A"
    "V_cell"
    "P_stack_W"
    "pO2_ca_kPa"
    "pCa_kPa"
    "pH2_an_kPa"
    "pAn_kPa"
    "lambda_mem"
    "T_stack_C"
    "xO2_ca"
    "RH_ca"
    "m_membrane_water_kg_s"
    "mO2_react_kg_s"
    "mH2_react_kg_s"
    "mH2O_prod_kg_s"
    "m_ca_out_kg_s"
    "m_an_out_kg_s"
    "energy_residual_W"
    "pO2_ca_in_kPa"
    "xO2_ca_in"
    "RH_ca_in"
    "Q_net_stack_W"
    "res_O2_ca_kg_s"
    "res_N2_ca_kg_s"
    "res_H2Ov_ca_kg_s"
    "res_H2Ol_ca_kg_s"
    "res_H2_an_kg_s"
    "res_H2Ov_an_kg_s"
    "res_H2Ol_an_kg_s"
    "res_membrane_water_pair_kg_s"
    "max_species_residual_kg_s"
    "Q_gen_W"
    "Q_cool_W"
    "Q_amb_W"
    "Q_gas_W"
    "E_rev_V"
    "eta_act_V"
    "eta_ohm_V"
    "eta_con_V"
    "lambda_O2_actual"
    "m_ca_in_actual_kg_s"
    "i_lim_eff_A_cm2"
    "i0_O2_scale"
    "mH2O_ca_in_kg_s"
    "mH2O_ca_out_kg_s"
    "mH2O_an_in_kg_s"
    "mH2O_an_out_kg_s"
    "m_liquid_diag_kg"
    "m_fresh_in_kg_s"
    "m_egr_return_kg_s"
    "m_vent_out_kg_s"
    "p_wet_out_kPa"
    "r_EGR_actual"
    "mH2O_hum_transfer_kg_s"
    "RH_hum_dry_out"
    "RH_hum_wet_out"
    "dp_bp_valve_kPa"
    "dp_hum_dry_kPa"
    "dp_hum_wet_kPa"
    "m_wet_out_kg_s"
    "m_egr_cmd_kg_s"
    "m_vent_cmd_kg_s"
    "p_vent_out_kPa"
    ];
end

function s = summaryStruct(v, fields)
s = struct();
for k = 1:numel(fields)
    s.(fields(k)) = v(k);
end
end

function v = vectorAt(ts, width, mode)
if mode == "final"
    idx = numSamples(ts, width);
else
    idx = 1;
end
v = vectorAtIndex(ts, width, idx);
end

function v = vectorAtIndex(ts, width, idx)
arr = squeeze(signalData(ts));
if isvector(arr)
    arr = arr(:);
    if numel(arr) == width
        v = arr;
    else
        idx = min(max(idx, 1), floor(numel(arr) / width));
        startIdx = (idx - 1) * width + 1;
        v = arr(startIdx:startIdx + width - 1);
    end
    return;
end
if size(arr, 1) == width
    idx = min(max(idx, 1), size(arr, 2));
    v = arr(:, idx);
elseif size(arr, 2) == width
    idx = min(max(idx, 1), size(arr, 1));
    v = arr(idx, :).';
elseif size(arr, 2) == width + 1
    idx = min(max(idx, 1), size(arr, 1));
    v = arr(idx, 2:end).';
else
    error('Signal length mismatch: expected width %d, got size [%s].', width, num2str(size(arr)));
end
end

function n = numSamples(ts, width)
arr = squeeze(signalData(ts));
if isvector(arr)
    n = max(floor(numel(arr) / width), 1);
elseif size(arr, 1) == width
    n = size(arr, 2);
elseif size(arr, 2) == width
    n = size(arr, 1);
elseif size(arr, 2) == width + 1
    n = size(arr, 1);
else
    error('Signal length mismatch: expected width %d, got size [%s].', width, num2str(size(arr)));
end
end

function data = signalData(sig)
if isa(sig, 'timeseries')
    data = sig.Data;
elseif isstruct(sig) && isfield(sig, 'signals') && isfield(sig.signals, 'values')
    data = sig.signals.values;
elseif isstruct(sig) && isfield(sig, 'Data')
    data = sig.Data;
else
    data = sig;
end
end

function steady = steadyCheck(out, stopTime)
fields = summaryFields();
n = numSamples(out.summary_vector, numel(fields));
idxStart = max(1, n - round(30 / max(stopTime / max(n - 1, 1), 0.1)));
vFirst = vectorAtIndex(out.summary_vector, numel(fields), idxStart);
vLast = vectorAtIndex(out.summary_vector, numel(fields), n);
sFirst = summaryStruct(vFirst, fields);
sLast = summaryStruct(vLast, fields);
dryFirst = nodeStruct(vectorAtIndex(out.humidifier_dry_node, 7, idxStart), []);
dryLast = nodeStruct(vectorAtIndex(out.humidifier_dry_node, 7, n), []);
steady.dV_cell = abs(sLast.V_cell - sFirst.V_cell);
steady.dT_stack = abs(sLast.T_stack_C - sFirst.T_stack_C);
steady.dRH_ca_in = abs(dryLast.RH - dryFirst.RH);
steady.is_steady = steady.dV_cell < 0.002 && steady.dT_stack < 0.5 && steady.dRH_ca_in < 0.02;
end

function st = nodeStruct(node, P) %#ok<INUSD>
mO2 = max(node(1), 0);
mN2 = max(node(2), 0);
mWv = max(node(3), 0);
T_C = node(5);
p_kPa = max(node(6), 1e-6);
nO2 = mO2 / 0.031998;
nN2 = mN2 / 0.0280134;
nW = mWv / 0.01801528;
nTot = max(nO2 + nN2 + nW, 1e-12);
st.T_C = T_C;
st.p_kPa = p_kPa;
st.xO2 = nO2 / nTot;
st.xH2O = nW / nTot;
st.pO2_kPa = st.xO2 * p_kPa;
st.pH2O_kPa = st.xH2O * p_kPa;
st.RH = min(max(st.pH2O_kPa / max(saturationPressureKPa(T_C), 1e-6), 0), 2);
st.omega_kgpkg = mWv / max(mO2 + mN2, 1e-12);
end

function p = saturationPressureKPa(T_C)
p = 0.61078 * exp(17.2694 * T_C / (T_C + 237.29));
end

function writeConditionSummary(file, baseline, cv, egr, po2, runMode)
lines = strings(0, 1);
lines(end + 1) = "# Condition Extension Summary";
lines(end + 1) = "";
lines(end + 1) = "Date: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
lines(end + 1) = "Run mode: `" + runMode + "`.";
lines(end + 1) = "";
if ~isempty(baseline)
    lines(end + 1) = "## Frozen No-EGR Baseline";
    lines(end + 1) = sprintf("- points: %d", height(baseline));
    lines(end + 1) = sprintf("- pressure_order_ok: %d/%d", nnz(logical(baseline.pressure_order_ok)), height(baseline));
    lines(end + 1) = sprintf("- V_cell RMSE vs bench: %.4f V/cell", rmse(baseline.V_cell_err));
    lines(end + 1) = sprintf("- T_stack range: %.2f-%.2f C", min(baseline.T_stack_sim_C), max(baseline.T_stack_sim_C));
    lines(end + 1) = sprintf("- pO2_ca_in range: %.2f-%.2f kPa", min(baseline.pO2_ca_in_kPa), max(baseline.pO2_ca_in_kPa));
    lines(end + 1) = sprintf("- min lambda_O2_actual: %.3f", min(baseline.lambda_O2_actual));
    lines(end + 1) = "";
end
if ~isempty(cv)
    lines(end + 1) = "## Constant-Voltage No-EGR Scan";
    lines(end + 1) = sprintf("- target count: %d", height(cv));
    lines(end + 1) = sprintf("- max target error: %.4f V/cell", max(abs(cv.target_error_V)));
    lines(end + 1) = "- This is an operating-condition lookup, not a new baseline fit.";
    lines(end + 1) = "";
end
if ~isempty(egr)
    lines(end + 1) = "## Same-Current EGR Ratio Scan";
    lines(end + 1) = sprintf("- points: %d", height(egr));
    lines(end + 1) = sprintf("- severe oxygen starvation points: %d", nnz(logical(egr.severe_oxygen_starvation)));
    lines(end + 1) = "- EGR results are qualitative trend checks only.";
    lines(end + 1) = "";
end
if ~isempty(po2)
    lines(end + 1) = "## Same-Current Constant-pO2 EGR Scan";
    lines(end + 1) = sprintf("- points: %d", height(po2));
    lines(end + 1) = sprintf("- pO2 target max abs error: %.3f kPa", max(abs(po2.pO2_error_kPa)));
    lines(end + 1) = "- Compressor fresh-air flow is represented by oxygen_stoich tuning in this model version.";
    lines(end + 1) = "";
end
lines(end + 1) = "## Boundary";
lines(end + 1) = "- Frozen no-EGR baseline uses the current pressurefix + thermal Stage A + humidifier-first + bench-voltage-fit parameter set.";
lines(end + 1) = "- EGR ratio is `m_egr / m_humidifier_wet_out`.";
lines(end + 1) = "- If `lambda_O2_actual < 1`, the point is marked as severe oxygen starvation and should not be interpreted as normal stack operation.";
lines(end + 1) = "- For constant-pO2 EGR, the target is the same-current no-EGR `pO2_ca_in_kPa`.";
writeText(file, lines);
end

function writeConditionDoc(file)
lines = [
    "# 下一阶段工况扩展实施说明"
    ""
    "## 冻结策略"
    ""
    "无 EGR 基线不再通过复制多套结构模型来推进。当前结构模型冻结为同一套物理拓扑，后续工况通过 MATLAB 脚本写入电流、回流比、氧计量比等工作点变量。"
    ""
    "推荐保留一个基线模型副本作为回滚证据：`CEGR_Vehicle_10kW_GZS60_v03_noEGR_frozen.slx`。工作模型仍为 `CEGR_Vehicle_10kW_GZS60_v03_stage1_pressurefix.slx`。"
    ""
    "## 工况实现"
    ""
    "- 恒电流无 EGR：按 13 个台架稳态点重放，输出 `no_egr_frozen_baseline_reference.csv`。"
    "- 恒电压无 EGR：以 0.9-0.7 V/cell 为目标，参考最接近的台架电流点，在附近扫电流，选择最接近目标电压的结果。"
    "- 同电流 EGR 循环比扫描：`egr_fraction_cmd = 0, 0.1, 0.2, 0.3, 0.4`，先做定性趋势。"
    "- 同电流恒入口氧分压 EGR：目标取同电流无 EGR 的 `pO2_ca_in_kPa`，通过 `oxygen_stoich` 等效调节空压机新鲜空气流量。"
    ""
    "## 当前限制"
    ""
    "- 当前空压机流量不是独立端口，而是由新鲜空气模块按氧计量比生成；所以恒氧分压第一版是等效调流量。"
    "- EGR 结果只用于趋势，不声称定量预测。"
    "- `lambda_O2_actual < 1` 的点标记为严重缺气，不作为正常电堆工作点解释。"
    ];
writeText(file, lines);
end

function value = rmse(x)
value = sqrt(mean(x .^ 2, 'omitnan'));
end

function writeText(file, lines)
fid = fopen(file, 'w');
if fid < 0
    error('Cannot write %s', file);
end
cleanup = onCleanup(@()fclose(fid));
for k = 1:numel(lines)
    fprintf(fid, '%s\n', lines(k));
end
end
