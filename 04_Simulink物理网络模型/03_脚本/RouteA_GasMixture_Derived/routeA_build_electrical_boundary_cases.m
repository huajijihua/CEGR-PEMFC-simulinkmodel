function cases = routeA_build_electrical_boundary_cases(boundaryType, caseSpecs)
% Build generic study cases without running or modifying the Simulink model.
%
% boundaryType is one of Current, Power, or Voltage. caseSpecs may be a
% struct array or a cell array of scalar structs. Each spec must provide
% caseId and profile; optional control structs are copied unchanged for the
% shared routeA_prepare_electrical_boundary_input contract.

type = canonicalBoundaryType(boundaryType);
if isempty(caseSpecs)
    error('RouteA:ElectricalBoundaryCaseSpecs', ...
        'caseSpecs must contain at least one case.');
end
if iscell(caseSpecs)
    count = numel(caseSpecs);
elseif isstruct(caseSpecs)
    count = numel(caseSpecs);
else
    error('RouteA:ElectricalBoundaryCaseSpecs', ...
        'caseSpecs must be a struct array or a cell array of structs.');
end

template = struct( ...
    'caseId', "", ...
    'boundary', struct('type', type, 'profile', []), ...
    'cegr', [], ...
    'air', [], ...
    'cathode', [], ...
    'anode', [], ...
    'thermal', [], ...
    'controller', [], ...
    'acceptance', [], ...
    'loadId', "", ...
    'currentDensity_A_cm2', NaN);
cases = repmat(template, count, 1);

for idx = 1:count
    if iscell(caseSpecs)
        spec = caseSpecs{idx};
    else
        spec = caseSpecs(idx);
    end
    if ~isstruct(spec) || ~isscalar(spec)
        error('RouteA:ElectricalBoundaryCaseSpecType', ...
            'Each case specification must be a scalar struct.');
    end
    if ~isfield(spec, 'caseId') || strlength(string(spec.caseId)) == 0
        error('RouteA:ElectricalBoundaryCaseId', ...
            'Each case specification must define a nonempty caseId.');
    end
    if ~isfield(spec, 'profile')
        error('RouteA:ElectricalBoundaryCaseProfile', ...
            'Each case specification must define profile.');
    end

    cases(idx).caseId = string(spec.caseId);
    cases(idx).boundary.profile = spec.profile;
    copyFields = {'air', 'cathode', 'anode', 'thermal', ...
        'controller', 'acceptance', 'loadId', 'currentDensity_A_cm2'};
    for fieldIdx = 1:numel(copyFields)
        name = copyFields{fieldIdx};
        if isfield(spec, name)
            cases(idx).(name) = spec.(name);
        end
    end
    if isfield(spec, 'cegr') && isfield(spec, 'targetRatio')
        error('RouteA:ElectricalBoundaryCaseCegr', ...
            'Use cegr or targetRatio, not both, in one case specification.');
    elseif isfield(spec, 'cegr')
        cases(idx).cegr = spec.cegr;
    elseif isfield(spec, 'targetRatio')
        cases(idx).cegr = struct('targetRatio', spec.targetRatio);
    end
end
end

function type = canonicalBoundaryType(value)
value = lower(string(value));
switch value
    case "current"
        type = "Current";
    case "power"
        type = "Power";
    case "voltage"
        type = "Voltage";
    otherwise
        error('RouteA:ElectricalBoundaryType', ...
            'boundaryType must be Current, Power, or Voltage.');
end
end
