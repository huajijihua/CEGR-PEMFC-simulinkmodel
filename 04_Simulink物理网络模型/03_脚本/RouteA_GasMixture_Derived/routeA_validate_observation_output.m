function report = routeA_validate_observation_output(out, registry)
% Validate registered output signals against one SimulationOutput.
% Presence alone is insufficient: time axis, finite data, shape, and explicit
% unit metadata are part of the Route A observation contract.

if nargin < 2 || isempty(registry)
    registry = routeA_observation_registry();
end
if ~isa(out, 'Simulink.SimulationOutput')
    error('RouteA:ObservationOutputType', ...
        'Observation validation requires a Simulink.SimulationOutput.');
end
try
    logsout = out.get('logsout');
    names = string(logsout.getElementNames);
catch ME
    error('RouteA:ObservationLogsoutUnavailable', ...
        'The SimulationOutput does not contain a readable logsout dataset: %s', ...
        ME.message);
end
outputNames = string(who(out));

report = struct();
report.schemaVersion = "RouteA_Observation_Output_Report_v01";
report.passed = true;
report.errors = strings(0, 1);
report.warnings = strings(0, 1);
report.present = strings(0, 1);
report.missingRequired = strings(0, 1);
report.missingOptional = strings(0, 1);
report.entries = repmat(entryReportTemplate(), 0, 1);

entries = registry.entries;
for idx = 1:numel(entries)
    entry = entries(idx);
    if entry.signalName == ""
        continue;
    end
    if entry.sourceType == "logsout"
        present = any(names == entry.signalName);
    elseif entry.sourceType == "SimulationOutput"
        present = any(outputNames == entry.signalName);
    else
        continue;
    end
    if present
        report.present(end + 1, 1) = entry.signalName;
        [values, readError] = readValues(out, logsout, entry, names, ...
            outputNames);
        item = entryReportTemplate();
        item.signalName = entry.signalName;
        item.required = entry.required;
        item.present = true;
        item.expectedShape = entry.shape;
        item.expectedUnit = entry.unit;
        if strlength(readError) > 0
            item.valid = false;
            item.error = readError;
            report = addEntryError(report, item, entry.required);
            continue;
        end
        item.actualUnit = signalUnit(values);
        item.actualShape = signalShape(values);
        item.timeCount = numel(values.Time);
        item.finite = all(isfinite(values.Time(:))) && ...
            all(isfinite(values.Data(:)));
        item.timeOrdered = isTimeOrdered(values.Time);
        item.shapeValid = shapeMatches(values, entry.shape);
        item.unitVerified = unitMatches(entry.unit, item.actualUnit);
        item.valid = item.finite && item.timeOrdered && item.shapeValid && ...
            item.unitVerified;
        item.warning = unitWarning(entry.unit, item.actualUnit);
        if ~item.finite
            item.error = "Registered observation contains NaN or Inf values.";
        elseif ~item.timeOrdered
            item.error = "Registered observation time values are not finite and ordered.";
        elseif ~item.shapeValid
            item.error = "Registered observation data shape disagrees with the registry.";
        elseif ~item.unitVerified
            item.error = "Registered observation unit disagrees with the registry.";
        elseif strlength(item.warning) > 0
            report.warnings(end + 1, 1) = item.warning;
        end
        if ~item.valid
            report = addEntryError(report, item, entry.required);
        end
        report.entries(end + 1) = item;
    elseif entry.required
        report.passed = false;
        report.missingRequired(end + 1, 1) = entry.signalName;
        report.errors(end + 1, 1) = ...
            "Required registered signal is missing: " + entry.signalName;
    else
        report.missingOptional(end + 1, 1) = entry.signalName;
        report.warnings(end + 1, 1) = ...
            "Optional registered signal is missing: " + entry.signalName;
    end
end
end

function [values, message] = readValues(out, logsout, entry, logNames, ...
        outputNames)
values = [];
message = "";
try
    if entry.sourceType == "logsout"
        if ~any(logNames == entry.signalName)
            message = "Registered logsout signal is unavailable.";
            return;
        end
        element = logsout.get(char(entry.signalName));
        values = element.Values;
    elseif entry.sourceType == "SimulationOutput"
        if ~any(outputNames == entry.signalName)
            message = "Registered SimulationOutput variable is unavailable.";
            return;
        end
        values = out.get(char(entry.signalName));
    else
        message = "Registered signal has an unsupported source type.";
        return;
    end
catch ME
    message = "Unable to read registered observation: " + string(ME.message);
    return;
end
if ~isa(values, 'timeseries')
    [values, converted] = structureWithTimeToTimeseries(values);
    if ~converted
        message = "Registered observation is not a timeseries or Structure With Time output.";
    end
end
end

function [signal, converted] = structureWithTimeToTimeseries(value)
signal = value;
converted = false;
if isstruct(value) && isfield(value, 'time') && isfield(value, 'signals') && ...
        isfield(value.signals, 'values')
    time = double(value.time(:));
    signal = timeseries(timeAlignedData(value.signals.values, time), time);
    converted = true;
elseif isstruct(value) && isfield(value, 'Time') && isfield(value, 'Data')
    time = double(value.Time(:));
    signal = timeseries(timeAlignedData(value.Data, time), time);
    converted = true;
end
end

function data = timeAlignedData(rawData, time)
timeCount = numel(time);
rawData = double(rawData);
dimensions = size(rawData);
timeDimension = find(dimensions == timeCount, 1, 'last');
if isempty(timeDimension)
    error('RouteA:ObservationShape', ...
        'Structure With Time data has no dimension matching its time vector.');
end
if timeDimension ~= 1
    order = [timeDimension, setdiff(1:ndims(rawData), timeDimension, 'stable')];
    rawData = permute(rawData, order);
end
data = reshape(rawData, timeCount, []);
end

function value = signalUnit(signal)
value = "";
try
    units = signal.DataInfo.Units;
    if isprop(units, 'Name')
        value = string(units.Name);
    elseif ischar(units) || isstring(units)
        value = string(units);
    end
catch
end
end

function value = signalShape(signal)
data = squeeze(signal.Data);
timeCount = numel(signal.Time);
if isscalar(data)
    value = "scalar";
elseif isvector(data) && numel(data) == timeCount
    value = "scalar";
else
    value = string(mat2str(size(data)));
end
end

function valid = shapeMatches(signal, expected)
expected = string(expected);
data = squeeze(signal.Data);
timeCount = numel(signal.Time);
if expected == "scalar"
    valid = (isscalar(data) && timeCount == 1) || ...
        (isvector(data) && numel(data) == timeCount);
elseif expected == "N-by-4"
    valid = (size(data, 1) == timeCount && size(data, 2) == 4) || ...
        (size(data, 2) == timeCount && size(data, 1) == 4);
else
    valid = true;
end
end

function valid = isTimeOrdered(time)
time = time(:);
valid = numel(time) >= 1 && all(diff(time) >= 0);
end

function valid = unitMatches(expected, actual)
expected = string(expected);
actual = string(actual);
if expected == "" || expected == "-"
    valid = true;
elseif actual == ""
    valid = true;
elseif expected == "-" && actual == "1"
    valid = true;
elseif (expected == "K" && actual == "deltaK") || ...
        (expected == "deltaK" && actual == "K")
    valid = true;
else
    valid = strcmpi(expected, actual);
end
end

function warning = unitWarning(expected, actual)
warning = "";
expected = string(expected);
actual = string(actual);
if expected ~= "" && expected ~= "-" && actual == ""
    warning = "Unit metadata is unavailable for registered signal; expected " + ...
        expected + ".";
end
end

function report = addEntryError(report, item, required)
if required
    report.passed = false;
    report.errors(end + 1, 1) = item.error;
else
    report.warnings(end + 1, 1) = item.error;
end
end

function item = entryReportTemplate()
item = struct( ...
    'signalName', "", ...
    'required', false, ...
    'present', false, ...
    'valid', false, ...
    'expectedShape', "", ...
    'actualShape', "", ...
    'expectedUnit', "", ...
    'actualUnit', "", ...
    'timeCount', 0, ...
    'finite', false, ...
    'timeOrdered', false, ...
    'shapeValid', false, ...
    'unitVerified', false, ...
    'warning', "", ...
    'error', "");
end
