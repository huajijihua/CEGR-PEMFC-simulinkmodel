function profile = routeA_normalize_electrical_profile( ...
    profileSpec, boundaryType, options)
% Normalize one logical-time Route A runtime-command profile.

if nargin < 2 || isempty(boundaryType)
    boundaryType = "Current";
end
if nargin < 3 || isempty(options)
    options = struct();
end
if isTextScalar(profileSpec) && ~isTextScalar(boundaryType)
    swap = profileSpec;
    profileSpec = boundaryType;
    boundaryType = swap;
end
if ~isstruct(options) || numel(options) ~= 1
    error('RouteA:ElectricalProfileOptions', ...
        'Profile options must be a scalar struct.');
end

type = string(boundaryType);
if ~isscalar(type) || ~any(type == supportedProfileTypes())
    error('RouteA:ElectricalProfileType', ...
        'Unsupported Route A runtime-command profile type: %s.', type);
end
constantRequest = isConstantProfileRequest(profileSpec);

defaults = struct( ...
    'duration_s', 600, ...
    'commandStartOffset_s', 0.5, ...
    'startupRampDuration_s', 0, ...
    'initialValue', [], ...
    'minValue', [], ...
    'maxValue', [], ...
    'label', type);
names = fieldnames(options);
for idx = 1:numel(names)
    name = names{idx};
    if ~isfield(defaults, name)
        error('RouteA:ElectricalProfileOptionField', ...
            'Unsupported profile option: %s.', name);
    end
    defaults.(name) = options.(name);
end
validateattributes(defaults.duration_s, {'numeric'}, ...
    {'scalar', 'real', 'positive', 'finite'});
validateattributes(defaults.commandStartOffset_s, {'numeric'}, ...
    {'scalar', 'real', 'nonnegative', 'finite'});
validateattributes(defaults.startupRampDuration_s, {'numeric'}, ...
    {'scalar', 'real', 'nonnegative', 'finite'});
if defaults.commandStartOffset_s >= defaults.duration_s
    error('RouteA:ElectricalProfileOffset', ...
        'commandStartOffset_s must be less than duration_s.');
end
if defaults.commandStartOffset_s + defaults.startupRampDuration_s > ...
        defaults.duration_s
    error('RouteA:ElectricalProfileRampDuration', ...
        'The startup ramp must finish inside the profile duration.');
end

[rawTime, rawValue] = parseProfile(profileSpec, type, ...
    defaults.duration_s, defaults.label);
if ~isvector(rawTime) || ~isvector(rawValue)
    error('RouteA:ElectricalProfileVectorShape', ...
        'Profile time and value must each be one-dimensional vectors.');
end
rawTime = rawTime(:);
rawValue = rawValue(:);
if numel(rawTime) ~= numel(rawValue) || numel(rawTime) < 2
    error('RouteA:ElectricalProfileShape', ...
        'Profile time and value must contain at least two paired samples.');
end
if any(~isfinite(rawTime)) || any(~isfinite(rawValue))
    error('RouteA:ElectricalProfileFinite', ...
        'Profile time and value must be finite.');
end
if rawTime(1) < 0 || rawTime(end) > defaults.duration_s
    error('RouteA:ElectricalProfileTimeRange', ...
        'Profile time must lie inside [0,duration_s].');
end
if any(diff(rawTime) <= 0)
    error('RouteA:ElectricalProfileTimeOrder', ...
        'Profile time must be strictly increasing.');
end

[defaultMin, defaultMax, unit] = limitsForType(type);
validateProfileUnit(profileSpec, type, unit);
lower = defaults.minValue;
upper = defaults.maxValue;
if isempty(lower)
    lower = defaultMin;
end
if isempty(upper)
    upper = defaultMax;
end
if (~isempty(lower) && any(rawValue < lower)) || ...
        (~isempty(upper) && any(rawValue > upper))
    error('RouteA:ElectricalProfileBounds', ...
        '%s contains a value outside its allowed range.', defaults.label);
end

initialValue = defaults.initialValue;
if isempty(initialValue)
    initialValue = rawValue(1);
end
validateattributes(initialValue, {'numeric'}, ...
    {'scalar', 'real', 'finite'});
if (~isempty(lower) && initialValue < lower) || ...
        (~isempty(upper) && initialValue > upper)
    error('RouteA:ElectricalProfileInitialValue', ...
        'The initial value is outside the profile bounds.');
end
if ~constantRequest
    if rawTime(1) ~= 0
        error('RouteA:ElectricalProfileInitialTime', ...
            '%s explicit profile must start at logical time 0 s.', ...
            defaults.label);
    end
    if abs(rawValue(1) - initialValue) > ...
            1e-9 * max([1, abs(rawValue(1)), abs(initialValue)])
        error('RouteA:ElectricalProfileInitialCommand', ...
            ['%s explicit profile first value must equal the initial-state ', ...
            'baseline command.'], defaults.label);
    end
end

offset = defaults.commandStartOffset_s;
rampDuration = defaults.startupRampDuration_s;
if constantRequest && rampDuration > 0 && ...
        abs(rawValue(1) - initialValue) > 0
    rampEnd = offset + rampDuration;
    if offset == 0
        time = [0; rampEnd; defaults.duration_s];
        value = [initialValue; rawValue(1); rawValue(1)];
    else
        epsilon = min(max(1e-6, offset * 1e-6), offset / 2);
        time = [0; max(offset - epsilon, 0); offset; ...
            rampEnd; defaults.duration_s];
        value = [initialValue; initialValue; initialValue; ...
            rawValue(1); rawValue(1)];
    end
elseif offset > 0
    epsilon = min(max(1e-6, offset * 1e-6), offset / 2);
    shiftedTime = rawTime + offset;
    keep = shiftedTime <= defaults.duration_s;
    if ~any(keep)
        keep = true;
        shiftedTime = defaults.duration_s;
        rawValue = rawValue(end);
    end
    time = [0; max(offset - epsilon, 0); offset; shiftedTime(keep)];
    value = [initialValue; initialValue; rawValue(1); rawValue(keep)];
    if time(end) < defaults.duration_s
        time(end + 1, 1) = defaults.duration_s;
        value(end + 1, 1) = rawValue(end);
    end
else
    time = rawTime;
    value = rawValue;
end

[time, keep] = unique(time, 'stable');
value = value(keep);
if time(end) < defaults.duration_s
    time(end + 1, 1) = defaults.duration_s;
    value(end + 1, 1) = value(end);
end
if any(diff(time) <= 0) || any(~isfinite(value))
    error('RouteA:ElectricalProfileNormalizedOrder', ...
        'The normalized profile is not finite and strictly ordered.');
end

profile = struct();
profile.type = type;
profile.unit = unit;
profile.label = string(defaults.label);
profile.duration_s = defaults.duration_s;
profile.commandStartOffset_s = offset;
profile.initialValue = initialValue;
profile.startupRampDuration_s = rampDuration;
profile.time_s = time;
profile.value = value;
profile.workspaceValue = [time, value];
profile.range = [lower, upper];
end

function validateProfileUnit(spec, type, canonicalUnit)
if ~isstruct(spec) || numel(spec) ~= 1
    return;
end
if isfield(spec, 'profile')
    spec = spec.profile;
end
if ~isstruct(spec) || ~isfield(spec, 'unit') || isempty(spec.unit)
    return;
end
unit = string(spec.unit);
if ~isscalar(unit)
    error('RouteA:ElectricalProfileUnit', ...
        '%s unit must be a scalar text value.', type);
end
if type == "CEGR" || canonicalUnit == "-"
    accepted = ["-", "1", "ratio"];
else
    accepted = canonicalUnit;
end
if ~any(unit == accepted)
    error('RouteA:ElectricalProfileUnit', ...
        '%s requires unit %s; implicit conversion is not supported.', ...
        type, canonicalUnit);
end
end

function [time, value] = parseProfile(spec, type, duration, label)
if isnumeric(spec)
    if isscalar(spec)
        time = [0; duration];
        value = [spec; spec];
        return;
    end
    if ismatrix(spec) && size(spec, 2) == 2
        time = spec(:, 1);
        value = spec(:, 2);
        return;
    end
    error('RouteA:ElectricalProfileNumericShape', ...
        ['%s numeric profile must be scalar or an N-by-2 ', ...
        '[time_s, value] matrix.'], label);
end
if isa(spec, 'timeseries')
    time = spec.Time;
    value = spec.Data;
    return;
end
if ~isstruct(spec) || numel(spec) ~= 1
    error('RouteA:ElectricalProfileSpec', ...
        '%s must be a scalar, timeseries, or profile struct.', label);
end
if isfield(spec, 'profile')
    spec = spec.profile;
end
if isfield(spec, 'time_s') && isfield(spec, 'value')
    time = spec.time_s;
    value = spec.value;
    return;
end
if isfield(spec, 'kind')
    kind = lower(string(spec.kind));
elseif isfield(spec, 'shape')
    kind = lower(string(spec.shape));
else
    error('RouteA:ElectricalProfileSpecFields', ...
        '%s requires time_s/value or a supported kind.', label);
end
switch kind
    case "constant"
        requireField(spec, 'value', label);
        time = [0; duration];
        value = [spec.value; spec.value];
    case "step"
        requireField(spec, 'before', label);
        requireField(spec, 'after', label);
        if isfield(spec, 'at_s')
            stepTime = spec.at_s;
        elseif isfield(spec, 'stepTime_s')
            stepTime = spec.stepTime_s;
        else
            error('RouteA:ElectricalProfileStepTime', ...
                '%s step profile requires at_s.', label);
        end
        validateattributes(stepTime, {'numeric'}, ...
            {'scalar', 'real', 'nonnegative', '<=', duration, 'finite'});
        epsilon = min(max(1e-6, duration * 1e-9), duration / 2);
        if stepTime == 0
            time = [0; duration];
            value = [spec.after; spec.after];
        elseif stepTime >= duration
            time = [0; duration];
            value = [spec.before; spec.after];
        else
            preStepTime = stepTime - min(epsilon, stepTime / 2);
            if preStepTime <= 0
                time = [0; stepTime; duration];
                value = [spec.before; spec.after; spec.after];
            else
                time = [0; preStepTime; stepTime; duration];
                value = [spec.before; spec.before; spec.after; spec.after];
            end
        end
    case "ramp"
        requireField(spec, 'start_value', label);
        requireField(spec, 'end_value', label);
        if isfield(spec, 'start_s')
            startTime = spec.start_s;
        else
            startTime = 0;
        end
        if isfield(spec, 'end_s')
            endTime = spec.end_s;
        else
            endTime = duration;
        end
        validateattributes(startTime, {'numeric'}, ...
            {'scalar', 'real', 'nonnegative', '<', duration, 'finite'});
        validateattributes(endTime, {'numeric'}, ...
            {'scalar', 'real', '>', startTime, '<=', duration, 'finite'});
        if startTime > 0
            time = [0; startTime];
            value = [spec.start_value; spec.start_value];
        else
            time = 0;
            value = spec.start_value;
        end
        time(end + 1, 1) = endTime;
        value(end + 1, 1) = spec.end_value;
        if endTime < duration
            time(end + 1, 1) = duration;
            value(end + 1, 1) = spec.end_value;
        end
    otherwise
        error('RouteA:ElectricalProfileKind', ...
            'Unsupported %s profile kind: %s.', type, kind);
end
end

function requireField(spec, fieldName, label)
if ~isfield(spec, fieldName)
    error('RouteA:ElectricalProfileField', ...
        '%s profile is missing field %s.', label, fieldName);
end
end

function [lower, upper, unit] = limitsForType(type)
switch type
    case "Current"
        lower = 0;
        upper = 392;
        unit = "A";
    case "Power"
        lower = 0;
        upper = Inf;
        unit = "kW";
    case "Voltage"
        lower = 0;
        upper = Inf;
        unit = "V";
    case "CEGR"
        lower = 0;
        upper = 1;
        unit = "-";
    case {"CathodeSourcePressure", "CathodeOutletPressure", ...
            "AnodeSourcePressure", "AnodeInletPressure"}
        lower = eps;
        upper = Inf;
        unit = "MPa";
    case {"CathodeSourceTemperature", "AnodeSourceTemperature", ...
            "StackTemperature"}
        lower = -273.15;
        upper = Inf;
        unit = "degC";
    case {"CathodeSourceO2", "CathodeSourceH2O", "AnodeSourceH2", ...
            "CathodeHumidifierRH", "CathodeHumidifierGain", ...
            "AnodeHumidifierRH", "AnodeRecirculationBase", ...
            "AnodePurgeEnable", "AnodePurgeOnN2", "AnodePurgeOffN2", ...
            "AirDirectCommand"}
        lower = 0;
        upper = 1;
        unit = "-";
    case "AirTargetMdot"
        lower = 0;
        upper = Inf;
        unit = "kg/s";
    case "AirTargetOer"
        lower = 0;
        upper = Inf;
        unit = "-";
    case "AnodeRecirculationGain"
        lower = 0;
        upper = Inf;
        unit = "1/A";
    otherwise
        error('RouteA:ElectricalProfileType', ...
            'Unsupported Route A runtime-command profile type: %s.', type);
end
end

function types = supportedProfileTypes()
types = ["Current", "Power", "Voltage", "CEGR", ...
    "CathodeSourcePressure", "CathodeSourceTemperature", ...
    "CathodeSourceO2", "CathodeSourceH2O", "AirTargetMdot", ...
    "AirTargetOer", "AirDirectCommand", "CathodeOutletPressure", ...
    "CathodeHumidifierRH", "CathodeHumidifierGain", ...
    "AnodeSourcePressure", "AnodeSourceTemperature", "AnodeSourceH2", ...
    "AnodeInletPressure", "AnodeHumidifierRH", ...
    "AnodeRecirculationBase", "AnodeRecirculationGain", ...
    "AnodePurgeEnable", "AnodePurgeOnN2", "AnodePurgeOffN2", ...
    "StackTemperature"];
end

function tf = isTextScalar(value)
tf = ischar(value) || (isstring(value) && isscalar(value));
end

function tf = isConstantProfileRequest(spec)
if isnumeric(spec)
    tf = isscalar(spec);
    return;
end
if ~isstruct(spec) || numel(spec) ~= 1
    tf = false;
    return;
end
if isfield(spec, 'profile')
    spec = spec.profile;
end
if isfield(spec, 'time_s') && isfield(spec, 'value')
    tf = false;
    return;
end
if isfield(spec, 'kind')
    kind = lower(string(spec.kind));
elseif isfield(spec, 'shape')
    kind = lower(string(spec.shape));
else
    tf = false;
    return;
end
tf = isscalar(kind) && kind == "constant";
end
