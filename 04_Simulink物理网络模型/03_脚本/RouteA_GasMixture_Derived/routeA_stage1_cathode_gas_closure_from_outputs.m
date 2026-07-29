function audit = routeA_stage1_cathode_gas_closure_from_outputs(out, model, cfg)
% Audit cathode oxygen and cEGR gas closure from one completed output.
%
% This helper only consumes the SimulationOutput produced by a Stage 1
% runner. It does not modify the model and never calls sim.

required = {'tailWindow_s', 'stackCells', 'faradayConstant_C_mol', ...
    'molarMass_kg_mol', 'gas'};
if ~isstruct(cfg) || ~builtin('all', isfield(cfg, required))
    error('RouteA:GasClosureConfig', ...
        'The cathode gas-closure configuration is incomplete.');
end
requiredGas = {'n2Index', 'o2Index', 'h2oIndex', ...
    'absoluteResidualTolerance_kg_s', 'relativeResidualTolerance'};
if ~builtin('all', isfield(cfg.gas, requiredGas))
    error('RouteA:GasClosureGasConfig', ...
        'The cathode gas-closure tolerance configuration is incomplete.');
end
if ~isa(out, 'Simulink.SimulationOutput')
    error('RouteA:GasClosureOutputType', ...
        'Cathode gas closure requires a Simulink.SimulationOutput.');
end

logsout = out.logsout;
compMdot = magnitudeTimeseries(loggedTimeseries(logsout, ...
    'routeA_mdot_comp_inlet'));
compYi = loggedTimeseries(logsout, 'routeA_yi_comp_inlet');
egrMdot = magnitudeTimeseries(loggedTimeseries(logsout, 'EGR_mdot_log'));
exhaustMdot = magnitudeTimeseries(outputTimeseries(out, logsout, ...
    'routeA_exhaust_mdot', 'routeA_exhaust_mdot_ts'));
outletYi = loggedTimeseries(logsout, 'routeA_yi_outlet');
stackCurrent = loggedTimeseries(logsout, 'routeA_stack_current_A');
speciesMdot = out.get('routeA_mdot_species_ca_in_ts');
if numel(stackCurrent.Time) < 2
    simlog = out.get(get_param(model, 'SimscapeLogName'));
    mea = routeA_simscape_log_mea(simlog);
    stackCurrent = timeseries(mea.Icell.series.values('A'), ...
        mea.Icell.series.time);
end

species = abs(compositionMatrix(speciesMdot, ...
    'routeA_mdot_species_ca_in'));
outletMoleFraction = compositionMatrix(outletYi, 'routeA_yi_outlet');
compressorMoleFraction = compositionMatrix(compYi, 'routeA_yi_comp_inlet');
tailWindow = cfg.tailWindow_s;

inletMask = signalMask(speciesMdot.Time, tailWindow, ...
    'cathode inlet species mass flow');
outletMask = signalMask(outletYi.Time, tailWindow, ...
    'cathode outlet composition');
compressorMask = signalMask(compMdot.Time, tailWindow, ...
    'compressor inlet mass flow');
compressorYiMask = signalMask(compYi.Time, tailWindow, ...
    'compressor inlet composition');
egrMask = signalMask(egrMdot.Time, tailWindow, 'cEGR mass flow');
exhaustMask = signalMask(exhaustMdot.Time, tailWindow, 'exhaust mass flow');
currentMask = signalMask(stackCurrent.Time, tailWindow, 'stack current');

inletSpecies = mean(species(inletMask, :), 1);
inletTotal = sum(inletSpecies);
inletMassFraction = normalizeComposition(inletSpecies);
compressorMdotMean = mean(compMdot.Data(compressorMask));
compressorMoleMean = mean(compressorMoleFraction(compressorYiMask, :), 1);
compressorMassFraction = moleFractionToMassFraction( ...
    compressorMoleMean, cfg.molarMass_kg_mol);
compressorSpecies = compressorMdotMean * compressorMassFraction;
egrMdotMean = mean(egrMdot.Data(egrMask));
exhaustMdotMean = mean(exhaustMdot.Data(exhaustMask));
freshAirMdot = compressorMdotMean - egrMdotMean;

outletMoleMean = mean(outletMoleFraction(outletMask, :), 1);
outletMassFraction = moleFractionToMassFraction( ...
    outletMoleMean, cfg.molarMass_kg_mol);
egrAtOutlet = interpolate(egrMdot.Time, egrMdot.Data, outletYi.Time);
exhaustAtOutlet = interpolate(exhaustMdot.Time, exhaustMdot.Data, ...
    outletYi.Time);
outletTotal = mean(egrAtOutlet(outletMask) + exhaustAtOutlet(outletMask));
outletSpecies = outletTotal * outletMassFraction;

externalMoleFraction = externalAirMoleFraction(model);
externalMassFraction = moleFractionToMassFraction( ...
    externalMoleFraction, cfg.molarMass_kg_mol);
freshAirSpecies = freshAirMdot * externalMassFraction;
recycleSpecies = egrMdotMean * outletMassFraction;
mixExpectedSpecies = freshAirSpecies + recycleSpecies;

n2 = cfg.gas.n2Index;
o2 = cfg.gas.o2Index;
h2o = cfg.gas.h2oIndex;
stackCurrentMean = mean(abs(stackCurrent.Data(currentMask)));
o2FaradayConsumption = cfg.stackCells * stackCurrentMean / ...
    (4 * cfg.faradayConstant_C_mol) * cfg.molarMass_kg_mol(o2);

audit = struct();
audit.tailWindow_s = tailWindow;
audit.inletSpeciesMdot_kg_s = inletSpecies;
audit.inletTotalMdot_kg_s = inletTotal;
audit.inletMassFraction = inletMassFraction;
audit.outletSpeciesMdot_kg_s = outletSpecies;
audit.outletTotalMdot_kg_s = outletTotal;
audit.outletMassFraction = outletMassFraction;
audit.compressorInletSpeciesMdot_kg_s = compressorSpecies;
audit.compressorInletMassFraction = compressorMassFraction;
audit.freshAirMdot_kg_s = freshAirMdot;
audit.freshAirSpeciesMdot_kg_s = freshAirSpecies;
audit.recycleMdot_kg_s = egrMdotMean;
audit.recycleSpeciesMdot_kg_s = recycleSpecies;
audit.exhaustMdot_kg_s = exhaustMdotMean;
audit.externalAirMassFraction = externalMassFraction;
audit.mixExpectedSpeciesMdot_kg_s = mixExpectedSpecies;
audit.stackCurrent_A = stackCurrentMean;
audit.n2StackResidual_kg_s = inletSpecies(n2) - outletSpecies(n2);
audit.o2NetConsumption_kg_s = inletSpecies(o2) - outletSpecies(o2);
audit.o2FaradayConsumption_kg_s = o2FaradayConsumption;
audit.o2FaradayResidual_kg_s = audit.o2NetConsumption_kg_s - ...
    o2FaradayConsumption;
audit.h2oNetResidual_kg_s = inletSpecies(h2o) - outletSpecies(h2o);
audit.mixResidualSpeciesMdot_kg_s = compressorSpecies - mixExpectedSpecies;
audit.n2MixResidual_kg_s = audit.mixResidualSpeciesMdot_kg_s(n2);
audit.o2MixResidual_kg_s = audit.mixResidualSpeciesMdot_kg_s(o2);
audit.h2oMixResidual_kg_s = audit.mixResidualSpeciesMdot_kg_s(h2o);
audit.outletFlowClosure_kg_s = outletTotal - egrMdotMean - exhaustMdotMean;
audit.n2StackPassed = residualPassed(audit.n2StackResidual_kg_s, ...
    max(abs(inletSpecies(n2)), abs(outletSpecies(n2))), cfg.gas);
audit.o2FaradayPassed = residualPassed(audit.o2FaradayResidual_kg_s, ...
    max(abs(audit.o2NetConsumption_kg_s), abs(o2FaradayConsumption)), ...
    cfg.gas);
audit.n2MixPassed = residualPassed(audit.n2MixResidual_kg_s, ...
    max(abs(compressorSpecies(n2)), abs(mixExpectedSpecies(n2))), cfg.gas);
audit.o2MixPassed = residualPassed(audit.o2MixResidual_kg_s, ...
    max(abs(compressorSpecies(o2)), abs(mixExpectedSpecies(o2))), cfg.gas);
audit.finite = builtin('all', isfinite([ ...
    audit.n2StackResidual_kg_s, audit.o2FaradayResidual_kg_s, ...
    audit.n2MixResidual_kg_s, audit.o2MixResidual_kg_s, ...
    audit.outletFlowClosure_kg_s, audit.freshAirMdot_kg_s]));
audit.passed = audit.finite && audit.n2StackPassed && ...
    audit.o2FaradayPassed && audit.n2MixPassed && audit.o2MixPassed;
audit.observability = struct( ...
    'cathodeInlet', 'direct species mass flow', ...
    'cathodeOutlet', 'flow derived from EGR plus exhaust; composition direct', ...
    'recycleFlow', 'direct EGR mass flow', ...
    'freshAirFlow', 'derived compressor inlet total minus recycle flow', ...
    'externalAirComposition', 'direct model-workspace boundary');
end

function signal = loggedTimeseries(logsout, name)
element = logsout.get(name);
if isempty(element) || isempty(element.Values)
    error('RouteA:GasClosureMissingLoggedSignal', ...
        'The required logged signal is unavailable: %s.', name);
end
signal = element.Values;
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

function data = compositionMatrix(signal, signalName)
data = squeeze(signal.Data);
if isvector(data)
    if isscalar(signal.Time)
        data = reshape(data, 1, []);
    else
        data = data(:);
    end
end
if size(data, 1) ~= numel(signal.Time)
    data = data.';
end
if size(data, 1) ~= numel(signal.Time)
    error('RouteA:GasClosureCompositionShape', ...
        'Unexpected signal shape for %s.', signalName);
end
end

function mask = signalMask(time, window, label)
mask = time >= window(1) & time < window(2);
if ~any(mask)
    error('RouteA:GasClosureEmptyWindow', ...
        'No samples were found for %s in the requested tail window.', label);
end
end

function values = interpolate(time, data, targetTime)
values = interp1(time, data(:), targetTime, 'linear', 'extrap');
values = values(:);
if any(~isfinite(values))
    error('RouteA:GasClosureInterpolation', ...
        'Could not align gas-flow time bases.');
end
end

function massFraction = moleFractionToMassFraction(moleFraction, molarMass)
weighted = moleFraction .* molarMass;
massFraction = weighted ./ sum(weighted, 2);
end

function normalized = normalizeComposition(values)
total = sum(values, 2);
if any(total <= 0) || any(~isfinite(total))
    error('RouteA:GasClosureCompositionTotal', ...
        'A gas-composition total is nonpositive or nonfinite.');
end
normalized = values ./ total;
end

function moleFraction = externalAirMoleFraction(model)
mw = get_param(model, 'ModelWorkspace');
yO2 = mw.getVariable('env_yO2');
yH2O = mw.getVariable('env_yH20');
moleFraction = [1 - yO2 - yH2O, yO2, 0, yH2O];
end

function passed = residualPassed(residual, reference, gasCfg)
tolerance = max(gasCfg.absoluteResidualTolerance_kg_s, ...
    gasCfg.relativeResidualTolerance * max(reference, 1e-12));
passed = isfinite(residual) && abs(residual) <= tolerance;
end
