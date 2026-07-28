function results = routeA_panel_extract_results(out, simCase)
% Extract KPI and time-series data from simulation output (panel helper)
%
% Inputs:
%   out      - Simulink.SimulationOutput from sim()
%   simCase  - the simCase struct used for this run
%
% Output:
%   results  - struct with fields:
%              .caseId
%              .voltage_V       - tail-window mean voltage [V]
%              .current_A       - tail-window mean current [A]
%              .power_kW        - tail-window mean power [kW]
%              .oer             - target OER from simCase
%              .cegr_ratio      - target cEGR ratio from simCase
%              .voltage_ts      - timeseries object for voltage
%              .current_ts      - timeseries object for current
%              .power_ts        - timeseries object for power
%
% Tail window is defined as the last 60 seconds of the simulation.
%
% See also: routeA_panel_build_simulation_input

%% Extract logsout
logsout = out.get('logsout');
if isempty(logsout)
    error('RouteA:PanelMissingLogsout', ...
        'Simulation output does not contain the logsout dataset.');
end

% Get voltage and current time series
vTs = requiredLoggedTimeseries(logsout, 'routeA_stack_voltage_V');
iTs = requiredLoggedTimeseries(logsout, 'routeA_stack_current_A');
if numel(vTs.Time) ~= numel(iTs.Time) || ...
        any(vTs.Time ~= iTs.Time)
    error('RouteA:PanelElectricalSignalTime', ...
        'Voltage and current logs do not share the same time base.');
end

%% Compute tail-window KPI (last 60s)
tMax = max(vTs.Time);
tailWindow_s = 60;
tailMask = vTs.Time >= (tMax - tailWindow_s);
if ~any(tailMask)
    error('RouteA:PanelEmptyTailWindow', ...
        'The result does not contain samples in the final %.3g s window.', ...
        tailWindow_s);
end

vTail = vTs.Data(tailMask);
iTail = iTs.Data(tailMask);

vMean = mean(vTail);
iMean = mean(iTail);

%% Compute or read power time series
% Prefer the model's logged electrical-power signal. The V*I fallback keeps
% the panel usable for legacy logging configurations and is explicitly marked.
powerSource = 'derived_V_times_I';
if any(strcmp(logsout.getElementNames, 'routeA_stack_power_kW'))
    pTs = routeA_stack_electrical_power_timeseries(logsout);
    if numel(pTs.Time) ~= numel(vTs.Time) || any(pTs.Time ~= vTs.Time)
        error('RouteA:PanelPowerSignalTime', ...
            'The logged power signal does not share the electrical time base.');
    end
    pTs.Name = 'Stack Power';
    pTs.DataInfo.Units = 'kW';
    pData = pTs.Data;
    powerSource = 'logged_routeA_stack_power_kW';
else
    pData = vTs.Data .* iTs.Data * 1e-3;  % [kW]
    pTs = timeseries(pData, vTs.Time, 'Name', 'Stack Power');
    pTs.DataInfo.Units = 'kW';
end
pMean = mean(pData(tailMask));

%% Build results struct
results = struct();
results.caseId = simCase.caseId;
results.voltage_V = vMean;
results.current_A = iMean;
results.power_kW = pMean;
results.oer = simCase.controls.cathode.targetOer;
results.cegr_ratio = simCase.controls.cegr.targetRatio;
results.voltage_ts = vTs;
results.current_ts = iTs;
results.power_ts = pTs;
results.power_source = powerSource;

end

function signal = requiredLoggedTimeseries(logsout, name)
if ~any(strcmp(logsout.getElementNames, name))
    error('RouteA:PanelMissingSignal', ...
        'Required logged signal %s is unavailable.', name);
end
element = logsout.get(name);
if isempty(element) || isempty(element.Values)
    error('RouteA:PanelEmptySignal', ...
        'Required logged signal %s is empty.', name);
end
signal = element.Values;
if ~isa(signal, 'timeseries') || isempty(signal.Time) || isempty(signal.Data)
    error('RouteA:PanelSignalType', ...
        'Logged signal %s is not a nonempty timeseries.', name);
end
end
