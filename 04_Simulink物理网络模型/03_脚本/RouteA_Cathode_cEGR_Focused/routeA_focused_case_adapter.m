function [caseCfg, adapter] = routeA_focused_case_adapter(inputCase, defaults)
% Normalize a focused case or standard Route A simCase.
%
% The focused model keeps the standard cathode/stack input contract while
% replacing the removed anode and thermal BOPs with explicit boundary values.
% This adapter is the only place where a full simCase is translated to the
% focused runner schema.

if nargin < 2 || ~isstruct(defaults) || ~isscalar(defaults)
    error('RouteA:FocusedAdapterDefaults', ...
        'Focused adapter defaults must be a scalar struct.');
end
if ~isstruct(inputCase) || ~isscalar(inputCase)
    error('RouteA:FocusedAdapterCase', ...
        'A focused case must be a scalar struct.');
end

if isfield(inputCase, 'controls')
    caseCfg = standardSimCaseToFocused(inputCase);
    adapter = struct( ...
        'schemaVersion', "RouteA_Focused_CaseAdapter_v01", ...
        'inputSchema', "RouteA_simCase", ...
        'status', "mapped", ...
        'initialStatePolicy', "cold_start_only");
else
    caseCfg = inputCase;
    adapter = struct( ...
        'schemaVersion', "RouteA_Focused_CaseAdapter_v01", ...
        'inputSchema', "RouteA_Focused_Case_v01", ...
        'status', "native_focused_case", ...
        'initialStatePolicy', "cold_start_only");
end

if ~isfield(caseCfg, 'caseId') || strlength(string(caseCfg.caseId)) == 0
    caseCfg.caseId = "focused_case";
end
if ~isfield(caseCfg, 'description') || isempty(caseCfg.description)
    caseCfg.description = "Focused cathode-cEGR case";
end

caseCfg = applyFocusedExternalCaseSizing(caseCfg, defaults);
[caseCfg, selfHumidifyingBoundary] = applySelfHumidifyingBoundary( ...
    caseCfg, defaults);
adapter.selfHumidifyingBoundary = selfHumidifyingBoundary;

if isfield(inputCase, 'initialState') && isstruct(inputCase.initialState) && ...
        isfield(inputCase.initialState, 'mode') && ...
        string(inputCase.initialState.mode) ~= "cold"
    error('RouteA:FocusedInitialState', ...
        'The focused runner supports cold-start-only cases.');
end

[focused, bridge] = routeA_focused_parameter_bridge(caseCfg, defaults);
caseCfg.focused = focused;
caseCfg.focusedParameterBridge = bridge;
end

function [caseCfg, boundary] = applySelfHumidifyingBoundary(caseCfg, defaults)
boundary = struct( ...
    'status', "not_applicable", ...
    'ambientTemperature_C', NaN, ...
    'ambientPressure_MPa_abs', NaN, ...
    'ambientRelativeHumidity', NaN, ...
    'waterVaporPartialPressure_Pa', NaN, ...
    'freshAirWaterMoleFraction', NaN, ...
    'humidifierEnabled', NaN);

if string(defaults.modelId) ~= "self_humidifying"
    return;
end

if ~isfield(caseCfg, 'environment') || ~isstruct(caseCfg.environment)
    caseCfg.environment = defaults.environment;
end
if ~isfield(caseCfg.environment, 'ambientTemperature_C') || ...
        isempty(caseCfg.environment.ambientTemperature_C)
    caseCfg.environment.ambientTemperature_C = ...
        defaults.environment.ambientTemperature_C;
end
if ~isfield(caseCfg.environment, 'ambientPressure_MPa_abs') || ...
        isempty(caseCfg.environment.ambientPressure_MPa_abs)
    caseCfg.environment.ambientPressure_MPa_abs = ...
        defaults.environment.ambientPressure_MPa_abs;
end
if ~isfield(caseCfg.environment, 'ambientRelativeHumidity') || ...
        isempty(caseCfg.environment.ambientRelativeHumidity)
    caseCfg.environment.ambientRelativeHumidity = ...
        defaults.environment.ambientRelativeHumidity;
end

temperature_C = double(caseCfg.environment.ambientTemperature_C);
pressure_MPa = double(caseCfg.environment.ambientPressure_MPa_abs);
relativeHumidity = double(caseCfg.environment.ambientRelativeHumidity);
validateattributes(temperature_C, {'numeric'}, {'scalar', 'real', 'finite', ...
    '>=', -30, '<=', 60}, 'RouteA:FocusedAmbientTemperature');
validateattributes(pressure_MPa, {'numeric'}, {'scalar', 'real', 'finite', ...
    '>', 0.05, '<=', 0.2}, 'RouteA:FocusedAmbientPressure');
validateattributes(relativeHumidity, {'numeric'}, {'scalar', 'real', 'finite', ...
    '>=', 0, '<=', 1}, 'RouteA:FocusedAmbientRelativeHumidity');

saturationPressure_Pa = waterSaturationPressure_Pa(temperature_C);
waterVaporPartialPressure_Pa = relativeHumidity * saturationPressure_Pa;
freshAirWaterMoleFraction = waterVaporPartialPressure_Pa / ...
    (pressure_MPa * 1e6);
if freshAirWaterMoleFraction >= 0.1
    error('RouteA:FocusedAmbientHumidity', ...
        'Ambient humidity produces an invalid fresh-air water mole fraction.');
end

if ~isfield(caseCfg, 'cathode') || ~isstruct(caseCfg.cathode)
    error('RouteA:FocusedCathodeBoundary', ...
        'Focused self-humidifying cases require a cathode boundary struct.');
end
caseCfg.cathode.humidifierEnabled = 0;
caseCfg.cathode.freshAirWaterMoleFraction = freshAirWaterMoleFraction;
caseCfg.environment.waterVaporPartialPressure_Pa = ...
    waterVaporPartialPressure_Pa;
caseCfg.environment.freshAirWaterMoleFraction = ...
    freshAirWaterMoleFraction;

boundary.status = "derived_from_ambient_T_p_RH";
boundary.ambientTemperature_C = temperature_C;
boundary.ambientPressure_MPa_abs = pressure_MPa;
boundary.ambientRelativeHumidity = relativeHumidity;
boundary.waterVaporPartialPressure_Pa = waterVaporPartialPressure_Pa;
boundary.freshAirWaterMoleFraction = freshAirWaterMoleFraction;
boundary.humidifierEnabled = 0;
end

function pressure_Pa = waterSaturationPressure_Pa(temperature_C)
% Buck equation for liquid-water saturation pressure over -30 to 60 degC.
pressure_Pa = 611.21 * exp((18.678 - temperature_C / 234.5) * ...
    (temperature_C / (257.14 + temperature_C)));
end

function caseCfg = applyFocusedExternalCaseSizing(caseCfg, defaults)
% The focused model is an external 240 kW case, so its active stack and
% cathode BOP must not inherit smaller platform values from a standard simCase.
if ~isfield(caseCfg, 'devices') || ~isstruct(caseCfg.devices) || ...
        ~isfield(caseCfg.devices, 'cathode') || ...
        ~isfield(caseCfg.devices, 'cegr') || ...
        ~isfield(caseCfg, 'stack') || ~isstruct(caseCfg.stack)
    error('RouteA:FocusedExternalCaseContract', ...
        'Focused cases require stack, cathode, and cEGR device contracts.');
end

caseCfg.stack.numCells = defaults.stack.numCells;
caseCfg.stack.area_cm2 = defaults.stack.area_cm2;
caseCfg.stack.iL_A_cm2 = defaults.stack.iL_A_cm2;
caseCfg.stack.io_A_cm2 = defaults.stack.io_A_cm2;

bop = defaults.bop;
caseCfg.devices.cathode.compressorMap.rpm_TLU = bop.compressorMap.rpm_TLU;
caseCfg.devices.cathode.compressorMap.p_ratio_TLU = ...
    bop.compressorMap.p_ratio_TLU;
caseCfg.devices.cathode.compressorMap.mdot_corr_TLU = ...
    bop.compressorMap.mdot_corr_TLU;
caseCfg.devices.cathode.intercoolerMdotNominal_kg_s = ...
    bop.intercoolerMdotNominal_kg_s;
caseCfg.devices.cathode.intercoolerDpNominal_MPa = ...
    focusedDeviceValue(caseCfg, 'intercoolerDpNominal_MPa', ...
    bop.intercoolerDpNominal_MPa, [0, 0.1]);
caseCfg.devices.cathode.intercoolerArea_m2 = bop.intercoolerArea_m2;
caseCfg.devices.cathode.separatorMdotNominal_kg_s = ...
    bop.separatorMdotNominal_kg_s;
caseCfg.devices.cathode.separatorDpNominal_MPa = ...
    bop.separatorDpNominal_MPa;
caseCfg.devices.cathode.separatorArea_m2 = bop.separatorArea_m2;
caseCfg.devices.cegr.valveMaxArea_m2 = bop.cegrValveMaxArea_m2;
caseCfg.devices.cegr.pipeDiameter_m = bop.cegrPipeDiameter_m;
end

function value = focusedDeviceValue(caseCfg, fieldName, default, limits)
value = default;
if ~isfield(caseCfg, 'focused') || ~isstruct(caseCfg.focused) || ...
        ~isfield(caseCfg.focused, fieldName) || ...
        isempty(caseCfg.focused.(fieldName))
    return;
end
value = caseCfg.focused.(fieldName);
validateattributes(value, {'numeric'}, {'scalar', 'real', 'finite'}, ...
    'RouteA:FocusedDeviceOverride', "focused." + string(fieldName));
if value < limits(1) || value > limits(2)
    error('RouteA:FocusedDeviceOverrideRange', ...
        'focused.%s must be within [%.6g, %.6g].', ...
        fieldName, limits(1), limits(2));
end
end

function caseCfg = standardSimCaseToFocused(simCase)
% Map the standard CR3 controls to the shared electrical-boundary adapter.

controls = simCase.controls;
if ~isfield(controls, 'electrical') || ...
        ~isfield(controls.electrical, 'mode') || ...
        ~isfield(controls.electrical, 'profile')
    error('RouteA:FocusedElectricalContract', ...
        'The standard simCase electrical contract is incomplete.');
end

caseCfg = struct();
caseCfg.caseId = string(getField(simCase, 'caseId', "focused_case"));
caseCfg.description = string(getField(simCase, 'description', ...
    "Focused case adapted from Route A simCase"));
caseCfg.boundary = struct( ...
    'type', string(controls.electrical.mode), ...
    'profile', controls.electrical.profile);

if isfield(controls.electrical, 'voltageController')
    caseCfg.controller = controls.electrical.voltageController;
end

if isfield(controls, 'cathode')
    cathode = controls.cathode;
    caseCfg.air = struct( ...
        'modeId', cathode.airControlMode, ...
        'targetOer', cathode.targetOer, ...
        'targetMdot_kg_s', cathode.targetMdot_kg_s, ...
        'directCommand', cathode.directCommand, ...
        'pid', cathode.airController);
    caseCfg.cathode = struct( ...
        'sourcePressure_MPa_abs', cathode.sourcePressure_MPa_abs, ...
        'sourceTemperature_C', cathode.sourceTemperature_C, ...
        'freshAirO2MoleFraction', cathode.o2MoleFraction, ...
        'freshAirWaterMoleFraction', cathode.h2oMoleFraction, ...
        'outletPressure_MPa_abs', cathode.outletPressure_MPa_abs, ...
        'humidifierRelativeHumidity', cathode.humidifierRH, ...
        'humidifierEnabled', cathode.humidifierEnabled);
end

if isfield(controls, 'cegr')
    caseCfg.cegr = controls.cegr;
    if ~isfield(caseCfg.cegr, 'profile')
        caseCfg.cegr.profile = caseCfg.cegr.targetRatio;
    end
end
if isfield(controls, 'anode')
    anode = controls.anode;
    caseCfg.anode = struct( ...
        'tankPressure_MPa_abs', anode.sourcePressure_MPa_abs, ...
        'sourceTemperature_C', anode.sourceTemperature_C, ...
        'hydrogenMoleFraction', anode.h2MoleFraction, ...
        'inletPressure_MPa_abs', anode.inletPressure_MPa_abs, ...
        'humidifierRelativeHumidity', anode.humidifierRH, ...
        'recirculationBaseCommand', anode.recirculationBaseCommand, ...
        'recirculationCurrentGain_A_inv', ...
            anode.recirculationCurrentGain_A_inv, ...
        'purgeEnabled', anode.purgeEnabled, ...
        'purgeOnN2MoleFraction', anode.purgeOnN2MoleFraction, ...
        'purgeOffN2MoleFraction', anode.purgeOffN2MoleFraction);
end
if isfield(controls, 'thermal')
    caseCfg.thermal = controls.thermal;
end
if isfield(controls, 'environment')
    caseCfg.environment = struct( ...
        'ambientTemperature_C', controls.environment.ambientTemperature_C, ...
        'ambientPressure_MPa_abs', controls.environment.ambientPressure_MPa_abs);
end
if isfield(controls, 'stack')
    caseCfg.stack = controls.stack;
end
if isfield(controls, 'devices')
    caseCfg.devices = controls.devices;
end
if isfield(simCase, 'acceptance')
    caseCfg.acceptance = simCase.acceptance;
end
if isfield(simCase, 'focused')
    caseCfg.focused = simCase.focused;
end
end

function value = getField(s, name, default)
if isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
else
    value = default;
end
end
