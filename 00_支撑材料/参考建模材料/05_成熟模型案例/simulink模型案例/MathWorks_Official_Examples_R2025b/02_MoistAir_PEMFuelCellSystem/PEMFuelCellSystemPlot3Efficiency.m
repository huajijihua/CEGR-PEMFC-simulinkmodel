% Code to plot simulation results from PEMFuelCellSystem
%% Plot Description:
%
% This plot show the thermal efficiency of the fuel cell and its reactant
% utilization fraction. The thermal efficiency indicates the fraction of
% the hydrogen fuel's energy that the fuel cell has converted to useful
% electrical work. The theoretical maximum efficiency for a PEM fuel cell
% is 83%. However, actual efficiency is around 60% due to internal losses.
% Near maximum current, the efficiency drops to around 45%.
%
% The reactant utilization is the fraction of the reactants, H2 and O2,
% flowing into the fuel cell stack that has been consumed by the fuel cell.
% While higher utilization makes better use of the gases flowing through
% the fuel cell, it decreases the concentration of the reactants and thus
% reduces the voltage produced. Unconsumed O2 is vented to the environment,
% but unconsumed H2 is recirculated back to the anode to avoid waste.
% However, in practice, the H2 is periodically purged to remove
% contaminants.

% Copyright 2020 The MathWorks, Inc.

% Generate simulation results if they don't exist
if ~exist('simlog_PEMFuelCellSystem', 'var')
    sim('PEMFuelCellSystem')
end

% Reuse figure if it exists, else create new figure
if ~exist('h3_PEMFuelCellSystem', 'var') || ...
        ~isgraphics(h3_PEMFuelCellSystem, 'figure')
    h3_PEMFuelCellSystem = figure('Name', 'PEMFuelCellSystem');
end
figure(h3_PEMFuelCellSystem)
clf(h3_PEMFuelCellSystem)

plotEfficiencyUtilization(simlog_PEMFuelCellSystem)



% Plot efficiency and utilization
function plotEfficiencyUtilization(simlog)

% Get simulation results
t = simlog.Membrane_Electrode_Assembly.efficiency_HHV.series.time;
eta_HHV = simlog.Membrane_Electrode_Assembly.efficiency_HHV.series.values('1');
eta_LHV = simlog.Membrane_Electrode_Assembly.efficiency_LHV.series.values('1');
H2_consumed = simlog.Membrane_Electrode_Assembly.H2_consumed.series.values('g/s');
O2_consumed = simlog.Membrane_Electrode_Assembly.O2_consumed.series.values('g/s');
H2_in = simlog.Anode_Gas_Channels.Pipe_MA.mdot_g_A.series.values('g/s');
O2_in = simlog.Cathode_Gas_Channels.Pipe_MA.mdot_g_A.series.values('g/s');

% Compute utilization fraction
util_H2 = H2_consumed./H2_in;
util_O2 = O2_consumed./O2_in;

% Omit initial transients
idx = t >= 1;

% Plot results
handles(1) = subplot(2, 1, 1);
plot(t, eta_HHV*100, 'LineWidth', 1)
hold on
plot(t, eta_LHV*100, 'LineWidth', 1)
legend('Based on HHV', 'Based on LHV', 'Location', 'best')
grid on
title('Thermal Efficiency (%)')
handles(2) = subplot(2, 1, 2);
plot(t(idx), util_H2(idx)*100, 'LineWidth', 1)
hold on
plot(t(idx), util_O2(idx)*100, 'LineWidth', 1)
grid on
ylim([0 100])
legend('H_2', 'O_2', 'Location', 'best')
title('Reactant Utilization (%)')
xlabel('Time (s)')

linkaxes(handles, 'x')

end