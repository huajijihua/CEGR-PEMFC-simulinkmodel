function simCase = routeA_validate_case(simCase)
% Validate and fill defaults for a simCase struct.
%
% Implements the CR3 schema validation rules (§7 of
% RouteA_cEGR_PEMFC_CR3三要素schema_v01.md):
%   - Type validation for caseId, modes, solver
%   - Range validation for key control parameters
%   - Mutex validation for electrical mode + voltageController
%   - Default filling from routeA_platform_default_parameters
%
% The caller may provide only the fields that differ from platform defaults;
% this function fills the rest and validates the result.
%
% Usage:
%   simCase = routeA_simCase_template();   % full defaults
%   simCase.caseId = 'my_case';
%   simCase.controls.electrical.mode = 'Power';
%   simCase.controls.electrical.profile = 40;
%   simCase = routeA_validate_case(simCase);  % fill + validate
%
% See also: routeA_simCase_template, routeA_platform_default_parameters

%% Reject explicit partial Voltage controller overrides before defaults fill.
% A basic-mode case may omit the controller and inherit platform defaults. An
% explicit controller struct, however, is an intentional override and must
% be complete; silently filling only part of it can hide a malformed case.
validateExplicitVoltageController(simCase);

%% Fill defaults from template (preserves caller overrides)
template = routeA_simCase_template();
simCase = fillDefaults(simCase, template);

%% Type validation
validateCaseId(simCase.caseId);
validateInitialStateMode(simCase.initialState.mode);
validateElectricalMode(simCase.controls.electrical.mode);
validateAirControlMode(simCase.controls.cathode.airControlMode);
validateSolverName(simCase.solver.solver);
validateBinary(simCase.controls.cathode.humidifierEnabled, ...
    'controls.cathode.humidifierEnabled');
validateBinary(simCase.controls.cegr.enabled, 'controls.cegr.enabled');
validateBinary(simCase.controls.anode.purgeEnabled, ...
    'controls.anode.purgeEnabled');

%% Range validation
validateRange(simCase.controls.cathode.targetOer, [1.5, 5], ...
    'controls.cathode.targetOer');
validatePositive(simCase.controls.cathode.targetMdot_kg_s, ...
    'controls.cathode.targetMdot_kg_s');
validateRange(simCase.controls.cathode.directCommand, [0, 1], ...
    'controls.cathode.directCommand');
validatePositive(simCase.controls.cathode.airController.Kp, ...
    'controls.cathode.airController.Kp');
validatePositive(simCase.controls.cathode.airController.Ki, ...
    'controls.cathode.airController.Ki');
validateRange(simCase.controls.cathode.sourcePressure_MPa_abs, [0.1, 0.5], ...
    'controls.cathode.sourcePressure_MPa_abs');
validateRange(simCase.controls.cathode.sourceTemperature_C, [10, 60], ...
    'controls.cathode.sourceTemperature_C');
validateRange(simCase.controls.cathode.o2MoleFraction, [0.15, 0.21], ...
    'controls.cathode.o2MoleFraction');
validateRange(simCase.controls.cathode.h2oMoleFraction, [0.005, 0.04], ...
    'controls.cathode.h2oMoleFraction');
validateRange(simCase.controls.cathode.outletPressure_MPa_abs, [0.1, 0.3], ...
    'controls.cathode.outletPressure_MPa_abs');
validateRange(simCase.controls.cegr.targetRatio, [0, 0.5], ...
    'controls.cegr.targetRatio');
validateRange(simCase.controls.cegr.valveMode, [1, 2], ...
    'controls.cegr.valveMode');
validateSupportedCegrValveMode(simCase.controls.cegr.valveMode);
validateRange(simCase.controls.cegr.controlMode, [1, 2], ...
    'controls.cegr.controlMode');
validateRange(simCase.controls.cegr.targetInputMode, [1, 1], ...
    'controls.cegr.targetInputMode');
validateRange(simCase.controls.cegr.directValveArea_m2, [1e-12, 1], ...
    'controls.cegr.directValveArea_m2');
validateRange(simCase.controls.cegr.directTargetRatio, [0, 0.5], ...
    'controls.cegr.directTargetRatio');
validatePositive(simCase.controls.cegr.controller.Kp_area, ...
    'controls.cegr.controller.Kp_area');
validatePositive(simCase.controls.cegr.controller.Ki_area, ...
    'controls.cegr.controller.Ki_area');
validatePositive(simCase.controls.cegr.controller.actuatorTau_s, ...
    'controls.cegr.controller.actuatorTau_s');
validateRange(simCase.controls.cathode.humidifierRH, [0, 1], ...
    'controls.cathode.humidifierRH');
validateRange(simCase.controls.anode.humidifierRH, [0, 1], ...
    'controls.anode.humidifierRH');
validateRange(simCase.controls.anode.sourcePressure_MPa_abs, [0.2, 0.5], ...
    'controls.anode.sourcePressure_MPa_abs');
validateRange(simCase.controls.anode.sourceTemperature_C, [10, 60], ...
    'controls.anode.sourceTemperature_C');
validateRange(simCase.controls.anode.h2MoleFraction, [0.9, 1.0], ...
    'controls.anode.h2MoleFraction');
validateRange(simCase.controls.anode.inletPressure_MPa_abs, [0.1, 0.3], ...
    'controls.anode.inletPressure_MPa_abs');
validateRange(simCase.controls.anode.recirculationBaseCommand, [0, 1], ...
    'controls.anode.recirculationBaseCommand');
validateRange(simCase.controls.anode.recirculationCurrentGain_A_inv, [0, 1], ...
    'controls.anode.recirculationCurrentGain_A_inv');
validateRange(simCase.controls.anode.purgeOnN2MoleFraction, [0, 1], ...
    'controls.anode.purgeOnN2MoleFraction');
validateRange(simCase.controls.anode.purgeOffN2MoleFraction, [0, 1], ...
    'controls.anode.purgeOffN2MoleFraction');
if simCase.controls.anode.sourcePressure_MPa_abs <= ...
        simCase.controls.anode.inletPressure_MPa_abs
    error('RouteA:AnodePressureOrder', ...
        'Anode source pressure must exceed the inlet-pressure command.');
end
if simCase.controls.anode.purgeOnN2MoleFraction <= ...
        simCase.controls.anode.purgeOffN2MoleFraction
    error('RouteA:AnodePurgeThresholdOrder', ...
        'Anode purge-on N2 threshold must exceed the purge-off threshold.');
end
validateIntegerRange(simCase.controls.stack.numCells, [1, 1000], ...
    'controls.stack.numCells');
validateRange(simCase.controls.stack.area_cm2, [1, 1000], ...
    'controls.stack.area_cm2');
validateRange(simCase.controls.stack.iL_A_cm2, [1e-3, 5], ...
    'controls.stack.iL_A_cm2');
validateRange(simCase.controls.stack.io_A_cm2, [1e-8, 0.1], ...
    'controls.stack.io_A_cm2');
validateRange(simCase.controls.devices.stack.alpha, [0.1, 1.5], ...
    'controls.devices.stack.alpha');
validateRange(simCase.controls.devices.stack.meaCp_J_kgK, [100, 5000], ...
    'controls.devices.stack.meaCp_J_kgK');
validateRange(simCase.controls.devices.stack.meaRho_kg_m3, [100, 5000], ...
    'controls.devices.stack.meaRho_kg_m3');
validateRange(simCase.controls.devices.stack.gdlThickness_um, [1, 2000], ...
    'controls.devices.stack.gdlThickness_um');
validateRange(simCase.controls.devices.stack.membraneThickness_um, [1, 1000], ...
    'controls.devices.stack.membraneThickness_um');
validateRange(simCase.controls.devices.cathode.intercoolerMdotNominal_kg_s, ...
    [eps, 1], 'controls.devices.cathode.intercoolerMdotNominal_kg_s');
validateRange(simCase.controls.devices.cathode.intercoolerDpNominal_MPa, ...
    [0, 0.1], 'controls.devices.cathode.intercoolerDpNominal_MPa');
validateRange(simCase.controls.devices.cathode.intercoolerArea_m2, ...
    [1e-8, 0.1], 'controls.devices.cathode.intercoolerArea_m2');
validateRange(simCase.controls.devices.cathode.intercoolerLaminarFraction, ...
    [0, 1], 'controls.devices.cathode.intercoolerLaminarFraction');
validateRange(simCase.controls.devices.cathode.separatorMdotNominal_kg_s, ...
    [eps, 1], 'controls.devices.cathode.separatorMdotNominal_kg_s');
validateRange(simCase.controls.devices.cathode.separatorDpNominal_MPa, ...
    [0, 0.1], 'controls.devices.cathode.separatorDpNominal_MPa');
validateRange(simCase.controls.devices.cathode.separatorArea_m2, ...
    [1e-8, 0.1], 'controls.devices.cathode.separatorArea_m2');
validateRange(simCase.controls.devices.cathode.separatorLaminarFraction, ...
    [0, 1], 'controls.devices.cathode.separatorLaminarFraction');
validateRange(simCase.controls.devices.cathode.mixerVolume_L, ...
    [eps, 1000], 'controls.devices.cathode.mixerVolume_L');
validateRange(simCase.controls.devices.cathode.outletChamberVolume_L, ...
    [eps, 1000], 'controls.devices.cathode.outletChamberVolume_L');
validateRange(simCase.controls.devices.cegr.valveMaxArea_m2, [eps, 1], ...
    'controls.devices.cegr.valveMaxArea_m2');
validateRange(simCase.controls.devices.cegr.pipeLength_m, [1e-4, 100], ...
    'controls.devices.cegr.pipeLength_m');
validateRange(simCase.controls.devices.cegr.pipeDiameter_m, [1e-4, 1], ...
    'controls.devices.cegr.pipeDiameter_m');
validateRange(simCase.controls.devices.cegr.pipeRoughness_m, [0, 0.01], ...
    'controls.devices.cegr.pipeRoughness_m');
validateRange(simCase.controls.devices.cegr.condensationTau_s, [eps, 1000], ...
    'controls.devices.cegr.condensationTau_s');
validateRange(simCase.controls.devices.cegr.inletMixerPressure_MPa_abs, ...
    [0.01, 1], 'controls.devices.cegr.inletMixerPressure_MPa_abs');
validateRange(simCase.controls.devices.cegr.outletChamberPressure_MPa_abs, ...
    [0.01, 1], 'controls.devices.cegr.outletChamberPressure_MPa_abs');
validateRange(simCase.controls.devices.cegr.pipeExtraLength_m, ...
    [0, 100], 'controls.devices.cegr.pipeExtraLength_m');
validateRange(simCase.controls.devices.cegr.pipePressure_MPa_abs, ...
    [0.01, 1], 'controls.devices.cegr.pipePressure_MPa_abs');
validateRange(simCase.controls.devices.cegr.valveOpenMinArea_m2, ...
    [1e-12, 1], 'controls.devices.cegr.valveOpenMinArea_m2');
validateRange(simCase.controls.devices.anode.tankPressure_MPa, [0.1, 100], ...
    'controls.devices.anode.tankPressure_MPa');
validateRange(simCase.controls.devices.anode.tankVolume_L, [eps, 1e5], ...
    'controls.devices.anode.tankVolume_L');
validateRange(simCase.controls.devices.anode.tankTemperature_C, [-50, 150], ...
    'controls.devices.anode.tankTemperature_C');
validateRange(simCase.controls.devices.anode.separatorMdotNominal_kg_s, ...
    [eps, 1], 'controls.devices.anode.separatorMdotNominal_kg_s');
validateRange(simCase.controls.devices.anode.separatorDpNominal_MPa, ...
    [0, 0.1], 'controls.devices.anode.separatorDpNominal_MPa');
validateRange(simCase.controls.devices.anode.separatorArea_m2, [1e-8, 0.1], ...
    'controls.devices.anode.separatorArea_m2');
validateRange(simCase.controls.devices.anode.separatorLaminarFraction, [0, 1], ...
    'controls.devices.anode.separatorLaminarFraction');
coolant = simCase.controls.devices.thermal.coolantGeometry;
validateIntegerRange(coolant.numLayers, [1, 100], ...
    'controls.devices.thermal.coolantGeometry.numLayers');
validateIntegerRange(coolant.numPasses, [1, 50], ...
    'controls.devices.thermal.coolantGeometry.numPasses');
validateRange(coolant.channelWidth_cm, [0.2, 2], ...
    'controls.devices.thermal.coolantGeometry.channelWidth_cm');
validateRange(coolant.tubeDiameter_m, [0.01, 0.10], ...
    'controls.devices.thermal.coolantGeometry.tubeDiameter_m');
radiator = simCase.controls.devices.thermal.radiatorCore;
validateRange(radiator.length_m, [0.2, 2], ...
    'controls.devices.thermal.radiatorCore.length_m');
validateRange(radiator.width_m, [0.005, 0.10], ...
    'controls.devices.thermal.radiatorCore.width_m');
validateRange(radiator.height_m, [0.10, 1.0], ...
    'controls.devices.thermal.radiatorCore.height_m');
validateIntegerRange(radiator.tubeCount, [2, 100], ...
    'controls.devices.thermal.radiatorCore.tubeCount');
validateRange(radiator.tubeHeight_m, [5e-4, 1e-2], ...
    'controls.devices.thermal.radiatorCore.tubeHeight_m');
validateRange(radiator.finSpacing_m, [5e-4, 1e-2], ...
    'controls.devices.thermal.radiatorCore.finSpacing_m');
validateRange(radiator.finEfficiency, [0.3, 1], ...
    'controls.devices.thermal.radiatorCore.finEfficiency');
validateRange(radiator.wallThickness_m, [1e-5, 1e-3], ...
    'controls.devices.thermal.radiatorCore.wallThickness_m');
validateRange(radiator.density_kg_m3, [500, 5000], ...
    'controls.devices.thermal.radiatorCore.density_kg_m3');
validateRange(radiator.specificHeat_J_kgK, [300, 1500], ...
    'controls.devices.thermal.radiatorCore.specificHeat_J_kgK');
if radiator.height_m <= radiator.tubeCount * radiator.tubeHeight_m
    error('RouteA:RadiatorCoreGeometry', ...
        'Radiator core height must exceed tubeCount*tubeHeight_m.');
end
simCase.controls.devices.cathode.compressorMap = ...
    routeA_validate_compressor_map(simCase.controls.devices.cathode.compressorMap);
validateRange(simCase.controls.thermal.stackTemperatureSet_C, [60, 100], ...
    'controls.thermal.stackTemperatureSet_C');
validateRange(simCase.controls.environment.ambientTemperature_C, [-50, 100], ...
    'controls.environment.ambientTemperature_C');
validateFixedAmbientPressure(simCase.controls.environment.ambientPressure_MPa_abs);
validateRange(simCase.solver.stopTime_s, [eps, Inf], 'solver.stopTime_s');
validateRange(simCase.solver.relTol, [eps, 1], 'solver.relTol');
validateRange(simCase.solver.absTol, [eps, Inf], 'solver.absTol');
validateRange(simCase.solver.maxStep_s, [0, Inf], 'solver.maxStep_s');

% A disabled cEGR path is represented by a zero target. The topology remains
% present in the active model, but no valve target is simultaneously applied.
if ~logical(simCase.controls.cegr.enabled)
    simCase.controls.cegr.targetRatio = 0;
end

%% Mutex validation (also validates voltageController fields for Voltage mode)
validateElectricalMutex(simCase.controls.electrical);

end

%% -----------------------------------------------------------------------
function sc = fillDefaults(sc, tmpl)
% Recursively fill missing fields from template, preserving caller values.
names = fieldnames(tmpl);
for i = 1:numel(names)
    f = names{i};
    if ~isfield(sc, f) || isempty(sc.(f))
        sc.(f) = tmpl.(f);
    elseif isstruct(sc.(f)) && isstruct(tmpl.(f))
        sc.(f) = fillDefaults(sc.(f), tmpl.(f));
    end
end
end

%% -----------------------------------------------------------------------
function validateCaseId(caseId)
caseId = string(caseId);
if strlength(caseId) == 0
    error('RouteA:ValidateCaseId', 'caseId must be non-empty.');
end
if ~regexp(caseId, '^[A-Za-z0-9_]+$')
    error('RouteA:ValidateCaseId', ...
        'caseId must be alphanumeric + underscore only: "%s".', caseId);
end
end

%% -----------------------------------------------------------------------
function validateInitialStateMode(mode)
mode = string(mode);
if ~isscalar(mode) || mode ~= "cold"
    error('RouteA:ValidateInitialStateMode', ...
        'The active Route A runner supports cold-start-only execution. Got: %s', ...
        mode);
end
end

%% -----------------------------------------------------------------------
function validateElectricalMode(mode)
mode = string(mode);
valid = ["Current", "Power", "Voltage"];
if ~any(mode == valid)
    error('RouteA:ValidateElectricalMode', ...
        'controls.electrical.mode must be one of: %s. Got: %s', ...
        strjoin(valid, ', '), mode);
end
end

%% -----------------------------------------------------------------------
function validateAirControlMode(modeId)
if ~isnumeric(modeId) || ~isscalar(modeId) || ~isreal(modeId) || ...
        ~isfinite(modeId) || modeId ~= fix(modeId) || ...
        ~ismember(modeId, [1, 2, 3])
    error('RouteA:ValidateAirControlMode', ...
        'controls.cathode.airControlMode must be 1, 2, or 3. Got: %g.', modeId);
end
end

%% -----------------------------------------------------------------------
function validateSupportedCegrValveMode(modeId)
if modeId ~= 1
    error('RouteA:CegRValveMode', ...
        ['The active Route A model implements only cEGR valve mode 1 ', ...
        '(open-area restriction).']);
end
end

%% -----------------------------------------------------------------------
function validateRange(value, bounds, fieldName)
validateattributes(value, {'numeric'}, {'scalar', 'real', 'finite'}, ...
    'routeA_validate_case', fieldName);
if value < bounds(1) || value > bounds(2)
    error('RouteA:ValidateRange', ...
        '%s = %g is out of range [%g, %g].', ...
        fieldName, value, bounds(1), bounds(2));
end
end

%% -----------------------------------------------------------------------
function validateFixedAmbientPressure(value)
fieldName = 'controls.environment.ambientPressure_MPa_abs';
validateattributes(value, {'numeric'}, {'scalar', 'real', 'finite'}, ...
    'routeA_validate_case', fieldName);
fixedPressure_MPa_abs = routeA_platform_default_parameters().environment.ambient_p_MPa_abs.value;
if value ~= fixedPressure_MPa_abs
    error('RouteA:FixedAmbientPressure', ...
        '%s is fixed at %.6g MPa(abs) for the active Route A platform.', ...
        fieldName, fixedPressure_MPa_abs);
end
end

%% -----------------------------------------------------------------------
function validatePositive(value, fieldName)
validateattributes(value, {'numeric'}, {'scalar', 'real', 'finite'}, ...
    'routeA_validate_case', fieldName);
if value <= 0
    error('RouteA:ValidatePositive', ...
        '%s = %g must be positive.', fieldName, value);
end
end

function validateIntegerRange(value, bounds, fieldName)
validateattributes(value, {'numeric'}, {'scalar', 'real', 'finite'}, ...
    'routeA_validate_case', fieldName);
if value ~= fix(value) || value < bounds(1) || value > bounds(2)
    error('RouteA:ValidateIntegerRange', ...
        '%s = %g must be an integer in [%g, %g].', ...
        fieldName, value, bounds(1), bounds(2));
end
end

function validateBinary(value, fieldName)
if ~(islogical(value) || isnumeric(value)) || ~isscalar(value) || ...
        ~isreal(value) || ~isfinite(double(value)) || ...
        ~ismember(double(value), [0, 1])
    error('RouteA:ValidateBinary', '%s must be 0/1 or logical.', fieldName);
end
end

function validateSolverName(value)
value = string(value);
% Keep the case validator aligned with studyDefaults. Other solver names are
% not a valid P1 input until the active runner and model contract support them.
valid = "VariableStepAuto";
if ~isscalar(value) || ~any(value == valid)
    error('RouteA:ValidateSolverName', ...
        'solver.solver must be one of: %s. Got: %s.', ...
        strjoin(valid, ', '), value);
end
end

%% -----------------------------------------------------------------------
function validateElectricalMutex(electrical)
mode = string(electrical.mode);
if mode == "Voltage"
    vc = electrical.voltageController;
    if ~isstruct(vc) || isempty(vc)
        error('RouteA:ValidateElectricalMutex', ...
            'Voltage mode requires electrical.voltageController struct.');
    end
    required = {'Kp_A_V', 'Ki_A_V_s', 'currentMin_A', 'currentMax_A'};
    for i = 1:numel(required)
        if ~isfield(vc, required{i}) || isempty(vc.(required{i}))
            error('RouteA:ValidateElectricalMutex', ...
                'Voltage mode requires voltageController.%s.', required{i});
        end
    end
    if vc.currentMin_A >= vc.currentMax_A
        error('RouteA:ValidateElectricalMutex', ...
            'currentMin_A (%g) must be less than currentMax_A (%g).', ...
            vc.currentMin_A, vc.currentMax_A);
    end
    % Range validation for PI gains (only checked in Voltage mode)
    validatePositive(vc.Kp_A_V, 'voltageController.Kp_A_V');
    validatePositive(vc.Ki_A_V_s, 'voltageController.Ki_A_V_s');
end
end

function validateExplicitVoltageController(simCase)
if ~isstruct(simCase) || ~isfield(simCase, 'controls') || ...
        ~isstruct(simCase.controls) || ...
        ~isfield(simCase.controls, 'electrical') || ...
        ~isstruct(simCase.controls.electrical) || ...
        ~isfield(simCase.controls.electrical, 'mode')
    return;
end
if string(simCase.controls.electrical.mode) ~= "Voltage"
    return;
end
if ~isfield(simCase.controls.electrical, 'voltageController')
    return;
end

controller = simCase.controls.electrical.voltageController;
if isempty(controller)
    error('RouteA:ValidateElectricalMutex', ...
        'Voltage mode requires electrical.voltageController struct.');
end
if ~isstruct(controller) || ~isscalar(controller)
    error('RouteA:ValidateElectricalMutex', ...
        'electrical.voltageController must be a scalar struct.');
end
required = {'Kp_A_V', 'Ki_A_V_s', 'currentMin_A', 'currentMax_A'};
missing = required(~isfield(controller, required));
if ~isempty(missing)
    error('RouteA:ValidateElectricalMutex', ...
        'Voltage controller is missing field(s): %s.', ...
        strjoin(missing, ', '));
end
end
