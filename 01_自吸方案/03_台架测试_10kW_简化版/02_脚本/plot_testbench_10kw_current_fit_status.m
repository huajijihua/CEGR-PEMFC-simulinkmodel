% plot_testbench_10kw_current_fit_status
% -------------------------------------------------------------------------
% Purpose:
%   Plot the current simplified bench calibration status from saved CSV
%   result tables. This script does not run Simulink and does not update
%   calibration parameters. It is intended as a quick visual review after
%   temperature and pressure calibration.
%
% Inputs:
%   04_验证结果/temperature_fit_v01/temperature_fit_fitted.csv
%   04_验证结果/pressure_fit_v01/pressure_fit_final.csv
%   04_验证结果/voltage_fit_v01/voltage_fit_noegr_residuals.csv
%   04_验证结果/voltage_fit_v01/voltage_fit_egr_validation.csv
%
% Outputs:
%   04_验证结果/fit_overview_v01/current_fit_overview.png
%   04_验证结果/fit_overview_v01/current_fit_overview.fig
%   04_验证结果/fit_overview_v01/current_fit_summary.csv

clear; clc;

scriptDir = fileparts(mfilename("fullpath"));
projectDir = fileparts(scriptDir);
resultDir = fullfile(projectDir, "04_验证结果");
outDir = fullfile(resultDir, "fit_overview_v01");
if ~exist(outDir, "dir")
    mkdir(outDir);
end

tempFile = fullfile(resultDir, "temperature_fit_v01", "temperature_fit_fitted.csv");
pressFile = fullfile(resultDir, "pressure_fit_v01", "pressure_fit_final.csv");
voltageNoEgrFile = fullfile(resultDir, "voltage_fit_v01", "voltage_fit_noegr_residuals.csv");
voltageEgrFile = fullfile(resultDir, "voltage_fit_v01", "voltage_fit_egr_validation.csv");

T = readtable(tempFile, "TextType", "string");
P = readtable(pressFile, "TextType", "string");
Vn = readtable(voltageNoEgrFile, "TextType", "string");
Ve = readtable(voltageEgrFile, "TextType", "string");

fig = figure("Color", "w", "Visible", "off", ...
    "Name", "Current simplified bench fit overview");
fig.Position(3:4) = [1500 980];
tl = tiledlayout(fig, 3, 3, "TileSpacing", "compact", "Padding", "compact");
title(tl, "Current Simplified Bench Fit Status");

% 1. Stack temperature: fitted average stack temperature against target.
nexttile;
scatter(T.stack_T_target_C, T.stack_T_sim_C, markerSize(T), T.current_density_A_cm2, "filled");
hold on; plotIdentity(T.stack_T_target_C, T.stack_T_sim_C);
grid on; axis square;
xlabel("T stack target (degC)");
ylabel("T stack sim (degC)");
title("Stack temperature");
cb = colorbar; cb.Label.String = "j (A/cm2)";

% 2. Stack outlet temperature, because this is directly measured.
nexttile;
scatter(T.stack_out_T_exp_C, T.stack_out_T_sim_C, markerSize(T), T.current_density_A_cm2, "filled");
hold on; plotIdentity(T.stack_out_T_exp_C, T.stack_out_T_sim_C);
grid on; axis square;
xlabel("T outlet exp (degC)");
ylabel("T outlet sim (degC)");
title("Stack outlet temperature");
cb = colorbar; cb.Label.String = "j (A/cm2)";

% 3. Temperature residuals against current density.
nexttile;
plotResidualByGroup(T.current_density_A_cm2, T.stack_T_err_C, T.is_no_egr);
hold on;
plotResidualByGroup(T.current_density_A_cm2, T.stack_out_T_err_C, T.is_no_egr, "--");
grid on; yline(0, "k-");
xlabel("j (A/cm2)");
ylabel("Error (degC)");
title("Temperature residuals");
legend("Tstack no-EGR", "Tstack EGR", "Tout no-EGR", "Tout EGR", ...
    "Location", "best");

% 4. Cathode internal pressure target against model pressure.
nexttile;
scatter(P.pCa_target_abs_kPa, P.pCa_model_abs_kPa, markerSize(P), P.current_density_A_cm2, "filled");
hold on; plotIdentity(P.pCa_target_abs_kPa, P.pCa_model_abs_kPa);
grid on; axis square;
xlabel("pCa target abs (kPa)");
ylabel("pCa model abs (kPa)");
title("Cathode channel pressure");
cb = colorbar; cb.Label.String = "j (A/cm2)";

% 5. Anode internal pressure target against model pressure.
nexttile;
scatter(P.pAn_target_abs_kPa, P.pAn_model_abs_kPa, markerSize(P), P.current_density_A_cm2, "filled");
hold on; plotIdentity(P.pAn_target_abs_kPa, P.pAn_model_abs_kPa);
grid on; axis square;
xlabel("pAn target abs (kPa)");
ylabel("pAn model abs (kPa)");
title("Anode channel pressure");
cb = colorbar; cb.Label.String = "j (A/cm2)";

% 6. Pressure residuals against current density.
nexttile;
plotResidualByGroup(P.current_density_A_cm2, P.pCa_err_kPa, P.is_no_egr);
hold on;
plotResidualByGroup(P.current_density_A_cm2, P.pAn_err_kPa, P.is_no_egr, "--");
grid on; yline(0, "k-");
xlabel("j (A/cm2)");
ylabel("Error (kPa)");
title("Pressure residuals");
legend("pCa no-EGR", "pCa EGR", "pAn no-EGR", "pAn EGR", ...
    "Location", "best");

% 7. Cooling curve now used by the temperature calibration.
nexttile;
validFlow = isfinite(T.coolant_flow_L_min) & isfinite(T.h_curve_W_K);
[flowUnique, ia] = unique(T.coolant_flow_L_min(validFlow));
hUnique = T.h_curve_W_K(validFlow);
hUnique = hUnique(ia);
plot(flowUnique, hUnique, "o-", "LineWidth", 1.2);
grid on;
xlabel("Coolant flow (L/min)");
ylabel("h curve (W/K)");
title("Cooling curve");

% 8. Voltage status is plotted only as context after thermal/pressure updates.
nexttile;
plot(Vn.current_density_A_cm2, Vn.err_V .* 1000, "o", "LineWidth", 1.1);
hold on;
plot(Ve.current_density_A_cm2, Ve.err_V .* 1000, "s", "LineWidth", 1.1);
grid on; yline(0, "k-");
xlabel("j (A/cm2)");
ylabel("V sim - V exp (mV)");
title("Saved voltage residual context");
legend("no-EGR fit", "EGR validation", "Location", "best");

% 9. Key residual metrics as text.
nexttile;
axis off;
summary = buildSummary(T, P, Vn, Ve);
text(0, 1, join(summary.displayText, newline), ...
    "VerticalAlignment", "top", "FontName", "Consolas", "FontSize", 10, ...
    "Interpreter", "none");
title("Summary metrics");

pngFile = fullfile(outDir, "current_fit_overview.png");
figFile = fullfile(outDir, "current_fit_overview.fig");
exportgraphics(fig, pngFile, "Resolution", 180);
savefig(fig, figFile);

summaryFile = fullfile(outDir, "current_fit_summary.csv");
writetable(summary.table, summaryFile);

fprintf("Saved overview figure: %s\n", pngFile);
fprintf("Saved editable figure: %s\n", figFile);
fprintf("Saved summary table: %s\n", summaryFile);

function s = markerSize(tbl)
    s = 35 + zeros(height(tbl), 1);
end

function plotIdentity(x, y)
    v = [x(:); y(:)];
    v = v(isfinite(v));
    lo = min(v);
    hi = max(v);
    pad = max((hi - lo) * 0.05, eps);
    plot([lo - pad, hi + pad], [lo - pad, hi + pad], "k--", "LineWidth", 1);
end

function plotResidualByGroup(x, y, isNoEgr, lineStyle)
    if nargin < 4
        lineStyle = "-";
    end
    lineStyle = char(lineStyle);
    noEgr = logical(isNoEgr);
    wasHold = ishold;
    plot(x(noEgr), y(noEgr), ['o' lineStyle], "LineWidth", 1.1);
    hold on;
    plot(x(~noEgr), y(~noEgr), ['s' lineStyle], "LineWidth", 1.1);
    if ~wasHold
        hold off;
    end
end

function out = buildSummary(T, P, Vn, Ve)
    metric = [
        "T_stack_rmse_C"
        "T_stack_max_abs_C"
        "T_out_rmse_C"
        "T_out_max_abs_C"
        "pCa_rmse_kPa"
        "pCa_max_abs_kPa"
        "pAn_rmse_kPa"
        "pAn_max_abs_kPa"
        "V_noEGR_rmse_mV"
        "V_noEGR_max_abs_mV"
        "V_EGR_rmse_mV"
        "V_EGR_max_abs_mV"
        ];

    value = [
        rmse(T.stack_T_err_C)
        max(abs(T.stack_T_err_C))
        rmse(T.stack_out_T_err_C)
        max(abs(T.stack_out_T_err_C))
        rmse(P.pCa_err_kPa)
        max(abs(P.pCa_err_kPa))
        rmse(P.pAn_err_kPa)
        max(abs(P.pAn_err_kPa))
        1000 * rmse(Vn.err_V)
        1000 * max(abs(Vn.err_V))
        1000 * rmse(Ve.err_V)
        1000 * max(abs(Ve.err_V))
        ];

    out.table = table(metric, value);
    out.displayText = strings(numel(metric), 1);
    for k = 1:numel(metric)
        out.displayText(k) = sprintf("%-22s %9.4g", metric(k), value(k));
    end
end

function y = rmse(x)
    x = x(isfinite(x));
    y = sqrt(mean(x .^ 2));
end
