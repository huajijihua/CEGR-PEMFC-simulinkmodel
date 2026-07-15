% Code to plot simulation results from PEMFuelCellSystemWithACustomLibrary
%% Plot Description:
%
% This plot shows the molar concentrations of Nitrogen and hydrogen in the  
% anode gas channel and the hydrogen lost through the purge valve opening.

% Copyright 2020-2021 The MathWorks, Inc.

% Generate simulation results if they don't exist
if ~exist('simlog_PEMFuelCellSystemWithACustomLibrary', 'var')
    sim('PEMFuelCellSystemWithACustomLibrary')
end

% Reuse figure if it exists, else create new figure
if ~exist('h6_PEMFuelCellSystemWithACustomLibrary', 'var') || ...
        ~isgraphics(h6_PEMFuelCellSystemWithACustomLibrary, 'figure')
    h6_PEMFuelCellSystemWithACustomLibrary = figure('Name', 'PEMFuelCellSystemWithACustomLibrary');
end
figure(h6_PEMFuelCellSystemWithACustomLibrary)
clf(h6_PEMFuelCellSystemWithACustomLibrary)

plotMolarConcentrations(simlog_PEMFuelCellSystemWithACustomLibrary, 'PEMFuelCellSystemWithACustomLibrary')



% Plot efficiency and utilization
function plotMolarConcentrations(simlog, model)

% Get vector of molar masses
M= eval( get_param([model '/Gas Mixture Properties'], 'M') ); % [kg/mol]

% Get simulation results
t           =  simlog.Membrane_Electrode_Assembly.A.x_i.series.time;

% Species mass fractions
x_anode   =  simlog.Membrane_Electrode_Assembly.A.x_i.series.values('1');

% Species mole fractions
Mmatrix= repmat(M(:)', length(t), 1);
y_anode= x_anode./Mmatrix./sum(x_anode./Mmatrix, 2);

% Purge valve opening and mass flow
valve_control    = simlog.Anode_Exhaust.Max_Area.I.series.values('1');
valve_activation = valve_control./max(valve_control);
valve_mdot       = simlog.Anode_Exhaust.Purge_Valve.mdot_A_i.series.values('kg/s');

% Cummulative Hydrogen lost through purge valve
Valve_mass_H2= cumtrapz(t, valve_mdot(:,3)); % [kg]

% Plot results
handles(1) = subplot(2, 1, 1);
plot(t, y_anode(:,[1,3]), 'LineWidth', 1)
hold on
plot(t, valve_activation, '--');
grid on
ylim([0 1])
title('Anode Mole Fractions')
legend('Nitrogen', 'Hydrogen', 'Purge Valve Activated', 'Location', 'best')

handles(2)= subplot(2, 1, 2);
plot(t, Valve_mass_H2, 'LineWidth', 1)
grid on
title('Hydrogen Lost Through Purge Valve (kg)')
xlabel('Time (s)')

linkaxes(handles, 'x')

end