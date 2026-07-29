function schema = routeA_command_profile_schema()
% Single source of truth for the Route A 22-field runtime-command profile.
%
% The 22-field schema is referenced by every consumer of the unified runtime
% command profile:
%   - routeA_assemble_command_profile       builds the struct + compat matrix
%   - routeA_prepare_electrical_boundary_input   reads the model baseline
%   - routeA_model_contract                   checks the model alignment
%
% The model-workspace variable routeA_command_profile_fields and the
% routeA_command_profile_baseline row vector must stay aligned with this
% order. Changing the field set or order here is the single edit point; all
% consumers pick up the change. Do not duplicate this list elsewhere.
%
% Output:
%   schema.names    - 22x1 string column vector of field names
%   schema.labels   - 22x1 string column vector of short normalized labels
%   schema.isStep   - 22x1 logical, true where the field is a step (no ramp)
%   schema.count    - scalar double, 22
%   schema.version  - string, "RouteA_Command_Profile_v10"
%
% See also: routeA_assemble_command_profile

names = [ ...
    "cathode_source_pressure_MPa_abs";
    "cathode_source_temperature_C";
    "cathode_source_o2_mole_fraction";
    "cathode_source_h2o_mole_fraction";
    "air_target_mdot_kg_s";
    "air_target_oer";
    "air_direct_command";
    "cathode_outlet_pressure_MPa_abs";
    "cathode_humidifier_rh";
    "cathode_humidifier_gain";
    "cegr_ratio";
    "anode_source_pressure_MPa_abs";
    "anode_source_temperature_C";
    "anode_source_h2_mole_fraction";
    "anode_inlet_pressure_MPa_abs";
    "anode_humidifier_rh";
    "anode_recirculation_base";
    "anode_recirculation_current_gain_A_inv";
    "anode_purge_enable";
    "anode_purge_on_n2_mole_fraction";
    "anode_purge_off_n2_mole_fraction";
    "stack_temperature_set_C"];

labels = [ ...
    "CathodeSourcePressure";
    "CathodeSourceTemperature";
    "CathodeSourceO2";
    "CathodeSourceH2O";
    "AirTargetMdot";
    "AirTargetOer";
    "AirDirectCommand";
    "CathodeOutletPressure";
    "CathodeHumidifierRH";
    "CathodeHumidifierGain";
    "CEGR";
    "AnodeSourcePressure";
    "AnodeSourceTemperature";
    "AnodeSourceH2";
    "AnodeInletPressure";
    "AnodeHumidifierRH";
    "AnodeRecirculationBase";
    "AnodeRecirculationGain";
    "AnodePurgeEnable";
    "AnodePurgeOnN2";
    "AnodePurgeOffN2";
    "StackTemperature"];

% The purge-enable flag is a discrete on/off command and must not be ramped.
isStep = false(size(names));
isStep(names == "anode_purge_enable") = true;

schema = struct();
schema.names = names;
schema.labels = labels;
schema.isStep = isStep;
schema.count = numel(names);
% v10 is the established command-profile schema revision. It does not define
% the active runtime initialization policy.
schema.version = "RouteA_Command_Profile_v10";

if schema.count ~= 22
    error('RouteA:CommandProfileSchemaCount', ...
        'The v10 command-profile schema must define exactly 22 fields.');
end
if numel(labels) ~= schema.count || numel(isStep) ~= schema.count
    error('RouteA:CommandProfileSchemaShape', ...
        'The v10 command-profile schema names/labels/isStep lengths disagree.');
end
if numel(unique(names)) ~= schema.count
    error('RouteA:CommandProfileSchemaDuplicate', ...
        'The v10 command-profile schema contains duplicate field names.');
end

end
