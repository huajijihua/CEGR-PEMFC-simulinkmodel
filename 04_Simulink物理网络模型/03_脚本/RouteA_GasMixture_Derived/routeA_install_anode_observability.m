function report = routeA_install_anode_observability()
% Install the minimum anode observations needed by the panel trust contract.

paths = routeA_project_paths();
model = char(paths.modelName);
if ~bdIsLoaded(model)
    load_system(paths.modelFile);
end

pressureScope = findOne(model, 'Pressure-Reducing.*Valve');
pressureSensor = findOne(pressureScope, 'Pressure.*Temperature');
sourceScope = findOne(model, '^Hydrogen\s*Source$');
sourceTank = findOne(sourceScope, '^Fuel\s*Tank$');
humidifierScope = findOne(model, '^Anode\s*Humidifier$');
humidifierSensor = findOne(humidifierScope, 'Composition.*Humidity');
humidifierConverter = findOne(humidifierScope, '^PS-Simulink\s*Converter$');
exhaustScope = findOne(model, '^Anode\s*Exhaust$');
exhaustConverter = findOne(exhaustScope, '^PS-Simulink\s*Converter$');
purgeState = findOne(exhaustScope, '^Purge_State_Memory$');

changed = false;
[changed, created] = addTankPressureCapture(changed, sourceScope, sourceTank, ...
    'FuelTankPressureSensor_FC', 'FuelTankPressure_PS2SL', ...
    'FuelTankPressure_ToWorkspace', 'routeA_anode_source_pressure_ts', ...
    [1110 12 1160 42]);
[changed, created] = addPhysicalCapture(changed, pressureScope, pressureSensor, 1, ...
    'AnodeInletPressure_PS2SL', 'AnodeInletPressure_ToWorkspace', ...
    'routeA_anode_inlet_pressure_ts', 'MPa', [390 80 440 110]);
[changed, created] = addPhysicalCapture(changed, pressureScope, pressureSensor, 2, ...
    'AnodeInletTemperature_PS2SL', 'AnodeInletTemperature_ToWorkspace', ...
    'routeA_anode_inlet_temperature_ts', 'degC', [390 150 440 180], created);
[changed, created] = addPhysicalCapture(changed, humidifierScope, humidifierSensor, 2, ...
    'AnodeInletComposition_PS2SL', 'AnodeInletComposition_ToWorkspace', ...
    'routeA_anode_inlet_yi_ts', '1', [380 170 430 200], created);
[changed, created] = addSignalCapture(changed, humidifierScope, humidifierConverter, ...
    'AnodeInletRH_ToWorkspace', 'routeA_anode_inlet_rh_ts', [510 80 600 110], created);
[changed, created] = addSignalCapture(changed, exhaustScope, exhaustConverter, ...
    'AnodeExhaustComposition_ToWorkspace', 'routeA_anode_outlet_yi_ts', [460 180 560 210], created);
[changed, created] = addSignalCapture(changed, exhaustScope, purgeState, ...
    'AnodePurgeState_ToWorkspace', 'routeA_anode_purge_state_ts', [460 250 560 280], created);

set_param(model, 'SimulationCommand', 'update');
if changed
    save_system(model, paths.modelFile);
end
assert(string(get_param(model, 'Dirty')) == "off", ...
    'RouteA:AnodeObservabilityDirty', 'The active model was not saved cleanly.');
report = struct('model', string(model), 'changed', changed, ...
    'created', string(created(:)), 'dirty', string(get_param(model, 'Dirty')));
end

function [changed, created] = addTankPressureCapture(changed, parent, tank, ...
        sensorName, converterName, sinkName, variableName, position)
created = strings(0, 1);
sensor = [parent '/' sensorName];
if ~isSimulinkPath(sensor)
    add_block('FuelCell_lib/sensors/Pressure and Temperature Sensor (FC)', sensor, ...
        'Position', position);
    tankPorts = get_param(tank, 'PortHandles');
    sensorPorts = get_param(sensor, 'PortHandles');
    % LConn3 is the Fuel Tank gas outlet; the sensor is a one-port observer.
    add_line(parent, tankPorts.LConn(3), sensorPorts.LConn(1), 'autorouting', 'on');
    changed = true;
    created(end + 1, 1) = string(sensor); %#ok<AGROW>
end
reference = [parent '/FuelTankPressureSensor_AbsoluteReference_FC'];
if ~isSimulinkPath(reference)
    add_block('FuelCell_lib/elements/Absolute Reference (FC)', reference, ...
        'Position', position + [0 80 0 80]);
    sensorPorts = get_param(sensor, 'PortHandles');
    referencePorts = get_param(reference, 'PortHandles');
    % The composition-reference port x_i must be closed exactly as on the
    % existing pressure-reducer sensor; it is not an additional gas branch.
    add_line(parent, sensorPorts.RConn(3), referencePorts.LConn(1), ...
        'autorouting', 'on');
    changed = true;
    created(end + 1, 1) = string(reference); %#ok<AGROW>
end
[changed, created] = addPhysicalCapture(changed, parent, sensor, 1, ...
    converterName, sinkName, variableName, 'MPa', position + [70 0 70 0], created);
[changed, created] = addPhysicalCapture(changed, parent, sensor, 2, ...
    'FuelTankTemperature_PS2SL', 'FuelTankTemperature_ToWorkspace', ...
    'routeA_anode_source_temperature_ts', 'degC', position + [70 70 70 70], created);
end

function [changed, created] = addPhysicalCapture(changed, parent, source, ...
        sourcePortIndex, converterName, sinkName, variableName, unit, position, created)
if nargin < 10
    created = strings(0, 1);
end
converter = [parent '/' converterName];
if ~isSimulinkPath(converter)
    add_block('nesl_utility/PS-Simulink Converter', converter, ...
        'Position', position);
    set_param(converter, 'Unit', unit);
    sourcePorts = get_param(source, 'PortHandles');
    converterPorts = get_param(converter, 'PortHandles');
    add_line(parent, sourcePorts.RConn(sourcePortIndex), converterPorts.LConn, ...
        'autorouting', 'on');
    changed = true;
    created(end + 1, 1) = string(converter); %#ok<AGROW>
end
[changed, created] = addSignalCapture(changed, parent, converter, sinkName, ...
    variableName, position + [140 0 140 0], created);
end

function [changed, created] = addSignalCapture(changed, parent, source, ...
        sinkName, variableName, position, created)
sink = [parent '/' sinkName];
if isSimulinkPath(sink)
    if string(get_param(sink, 'SaveFormat')) ~= "Structure With Time"
        set_param(sink, 'SaveFormat', 'Structure With Time');
        changed = true;
    end
    return;
end
add_block('simulink/Sinks/To Workspace', sink, 'Position', position);
set_param(sink, 'VariableName', variableName, 'SaveFormat', 'Structure With Time');
sourcePorts = get_param(source, 'PortHandles');
sinkPorts = get_param(sink, 'PortHandles');
add_line(parent, sourcePorts.Outport(1), sinkPorts.Inport(1), 'autorouting', 'on');
changed = true;
created(end + 1, 1) = string(sink); %#ok<AGROW>
end

function path = findOne(scope, expression)
matches = find_system(scope, 'FollowLinks', 'on', 'LookUnderMasks', 'all', ...
    'RegExp', 'on', 'Name', expression);
matches = matches(~strcmp(matches, scope));
assert(numel(matches) == 1, 'RouteA:AnodeObservabilityPath', ...
    'Expected one block matching %s below %s, found %d.', expression, scope, numel(matches));
path = matches{1};
end

function tf = isSimulinkPath(path)
tf = getSimulinkBlockHandle(path) ~= -1;
end
