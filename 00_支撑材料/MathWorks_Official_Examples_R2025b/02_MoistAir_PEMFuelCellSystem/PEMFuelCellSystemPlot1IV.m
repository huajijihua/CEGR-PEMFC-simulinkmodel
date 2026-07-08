% Code to plot simulation results from PEMFuelCellSystem
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

% Copyright 2020 The MathWorks, Inc.

% Generate simulation results if they don't exist
if ~exist('simlog_PEMFuelCellSystem', 'var')
    sim('PEMFuelCellSystem')
end

% Reuse figure if it exists, else create new figure
if ~exist('h1_PEMFuelCellSystem', 'var') || ...
        ~isgraphics(h1_PEMFuelCellSystem, 'figure')
    h1_PEMFuelCellSystem = figure('Name', 'PEMFuelCellSystem');
end
figure(h1_PEMFuelCellSystem)
clf(h1_PEMFuelCellSystem)

plotIV(simlog_PEMFuelCellSystem)



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