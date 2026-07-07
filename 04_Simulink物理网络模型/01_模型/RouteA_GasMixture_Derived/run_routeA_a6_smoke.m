%% Route A A6 smoke run for compressor-inlet cathode cEGR
% Runs two short cases:
%   1. no_egr  : EGR valve near closed
%   2. low_egr : fixed low EGR valve area
%
% The script prints only compact KPI evidence. It does not export figures,
% CSV files, or model copies.

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = [model '.slx'];
scriptDir = fileparts(mfilename('fullpath'));
oldDir = pwd;
cleanup = onCleanup(@() cd(oldDir));
cd(scriptDir);

if ~bdIsLoaded(model)
    load_system(modelFile);
end

% Refresh the model workspace from the parameter script so recently added
% cegr_* variables are available during block parameter evaluation.
modelWorkspace = get_param(model, 'ModelWorkspace');
if strcmp(modelWorkspace.DataSource, 'MATLAB File')
    modelWorkspace.reload;
end

egrValvePath = Simulink.ID.getFullName([model ':1294']);
stopTime = '30';

caseDefs = struct( ...
    'name', {'no_egr', 'low_egr'}, ...
    'restrictionArea', {'cegr_valve_area_closed', 'cegr_valve_area_low'});

results = repmat(emptyResult(), numel(caseDefs), 1);

for k = 1:numel(caseDefs)
    in = Simulink.SimulationInput(model);
    in = in.setModelParameter( ...
        'StopTime', stopTime, ...
        'SignalLogging', 'on', ...
        'SignalLoggingName', 'logsout', ...
        'SimscapeLogType', 'all', ...
        'SimscapeLogName', ['simlog_' model]);
    in = in.setBlockParameter(egrValvePath, ...
        'restriction_area', caseDefs(k).restrictionArea);

    out = sim(in);
    results(k) = collectResult(out, caseDefs(k).name, ...
        caseDefs(k).restrictionArea);
end

assignin('base', 'routeA_smoke_results', results);
dispResults(results);

function result = emptyResult()
result = struct( ...
    'caseName', "", ...
    'restrictionArea', "", ...
    'cegrMdot', NaN, ...
    'pOutlet', NaN, ...
    'pEgrValveUp', NaN, ...
    'pEgrValveDown', NaN, ...
    'pCompInlet', NaN, ...
    'yO2Outlet', NaN, ...
    'yO2CompInlet', NaN);
end

function result = collectResult(out, caseName, restrictionArea)
logsout = out.logsout;
assertHasSignals(logsout, [ ...
    "routeA_cegr_mdot", ...
    "routeA_p_outlet", ...
    "routeA_p_egr_valve_up", ...
    "routeA_p_egr_valve_down", ...
    "routeA_p_comp_inlet", ...
    "routeA_yi_outlet", ...
    "routeA_yi_comp_inlet"]);

outletYi = lastLoggedValue(logsout, "routeA_yi_outlet");
inletYi = lastLoggedValue(logsout, "routeA_yi_comp_inlet");

result = emptyResult();
result.caseName = string(caseName);
result.restrictionArea = string(restrictionArea);
result.cegrMdot = scalarLast(logsout, "routeA_cegr_mdot");
result.pOutlet = scalarLast(logsout, "routeA_p_outlet");
result.pEgrValveUp = scalarLast(logsout, "routeA_p_egr_valve_up");
result.pEgrValveDown = scalarLast(logsout, "routeA_p_egr_valve_down");
result.pCompInlet = scalarLast(logsout, "routeA_p_comp_inlet");
result.yO2Outlet = pickSpecies(outletYi, 2);
result.yO2CompInlet = pickSpecies(inletYi, 2);
end

function assertHasSignals(logsout, expectedNames)
availableNames = string(logsout.getElementNames);
missing = expectedNames(~ismember(expectedNames, availableNames));
assert(isempty(missing), ...
    "Missing logged signal(s): %s", strjoin(missing, ", "));
end

function value = scalarLast(logsout, signalName)
value = lastLoggedValue(logsout, signalName);
value = value(1);
end

function value = lastLoggedValue(logsout, signalName)
signal = logsout.get(char(signalName)).Values;
data = signal.Data;
nTime = numel(signal.Time);

if isvector(data)
    value = data(end);
    return;
end

if size(data, 1) == nTime
    value = squeeze(data(end, :));
elseif size(data, ndims(data)) == nTime
    reshaped = reshape(data, [], nTime);
    value = reshaped(:, end).';
else
    value = squeeze(data(end, :));
end

value = value(:).';
end

function value = pickSpecies(vectorValue, speciesIndex)
if numel(vectorValue) >= speciesIndex
    value = vectorValue(speciesIndex);
else
    value = NaN;
end
end

function dispResults(results)
fprintf('\nRoute A A6 smoke summary\n');
fprintf('Signals are PS-Simulink converter outputs in block-native units.\n');
fprintf('%-8s %-24s %12s %12s %12s %12s %12s %10s %10s\n', ...
    'case', 'valve_area_expr', 'mdot_egr', 'p_out', 'p_valve_up', ...
    'p_valve_dn', 'p_comp_in', 'yO2_out', 'yO2_in');

for k = 1:numel(results)
    r = results(k);
    fprintf(['%-8s %-24s %12.5g %12.5g %12.5g %12.5g %12.5g ', ...
        '%10.5g %10.5g\n'], ...
        r.caseName, r.restrictionArea, r.cegrMdot, r.pOutlet, ...
        r.pEgrValveUp, r.pEgrValveDown, r.pCompInlet, ...
        r.yO2Outlet, r.yO2CompInlet);
end
end
