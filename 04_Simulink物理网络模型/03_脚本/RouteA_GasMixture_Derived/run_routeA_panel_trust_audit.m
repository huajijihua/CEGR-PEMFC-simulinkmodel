function report = run_routeA_panel_trust_audit(options)
% Formal 101-input Route A panel trust audit.
if nargin < 1 || isempty(options), options = struct(); end
options = auditOptions(options);
paths = routeA_project_paths();
if strlength(string(options.outputRoot)) == 0
    options.outputRoot = fullfile(paths.panelResultRoot,'trust_audit');
end
if ~isfolder(options.outputRoot), mkdir(options.outputRoot); end
% v10 is intentionally a fresh evidence series. It does not load v02-v09:
% v10 adds Fuel Tank outlet P/T observations and normalizes Structure With
% selects RH from the H2O channel of the sensor W vector.
version = "RouteA_Panel_TrustAudit_v10";
info = dir(paths.modelFile);
checksum = string(info.bytes)+"_"+string(info.datenum);
matrix = routeA_p1_panel_capability_matrix(paths);
registry = routeA_parameter_registry(paths);
obs = routeA_observation_registry(paths);
inventory = routeA_audit_parameter_inventory(false);
mask = arrayfun(@(x) x.status=="active",registry.entries);
planOptions = options;
planOptions.caseFilter = strings(0,1);
planOptions.domainFilter = strings(0,1);
items = planAudit(registry.entries(mask),matrix.parameters,inventory,planOptions,checksum,version);
assertContractsComplete(items);
old = loadState(options.outputRoot,options.resume,checksum,version);
items = reuse(items,old.items);
if options.dryRun
    report = package(items,options,checksum,version,"dry_run");
    report.state = auditState(items,checksum,version); saveEvidence(report,fullfile(options.outputRoot,'dry_run')); return
end
ran = 0;
if options.parallel
    [items, ran] = runParallelItems(items, ran, options, obs, checksum, version);
end
for k = 1:numel(items)
    if options.parallel, break; end
    if ran >= options.maxCases, break; end
    if ~filterEntry(items(k),options), continue; end
    if options.resume && items(k).status~="planned" && items(k).status~="running" && ~(options.retryFailed && (contains(items(k).status,"failed") || contains(items(k).status,"no_observable"))), continue; end
    items(k) = runItem(items(k),options,obs);
    ran = ran+1;
    report = package(items,options,checksum,version,"running");
    report.state = auditState(items,checksum,version); saveEvidence(report,options.outputRoot);
end
status = ternary(any(string({items.status})=="planned"),"partial","completed");
report = package(items,options,checksum,version,status);
report.state = auditState(items,checksum,version); saveEvidence(report,options.outputRoot);
report.ran = ran;
if strlength(string(options.outputFile))>0, save(options.outputFile,'report','-v7.3'); end
end

function o = auditOptions(o)
d = struct('scope',"all_active",'dryRun',false,'maxCases',Inf,'resume',true,'outputRoot',"", ...
    'stopTimeShort_s',10,'stopTimeLong_s',600,'caseFilter',strings(0,1), ...
    'domainFilter',strings(0,1),'runLong',true,'outputFile',"",'shortRampDuration_s',[], ...
    'parallel',false,'parallelWorkers',2,'retryFailed',false);
for n = fieldnames(o)'
    if ~isfield(d,n{1}), error('RouteA:TrustAuditOption','Unsupported option %s.',n{1}); end
    d.(n{1}) = o.(n{1});
end
if d.scope~="all_active", error('RouteA:TrustAuditScope','Only all_active is supported.'); end
o=d;
end

function [items,ran] = runParallelItems(items,ran,options,obs,checksum,version)
pool = gcp('nocreate');
if isempty(pool), pool = parpool('local',options.parallelWorkers); end
pending = find(arrayfun(@(x) (x.status=="planned" || x.status=="running" || (options.retryFailed && (contains(x.status,"failed") || contains(x.status,"no_observable")))) && filterEntry(x,options),items));
limit = min(numel(pending),max(0,options.maxCases-ran)); pending = pending(1:limit);
cursor = 1; batchSize = min(pool.NumWorkers,max(1,numel(pending)));
while cursor <= numel(pending)
    ids = pending(cursor:min(cursor+batchSize-1,numel(pending)));
    futures = parallel.FevalFuture.empty(0,numel(ids));
    for j=1:numel(ids), futures(j)=parfeval(pool,@runItem,1,items(ids(j)),options,obs); end
    wait(futures);
    for j=1:numel(ids)
        idx=ids(j);
        if futures(j).State=="finished" && isempty(futures(j).Error)
            value=fetchOutputs(futures(j)); items(idx)=value;
        else
            items(idx).status="failed";
            if isempty(futures(j).Error)
                items(idx).failureReason="Parallel future did not finish.";
            else
                items(idx).failureReason=string(futures(j).Error.identifier)+": "+string(futures(j).Error.message);
            end
        end
        ran=ran+1; partial=package(items,options,checksum,version,"running"); partial.state=auditState(items,checksum,version); saveEvidence(partial,options.outputRoot);
    end
    cursor=cursor+numel(ids);
end
end

function a = planAudit(entries,params,inventory,options,checksum,version)
t = itemTemplate(); a=repmat(t,0,1);
for k=1:numel(entries)
    e=entries(k); if ~filterEntry(e,options), continue; end
    p=params(strcmp(string({params.canonicalName}),string(e.canonicalName)));
    x=t; x.canonicalName=string(e.canonicalName); x.domain=string(e.domain); x.uiControl=string(p.uiProperty);
    x.simCasePath=string(p.simCasePath); x.writePath=string(p.writePath); x.unit=string(e.unit); x.baseValue=e.defaultValue;
    [x.perturbValue,x.perturbationStatus,x.perturbationRule]=makePerturbation(e); x.linkedObservations=string(p.observationLinks(:));
    x.consumer=consumerEvidence(inventory,x.canonicalName,e);
    x.validationContract=validationContract(x.canonicalName,x.linkedObservations,e,p,x.consumer);
    x.fingerprint=fingerprint(checksum,version,x,options); x.status="planned"; a(end+1,1)=x; %#ok<AGROW>
end
end

function x = runItem(x,options,obs)
if x.perturbationStatus~="ready", x.status="blocked_perturbation_definition"; x.failureReason=x.perturbationStatus; return; end
if ~x.validationContract.defined, x.status="blocked_validation_contract"; x.failureReason=x.validationContract.reason; return; end
if ~x.validationContract.runnable, x.status="blocked_observation_unavailable"; x.failureReason=x.validationContract.reason; return; end
b=makeCase(x,x.baseValue,options,false); q=makeCase(x,x.perturbValue,options,true);
x.short.base=runOne(b,options.stopTimeShort_s,options,obs); x.short.perturb=runOne(q,options.stopTimeShort_s,options,obs); x.short=evaluate(x.short,x);
if options.runLong && x.short.gatePassed
    x.long.base=runOne(b,options.stopTimeLong_s,options,obs); x.long.perturb=runOne(q,options.stopTimeLong_s,options,obs); x.long=evaluate(x.long,x);
else, x.long=struct('status',"not_run_short_gate",'gatePassed',false); end
if x.short.gatePassed && (x.long.status=="not_run_short_gate" || x.long.gatePassed), x.status="completed";
elseif contains(x.short.status,"failed"), x.status="failed"; else, x.status=x.short.status; end
x.failureReason=x.short.status;
end

function r=runOne(c,stopTime,options,obs)
r=outcome(); c.solver.stopTime_s=stopTime;
if isempty(options.shortRampDuration_s), ramp=min(60,.1*stopTime); else, ramp=min(options.shortRampDuration_s,.9*stopTime); end
try
    [in,ctx]=routeA_panel_build_simulation_input(c,ramp); r.writeReadback=readback(in);
    if ~r.writeReadback.passed, r.status="write_readback_failed"; r.reason=r.writeReadback.reason; return; end
    out=sim(in); if strlength(string(out.ErrorMessage))>0, r.status="simulation_failed"; r.reason=string(out.ErrorMessage); return; end
    z=routeA_panel_extract_results(out,c,ctx); r.executed=true; r.status="executed"; r.metrics=metrics(z); r.signalManifest=z.signalManifest; r.resultStatus=safeText(z.status); r.modelVersion=safeText(z.modelVersion); r.topologyHash=safeText(z.topologyHash);
catch err, r.status="failed"; r.reason=string(err.identifier)+": "+string(err.message); end
end

function p=evaluate(p,item)
p.executionPassed=p.base.executed && p.perturb.executed; p.response=response(p.base,p.perturb,item.validationContract); p.direction=direction(item,p.base,p.perturb); p.unit=units(p.base,item.validationContract.observations); p.consumerPassed=item.consumer.passed && p.base.writeReadback.passed && p.perturb.writeReadback.passed;
p.gatePassed=p.executionPassed && p.consumerPassed && p.response.passed && (p.direction.passed || ismember(p.direction.status,["response_only","not_applicable"])) && p.unit.passed;
if ~p.executionPassed, p.status="execution_failed"; elseif ~p.consumerPassed, p.status="consumer_failed"; elseif ~p.response.passed, p.status=ternary(item.validationContract.evaluationKind=="numerical_integrity","numerical_integrity_failed","no_observable_response"); elseif ~(p.direction.passed || ismember(p.direction.status,["response_only","not_applicable"])), p.status="direction_failed"; elseif ~p.unit.passed, p.status="unit_contract_failed"; else, p.status="gate_passed"; end
end

function r=response(b,q,contract)
r=struct('passed',false,'status',"not_observable",'deltas',struct(),'reason',""); if ~b.executed || ~q.executed || ~contract.defined || isempty(contract.observations), r.reason="No completed pair or validation observation."; return; end
if contract.evaluationKind=="numerical_integrity"
    r=numericalConsistency(b,q,contract);
    return
end
changed=false;
for k=1:numel(contract.observations)
    key=metricKey(contract.observations(k));
    if isfield(b.metrics,key) && isfield(q.metrics,key)
        baseValue=scalarMetric(b.metrics.(key)); perturbValue=scalarMetric(q.metrics.(key));
        if isnumeric(baseValue) && isnumeric(perturbValue) && isscalar(baseValue) && isscalar(perturbValue)
            d=perturbValue-baseValue; r.deltas.(key)=d;
            changed=changed || (isfinite(d) && abs(d)>1e-9);
        end
    end
end
r.passed=changed; r.status=ternary(changed,"changed","no_change"); r.reason=ternary(changed,"Linked model signal changed.","No linked signal exceeded tolerance.");
end

function r=numericalConsistency(b,q,contract)
r=struct('passed',false,'status',"not_observable",'deltas',struct(),'reason',"");
available=false; consistent=true;
for k=1:numel(contract.observations)
    key=metricKey(contract.observations(k));
    if ~isfield(b.metrics,key) || ~isfield(q.metrics,key), continue; end
    baseValue=scalarMetric(b.metrics.(key)); perturbValue=scalarMetric(q.metrics.(key));
    if ~isnumeric(baseValue) || ~isnumeric(perturbValue) || ~isscalar(baseValue) || ~isscalar(perturbValue), continue; end
    d=perturbValue-baseValue; scale=max([1,abs(baseValue),abs(perturbValue)]);
    r.deltas.(key)=d; r.deltas.(key+"_relative")=abs(d)/scale;
    available=true; consistent=consistent && isfinite(d) && abs(d)/scale<=0.05;
end
r.passed=available && consistent;
r.status=ternary(r.passed,"numerically_consistent","numerically_inconsistent");
r.reason=ternary(r.passed,"Solver perturbation preserved the declared physical checks.","Solver perturbation changed a declared physical check by more than 5 percent.");
end

function r=direction(item,b,q)
r=struct('passed',true,'status',"response_only",'rule',"response_only",'reason',""); n=item.canonicalName; m="";
rule=item.validationContract.directionRule;
if rule=="inlet_OER_and_air_flow_increase", r.rule=rule; m="cathode_inlet_oer";
elseif rule=="inlet_mass_flow_increase", r.rule=rule; m="cathode_compressor_mdot_kg_s";
elseif rule=="cathode_outlet_pressure_increase", r.rule=rule; m="cathode_outlet_pressure_MPa";
elseif rule=="RH_increase", r.rule=rule; m="cathode_rh_in";
elseif rule=="anode_source_pressure_increase", r.rule=rule; m="anode_source_pressure_MPa";
elseif rule=="anode_inlet_pressure_increase", r.rule=rule; m="anode_inlet_pressure_MPa";
elseif rule=="anode_source_temperature_increase", r.rule=rule; m="anode_source_temperature_C";
elseif rule=="anode_inlet_temperature_increase", r.rule=rule; m="anode_inlet_temperature_C";
elseif rule=="anode_inlet_hydrogen_increase", r.rule=rule; m="anode_inlet_hydrogen_mole_fraction";
elseif rule=="anode_inlet_RH_increase", r.rule=rule; m="anode_inlet_rh";
elseif rule=="not_applicable", r.rule=rule; r.status="not_applicable"; return;
elseif n=="electrical.current.profile", r.rule="current_A_increases"; m="stack_current_A";
elseif n=="electrical.power.profile", r.rule="power_kW_increases"; m="stack_power_kW";
elseif n=="electrical.voltage.profile", r.rule="voltage_V_increases"; m="stack_voltage_V";
elseif n=="cegr.targetRatio", r.rule="cegr_ratio_increases"; m="cegr_actual_ratio";
else, return; end
r.status="direction_check"; if ~b.executed || ~q.executed || ~isfield(b.metrics,m) || ~isfield(q.metrics,m), r.passed=false; r.reason="Direction signal unavailable."; return; end
d=scalarMetric(q.metrics.(m))-scalarMetric(b.metrics.(m)); inputDelta=scalarInput(item.perturbValue)-scalarInput(item.baseValue);
if ~isfinite(inputDelta) || abs(inputDelta)<=eps
    r.passed=false; r.reason="Input perturbation has no scalar direction."; return
end
r.passed=isfinite(d) && abs(d)>1e-9 && sign(d)==sign(inputDelta);
r.reason=ternary(r.passed,"Direction rule passed.","Direction rule failed relative to the applied perturbation sign.");
end

function value=scalarInput(value)
if isnumeric(value) || islogical(value)
    if isscalar(value), value=double(value); else, value=NaN; end
else
    value=NaN;
end
end

function r=units(b,linked)
r=struct('passed',false,'status',"not_observable",'signals',strings(0,1),'reason',""); if ~b.executed || isempty(linked), r.reason="No linked observable."; return; end
for k=1:numel(linked), i=find(strcmp(string({b.signalManifest.canonicalName}),string(linked(k))),1); if ~isempty(i) && strlength(string(b.signalManifest(i).unit))>0, r.signals(end+1,1)=string(linked(k)); end, end
r.passed=~isempty(r.signals); r.status=ternary(r.passed,"unit_declared","unit_missing"); r.reason=ternary(r.passed,"Manifest unit available.","No linked unit available.");
end

function value=scalarMetric(value)
% Extract the tail mean from the statistics structs returned by the panel
% result extractor. This keeps comparisons on model-derived values rather
% than comparing a struct or a command/profile value.
if isstruct(value) && isfield(value,'mean')
    value=value.mean;
end
if isnumeric(value) && ~isscalar(value)
    value=mean(value(:),'omitnan');
end
end

function m=metrics(z)
m=struct('stack_current_A',z.current_A,'stack_voltage_V',z.voltage_V,'stack_power_kW',z.power_kW,'cathode_compressor_mdot_kg_s',z.domains.cathode.compressorInletMassFlow_kg_s,'cathode_inlet_oer',z.domains.cathode.inletOxygenStoich,'cathode_outlet_pressure_MPa',z.domains.cathode.cathodeOutletPressure_MPa,'cathode_outlet_temperature_K',z.domains.cathode.cathodeOutletTemperature_K,'cathode_rh_in',z.domains.cathode.inletRelativeHumidity,'cathode_rh_out',z.domains.cathode.outletRelativeHumidity,'cegr_actual_ratio',z.actual_cegr_ratio,'cegr_mdot_kg_s',z.domains.cegr.massFlow_kg_s,'stack_temperature_C',z.domains.stack.temperature_C,'water_sep_kg_s',z.domains.cathode.waterSeparationRate_kg_s,'anode_source_pressure_MPa',z.domains.anode.sourcePressure_MPa,'anode_source_temperature_C',z.domains.anode.sourceTemperature_C,'anode_inlet_pressure_MPa',z.domains.anode.inletPressure_MPa,'anode_inlet_temperature_C',z.domains.anode.inletTemperature_C,'anode_inlet_hydrogen_mole_fraction',z.domains.anode.inletComposition.H2,'anode_inlet_rh',z.domains.anode.inletRelativeHumidity,'anode_outlet_hydrogen_mole_fraction',z.domains.anode.outletComposition.H2,'anode_purge_state',z.domains.anode.purgeState);
end

function k=metricKey(n)
switch string(n), case "stack.current",k="stack_current_A"; case "stack.voltage",k="stack_voltage_V"; case "stack.power",k="stack_power_kW"; case "cathode.compressorInletMassFlow",k="cathode_compressor_mdot_kg_s"; case {"cathode.inletOxygenStoich","cathode.inletOER"},k="cathode_inlet_oer"; case "cathode.outletPressure",k="cathode_outlet_pressure_MPa"; case "cathode.outletTemperature",k="cathode_outlet_temperature_K"; case "cathode.inletRelativeHumidity",k="cathode_rh_in"; case "cathode.outletRelativeHumidity",k="cathode_rh_out"; case "cegr.actualRatio",k="cegr_actual_ratio"; case "cegr.massFlow",k="cegr_mdot_kg_s"; case "anode.sourcePressure",k="anode_source_pressure_MPa"; case "anode.sourceTemperature",k="anode_source_temperature_C"; case "anode.inletPressure",k="anode_inlet_pressure_MPa"; case "anode.inletTemperature",k="anode_inlet_temperature_C"; case "anode.inletComposition",k="anode_inlet_hydrogen_mole_fraction"; case "anode.inletRelativeHumidity",k="anode_inlet_rh"; case "anode.outletComposition",k="anode_outlet_hydrogen_mole_fraction"; case "anode.purgeState",k="anode_purge_state"; otherwise,k=char(n); end
end

function s=safeText(v)
if ischar(v) || isstring(v), s=string(v); elseif isnumeric(v) && isscalar(v), s=string(v); else, s=""; end
end

function c=makeCase(item,v,options,isPerturb)
c=routeA_simCase_template(); c.caseId="trust_"+regexprep(item.canonicalName,'[^A-Za-z0-9_]','_')+ternary(isPerturb,"_perturb","_base"); c.solver.stopTime_s=options.stopTimeShort_s; c.controls.electrical.mode='Current'; c.controls.electrical.profile=28; n=item.canonicalName;
if startsWith(n,"electrical.")
    if n=="electrical.mode", c.controls.electrical.mode=char(v); c.controls.electrical.profile=defaultCommand(v); elseif contains(n,"voltageController"), c.controls.electrical.mode='Voltage'; c.controls.electrical.profile=.65; c.controls.electrical.voltageController=setNested(c.controls.electrical.voltageController,erase(n,"electrical.voltageController."),v); elseif contains(n,"power.profile"), c.controls.electrical.mode='Power'; c.controls.electrical.profile=v; elseif contains(n,"voltage.profile"), c.controls.electrical.mode='Voltage'; c.controls.electrical.profile=v; else, c.controls.electrical.profile=v; end
elseif startsWith(n,"solver."), c.solver.(char(erase(n,"solver.")))=v; elseif startsWith(n,"device."), c.controls.devices=setNested(c.controls.devices,erase(n,"device."),v); elseif startsWith(n,"stack."), c.controls.stack=setNested(c.controls.stack,erase(n,"stack."),v); elseif startsWith(n,"environment."), c.controls.environment=setNested(c.controls.environment,erase(n,"environment."),v); elseif startsWith(n,"thermal."), c.controls.thermal=setNested(c.controls.thermal,erase(n,"thermal."),v); elseif startsWith(n,"cathode.airController."), c.controls.cathode.airController=setNested(c.controls.cathode.airController,erase(n,"cathode.airController."),v); elseif startsWith(n,"cathode."), c.controls.cathode=setNested(c.controls.cathode,erase(n,"cathode."),v); elseif startsWith(n,"cegr.controller."), c.controls.cegr.controller=setNested(c.controls.cegr.controller,erase(n,"cegr.controller."),v); elseif startsWith(n,"cegr."), c.controls.cegr=setNested(c.controls.cegr,erase(n,"cegr."),v); elseif startsWith(n,"anode."), c.controls.anode=setNested(c.controls.anode,erase(n,"anode."),v); end
if n=="cathode.airControlMode", c.controls.cathode.airControlMode=v; end
if n=="cathode.targetOer", c.controls.cathode.airControlMode=2; end
if n=="cathode.targetMdot_kg_s", c.controls.cathode.airControlMode=1; end
if n=="cathode.directCommand", c.controls.cathode.airControlMode=3; end
if startsWith(n,"cegr.") && n~="cegr.enabled", c.controls.cegr.enabled=true; end
if contains(n,"humidifierRH") || contains(n,"humidifierEnabled"), c.controls.cathode.humidifierEnabled=true; end
if contains(n,"purge"), c.controls.anode.purgeEnabled=true; end
end

function v=defaultCommand(t)
switch string(t), case "Power",v=10; case "Voltage",v=.65; otherwise,v=28; end
end

function s=setNested(s,p,v)
x=split(string(p),'.'); if numel(x)==1, s.(char(x(1)))=v; else, s.(char(x(1)))=setNested(s.(char(x(1))),strjoin(x(2:end),'.'),v); end
end

function [v,status,rule]=makePerturbation(e)
v=e.defaultValue; status="ready"; rule=""; lo=e.minimum; hi=e.maximum;
if e.canonicalName=="electrical.mode"
    v="Power"; rule="registry_mode_alternate"; return
end
if e.canonicalName=="solver.solver"
    v="ode23t"; rule="registry_solver_alternate"; return
end
if e.canonicalName=="cathode.airControlMode"
    v=3; rule="registry_air_mode_alternate"; return
end
if ischar(v) || isstring(v) || iscategorical(v), status="blocked_perturbation_definition"; rule="categorical_requires_alternate"; return; end
if islogical(v), v=~v; rule="boolean_toggle"; return; end
if isempty(v) || ~isnumeric(v) || ~all(isfinite(v(:))), status="blocked_perturbation_definition"; rule="non_numeric"; return; end
if ~isempty(lo) && ~isempty(hi) && isequal(lo,hi), status="blocked_perturbation_definition"; rule="fixed_range"; return; end
if isscalar(v)
    if ~isempty(lo) && ~isempty(hi) && isfinite(lo) && isfinite(hi)
        if abs(hi-v)>=abs(v-lo), v=hi; else, v=lo; end
        rule="farthest_legal_bound";
    else
        step=max(abs(v)*.1,1e-12); if v==0 && ~isempty(hi) && hi>0, step=.1*hi; end; if ~isempty(hi) && v+step<=hi, v=v+step; elseif ~isempty(lo) && v-step>=lo, v=v-step; else, v=v+step; end; rule="bounds_then_10_percent";
    end
else
    base=v; if ~isempty(hi) && isequal(size(hi),size(base)), mask=base<hi; v(mask)=min(base(mask)+max(abs(base(mask))*.1,1e-12),hi(mask)); else, v=base*1.1; if all(v(:)==0), v(1)=1e-12; end, end; rule="shape_preserving_element_perturbation";
end
end

function e=consumerEvidence(inv,name,entry)
e=struct('passed',false,'referenceState',"",'resolvedWriteVariable',"",'blockUsers',"",'profileField',string(entry.profileField),'reason',"");
if startsWith(name,"solver.")
    e.passed=true; e.referenceState="SimulationInput_model_parameter";
    e.reason="SimulationInput model parameter is the numerical consumer.";
    return
end
if name=="electrical.mode"
    e.passed=true; e.referenceState="SimulationInput_block_parameter";
    e.reason="Electrical boundary block parameter is the model consumer.";
    return
end
if ~isfield(inv,'inputContract') || isempty(inv.inputContract), e.reason="Inventory unavailable."; return; end
r=inv.inputContract(strcmp(string(inv.inputContract.canonicalName),name),:); if isempty(r), e.reason="No inventory row."; return; end
e.referenceState=string(r.referenceState(1)); e.resolvedWriteVariable=string(r.resolvedWriteVariable(1)); e.blockUsers=string(r.blockUsers(1)); e.passed=any(e.referenceState==["model_referenced","library_boundary_verified","write_target_referenced","write_target_library_boundary_verified"]) || strlength(string(entry.blockParameter))>0;
if ~e.passed && strlength(e.profileField)>0, e.passed=true; e.reason="Formal profile consumer; behavior remains gated."; elseif ~e.passed, e.reason="No referenced model consumer."; end
end

function e=readback(in)
e=struct('passed',false,'variables',strings(0,1),'blockParameters',strings(0,1),'modelParameters',strings(0,1),'reason',"");
try,e.variables=arrayfun(@(x)string(x.Name),in.Variables);catch,end; try,e.blockParameters=arrayfun(@(x)string(x.BlockPath),in.BlockParameters);catch,end; try,e.modelParameters=arrayfun(@(x)string(x.Name),in.ModelParameters);catch,end
e.passed=~isempty(e.variables)||~isempty(e.blockParameters)||~isempty(e.modelParameters); e.reason=ternary(e.passed,"SimulationInput entries read back.","No SimulationInput write entries.");
end

function s=loadState(root,resume,checksum,version)
s=struct('items',repmat(itemTemplate(),0,1)); f=fullfile(root,'trust_audit_state.mat'); if ~resume || ~isfile(f), return; end
try, x=load(f,'state'); if string(x.state.modelChecksum)==checksum && string(x.state.version)==version, s=x.state; end, catch, end
end

function a=reuse(a,old)
for k=1:numel(a)
    i=find(strcmp(string({old.fingerprint}),a(k).fingerprint) & string({old.status})~="running",1);
    if ~isempty(i), a(k)=old(i); end
end
end

function r=package(items,options,checksum,version,status)
r=struct('schemaVersion',version,'auditStatus',status,'status',status,'modelChecksum',checksum,'runnerVersion',version,'options',options,'items',items,'summary',summary(items),'generatedAt',string(datetime('now')));
end

function s=auditState(items,checksum,version)
s=struct('version',version,'modelChecksum',checksum,'items',items,'updatedAt',string(datetime('now')));
end

function s=summary(a)
s=struct('planned',numel(a),'completed',0,'shortGatePassed',0,'longGatePassed',0,'blocked',0,'failed',0);
for k=1:numel(a), s.completed=s.completed+double(a(k).status=="completed"); s.shortGatePassed=s.shortGatePassed+double(isfield(a(k).short,'gatePassed')&&a(k).short.gatePassed); s.longGatePassed=s.longGatePassed+double(isfield(a(k).long,'gatePassed')&&a(k).long.gatePassed); s.blocked=s.blocked+double(startsWith(a(k).status,"blocked")); s.failed=s.failed+double(contains(a(k).status,"failed")||contains(a(k).status,"no_observable")); end
end

function saveEvidence(r,root)
if ~isfolder(root), mkdir(root); end
state=r.state; save(fullfile(root,'trust_audit_state.mat'),'state','-v7.3'); a=r.items; n=numel(a); names=strings(n,1); domains=strings(n,1); statuses=strings(n,1); short=strings(n,1); direction=strings(n,1); unit=strings(n,1); consumer=strings(n,1); reason=strings(n,1); fp=strings(n,1);
for k=1:n, names(k)=a(k).canonicalName; domains(k)=a(k).domain; statuses(k)=a(k).status; short(k)=getStatus(a(k),'short'); direction(k)=getStatus(a(k),'direction'); unit(k)=getStatus(a(k),'unit'); consumer(k)=string(a(k).consumer.referenceState); reason(k)=a(k).failureReason; fp(k)=a(k).fingerprint; end
T=table(names,domains,statuses,short,direction,unit,consumer,reason,fp,'VariableNames',{'canonicalName','domain','status','shortStatus','directionStatus','unitStatus','consumerState','failureReason','fingerprint'}); writetable(T,fullfile(root,'trust_audit_cases.csv'));
writeContractEvidence(a,root);
fid=fopen(fullfile(root,'trust_audit_summary.md'),'w'); c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# Route A Panel Trust Audit\n\n- status: `%s`\n- planned: %d\n- completed: %d\n- short gate passed: %d\n- long gate passed: %d\n- blocked: %d\n- failed: %d\n\nWater separation remains `not_validated` L2 diagnostic only.\n',r.auditStatus,r.summary.planned,r.summary.completed,r.summary.shortGatePassed,r.summary.longGatePassed,r.summary.blocked,r.summary.failed);
end

function writeContractEvidence(items,root)
% This is the reviewable pre-run contract, distinct from runtime outcomes.
n=numel(items); ui=strings(n,1); simCase=strings(n,1); writePath=strings(n,1); consumer=strings(n,1); consumerState=strings(n,1); kind=strings(n,1); activation=strings(n,1); observations=strings(n,1); units=strings(n,1); sampling=strings(n,1); perturb=strings(n,1); criterion=strings(n,1); runnable=false(n,1); reason=strings(n,1);
for k=1:n
    x=items(k); c=x.validationContract; ui(k)=x.uiControl; simCase(k)=x.simCasePath; writePath(k)=x.writePath;
    consumer(k)=c.actualConsumer; consumerState(k)=string(x.consumer.referenceState); kind(k)=c.evaluationKind; activation(k)=c.activation;
    observations(k)=strjoin(c.observations,'; '); units(k)=c.unitContract; sampling(k)=c.samplingLocation;
    perturb(k)=c.perturbationRule; criterion(k)=c.passCriterion; runnable(k)=c.runnable; reason(k)=c.reason;
end
T=table(string({items.canonicalName})',string({items.domain})',ui,simCase,writePath,consumer,consumerState,kind,activation,observations,units,sampling,perturb,criterion,runnable,reason, ...
    'VariableNames',{'canonicalName','domain','uiControl','simCasePath','simulationInputWrite','actualConsumer','consumerEvidence','evaluationKind','activation','primaryObservations','unitRule','samplingLocation','perturbationRule','shortPassCriterion','runnable','blockReason'});
writetable(T,fullfile(root,'trust_audit_contract_v10.csv'));
fid=fopen(fullfile(root,'trust_audit_contract_v10.md'),'w'); assert(fid>=0,'RouteA:TrustAuditContractWrite','Cannot write contract evidence.'); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# Route A Panel Input Verification Contract v10\n\n');
fprintf(fid,'- inputs: `%d`\n- runnable short-run candidates: `%d`\n- blocked before simulation: `%d`\n- evidence semantics: consumer evidence is model-reference read-back; only a later baseline/perturbation can establish behavior.\n\n',n,sum(runnable),sum(~runnable));
fprintf(fid,'| Input | UI | simCase | SimulationInput write | Consumer evidence | Contract kind / activation | Primary physical observation | Unit / sampling / perturbation / short-pass rule | Runnable |\n|---|---|---|---|---|---|---|---|---|\n');
for k=1:n
    row=T(k,:); detail=escapeCell(row.unitRule)+"; "+escapeCell(row.samplingLocation)+"; "+escapeCell(row.perturbationRule)+"; "+escapeCell(row.shortPassCriterion);
    activationDetail=escapeCell(row.evaluationKind)+"; "+escapeCell(row.activation);
    fprintf(fid,'| %s | %s | %s | %s | %s (%s) | %s | %s | %s | %s |\n',escapeCell(row.canonicalName),escapeCell(row.uiControl),escapeCell(row.simCasePath),escapeCell(row.simulationInputWrite),escapeCell(row.actualConsumer),escapeCell(row.consumerEvidence),activationDetail,escapeCell(row.primaryObservations),detail,string(row.runnable));
end
end

function value=escapeCell(value)
value=replace(string(value),"|","/");
value=replace(value,newline," ");
end

function s=getStatus(a,field)
s="not_run";
if isfield(a,field)&&isstruct(a.(field))&&isfield(a.(field),'status')
    s=string(a.(field).status); return
end
% Direction and unit are stored under the short/long run gates. Export the
% short-run evidence rather than presenting a completed nested gate as not run.
if isfield(a,'short')&&isstruct(a.short)&&isfield(a.short,field)&& ...
        isstruct(a.short.(field))&&isfield(a.short.(field),'status')
    s=string(a.short.(field).status);
end
end

function ok=filterEntry(e,o)
ok=isempty(o.caseFilter)||any(string(e.canonicalName)==string(o.caseFilter)); if ok&&~isempty(o.domainFilter), ok=any(string(e.domain)==string(o.domainFilter)); end
end

function f=fingerprint(checksum,version,x,o)
f=checksum+"|"+version+"|"+x.canonicalName+"|"+valueKey(x.baseValue)+"|"+valueKey(x.perturbValue)+"|"+x.unit+"|"+string(o.stopTimeShort_s)+"|"+string(o.stopTimeLong_s);
end

function k=valueKey(v)
if isnumeric(v)||islogical(v), k=string(mat2str(v,16)); else, k=string(v); end
end

function t=itemTemplate()
t=struct('canonicalName',"",'domain',"",'uiControl',"",'simCasePath',"",'writePath',"",'unit',"",'baseValue',[],'perturbValue',[],'perturbationStatus',"",'perturbationRule',"",'linkedObservations',strings(0,1),'validationContract',validationContractTemplate(),'consumer',struct(),'fingerprint',"",'status',"",'failureReason',"",'short',struct(),'long',struct());
end

function c=validationContractTemplate()
c=struct('defined',false,'runnable',false,'evaluationKind',"physical_response",'activation',"",'actualConsumer',"", ...
    'observations',strings(0,1),'samplingLocation',"",'directionRule',"response_only", ...
    'unitContract',"",'perturbationRule',"",'passCriterion',"",'reason',"");
end

function c=validationContract(name,links,entry,parameter,consumer)
% Complete input-specific contract. The matrix owns UI/simCase/write paths;
% this function owns activation, consumer semantics, physical observation,
% unit/location, perturbation, and the short-run acceptance rule.
c=validationContractTemplate(); c.defined=true; c.observations=string(links(:));
if isempty(c.observations)
    % A missing registered output is recorded as an explicit capability
    % boundary. It must not silently become an empty observation contract.
    c.observations="not_observable."+replace(string(name),".","_");
end
c.actualConsumer=consumerText(entry,parameter,consumer);
c.activation=activationRule(name);
c.samplingLocation=samplingRule(c.observations);
c.unitContract=unitRule(entry.unit,c.observations);
c.perturbationRule=perturbationRule(name,entry);
c.passCriterion="SimulationInput read-back; referenced consumer; primary model observable changes; declared direction holds when applicable.";
c.runnable=~isempty(c.observations) && ~startsWith(c.activation,"not_runnable") && ...
    ~startsWith(c.samplingLocation,"unregistered") && strlength(c.actualConsumer)>0;
switch string(name)
    case "cathode.targetOer"
        c.activation="cathode.airControlMode=2 (OER controller)"; c.observations=["cathode.inletOxygenStoich";"cathode.compressorInletMassFlow"]; c.directionRule="inlet_OER_and_air_flow_increase"; c.unitContract="OER dimensionless; inlet mdot kg/s";
    case "cathode.targetMdot_kg_s"
        c.activation="cathode.airControlMode=1 (mass-flow controller)"; c.observations="cathode.compressorInletMassFlow"; c.directionRule="inlet_mass_flow_increase"; c.unitContract="kg/s";
    case "cathode.directCommand"
        c.activation="cathode.airControlMode=3 (direct compressor command)"; c.observations="cathode.compressorInletMassFlow"; c.directionRule="inlet_mass_flow_increase"; c.unitContract="normalized command; observed mdot kg/s";
    case "cathode.outletPressure_MPa_abs"
        c.activation="cathode exhaust backpressure profile"; c.observations="cathode.outletPressure"; c.directionRule="cathode_outlet_pressure_increase"; c.unitContract="command MPa(abs); signal Pa, display MPa";
    case "cathode.humidifierRH"
        c.activation="cathode.humidifierEnabled=true"; c.observations=["cathode.inletRelativeHumidity";"cathode.outletRelativeHumidity"]; c.directionRule="RH_increase"; c.unitContract="RH fraction 0..1";
    case "anode.sourcePressure_MPa_abs"
        c.observations="anode.sourcePressure"; c.directionRule="anode_source_pressure_increase"; c.unitContract="MPa(abs) at Fuel Tank outlet, upstream of pressure reducer";
    case "anode.inletPressure_MPa_abs"
        c.observations="anode.inletPressure"; c.directionRule="anode_inlet_pressure_increase"; c.unitContract="MPa(abs) at pressure-reducer outlet";
    case "anode.sourceTemperature_C"
        c.observations="anode.sourceTemperature"; c.directionRule="anode_source_temperature_increase"; c.unitContract="degC at Fuel Tank outlet, upstream of pressure reducer";
    case "anode.h2MoleFraction"
        c.observations="anode.inletComposition"; c.directionRule="anode_inlet_hydrogen_increase"; c.unitContract="mole fraction, channel H2 in [N2 O2 H2 H2O]";
    case "anode.humidifierRH"
        c.activation="anode humidifier command active"; c.observations="anode.inletRelativeHumidity"; c.directionRule="anode_inlet_RH_increase"; c.unitContract="RH fraction 0..1";
    case {"anode.recirculationBaseCommand", "anode.recirculationCurrentGain_A_inv"}
        c.observations="anode.inletPressure"; c.unitContract="input command; physical response MPa(abs) at pressure-reducer outlet";
    case {"anode.purgeEnabled", "anode.purgeOnN2MoleFraction", "anode.purgeOffN2MoleFraction"}
        c.activation="anode purge enabled with the N2 threshold crossed"; c.observations=["anode.purgeState";"anode.outletComposition"]; c.unitContract="purge state 0/1; outlet mole fractions [N2 O2 H2 H2O]";
    case {"solver.stopTime_s", "solver.solver", "solver.relTol", "solver.absTol", "solver.maxStep_s"}
        c.evaluationKind="numerical_integrity"; c.activation="numerical configuration applied before sim()"; c.observations=["stack.current";"stack.voltage";"cathode.outletPressure"]; c.directionRule="not_applicable"; c.unitContract="model parameter; physical checks A, V, and MPa"; c.passCriterion="SimulationInput model-parameter read-back; both simulations execute; declared physical checks remain within 5 percent.";
end
% Refresh derived fields after input-specific overrides.
c.samplingLocation=samplingRule(c.observations); c.runnable=~isempty(c.observations) && ...
    ~startsWith(c.activation,"not_runnable") && ~startsWith(c.samplingLocation,"unregistered");
if ~c.runnable
    c.reason="Contract has no valid registered observation or activation path.";
end
end

function text=consumerText(entry,parameter,consumer)
text=string(parameter.writePath);
if strlength(string(entry.modelWorkspaceVariable))>0
    text=text+"; model variable "+string(entry.modelWorkspaceVariable);
elseif strlength(string(entry.profileField))>0
    text=text+"; command-profile field "+string(entry.profileField);
elseif strlength(string(entry.blockParameter))>0
    text=text+"; block parameter "+string(entry.blockParameter);
end
if strlength(string(consumer.blockUsers))>0 && string(consumer.blockUsers)~="-"
    text=text+"; model users "+string(consumer.blockUsers);
elseif strlength(string(consumer.referenceState))>0
    text=text+"; reference state "+string(consumer.referenceState);
end
end

function text=activationRule(name)
n=string(name); text="always active for this case";
if n=="electrical.current.profile", text="electrical.mode=Current";
elseif n=="electrical.power.profile", text="electrical.mode=Power";
elseif n=="electrical.voltage.profile" || startsWith(n,"electrical.voltageController."), text="electrical.mode=Voltage";
elseif n=="cathode.targetOer", text="cathode.airControlMode=2";
elseif n=="cathode.targetMdot_kg_s", text="cathode.airControlMode=1";
elseif n=="cathode.directCommand", text="cathode.airControlMode=3";
elseif contains(n,"humidifierRH"), text="corresponding humidifierEnabled=true";
elseif n=="anode.sourcePressure_MPa_abs", text="source value differs from platform default and overrides tank_p";
elseif n=="anode.sourceTemperature_C", text="source value differs from platform default and overrides tank_T";
elseif n=="anode.inletPressure_MPa_abs", text="anode pressure-reducing valve setpoint profile";
elseif startsWith(n,"anode.recirculation"), text="anode recirculation command with nonzero stack current";
elseif n=="cegr.targetRatio" || startsWith(n,"cegr.controller."), text="cegr.enabled=true and cegr.controlMode=1";
elseif startsWith(n,"cegr.direct"), text="cegr.enabled=true and cegr.controlMode=2";
elseif contains(n,"purge"), text="anode.purgeEnabled=true and N2 threshold crossing";
elseif startsWith(n,"solver."), text="numerical setting applied before sim()";
end
end

function text=samplingRule(observations)
o=string(observations(:));
if isempty(o), text="unregistered: no observation"; return; end
if any(startsWith(o,"not_observable.")), text="unregistered: no active-model physical observation"; return; end
if any(o=="anode.sourcePressure" | o=="anode.sourceTemperature"), text="Fuel Tank gas outlet upstream of the pressure reducer"; return; end
if any(startsWith(o,"anode.")), text="anode pressure-reducer outlet, humidifier outlet, or purge-valve inlet; species order [N2 O2 H2 H2O]"; return; end
if any(startsWith(o,"thermal.coolant")), text="unregistered: status-only observation"; return; end
if any(o=="cathode.outletPressure"), text="cathode exhaust outlet pressure observer (Pa; displayed MPa)";
elseif any(contains(o,"RelativeHumidity")), text="humidifier outlet/cathode inlet and cathode exhaust RH observers";
elseif any(contains(o,"Composition")) || any(contains(o,"Species")), text="cathode inlet/exhaust gas-mixture observers; channel order [N2 O2 H2 H2O]";
elseif any(contains(o,"Temperature")), text="stack thermal sensor or cathode exhaust temperature observer";
elseif any(startsWith(o,"cegr.")), text="cEGR branch flow/valve observers between cathode exhaust split and compressor-inlet mixer";
elseif any(startsWith(o,"stack.")), text="stack electrical/thermal observer";
else, text="registered model observer"; end
end

function text=unitRule(inputUnit,observations)
text="input "+string(inputUnit)+"; primary observation units declared in observation registry: "+strjoin(string(observations(:)),", ");
end

function text=perturbationRule(name,entry)
if string(name)=="electrical.mode", text="switch to an alternate legal boundary mode with its matching command";
elseif islogical(entry.defaultValue), text="toggle the boolean under its activation mode";
elseif isnumeric(entry.defaultValue), text="farthest legal scalar bound; arrays use shape-preserving in-range perturbation";
else, text="explicit alternate legal categorical value"; end
end

function assertContractsComplete(items)
for k=1:numel(items)
    c=items(k).validationContract;
    assert(c.defined && strlength(c.evaluationKind)>0 && strlength(c.activation)>0 && strlength(c.actualConsumer)>0 && ...
        strlength(c.unitContract)>0 && strlength(c.samplingLocation)>0 && ...
        strlength(c.perturbationRule)>0 && strlength(c.passCriterion)>0, ...
        'RouteA:TrustAuditIncompleteContract','Incomplete contract for %s.',items(k).canonicalName);
end
end

function t=outcome()
t=struct('caseId',"",'executed',false,'status',"planned",'reason',"",'resultStatus',"",'writeReadback',struct('passed',false,'variables',strings(0,1),'blockParameters',strings(0,1),'modelParameters',strings(0,1),'reason',""),'metrics',struct(),'signalManifest',struct(),'modelVersion',"",'topologyHash',"");
end

function v=ternary(c,a,b)
if c,v=a;else,v=b;end
end
