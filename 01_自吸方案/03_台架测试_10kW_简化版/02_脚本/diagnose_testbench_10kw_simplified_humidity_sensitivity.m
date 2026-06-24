function outputs = diagnose_testbench_10kw_simplified_humidity_sensitivity(stopTime_s, showFigures)
%DIAGNOSE_TESTBENCH_10KW_SIMPLIFIED_HUMIDITY_SENSITIVITY
% 诊断“无外部加湿 vs 加压加湿 no-EGR”在不同电流密度下的湿度响应差异。
% 重点关注 0.4 A/cm2 前后：
% 1. 阴极入口 RH / 氧分压；
% 2. 阴极/阳极平衡膜含水 lambdaCa/lambdaAn 和平均 lambda_m；
% 3. 阴极冷凝、产水/入口水比例与跨膜水通量；
% 4. 欧姆损失 etaOhm 与最终电压差。

if nargin < 1 || isempty(stopTime_s)
    stopTime_s = 120;
end
if nargin < 2 || isempty(showFigures)
    showFigures = true;
end

scriptDir = fileparts(mfilename("fullpath"));
rootDir = fileparts(scriptDir);
resultDir = fullfile(rootDir, "04_验证结果", "custom_inlet_study_v01");
caseDefFile = fullfile(resultDir, "custom_inlet_case_definition.csv");
if ~isfile(caseDefFile)
    error("CEGR:SimplifiedBench:MissingCustomCaseDefinition", ...
        "Cannot find %s. Run run_testbench_10kw_simplified_custom_inlet_study first.", caseDefFile);
end

caseDef = readtable(caseDefFile, "TextType", "string");
caseDef = normalizeCaseDefinition(caseDef);

P0 = init_testbench_10kw_simplified_egr(1, "initial_noegr", false);
model = P0.modelName;
load_system(model);

rows = {};
for k = 1:height(caseDef)
    rows{end + 1, 1} = simulateMode(caseDef(k, :), "dry", stopTime_s, model); %#ok<AGROW>
    rows{end + 1, 1} = simulateMode(caseDef(k, :), "ref", stopTime_s, model); %#ok<AGROW>
end

detail = sortrows(vertcat(rows{:}), {'current_density_A_cm2', 'mode'});
delta = buildDeltaTable(detail);
summary = summarizeTransition(delta);

fig1 = [];
fig2 = [];
fig3 = [];
if showFigures
    fig1 = plotHydrationFigure(detail, delta);
    fig2 = plotWaterBalanceFigure(detail, delta);
    fig3 = plotVoltageFigure(detail, delta);
end

printSummary(summary);

outputs = struct();
outputs.detail = detail;
outputs.delta = delta;
outputs.summary = summary;
outputs.hydration_figure = fig1;
outputs.water_balance_figure = fig2;
outputs.voltage_figure = fig3;
end

function row = simulateMode(caseRow, mode, stopTime_s, model)
caseIdx = caseRow.boundary_case_index;
Pbase = init_testbench_10kw_simplified_egr(caseIdx, "initial_noegr", false);
if mode == "dry"
    override = struct( ...
        "bench_supply_gas_p_kPa", caseRow.ambient_supply_p_kPa_g, ...
        "bench_supply_gas_T_C", caseRow.ambient_supply_T_C, ...
        "bench_supply_gas_RH", caseRow.ambient_supply_RH, ...
        "stack_in_flow_kg_s", caseRow.stack_in_flow_recomputed_kg_s, ...
        "stack_in_flow_SLPM", caseRow.stack_in_flow_recomputed_SLPM, ...
        "egr_fraction_cmd", 0.0, ...
        "separator_p_kPa", Pbase.stack_out_p_kPa, ...
        "separator_T_C", Pbase.stack_out_T_C);
    P = init_testbench_10kw_simplified_egr(caseIdx, "initial_noegr", false, override);
else
    P = Pbase;
end

out = simulateCase(P, stopTime_s, model);
summaryVec = lastSummary(out);

row = table();
row.mode = string(mode);
row.case_id = string(P.case_id);
row.current_A = P.I_stack_default_A;
row.current_density_A_cm2 = P.current_density_A_cm2;
row.stack_in_flow_kg_s = P.stack_in_flow_kg_s;
row.supply_RH = P.bench_supply_gas_RH;
row.supply_p_kPa_g = P.bench_supply_gas_p_kPa;
row.supply_T_C = P.bench_supply_gas_T_C;
row.xO2_in = summaryVec(20);
row.pO2_in_kPa = summaryVec(19);
row.RH_in = summaryVec(21);
row.lambda_O2_actual = summaryVec(40);
row.V_cell = summaryVec(2);
row.etaOhm_V = summaryVec(38);
row.etaAct_V = summaryVec(37);
row.lambda_m = summaryVec(8);
row.lambdaCa = summaryVec(49);
row.lambdaAn = summaryVec(50);
row.mWater_kg_s = summaryVec(15);
row.mVIn_kg_s = summaryVec(44);
row.mVOut_kg_s = summaryVec(45);
row.phaseCa_kg_s = summaryVec(26);
row.phaseAn_kg_s = summaryVec(29);
row.liqCa_kg_s = summaryVec(57);
row.liqAn_kg_s = summaryVec(58);
row.JDrag_mol_m2_s = summaryVec(59);
row.JDiff_mol_m2_s = summaryVec(60);
row.JNet_mol_m2_s = summaryVec(61);
row.mDrag_kg_s = summaryVec(62);
row.mDiff_kg_s = summaryVec(63);
row.mMemRaw_kg_s = summaryVec(64);
row.mMemLimit_kg_s = summaryVec(65);
row.mMemTarget_kg_s = summaryVec(66);
row.prod_to_inlet_ratio = row.mWater_kg_s / max(row.mVIn_kg_s, 1e-12);
row.condensed_total_kg_s = row.liqCa_kg_s + row.liqAn_kg_s;
row.ca_saturated_flag = row.liqCa_kg_s > 0;
end

function out = simulateCase(P, stopTime_s, model)
in = Simulink.SimulationInput(model);
in = in.setModelParameter("StopTime", num2str(stopTime_s), ...
    "SolverType", "Fixed-step", "Solver", "ode4", "FixedStep", num2str(P.dt_s));
in = in.setVariable("PhysicalParam_simplified", P.PhysicalParam);
in = in.setVariable("StackModelParam_simplified", P.StackModelParam);
in = in.setVariable("CaseBoundaryParam_simplified", P.CaseBoundaryParam);
in = in.setVariable("CoolingCurveParam_simplified", P.CoolingCurveParam);
in = in.setVariable("dt_s_simplified", P.dt_s_simplified);
in = in.setVariable("StackInitialState_simplified", P.stack_initial_state);
in = in.setVariable("EGRInitialNode_simplified", P.egr_initial_node);
out = sim(in);
end

function s = lastSummary(out)
v = out.summary_vector.signals.values;
s = squeeze(v(:, 1, end));
end

function delta = buildDeltaTable(detail)
dry = sortrows(detail(detail.mode == "dry", :), "current_density_A_cm2");
ref = sortrows(detail(detail.mode == "ref", :), "current_density_A_cm2");

delta = table();
delta.case_id = dry.case_id;
delta.current_A = dry.current_A;
delta.current_density_A_cm2 = dry.current_density_A_cm2;
delta.RH_in_dry = dry.RH_in;
delta.RH_in_ref = ref.RH_in;
delta.dRH_in = dry.RH_in - ref.RH_in;
delta.lambdaCa_dry = dry.lambdaCa;
delta.lambdaCa_ref = ref.lambdaCa;
delta.dlambdaCa = dry.lambdaCa - ref.lambdaCa;
delta.lambdaAn_dry = dry.lambdaAn;
delta.lambdaAn_ref = ref.lambdaAn;
delta.dlambdaAn = dry.lambdaAn - ref.lambdaAn;
delta.lambda_m_dry = dry.lambda_m;
delta.lambda_m_ref = ref.lambda_m;
delta.dlambda_m = dry.lambda_m - ref.lambda_m;
delta.liqCa_dry = dry.liqCa_kg_s;
delta.liqCa_ref = ref.liqCa_kg_s;
delta.prod_to_inlet_dry = dry.prod_to_inlet_ratio;
delta.prod_to_inlet_ref = ref.prod_to_inlet_ratio;
delta.etaOhm_dry_mV = 1000 * dry.etaOhm_V;
delta.etaOhm_ref_mV = 1000 * ref.etaOhm_V;
delta.detaOhm_mV = 1000 * (dry.etaOhm_V - ref.etaOhm_V);
delta.pO2_in_dry_kPa = dry.pO2_in_kPa;
delta.pO2_in_ref_kPa = ref.pO2_in_kPa;
delta.dpO2_in_kPa = dry.pO2_in_kPa - ref.pO2_in_kPa;
delta.xO2_in_dry = dry.xO2_in;
delta.xO2_in_ref = ref.xO2_in;
delta.dxO2_in = dry.xO2_in - ref.xO2_in;
delta.V_dry = dry.V_cell;
delta.V_ref = ref.V_cell;
delta.dV_mV = 1000 * (dry.V_cell - ref.V_cell);
delta.ca_saturated_dry = dry.ca_saturated_flag;
delta.ca_saturated_ref = ref.ca_saturated_flag;
end

function summary = summarizeTransition(delta)
summary = struct();
summary.first_condensing_dry_j = firstTrueCurrent(delta.current_density_A_cm2, delta.ca_saturated_dry);
summary.first_small_lambda_gap_j = firstGapCurrent(delta.current_density_A_cm2, abs(delta.dlambda_m), 0.05);
summary.first_small_ohmic_gap_j = firstGapCurrent(delta.current_density_A_cm2, abs(delta.detaOhm_mV), 0.5);
summary.first_voltage_flip_j = firstTrueCurrent(delta.current_density_A_cm2, delta.dV_mV >= 0);
end

function j = firstTrueCurrent(jGrid, mask)
idx = find(mask, 1, "first");
if isempty(idx)
    j = NaN;
else
    j = jGrid(idx);
end
end

function j = firstGapCurrent(jGrid, gap, threshold)
idx = find(gap <= threshold, 1, "first");
if isempty(idx)
    j = NaN;
else
    j = jGrid(idx);
end
end

function fig = plotHydrationFigure(detail, delta)
fig = figure("Color", "w", "Visible", "on", ...
    "Name", "Humidity sensitivity diagnosis - hydration");
fig.Position(3:4) = [1540 980];
tl = tiledlayout(fig, 2, 2, "TileSpacing", "compact", "Padding", "compact");
title(tl, "湿度敏感性诊断：入口 RH 与膜含水链路");

plotModePair(nexttile, detail, "RH_in", "Cathode inlet RH (-)", true);
plotModePair(nexttile, detail, "lambdaCa", "lambda_{Ca} (-)", false);
plotModePair(nexttile, detail, "lambdaAn", "lambda_{An} (-)", false);

ax = nexttile;
hold(ax, "on"); grid(ax, "on"); box(ax, "on");
plot(ax, delta.current_density_A_cm2, delta.lambda_m_dry, "-o", ...
    "Color", [0.2 0.45 0.85], "LineWidth", 1.8, "MarkerSize", 5, ...
    "DisplayName", "dry lambda_m");
plot(ax, delta.current_density_A_cm2, delta.lambda_m_ref, "-s", ...
    "Color", [0.88 0.42 0.18], "LineWidth", 1.8, "MarkerSize", 5, ...
    "DisplayName", "humidified ref lambda_m");
yyaxis(ax, "right");
plot(ax, delta.current_density_A_cm2, delta.dlambda_m, "--d", ...
    "Color", [0.35 0.35 0.35], "LineWidth", 1.5, "MarkerSize", 4, ...
    "DisplayName", "dry-ref");
ylabel(ax, "\Delta lambda_m (-)");
yyaxis(ax, "left");
xlabel(ax, "Current density (A/cm^2)");
ylabel(ax, "Mean membrane hydration (-)");
xline(ax, 0.4, ":", "j=0.4", "Color", [0.75 0.1 0.1], ...
    "LabelVerticalAlignment", "bottom");
title(ax, "Mean membrane hydration");
legend(ax, "Location", "best");
end

function fig = plotWaterBalanceFigure(detail, delta)
fig = figure("Color", "w", "Visible", "on", ...
    "Name", "Humidity sensitivity diagnosis - water balance");
fig.Position(3:4) = [1540 980];
tl = tiledlayout(fig, 2, 2, "TileSpacing", "compact", "Padding", "compact");
title(tl, "湿度敏感性诊断：产水、冷凝与跨膜水通量");

ax1 = nexttile;
hold(ax1, "on"); grid(ax1, "on"); box(ax1, "on");
plot(ax1, delta.current_density_A_cm2, delta.prod_to_inlet_dry, "-o", ...
    "Color", [0.2 0.45 0.85], "LineWidth", 1.8, "MarkerSize", 5, ...
    "DisplayName", "dry m_{water}/m_{v,in}");
plot(ax1, delta.current_density_A_cm2, delta.prod_to_inlet_ref, "-s", ...
    "Color", [0.88 0.42 0.18], "LineWidth", 1.8, "MarkerSize", 5, ...
    "DisplayName", "humidified ref m_{water}/m_{v,in}");
xline(ax1, 0.4, ":", "j=0.4", "Color", [0.75 0.1 0.1], ...
    "LabelVerticalAlignment", "bottom");
xlabel(ax1, "Current density (A/cm^2)");
ylabel(ax1, "Water production / inlet vapor (-)");
title(ax1, "Water production relative to inlet vapor");
legend(ax1, "Location", "northwest");

ax2 = nexttile;
hold(ax2, "on"); grid(ax2, "on"); box(ax2, "on");
plot(ax2, delta.current_density_A_cm2, 1e6 * delta.liqCa_dry, "-o", ...
    "Color", [0.2 0.45 0.85], "LineWidth", 1.8, "MarkerSize", 5, ...
    "DisplayName", "dry cathode condensation");
plot(ax2, delta.current_density_A_cm2, 1e6 * delta.liqCa_ref, "-s", ...
    "Color", [0.88 0.42 0.18], "LineWidth", 1.8, "MarkerSize", 5, ...
    "DisplayName", "humidified ref cathode condensation");
xline(ax2, 0.4, ":", "j=0.4", "Color", [0.75 0.1 0.1], ...
    "LabelVerticalAlignment", "bottom");
xlabel(ax2, "Current density (A/cm^2)");
ylabel(ax2, "liqCa (ug/s)");
title(ax2, "Cathode condensation onset");
legend(ax2, "Location", "northwest");

plotModePair(nexttile, detail, "JDrag_mol_m2_s", "J_{drag} (mol/m^2/s)", false);
plotModePair(nexttile, detail, "JDiff_mol_m2_s", "J_{diff} (mol/m^2/s)", false);
end

function fig = plotVoltageFigure(detail, delta)
fig = figure("Color", "w", "Visible", "on", ...
    "Name", "Humidity sensitivity diagnosis - voltage");
fig.Position(3:4) = [1540 980];
tl = tiledlayout(fig, 2, 2, "TileSpacing", "compact", "Padding", "compact");
title(tl, "湿度敏感性诊断：氧分压、欧姆损失与电压");

plotModePair(nexttile, detail, "pO2_in_kPa", "Cathode inlet pO2 (kPa)", false);

ax2 = nexttile;
hold(ax2, "on"); grid(ax2, "on"); box(ax2, "on");
plot(ax2, delta.current_density_A_cm2, delta.etaOhm_dry_mV, "-o", ...
    "Color", [0.2 0.45 0.85], "LineWidth", 1.8, "MarkerSize", 5, ...
    "DisplayName", "dry etaOhm");
plot(ax2, delta.current_density_A_cm2, delta.etaOhm_ref_mV, "-s", ...
    "Color", [0.88 0.42 0.18], "LineWidth", 1.8, "MarkerSize", 5, ...
    "DisplayName", "humidified ref etaOhm");
yyaxis(ax2, "right");
plot(ax2, delta.current_density_A_cm2, delta.detaOhm_mV, "--d", ...
    "Color", [0.35 0.35 0.35], "LineWidth", 1.5, "MarkerSize", 4, ...
    "DisplayName", "dry-ref");
ylabel(ax2, "\Delta etaOhm (mV)");
yyaxis(ax2, "left");
xlabel(ax2, "Current density (A/cm^2)");
ylabel(ax2, "etaOhm (mV)");
xline(ax2, 0.4, ":", "j=0.4", "Color", [0.75 0.1 0.1], ...
    "LabelVerticalAlignment", "bottom");
title(ax2, "Ohmic loss");
legend(ax2, "Location", "northwest");

ax3 = nexttile;
hold(ax3, "on"); grid(ax3, "on"); box(ax3, "on");
plot(ax3, delta.current_density_A_cm2, delta.dpO2_in_kPa, "-o", ...
    "Color", [0.55 0.28 0.75], "LineWidth", 1.8, "MarkerSize", 5, ...
    "DisplayName", "dry-ref pO2");
xline(ax3, 0.4, ":", "j=0.4", "Color", [0.75 0.1 0.1], ...
    "LabelVerticalAlignment", "bottom");
xlabel(ax3, "Current density (A/cm^2)");
ylabel(ax3, "\Delta pO2_{in} (kPa)");
title(ax3, "Oxygen partial-pressure advantage of dry case");
legend(ax3, "Location", "northwest");

ax4 = nexttile;
hold(ax4, "on"); grid(ax4, "on"); box(ax4, "on");
plot(ax4, delta.current_density_A_cm2, delta.dV_mV, "-o", ...
    "Color", [0.15 0.15 0.15], "LineWidth", 1.8, "MarkerSize", 5, ...
    "DisplayName", "dry-ref Vcell");
xline(ax4, 0.4, ":", "j=0.4", "Color", [0.75 0.1 0.1], ...
    "LabelVerticalAlignment", "bottom");
yline(ax4, 0, "--", "Color", [0.5 0.5 0.5], ...
    "HandleVisibility", "off");
xlabel(ax4, "Current density (A/cm^2)");
ylabel(ax4, "\Delta V_{cell} (mV)");
title(ax4, "Net voltage difference");
legend(ax4, "Location", "southwest");
end

function plotModePair(ax, detail, varName, yLabelText, showLegend)
hold(ax, "on"); grid(ax, "on"); box(ax, "on");
dry = sortrows(detail(detail.mode == "dry", :), "current_density_A_cm2");
ref = sortrows(detail(detail.mode == "ref", :), "current_density_A_cm2");
plot(ax, dry.current_density_A_cm2, dry.(varName), "-o", ...
    "Color", [0.2 0.45 0.85], "LineWidth", 1.8, "MarkerSize", 5, ...
    "DisplayName", "dry");
plot(ax, ref.current_density_A_cm2, ref.(varName), "-s", ...
    "Color", [0.88 0.42 0.18], "LineWidth", 1.8, "MarkerSize", 5, ...
    "DisplayName", "pressurized humidified ref");
xline(ax, 0.4, ":", "j=0.4", "Color", [0.75 0.1 0.1], ...
    "LabelVerticalAlignment", "bottom");
xlabel(ax, "Current density (A/cm^2)");
ylabel(ax, yLabelText);
title(ax, strrep(varName, "_", "\_"));
if showLegend
    legend(ax, "Location", "best");
end
end

function printSummary(summary)
fprintf("Humidity sensitivity transition summary:\n");
fprintf("  first dry cathode condensation j = %.3f A/cm^2\n", summary.first_condensing_dry_j);
fprintf("  first |dry-ref lambda_m| <= 0.05 at j = %.3f A/cm^2\n", summary.first_small_lambda_gap_j);
fprintf("  first |dry-ref etaOhm| <= 0.5 mV at j = %.3f A/cm^2\n", summary.first_small_ohmic_gap_j);
fprintf("  first dry-ref voltage >= 0 at j = %.3f A/cm^2\n", summary.first_voltage_flip_j);
end

function T = normalizeCaseDefinition(T)
numericVars = ["boundary_case_index", "current_A", "current_density_A_cm2", ...
    "lambdaO2_initial", "stack_in_flow_recomputed_kg_s", "stack_in_flow_recomputed_SLPM", ...
    "ambient_supply_p_kPa_g", "ambient_supply_T_C", "ambient_supply_RH"];
for k = 1:numel(numericVars)
    name = numericVars(k);
    if ismember(name, string(T.Properties.VariableNames)) && ~isnumeric(T.(name))
        T.(name) = str2double(string(T.(name)));
    end
end
end
