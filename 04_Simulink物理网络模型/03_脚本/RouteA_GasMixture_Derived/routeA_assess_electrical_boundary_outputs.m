function result = routeA_assess_electrical_boundary_outputs( ...
    out, model, context, caseCfg)
% Extract unified I/V/P, gas, cEGR, actuator, and boundary KPIs.

if ~isa(out, 'Simulink.SimulationOutput')
    error('RouteA:ElectricalBoundaryOutputType', ...
        'Output assessment requires a Simulink.SimulationOutput.');
end
if ~isstruct(context) || ~isfield(context, 'tailWindow_s')
    error('RouteA:ElectricalBoundaryContext', ...
        'The boundary assessment context is incomplete.');
end
logsout = out.logsout;
ratio = loggedTimeseries(logsout, 'routeA_egr_ratio_comp_in');
area = loggedTimeseries(logsout, 'routeA_egr_valve_area_cmd');
pUp = loggedTimeseries(logsout, 'routeA_p_egr_valve_up');
pDown = loggedTimeseries(logsout, 'routeA_p_egr_valve_down');
compMdot = magnitudeTimeseries(loggedTimeseries(logsout, ...
    'routeA_mdot_comp_inlet'));
compP = loggedTimeseries(logsout, 'routeA_p_comp_inlet');
compT = loggedTimeseries(logsout, 'routeA_T_comp_inlet');
outletT = loggedTimeseries(logsout, 'routeA_T_outlet');
compCmd = loggedTimeseries(logsout, 'routeA_compressor_cmd');
compRpm = loggedTimeseries(logsout, 'routeA_compressor_rpm');
airMdotSet = magnitudeTimeseries(loggedTimeseries(logsout, ...
    'routeA_air_mdot_set'));
airControlError = loggedTimeseries(logsout, 'routeA_air_control_error');
egrMdot = magnitudeTimeseries(loggedTimeseries(logsout, 'EGR_mdot_log'));
stackCurrent = loggedTimeseries(logsout, 'routeA_stack_current_A');
stackVoltage = loggedTimeseries(logsout, 'routeA_stack_voltage_V');
stackPower = routeA_stack_electrical_power_timeseries(logsout);
stackTemperature = loggedTimeseries(logsout, 'routeA_stack_temperature_C');
rhIn = waterRelativeHumidity(outputTimeseries(out, logsout, ...
    'routeA_RH_ca_in', 'routeA_RH_ca_in_ts'));
rhOut = waterRelativeHumidity(outputTimeseries(out, logsout, ...
    'routeA_RH_ca_out', 'routeA_RH_ca_out_ts'));
waterSeparator = outputTimeseries(out, logsout, 'routeA_m_water_sep', ...
    'routeA_m_water_sep_ts');
speciesMdot = out.get('routeA_mdot_species_ca_in_ts');
[species, speciesTotal, speciesMassFraction] = inletSpeciesMetrics(speciesMdot);
inletTotalMdot = timeseries(speciesTotal, speciesMdot.Time);
inletO2MassFraction = timeseries(speciesMassFraction(:, 2), ...
    speciesMdot.Time);
inletWaterVaporMdot = timeseries(species(:, 4), speciesMdot.Time);
lambdaCaIn = inletOxygenStoich(speciesMdot, stackCurrent, context.stackCells);
egrAtCompressorTime = interpolate(egrMdot.Time, egrMdot.Data, ...
    compMdot.Time);
freshAirApprox = timeseries(compMdot.Data - egrAtCompressorTime, ...
    compMdot.Time);
airMdotSetAtCompressorTime = interpolate(airMdotSet.Time, ...
    airMdotSet.Data, compMdot.Time);
compressorMdotTrackingError = timeseries(compMdot.Data - ...
    airMdotSetAtCompressorTime, compMdot.Time);
pressureDeltaMPa = timeseries((pUp.Data - pDown.Data) * 1e-6, pUp.Time);
areaFraction = timeseries(area.Data / context.cegrValveMaxArea_m2, area.Time);
outletPressure = loggedTimeseries(logsout, 'routeA_p_outlet');
outletPressureMPa = timeseries(outletPressure.Data * 1e-6, ...
    outletPressure.Time);

tail = struct();
tail.egrRatio = windowStats(ratio, context.tailWindow_s);
tail.egrMdot_kg_s = windowStats(egrMdot, context.tailWindow_s);
tail.freshAirApprox_kg_s = windowStats(freshAirApprox, context.tailWindow_s);
tail.inletTotalMdot_kg_s = windowStats(inletTotalMdot, context.tailWindow_s);
tail.inletWaterVaporMdot_kg_s = windowStats(inletWaterVaporMdot, ...
    context.tailWindow_s);
tail.stackCurrent_A = windowStats(stackCurrent, context.tailWindow_s);
tail.stackVoltage_V = windowStats(stackVoltage, context.tailWindow_s);
tail.stackPower_kW = windowStats(stackPower, context.tailWindow_s);
tail.stackTemperature_C = windowStats(stackTemperature, context.tailWindow_s);
tail.compressorMdot_kg_s = windowStats(compMdot, context.tailWindow_s);
tail.compressorMdotSet_kg_s = windowStats(airMdotSet, context.tailWindow_s);
tail.compressorMdotTrackingError_kg_s = windowStats( ...
    compressorMdotTrackingError, context.tailWindow_s);
tail.airControlError_kg_s = windowStats(airControlError, context.tailWindow_s);
tail.compressorPressure_Pa = windowStats(compP, context.tailWindow_s);
tail.compressorTemperature_K = windowStats(compT, context.tailWindow_s);
tail.cathodeOutletTemperature_K = windowStats(outletT, context.tailWindow_s);
tail.compressorCommand = windowStats(compCmd, context.tailWindow_s);
tail.compressorRpm = windowStats(compRpm, context.tailWindow_s);
tail.egrValveDeltaP_MPa = windowStats(pressureDeltaMPa, context.tailWindow_s);
tail.egrValveUpstreamPressure_Pa = windowStats(pUp, context.tailWindow_s);
tail.egrValveDownstreamPressure_Pa = windowStats(pDown, context.tailWindow_s);
tail.egrValveArea_m2 = windowStats(area, context.tailWindow_s);
tail.egrValveAreaFraction = windowStats(areaFraction, context.tailWindow_s);
tail.cathodeOutletPressure_MPa = windowStats(outletPressureMPa, ...
    context.tailWindow_s);
tail.rhCaIn = windowStats(rhIn, context.tailWindow_s);
tail.rhCaOut = windowStats(rhOut, context.tailWindow_s);
tail.waterSeparator = windowStats(waterSeparator, context.tailWindow_s);
tail.lambdaCaIn = windowStats(lambdaCaIn, context.tailWindow_s);
tail.inletO2MassFraction = windowStats(inletO2MassFraction, ...
    context.tailWindow_s);

steadySignals = struct( ...
    'stackCurrent_A', stackCurrent, ...
    'stackVoltage_V', stackVoltage, ...
    'stackPower_kW', stackPower, ...
    'stackTemperature_C', stackTemperature, ...
    'compressorMdot_kg_s', compMdot, ...
    'compressorPressure_Pa', compP, ...
    'compressorTemperature_K', compT, ...
    'cathodeInletWaterVaporMdot_kg_s', inletWaterVaporMdot, ...
    'cathodeOxygenStoich', lambdaCaIn, ...
    'egrRatio', ratio);
steady = assessSteady(steadySignals, context);

acceptance = acceptanceConfig(caseCfg, context.boundaryType);
boundaryTarget = interp1(context.boundaryModelTime_s, ...
    context.boundaryProfile.value, stackCurrent.Time, 'linear', 'extrap');
boundary = assessBoundary(context.boundaryType, boundaryTarget, ...
    stackCurrent, stackVoltage, stackPower, context, acceptance);
cegrTarget = interp1(context.cegrModelTime_s, context.cegrProfile.value, ...
    ratio.Time, 'linear', 'extrap');
cegr = assessCegr(cegrTarget, ratio, context.tailWindow_s, ...
    context.cegrControls, acceptance);
saturation = assessSaturation(logsout, context, stackVoltage, ...
    stackPower, acceptance);

gasClosure = routeA_stage1_cathode_gas_closure_from_outputs(out, ...
    model, context);
purge = purgeStats(out, model, context);
periodicAnode = assessPeriodicAnodeBehavior(stackCurrent, stackVoltage, ...
    stackPower, purge, context);
result = struct();
result.caseId = getCaseId(caseCfg);
result.modeId = 1;
result.boundaryType = context.boundaryType;
result.initialState = context.initialStateMetadata;
result.targetRatio = cegr.targetValue;
result.actualRatio = tail.egrRatio.mean;
result.targetError = cegr.tailMeanError;
result.targetTolerance = cegr.tolerance;
result.cegrTrackingRequired = cegr.trackingRequired;
result.targetAirEquivalentOer = context.air.targetOer;
result.targetCurrentA = commandTailValue(context, "Current");
result.targetPower_kW = commandTailValue(context, "Power");
result.targetVoltage_V = commandTailValue(context, "Voltage");
result.researchStartModelTime_s = context.researchStartTime_s;
result.researchDuration_s = context.researchDuration_s;
result.tailLogicalWindow_s = context.tailLogicalWindow_s;
result.tailModelWindow_s = context.tailWindow_s;
result.tail = tail;
result.steady = steady;
result.boundary = boundary;
result.cegr = cegr;
result.saturation = saturation;
result.gasClosure = gasClosure;
result.gasClosurePassed = gasClosure.passed;
result.purge = purge;
result.periodicAnode = periodicAnode;
result.tailPurgeFree = purge.observed && purge.tailEventCount == 0;
result.finiteTail = tailFinite(tail);
result.steadyPassed = steady.passed;
result.steadyStrictPassed = steady.strictPassed;
result.steadyEngineeringPassed = steady.engineeringPassed;
result.lambdaTailMin = tail.lambdaCaIn.minimum;
result.lambdaPassed = tail.lambdaCaIn.nonfiniteCount == 0 && ...
    tail.lambdaCaIn.minimum > 1;
result.pressureDirectionPassed = result.targetRatio == 0 || ...
    tail.egrValveDeltaP_MPa.mean > 0;
result.areaPassed = tail.egrValveAreaFraction.minimum >= 0 && ...
    tail.egrValveAreaFraction.maximum < 1 - 1e-6;
result.compressorRpmLookupPassed = ...
    tail.compressorRpm.minimum >= context.compressorRpmLookupBounds(1) - 1e-9 && ...
    tail.compressorRpm.maximum <= context.compressorRpmLookupBounds(2) + 1e-9;
% Mode 3 is an intentional direct compressor command and bypasses the
% mass-flow/OER controller. Its flow mismatch is diagnostic only, not a
% tracking failure. Modes 1 and 2 retain the closed-loop tracking gate.
result.compressorMdotTrackingPassed = context.air.modeId == 3 || ...
    tail.compressorMdotTrackingError_kg_s.maximumAbs <= ...
    max(0.02 * abs(tail.compressorMdotSet_kg_s.mean), 5e-4);
result.boundaryPassed = boundary.passed;
result.cegrPassed = cegr.passed;
result.saturationPassed = saturation.passed;
% This signal is produced by the L2 saturation-excess estimator. It is not
% a physical liquid separator flow, inventory, drain flow, or efficiency.
result.waterSeparation = struct( ...
    'sourceSignal', "routeA_m_water_sep_ts", ...
    'unit', "kg/s", ...
    'samplingLocation', "cathode exhaust observer before any liquid-water closure", ...
    'postProcessFormula', "model L2 saturation-excess estimate", ...
    'status', "not_validated_L2_estimate", ...
    'validationEvidence', "requires pressure/temperature/composition consistency; no liquid closure");
result.localPassed = result.finiteTail && result.boundaryPassed && ...
    result.cegrPassed && result.saturationPassed && result.lambdaPassed && ...
    result.pressureDirectionPassed && result.areaPassed && ...
    result.compressorRpmLookupPassed && ...
    result.compressorMdotTrackingPassed && result.gasClosurePassed && ...
    result.tailPurgeFree && result.steadyPassed;
result.passed = result.localPassed;
result.failureCategory = failureCategory(result);
end

function boundary = assessBoundary(type, target, current, voltage, power, context, acceptance)
switch type
    case "Current"
        actual = current;
        tolerance = acceptance.currentAbsoluteTolerance_A;
        errorScale = max(abs(target), 1);
        relativeTolerance = tolerance / errorScale;
    case "Power"
        actual = power;
        tolerance = acceptance.powerRelativeTolerance;
        relativeTolerance = tolerance;
    case "Voltage"
        actual = voltage;
        tolerance = acceptance.voltageRelativeTolerance;
        relativeTolerance = tolerance;
end
errorData = interpolate(actual.Time, actual.Data, actual.Time) - ...
    interpolate(current.Time, target, actual.Time);
tailMask = actual.Time >= context.tailWindow_s(1) & ...
    actual.Time < context.tailWindow_s(2);
if ~any(tailMask)
    error('RouteA:ElectricalBoundaryTrackingWindow', ...
        'No electrical samples are available in the tail window.');
end
tailErrors = abs(errorData(tailMask));
targetTail = interpolate(current.Time, target, actual.Time(tailMask));
actualTail = actual.Data(tailMask);
stats = struct();
stats.type = type;
stats.targetTailMean = mean(targetTail);
stats.actualTailMean = mean(actualTail);
stats.maxAbsError = max(abs(errorData));
stats.tailMaxAbsError = max(tailErrors);
stats.tailRelativeError = abs(mean(actualTail) - mean(targetTail)) / ...
    max(abs(mean(targetTail)), 1e-6);
stats.tailSpan = max(actualTail) - min(actualTail);
stats.targetProfile = context.boundaryProfile;
stats.passed = false;
if type == "Current"
    stats.passed = stats.tailMaxAbsError <= tolerance;
elseif type == "Power"
    stats.passed = stats.tailRelativeError <= relativeTolerance;
else
    stats.passed = stats.tailRelativeError <= relativeTolerance && ...
        stats.tailSpan <= acceptance.voltageSpanFraction * ...
        max(abs(stats.targetTailMean), 1e-6);
end
boundary = stats;
end

function cegr = assessCegr(target, actual, window, controls, acceptance)
mask = actual.Time >= window(1) & actual.Time < window(2);
if ~any(mask)
    error('RouteA:ElectricalBoundaryCegrWindow', ...
        'No cEGR samples are available in the tail window.');
end
data = actual.Data(mask);
targetData = target(mask);
cegr = struct();
cegr.targetValue = mean(targetData);
cegr.actualTailMean = mean(data);
cegr.tailMeanError = cegr.actualTailMean - cegr.targetValue;
cegr.tolerance = targetTolerance(cegr.targetValue, acceptance);
cegr.maxAbsError = max(abs(data - targetData));
cegr.trackingRequired = controls.controlMode == 1;
if cegr.trackingRequired
    cegr.passed = abs(cegr.tailMeanError) <= cegr.tolerance;
else
    % Direct valve-area control has no ratio feedback loop. Keep the
    % commanded reference and measured ratio for diagnosis, but accept the
    % physical response rather than applying the closed-loop tracking gate.
    cegr.passed = all(isfinite(data)) && all(data >= 0) && all(data <= 0.5);
end
end

function steady = assessSteady(signals, context)
steady = struct('required', context.calculationType == "steady", ...
    'passed', true, 'windowModel_s', [NaN, NaN], ...
    'relativeVariationLimit', context.steadyRelativeVariationLimit, ...
    'engineeringRelativeVariationLimit', ...
        context.engineeringSteadyRelativeVariationLimit, ...
    'strictPassed', true, 'engineeringPassed', true, ...
    'classification', "not_applicable", ...
    'maximumRelativeChange', NaN, 'metrics', struct());
if ~steady.required
    return;
end
windowEnd = context.tailWindow_s(2);
window = [windowEnd - context.steadyWindowDuration_s, windowEnd];
if window(1) < context.tailWindow_s(1) - eps
    error('RouteA:ElectricalBoundarySteadyWindow', ...
        'The requested steady window is outside the tail statistics window.');
end
midpoint = mean(window);
steady.windowModel_s = window;
names = fieldnames(signals);
maximum = 0;
for idx = 1:numel(names)
    name = names{idx};
    first = windowStats(signals.(name), [window(1), midpoint]);
    second = windowStats(signals.(name), [midpoint, window(2)]);
    scale = steadyMetricScale(name);
    relativeChange = abs(second.mean - first.mean) / ...
        max([abs(first.mean), abs(second.mean), scale]);
    metric = struct('firstHalfMean', first.mean, ...
        'secondHalfMean', second.mean, ...
        'relativeChange', relativeChange, ...
        'finite', first.nonfiniteCount == 0 && second.nonfiniteCount == 0, ...
        'strictPassed', false, 'engineeringPassed', false, 'passed', false);
    metric.strictPassed = metric.finite && ...
        metric.relativeChange <= context.steadyRelativeVariationLimit;
    metric.engineeringPassed = metric.finite && ...
        metric.relativeChange <= context.engineeringSteadyRelativeVariationLimit;
    metric.passed = metric.strictPassed;
    steady.metrics.(name) = metric;
    steady.strictPassed = steady.strictPassed && metric.strictPassed;
    steady.engineeringPassed = steady.engineeringPassed && ...
        metric.engineeringPassed;
    maximum = max(maximum, relativeChange);
end
steady.passed = steady.strictPassed;
if steady.strictPassed
    steady.classification = "strict_steady";
elseif steady.engineeringPassed
    steady.classification = "engineering_steady";
else
    steady.classification = "not_steady";
end
steady.maximumRelativeChange = maximum;
end

function scale = steadyMetricScale(name)
switch string(name)
    case {"stackCurrent_A", "stackVoltage_V", "stackPower_kW", ...
            "stackTemperature_C", "compressorTemperature_K", ...
            "cathodeOxygenStoich"}
        scale = 1;
    case "compressorPressure_Pa"
        scale = 1e3;
    case "compressorMdot_kg_s"
        scale = 1e-6;
    case "cathodeInletWaterVaporMdot_kg_s"
        scale = 1e-8;
    case "egrRatio"
        scale = 1e-4;
    otherwise
        error('RouteA:ElectricalBoundarySteadyMetric', ...
            'No scale is defined for steady metric %s.', name);
end
end

function saturation = assessSaturation(logsout, context, voltage, power, acceptance)
saturation = struct('applicable', false, 'tailFraction', 0, ...
    'maxAbsCommand_A', NaN, 'passed', true);
if context.boundaryType == "Current"
    return;
end
if context.boundaryType == "Voltage"
    status = optionalLoggedTimeseries(logsout, ...
        'routeA_voltage_current_saturated');
    limited = optionalLoggedTimeseries(logsout, ...
        'routeA_voltage_current_cmd_limited_A');
    saturation.applicable = true;
    if ~isempty(status)
        saturation.tailFraction = booleanTimeFraction(status, ...
            context.tailWindow_s);
    elseif ~isempty(limited)
        saturation.tailFraction = boundFraction(limited, context, acceptance);
    end
else
    targetPower = interp1(context.boundaryModelTime_s, ...
        context.boundaryProfile.value, power.Time, 'linear', 'extrap');
    rawCommand = targetPower * 1e3 ./ max(abs(voltage.Data), 1e-6);
    limited = optionalLoggedTimeseries(logsout, ...
        'routeA_power_current_cmd_limited_A');
    saturation.applicable = true;
    if isempty(limited)
        limited = power;
        limited.Data = power.Data .* 1e3 ./ max(abs(voltage.Data), 1e-6);
    end
    limitedData = interpolate(limited.Time, limited.Data, power.Time);
    status = abs(rawCommand - limitedData) > acceptance.currentSaturationTolerance_A;
    saturation.tailFraction = booleanTimeFraction( ...
        timeseries(double(status), power.Time), context.tailWindow_s);
    saturation.maxAbsCommand_A = max(abs(limitedData));
end
saturation.passed = saturation.tailFraction <= ...
    acceptance.currentSaturationTailFractionLimit;
end

function fraction = boundFraction(signal, context, acceptance)
sampleTime = unique([context.tailWindow_s(1); ...
    signal.Time(signal.Time > context.tailWindow_s(1) & ...
    signal.Time < context.tailWindow_s(2)); context.tailWindow_s(2)]);
data = interpolate(signal.Time, signal.Data, sampleTime);
atBound = abs(data - context.controller.currentMin_A) <= ...
    acceptance.currentSaturationTolerance_A | ...
    abs(data - context.controller.currentMax_A) <= ...
    acceptance.currentSaturationTolerance_A;
fraction = trapz(sampleTime, double(atBound)) / diff(context.tailWindow_s);
end

function fraction = booleanTimeFraction(signal, window)
time = signal.Time(:);
data = logical(signal.Data(:));
mask = time >= window(1) & time < window(2);
if ~any(mask)
    fraction = 0;
    return;
end
sampleTime = unique([window(1); time(mask); window(2)]);
sample = interp1(time, double(data), sampleTime, 'previous', 'extrap');
fraction = trapz(sampleTime, sample) / diff(window);
end

function value = commandTailValue(context, type)
value = NaN;
if context.boundaryType == type
    profile = context.boundaryProfile;
    data = profile.value(profile.time_s >= ...
        context.tailLogicalWindow_s(1) & ...
        profile.time_s < context.tailLogicalWindow_s(2));
    if ~isempty(data)
        value = mean(data);
    else
        value = profile.value(end);
    end
end
end

function acceptance = acceptanceConfig(caseCfg, type)
acceptance = struct( ...
    'currentAbsoluteTolerance_A', 5e-3, ...
    'powerRelativeTolerance', 5e-3, ...
    'voltageRelativeTolerance', 5e-3, ...
    'voltageSpanFraction', 5e-3, ...
    'cegrRatioTolerance', NaN, ...
    'currentSaturationTailFractionLimit', 0.01, ...
    'currentSaturationTolerance_A', 1e-6);
if isfield(caseCfg, 'acceptance') && isstruct(caseCfg.acceptance)
    user = caseCfg.acceptance;
    names = fieldnames(user);
    for idx = 1:numel(names)
        if isfield(acceptance, names{idx})
            acceptance.(names{idx}) = user.(names{idx});
        end
    end
end
if type == "Current"
    validateattributes(acceptance.currentAbsoluteTolerance_A, {'numeric'}, ...
        {'scalar', 'nonnegative', 'finite'});
end
end

function tolerance = targetTolerance(value, acceptance)
if abs(value) < eps
    tolerance = 1e-4;
else
    tolerance = max(0.002, 0.10 * abs(value));
end
if isfield(acceptance, 'cegrRatioTolerance') && ...
        isfinite(acceptance.cegrRatioTolerance)
    tolerance = acceptance.cegrRatioTolerance;
end
end

function category = failureCategory(result)
reasons = strings(1, 0);
if ~result.boundaryPassed
    reasons(end + 1) = "electrical_boundary";
end
if ~result.cegrPassed
    reasons(end + 1) = "cegr_tracking";
end
if ~result.saturationPassed
    reasons(end + 1) = "current_saturation";
end
if ~result.lambdaPassed
    reasons(end + 1) = "oxygen_supply";
end
if ~result.gasClosurePassed
    reasons(end + 1) = "gas_closure";
end
if ~result.steadyPassed
    reasons(end + 1) = "not_steady";
end
if ~result.tailPurgeFree
    reasons(end + 1) = "tail_purge";
end
category = strjoin(reasons, ";");
end

function id = getCaseId(caseCfg)
if isfield(caseCfg, 'caseId')
    id = string(caseCfg.caseId);
else
    id = "electrical_boundary_case";
end
end

function stats = windowStats(signal, window)
time = signal.Time(:);
data = squeeze(signal.Data);
if ~isvector(data)
    error('RouteA:ElectricalBoundaryWindowSignalShape', ...
        'Tail statistics require a scalar signal.');
end
data = data(:);
if numel(data) ~= numel(time)
    error('RouteA:ElectricalBoundaryWindowSignalShape', ...
        'Signal time and data dimensions are inconsistent.');
end
rawMask = time >= window(1) & time < window(2);
sampleTime = unique([window(1); time(rawMask); window(2)]);
values = interpolate(time, data, sampleTime);
finiteValues = values(isfinite(values));
stats = struct('mean', NaN, 'std', NaN, 'span', Inf, ...
    'minimum', NaN, 'maximum', NaN, 'sampleCount', sum(rawMask), ...
    'nonfiniteCount', sum(~isfinite(values)) + double(~any(rawMask)), ...
    'maximumAbs', Inf);
if numel(sampleTime) >= 2 && numel(finiteValues) == numel(values)
    duration = diff(window);
    stats.mean = trapz(sampleTime, values) / duration;
    variance = trapz(sampleTime, (values - stats.mean).^2) / duration;
    stats.std = sqrt(max(variance, 0));
    stats.span = max(finiteValues) - min(finiteValues);
    stats.minimum = min(finiteValues);
    stats.maximum = max(finiteValues);
    stats.maximumAbs = max(abs(finiteValues));
end
end

function values = interpolate(time, data, targetTime)
if isscalar(time)
    values = repmat(data(1), numel(targetTime), 1);
else
    values = interp1(time(:), squeeze(data), targetTime, 'linear', 'extrap');
end
values = values(:);
end

function signal = loggedTimeseries(logsout, name)
element = logsout.get(name);
if isempty(element) || isempty(element.Values)
    error('RouteA:ElectricalBoundaryMissingSignal', ...
        'The required logged signal is unavailable: %s.', name);
end
signal = element.Values;
end

function signal = optionalLoggedTimeseries(logsout, name)
signal = [];
try
    element = logsout.get(name);
    if ~isempty(element) && ~isempty(element.Values)
        signal = element.Values;
    end
catch
end
end

function signal = outputTimeseries(out, logsout, logName, outputName)
if datasetHasElement(logsout, logName)
    element = logsout.get(logName);
    if ~isempty(element) && ~isempty(element.Values)
        signal = element.Values;
        return;
    end
end
signal = out.get(outputName);
end

function present = datasetHasElement(dataset, name)
present = false;
try
    present = any(strcmp(dataset.getElementNames, name));
catch
end
end

function signal = magnitudeTimeseries(signal)
signal = timeseries(abs(signal.Data), signal.Time);
end

function rh = waterRelativeHumidity(signal)
data = squeeze(signal.Data);
if isvector(data)
    data = data(:);
end
if size(data, 1) ~= numel(signal.Time)
    data = data.';
end
if size(data, 2) < 4
    error('RouteA:ElectricalBoundaryHumidityShape', ...
        'The relative-humidity signal lacks the water component.');
end
rh = timeseries(data(:, 4), signal.Time);
end

function [species, total, massFraction] = inletSpeciesMetrics(signal)
data = squeeze(signal.Data);
if isvector(data)
    data = data(:);
end
if size(data, 1) ~= numel(signal.Time)
    data = data.';
end
if size(data, 1) ~= numel(signal.Time)
    error('RouteA:ElectricalBoundarySpeciesShape', ...
        'The cathode species flow signal has an unexpected shape.');
end
species = abs(data);
total = sum(species, 2);
if any(~isfinite(total))
    error('RouteA:ElectricalBoundarySpeciesTotal', ...
        'The cathode inlet species total is nonfinite.');
end
% Cold starts may legitimately have zero inlet flow before the startup ramp.
% Keep those rows finite; tail-window checks decide whether flow was established.
massFraction = zeros(size(species));
positive = total > 0;
massFraction(positive, :) = species(positive, :) ./ total(positive);
end

function lambda = inletOxygenStoich(speciesMdot, stackCurrent, stackCells)
[species, ~, ~] = inletSpeciesMetrics(speciesMdot);
current = interpolate(stackCurrent.Time, stackCurrent.Data, ...
    speciesMdot.Time);
o2SupplyMolS = species(:, 2) / 0.0319988;
o2ConsumptionMolS = stackCells * abs(current) / (4 * 96485.33212);
lambda = timeseries(o2SupplyMolS ./ o2ConsumptionMolS, speciesMdot.Time);
end

function purge = purgeStats(out, model, context)
purge = emptyPurgeStats();
try
    simlog = out.get(get_param(model, 'SimscapeLogName'));
    paths = routeA_block_paths(model);
    exhaust = simscape.logging.findNode(simlog, paths.anodeExhaust);
    valve = exhaust.Purge_Valve;
    series = valve.AR.series;
    time = series.time();
    area = series.values('m^2');
    time = time(:);
    area = area(:);
    if numel(time) ~= numel(area) || isempty(time) || ...
            any(~isfinite(time)) || any(~isfinite(area))
        return;
    end

    % Purge is an actual valve-open event, not an inferred anode-composition
    % slope. A scale-aware threshold avoids numerical zero around a closed valve.
    threshold = max(1e-12, 1e-6 * max(abs(area)));
    open = abs(area) > threshold;
    starts = [open(1); diff(double(open)) == 1];
    stops = [diff(double(open)) == -1; open(end)];
    eventTimes = time(starts);
    eventEndTimes = time(stops);
    eventDurations = max(0, eventEndTimes - eventTimes);
    tailMask = eventTimes >= context.tailWindow_s(1) & ...
        eventTimes < context.tailWindow_s(2);

    purge.observed = true;
    purge.source = "anode_exhaust_purge_valve_area";
    purge.openThreshold_m2 = threshold;
    purge.valveAreaMaximum_m2 = max(area);
    purge.eventTimesModel_s = eventTimes(:).';
    purge.eventEndTimesModel_s = eventEndTimes(:).';
    purge.eventDurations_s = eventDurations(:).';
    purge.tailEventTimesModel_s = eventTimes(tailMask).';
    purge.tailEventCount = sum(tailMask);
catch
    % The panel must distinguish unavailable anode observability from a
    % physically event-free run. Acceptance remains conservative below.
end
end

function purge = emptyPurgeStats()
purge = struct('observed', false, 'source', "not_observable", ...
    'openThreshold_m2', NaN, 'valveAreaMaximum_m2', NaN, ...
    'eventTimesModel_s', zeros(1, 0), ...
    'eventEndTimesModel_s', zeros(1, 0), ...
    'eventDurations_s', zeros(1, 0), ...
    'tailEventTimesModel_s', zeros(1, 0), 'tailEventCount', 0);
end

function periodic = assessPeriodicAnodeBehavior(current, voltage, power, ...
        purge, context)
% Report purge-cycle behavior separately from the steady-signal gate.
events = purge.eventTimesModel_s(:);
periodic = struct( ...
    'classification', "no_periodic_events", ...
    'eventCount', numel(events), ...
    'tailEventCount', purge.tailEventCount, ...
    'completeCycleCount', 0, ...
    'cyclePeriod_s', zeros(0, 1), ...
    'cyclePeriodMean_s', NaN, ...
    'cyclePeriodStd_s', NaN, ...
    'cycleStats', periodicCycleTemplate(zeros(0, 1)), ...
    'tailWindow', periodicWindowStats(current, voltage, power, ...
        context.tailWindow_s));
if numel(events) < 2
    if isscalar(events)
        periodic.classification = "insufficient_events";
    end
    return;
end

periodic.classification = "periodic_anode_inventory";
periodic.completeCycleCount = numel(events) - 1;
periodic.cyclePeriod_s = diff(events);
periodic.cyclePeriodMean_s = mean(periodic.cyclePeriod_s);
periodic.cyclePeriodStd_s = std(periodic.cyclePeriod_s, 0);
cycles = periodicCycleTemplate(events(1:end - 1));
for idx = 1:numel(cycles)
    window = [events(idx), events(idx + 1)];
    cycles(idx).end_s = window(2);
    cycles(idx).period_s = diff(window);
    cycles(idx).signals = periodicWindowStats(current, voltage, power, ...
        window);
end
periodic.cycleStats = cycles;
end

function cycles = periodicCycleTemplate(startTimes)
cycles = repmat(struct( ...
    'start_s', NaN, ...
    'end_s', NaN, ...
    'period_s', NaN, ...
    'signals', struct()), numel(startTimes), 1);
for idx = 1:numel(startTimes)
    cycles(idx).start_s = startTimes(idx);
end
end

function stats = periodicWindowStats(current, voltage, power, window)
stats = struct( ...
    'stackCurrent_A', windowStats(current, window), ...
    'stackVoltage_V', windowStats(voltage, window), ...
    'stackPower_kW', windowStats(power, window));
end

function passed = tailFinite(tail)
names = fieldnames(tail);
passed = true;
for idx = 1:numel(names)
    value = tail.(names{idx});
    if isstruct(value) && isfield(value, 'nonfiniteCount') && ...
            value.nonfiniteCount ~= 0
        passed = false;
        return;
    end
end
end
