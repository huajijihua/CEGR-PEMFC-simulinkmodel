% Code to plot simulation results from PEMFuelCellSystem
%% Plot Description:
%
% This plot shows the temperatures at various locations in the system. The
% fuel cell stack temperature is maintained at a maximum of 80 degC by the
% cooling system. Fuel flowing to the anode is warmed by the recirculated
% flow. Air flowing to the cathode is warmed by the compressor.
%
% Maintaining an optimal temperature is critical to the operation of the
% fuel cell because higher temperatures lower the relative humidity which
% increases the membrane resistance. In this model, the cooling system is
% operated by a simple control of the coolant pump flow rate. The plot
% shows the temperature of the coolant after it has absorbed heat from the
% fuel cell stack and after it has rejected heat in the radiator.

% Copyright 2020 The MathWorks, Inc.

% Generate simulation results if they don't exist
if ~exist('simlog_PEMFuelCellSystem', 'var')
    sim('PEMFuelCellSystem')
end

% Reuse figure if it exists, else create new figure
if ~exist('h4_PEMFuelCellSystem', 'var') || ...
        ~isgraphics(h4_PEMFuelCellSystem, 'figure')
    h4_PEMFuelCellSystem = figure('Name', 'PEMFuelCellSystem');
end
figure(h4_PEMFuelCellSystem)
clf(h4_PEMFuelCellSystem)

plotTemperature(simlog_PEMFuelCellSystem)



% Plot temperature in fuel cell and coolant system
function plotTemperature(simlog)

% Get simulation results
t = simlog.MEA_Thermal_Mass.T.series.time;
T_stack = simlog.MEA_Thermal_Mass.T.series.values('degC');
T_anode = simlog.Anode_Gas_Channels.Pipe_MA.A.T.series.values('degC');
T_cathode = simlog.Cathode_Gas_Channels.Pipe_MA.A.T.series.values('degC');
T_coolant = simlog.Cooling_System.Fuel_Cell_Coolant_Channels.T_I.series.values('degC');
T_radiator = simlog.Cooling_System.Radiator.T_I.series.values('degC');
mdot_pump = simlog.Cooling_System.Pump.mdot_A.series.values('kg/s');

% Plot results
handles(1) = subplot(2, 1, 1);
plot(t, T_stack, 'LineWidth', 1)
hold on
plot(t, T_anode, 'LineWidth', 1)
plot(t, T_cathode, 'LineWidth', 1)
plot(t, T_coolant, 'LineWidth', 1)
plot(t, T_radiator, 'LineWidth', 1)
grid on
legend('Stack', 'Anode Inflow', 'Cathode Inflow', 'Coolant at Stack', 'Coolant at Radiator', 'Location', 'best')
title('Temperature (degC)')
handles(2) = subplot(2, 1, 2);
plot(t, mdot_pump, 'LineWidth', 1)
grid on
title('Coolant Pump Mass Flow Rate (kg/s)')
xlabel('Time (s)')

linkaxes(handles, 'x')

end