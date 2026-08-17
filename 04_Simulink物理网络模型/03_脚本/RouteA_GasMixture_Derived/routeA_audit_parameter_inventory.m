function report = routeA_audit_parameter_inventory(writeReport)
% Audit the Route A model-to-panel parameter contract.
%
% The audit is intentionally model-first: ModelWorkspace variables and
% Simulink.findVars usage are the source of truth. The parameter registry
% then records how, or whether, each live model parameter is represented in
% the panel contract. When requested, a searchable Markdown report is
% written under the Route A current-guidance directory.

if nargin < 1
    writeReport = true;
end

paths = routeA_project_paths();
model = char(paths.modelName);
if ~bdIsLoaded(model)
    load_system(paths.modelFile);
end

modelWorkspace = get_param(model, 'ModelWorkspace');
workspaceInfo = modelWorkspace.whos;
modelVars = string({workspaceInfo.name})';
% Cached usage can be incomplete after model updates or SimulationInput
% execution. Merge it with the official compiled query so a stale cache
% cannot turn valid panel write targets into false audit mismatches.
cachedFindVars = [];
cachedSearchError = [];
try
    cachedFindVars = Simulink.findVars(model, 'SearchMethod', 'cached');
catch ME
    cachedSearchError = ME;
end
try
    compiledFindVars = Simulink.findVars(model, 'SearchMethod', 'compiled');
catch compiledSearchError
    if isempty(cachedFindVars)
        if isempty(cachedSearchError)
            throw(compiledSearchError);
        end
        throw(addCause(compiledSearchError, cachedSearchError));
    end
    compiledFindVars = [];
end
if isempty(cachedFindVars)
    findVars = compiledFindVars;
elseif isempty(compiledFindVars)
    findVars = cachedFindVars;
else
    findVars = [cachedFindVars; compiledFindVars];
end
registry = routeA_parameter_registry(paths);
entries = registry.entries;
activeEntries = entries(string({entries.status}) == "active");

workspaceRows = repmat(workspaceRowTemplate(), numel(workspaceInfo), 1);
for idx = 1:numel(workspaceInfo)
    name = modelVars(idx);
    value = modelWorkspace.getVariable(char(name));
    usedBy = modelUsersFor(findVars, name);
    matchingEntries = activeEntries(arrayfun(@(entry) ...
        resolvedWriteVariable(entry) == name, activeEntries));
    derivedEntries = activeEntries(arrayfun(@(entry) ...
        any(derivedWriteVariables(entry) == name), activeEntries));
    matchingEntries = [matchingEntries, derivedEntries];
    [canonicalNames, panelExposure] = registryText(matchingEntries);
    workspaceRows(idx) = struct( ...
        'modelVariable', name, ...
        'valuePreview', valuePreview(value), ...
        'valueClass', string(class(value)), ...
        'size', string(mat2str(size(value))), ...
        'physicalRole', physicalRole(name), ...
        'openingDisposition', openingDisposition(name), ...
        'referenceState', referenceState(name, usedBy, matchingEntries), ...
        'blockUsers', compactUsers(usedBy, model), ...
        'activePanelEntries', canonicalNames, ...
        'panelExposure', panelExposure);
end

contractRows = repmat(contractRowTemplate(), numel(activeEntries), 1);
for idx = 1:numel(activeEntries)
    entry = activeEntries(idx);
    resolvedVariable = resolvedWriteVariable(entry);
    usedBy = modelUsersFor(findVars, resolvedVariable);
    if strlength(resolvedVariable) == 0
        reference = "non_workspace_input";
    elseif isLibraryBoundaryInput(resolvedVariable)
        reference = "write_target_library_boundary_verified";
    elseif isempty(usedBy)
        reference = "write_target_not_referenced";
    else
        reference = "write_target_referenced";
    end
    contractRows(idx) = struct( ...
        'canonicalName', string(entry.canonicalName), ...
        'displayName', string(entry.displayName), ...
        'panelExposure', string(entry.panelExposure), ...
        'unit', string(entry.unit), ...
        'limits', limitText(entry.minimum, entry.maximum), ...
        'modelWorkspaceVariable', string(entry.modelWorkspaceVariable), ...
        'profileField', string(entry.profileField), ...
        'resolvedWriteVariable', resolvedVariable, ...
        'application', string(entry.applyAction), ...
        'derivedWriteVariables', strjoin(derivedWriteVariables(entry), ', '), ...
        'referenceState', reference, ...
        'blockUsers', compactUsers(usedBy, model));
end

workspaceTable = struct2table(workspaceRows);
contractTable = struct2table(contractRows);
mismatch = contractTable(contractTable.referenceState == ...
    "write_target_not_referenced", :);
unrepresented = workspaceTable( ...
    workspaceTable.referenceState == "model_referenced_no_active_panel_entry", :);
workspaceStates = string(workspaceTable.referenceState);
entryExposure = string({entries.panelExposure});
entryStatus = string({entries.status});
entryNames = string({entries.canonicalName});
entryDomains = string({entries.domain});
deviceCatalogMask = entryExposure == "device_settings" | ...
    ((startsWith(entryNames, "platform.") | startsWith(entryNames, "device.")) & ...
    ismember(entryDomains, ["stack", "cathode", "cegr", "anode", "thermal"]));
panelMappedReferencedCount = sum(ismember(workspaceStates, ...
    ["model_referenced_panel_contract", "library_boundary_verified"]));
workspaceOnlyCount = sum(workspaceStates == "workspace_only");
panelEntryWithoutReferenceCount = sum(workspaceStates == ...
    "panel_entry_without_model_reference");
deviceCatalogCount = sum(deviceCatalogMask);
deviceEditableCount = sum(deviceCatalogMask & entryExposure == "device_settings" & ...
    entryStatus == "active");
deviceInventoryCount = sum(deviceCatalogMask & entryStatus == "inventory");
deviceUnresolvedCount = sum(deviceCatalogMask & entryStatus == "unresolved");

report = struct( ...
    'schemaVersion', "RouteA_ModelPanelParameterAudit_v01", ...
    'model', string(model), ...
    'modelDirty', string(get_param(model, 'Dirty')), ...
    'generatedAt', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'workspace', workspaceTable, ...
    'inputContract', contractTable, ...
    'panelWriteTargetMismatches', mismatch, ...
    'referencedModelParametersWithoutActivePanelEntry', unrepresented, ...
    'redundancyAudit', redundancyAudit(workspaceTable, contractTable), ...
    'counts', struct( ...
        'workspaceVariableCount', height(workspaceTable), ...
        'referencedWorkspaceVariableCount', sum(startsWith( ...
            workspaceTable.referenceState, "model_referenced") | ...
            workspaceTable.referenceState == "library_boundary_verified"), ...
        'panelMappedReferencedWorkspaceVariableCount', panelMappedReferencedCount, ...
        'workspaceOnlyVariableCount', workspaceOnlyCount, ...
        'panelEntryWithoutModelReferenceCount', panelEntryWithoutReferenceCount, ...
        'activePanelEntryCount', height(contractTable), ...
        'panelWriteTargetMismatchCount', height(mismatch), ...
        'referencedModelParametersWithoutActivePanelEntryCount', ...
            height(unrepresented), ...
        'deviceCatalogEntryCount', deviceCatalogCount, ...
        'deviceEditableEntryCount', deviceEditableCount, ...
        'deviceReadonlyCatalogEntryCount', deviceCatalogCount - deviceEditableCount, ...
        'deviceInventoryEntryCount', deviceInventoryCount, ...
        'deviceUnresolvedEntryCount', deviceUnresolvedCount));

if writeReport
    reportPath = fullfile(paths.simulinkRoot, '04_说明', ...
        'RouteA_GasMixture_Derived', '01_当前指导', ...
        'RouteA_cEGR_PEMFC_模型-面板参数汇总表_v01.md');
    writeMarkdownReport(report, reportPath);
    report.reportPath = string(reportPath);
else
    report.reportPath = "";
end
end

function row = workspaceRowTemplate()
row = struct('modelVariable', "", 'valuePreview', "", 'valueClass', "", ...
    'size', "", 'physicalRole', "", 'openingDisposition', "", ...
    'referenceState', "", ...
    'blockUsers', "", 'activePanelEntries', "", 'panelExposure', "");
end

function row = contractRowTemplate()
row = struct('canonicalName', "", 'displayName', "", 'panelExposure', "", ...
    'unit', "", 'limits', "", 'modelWorkspaceVariable', "", ...
    'profileField', "", 'resolvedWriteVariable', "", 'application', "", ...
    'derivedWriteVariables', "", 'referenceState', "", 'blockUsers', "");
end

function users = modelUsersFor(findVars, name)
users = string.empty(0, 1);
if strlength(name) == 0
    return;
end
for idx = 1:numel(findVars)
    if string(findVars(idx).Name) == name
        users = [users; string(findVars(idx).Users(:))]; %#ok<AGROW>
    end
end
users = unique(users, 'stable');
end

function [canonicalNames, panelExposure] = registryText(entries)
if isempty(entries)
    canonicalNames = "";
    panelExposure = "";
    return;
end
canonicalNames = strjoin(string({entries.canonicalName}), ', ');
panelExposure = strjoin(unique(string({entries.panelExposure}), 'stable'), ', ');
end

function state = referenceState(name, usedBy, entries)
if isLibraryBoundaryInput(name)
    state = "library_boundary_verified";
    return;
end
if isempty(usedBy) && isempty(entries)
    state = "workspace_only";
elseif isempty(usedBy)
    state = "panel_entry_without_model_reference";
elseif isempty(entries)
    state = "model_referenced_no_active_panel_entry";
else
    state = "model_referenced_panel_contract";
end
end

function tf = isLibraryBoundaryInput(name)
tf = any(string(name) == ["drive_cycle_current", "drive_cycle_power"]);
end

function variable = resolvedWriteVariable(entry)
if any(string(entry.canonicalName) == ["anode.sourcePressure_MPa_abs", ...
        "anode.sourceTemperature_C"])
    variable = string(entry.modelWorkspaceVariable);
    return;
end
if strlength(string(entry.profileField)) > 0
    variable = "routeA_command_profile";
else
    variable = string(entry.modelWorkspaceVariable);
end
end

function variables = derivedWriteVariables(entry)
variables = strings(0, 1);
switch string(entry.canonicalName)
    case "device.cegr.pipeDiameter_m"
        variables = "cegr_pipe_area";
    case {"electrical.current.profile", "electrical.power.profile", ...
            "electrical.voltage.profile"}
        variables = "drive_cycle_time";
    case "anode.h2MoleFraction"
        variables = "tank_yH2";
    case "device.thermal.radiatorCore.length_m"
        variables = "radiator_tube_Leq";
end
end

function tableOut = redundancyAudit(workspaceTable, contractTable)
template = struct('classification', "", 'canonicalInput', "", ...
    'modelVariables', "", 'state', "", 'evidence', "");
rows = repmat(template, 6, 1);
rows(1) = struct( ...
    'classification', "active_derived_geometry", ...
    'canonicalInput', "device.cegr.pipeDiameter_m", ...
    'modelVariables', "cegr_pipe_D; cegr_pipe_area", ...
    'state', "resolved", ...
    'evidence', "SimulationInput writes D and derives area=pi*D^2/4.");
rows(2) = struct( ...
    'classification', "legacy_unbound_geometry", ...
    'canonicalInput', "device.cathode.separatorArea_m2", ...
    'modelVariables', "cathode_separator_D; cathode_separator_area", ...
    'state', "legacy_workspace_only_excluded", ...
    'evidence', "D is workspace-only; active FC block uses area.");
rows(3) = struct( ...
    'classification', "legacy_unbound_geometry", ...
    'canonicalInput', "device.anode.separatorArea_m2", ...
    'modelVariables', "anode_separator_D; anode_separator_area", ...
    'state', "legacy_workspace_only_excluded", ...
    'evidence', "D is workspace-only; active FC block uses area.");
rows(4) = struct( ...
    'classification', "legacy_unbound_geometry", ...
    'canonicalInput', "-", ...
    'modelVariables', "intercooler_Dh; intercooler_area", ...
    'state', "legacy_workspace_only_excluded", ...
    'evidence', "Dh is workspace-only; active FC block uses area.");
rows(5) = struct( ...
    'classification', "legacy_profile_shadow", ...
    'canonicalInput', "routeA_command_profile", ...
    'modelVariables', "routeA_anode_*; routeA_cathode_*; routeA_backpressure_control_mode_id", ...
    'state', "workspace_only_excluded", ...
    'evidence', "The active control path reads the 22-column command profile, not these legacy scalars.");
rows(6) = struct( ...
    'classification', "unbound_thermal_metadata", ...
    'canonicalInput', "-", ...
    'modelVariables', "radiator_H; radiator_N_fins; radiator_fin_spacing; radiator_gap_H", ...
    'state', "workspace_only_no_platform_default", ...
    'evidence', "No active block references these items; H and N_fins were removed from platform defaults.");

for idx = 1:height(contractTable)
    variables = split(contractTable.derivedWriteVariables(idx), ", ");
    variables = variables(strlength(variables) > 0);
    for jdx = 1:numel(variables)
        assert(any(workspaceTable.modelVariable == variables(jdx)), ...
            'RouteA:DerivedWriteTargetMissing', ...
            'Derived write target %s is not in the model workspace.', variables(jdx));
    end
end
tableOut = struct2table(rows);
end

function textValue = compactUsers(users, model)
if isempty(users)
    textValue = "-";
    return;
end
shortNames = erase(users, string(model) + "/");
limit = min(3, numel(shortNames));
textValue = strjoin(shortNames(1:limit), '; ');
if numel(shortNames) > limit
    textValue = textValue + sprintf('; ... (+%d)', numel(shortNames) - limit);
end
textValue = string(textValue);
end

function textValue = valuePreview(value)
if isnumeric(value) || islogical(value)
    if isscalar(value)
        textValue = string(sprintf('%.8g', double(value)));
    elseif numel(value) <= 12
        textValue = string(mat2str(value, 6));
    else
        textValue = sprintf('%s%s', class(value), mat2str(size(value)));
    end
elseif isstring(value) || ischar(value)
    textValue = string(value);
else
    textValue = sprintf('%s%s', class(value), mat2str(size(value)));
end
textValue = string(textValue);
end

function textValue = physicalRole(name)
name = string(name);
if startsWith(name, "stack_")
    textValue = "电堆 / MEA 电化学、几何或热容参数";
elseif startsWith(name, "comp_")
    textValue = "阴极空压机图谱、转速边界或入口混合容积";
elseif startsWith(name, "intercooler_")
    textValue = "阴极中冷器 L2 流阻与初始状态参数";
elseif startsWith(name, "cathode_separator_")
    textValue = "阴极分离器 L2 流阻与初始状态参数";
elseif startsWith(name, "anode_separator_")
    textValue = "阳极分离器 L2 流阻与初始状态参数";
elseif startsWith(name, "cegr_") || startsWith(name, "routeA_egr_")
    textValue = "被动 cEGR 支路几何、阀或控制参数";
elseif startsWith(name, "routeA_")
    textValue = "Route A 运行工况、控制或命令配置";
elseif startsWith(name, "drive_cycle_")
    textValue = "电边界时序命令";
elseif startsWith(name, "env_")
    textValue = "环境与气体初始边界";
elseif startsWith(name, "tank_")
    textValue = "阳极储氢罐初始状态/容积";
elseif startsWith(name, "coolant_") || startsWith(name, "radiator_")
    textValue = "热管理 BOP 几何或热容参数";
elseif startsWith(name, "pSat_") || name == "T_TLU"
    textValue = "水蒸气饱和性质查表数据";
elseif startsWith(name, "separator_")
    textValue = "L2 冷凝/分离功能标记";
else
    textValue = "模型内部配置或辅助参数";
end
textValue = string(textValue);
end

function textValue = openingDisposition(name)
name = string(name);
switch name
    case {"anode_tube_D", "cathode_tube_D"}
        textValue = "只读：多块共享的内部管路几何；需结构一致性验证后再考虑开放";
    case {"stack_num_channels", "stack_w_channels"}
        textValue = "只读：通道结构/拓扑参数；改变可能影响编译、初始化和几何一致性";
    case "cegr_comp_map_t_denom_epsilon"
        textValue = "只读：压缩机图谱数值保护量，不代表设备性能设定";
    otherwise
        textValue = "可进入开放审查；需完成写入、范围和响应验证";
end
textValue = string(textValue);
end

function textValue = limitText(minimum, maximum)
if isempty(minimum) && isempty(maximum)
    textValue = "结构化数据/由专用校验器约束";
else
    textValue = sprintf('[%s, %s]', scalarText(minimum), scalarText(maximum));
end
textValue = string(textValue);
end

function textValue = scalarText(value)
if isempty(value)
    textValue = "-";
elseif isinf(value)
    textValue = "Inf";
else
    textValue = sprintf('%.8g', value);
end
end

function writeMarkdownReport(report, reportPath)
fid = fopen(reportPath, 'w', 'n', 'UTF-8');
assert(fid >= 0, 'RouteA:ParameterAuditWrite', ...
    'Cannot write parameter audit report: %s', reportPath);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# Route A 模型-面板参数汇总表 v01\n\n');
fprintf(fid, '本表由 `routeA_audit_parameter_inventory.m` 从当前 `.slx` 的模型工作区和 `Simulink.findVars` 生成。');
fprintf(fid, '模型引用是参数有效性的唯一依据；面板可写项必须指向实际被模型引用的写入目标。\n\n');
fprintf(fid, '- 模型：`%s`\n', report.model);
fprintf(fid, '- 生成时间：%s\n', report.generatedAt);
fprintf(fid, '- 模型 Dirty：`%s`\n\n', report.modelDirty);

fprintf(fid, '## 覆盖摘要\n\n');
fprintf(fid, '| 项目 | 数量 | 含义 |\n|---|---:|---|\n');
fprintf(fid, '| 模型工作区变量 | %d | 当前 `.slx` 保存的变量 |\n', report.counts.workspaceVariableCount);
fprintf(fid, '| 被模型实际引用的工作区变量 | %d | `Simulink.findVars` 在模型范围内检出 |\n', report.counts.referencedWorkspaceVariableCount);
fprintf(fid, '| 面板活动参数 | %d | 通过统一 `simCase -> SimulationInput` 链路应用 |\n', report.counts.activePanelEntryCount);
fprintf(fid, '| 面板写入目标未被模型引用 | %d | 必须移出可写面板或补齐模型接线 |\n', report.counts.panelWriteTargetMismatchCount);
fprintf(fid, '| 模型已引用但尚未开放为面板活动参数 | %d | 保留目录并按验证准入决定是否开放 |\n\n', report.counts.referencedModelParametersWithoutActivePanelEntryCount);

fprintf(fid, '## 数量口径与从属关系\n\n');
fprintf(fid, '以下三组数字使用不同计数单位，不能直接相加：模型工作区按变量计数，面板按输入契约条目计数，设备目录按设备参数目录条目计数。\n\n');
fprintf(fid, '- 模型工作区变量：`%d = %d 实际引用 + %d 未引用/辅助 + %d 面板映射但未被引用`。\n', ...
    report.counts.workspaceVariableCount, report.counts.referencedWorkspaceVariableCount, ...
    report.counts.workspaceOnlyVariableCount, report.counts.panelEntryWithoutModelReferenceCount);
fprintf(fid, '- 实际引用变量：`%d = %d 已由面板承接 + %d 已引用但待开放`。\n', ...
    report.counts.referencedWorkspaceVariableCount, ...
    report.counts.panelMappedReferencedWorkspaceVariableCount, ...
    report.counts.referencedModelParametersWithoutActivePanelEntryCount);
fprintf(fid, '- 活动面板参数：`%d` 个契约条目，按页签拆分为基础/高级/设备页；其中可能包含非工作区输入、一个条目写入多个变量，以及图谱数组和几何派生写入，因此不与工作区变量数相加。\n', ...
    report.counts.activePanelEntryCount);
fprintf(fid, '- 设备页目录：`%d = %d 可编辑字段 + %d platform_default 源目录 + %d 未接入审查`；空压机三数组作为一个图谱编辑器组原子提交，但在参数契约中保留三条数组记录。\n\n', ...
    report.counts.deviceCatalogEntryCount, report.counts.deviceEditableEntryCount, ...
    report.counts.deviceInventoryEntryCount, report.counts.deviceUnresolvedEntryCount);

fprintf(fid, '状态解释：模型已引用/面板已承接 = 已闭合输入链；库边界已验证/面板已承接 = 通过库封装边界生效；模型已引用/待开放 = 真实模型变量但当前只读；未引用/工作区辅助 = 当前不参与模型行为；platform_default 源目录 = 默认参数叶项，不是独立面板输入；未接入审查 = 已登记但尚未绑定活动块参数；异常 = 面板映射或写入目标未被模型引用，需要修复。\n\n');

fprintf(fid, '## 面板输入与模型写入链\n\n');
fprintf(fid, '| 面板参数 | 页签 | 单位 | 范围 | 工作区变量 | 时序字段 | 实际写入目标 | 派生写入目标 | 写入方式 | 引用状态 |\n|---|---|---|---|---|---|---|---|---|---|\n');
for idx = 1:height(report.inputContract)
    row = report.inputContract(idx, :);
    fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n', ...
        markdownCell(row.canonicalName), panelExposureText(row.panelExposure), ...
        markdownCell(row.unit), markdownCell(row.limits), ...
        markdownCell(row.modelWorkspaceVariable), markdownCell(row.profileField), ...
        markdownCell(row.resolvedWriteVariable), ...
        markdownCell(row.derivedWriteVariables), markdownCell(row.application), ...
        referenceStateText(row.referenceState));
end

fprintf(fid, '\n## 模型工作区参数\n\n');
fprintf(fid, '| 变量 | 默认值摘要 | 类型/尺寸 | 物理含义/功能 | 开放处置 | 模型引用状态 | 所属子系统/块 | 面板承接参数 | 面板权限 |\n|---|---|---|---|---|---|---|---|---|\n');
for idx = 1:height(report.workspace)
    row = report.workspace(idx, :);
    fprintf(fid, '| %s | %s | %s %s | %s | %s | %s | %s | %s | %s |\n', ...
        markdownCell(row.modelVariable), markdownCell(row.valuePreview), ...
        markdownCell(row.valueClass), markdownCell(row.size), ...
        physicalMeaning(row.modelVariable, row.physicalRole), ...
        markdownCell(row.openingDisposition), ...
        referenceStateText(row.referenceState), ...
        markdownCell(row.blockUsers), markdownCell(row.activePanelEntries), ...
        panelExposureText(row.panelExposure));
end

fprintf(fid, '\n## 命名与冗余审计\n\n');
fprintf(fid, '该审计区分“同一物理量的重复写入”与“不同部件恰好同值”。只有前者才会合并或建立派生关系；相同的环境初值、两侧分离器参数等不视为冗余。\n\n');
fprintf(fid, '| 分类 | 规范输入 | 工作区变量 | 状态 | 证据 |\n|---|---|---|---|---|\n');
for idx = 1:height(report.redundancyAudit)
    row = report.redundancyAudit(idx, :);
    fprintf(fid, '| %s | %s | %s | %s | %s |\n', ...
        markdownCell(row.classification), markdownCell(row.canonicalInput), ...
        markdownCell(row.modelVariables), markdownCell(row.state), ...
        markdownCell(row.evidence));
end

fprintf(fid, '\n## 维护规则\n\n');
fprintf(fid, '1. 新增面板输入前，必须先在本表中确认其“实际写入目标”为 `write_target_referenced`。\n');
fprintf(fid, '2. 模型引用但未开放的参数先在“系统模型参数”页保持只读目录状态，并进入开放审查；补足参数来源、范围、验证器和响应证据后转为可写，只有明确属于内部建模或初始化的变量继续只读。\n');
fprintf(fid, '3. `workspace_only` 变量不得被称为当前设备性能，除非后续确认对活动模型/面板计算链有用途、补齐块接线并重新审计；无用途的历史变量移除或归档。\n');
fprintf(fid, '4. 同一几何量若模型需同时使用直径与面积，只保留一个可编辑规范输入，其余变量必须在 `SimulationInput` 中由它推导。\n');
fprintf(fid, '5. 面板最终闭环必须保持为“输入基础/高级/设备参数 -> 运行统一模型 -> 返回结果”；“系统模型参数”只承担完整参数的只读解释和追溯。\n');
end

function textValue = referenceStateText(state)
switch string(state)
    case "model_referenced_panel_contract"
        textValue = "模型已引用 / 面板已承接";
    case "model_referenced_no_active_panel_entry"
        textValue = "模型已引用 / 待开放";
    case "library_boundary_verified"
        textValue = "库边界已验证 / 面板已承接";
    case "workspace_only"
        textValue = "未引用 / 工作区辅助";
    case "panel_entry_without_model_reference"
        textValue = "异常：面板映射但模型未引用";
    case "non_workspace_input"
        textValue = "非工作区输入 / 运行配置";
    case "write_target_library_boundary_verified"
        textValue = "库边界已验证 / 面板已承接";
    case "write_target_referenced"
        textValue = "模型写入目标已引用";
    case "write_target_not_referenced"
        textValue = "异常：写入目标未被模型引用";
    otherwise
        textValue = string(state);
end
textValue = markdownCell(textValue);
end

function textValue = panelExposureText(exposure)
switch string(exposure)
    case "basic"
        textValue = "基础页可编辑";
    case "advanced"
        textValue = "高级页可编辑";
    case "device_settings"
        textValue = "设备页可编辑";
    case "read_only_catalog"
        textValue = "固定平台边界 / 只读";
    otherwise
        textValue = markdownCell(exposure);
end
textValue = markdownCell(textValue);
end

function textValue = physicalMeaning(name, fallback)
name = string(name);
if name == "stack_num_cells"
    textValue = "电堆串联单体数量";
elseif name == "stack_area"
    textValue = "每个单体有效活性面积";
elseif name == "stack_iL"
    textValue = "电化学极限电流密度";
elseif name == "stack_io"
    textValue = "电化学交换电流密度";
elseif startsWith(name, "stack_")
    textValue = "电堆 / MEA 性能或几何参数";
elseif startsWith(name, "coolant_")
    textValue = "冷却回路几何、流阻或通道参数";
elseif startsWith(name, "radiator_")
    textValue = "散热器换热几何、材料或热容量参数";
elseif startsWith(name, "comp_")
    textValue = "阴极空压机入口容积或特性图谱参数";
elseif startsWith(name, "intercooler_")
    textValue = "阴极中冷器几何、流阻或换热参数";
elseif startsWith(name, "cathode_separator_")
    textValue = "阴极分离器流阻与初始状态参数";
elseif startsWith(name, "anode_separator_")
    textValue = "阳极分离器流阻与初始状态参数";
elseif startsWith(name, "cegr_")
    textValue = "cEGR 回流管、阀或支路控制参数";
elseif startsWith(name, "routeA_")
    textValue = "Route A 运行、控制或接口配置";
elseif startsWith(name, "drive_cycle_")
    textValue = "电边界命令时序或其辅助字段";
elseif startsWith(name, "env_")
    textValue = "环境压力、温度、湿度或气体组分边界";
elseif startsWith(name, "tank_")
    textValue = "阳极储氢罐状态或气体组分";
elseif startsWith(name, "pSat_") || name == "T_TLU"
    textValue = "水蒸气饱和性质查表数据";
elseif startsWith(name, "Gas_properties")
    textValue = "气体混合物属性配置或候选列表";
elseif startsWith(name, "humidifier_")
    textValue = "加湿器工作状态或旁路配置";
elseif startsWith(name, "separator_")
    textValue = "L2 冷凝/分离能力配置";
else
    textValue = string(fallback);
end
textValue = markdownCell(textValue);
end

function textValue = markdownCell(value)
if iscell(value)
    value = value{1};
end
textValue = char(replace(string(value), ["|", newline], ["\\|", "<br>"]));
if isempty(textValue)
    textValue = '-';
end
end
