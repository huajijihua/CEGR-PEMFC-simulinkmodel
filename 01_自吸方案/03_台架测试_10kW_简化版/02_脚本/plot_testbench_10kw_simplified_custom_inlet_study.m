function outputs = plot_testbench_10kw_simplified_custom_inlet_study(saveOutputs)
%PLOT_TESTBENCH_10KW_SIMPLIFIED_CUSTOM_INLET_STUDY
% 绘制自定义进气阶段的稳态对比图：
% 1. 低/中/高负载三张电压-循环比图，并叠加加压加湿 no-EGR 参考仿真的横向基准线。
% 2. 全电流密度的阴极入口 lambdaO2-循环比图。
% 3. 全电流密度的阴极入口干基含湿量-循环比图。

if nargin < 1 || isempty(saveOutputs)
    saveOutputs = false;
end

scriptDir = fileparts(mfilename("fullpath"));
rootDir = fileparts(scriptDir);
resultDir = fullfile(rootDir, "04_验证结果", "custom_inlet_study_v01");
plotDir = fullfile(resultDir, "plots");
if ~exist(plotDir, "dir")
    mkdir(plotDir);
end

scanFile = fullfile(resultDir, "custom_inlet_egr_scan.csv");
refFile = fullfile(resultDir, "humidified_reference_scan.csv");
if ~isfile(scanFile)
    error("CEGR:SimplifiedBench:MissingCustomScan", ...
        "Cannot find %s. Run run_testbench_10kw_simplified_custom_inlet_study first.", scanFile);
end
if ~isfile(refFile)
    run_testbench_10kw_simplified_humidified_reference_study();
end

S = readtable(scanFile, "TextType", "string");
R = readtable(refFile, "TextType", "string");
S = normalizeScanTable(S);
R = normalizeReferenceTable(R);
S = addMoistureContentColumns(S);
S = S(S.status == "ok", :);
R = R(R.status == "ok", :);

allJ = unique(S.current_density_command_A_cm2, "sorted");
colors = lines(numel(allJ));

outputs = struct();
outputs.voltage_png = fullfile(plotDir, ["custom_inlet_voltage_low_vs_egr.png", ...
    "custom_inlet_voltage_mid_vs_egr.png", "custom_inlet_voltage_high_vs_egr.png"]);
outputs.voltage_fig = fullfile(plotDir, ["custom_inlet_voltage_low_vs_egr.fig", ...
    "custom_inlet_voltage_mid_vs_egr.fig", "custom_inlet_voltage_high_vs_egr.fig"]);
outputs.lambda_png = fullfile(plotDir, "custom_inlet_lambdaO2_vs_egr.png");
outputs.lambda_fig = fullfile(plotDir, "custom_inlet_lambdaO2_vs_egr.fig");
outputs.moisture_png = fullfile(plotDir, "custom_inlet_moisture_content_vs_egr.png");
outputs.moisture_fig = fullfile(plotDir, "custom_inlet_moisture_content_vs_egr.fig");

outputs.voltage_figure = plotVoltageFigures(S, R, allJ, colors, outputs.voltage_png, outputs.voltage_fig, saveOutputs);
outputs.lambda_figure = plotLambdaFigure(S, allJ, colors, outputs.lambda_png, outputs.lambda_fig, saveOutputs);
outputs.moisture_figure = plotMoistureFigure(S, allJ, colors, outputs.moisture_png, outputs.moisture_fig, saveOutputs);
outputs.rh_figure = outputs.moisture_figure;
outputs.rh_png = outputs.moisture_png;
outputs.rh_fig = outputs.moisture_fig;

if saveOutputs
    fprintf("Saved voltage plots: %s\n", strjoin(string(outputs.voltage_png), ", "));
    fprintf("Saved lambda plot: %s\n", outputs.lambda_png);
    fprintf("Saved moisture plot: %s\n", outputs.moisture_png);
else
    fprintf("Opened voltage, lambda, and moisture figures in the MATLAB session.\n");
end
end

function figs = plotVoltageFigures(S, R, allJ, colors, pngFiles, figFiles, saveOutputs)
bandOrder = ["low", "mid", "high"];
bandTitle = ["Low load", "Mid load", "High load"];
figName = ["Custom inlet voltage vs EGR - low load", ...
    "Custom inlet voltage vs EGR - mid load", ...
    "Custom inlet voltage vs EGR - high load"];
figs = gobjects(numel(bandOrder), 1);

for b = 1:numel(bandOrder)
    fig = figure("Color", "w", "Visible", "on", "Name", figName(b));
    fig.Position = [60 + 45 * (b - 1), 90 + 35 * (b - 1), 1850, 760];
    figs(b) = fig;
    ax = axes(fig);
    hold(ax, "on");
    grid(ax, "on");
    box(ax, "on");
    Tsim = S(S.egr_band == bandOrder(b), :);
    Tref = R(R.egr_band == bandOrder(b), :);
    Tplot = Tsim(~Tsim.oxygen_starvation_risk & Tsim.gas_residual_ok, :);
    jBand = unique(Tsim.current_density_command_A_cm2, "sorted");
    maxPlotEgr = max(Tplot.egr_fraction_cmd, [], "omitnan");
    if isempty(maxPlotEgr) || isnan(maxPlotEgr)
        maxPlotEgr = max(Tsim.egr_fraction_cmd, [], "omitnan");
    end

    legendHandles = gobjects(0);
    legendLabels = strings(0, 1);
    voltageForLimits = [];

    for j = jBand(:).'
        idx = find(abs(allJ - j) < 1e-12, 1, "first");
        c = colors(idx, :);

        TjSim = sortrows(Tplot(abs(Tplot.current_density_command_A_cm2 - j) < 1e-12, :), "egr_fraction_cmd");
        if ~isempty(TjSim)
            hSim = plot(ax, TjSim.egr_fraction_cmd, TjSim.V_cell_sim, "-o", ...
                "Color", c, "LineWidth", 2.0, "MarkerSize", 4.2, ...
                "MarkerFaceColor", "w", ...
                "DisplayName", sprintf("j=%.1f sim no-humid", j));
            legendHandles(end + 1) = hSim; %#ok<AGROW>
            legendLabels(end + 1) = string(hSim.DisplayName); %#ok<AGROW>
            voltageForLimits = [voltageForLimits; TjSim.V_cell_sim(:)]; %#ok<AGROW>
            addVoltagePointLabels(ax, TjSim, c);
        end

        TjRef0 = Tref(abs(Tref.current_density_command_A_cm2 - j) < 1e-12 & abs(Tref.egr_fraction_cmd) < 1e-12, :);
        if ~isempty(TjRef0)
            vRef = TjRef0.V_cell_sim(1);
            xRef = [0, maxPlotEgr];
            hRef = plot(ax, xRef, [vRef, vRef], "--", ...
                "Color", c, "LineWidth", 1.5, ...
                "DisplayName", sprintf("j=%.1f pressurized humidified ref", j));
            legendHandles(end + 1) = hRef; %#ok<AGROW>
            legendLabels(end + 1) = string(hRef.DisplayName); %#ok<AGROW>
            voltageForLimits = [voltageForLimits; vRef]; %#ok<AGROW>
        end
    end

    omittedCount = nnz(Tsim.oxygen_starvation_risk | ~Tsim.gas_residual_ok);
    if omittedCount > 0
        text(ax, 0.98, 0.95, sprintf("omitted risk/residual points: %d", omittedCount), ...
            "Units", "normalized", "HorizontalAlignment", "right", ...
            "VerticalAlignment", "top", "FontSize", 8, "Color", [0.75 0.1 0.1]);
    end

    xlabel(ax, "EGR ratio (-)");
    ylabel(ax, "Cell voltage (V)");
    title(ax, "无外部加湿器稳态电压对比：" + bandTitle(b));
    xlim(ax, [0, maxPlotEgr + 0.02]);
    if ~isempty(voltageForLimits)
        vMin = min(voltageForLimits);
        vMax = max(voltageForLimits);
        pad = max(0.004, 0.10 * (vMax - vMin));
        ylim(ax, [vMin - pad, vMax + pad]);
    end
    text(ax, 0.02, 0.96, "solid = no external humidifier, dashed = pressurized humidified no-EGR reference", ...
        "Units", "normalized", "FontSize", 8, "VerticalAlignment", "top");
    legend(ax, legendHandles, cellstr(legendLabels), "Location", "southwest", "FontSize", 8);

    if saveOutputs
        exportgraphics(fig, pngFiles(b), "Resolution", 180);
        savefig(fig, figFiles(b));
    end
end
end

function addVoltagePointLabels(ax, TjSim, color)
for r = 1:height(TjSim)
    text(ax, TjSim.egr_fraction_cmd(r), TjSim.V_cell_sim(r), ...
        sprintf("\\lambda=%.2f\nRH=%.1f%%", TjSim.lambda_O2_actual(r), 100 * TjSim.RH_ca_in(r)), ...
        "Color", color, "FontSize", 6.8, "Interpreter", "tex", ...
        "HorizontalAlignment", "center", "VerticalAlignment", "bottom", ...
        "Margin", 0.5);
end
end

function fig = plotLambdaFigure(S, allJ, colors, pngFile, figFile, saveOutputs)
fig = figure("Color", "w", "Visible", "on", ...
    "Name", "Custom inlet lambdaO2 vs EGR");
fig.Position(3:4) = [1280 880];
ax = axes(fig);
hold(ax, "on");
grid(ax, "on");
box(ax, "on");

for j = allJ(:).'
    idx = find(abs(allJ - j) < 1e-12, 1, "first");
    c = colors(idx, :);
    Tj = sortrows(S(abs(S.current_density_command_A_cm2 - j) < 1e-12, :), "egr_fraction_cmd");
    plot(ax, Tj.egr_fraction_cmd, Tj.lambda_O2_actual, "-", ...
        "Color", c, "LineWidth", 1.6, ...
        "DisplayName", sprintf("j=%.1f", j));
end

Trisk = S(S.oxygen_starvation_risk, :);
if ~isempty(Trisk)
    scatter(ax, Trisk.egr_fraction_cmd, Trisk.lambda_O2_actual, 52, ...
        "Marker", "x", "LineWidth", 1.5, "MarkerEdgeColor", [0.85 0.2 0.2], ...
        "DisplayName", "lambdaO2<1.2 risk");
end
hRiskLine = yline(ax, 1.2, "--", "lambda_{O2}=1.2 risk line", ...
    "Color", [0.8 0.1 0.1], "LineWidth", 1.2, ...
    "LabelHorizontalAlignment", "left", "LabelVerticalAlignment", "bottom");
hRiskLine.Annotation.LegendInformation.IconDisplayStyle = "off";

xlabel(ax, "EGR ratio (-)");
ylabel(ax, "Cathode inlet lambda_{O2} (-)");
title(ax, "无外部加湿器：阴极入口氧气计量比");
legend(ax, "Location", "eastoutside");

if saveOutputs
    exportgraphics(fig, pngFile, "Resolution", 180);
    savefig(fig, figFile);
end
end

function fig = plotMoistureFigure(S, ~, ~, pngFile, figFile, saveOutputs)
fig = figure("Color", "w", "Visible", "on", ...
    "Name", "Custom inlet moisture content vs EGR");
fig.Position(3:4) = [1280 880];
ax = axes(fig);
hold(ax, "on");
grid(ax, "on");
box(ax, "on");

bandOrder = ["low", "mid", "high"];
bandLabels = ["Low load", "Mid load", "High load"];
bandColors = [0.15 0.45 0.85; 0.05 0.60 0.25; 0.85 0.35 0.10];

for b = 1:numel(bandOrder)
    Tband = S(S.egr_band == bandOrder(b), :);
    if isempty(Tband)
        continue;
    end
    stats = aggregateMoistureByEgr(Tband);
    c = bandColors(b, :);
    fill(ax, [stats.egr; flipud(stats.egr)], ...
        [stats.minMoisture; flipud(stats.maxMoisture)], c, ...
        "FaceAlpha", 0.12, "EdgeColor", "none", ...
        "HandleVisibility", "off");
    plot(ax, stats.egr, stats.meanMoisture, "-o", ...
        "Color", c, "LineWidth", 2.2, "MarkerSize", 5, ...
        "MarkerFaceColor", "w", ...
        "DisplayName", sprintf("%s mean", bandLabels(b)));
end

xlabel(ax, "EGR ratio (-)");
ylabel(ax, "Cathode inlet moisture content (g/kg dry gas)");
title(ax, "无外部加湿器：阴极入口干基含湿量（按负载段汇总）");
legend(ax, "Location", "northwest");
text(ax, 0.98, 0.04, "solid = band mean, shaded = min-max across current densities", ...
    "Units", "normalized", "HorizontalAlignment", "right", ...
    "VerticalAlignment", "bottom", "FontSize", 8, "Color", [0.25 0.25 0.25]);

if saveOutputs
    exportgraphics(fig, pngFile, "Resolution", 180);
    savefig(fig, figFile);
end
end

function stats = aggregateMoistureByEgr(T)
egrVals = unique(T.egr_fraction_cmd, "sorted");
egrVals = egrVals(:);
stats = table(egrVals, nan(numel(egrVals), 1), nan(numel(egrVals), 1), ...
    nan(numel(egrVals), 1), ...
    'VariableNames', {'egr', 'meanMoisture', 'minMoisture', 'maxMoisture'});
for k = 1:numel(egrVals)
    y = T.moisture_content_g_per_kgDry(abs(T.egr_fraction_cmd - egrVals(k)) < 1e-12);
    stats.meanMoisture(k) = mean(y, "omitnan");
    stats.minMoisture(k) = min(y, [], "omitnan");
    stats.maxMoisture(k) = max(y, [], "omitnan");
end
end

function T = addMoistureContentColumns(T)
if isempty(T)
    T.stack_in_T_C = zeros(0, 1);
    T.stack_in_p_kPa_abs = zeros(0, 1);
    T.xH2O_ca_in = zeros(0, 1);
    T.moisture_content_kg_per_kgDry = zeros(0, 1);
    T.moisture_content_g_per_kgDry = zeros(0, 1);
    return;
end

P0 = init_testbench_10kw_simplified_egr(1, "initial_noegr", false);
M_O2 = P0.M_O2_kg_mol;
M_N2 = P0.M_N2_kg_mol;
M_H2O = P0.M_H2O_kg_mol;

caseIdx = unique(T.boundary_case_index);
stackInTC = nan(height(T), 1);
for k = 1:numel(caseIdx)
    idx = find(T.boundary_case_index == caseIdx(k));
    P = init_testbench_10kw_simplified_egr(caseIdx(k), "initial_noegr", false);
    stackInTC(idx) = P.bench_stack_in_T_C;
end

stackInPAbs = T.pO2_ca_in_kPa ./ max(T.xO2_ca_in, 1e-12);
pH2O = T.RH_ca_in .* satKPaPlotLocal(stackInTC);
xH2O = pH2O ./ max(stackInPAbs, 1e-12);
xH2O = min(max(xH2O, 0), 0.999999);
xN2 = max(1 - T.xO2_ca_in - xH2O, 0);
dryMass = T.xO2_ca_in * M_O2 + xN2 * M_N2;
moistureKgKg = (xH2O * M_H2O) ./ max(dryMass, 1e-12);

T.stack_in_T_C = stackInTC;
T.stack_in_p_kPa_abs = stackInPAbs;
T.xH2O_ca_in = xH2O;
T.moisture_content_kg_per_kgDry = moistureKgKg;
T.moisture_content_g_per_kgDry = 1000 * moistureKgKg;
end

function p = satKPaPlotLocal(T)
p = 0.61121 .* exp((18.678 - T ./ 234.5) .* (T ./ (257.14 + T)));
end

function T = normalizeScanTable(T)
numericVars = ["boundary_case_index", "current_density_command_A_cm2", "egr_fraction_cmd", ...
    "V_cell_sim", "xO2_ca_in", "pO2_ca_in_kPa", "lambda_O2_actual", "RH_ca_in"];
for k = 1:numel(numericVars)
    name = numericVars(k);
    if ismember(name, string(T.Properties.VariableNames)) && ~isnumeric(T.(name))
        T.(name) = str2double(string(T.(name)));
    end
end
if ismember("oxygen_starvation_risk", string(T.Properties.VariableNames))
    T.oxygen_starvation_risk = parseLogicalColumn(T.oxygen_starvation_risk);
end
if ismember("gas_residual_ok", string(T.Properties.VariableNames))
    T.gas_residual_ok = parseLogicalColumn(T.gas_residual_ok);
else
    T.gas_residual_ok = true(height(T), 1);
end
end

function values = parseLogicalColumn(raw)
if islogical(raw)
    values = raw;
elseif isnumeric(raw)
    values = raw ~= 0;
else
    txt = lower(strtrim(string(raw)));
    values = txt == "true" | txt == "1";
end
end

function T = normalizeReferenceTable(T)
numericVars = ["current_density_command_A_cm2", "egr_fraction_cmd", "V_cell_sim"];
for k = 1:numel(numericVars)
    name = numericVars(k);
    if ismember(name, string(T.Properties.VariableNames)) && ~isnumeric(T.(name))
        T.(name) = str2double(string(T.(name)));
    end
end
end
