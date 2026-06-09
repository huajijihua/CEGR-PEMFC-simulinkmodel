function result = calibrate_testbench_10kw_simplified_egr()
%CALIBRATE_TESTBENCH_10KW_SIMPLIFIED_EGR Refit simplified bench EGR model.
%
% Stage 1 fits the no-EGR polarization curve on the same voltage equation
% used in PEMFCStackCore, then validates with Simulink. Stage 2 keeps the
% no-EGR stack fit fixed and fits an EGR-only empirical mass-transfer loss.
% Calibration uses the measured gas conditions for each test point directly.
% lambdaO2 is a derived diagnostic from those conditions, not a fitted target
% and not a command to replace measured flow with nominal stoichiometry.

rootDir = fileparts(fileparts(mfilename('fullpath')));
paramDir = fullfile(rootDir, '00_输入参数', '标定参数');
if ~isfolder(paramDir)
    mkdir(paramDir);
end

stackFile = fullfile(paramDir, 'simplified_noegr_stack_params.csv');
egrFile = fullfile(paramDir, 'simplified_egr_boundary_params.csv');
if isfile(stackFile), delete(stackFile); end
if isfile(egrFile), delete(egrFile); end

P0 = init_testbench_10kw_simplified_egr(1, 'noegr', false);
noEgr = P0.noEgrTable;
egr = P0.egrTable;
egrTrain = egr(isfinite(egr.cell_voltage_V), :);

fprintf('Stage 1: no-EGR voltage-equation fit using %d points.\n', height(noEgr));
boundarySpec = egrBoundaryDefaultSpec();
caVolumeFit = fitCathodeVolumeScale(noEgr, boundarySpec, egrFile);
boundarySpec.default(boundarySpec.names == "ca_volume_scale") = caVolumeFit.scale;
writeEgrParams(egrFile, boundarySpec, boundarySpec.default);
fprintf('Stage 0 done: ca_volume_scale %.4f, pressure RMSE %.3f kPa.\n', ...
    caVolumeFit.scale, caVolumeFit.rmse_kPa);
baseNoEgr = evaluateNoEgr(noEgr);
stackFit = fitNoEgrVoltageEquation(baseNoEgr, P0);
writeStackParams(stackFile, stackFit.spec, stackFit.values);
writeEgrParams(egrFile, boundarySpec, boundarySpec.default);
fitNoEgr = evaluateNoEgr(noEgr);
fprintf('Stage 1 done: RMSE %.5f V, max abs %.5f V.\n', ...
    rmse(fitNoEgr.err_V), max(abs(fitNoEgr.err_V)));

fprintf('Stage 2: EGR loss fit using %d finite voltage points.\n', height(egrTrain));
baseEgr = evaluateEgr(egrTrain);
egrLossFit = fitEgrLoss(baseEgr);
finalSpec = appendEgrLossSpec(stackFit.spec);
finalValues = [stackFit.values(:); egrLossFit.values(:)];
writeStackParams(stackFile, finalSpec, finalValues);
fitEgr = evaluateEgr(egrTrain);
fprintf('Stage 2 done: RMSE %.5f V, max abs %.5f V.\n', ...
    rmse(fitEgr.err_V), max(abs(fitEgr.err_V)));

fprintf('FINAL_NOEGR_RMSE=%.6f\n', rmse(fitNoEgr.err_V));
fprintf('FINAL_EGR_RMSE=%.6f\n', rmse(fitEgr.err_V));
fprintf('NOEGR_MAX_ABS=%.6f\n', max(abs(fitNoEgr.err_V)));
fprintf('EGR_MAX_ABS=%.6f\n', max(abs(fitEgr.err_V)));

plotCalibration(fitNoEgr, fitEgr);

result = struct();
result.noegr = fitNoEgr;
result.egr = fitEgr;
result.stack_params = table(finalSpec.names(:), finalSpec.stackIndex(:), finalValues(:), ...
    'VariableNames', {'parameter', 'stack_index', 'value'});
result.egr_boundary_params = readtable(egrFile, 'TextType', 'string');
result.ca_volume_fit = caVolumeFit;
end

function spec = baseVoltageSpec(P)
names = ["book_theta1"; "book_theta3"; "book_theta4"; "book_theta9"; "book_theta10"; ...
    "pem_sigma_scale"; "asr0_ohm_cm2"];
idx = [24; 26; 27; 30; 31; 82; 83];
default = P.StackParam(idx);
lower = [-0.40; -1.20e-3; 0.0; 0.0; 0.0; 0.2; 0.0];
upper = [0.80;  2.00e-4; 8.0e-4; 0.35; 2.5e-2; 10.0; 0.25];
default = min(max(default, lower), upper);
spec = struct('names', names, 'stackIndex', idx, ...
    'default', default, 'lower', lower, 'upper', upper);
end

function spec = appendEgrLossSpec(baseSpec)
extra = struct();
extra.names = ["egr_loss_k_V"; "egr_loss_exp"; "egr_loss_rh_V"];
extra.stackIndex = [76; 77; 78];
spec = struct();
spec.names = [baseSpec.names(:); extra.names(:)];
spec.stackIndex = [baseSpec.stackIndex(:); extra.stackIndex(:)];
end

function spec = egrBoundaryDefaultSpec()
names = ["egr_fraction_scale"; "egr_fraction_bias"; "separator_T_offset_C"; ...
    "separator_p_offset_kPa"; "stack_in_flow_scale"; "fresh_supply_flow_scale"; ...
    "ca_out_K_scale"; "ca_volume_scale"];
default = [1.0; 0.0; 0.0; 0.0; 1.0; 1.0; 1.1; 1.0];
spec = struct('names', names, 'default', default);
end

function fit = fitCathodeVolumeScale(noEgr, boundarySpec, egrFile)
scales = [0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0];
score = zeros(size(scales));
rmseVals = zeros(size(scales));
for i = 1:numel(scales)
    [score(i), rmseVals(i)] = pressureObjective(noEgr, boundarySpec, egrFile, scales(i));
end
[~, bestIdx] = min(score);
lo = scales(max(bestIdx - 1, 1));
hi = scales(min(bestIdx + 1, numel(scales)));
if lo == hi
    scale = scales(bestIdx);
else
    scale = fminbnd(@(x) pressureObjective(noEgr, boundarySpec, egrFile, x), lo, hi, ...
        optimset('Display', 'off', 'TolX', 1e-3));
end
[~, rmseBest, detail] = pressureObjective(noEgr, boundarySpec, egrFile, scale);
fit = struct('scale', scale, 'rmse_kPa', rmseBest, 'detail', detail);
end

function [score, rmseVal, detail] = pressureObjective(noEgr, boundarySpec, egrFile, scale)
scale = min(max(scale, 0.25), 5.0);
values = boundarySpec.default;
values(boundarySpec.names == "ca_volume_scale") = scale;
writeEgrParams(egrFile, boundarySpec, values);
n = height(noEgr);
pInternal = zeros(n, 1);
pAvg = 0.5 * (noEgr.cathode_in_p_g_kPa + noEgr.cathode_out_p_g_kPa);
for k = 1:n
    P = init_testbench_10kw_simplified_egr(noEgr.case_index(k), 'noegr', false);
    out = simulateCase(P);
    s = lastVector(out.get('summary_vector'));
    pInternal(k) = s(5) - P.p_amb_kPa;
end
err = pInternal - pAvg;
weights = max(noEgr.current_A / max(noEgr.current_A), 0.25);
score = mean(weights .* err.^2);
rmseVal = rmse(err);
detail = table(noEgr.case_index, noEgr.current_A, noEgr.cathode_in_p_g_kPa, ...
    noEgr.cathode_out_p_g_kPa, pAvg, pInternal, err, ...
    'VariableNames', {'case_index','current_A','p_in_g_kPa','p_out_g_kPa', ...
    'p_avg_g_kPa','p_internal_g_kPa','err_kPa'});
end

function fit = fitNoEgrVoltageEquation(simFit, P)
spec = baseVoltageSpec(P);
I = simFit.current_A;
TK = simFit.T_stack_C + 273.15;
E = simFit.E_Nernst_V;
CO2 = max(simFit.i0Scale, 1e-12);
Vexp = simFit.V_exp;
th2 = P.StackParam(25);
deltaCm = P.StackParam(28);
lambdaMem = simFit.lambdaMem;
sigmaBase = max(0.005193 .* lambdaMem - 0.00326, 1e-6) .* ...
    exp(1268 .* (1 / 303.15 - 1 ./ TK));
j = I ./ P.StackParam(10);

    function V = predict(theta)
        theta = min(max(theta(:), spec.lower), spec.upper);
        etaAct = max(theta(1) + th2 .* TK + theta(2) .* TK .* log(CO2) + ...
            theta(3) .* TK .* log(max(I, 1e-6)), 0);
        etaOhm = j .* (deltaCm ./ max(theta(6) .* sigmaBase, 1e-9) + theta(7));
        etaCon = max(theta(4) .* exp(min(theta(5) .* I, 50)), 0);
        V = E - etaAct - etaOhm - etaCon;
    end

    function f = objective(z)
        theta = boundedFromUnit(z, spec.lower, spec.upper);
        err = predict(theta) - Vexp;
        f = mean(err.^2) + 5e-4 * theta(5)^2;
    end

z0 = unitFromBounded(spec.default, spec.lower, spec.upper);
opts = optimset('Display', 'off', 'MaxIter', 3000, 'MaxFunEvals', 12000, ...
    'TolX', 1e-10, 'TolFun', 1e-12);
z = fminsearch(@objective, z0, opts);
values = boundedFromUnit(z, spec.lower, spec.upper);
fit = struct('spec', spec, 'values', values);
fprintf('Stage 1 analytic RMSE %.5f V before Simulink replay.\n', ...
    rmse(predict(values) - Vexp));
end

function fit = fitEgrLoss(simFit)
lossNeeded = simFit.V_sim - simFit.V_exp;
fEgr = max(simFit.egr_fraction_used, 0);
rhExcess = max(simFit.RHIn - 0.8, 0) .* fEgr;
X = [fEgr, rhExcess];
valid = all(isfinite(X), 2) & isfinite(lossNeeded) & lossNeeded > -0.03;
if nnz(valid) < 2 || max(fEgr(valid)) <= 0
    k = [0; 0];
else
    y = max(lossNeeded(valid), 0);
    Xv = X(valid, :);
    k = (Xv' * Xv + 1e-8 * eye(2)) \ (Xv' * y);
    k = max(k, 0);
end
fit.values = [min(k(1), 0.60); 1.0; min(k(2), 0.60)];
fprintf('Stage 2 fitted egr_loss_k_V %.5f, egr_loss_exp %.3f, egr_loss_rh_V %.5f.\n', ...
    fit.values(1), fit.values(2), fit.values(3));
end

function fit = evaluateNoEgr(data)
n = height(data);
fit = table('Size', [n 18], 'VariableTypes', repmat("double", 1, 18), ...
    'VariableNames', {'case_index','current_A','egr_fraction','V_exp','V_sim','err_V', ...
    'xO2In','RHIn','lambdaO2','pCa_kPa','T_stack_C','E_Nernst_V','etaAct_V', ...
    'etaOhm_V','etaCon_V','i0Scale','lambdaMem','max_gas_residual'});
for k = 1:n
    P = init_testbench_10kw_simplified_egr(data.case_index(k), 'noegr', false);
    out = simulateCase(P);
    s = lastVector(out.get('summary_vector'));
    fit.case_index(k) = data.case_index(k);
    fit.current_A(k) = P.I_stack_default_A;
    fit.egr_fraction(k) = P.egr_fraction_cmd;
    fit = fillCommonFit(fit, k, s, P);
end
assert(any(abs(fit.V_exp) > 0) && any(abs(fit.V_sim) > 0), ...
    'CEGR:SimplifiedCalibration:InvalidNoEgrFit', 'No-EGR fit table was not populated.');
end

function fit = evaluateEgr(data)
n = height(data);
fit = table('Size', [n 19], 'VariableTypes', repmat("double", 1, 19), ...
    'VariableNames', {'case_index','current_A','egr_fraction_raw','egr_fraction_used','V_exp','V_sim','err_V', ...
    'xO2In','RHIn','lambdaO2','mIn_kg_s','mEgr_kg_s','mBenchOut_kg_s','sepDrain_kg_s', ...
    'E_Nernst_V','etaAct_V','etaOhm_V','etaCon_V','max_gas_residual'});
for k = 1:n
    P = init_testbench_10kw_simplified_egr(data.case_index(k), 'egr', false);
    out = simulateCase(P);
    s = lastVector(out.get('summary_vector'));
    fit.case_index(k) = data.case_index(k);
    fit.current_A(k) = P.I_stack_default_A;
    fit.egr_fraction_raw(k) = P.egr_fraction_cmd_raw;
    fit.egr_fraction_used(k) = P.egr_fraction_cmd;
    fit = fillCommonFit(fit, k, s, P);
    fit.mIn_kg_s(k) = s(50);
    fit.mEgr_kg_s(k) = s(51);
    fit.mBenchOut_kg_s(k) = s(52);
    fit.sepDrain_kg_s(k) = s(62);
end
assert(any(abs(fit.V_exp) > 0) && any(abs(fit.V_sim) > 0), ...
    'CEGR:SimplifiedCalibration:InvalidEgrFit', 'EGR fit table was not populated.');
end

function fit = fillCommonFit(fit, k, s, P)
fit.V_exp(k) = P.cell_voltage_bench_V;
fit.V_sim(k) = s(2);
fit.err_V(k) = s(2) - P.cell_voltage_bench_V;
fit.xO2In(k) = s(49);
fit.RHIn(k) = s(21);
fit.lambdaO2(k) = s(40);
fit.E_Nernst_V(k) = s(36);
fit.etaAct_V(k) = s(37);
fit.etaOhm_V(k) = s(38);
fit.etaCon_V(k) = s(39);
fit.max_gas_residual(k) = s(31);
if ismember('pCa_kPa', fit.Properties.VariableNames)
    fit.pCa_kPa(k) = s(5);
    fit.T_stack_C(k) = s(9);
    fit.i0Scale(k) = s(43);
    fit.lambdaMem(k) = s(8);
end
end

function out = simulateCase(P)
in = Simulink.SimulationInput(P.modelName);
in = in.setModelParameter('StopTime', num2str(P.stopTime_s), ...
    'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', num2str(P.dt_s));
in = in.setVariable('BenchBoundaryParam_simplified', P.BenchBoundaryParam);
in = in.setVariable('EgrSplitParam_simplified', P.EgrSplitParam);
in = in.setVariable('StackParam_simplified', P.StackParam);
in = in.setVariable('I_stack_cmd_A_simplified', P.I_stack_default_A);
in = in.setVariable('StackInitialState_simplified', P.stack_initial_state);
in = in.setVariable('EGRInitialNode_simplified', P.egr_initial_node);
out = sim(in);
end

function z = unitFromBounded(x, lb, ub)
x = min(max(x(:), lb(:) + 1e-12), ub(:) - 1e-12);
r = (x - lb(:)) ./ max(ub(:) - lb(:), 1e-12);
z = log(r ./ max(1 - r, 1e-12));
end

function x = boundedFromUnit(z, lb, ub)
r = 1 ./ (1 + exp(-z(:)));
x = lb(:) + r .* (ub(:) - lb(:));
end

function v = lastVector(ts)
v = ts.signals.values(:, :, end);
v = v(:);
end

function writeStackParams(filePath, spec, values)
folder = fileparts(filePath);
if ~isfolder(folder), mkdir(folder); end
T = table(spec.names(:), spec.stackIndex(:), values(:), ...
    'VariableNames', {'parameter', 'stack_index', 'value'});
writetable(T, filePath);
end

function writeEgrParams(filePath, spec, values)
folder = fileparts(filePath);
if ~isfolder(folder), mkdir(folder); end
T = table(spec.names(:), values(:), 'VariableNames', {'parameter', 'value'});
writetable(T, filePath);
end

function y = rmse(x)
x = x(isfinite(x));
y = sqrt(mean(x.^2));
end

function plotCalibration(noEgrFit, egrFit)
figure('Name', 'Simplified bench calibration', 'NumberTitle', 'off');
tiledlayout(2, 2);

nexttile;
plot(noEgrFit.current_A, noEgrFit.V_exp, 'ko', noEgrFit.current_A, noEgrFit.V_sim, 'b.-');
grid on; xlabel('Current A'); ylabel('Cell voltage V'); title('No-EGR polarization');
legend('Experiment', 'Simulation', 'Location', 'best');

nexttile;
plot(noEgrFit.current_A, noEgrFit.err_V, 'r.-');
grid on; xlabel('Current A'); ylabel('Sim - Exp V'); title('No-EGR residual');

nexttile;
hold on;
currents = unique(egrFit.current_A(:)).';
colors = lines(numel(currents));
legendText = strings(0, 1);
for i = 1:numel(currents)
    idx = egrFit.current_A == currents(i);
    scatter(egrFit.egr_fraction_used(idx), egrFit.V_exp(idx), 42, colors(i, :), 'filled');
    legendText(end + 1, 1) = sprintf('Exp %.0f A', currents(i)); %#ok<AGROW>
    scatter(egrFit.egr_fraction_used(idx), egrFit.V_sim(idx), 42, colors(i, :), 'x');
    legendText(end + 1, 1) = sprintf('Sim %.0f A', currents(i)); %#ok<AGROW>
end
grid on; xlabel('EGR fraction'); ylabel('Cell voltage V'); title('EGR voltage by measured point');
legend(legendText, 'Location', 'best');

nexttile;
hold on;
for i = 1:numel(currents)
    idx = egrFit.current_A == currents(i);
    scatter(egrFit.egr_fraction_used(idx), egrFit.xO2In(idx), 42, colors(i, :), 'filled');
end
grid on; xlabel('EGR fraction'); ylabel('Inlet O2 mole fraction'); title('EGR inlet oxygen dilution');
legend(compose('%.0f A', currents), 'Location', 'best');
end
