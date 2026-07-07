% Code to plot simulation results from PEMFuelCellSystemWithACustomLibrary
%% Plot Description:
%
% This plot shows the current-voltage (i-v) curve of a fuel cell in the
% stack. As the current ramps up, an initial drop in voltage occurs due to
% electrode activation losses, followed by a gradual decrease in voltage
% due to Ohmic resistances. Near maximum current, a sharp drop in voltage
% occurs due to gas-transport-related losses.
%
% This plot also shows the power produced by the cell. When the ramp
% scenario is selected, the power increases until a maximum power output,
% then decreases due to the high losses near maximum current.

% Copyright 2020-2021 The MathWorks, Inc.

% Generate simulation results if they don't exist
if ~exist('simlog_PEMFuelCellSystemWithACustomLibrary', 'var')
    sim('PEMFuelCellSystemWithACustomLibrary')
end

% Reuse figure if it exists, else create new figure
if ~exist('h1_PEMFuelCellSystemWithACustomLibrary', 'var') || ...
        ~isgraphics(h1_PEMFuelCellSystemWithACustomLibrary, 'figure')
    h1_PEMFuelCellSystemWithACustomLibrary = figure('Name', 'PEMFuelCellSystemWithACustomLibrary');
end
figure(h1_PEMFuelCellSystemWithACustomLibrary)
clf(h1_PEMFuelCellSystemWithACustomLibrary)

plotIV(simlog_PEMFuelCellSystemWithACustomLibrary)



% Plot fuel cell i-v curve
function plotIV(simlog)

% Get simulation results
i_cell = simlog.Membrane_Electrode_Assembly.i_cell.series.values('A/cm^2');
v_cell = simlog.Membrane_Electrode_Assembly.v_cell.series.values('V');

% Plot results
yyaxis left
plot(i_cell, v_cell, 'LineWidth', 1)
grid on
title('Fuel Cell I-V Curve')
ylabel('Cell Voltage (V)')
yyaxis right
plot(i_cell, i_cell.*v_cell, 'LineWidth', 1)
ylabel('Power Density (W/cm^2)')
xlabel('Current Density (A/cm^2)')
set(gca, 'LineWidth', 1)

end