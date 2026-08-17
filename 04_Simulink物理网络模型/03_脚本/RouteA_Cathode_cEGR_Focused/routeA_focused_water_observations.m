function water = routeA_focused_water_observations(out, model, window)
% Collect gas-phase condensation and saturation evidence from Simscape logs.
%
% This function deliberately does not claim liquid inventory, carryover, or
% separator efficiency. It reports the gas-network quantities that the
% focused model actually exposes.

water = struct( ...
    'status', "not_collected", ...
    'scope', "gas_phase_condensation_and_saturation_only", ...
    'window_s', window, ...
    'nodes', repmat(nodeTemplate(), 0, 1), ...
    'liquidInventoryClosed', false, ...
    'liquidTransportClosed', false, ...
    'liquidDrainClosed', false, ...
    'separatorEfficiencyClosed', false);

try
    simlog = out.get(get_param(model, 'SimscapeLogName'));
    paths = routeA_block_paths(model);
    specs = { ...
        'compressor_inlet_mixer', paths.compressorInletMixer, 'mdot_cond'; ...
        'compressor_volume', paths.compressorVolume, 'mdot_cond'; ...
        'cathode_humidifier_pipe', ...
            [paths.cathodeHumidifier '/Pipe (FC)'], 'mdot_c'; ...
        'cathode_gas', [paths.cathodeGas '/Cathode'], 'mdot_cond'; ...
        'cathode_outlet_chamber', paths.outletChamber, 'mdot_cond'; ...
        'egr_pipe', paths.egrPipe, 'mdot_c'; ...
        'membrane_humidifier_wet_L2', ...
            [model '/Cathode_Exhaust_Backpressure_Water/' ...
            'MembraneHumidifierWet_L2_FC'], 'mdot_c'; ...
        'cathode_exhaust_pipe', ...
            [paths.cathodeExhaustBlock '/Pipe (N Gas)1'], 'mdot_c'};

    for idx = 1:size(specs, 1)
        item = nodeTemplate();
        item.name = string(specs{idx, 1});
        item.path = string(specs{idx, 2});
        item.condensationQuantity = string(specs{idx, 3});
        node = simscape.logging.findNode(simlog, char(item.path));
        if isempty(node) || ~isprop(node, char(item.condensationQuantity))
            if item.name == "membrane_humidifier_wet_L2"
                item.status = "not_applicable_L2_no_storage";
            else
                item.status = "unavailable";
            end
            water.nodes(end + 1) = item; %#ok<AGROW>
            continue;
        end

        item.condensation = seriesStats(node, ...
            char(item.condensationQuantity), 'kg/s', window);
        item.saturation = saturationStats(node, window);
        item.status = "collected";
        water.nodes(end + 1) = item; %#ok<AGROW>
    end

    collected = [water.nodes.status] == "collected" | ...
        [water.nodes.status] == "not_applicable_L2_no_storage";
    if all(collected)
        water.status = "collected";
    elseif any(collected)
        water.status = "partial";
    else
        water.status = "unavailable";
    end
catch exception
    water.status = "collection_error";
    water.errorId = string(exception.identifier);
    water.errorMessage = string(exception.message);
end
end

function item = nodeTemplate()
item = struct( ...
    'name', "", ...
    'path', "", ...
    'status', "not_collected", ...
    'condensationQuantity', "", ...
    'condensation', struct(), ...
    'saturation', struct());
end

function stats = seriesStats(node, propertyName, unit, window)
series = node.(propertyName).series;
time = series.time;
time = time(:);
data = series.values(unit);
data = normalizeData(data, time);
if size(data, 2) < 4
    error('RouteA:FocusedWaterSpecies', ...
        'Water species component is unavailable for %s.', propertyName);
end
values = data(:, 4);
mask = time >= window(1) & time < window(2);
if ~any(mask)
    error('RouteA:FocusedWaterWindow', ...
        'No samples are available in the focused water window.');
end
sampleTime = unique([window(1); time(mask); window(2)]);
sampleValues = interp1(time, values, sampleTime, 'linear', 'extrap');
stats = struct( ...
    'unit', unit, ...
    'mean_kg_s', trapz(sampleTime, sampleValues) / diff(window), ...
    'maximum_kg_s', max(sampleValues), ...
    'minimum_kg_s', min(sampleValues), ...
    'integral_kg', trapz(sampleTime, sampleValues));
end

function stats = saturationStats(node, window)
stats = struct('available', false);
if ~isprop(node, 'p_I') || ~isprop(node, 'T_I') || ...
        ~isprop(node, 'y_I_i')
    return;
end

pSeries = node.p_I.series;
p = pSeries.values('Pa');
tSeries = node.T_I.series;
T = tSeries.values('K');
ySeries = node.y_I_i.series;
time = pSeries.time;
time = time(:);
y = normalizeData(ySeries.values('1'), time);
p = p(:);
T = T(:);
if size(y, 2) < 4
    return;
end

temperatureC = T - 273.15;
pSat = 611.21 .* exp((18.678 - temperatureC ./ 234.5) .* ...
    (temperatureC ./ (257.14 + temperatureC)));
ratio = y(:, 4) .* p ./ pSat;
mask = time >= window(1) & time < window(2);
if ~any(mask)
    return;
end
stats = struct( ...
    'available', true, ...
    'maximum', max(ratio(mask)), ...
    'minimum', min(ratio(mask)), ...
    'mean', mean(ratio(mask)));
end

function data = normalizeData(data, time)
if isvector(data)
    data = data(:);
end
if size(data, 1) ~= numel(time)
    data = data.';
end
if size(data, 1) ~= numel(time)
    error('RouteA:FocusedWaterSeriesShape', ...
        'Simscape series shape is inconsistent with its time vector.');
end
end
