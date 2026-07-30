function report = run_routeA_p1_panel_contract_tests()
% Optional P1 development wiring smoke; no simulation and no completion gate.

base = routeA_simCase_template();
base.caseId = "p1_contract_valid";
base.controls.electrical.profile = 100;
matrix = routeA_p1_panel_capability_matrix();
assert(matrix.counts.resultObservationCount == 22, ...
    'P1 expects 22 result observations.');
assert(matrix.counts.statusOnlyObservationCount == 4, ...
    'P1 expects four status-only observations.');
assert(all(arrayfun(@(entry) strlength(entry.uiProperty) > 0, ...
    matrix.parameters)), 'An active parameter has no UI mapping.');
assert(all(arrayfun(@(entry) strlength(entry.simCasePath) > 0, ...
    matrix.parameters)), 'An active parameter has no simCase path.');
assert(all(arrayfun(@(entry) strlength(entry.writePath) > 0, ...
    matrix.parameters)), 'An active parameter has no write point.');

names = { ...
    'airControlMode', 'targetOer', 'targetMdot_kg_s', 'directCommand', ...
    'sourcePressure_MPa_abs', 'sourceTemperature_C', 'humidifierRH', ...
    'o2MoleFraction', 'h2oMoleFraction', 'outletPressure_MPa_abs', ...
    'cegrRatio', 'valveMode', 'controlMode', 'targetInputMode', ...
    'stackTemperatureSet_C', 'stopTime_s', 'solver', 'relTol', ...
    'absTol', 'maxStep_s', 'voltageController'};
values = { ...
    4, 1, 0, -0.1, 0.05, 5, 1.1, 0.1, 0.001, 0.05, ...
    0.6, 3, 2, 2, 120, 0, 'ode1', 0, 0, -1, 'bad'};
tests = repmat(struct('name', "", 'passed', false, 'errorId', "", ...
    'message', ""), numel(names), 1);
for idx = 1:numel(names)
    candidate = setValue(base, names{idx}, values{idx});
    tests(idx).name = string(names{idx});
    try
        routeA_validate_case(candidate);
        error('RouteA:P1ContractTestNotRejected', ...
            'Invalid input %s was not rejected.', names{idx});
    catch ME
        tests(idx).passed = ~strcmp(ME.identifier, ...
            'RouteA:P1ContractTestNotRejected');
        tests(idx).errorId = string(ME.identifier);
        tests(idx).message = string(ME.message);
        assert(tests(idx).passed, '%s', ME.message);
    end
end

valid = base;
valid.controls.cegr.enabled = false;
valid.controls.cegr.targetRatio = 0.3;
valid = routeA_validate_case(valid);
assert(valid.controls.cegr.targetRatio == 0, ...
    'Disabled cEGR must normalize targetRatio to zero.');

rampRejected = false;
try
    routeA_panel_build_simulation_input(valid, valid.solver.stopTime_s);
catch ME
    rampRejected = strcmp(ME.identifier, 'RouteA:PanelRampDuration') || ...
        contains(string(ME.identifier), "RampDuration");
end
assert(rampRejected, 'Ramp duration equal to stop time was not rejected.');

[~, context] = routeA_panel_build_simulation_input(valid, ...
    min(60, 0.1 * valid.solver.stopTime_s));
assert(~context.requestedCegrEnabled && context.requestedCegrRatio == 0, ...
    'Disabled cEGR was not propagated through the panel builder.');
assert(~context.cegrControls.enabled && context.cegrControls.valveMode == ...
    valid.controls.cegr.valveMode, ...
    'cEGR compile-time controls were not propagated through the builder.');

% Exercise every electrical boundary and every mutually exclusive air mode
% through the same panel builder. These are wiring checks only; no sim() is
% started here.
electricalTypes = ["Current", "Power", "Voltage"];
electricalCommands = [100, 40, 410];
for idx = 1:numel(electricalTypes)
    modeCase = valid;
    modeCase.controls.electrical.mode = char(electricalTypes(idx));
    modeCase.controls.electrical.profile = electricalCommands(idx);
    [~, modeContext] = routeA_panel_build_simulation_input(modeCase, ...
        min(60, 0.1 * modeCase.solver.stopTime_s));
    assert(modeContext.boundaryType == electricalTypes(idx), ...
        'Electrical boundary %s did not reach the builder.', ...
        electricalTypes(idx));
end

for modeId = 1:3
    modeCase = valid;
    modeCase.controls.cathode.airControlMode = modeId;
    modeCase.controls.cathode.targetOer = 3;
    modeCase.controls.cathode.targetMdot_kg_s = 0.045;
    modeCase.controls.cathode.directCommand = 0.45;
    [~, modeContext] = routeA_panel_build_simulation_input(modeCase, ...
        min(60, 0.1 * modeCase.solver.stopTime_s));
    assert(modeContext.air.modeId == modeId, ...
        'Air control mode %d did not reach the builder.', modeId);
end

advancedCase = valid;
advancedCase.controls.electrical.mode = 'Voltage';
advancedCase.controls.electrical.profile = 410;
advancedCase.controls.cathode.airControlMode = 3;
advancedCase.controls.cathode.directCommand = 0.45;
advancedCase.controls.cathode.sourcePressure_MPa_abs = 0.17;
advancedCase.controls.cathode.sourceTemperature_C = 35;
advancedCase.controls.cathode.o2MoleFraction = 0.19;
advancedCase.controls.cathode.h2oMoleFraction = 0.012;
advancedCase.controls.cathode.humidifierEnabled = true;
advancedCase.controls.cegr.enabled = true;
advancedCase.controls.cegr.targetRatio = 0.3;
advancedCase.controls.cegr.valveMode = 2;
[~, advancedContext] = routeA_panel_build_simulation_input(advancedCase, ...
    min(60, 0.1 * advancedCase.solver.stopTime_s));
assert(advancedContext.air.modeId == 3 && ...
    advancedContext.cathode.sourcePressure_MPa_abs == 0.17 && ...
    advancedContext.cathode.sourceTemperature_C == 35 && ...
    advancedContext.requestedCegrRatio == 0.3 && ...
    advancedContext.cegrControls.valveMode == 2, ...
    'Advanced panel controls did not reach the unified builder.');

report = struct( ...
    'schemaVersion', "RouteA_P1_Panel_Contract_Tests_v01", ...
    'passed', true, ...
    'simulationStarted', false, ...
    'invalidInputCount', numel(tests), ...
    'invalidInputs', tests, ...
    'disabledCegrTargetNormalized', valid.controls.cegr.targetRatio, ...
    'rampRejected', rampRejected, ...
    'electricalModesBuilt', numel(electricalTypes), ...
    'airModesBuilt', 3, ...
    'advancedMappingPassed', true, ...
    'capabilityCounts', matrix.counts, ...
    'generatedAt', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
end

function simCase = setValue(simCase, name, value)
switch name
    case 'airControlMode'
        simCase.controls.cathode.airControlMode = value;
    case 'targetOer'
        simCase.controls.cathode.targetOer = value;
    case 'targetMdot_kg_s'
        simCase.controls.cathode.targetMdot_kg_s = value;
    case 'directCommand'
        simCase.controls.cathode.directCommand = value;
    case 'sourcePressure_MPa_abs'
        simCase.controls.cathode.sourcePressure_MPa_abs = value;
    case 'sourceTemperature_C'
        simCase.controls.cathode.sourceTemperature_C = value;
    case 'humidifierRH'
        simCase.controls.cathode.humidifierRH = value;
    case 'o2MoleFraction'
        simCase.controls.cathode.o2MoleFraction = value;
    case 'h2oMoleFraction'
        simCase.controls.cathode.h2oMoleFraction = value;
    case 'outletPressure_MPa_abs'
        simCase.controls.cathode.outletPressure_MPa_abs = value;
    case 'cegrRatio'
        simCase.controls.cegr.targetRatio = value;
    case 'valveMode'
        simCase.controls.cegr.valveMode = value;
    case 'controlMode'
        simCase.controls.cegr.controlMode = value;
    case 'targetInputMode'
        simCase.controls.cegr.targetInputMode = value;
    case 'stackTemperatureSet_C'
        simCase.controls.thermal.stackTemperatureSet_C = value;
    case 'stopTime_s'
        simCase.solver.stopTime_s = value;
    case 'solver'
        simCase.solver.solver = value;
    case 'relTol'
        simCase.solver.relTol = value;
    case 'absTol'
        simCase.solver.absTol = value;
    case 'maxStep_s'
        simCase.solver.maxStep_s = value;
    case 'voltageController'
        simCase.controls.electrical.mode = 'Voltage';
        simCase.controls.electrical.voltageController.currentMin_A = 200;
        simCase.controls.electrical.voltageController.currentMax_A = 100;
    otherwise
        error('RouteA:P1ContractTestField', 'Unsupported test field %s.', name);
end
end
