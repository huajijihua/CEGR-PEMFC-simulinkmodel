function outputs = plot_testbench_10kw_simplified_constant_voltage_38A_cegr_study(saveOutputs)
%PLOT_TESTBENCH_10KW_SIMPLIFIED_CONSTANT_VOLTAGE_38A_CEGR_STUDY
% 绘制 38A 基准恒电压 CEGR 降电流研究总览图。
%
% Inputs:
%   04_验证结果/constant_voltage_38A_cegr_v01/constant_voltage_38A_cegr_scan.csv
%
% Outputs:
%   04_验证结果/constant_voltage_38A_cegr_v01/plots/constant_voltage_38A_cegr_overview.png
%   04_验证结果/constant_voltage_38A_cegr_v01/plots/constant_voltage_38A_cegr_overview.fig

if nargin < 1 || isempty(saveOutputs)
    saveOutputs = true;
end

scriptDir = fileparts(mfilename("fullpath"));
rootDir = fileparts(scriptDir);
resultDir = fullfile(rootDir, "04_验证结果", "constant_voltage_38A_cegr_v01");
plotDir = fullfile(resultDir, "plots");
if ~exist(plotDir, "dir")
    mkdir(plotDir);
end

scanFile = fullfile(resultDir, "constant_voltage_38A_cegr_scan.csv");
if ~isfile(scanFile)
    error("CEGR:SimplifiedBench:MissingConstantVoltageScan", ...
        "Cannot find %s. Run run_testbench_10kw_simplified_constant_voltage_38A_cegr_study first.", scanFile);
end

T = readtable(scanFile, "TextType", "string");
T = normalizeScanTable(T);
T = sortrows(T, "egr_fraction_cmd");

outputs = struct();
outputs.overview_png = fullfile(plotDir, "constant_voltage_38A_cegr_overview.png");
outputs.overview_fig = fullfile(plotDir, "constant_voltage_38A_cegr_overview.fig");
outputs.figure = plotOverview(T, outputs.overview_png, outputs.overview_fig, saveOutputs);

if saveOutputs
    fprintf("Saved constant-voltage CEGR overview: %s\n", outputs.overview_png);
    fprintf("Saved editable figure: %s\n", outputs.overview_fig);
else
    fprintf("Opened constant-voltage CEGR overview figure in MATLAB.\n");
end
end

function fig = plotOverview(T, pngFile, figFile, saveOutputs)
targetV = firstFinite(T.target_V_cell, 0.800);
baseCurrentA = firstFinite(T.base_current_A, 38.0);
basePowerW = targetV * baseCurrentA * 16.0;
valid = T.status == "ok" & T.normal_operation_ok;
risk = ~valid;

figVisible = "on";
if saveOutputs
    figVisible = "off";
end
fig = figure("Color", "w", "Visible", figVisible, ...
    "Name", "Constant voltage 38A CEGR current reduction overview");
fig.Position(3:4) = [1550 980];
tl = tiledlayout(fig, 2, 3, "TileSpacing", "compact", "Padding", "compact");
title(tl, "38A基准恒电压 CEGR 降电流总览");

blue = [0.10 0.36 0.75];
green = [0.05 0.55 0.28];
orange = [0.90 0.45 0.10];
red = [0.82 0.15 0.15];
gray = [0.35 0.35 0.35];

% 1. Required current.
ax = nexttile(tl, 1);
hold(ax, "on"); grid(ax, "on"); box(ax, "on");
plot(ax, T.egr_fraction_cmd, T.I_solution_A, "-o", ...
    "Color", blue, "LineWidth", 2.2, "MarkerFaceColor", "w", ...
    "DisplayName", "Solved current");
if any(risk)
    scatter(ax, T.egr_fraction_cmd(risk), T.I_solution_A(risk), 52, ...
        "x", "LineWidth", 1.5, "MarkerEdgeColor", red, ...
        "DisplayName", "Rejected point");
end
hBase = yline(ax, baseCurrentA, "--", "38 A baseline", ...
    "Color", gray, "LineWidth", 1.2, "LabelHorizontalAlignment", "left");
hBase.Annotation.LegendInformation.IconDisplayStyle = "off";
xlabel(ax, "EGR ratio (-)");
ylabel(ax, "Solved stack current (A)");
title(ax, "恒0.800 V/cell所需电流");
legend(ax, "Location", "southwest");

% 2. Reduction and economic proxy.
ax = nexttile(tl, 2);
hold(ax, "on"); grid(ax, "on"); box(ax, "on");
plot(ax, T.egr_fraction_cmd, T.I_reduction_pct, "-o", ...
    "Color", green, "LineWidth", 2.1, "MarkerFaceColor", "w", ...
    "DisplayName", "Current reduction");
plot(ax, T.egr_fraction_cmd, T.H2_reduction_pct, "--s", ...
    "Color", orange, "LineWidth", 1.8, "MarkerFaceColor", "w", ...
    "DisplayName", "Reaction H2 reduction");
hZero = yline(ax, 0, "k-", "LineWidth", 0.8);
hZero.Annotation.LegendInformation.IconDisplayStyle = "off";
xlabel(ax, "EGR ratio (-)");
ylabel(ax, "Reduction relative to 38 A (%)");
title(ax, "电流与反应氢耗下降比例");
legend(ax, "Location", "northwest");

% 3. Power.
ax = nexttile(tl, 3);
hold(ax, "on"); grid(ax, "on"); box(ax, "on");
yyaxis(ax, "left");
plot(ax, T.egr_fraction_cmd, T.P_stack_W, "-o", ...
    "LineWidth", 2.0, "MarkerFaceColor", "w", ...
    "DisplayName", "Stack power");
ylabel(ax, "Stack power (W)");
yyaxis(ax, "right");
plot(ax, T.egr_fraction_cmd, T.P_reduction_pct, "--s", ...
    "LineWidth", 1.8, "MarkerFaceColor", "w", ...
    "DisplayName", "Power reduction");
ylabel(ax, "Power reduction (%)");
hZero = yline(ax, 0, "k-", "LineWidth", 0.8);
hZero.Annotation.LegendInformation.IconDisplayStyle = "off";
xlabel(ax, "EGR ratio (-)");
title(ax, sprintf("功率口径：base %.1f W", basePowerW));
legend(ax, "Location", "best");

% 4. Oxygen dilution and lambda.
ax = nexttile(tl, 4);
hold(ax, "on"); grid(ax, "on"); box(ax, "on");
yyaxis(ax, "left");
plot(ax, T.egr_fraction_cmd, T.xO2_ca_in, "-o", ...
    "LineWidth", 2.0, "MarkerFaceColor", "w", ...
    "DisplayName", "xO2 in");
ylabel(ax, "Cathode inlet xO2 (-)");
yyaxis(ax, "right");
plot(ax, T.egr_fraction_cmd, T.lambda_O2_actual, "--s", ...
    "LineWidth", 1.8, "MarkerFaceColor", "w", ...
    "DisplayName", "lambdaO2");
hRisk = yline(ax, 1.2, ":", "lambdaO2=1.2", "LineWidth", 1.1, ...
    "LabelHorizontalAlignment", "left");
hRisk.Annotation.LegendInformation.IconDisplayStyle = "off";
ylabel(ax, "lambdaO2 (-)");
xlabel(ax, "EGR ratio (-)");
title(ax, "阴极入口氧稀释与氧计量比");
legend(ax, "Location", "best");

% 5. Voltage tracking.
ax = nexttile(tl, 5);
hold(ax, "on"); grid(ax, "on"); box(ax, "on");
plot(ax, T.egr_fraction_cmd, T.V_cell_sim, "-o", ...
    "Color", blue, "LineWidth", 2.0, "MarkerFaceColor", "w", ...
    "DisplayName", "V sim");
hTarget = yline(ax, targetV, "k--", "target 0.800 V", "LineWidth", 1.2, ...
    "LabelHorizontalAlignment", "left");
hTarget.Annotation.LegendInformation.IconDisplayStyle = "off";
hUpper = yline(ax, targetV + 5e-4, ":", "+/-0.5 mV", "Color", gray, "LineWidth", 1.0);
hLower = yline(ax, targetV - 5e-4, ":", "Color", gray, "LineWidth", 1.0);
hUpper.Annotation.LegendInformation.IconDisplayStyle = "off";
hLower.Annotation.LegendInformation.IconDisplayStyle = "off";
xlabel(ax, "EGR ratio (-)");
ylabel(ax, "Cell voltage (V)");
title(ax, "恒电压求解误差检查");
ylim(ax, [targetV - 0.0012, targetV + 0.0012]);
legend(ax, "Location", "best");

% 6. Validation status.
ax = nexttile(tl, 6);
axis(ax, "off");
summaryText = buildSummaryText(T, valid);
text(ax, 0, 1, join(summaryText, newline), ...
    "VerticalAlignment", "top", "FontName", "Consolas", ...
    "FontSize", 10, "Interpreter", "none");
title(ax, "Validation summary");

if saveOutputs
    exportgraphics(fig, pngFile, "Resolution", 180);
    savefig(fig, figFile);
end
end

function lines = buildSummaryText(T, valid)
normal = T(valid, :);
egr0 = T(abs(T.egr_fraction_cmd) < 1e-12 & T.status == "ok", :);
if isempty(normal)
    lines = [
        "No valid normal-operation points."
        sprintf("Total rows: %d", height(T))
        ];
    return;
end

[maxDrop, idx] = max(normal.I_reduction_A);
best = normal(idx, :);
lines = [
    sprintf("Rows:                 %d", height(T))
    sprintf("Valid rows:           %d", height(normal))
    sprintf("Rejected rows:        %d", height(T) - height(normal))
    sprintf("xO2 monotonic:        %d", all(T.xO2_monotonic_ok))
    ""
    sprintf("EGR=0 solved I:       %.4f A", firstFinite(egr0.I_solution_A, NaN))
    sprintf("EGR=0 vs 38A:         %.4f A", firstFinite(egr0.I_solution_A, NaN) - 38.0)
    ""
    sprintf("Max valid drop:       %.4f A", maxDrop)
    sprintf("At EGR:               %.2f", best.egr_fraction_cmd)
    sprintf("Current reduction:    %.2f %%", best.I_reduction_pct)
    sprintf("Power reduction:      %.2f %%", best.P_reduction_pct)
    sprintf("H2 proxy reduction:   %.2f %%", best.H2_reduction_pct)
    ""
    "Scope:"
    "Fixed 38A bench boundary."
    "Only cathode gas composition changes."
    "Auxiliary power is not included."
    ];
end

function value = firstFinite(x, fallback)
if isempty(x)
    value = fallback;
    return;
end
idx = find(isfinite(x), 1, "first");
if isempty(idx)
    value = fallback;
else
    value = x(idx);
end
end

function T = normalizeScanTable(T)
numericVars = [
    "target_V_cell"
    "base_current_A"
    "egr_fraction_cmd"
    "I_solution_A"
    "I_reduction_A"
    "I_reduction_pct"
    "V_cell_sim"
    "V_error_V"
    "P_stack_W"
    "P_reduction_pct"
    "H2_reduction_pct"
    "xO2_ca_in"
    "lambda_O2_actual"
    ];
for k = 1:numel(numericVars)
    name = numericVars(k);
    if ismember(name, string(T.Properties.VariableNames)) && ~isnumeric(T.(name))
        T.(name) = str2double(string(T.(name)));
    end
end

stringVars = ["status", "risk_label"];
for k = 1:numel(stringVars)
    name = stringVars(k);
    if ismember(name, string(T.Properties.VariableNames))
        T.(name) = string(T.(name));
    end
end

logicalVars = ["normal_operation_ok", "xO2_monotonic_ok"];
for k = 1:numel(logicalVars)
    name = logicalVars(k);
    if ismember(name, string(T.Properties.VariableNames))
        T.(name) = parseLogicalColumn(T.(name));
    else
        T.(name) = false(height(T), 1);
    end
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
