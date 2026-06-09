function freezeAudit = run_model_freeze_audit_v01()
%RUN_MODEL_FREEZE_AUDIT_V01 Pre-fit freeze audit for the simplified CEGR bench model.
%
% This script does not change the model or fit parameters. It checks whether
% the current v02 audit artifacts are consistent enough to start staged
% no-EGR / CEGR calibration.

rootDir = fileparts(fileparts(mfilename('fullpath')));
dataFile = fullfile(rootDir, '00_输入参数', '实验数据', 'combined_noegr_cegr_fit_points.csv');
resultDir = fullfile(rootDir, '04_验证结果');
auditFile = fullfile(resultDir, 'core_fix_v02_audit.csv');
detailFile = fullfile(resultDir, 'core_fix_v02_detailed_variable_audit.csv');
interfaceFile = fullfile(resultDir, 'core_fix_v02_interface_consistency.csv');

if ~isfolder(resultDir)
    mkdir(resultDir);
end

requireFile(dataFile);
requireFile(auditFile);
requireFile(detailFile);
requireFile(interfaceFile);

cases = readtable(dataFile, 'TextType', 'string');
audit = readtable(auditFile, 'TextType', 'string');
detail = readtable(detailFile, 'TextType', 'string');
interfaces = readtable(interfaceFile, 'TextType', 'string');
P0 = init_testbench_10kw_simplified_egr(1, 'all', false);
coeffAudit = collectFlowCoefficientAudit(P0);

freezeAudit = emptyFreezeAudit();

freezeAudit = addCheck(freezeAudit, "data_case_count", "data", "blocker", ...
    height(cases) == 29 && height(audit) == 29, height(audit), 29, ...
    "Unified case table and v02 audit should both contain 29 cases.");

initialNoegrCount = sum(cases.source_dataset == "initial_noegr_steady_xlsx");
cegr0608Count = sum(cases.source_dataset == "cegr_0608_txt");
freezeAudit = addCheck(freezeAudit, "data_noegr_case_count", "data", "blocker", ...
    initialNoegrCount == 13, initialNoegrCount, 13, ...
    "Initial no-EGR baseline should contain 13 steady points.");
freezeAudit = addCheck(freezeAudit, "data_cegr_case_count", "data", "blocker", ...
    cegr0608Count == 16, cegr0608Count, 16, "CEGR0608 set should contain 16 points.");

requiredVars = ["current_A", "cell_voltage_V", "stack_in_flow_meter_SLPM", ...
    "bench_supply_flow_SLPM", "stack_in_p_kPa", "stack_in_T_C", "stack_in_RH_pct"];
missingRequired = missingRequiredValues(cases, requiredVars);
freezeAudit = addCheck(freezeAudit, "data_required_fields_present", "data", "blocker", ...
    missingRequired == 0, missingRequired, 0, ...
    "Required current, voltage, cathode inlet flow, inlet pressure, temperature and RH fields should be present.");

pressureVars = ["stack_out_p_kPa", "cathode_dp_kPa"];
missingPressure = missingRequiredValues(cases, pressureVars);
freezeAudit = addCheck(freezeAudit, "data_outlet_pressure_fields_present", "data", "warn", ...
    missingPressure == 0, missingPressure, 0, ...
    "Outlet pressure and cathode dp are important fitting targets; missing 20 A values can be filled or excluded from pressure fitting.");

okRows = audit.status == "ok";
freezeAudit = addCheck(freezeAudit, "simulation_success_all_cases", "simulation", "blocker", ...
    all(okRows) && height(audit) == 29, sum(okRows), height(audit), ...
    "All cases should complete simulation before fitting.");

badFinite = countNonFinite(audit, ["V_sim", "pO2_stack_kPa", "pCa_stack_kPa_abs", ...
    "pH2_stack_kPa", "pAn_stack_kPa_abs", "xO2_in", "RH_in", "lambdaO2", ...
    "mMem_kg_s", "maxGasRes_kg_s"]);
freezeAudit = addCheck(freezeAudit, "simulation_key_outputs_finite", "simulation", "blocker", ...
    badFinite == 0, badFinite, 0, "Key simulated outputs should be finite.");

freezeAudit = addCheck(freezeAudit, "flow_coefficients_not_overwritten_per_case", "flow_coeff", "blocker", ...
    coeffAudit.unique_count_max == 1, coeffAudit.unique_count_max, 1, ...
    "K_ca_in, K_ca_out and K_an_out should remain global coefficients, not per-case back-calculated values.");

freezeAudit = addCheck(freezeAudit, "flow_coefficients_positive", "flow_coeff", "blocker", ...
    coeffAudit.min_value > 0, coeffAudit.min_value, 0, ...
    "Pressure-flow coefficients used by the stack should be positive.");

freezeAudit = addCheck(freezeAudit, "anode_inlet_pressure_flow_mode_present", "flow_coeff", "warn", ...
    false, 0, 1, ...
    "Current stack core has no K_an_in; anode inlet is set by anode stoichiometry, not linear pressure-flow.");

dpIdx = isfinite(cases.stack_in_p_kPa) & isfinite(cases.stack_out_p_kPa) & isfinite(cases.cathode_dp_kPa);
dpErr = abs(cases.stack_in_p_kPa(dpIdx) - cases.stack_out_p_kPa(dpIdx) - cases.cathode_dp_kPa(dpIdx));
freezeAudit = addCheck(freezeAudit, "data_cathode_dp_matches_in_minus_out", "pressure", "blocker", ...
    max(dpErr, [], 'omitnan') <= 1e-6, max(dpErr, [], 'omitnan'), 1e-6, ...
    "Measured cathode pressure drop should equal inlet gauge pressure minus outlet gauge pressure.");

inAbs = audit.stack_in_p_kPa_g + 101.325;
outAbs = audit.stack_out_p_kPa_g + 101.325;
stackP = audit.pCa_stack_kPa_abs;
outsideBand = max([outAbs - stackP, stackP - inAbs], [], 2);
maxOutside = max(outsideBand, [], 'omitnan');
freezeAudit = addCheck(freezeAudit, "stack_pressure_between_inlet_and_outlet", "pressure", "warn", ...
    maxOutside <= 3.0, maxOutside, 3.0, ...
    "Stack cathode gas pressure should stay close to the measured inlet/outlet pressure band.");

noegrAudit = audit(audit.source_dataset == "initial_noegr_steady_xlsx", :);
noegrFlowDiff = abs(noegrAudit.stack_in_flow_SLPM - noegrAudit.fresh_supply_flow_SLPM);
freezeAudit = addCheck(freezeAudit, "noegr_stack_flow_equals_fresh_flow", "flow", "blocker", ...
    max(noegrFlowDiff, [], 'omitnan') <= 1e-9, max(noegrFlowDiff, [], 'omitnan'), 1e-9, ...
    "No-EGR direct bench-to-stack flow should use measured stack inlet flow as fresh flow.");

cegrAudit = audit(audit.egr_fraction > 0, :);
cegrFlowSlack = cegrAudit.stack_in_flow_SLPM - cegrAudit.fresh_supply_flow_SLPM;
freezeAudit = addCheck(freezeAudit, "cegr_stack_flow_not_below_fresh_flow", "flow", "blocker", ...
    min(cegrFlowSlack, [], 'omitnan') >= -1e-6, min(cegrFlowSlack, [], 'omitnan'), 0, ...
    "CEGR stack inlet flow should not be lower than fresh bench supply flow.");

lambdaO2Min = min(audit.lambdaO2, [], 'omitnan');
freezeAudit = addCheck(freezeAudit, "oxygen_excess_not_depleted", "oxygen", "blocker", ...
    lambdaO2Min > 1.0, lambdaO2Min, 1.0, ...
    "Actual oxygen excess should remain above one; zero values indicate inlet-flow gating or variable handoff problems.");

mInRows = detail(detail.module == "stack_summary" & detail.variable == "mIn_kg_s", :);
targetFlow = audit(:, ["case_id", "mIn_kg_s"]);
mInRows = outerjoin(mInRows, targetFlow, 'Keys', 'case_id', 'MergeKeys', true, ...
    'LeftVariables', {'case_id','last_window_min','last_window_max','last_window_range'}, ...
    'RightVariables', {'mIn_kg_s'});
mInRelativeRange = mInRows.last_window_range ./ max(abs(mInRows.mIn_kg_s), 1e-12);
maxMInRelativeRange = max(mInRelativeRange, [], 'omitnan');
freezeAudit = addCheck(freezeAudit, "actual_stack_inlet_flow_stable", "flow", "blocker", ...
    maxMInRelativeRange <= 0.02, maxMInRelativeRange, 0.02, ...
    "Actual stack inlet mass flow should not pulse between zero and target flow in the final window.");

cegrXcorr = pearsonSafe(cegrAudit.egr_fraction, cegrAudit.xO2_in);
freezeAudit = addCheck(freezeAudit, "cegr_xO2_decreases_with_egr", "oxygen", "warn", ...
    cegrXcorr < 0, cegrXcorr, 0, ...
    "Inlet oxygen mole fraction should generally decrease as CEGR fraction increases.");

gasResidualMax = max(abs(audit.maxGasRes_kg_s), [], 'omitnan');
freezeAudit = addCheck(freezeAudit, "gas_mass_residual_small", "conservation", "blocker", ...
    gasResidualMax <= 1e-10, gasResidualMax, 1e-10, ...
    "O2/N2/H2/H2O gas residuals should be near numerical roundoff.");

failedInterfaceCount = sum(~interfaces.pass);
freezeAudit = addCheck(freezeAudit, "interface_consistency_all_pass", "interface", "blocker", ...
    failedInterfaceCount == 0, failedInterfaceCount, 0, ...
    "Detailed interface consistency checks should all pass.");

voltageClosure = audit.E_Nernst_V - audit.etaAct_V - audit.etaOhm_V - audit.etaCon_V - audit.V_sim;
maxVoltageClosure = max(abs(voltageClosure), [], 'omitnan');
freezeAudit = addCheck(freezeAudit, "voltage_decomposition_closure", "voltage", "blocker", ...
    maxVoltageClosure <= 1e-9, maxVoltageClosure, 1e-9, ...
    "V_sim should equal E_Nernst - etaAct - etaOhm - etaCon.");

mMemRows = detail(detail.module == "stack_summary" & detail.variable == "mMem_kg_s", :);
mMemSignChanges = sum(mMemRows.sign_changes_last_window > 0);
freezeAudit = addCheck(freezeAudit, "membrane_mmem_no_last_window_sign_flip", "membrane", "blocker", ...
    mMemSignChanges == 0, mMemSignChanges, 0, ...
    "mMem should not flip sign in the final audit window.");

aLimitedBad = sum(audit.aCa_limited < -1e-12 | audit.aCa_limited > 1 + 1e-12 | ...
    audit.aAn_limited < -1e-12 | audit.aAn_limited > 1 + 1e-12 | ...
    audit.a_memb < -1e-12 | audit.a_memb > 1 + 1e-12);
freezeAudit = addCheck(freezeAudit, "water_activity_limited_range", "membrane", "blocker", ...
    aLimitedBad == 0, aLimitedBad, 0, ...
    "Limited cathode/anode/membrane water activities should stay within [0,1].");

mMemLimitMax = max(abs(audit.mMem_limit_delta_kg_s), [], 'omitnan');
freezeAudit = addCheck(freezeAudit, "membrane_inventory_limiter_inactive_at_final", "membrane", "warn", ...
    mMemLimitMax <= 1e-12, mMemLimitMax, 1e-12, ...
    "Final mMem should not be dominated by inventory clipping.");

noegrDpCorr = pearsonSafe(noegrAudit.current_A, noegrAudit.cathode_dp_kPa);
freezeAudit = addCheck(freezeAudit, "noegr_dp_increases_with_current", "pressure", "warn", ...
    noegrDpCorr > 0.5, noegrDpCorr, 0.5, ...
    "Initial no-EGR measured cathode pressure drop should increase with current before fitting pressure-flow parameters.");

rmseNoegr = rmse(audit.err_V(audit.egr_fraction == 0));
rmseCegr = rmse(audit.err_V(audit.egr_fraction > 0));
freezeAudit = addCheck(freezeAudit, "voltage_prefit_noegr_rmse_record", "voltage", "info", ...
    true, rmseNoegr, NaN, "Recorded no-EGR voltage RMSE before calibration.");
freezeAudit = addCheck(freezeAudit, "voltage_prefit_cegr_rmse_record", "voltage", "info", ...
    true, rmseCegr, NaN, "Recorded CEGR voltage RMSE before calibration.");

freezeAudit.recommendation = recommendationColumn(freezeAudit);

csvFile = fullfile(resultDir, 'model_freeze_audit_v01.csv');
summaryFile = fullfile(resultDir, 'model_freeze_audit_v01_summary.md');
coeffFile = fullfile(resultDir, 'model_freeze_flow_coefficients_v01.csv');
writetable(freezeAudit, csvFile);
writetable(coeffAudit.by_case, coeffFile);
writeSummary(summaryFile, freezeAudit, audit, cases, coeffAudit);
fprintf('Wrote %s\n', csvFile);
fprintf('Wrote %s\n', coeffFile);
fprintf('Wrote %s\n', summaryFile);
end

function requireFile(path)
if ~isfile(path)
    error('ModelFreezeAudit:MissingFile', 'Missing required file: %s', path);
end
end

function t = emptyFreezeAudit()
t = table('Size', [0, 9], ...
    'VariableTypes', {'string','string','string','string','logical','double','double','string','string'}, ...
    'VariableNames', {'check_id','category','severity','status','pass','value','threshold','detail','recommendation'});
end

function t = addCheck(t, checkId, category, severity, pass, value, threshold, detail)
if pass
    status = "pass";
elseif severity == "blocker"
    status = "block";
elseif severity == "warn"
    status = "warn";
else
    status = "info";
end
newRow = table(string(checkId), string(category), string(severity), string(status), ...
    logical(pass), double(value), double(threshold), string(detail), "", ...
    'VariableNames', t.Properties.VariableNames);
t = [t; newRow];
end

function n = missingRequiredValues(T, vars)
n = 0;
for k = 1:numel(vars)
    v = T.(vars(k));
    if isnumeric(v)
        n = n + sum(~isfinite(v));
    else
        n = n + sum(strlength(string(v)) == 0 | ismissing(string(v)));
    end
end
end

function n = countNonFinite(T, vars)
n = 0;
for k = 1:numel(vars)
    v = T.(vars(k));
    n = n + sum(~isfinite(v));
end
end

function r = pearsonSafe(x, y)
x = double(x);
y = double(y);
idx = isfinite(x) & isfinite(y);
if nnz(idx) < 3 || std(x(idx)) == 0 || std(y(idx)) == 0
    r = NaN;
    return;
end
c = corrcoef(x(idx), y(idx));
r = c(1, 2);
end

function v = rmse(x)
x = double(x);
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = sqrt(mean(x.^2));
end
end

function coeffAudit = collectFlowCoefficientAudit(P0)
n = height(P0.allCaseTable);
caseId = strings(n, 1);
sourceDataset = strings(n, 1);
KCaIn = zeros(n, 1);
KCaOut = zeros(n, 1);
KAnOut = zeros(n, 1);
pAnInAbs = zeros(n, 1);
pAnOutAbs = zeros(n, 1);
anodeStoich = zeros(n, 1);
for k = 1:n
    P = init_testbench_10kw_simplified_egr(k, 'all', false);
    caseId(k) = string(P.case_id);
    sourceDataset(k) = string(P.source_dataset);
    KCaIn(k) = P.StackParam(38);
    KCaOut(k) = P.StackParam(13);
    KAnOut(k) = P.StackParam(14);
    pAnInAbs(k) = P.StackParam(37);
    pAnOutAbs(k) = P.StackParam(16);
    anodeStoich(k) = P.StackParam(33);
end
coeffAudit.by_case = table(caseId, sourceDataset, KCaIn, KCaOut, KAnOut, ...
    pAnInAbs, pAnOutAbs, anodeStoich, ...
    'VariableNames', {'case_id','source_dataset','K_ca_in_kg_s_kPa', ...
    'K_ca_out_kg_s_kPa','K_an_out_kg_s_kPa','p_anode_in_abs_kPa', ...
    'p_anode_out_abs_kPa','anode_stoich'});
coeffAudit.unique_count_max = max([numel(unique(KCaIn)); numel(unique(KCaOut)); numel(unique(KAnOut))]);
coeffAudit.min_value = min([KCaIn; KCaOut; KAnOut]);
coeffAudit.K_ca_in = KCaIn(1);
coeffAudit.K_ca_out = KCaOut(1);
coeffAudit.K_an_out = KAnOut(1);
coeffAudit.has_K_an_in = false;
end

function out = recommendationColumn(T)
out = strings(height(T), 1);
for k = 1:height(T)
    if T.status(k) == "block"
        out(k) = "Fix before calibration.";
    elseif T.status(k) == "warn"
        out(k) = "Review during staged calibration.";
    elseif T.status(k) == "info"
        out(k) = "Record only.";
    else
        out(k) = "OK.";
    end
end
end

function writeSummary(path, freezeAudit, audit, cases, coeffAudit)
fid = fopen(path, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Model Freeze Audit v01 Summary\n\n');
fprintf(fid, 'This audit checks whether the current simplified 10 kW PEMFC/CEGR model is ready for staged no-EGR and CEGR calibration. It does not fit parameters or modify the model.\n\n');
fprintf(fid, '## Case Set\n\n');
fprintf(fid, '- Unified cases: %d\n', height(cases));
fprintf(fid, '- Initial no-EGR cases: %d\n', sum(cases.source_dataset == "initial_noegr_steady_xlsx"));
fprintf(fid, '- CEGR0608 cases: %d\n', sum(cases.source_dataset == "cegr_0608_txt"));
fprintf(fid, '- EGR fraction equals zero cases: %d\n', sum(cases.is_no_egr == 1));
fprintf(fid, '- Positive EGR fraction cases: %d\n', sum(cases.is_no_egr == 0));
fprintf(fid, '- Successful v02 simulations: %d / %d\n\n', sum(audit.status == "ok"), height(audit));

blockers = freezeAudit(freezeAudit.status == "block", :);
warnings = freezeAudit(freezeAudit.status == "warn", :);
fprintf(fid, '## Gate Result\n\n');
if isempty(blockers)
    fprintf(fid, '- Result: PASS WITH WARNINGS\n');
    fprintf(fid, '- Interpretation: model equations and variable handoff are sufficiently frozen to start no-EGR baseline calibration, while warnings should be tracked and not hidden by free fitting parameters.\n\n');
else
    fprintf(fid, '- Result: BLOCKED\n');
    fprintf(fid, '- Interpretation: fix blocker items before any voltage or CEGR parameter fitting.\n\n');
end
fprintf(fid, '- Blocker count: %d\n', height(blockers));
fprintf(fid, '- Warning count: %d\n\n', height(warnings));

fprintf(fid, '## Blockers\n\n');
if isempty(blockers)
    fprintf(fid, '- None.\n\n');
else
    for k = 1:height(blockers)
        fprintf(fid, '- `%s`: value %.6g, threshold %.6g. %s\n', ...
            blockers.check_id(k), blockers.value(k), blockers.threshold(k), blockers.detail(k));
    end
    fprintf(fid, '\n');
end

fprintf(fid, '## Warnings\n\n');
if isempty(warnings)
    fprintf(fid, '- None.\n\n');
else
    for k = 1:height(warnings)
        fprintf(fid, '- `%s`: value %.6g, threshold %.6g. %s\n', ...
            warnings.check_id(k), warnings.value(k), warnings.threshold(k), warnings.detail(k));
    end
    fprintf(fid, '\n');
end

fprintf(fid, '## Flow Coefficient Audit\n\n');
fprintf(fid, '- K_ca_in: %.6g kg/s/kPa, StackParam(38), used as `mInPressure = KcaIn * max(p_in - p_ca, 0)`.\n', coeffAudit.K_ca_in);
fprintf(fid, '- K_ca_out: %.6g kg/s/kPa, StackParam(13), used as cathode outlet pressure-flow coefficient.\n', coeffAudit.K_ca_out);
fprintf(fid, '- K_an_out: %.6g kg/s/kPa, StackParam(14), used as anode outlet pressure-flow coefficient.\n', coeffAudit.K_an_out);
fprintf(fid, '- K_an_in: not present in the current stack core; anode inlet hydrogen is calculated from anode stoichiometry and Faraday consumption.\n\n');

fprintf(fid, '## Calibration Start Order\n\n');
fprintf(fid, '1. Freeze current mass, pressure, water and voltage decomposition equations.\n');
fprintf(fid, '2. Fit no-EGR baseline first: pressure-flow, thermal balance and base voltage parameters.\n');
fprintf(fid, '3. Use CEGR cases after the no-EGR baseline is fixed or weakly adjusted.\n');
fprintf(fid, '4. Do not use direct EGR voltage penalty or free membrane scaling to hide boundary-condition or water-management errors.\n\n');

fprintf(fid, '## Key Recorded Metrics\n\n');
fprintf(fid, '- No-EGR voltage RMSE before calibration: %.6g V\n', rmse(audit.err_V(audit.egr_fraction == 0)));
fprintf(fid, '- CEGR voltage RMSE before calibration: %.6g V\n', rmse(audit.err_V(audit.egr_fraction > 0)));
fprintf(fid, '- Minimum oxygen excess ratio: %.6g\n', min(audit.lambdaO2, [], 'omitnan'));
fprintf(fid, '- Maximum gas residual: %.6g kg/s\n', max(abs(audit.maxGasRes_kg_s), [], 'omitnan'));
fprintf(fid, '- Maximum final mMem limiter delta: %.6g kg/s\n', max(abs(audit.mMem_limit_delta_kg_s), [], 'omitnan'));
end
