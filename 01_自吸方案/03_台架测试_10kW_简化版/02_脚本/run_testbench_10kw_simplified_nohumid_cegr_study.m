function result = run_testbench_10kw_simplified_nohumid_cegr_study(varargin)
%RUN_TESTBENCH_10KW_SIMPLIFIED_NOHUMID_CEGR_STUDY Study no-humidifier CEGR cases.
%
% The study mode keeps stack inlet total flow fixed. At EGR = 0, all inlet
% gas is ambient air. At EGR > 0, cathode exhaust replaces part of the
% ambient air flow by mass while the total stack inlet flow stays unchanged.
% Ambient O2/N2/H2O composition is computed from ambient T, p, and RH.
% Ambient_RH is only used at Ambient_T_C/Ambient_p_kPa to compute gas
% composition. It is not reused as the stack-inlet RH after the gas is
% brought to the selected stack inlet pressure and temperature.
%
% Mode definitions used by this script:
% 1) Calibration replay mode, used by init/calibration scripts:
%    inlet_condition_mode = 0. BenchInletConditioner overwrites inlet vapor
%    mass to match measured stack-inlet RH. This is correct for replaying
%    experimental points, but it hides CEGR self-humidification.
% 2) Composition-preserve study mode, used here:
%    inlet_condition_mode = 1. BenchInletConditioner only applies the target
%    inlet pressure and temperature. O2/N2/H2O vapor mass fractions come from
%    ambient air plus returned cathode exhaust, so oxygen dilution and
%    self-humidification are computed by species conservation.
%
% EGR_fraction here means returned cathode exhaust mass fraction in the stack
% inlet total gas flow:
%    m_total = m_amb + m_EGR_return = fixed stack inlet flow
%    EGR_fraction = m_EGR_return / m_total
%    m_amb = (1 - EGR_fraction) * m_total
%
% Risk definition:
%    lambdaO2 < 1 means cathode oxygen supply is below stoichiometric demand.
%    These points are oxygen-starvation dangerous operating points, not
%    acceptable performance points.
%
% Ohmic model:
% eta_ohm = j*(delta_PEM/sigma_PEM(lambda,T) + ASR0), where sigma_PEM uses
% the book membrane-conductivity formula. theta5/theta6/theta7/theta8 belong
% to the old empirical ohmic relation and are not used as the primary ohmic
% humidity relation in this simplified bench model.

rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(rootDir, '01_模型'));

p = inputParser;
p.addParameter('Current_A', [38 76 114 152 228 266 342 418 494 570 646 684 722]);
p.addParameter('EGR_fraction', [0 0.1 0.2 0.3 0.4 0.5 0.6]);
p.addParameter('Ambient_T_C', 25);
p.addParameter('Ambient_p_kPa', 101);
p.addParameter('Ambient_RH', 0.50);
p.addParameter('UseNoEgrBoundaryInterpolation', true); % true: use measured no-EGR flow/p/T/outlet boundary vs current
p.addParameter('StopTime_s', 240);
p.parse(varargin{:});
opt = p.Results;

P0 = init_testbench_10kw_simplified_egr(1, 'noegr', false);
noEgr = P0.noEgrTable;
wAmb = ambientMassFractions(opt.Ambient_T_C, opt.Ambient_p_kPa, opt.Ambient_RH, P0);

nI = numel(opt.Current_A);
nR = numel(opt.EGR_fraction);
n = nI * nR;
T = table('Size', [n 29], 'VariableTypes', repmat("double", 1, 29), ...
    'VariableNames', {'current_A','egr_fraction','m_total_kg_s','m_amb_kg_s','m_egr_kg_s', ...
    'V_cell','P_stack_W','lambda_mem','xO2_in','wO2_in','wN2_in','wH2O_in','RH_in','lambdaO2', ...
    'valid_oxygen','risk_oxygen_starvation', ...
    'p_in_g_kPa','p_ca_internal_g_kPa','p_out_g_kPa','T_in_C','T_stack_C','T_out_C', ...
    'flow_in_SLPM','flow_amb_SLPM','flow_egr_SLPM','flow_out_SLPM', ...
    'mWaterVaporIn_kg_s','mWaterVaporOut_kg_s','max_gas_residual'});

rowIdx = 0;
for i = 1:nI
    for j = 1:nR
        rowIdx = rowIdx + 1;
        currentA = opt.Current_A(i);
        egrFrac = min(max(opt.EGR_fraction(j), 0), 0.95);

        P = initFromCurrent(noEgr, currentA);
        P.stopTime_s = opt.StopTime_s;
        P.egr_fraction_cmd = egrFrac;
        P.egr_fraction_cmd_raw = egrFrac;
        P.egr_valve_target_pct = 100 * egrFrac;
        P.egr_valve_input_pct = 100 * egrFrac;
        P.inlet_condition_mode = 1.0; % composition-preserve study mode, not measured-RH replay

        if opt.UseNoEgrBoundaryInterpolation
            ref = interpNoEgr(noEgr, currentA);
            P.stack_in_flow_SLPM = ref.cathode_flow_SLPM;
            P.stack_in_flow_kg_s = slpmAirToKgS(P.stack_in_flow_SLPM);
            P.fresh_supply_flow_kg_s = P.stack_in_flow_kg_s * (1 - egrFrac);
            P.fresh_supply_flow_SLPM = P.stack_in_flow_SLPM * (1 - egrFrac);
            P.bench_stack_in_p_kPa = ref.cathode_in_p_g_kPa;
            P.bench_stack_in_T_C = ref.cathode_in_T_C;
            P.separator_p_kPa = ref.cathode_out_p_g_kPa;
            P.separator_T_C = ref.cathode_out_T_C;
            P.p_cathode_back_kPa = P.separator_p_kPa + P.p_amb_kPa;
        end

        P = applyStudyBoundary(P, wAmb, egrFrac);
        out = simulateCase(P);
        s = lastVector(out.get('summary_vector'));
        caIn = lastVector(out.get('stack_in_node'));
        caOut = lastVector(out.get('stack_ca_out_node'));

        mTotal = P.stack_in_flow_kg_s;
        mAmb = (1 - egrFrac) * mTotal;
        mEgr = egrFrac * mTotal;
        wIn = caIn(1:3) / max(sum(caIn(1:3)), 1e-12);

        T.current_A(rowIdx) = currentA;
        T.egr_fraction(rowIdx) = egrFrac;
        T.m_total_kg_s(rowIdx) = mTotal;
        T.m_amb_kg_s(rowIdx) = mAmb;
        T.m_egr_kg_s(rowIdx) = mEgr;
        T.V_cell(rowIdx) = s(2);
        T.P_stack_W(rowIdx) = s(3);
        T.lambda_mem(rowIdx) = s(8);
        T.xO2_in(rowIdx) = s(49);
        T.wO2_in(rowIdx) = wIn(1);
        T.wN2_in(rowIdx) = wIn(2);
        T.wH2O_in(rowIdx) = wIn(3);
        T.RH_in(rowIdx) = s(21);
        T.lambdaO2(rowIdx) = s(40);
        T.valid_oxygen(rowIdx) = double(s(40) > 1.0);
        T.risk_oxygen_starvation(rowIdx) = double(s(40) < 1.0);
        T.p_in_g_kPa(rowIdx) = caIn(6) - P.p_amb_kPa;
        T.p_ca_internal_g_kPa(rowIdx) = s(5) - P.p_amb_kPa;
        T.p_out_g_kPa(rowIdx) = caOut(6) - P.p_amb_kPa;
        T.T_in_C(rowIdx) = caIn(5);
        T.T_stack_C(rowIdx) = s(9);
        T.T_out_C(rowIdx) = caOut(5);
        T.flow_in_SLPM(rowIdx) = kgSToSlpm(s(50));
        T.flow_amb_SLPM(rowIdx) = kgSToSlpm(mAmb);
        T.flow_egr_SLPM(rowIdx) = kgSToSlpm(s(51));
        T.flow_out_SLPM(rowIdx) = kgSToSlpm(s(52));
        T.mWaterVaporIn_kg_s(rowIdx) = s(44);
        T.mWaterVaporOut_kg_s(rowIdx) = s(45);
        T.max_gas_residual(rowIdx) = s(31);
    end
end

result = struct();
result.study = T;
result.ambient = struct('T_C', opt.Ambient_T_C, 'p_kPa', opt.Ambient_p_kPa, ...
    'RH', opt.Ambient_RH, 'mass_fraction_O2_N2_H2O', wAmb(:).');
result.assumptions = [
    "No external humidifier in study mode."
    "Stack inlet total flow is fixed for each current point."
    "Ambient air is replaced by returned cathode exhaust according to EGR mass fraction."
    "Inlet pressure and temperature follow the selected no-EGR bench boundary."
    "lambdaO2 < 1 is judged as oxygen-starvation danger, not a valid performance point."
    ];

printSummary(result);
plotStudy(result);
plotVoltageVsEgrByLoad(result);
end

function P = initFromCurrent(noEgr, currentA)
[~, idx] = min(abs(noEgr.current_A - currentA));
P = init_testbench_10kw_simplified_egr(noEgr.case_index(idx), 'noegr', false);
P.I_stack_default_A = currentA;
P.current_density_A_cm2 = currentA / P.A_cell_cm2;
end

function P = applyStudyBoundary(P, wAmb, egrFrac)
P.fresh_supply_flow_kg_s = P.stack_in_flow_kg_s * (1 - egrFrac);
P.fresh_supply_flow_SLPM = kgSToSlpm(P.fresh_supply_flow_kg_s);
xO2DryAmb = massToDryMoleO2(wAmb, P);
rhStackEquivalent = stackEquivalentRH(wAmb, P);
P.BenchBoundaryParam = [
    P.M_O2_kg_mol
    P.M_N2_kg_mol
    P.M_H2O_kg_mol
    P.bench_stack_in_p_kPa + P.p_amb_kPa
    P.bench_stack_in_T_C
    rhStackEquivalent
    xO2DryAmb
    1 - xO2DryAmb
    P.stack_in_flow_kg_s
    P.fresh_supply_flow_kg_s
    P.inlet_condition_mode
    ];
P.EgrSplitParam = [
    egrFrac
    P.separator_T_C
    P.separator_p_kPa + P.p_amb_kPa
    P.egr_valve_target_pct
    P.egr_valve_input_pct
    ];
P.StackParam(15) = P.p_cathode_back_kPa;
P.StackParam(75) = egrFrac;
P.StackParam(80) = P.separator_T_C;

T0_K = P.bench_stack_in_T_C + 273.15;
pAbs = P.bench_stack_in_p_kPa + P.p_amb_kPa;
y = massToMoleFractions(wAmb, P);
pO2 = max(pAbs * y(1), 1e-6);
pN2 = max(pAbs * y(2), 1e-6);
pH2O = max(pAbs * y(3), 0);
P.stack_initial_state(1) = pO2 * 1000 * P.V_ca_m3 * P.M_O2_kg_mol / (P.R_J_molK * T0_K);
P.stack_initial_state(2) = pN2 * 1000 * P.V_ca_m3 * P.M_N2_kg_mol / (P.R_J_molK * T0_K);
P.stack_initial_state(3) = pH2O * 1000 * P.V_ca_m3 * P.M_H2O_kg_mol / (P.R_J_molK * T0_K);
P.stack_initial_state(6) = P.bench_stack_in_T_C;
P.egr_initial_node = zeros(7, 1);
P.egr_initial_node(1:3) = egrFrac * P.stack_in_flow_kg_s * wAmb(:);
P.egr_initial_node(5) = P.separator_T_C;
P.egr_initial_node(6) = P.separator_p_kPa + P.p_amb_kPa;
end

function w = ambientMassFractions(T_C, p_kPa, RH, P)
pV = min(max(RH, 0) * satKPa(T_C), 0.98 * p_kPa);
yV = min(max(pV / max(p_kPa, 1e-9), 0), 0.98);
yO2 = (1 - yV) * P.xO2_dry;
yN2 = (1 - yV) * P.xN2_dry;
m = [yO2 * P.M_O2_kg_mol; yN2 * P.M_N2_kg_mol; yV * P.M_H2O_kg_mol];
w = m / sum(m);
end

function y = massToMoleFractions(w, P)
n = [w(1) / P.M_O2_kg_mol; w(2) / P.M_N2_kg_mol; w(3) / P.M_H2O_kg_mol];
y = n / sum(n);
end

function xO2Dry = massToDryMoleO2(w, P)
nO2 = w(1) / P.M_O2_kg_mol;
nN2 = w(2) / P.M_N2_kg_mol;
xO2Dry = nO2 / max(nO2 + nN2, 1e-12);
end

function rh = stackEquivalentRH(w, P)
y = massToMoleFractions(w, P);
pAbs = P.bench_stack_in_p_kPa + P.p_amb_kPa;
rh = y(3) * pAbs / max(satKPa(P.bench_stack_in_T_C), 1e-9);
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

function printSummary(result)
T = result.study;
fprintf('Ambient mass fraction [O2 N2 H2O] = [%.6f %.6f %.6f]\\n', ...
    result.ambient.mass_fraction_O2_N2_H2O);
fprintf('Cases: %d, currents: %d, EGR fractions: %d\\n', height(T), ...
    numel(unique(T.current_A)), numel(unique(T.egr_fraction)));
fprintf('V_cell range %.4f to %.4f V/cell, lambda_mem range %.3f to %.3f, RH_in range %.3f to %.3f, lambdaO2 range %.3f to %.3f\\n', ...
    min(T.V_cell), max(T.V_cell), min(T.lambda_mem), max(T.lambda_mem), min(T.RH_in), max(T.RH_in), min(T.lambdaO2), max(T.lambdaO2));
fprintf('Oxygen-valid cases lambdaO2 > 1: %d/%d\\n', nnz(T.valid_oxygen > 0.5), height(T));
fprintf('Oxygen-starvation danger cases lambdaO2 < 1: %d/%d\\n', nnz(T.risk_oxygen_starvation > 0.5), height(T));
fprintf('Max gas residual %.3g\\n', max(T.max_gas_residual));
end

function plotStudy(result)
T = result.study;
safe = T.risk_oxygen_starvation < 0.5;
risk = ~safe;

figure('Name', 'No humidifier CEGR study', 'NumberTitle', 'off');
tiledlayout(2, 3);

nexttile;
hold on;
plotByEgr(T(safe, :), 'V_cell', false);
scatter(T.current_A(risk), T.V_cell(risk), 46, 'rx', 'LineWidth', 1.5);
grid on; xlabel('Current A'); ylabel('Cell voltage V'); title('Voltage');
legendWithRisk(T, risk);

nexttile;
hold on;
plotByEgr(T(safe, :), 'RH_in', false);
scatter(T.current_A(risk), T.RH_in(risk), 46, 'rx', 'LineWidth', 1.5);
grid on; xlabel('Current A'); ylabel('Inlet RH'); title('Self humidification');
legendWithRisk(T, risk);

nexttile;
hold on;
plotByEgr(T(safe, :), 'lambdaO2', false);
scatter(T.current_A(risk), T.lambdaO2(risk), 46, 'rx', 'LineWidth', 1.5);
yline(1, 'r--', 'lambdaO2 = 1');
grid on; xlabel('Current A'); ylabel('lambdaO2'); title('Oxygen stoich risk');
legendWithRisk(T, risk);

nexttile;
hold on;
plotByEgr(T(safe, :), 'wO2_in', false);
scatter(T.current_A(risk), T.wO2_in(risk), 46, 'rx', 'LineWidth', 1.5);
grid on; xlabel('Current A'); ylabel('O2 mass fraction'); title('Inlet O2 fraction');
legendWithRisk(T, risk);

nexttile;
hold on;
plotByEgr(T(safe, :), 'wH2O_in', false);
scatter(T.current_A(risk), T.wH2O_in(risk), 46, 'rx', 'LineWidth', 1.5);
grid on; xlabel('Current A'); ylabel('H2O vapor mass fraction'); title('Inlet vapor fraction');
legendWithRisk(T, risk);

nexttile;
hold on;
plotByEgr(T(safe, :), 'P_stack_W', false);
scatter(T.current_A(risk), T.P_stack_W(risk), 46, 'rx', 'LineWidth', 1.5);
grid on; xlabel('Current A'); ylabel('Stack power W'); title('Stack power');
legendWithRisk(T, risk);

figure('Name', 'No humidifier CEGR risk map', 'NumberTitle', 'off');
tiledlayout(1, 2);

nexttile;
scatter(T.egr_fraction, T.current_A, 48, T.lambdaO2, 'filled'); hold on;
scatter(T.egr_fraction(risk), T.current_A(risk), 60, 'rx', 'LineWidth', 1.7);
ylabel('Current A'); xlabel('EGR fraction'); title('lambdaO2 map');
grid on; colorbar;

nexttile;
scatter(T.egr_fraction, T.current_A, 48, T.RH_in, 'filled'); hold on;
scatter(T.egr_fraction(risk), T.current_A(risk), 60, 'rx', 'LineWidth', 1.7);
ylabel('Current A'); xlabel('EGR fraction'); title('Inlet RH map');
grid on; colorbar;
end

function plotVoltageVsEgrByLoad(result)
T = result.study;
bench = hydratedNoEgrBaseline(unique(T.current_A));
risk = T.risk_oxygen_starvation > 0.5;

groups = {
    "Low load 0.05-0.3 A/cm2", 0.05, 0.30
    "Medium load", 0.40, 0.90
    "High load", 1.10, inf
    };

figure('Name', 'Voltage vs EGR by load', 'NumberTitle', 'off');
tiledlayout(1, 3);
for g = 1:size(groups, 1)
    titleText = groups{g, 1};
    lo = groups{g, 2};
    hi = groups{g, 3};
    idxLoad = T.current_A / 380 >= lo & T.current_A / 380 <= hi;
    S = T(idxLoad, :);
    currents = unique(S.current_A(:)).';
    colors = lines(max(numel(currents), 1));
    nexttile;
    hold on;
    legendText = strings(0, 1);
    for i = 1:numel(currents)
        idx = S.current_A == currents(i) & S.risk_oxygen_starvation < 0.5;
        A = sortrows(S(idx, :), 'egr_fraction');
        if ~isempty(A)
            plot(A.egr_fraction, A.V_cell, '.-', 'Color', colors(i, :), 'MarkerSize', 12);
            labelLambdaMem(A);
            legendText(end + 1, 1) = sprintf('%.2f A/cm2', currents(i) / 380); %#ok<AGROW>
        end

        idxRisk = S.current_A == currents(i) & S.risk_oxygen_starvation > 0.5;
        R = S(idxRisk, :);
        if ~isempty(R)
            scatter(R.egr_fraction, R.V_cell, 48, 'rx', 'LineWidth', 1.5);
            labelLambdaMem(R);
        end

        b = bench(bench.current_A == currents(i), :);
        if ~isempty(b)
            scatter(0, b.V_cell_humid_noegr, 52, colors(i, :), 's', 'LineWidth', 1.4);
        end
    end
    if any(risk & idxLoad)
        legendText(end + 1, 1) = "lambdaO2 < 1 danger"; %#ok<AGROW>
    end
    if any(ismember(bench.current_A, currents))
        legendText(end + 1, 1) = "humidified no-CEGR baseline"; %#ok<AGROW>
    end
    grid on;
    xlabel('EGR fraction');
    ylabel('Cell voltage V');
    title(titleText);
    xlim([-0.02 0.62]);
    if ~isempty(legendText)
        legend(legendText, 'Location', 'best');
    end
end
end

function labelLambdaMem(T)
for k = 1:height(T)
    text(T.egr_fraction(k) + 0.006, T.V_cell(k), sprintf('%.1f', T.lambda_mem(k)), ...
        'FontSize', 7, 'Color', [0.15 0.15 0.15], 'Clipping', 'on');
end
end

function bench = hydratedNoEgrBaseline(currents)
n = numel(currents);
bench = table('Size', [n 2], 'VariableTypes', ["double", "double"], ...
    'VariableNames', {'current_A','V_cell_humid_noegr'});
for i = 1:n
    P = init_testbench_10kw_simplified_egr(1, 'noegr', false);
    data = P.noEgrTable;
    [~, idx] = min(abs(data.current_A - currents(i)));
    P = init_testbench_10kw_simplified_egr(data.case_index(idx), 'noegr', false);
    P.I_stack_default_A = currents(i);
    out = simulateCase(P);
    s = lastVector(out.get('summary_vector'));
    bench.current_A(i) = currents(i);
    bench.V_cell_humid_noegr(i) = s(2);
end
end

function plotByEgr(T, yName, useMarkerOnly)
egrVals = unique(T.egr_fraction(:)).';
colors = lines(max(numel(egrVals), 1));
for i = 1:numel(egrVals)
    idx = T.egr_fraction == egrVals(i);
    S = sortrows(T(idx, :), 'current_A');
    if useMarkerOnly
        scatter(S.current_A, S.(yName), 34, colors(i, :), 'filled');
    else
        plot(S.current_A, S.(yName), '.-', 'Color', colors(i, :), 'MarkerSize', 12);
    end
end
end

function legendWithRisk(T, risk)
plottedEgr = unique(T.egr_fraction(T.risk_oxygen_starvation < 0.5));
labels = compose('EGR %.1f', plottedEgr(:));
if any(risk)
    labels = [labels; "lambdaO2 < 1 danger"];
end
if ~isempty(labels)
    legend(labels, 'Location', 'best');
end
end

function v = lastVector(ts)
v = ts.signals.values(:, :, end);
v = v(:);
end

function slpm = kgSToSlpm(m)
slpm = m * 60000 / 1.293;
end

function m = slpmAirToKgS(slpm)
m = slpm * 1.293 / 60000;
end

function r = interpNoEgr(T, currentA)
vars = T.Properties.VariableNames;
r = T(1, :);
for k = 1:numel(vars)
    v = T.(vars{k});
    if isnumeric(v)
        r.(vars{k}) = interp1(T.current_A, v, currentA, 'linear', 'extrap');
    end
end
end

function p = satKPa(T)
Tc = min(max(T, -40), 120);
p = 0.61121 * exp((18.678 - Tc / 234.5) * (Tc / (257.14 + Tc)));
end
