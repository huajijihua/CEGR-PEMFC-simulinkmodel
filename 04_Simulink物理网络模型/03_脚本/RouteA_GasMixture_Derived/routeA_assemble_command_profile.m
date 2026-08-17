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
%               .air_direct_command                  [Nx2, t, normalized compressor command 0..1]
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
% Defaults are derived from routeA_platform_default_parameters (single source
% of truth). Callers that provide explicit values in the controls struct
% override these defaults; callers that omit a field inherit the platform
% default.
params = routeA_platform_default_parameters();
pCtrl = params.controls;
pEnv  = params.environment;
pCath = params.cathode;
pAnode = params.anode;
pTherm = params.thermal;

oer = getField(controls, 'cathode', 'targetOer', pCtrl.target_oer.value);
mdot = getField(controls, 'cathode', 'targetMdot_kg_s', pCtrl.target_mdot_kg_s.value);
directCmd = getField(controls, 'cathode', 'directCommand', pCtrl.air_direct_command.value);
srcP = getField(controls, 'cathode', 'sourcePressure_MPa_abs', pCtrl.cathode_source_pressure_MPa_abs.value);
srcT = getField(controls, 'cathode', 'sourceTemperature_C', pCtrl.cathode_source_temperature_C.value);
o2Frac = getField(controls, 'cathode', 'o2MoleFraction', pEnv.o2_mole_fraction.value);
h2oFrac = getField(controls, 'cathode', 'h2oMoleFraction', pEnv.h2o_mole_fraction.value);
outP = getField(controls, 'cathode', 'outletPressure_MPa_abs', pCtrl.backpressure_MPa_abs.value);
rh = getField(controls, 'cathode', 'humidifierRH', pCath.humidifier.default_rh.value);
humGain = getField(controls, 'cathode', 'humidifierEnabled', pCath.humidifier.enabled.value);

cegrRatio = getField(controls, 'cegr', 'targetRatio', pCtrl.cegr_target_ratio.value);

anSrcP = getField(controls, 'anode', 'sourcePressure_MPa_abs', pCtrl.anode_source_pressure_MPa_abs.value);
anSrcT = getField(controls, 'anode', 'sourceTemperature_C', pCtrl.anode_source_temperature_C.value);
anH2Frac = getField(controls, 'anode', 'h2MoleFraction', pAnode.tank.yH2.value);
anInP = getField(controls, 'anode', 'inletPressure_MPa_abs', pAnode.default_pressure_MPa_abs.value);
anRH = getField(controls, 'anode', 'humidifierRH', pAnode.humidifier.default_rh.value);
anRecircBase = getField(controls, 'anode', 'recirculationBaseCommand', pCtrl.anode_recirc_base.value);
anRecircGain = getField(controls, 'anode', 'recirculationCurrentGain_A_inv', pCtrl.anode_recirc_gain_A_inv.value);
anPurgeEn = getField(controls, 'anode', 'purgeEnabled', pCtrl.anode_purge_enable.value);
anPurgeOn = getField(controls, 'anode', 'purgeOnN2MoleFraction', pCtrl.anode_purge_on_n2.value);
anPurgeOff = getField(controls, 'anode', 'purgeOffN2MoleFraction', pCtrl.anode_purge_off_n2.value);

stackT = getField(controls, 'thermal', 'stackTemperatureSet_C', pTherm.stack_temperature_set_C.value);

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
    if any(schema.names(idx) == ["cathode_humidifier_gain", "anode_purge_enable"])
        % The model-facing profile is numeric even when the panel stores an
        % enable flag as logical.
        thisValue = double(thisValue);
    end
    thisIsStep = schema.isStep(idx);
    thisInitialValue = initialProfileValue(thisValue);
    thisStartOffset_s = study.commandStartOffset_s;
    if schema.names(idx) == "air_direct_command" && ...
            isnumeric(thisValue) && isscalar(thisValue)
        % A direct compressor command must not be applied before cold-start
        % states are established. Start its ramp at t=0 so the compressor-flow
        % denominator does not dwell at an exact zero command after startup.
        thisInitialValue = 0;
        thisStartOffset_s = 0;
    end
    thisOptions = struct( ...
        'duration_s', study.researchDuration_s, ...
        'commandStartOffset_s', thisStartOffset_s, ...
        'startupRampDuration_s', study.startupRampDuration_s, ...
        'initialValue', thisInitialValue, ...
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

function value = initialProfileValue(spec)
% Keep profile specifications dynamic while supplying a scalar initial value.
value = spec;
if isnumeric(spec) && ismatrix(spec) && size(spec, 2) == 2 && ...
        size(spec, 1) >= 1
    value = spec(1, 2);
    return;
end
if isa(spec, 'timeseries')
    value = spec.Data(1);
    return;
end
if ~isstruct(spec) || ~isscalar(spec)
    return;
end
if isfield(spec, 'profile')
    value = initialProfileValue(spec.profile);
elseif isfield(spec, 'time_s') && isfield(spec, 'value')
    value = spec.value(1);
elseif isfield(spec, 'kind') || isfield(spec, 'shape')
    if isfield(spec, 'kind')
        kind = lower(string(spec.kind));
    else
        kind = lower(string(spec.shape));
    end
    if kind == "constant" && isfield(spec, 'value')
        value = spec.value;
    elseif kind == "step" && isfield(spec, 'before')
        value = spec.before;
    elseif kind == "ramp" && isfield(spec, 'start_value')
        value = spec.start_value;
    end
end
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
