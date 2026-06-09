function result = plot_testbench_10kw_simplified_egr_diagnostics()
%PLOT_TESTBENCH_10KW_SIMPLIFIED_EGR_DIAGNOSTICS Plot calibration diagnostics.
%
% This script replays the current calibrated model and opens MATLAB figures.
% It does not change parameters and does not save image files. Boundary plots
% check whether measured gas conditions are passed into the model correctly;
% they should not be interpreted as independently fitted predictions.

rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(rootDir, '01_模型'));
vehicleScriptDir = fullfile(fileparts(rootDir), '01_车载系统_10kW_GZS60_v3', '02_脚本');
addpath(vehicleScriptDir);

P0 = init_testbench_10kw_simplified_egr(1, 'noegr', false);
noEgr = replayGroup(P0.noEgrTable.case_index, "noegr");
egr = replayGroup(P0.egrTable.case_index, "egr");

plotBoundaryReplay(noEgr, egr);
plotEgrDiagnostics(egr);
plotNoEgrDiagnostics(noEgr);

result = struct('noegr', noEgr, 'egr', egr);
end

function T = replayGroup(caseIndex, mode)
n = numel(caseIndex);
T = table('Size', [n 29], ...
    'VariableTypes', repmat("double", 1, 29), ...
    'VariableNames', {'case_index','current_A','egr_fraction','V_exp','V_sim','err_V', ...
    'p_in_exp_g_kPa','p_in_model_g_kPa','p_ca_internal_g_kPa','p_out_exp_g_kPa','p_out_model_g_kPa','p_ca_avg_exp_g_kPa', ...
    'T_in_exp_C','T_in_model_C','T_stack_model_C','T_out_exp_C','T_out_model_C', ...
    'flow_in_exp_SLPM','flow_in_model_SLPM','flow_egr_model_SLPM','flow_out_model_SLPM','sep_drain_kg_s', ...
    'RH_in_exp','RH_in_model','RH_out_exp','xO2_in_model','lambdaO2_diag','mIn_over_cmd','max_gas_residual'});

for i = 1:n
    P = init_testbench_10kw_simplified_egr(caseIndex(i), mode, false);
    out = simulateCase(P);
    s = lastVector(out.get('summary_vector'));
    caIn = lastVector(out.get('stack_in_node'));
    caOut = lastVector(out.get('stack_ca_out_node'));

    T.case_index(i) = P.caseIndex;
    T.current_A(i) = P.I_stack_default_A;
    T.egr_fraction(i) = P.egr_fraction_cmd;
    T.V_exp(i) = P.cell_voltage_bench_V;
    T.V_sim(i) = s(2);
    T.err_V(i) = s(2) - P.cell_voltage_bench_V;

    T.p_in_exp_g_kPa(i) = P.bench_stack_in_p_kPa;
    T.p_in_model_g_kPa(i) = caIn(6) - P.p_amb_kPa;
    T.p_ca_internal_g_kPa(i) = s(5) - P.p_amb_kPa;
    T.p_out_exp_g_kPa(i) = P.separator_p_kPa;
    T.p_out_model_g_kPa(i) = caOut(6) - P.p_amb_kPa;
    T.p_ca_avg_exp_g_kPa(i) = 0.5 * (T.p_in_exp_g_kPa(i) + T.p_out_exp_g_kPa(i));

    T.T_in_exp_C(i) = P.bench_stack_in_T_C;
    T.T_in_model_C(i) = caIn(5);
    T.T_stack_model_C(i) = s(9);
    T.T_out_exp_C(i) = P.separator_T_C;
    T.T_out_model_C(i) = caOut(5);

    T.flow_in_exp_SLPM(i) = P.stack_in_flow_SLPM;
    T.flow_in_model_SLPM(i) = kgSToSlpm(s(50));
    T.flow_egr_model_SLPM(i) = kgSToSlpm(s(51));
    T.flow_out_model_SLPM(i) = kgSToSlpm(s(52));
    T.sep_drain_kg_s(i) = s(62);

    T.RH_in_exp(i) = P.bench_stack_in_RH;
    T.RH_in_model(i) = s(21);
    T.xO2_in_model(i) = s(49);
    T.lambdaO2_diag(i) = s(40);
    T.mIn_over_cmd(i) = s(41) / max(s(end - 4), 1e-12);
    T.max_gas_residual(i) = s(31);

    if mode == "egr"
        row = P.egrTable(P.caseIndex, :);
        T.RH_out_exp(i) = row.stack_out_RH;
    else
        T.RH_out_exp(i) = NaN;
    end
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

function plotBoundaryReplay(noEgr, egr)
allCases = [noEgr; egr];
figure('Name', 'Simplified bench boundary replay', 'NumberTitle', 'off');
tiledlayout(2, 2);

nexttile;
scatter(allCases.p_in_exp_g_kPa, allCases.p_in_model_g_kPa, 34, allCases.current_A, 'filled'); hold on;
plotIdentity(allCases.p_in_exp_g_kPa, allCases.p_in_model_g_kPa);
grid on; xlabel('Measured inlet pressure g kPa'); ylabel('Model inlet pressure g kPa'); title('Inlet pressure boundary');

nexttile;
scatter(allCases.T_in_exp_C, allCases.T_in_model_C, 34, allCases.current_A, 'filled'); hold on;
plotIdentity(allCases.T_in_exp_C, allCases.T_in_model_C);
grid on; xlabel('Measured inlet T C'); ylabel('Model inlet T C'); title('Inlet temperature boundary');

nexttile;
scatter(allCases.flow_in_exp_SLPM, allCases.flow_in_model_SLPM, 34, allCases.current_A, 'filled'); hold on;
plotIdentity(allCases.flow_in_exp_SLPM, allCases.flow_in_model_SLPM);
grid on; xlabel('Measured stack inlet flow SLPM'); ylabel('Model inlet flow SLPM'); title('Inlet flow boundary');

nexttile;
scatter(allCases.RH_in_exp, allCases.RH_in_model, 34, allCases.current_A, 'filled'); hold on;
plotIdentity(allCases.RH_in_exp, allCases.RH_in_model);
grid on; xlabel('Measured inlet RH'); ylabel('Model inlet RH'); title('Inlet humidity boundary');
end

function plotEgrDiagnostics(egr)
figure('Name', 'Simplified EGR diagnostics', 'NumberTitle', 'off');
tiledlayout(2, 3);

nexttile;
hold on;
currents = unique(egr.current_A(:)).';
colors = lines(numel(currents));
legendText = strings(0, 1);
for i = 1:numel(currents)
    idx = egr.current_A == currents(i);
    scatter(egr.egr_fraction(idx), egr.V_exp(idx), 38, colors(i, :), 'filled');
    legendText(end + 1, 1) = sprintf('Exp %.0f A', currents(i)); %#ok<AGROW>
    scatter(egr.egr_fraction(idx), egr.V_sim(idx), 38, colors(i, :), 'x');
    legendText(end + 1, 1) = sprintf('Sim %.0f A', currents(i)); %#ok<AGROW>
end
grid on; xlabel('EGR fraction'); ylabel('Cell voltage V'); title('Voltage');
legend(legendText, 'Location', 'best');

nexttile;
scatter(egr.egr_fraction, egr.xO2_in_model, 38, egr.current_A, 'filled');
grid on; xlabel('EGR fraction'); ylabel('O2 mole fraction'); title('Inlet O2 composition');

nexttile;
scatter(egr.egr_fraction, egr.RH_in_model, 38, egr.current_A, 'filled');
grid on; xlabel('EGR fraction'); ylabel('Inlet RH'); title('Inlet humidity');

nexttile;
plot(egr.egr_fraction, egr.flow_in_model_SLPM, 'ko', ...
    egr.egr_fraction, egr.flow_egr_model_SLPM, 'bs', ...
    egr.egr_fraction, egr.flow_out_model_SLPM, 'r^');
grid on; xlabel('EGR fraction'); ylabel('Flow SLPM'); title('Gas flow split');
legend('Stack inlet', 'EGR return', 'Bench outlet', 'Location', 'best');

nexttile;
validP = isfinite(egr.p_out_exp_g_kPa);
scatter(egr.p_out_exp_g_kPa(validP), egr.p_out_model_g_kPa(validP), 38, egr.current_A(validP), 'filled'); hold on;
plotIdentity(egr.p_out_exp_g_kPa(validP), egr.p_out_model_g_kPa(validP));
grid on; xlabel('Measured outlet pressure g kPa'); ylabel('Model outlet pressure g kPa'); title('Outlet pressure boundary');

nexttile;
validT = isfinite(egr.T_out_exp_C);
scatter(egr.T_out_exp_C(validT), egr.T_out_model_C(validT), 38, egr.current_A(validT), 'filled'); hold on;
plotIdentity(egr.T_out_exp_C(validT), egr.T_out_model_C(validT));
grid on; xlabel('Measured outlet T C'); ylabel('Model outlet T C'); title('Outlet temperature boundary');
end

function plotNoEgrDiagnostics(noEgr)
figure('Name', 'Simplified no-EGR internal diagnostics', 'NumberTitle', 'off');
tiledlayout(2, 2);

nexttile;
plot(noEgr.current_A, noEgr.p_in_model_g_kPa, 'ko-', ...
    noEgr.current_A, noEgr.p_out_exp_g_kPa, 'rs-', ...
    noEgr.current_A, noEgr.p_ca_avg_exp_g_kPa, 'k--', ...
    noEgr.current_A, noEgr.p_ca_internal_g_kPa, 'b.-');
grid on; xlabel('Current A'); ylabel('Pressure g kPa'); title('Cathode pressure');
legend('Inlet boundary', 'Outlet boundary', 'Measured average', 'Internal PV=nRT', 'Location', 'best');

nexttile;
plot(noEgr.current_A, noEgr.T_in_model_C, 'ko-', ...
    noEgr.current_A, noEgr.T_stack_model_C, 'r.-', ...
    noEgr.current_A, noEgr.T_out_model_C, 'bs-');
grid on; xlabel('Current A'); ylabel('Temperature C'); title('Temperature response');
legend('Inlet boundary', 'Stack state', 'Outlet gas', 'Location', 'best');

nexttile;
plot(noEgr.current_A, noEgr.xO2_in_model, 'b.-');
grid on; xlabel('Current A'); ylabel('O2 mole fraction'); title('Inlet O2 composition');

nexttile;
plot(noEgr.current_A, noEgr.lambdaO2_diag, 'm.-');
grid on; xlabel('Current A'); ylabel('Diagnostic O2 stoich'); title('O2 stoich from test gas');
end

function v = lastVector(ts)
v = ts.signals.values(:, :, end);
v = v(:);
end

function slpm = kgSToSlpm(m)
slpm = m * 60000 / 1.293;
end

function plotIdentity(x, y)
z = [x(:); y(:)];
z = z(isfinite(z));
if isempty(z)
    return;
end
lo = min(z);
hi = max(z);
if lo == hi
    lo = lo - 1;
    hi = hi + 1;
end
plot([lo hi], [lo hi], 'k--');
end
