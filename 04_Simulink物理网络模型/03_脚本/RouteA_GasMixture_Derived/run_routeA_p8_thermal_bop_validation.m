function report = run_routeA_p8_thermal_bop_validation(options)
% Short dynamic response validation for the Route A thermal BOP groups.
% The runner keeps the passive cEGR/cold-start/L2 topology unchanged and
% perturbs one thermal group at a time through the unified SimulationInput.

if nargin < 1 || isempty(options)
    options = struct();
end
defaults = struct('stopTime_s', 30, 'rampDuration_s', 10, ...
    'current_A', 100, 'outputFile', "");
names = fieldnames(options);
for idx = 1:numel(names)
    if ~isfield(defaults, names{idx})
        error('RouteA:P8Option', 'Unsupported P8 option: %s.', names{idx});
    end
    defaults.(names{idx}) = options.(names{idx});
end
validateattributes(defaults.stopTime_s, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(defaults.rampDuration_s, {'numeric'}, ...
    {'scalar', 'nonnegative', 'finite', '<', defaults.stopTime_s});
validateattributes(defaults.current_A, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'});

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
scenarioNames = ["baseline", "radiator_area_up", ...
    "thermal_mass_up", "coolant_diameter_up"];
scenarioCount = numel(scenarioNames);
results = repmat(struct('name', "", 'simCompleted', false, ...
    'finiteSignals', false, 'writeReadback', struct(), ...
    'metrics', struct(), 'errorId', "", 'errorMessage', ""), ...
    scenarioCount, 1);

for idx = 1:scenarioCount
    name = scenarioNames(idx);
    results(idx).name = name;
    simCase = routeA_simCase_template();
    simCase.caseId = "p8_" + name;
    simCase.controls.electrical.mode = 'Current';
    simCase.controls.electrical.profile = defaults.current_A;
    simCase.controls.cegr.enabled = false;
    simCase.controls.cegr.targetRatio = 0;
    simCase.solver.stopTime_s = defaults.stopTime_s;
    switch name
        case "radiator_area_up"
            simCase.controls.devices.thermal.radiatorCore.length_m = 1.3;
            simCase.controls.devices.thermal.radiatorCore.height_m = 0.65;
            simCase.controls.devices.thermal.radiatorCore.finSpacing_m = 0.0018;
        case "thermal_mass_up"
            simCase.controls.devices.thermal.radiatorCore.density_kg_m3 = 4050;
            simCase.controls.devices.thermal.radiatorCore.specificHeat_J_kgK = 1365;
        case "coolant_diameter_up"
            simCase.controls.devices.thermal.coolantGeometry.tubeDiameter_m = 0.07;
    end
    try
        [simIn, context] = routeA_panel_build_simulation_input( ...
            simCase, defaults.rampDuration_s);
        results(idx).writeReadback = readWriteTargets(simIn);
        out = sim(simIn);
        results(idx).simCompleted = true;
        results(idx).metrics = extractThermalMetrics(out, model);
        results(idx).finiteSignals = results(idx).metrics.finiteSignals;
        results(idx).metrics.boundaryType = context.boundaryType;
    catch ME
        results(idx).errorId = string(ME.identifier);
        results(idx).errorMessage = string(ME.message);
    end
end

report = struct();
report.schemaVersion = "RouteA_P8_Thermal_BOP_Validation_v01";
report.model = string(model);
report.policy = struct('initialState', "cold", 'cegr', "passive_disabled", ...
    'waterManagement', "L2", 'topologyChanged', false);
report.scenarios = results;
report.allSimulationsCompleted = all([results.simCompleted]);
report.allSignalsFinite = all([results.finiteSignals]);
report.directionalSensitivity = compareSensitivity(results);
report.passed = report.allSimulationsCompleted && report.allSignalsFinite;
report.generatedAt = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
if strlength(string(defaults.outputFile)) > 0
    save(char(defaults.outputFile), 'report');
end
end

function targets = readWriteTargets(simIn)
variables = simIn.Variables;
names = string({variables.Name});
targets = struct();
targets.coolantTubeDiameter_m = variables(names == "coolant_tube_D").Value;
targets.radiatorPrimaryArea_m2 = variables( ...
    names == "radiator_air_area_primary").Value;
targets.radiatorFinArea_m2 = variables( ...
    names == "radiator_air_area_fins").Value;
targets.radiatorEquivalentLength_m = variables( ...
    names == "radiator_tube_Leq").Value;
targets.radiatorThermalMass_kg = variables(names == "radiator_rho").Value * ...
    variables(names == "radiator_t_wall").Value * ...
    (targets.radiatorPrimaryArea_m2 + targets.radiatorFinArea_m2);
end

function metrics = extractThermalMetrics(out, model)
logs = out.get('logsout');
stack = logs.get('routeA_stack_temperature_C').Values;
time = stack.Time;
stackValues = stack.Data;
logName = get_param(model, 'SimscapeLogName');
simlog = out.get(logName);
cooling = simlog.Thermal_Management_BOP.Cooling_System;
metrics = struct();
metrics.stackTemperature_C = summarize(stackValues, time);
metrics.radiatorTemperature_C = summarizeSeries( ...
    cooling.Radiator.T_I.series, 'degC');
metrics.radiatorHeat_kW = summarizeSeries(cooling.Radiator.Q_H.series, 'kW');
metrics.radiatorMdot_kg_s = summarizeSeries(cooling.Radiator.mdot_A.series, 'kg/s');
metrics.radiatorPressureLoss_MPa = summarizeSeries( ...
    cooling.Radiator.pressure_loss_A.series, 'MPa');
metrics.coolantTemperature_C = summarizeSeries( ...
    cooling.Fuel_Cell_Coolant_Channels.T_I.series, 'degC');
metrics.coolantMdot_kg_s = summarizeSeries( ...
    cooling.Fuel_Cell_Coolant_Channels.mdot_A.series, 'kg/s');
metrics.coolantPressureLoss_MPa = summarizeSeries( ...
    cooling.Fuel_Cell_Coolant_Channels.pressure_loss_A.series, 'MPa');
metrics.pumpMdot_kg_s = summarizeSeries(cooling.Pump.mdot_A.series, 'kg/s');
metrics.thermalMassTemperature_C = summarizeSeries( ...
    cooling.Thermal_Mass.T.series, 'degC');
metrics.convectiveHeat_W = summarizeSeries( ...
    cooling.Convective_Heat_Transfer.Q.series, 'W');
metrics.finiteSignals = allFinite(metrics);
end

function summary = summarizeSeries(series, unit)
summary = summarize(series.values(unit), series.time);
end

function summary = summarize(values, time)
values = squeeze(values);
values = values(:);
time = time(:);
tailCount = max(1, ceil(0.2 * numel(values)));
tail = values(end-tailCount+1:end);
summary = struct('mean', mean(tail, 'omitnan'), ...
    'std', std(tail, 0, 'omitnan'), 'span', max(tail) - min(tail), ...
    'minimum', min(values), 'maximum', max(values), ...
    'initial', values(1), 'final', values(end), ...
    'riseRateTail', slope(time(end-tailCount+1:end), tail), ...
    'nonfiniteCount', sum(~isfinite(values)));
end

function value = slope(time, data)
if numel(time) < 2 || time(end) == time(1)
    value = NaN;
else
    coeff = polyfit(time, data, 1);
    value = coeff(1);
end
end

function tf = allFinite(value)
if isstruct(value)
    fields = fieldnames(value);
    tf = true;
    for idx = 1:numel(fields)
        tf = tf && allFinite(value.(fields{idx}));
    end
elseif isnumeric(value)
    tf = all(isfinite(value(:)));
else
    tf = true;
end
end

function sensitivity = compareSensitivity(results)
sensitivity = struct('radiatorAreaDeltaTailStackTemperature_C', NaN, ...
    'thermalMassDeltaRiseRate_C_s', NaN, ...
    'coolantDiameterDeltaPressureLoss_MPa', NaN, ...
    'interpretation', "not_available");
if numel(results) < 4 || ~all([results.simCompleted])
    return;
end
base = results(1).metrics;
area = results(2).metrics;
mass = results(3).metrics;
diameter = results(4).metrics;
sensitivity.radiatorAreaDeltaTailStackTemperature_C = ...
    area.stackTemperature_C.mean - base.stackTemperature_C.mean;
sensitivity.thermalMassDeltaRiseRate_C_s = ...
    mass.stackTemperature_C.riseRateTail - base.stackTemperature_C.riseRateTail;
sensitivity.coolantDiameterDeltaPressureLoss_MPa = ...
    diameter.coolantPressureLoss_MPa.mean - base.coolantPressureLoss_MPa.mean;
sensitivity.interpretation = ...
    "Directional values are reported for engineering review; no topology or acceptance threshold is altered by this runner.";
end
