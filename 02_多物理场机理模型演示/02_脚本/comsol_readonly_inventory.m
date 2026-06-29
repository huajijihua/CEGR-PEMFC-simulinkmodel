function summary = comsol_readonly_inventory(userCfg)
%COMSOL_READONLY_INVENTORY Read a compact COMSOL Server model inventory.
%
% This script connects to an existing COMSOL Server session, summarizes the
% models currently loaded in that session, and does not modify, solve, save,
% export, or create model files.

if nargin < 1
    userCfg = struct();
end
cfg = localDefaultConfig();
cfg = localMergeStruct(cfg, userCfg);

if exist('mphstart', 'file') == 0 && isfolder(cfg.comsolMliPath)
    addpath(cfg.comsolMliPath);
end
assert(exist('mphstart', 'file') ~= 0, ...
    'COMSOL LiveLink mphstart was not found. Check cfg.comsolMliPath.');

import com.comsol.model.*
import com.comsol.model.util.*

connectedByScript = false;
try
    modelTags = localJavaStringArrayToCell(ModelUtil.tags());
catch
    mphstart(cfg.comsolHost, cfg.comsolPort);
    connectedByScript = true;
    modelTags = localJavaStringArrayToCell(ModelUtil.tags());
end

summary = struct();
summary.host = cfg.comsolHost;
summary.port = cfg.comsolPort;
summary.comsolMliPath = cfg.comsolMliPath;
summary.connectedByScript = connectedByScript;
summary.modelTags = modelTags;
summary.models = repmat(localEmptyModelSummary(), 1, 0);

fprintf('COMSOL_READONLY_INVENTORY host=%s port=%d models=%d\n', ...
    cfg.comsolHost, cfg.comsolPort, numel(modelTags));

for i = 1:numel(modelTags)
    model = ModelUtil.model(modelTags{i});
    item = localDescribeModel(model, modelTags{i}, cfg);
    summary.models(end + 1) = item; %#ok<AGROW>
    localPrintModelSummary(item, cfg);
end

if isempty(modelTags)
    fprintf('COMSOL_NO_MODELS_LOADED: open the target .mph in the GUI connected to the same Server.\n');
end
end

function cfg = localDefaultConfig()
cfg = struct();
cfg.comsolHost = 'localhost';
cfg.comsolPort = 2036;
cfg.comsolMliPath = 'D:\COMSOL63\Multiphysics\mli';
cfg.maxTagsPerGroup = 40;
cfg.includeFeatureTags = true;
end

function cfg = localMergeStruct(cfg, userCfg)
names = fieldnames(userCfg);
for i = 1:numel(names)
    name = names{i};
    cfg.(name) = userCfg.(name);
end
end

function item = localEmptyModelSummary()
item = struct();
item.tag = '';
item.label = '';
item.filePath = '';
item.componentTags = cell(1, 0);
item.geometryTags = cell(1, 0);
item.materialTags = cell(1, 0);
item.physics = repmat(struct('component', '', 'tag', '', 'label', '', 'featureTags', {{}}), 1, 0);
item.variableTags = cell(1, 0);
item.probeTags = cell(1, 0);
item.studyTags = cell(1, 0);
item.solverTags = cell(1, 0);
item.solutionTags = cell(1, 0);
item.datasetTags = cell(1, 0);
item.evidencePaths = cell(1, 0);
item.warnings = cell(1, 0);
end

function item = localDescribeModel(model, modelTag, cfg)
item = localEmptyModelSummary();
item.tag = modelTag;
item.label = localTryChar(@() model.label(), '');
item.filePath = localTryChar(@() model.file(), '');

item.componentTags = localCollectionTags(@() model.component());
item.studyTags = localCollectionTags(@() model.study());
item.solverTags = localCollectionTags(@() model.sol());
item.solutionTags = item.solverTags;
item.datasetTags = localCollectionTags(@() model.result().dataset());

globalMaterials = localCollectionTags(@() model.material());
globalVariables = localCollectionTags(@() model.variable());
globalProbes = localCollectionTags(@() model.probe());

item.materialTags = globalMaterials;
item.variableTags = globalVariables;
item.probeTags = globalProbes;

for c = 1:numel(item.componentTags)
    compTag = item.componentTags{c};
    comp = model.component(compTag);

    geomTags = localCollectionTags(@() comp.geom());
    item.geometryTags = localUniqueAppend(item.geometryTags, ...
        localPrefixTags('component', compTag, 'geometry', geomTags));

    compMaterials = localCollectionTags(@() comp.material());
    item.materialTags = localUniqueAppend(item.materialTags, ...
        localPrefixTags('component', compTag, 'material', compMaterials));

    compVariables = localCollectionTags(@() comp.variable());
    item.variableTags = localUniqueAppend(item.variableTags, ...
        localPrefixTags('component', compTag, 'variable', compVariables));

    compProbes = localCollectionTags(@() comp.probe());
    item.probeTags = localUniqueAppend(item.probeTags, ...
        localPrefixTags('component', compTag, 'probe', compProbes));

    physicsTags = localCollectionTags(@() comp.physics());
    for p = 1:numel(physicsTags)
        physTag = physicsTags{p};
        phys = comp.physics(physTag);
        physItem = struct();
        physItem.component = compTag;
        physItem.tag = physTag;
        physItem.label = localTryChar(@() phys.label(), '');
        if cfg.includeFeatureTags
            physItem.featureTags = localTrim(localCollectionTags(@() phys.feature()), cfg.maxTagsPerGroup);
        else
            physItem.featureTags = {};
        end
        item.physics(end + 1) = physItem; %#ok<AGROW>
    end
end

item.componentTags = localTrim(item.componentTags, cfg.maxTagsPerGroup);
item.geometryTags = localTrim(item.geometryTags, cfg.maxTagsPerGroup);
item.materialTags = localTrim(item.materialTags, cfg.maxTagsPerGroup);
item.variableTags = localTrim(item.variableTags, cfg.maxTagsPerGroup);
item.probeTags = localTrim(item.probeTags, cfg.maxTagsPerGroup);
item.studyTags = localTrim(item.studyTags, cfg.maxTagsPerGroup);
item.solverTags = localTrim(item.solverTags, cfg.maxTagsPerGroup);
item.solutionTags = localTrim(item.solutionTags, cfg.maxTagsPerGroup);
item.datasetTags = localTrim(item.datasetTags, cfg.maxTagsPerGroup);

item.evidencePaths = localBuildEvidencePaths(item);
end

function localPrintModelSummary(item, cfg)
fprintf('MODEL tag=%s label=%s file=%s\n', item.tag, item.label, item.filePath);
fprintf('  components=%s\n', localJoin(item.componentTags));
fprintf('  geometries=%s\n', localJoin(item.geometryTags));
fprintf('  materials=%s\n', localJoin(item.materialTags));
fprintf('  variables=%s\n', localJoin(item.variableTags));
fprintf('  probes=%s\n', localJoin(item.probeTags));
fprintf('  studies=%s\n', localJoin(item.studyTags));
fprintf('  solvers=%s\n', localJoin(item.solverTags));
fprintf('  datasets=%s\n', localJoin(item.datasetTags));
fprintf('  physics_count=%d\n', numel(item.physics));
for p = 1:min(numel(item.physics), cfg.maxTagsPerGroup)
    phys = item.physics(p);
    fprintf('    physics component=%s tag=%s label=%s features=%s\n', ...
        phys.component, phys.tag, phys.label, localJoin(phys.featureTags));
end
fprintf('  evidence_paths=%s\n', localJoin(item.evidencePaths));
end

function paths = localBuildEvidencePaths(item)
paths = {};
for i = 1:numel(item.componentTags)
    paths{end + 1} = sprintf('component/%s', item.componentTags{i}); %#ok<AGROW>
end
for i = 1:numel(item.physics)
    paths{end + 1} = sprintf('component/%s/physics/%s', ...
        item.physics(i).component, item.physics(i).tag); %#ok<AGROW>
end
for i = 1:numel(item.studyTags)
    paths{end + 1} = sprintf('study/%s', item.studyTags{i}); %#ok<AGROW>
end
for i = 1:numel(item.solverTags)
    paths{end + 1} = sprintf('solver/%s', item.solverTags{i}); %#ok<AGROW>
end
end

function tags = localCollectionTags(collectionFcn)
try
    collection = collectionFcn();
    tags = localJavaStringArrayToCell(collection.tags());
catch
    tags = {};
end
end

function cells = localJavaStringArrayToCell(values)
cells = cell(1, numel(values));
for i = 1:numel(values)
    cells{i} = char(values(i));
end
end

function value = localTryChar(valueFcn, fallback)
try
    value = char(valueFcn());
catch
    value = fallback;
end
end

function out = localPrefixTags(kind1, tag1, kind2, tags)
out = cell(1, numel(tags));
for i = 1:numel(tags)
    out{i} = sprintf('%s/%s/%s/%s', kind1, tag1, kind2, tags{i});
end
end

function out = localUniqueAppend(base, extra)
out = base;
for i = 1:numel(extra)
    if ~ismember(extra{i}, out)
        out{end + 1} = extra{i}; %#ok<AGROW>
    end
end
end

function tags = localTrim(tags, maxItems)
if numel(tags) > maxItems
    tags = [tags(1:maxItems), {sprintf('...(+%d)', numel(tags) - maxItems)}];
end
end

function text = localJoin(values)
if isempty(values)
    text = '<none>';
else
    text = strjoin(values, ', ');
end
end
