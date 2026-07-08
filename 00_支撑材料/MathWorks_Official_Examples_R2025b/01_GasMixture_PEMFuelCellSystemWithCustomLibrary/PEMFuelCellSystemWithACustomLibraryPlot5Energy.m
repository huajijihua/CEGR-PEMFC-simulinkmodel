% Code to plot simulation results from PEMFuelCellSystemWithACustomLibrary
%% Plot Description:
%
% This plot shows the mass of hydrogen used during operation and the
% corresponding decrease in the hydrogen tank pressure. The energy of the
% consumed hydrogen fuel is converted to electrical energy.

% Copyright 2020-2021 The MathWorks, Inc.

% Generate simulation results if they don't exist
if ~exist('simlog_PEMFuelCellSystemWithACustomLibrary', 'var')
    sim('PEMFuelCellSystemWithACustomLibrary')
end

% Reuse figure if it exists, else create new figure
if ~exist('h5_PEMFuelCellSystemWithACustomLibrary', 'var') || ...
        ~isgraphics(h5_PEMFuelCellSystemWithACustomLibrary, 'figure')
    h5_PEMFuelCellSystemWithACustomLibrary = figure('Name', 'PEMFuelCellSystemWithACustomLibrary');
end
figure(h5_PEMFuelCellSystemWithACustomLibrary)
clf(h5_PEMFuelCellSystemWithACustomLibrary)

plotEnergy(simlog_PEMFuelCellSystemWithACustomLibrary, ...
    getVariable(get_param('PEMFuelCellSystemWithACustomLibrary', 'ModelWorkspace'), 'tank_V'))



% Plot energy produced and consumed
function plotEnergy(simlog, tank_V)

% Convert from l to m^3
tank_V = tank_V * 1e-3;

% Get simulation results
t = simlog.Hydrogen_Source.Fuel_Tank.p_I.series.time;
p_fuel = simlog.Hydrogen_Source.Fuel_Tank.p_I.series.values('MPa');
rho_fuel = simlog.Hydrogen_Source.Fuel_Tank.rho_I.series.values('kg/m^3');
power_elec = simlog.Membrane_Electrode_Assembly.power_elec.series.values('kW');
power_dissipated = simlog.Membrane_Electrode_Assembly.power_dissipated.series.values('kW');

M_consumed = (rho_fuel(1) - rho_fuel)*tank_V;
E_fuel = cumtrapz(t, power_elec + power_dissipated);
E_produced = cumtrapz(t, power_elec);

% Plot results
handles(1) = subplot(3, 1, 1);
plot(t, p_fuel, 'LineWidth', 1)
grid on
title('Fuel Tank Pressure (MPa)')
handles(2) = subplot(3, 1, 2);
plot(t, M_consumed, 'LineWidth', 1)
grid on
title('Tank Hydrogen Consumed (kg)')
handles(2) = subplot(3, 1, 3);
plot(t, E_fuel*1e-3, 'LineWidth', 1)
hold on
plot(t, E_produced*1e-3, 'LineWidth', 1)
grid on
legend('Hydrogen Consumed', 'Energy Produced', 'Location', 'best')
title('Energy (MJ)')
xlabel('Time (s)')

linkaxes(handles, 'x')

end