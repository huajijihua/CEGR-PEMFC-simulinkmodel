function profile = routeA_assemble_command_profile(controls, study)
% Build a named-struct runtime-command profile from a simCase controls struct.
%
% The output replaces the legacy 22-column routeA_command_profile matrix with
% individually named fields, one per control variable. A backward-compatible
% workspaceValue field is also provided for model paths that still use the
% old [time, 22values] FromWorkspace format.
%
% Inputs:
%   controls  - simCase.controls struct (Phase A CR3 schema):
%               .electrical.mode, .cathode, .cegr, .anode, .thermal
%   study     - study config with .researchDuration_s, .commandStartOffset_s,
%               .startupRampDuration_s
%
% Output:
%   profile   - scalar struct with fields:
%               .cathode_source_pressure_MPa_abs     [Nx2, t, value]
%               .cathode_source_temperature_C        [Nx2, t, value]
%               .cathode_source_o2_mole_fraction     [Nx2, t, value]
%               .cathode_source_h2o_mole_fraction    [Nx2, t, value]
%               .air_target_mdot_kg_s                [Nx2, t, value]
%               .air_target_oer                      [Nx2, t, value]
%               .air_direct_command                  [Nx2, t, value]
%               .cathode_outlet_pressure_MPa_abs     [Nx2, t, value]
%               .cathode_humidifier_rh               [Nx2, t, value]
%               .cathode_humidifier_gain             [Nx2, t, value]
%               .cegr_ratio                          [Nx2, t, value]
%               .anode_source_pressure_MPa_abs       [Nx2, t, value]
%               .anode_source_temperature_C          [Nx2, t, value]
%               .anode_source_h2_mole_fraction       [Nx2, t, value]
%               .anode_inlet_pressure_MPa_abs        [Nx2, t, value]
%               .anode_humidifier_rh                 [Nx2, t, value]
%               .anode_recirculation_base            [Nx2, t, value]
%               .anode_recirculation_current_gain_A_inv [Nx2, t, value]
%               .anode_purge_enable                  [Nx2, t, value]
%               .anode_purge_on_n2_mole_fraction     [Nx2, t, value]
%               .anode_purge_off_n2_mole_fraction    [Nx2, t, value]
%               .stack_temperature_set_C             [Nx2, t, value]
%               .workspaceValue                      [NxT, 22cols] backward compat
%               .time_s                              column vector
%               .fields                              cellstr of field names
%
% Usage:
%   profile = routeA_assemble_command_profile(simCase.controls, study);
%   % Access individual fields:
%   simCase.controls.cathode.targetOer  % 3.0
%   profile.air_target_oer              % [Nx2] time series
%
% See also: routeA_simCase_template, routeA_normalize_electrical_profile

%#ok<*NASGU>

%% Resolve defaults from controls struct
% Use getFieldOrDefault to provide safe defaults for missing fields
oer = getField(controls, 'cathode', 'targetOer', 3.0);
mdot = getField(controls, 'cathode', 'targetMdot_kg_s', 0.005);
directCmd = getField(controls, 'cathode', 'directCommand', 0.5);
srcP = getField(controls, 'cathode', 'sourcePressure_MPa_abs', 0.15);
srcT = getField(controls, 'cathode', 'sourceTemperature_C', 20);
o2Frac = getField(controls, 'cathode', 'o2MoleFraction', 0.21);
h2oFrac = getField(controls, 'cathode', 'h2oMoleFraction', 0.0115);
outP = getField(controls, 'cathode', 'outletPressure_MPa_abs', 0.1613);
rh = getField(controls, 'cathode', 'humidifierRH', 0.9);
humGain = getField(controls, 'cathode', 'humidifierEnabled', 1);

cegrRatio = getField(controls, 'cegr', 'targetRatio', 0);

anSrcP = getField(controls, 'anode', 'sourcePressure_MPa_abs', 0.3);
anSrcT = getField(controls, 'anode', 'sourceTemperature_C', 20);
anH2Frac = getField(controls, 'anode', 'h2MoleFraction', 0.9997);
anInP = getField(controls, 'anode', 'inletPressure_MPa_abs', 0.15);
anRH = getField(controls, 'anode', 'humidifierRH', 0.5);
anRecircBase = getField(controls, 'anode', 'recirculationBaseCommand', 0);
anRecircGain = getField(controls, 'anode', 'recirculationCurrentGain_A_inv', 0);
anPurgeEn = getField(controls, 'anode', 'purgeEnabled', 0);
anPurgeOn = getField(controls, 'anode', 'purgeOnN2MoleFraction', 0.1);
anPurgeOff = getField(controls, 'anode', 'purgeOffN2MoleFraction', 0.05);

stackT = getField(controls, 'thermal', 'stackTemperatureSet_C', 80);

%% Resolve the canonical 22-field schema (single source of truth)
% Field names, labels, order, and step flags come from
% routeA_command_profile_schema, so this builder cannot drift from the
% validators that check the same profile (commandBaseline and
% validateV10PhysicalMetadata). Defaults are keyed by field name below, making
% value lookup order-independent.
schema = routeA_command_profile_schema();
count = schema.count;
fieldNames = schema.names.';

defaults = struct( ...
    'cathode_source_pressure_MPa_abs', srcP, ...
    'cathode_source_temperature_C', srcT, ...
    'cathode_source_o2_mole_fraction', o2Frac, ...
    'cathode_source_h2o_mole_fraction', h2oFrac, ...
    'air_target_mdot_kg_s', mdot, ...
    'air_target_oer', oer, ...
    'air_direct_command', directCmd, ...
    'cathode_outlet_pressure_MPa_abs', outP, ...
    'cathode_humidifier_rh', rh, ...
    'cathode_humidifier_gain', humGain, ...
    'cegr_ratio', cegrRatio, ...
    'anode_source_pressure_MPa_abs', anSrcP, ...
    'anode_source_temperature_C', anSrcT, ...
    'anode_source_h2_mole_fraction', anH2Frac, ...
    'anode_inlet_pressure_MPa_abs', anInP, ...
    'anode_humidifier_rh', anRH, ...
    'anode_recirculation_base', anRecircBase, ...
    'anode_recirculation_current_gain_A_inv', anRecircGain, ...
    'anode_purge_enable', anPurgeEn, ...
    'anode_purge_on_n2_mole_fraction', anPurgeOn, ...
    'anode_purge_off_n2_mole_fraction', anPurgeOff, ...
    'stack_temperature_set_C', stackT);

%% Build individual normalized profiles
profiles = cell(count, 1);
time = zeros(0, 1);
for idx = 1:count
    thisLabel = schema.labels(idx);
    thisValue = defaults.(schema.names(idx));
    thisIsStep = schema.isStep(idx);
    thisOptions = struct( ...
        'duration_s', study.researchDuration_s, ...
        'commandStartOffset_s', study.commandStartOffset_s, ...
        'startupRampDuration_s', study.startupRampDuration_s, ...
        'initialValue', thisValue, ...
        'label', thisLabel);
    if thisIsStep
        thisOptions.startupRampDuration_s = 0;
    end
    profiles{idx} = routeA_normalize_electrical_profile( ...
        thisValue, thisLabel, thisOptions);
    time = unique([time; profiles{idx}.time_s], 'sorted');
end

%% Interpolate all fields to common time base
value = zeros(numel(time), count);
for idx = 1:count
    value(:, idx) = interp1(profiles{idx}.time_s, profiles{idx}.value, ...
        time, 'linear');
end

%% Validate
validateCommandProfileMatrix(time, value);

%% Populate output struct
profile = struct();
profile.time_s = time;
profile.fields = fieldNames;
for idx = 1:count
    name = char(schema.names(idx));
    profile.(name) = [time, value(:, idx)];
end
profile.workspaceValue = [time, value];
profile.schema = schema.version;

end

%% -----------------------------------------------------------------------
function v = getField(controls, domain, field, default)
% Get a field from controls.(domain).(field), returning default if absent.
if ~isstruct(controls) || ~isfield(controls, domain)
    v = default;
    return;
end
d = controls.(domain);
if ~isstruct(d) || ~isfield(d, field)
    v = default;
    return;
end
v = d.(field);
if isempty(v)
    v = default;
end
end

%% -----------------------------------------------------------------------
function validateCommandProfileMatrix(time, value)
% Validate the 22-column matrix (same rules as original).
if any(~isfinite(time)) || any(~isfinite(value(:))) || any(diff(time) <= 0)
    error('RouteA:CommandProfileFinite', ...
        'The unified runtime-command profile is not finite and ordered.');
end
if any(value(:, 3) + value(:, 4) > 1 + 1e-12)
    error('RouteA:CathodeSourceComposition', ...
        'Cathode O2 and H2O command fractions must sum to no more than one.');
end
if any(value(:, 12) <= value(:, 15))
    error('RouteA:AnodePressureOrder', ...
        'Anode source pressure must exceed the inlet-pressure command.');
end
if any(value(:, 20) <= value(:, 21))
    error('RouteA:AnodePurgeThresholdOrder', ...
        'Anode purge-on threshold must exceed the purge-off threshold.');
end
end