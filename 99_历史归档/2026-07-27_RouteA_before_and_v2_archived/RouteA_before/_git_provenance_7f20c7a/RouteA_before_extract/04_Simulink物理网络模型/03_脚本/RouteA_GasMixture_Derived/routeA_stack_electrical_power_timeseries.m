function power = routeA_stack_electrical_power_timeseries(logsout)
% Return the electrical-power component of the Measurements P output.
%
% routeA_stack_power_kW carries [P_stack_kW, Q_stack]. The first component
% is the stack electrical power used by constant-power studies.

element = logsout.get('routeA_stack_power_kW');
if isempty(element) || isempty(element.Values)
    error('RouteA:MissingStackPowerSignal', ...
        'The required logged signal routeA_stack_power_kW is unavailable.');
end
raw = element.Values;
data = squeeze(raw.Data);
time = raw.Time(:);
if isvector(data)
    data = data(:);
elseif size(data, 1) ~= numel(time)
    data = data.';
end
if size(data, 1) ~= numel(time) || size(data, 2) < 1
    error('RouteA:StackPowerSignalShape', ...
        'The logged stack-power signal has an unexpected shape.');
end
power = timeseries(data(:, 1), time);
end
