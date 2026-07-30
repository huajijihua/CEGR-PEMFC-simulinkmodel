function [resultSnapshot, readback] = routeA_panel_export_result(results, outputFile)
% Export one P1 result and verify the saved schema by loading it again.

if ~isstruct(results) || ~isscalar(results) || ...
        ~isfield(results, 'resultContractVersion')
    error('RouteA:ResultExportInput', ...
        'A scalar P1 result object is required for export.');
end
if ~(ischar(outputFile) || isstring(outputFile)) || ...
        ~isscalar(string(outputFile))
    error('RouteA:ResultExportPath', 'outputFile must be a scalar text path.');
end
outputFile = char(string(outputFile));
outputDir = fileparts(outputFile);
if ~isempty(outputDir) && ~isfolder(outputDir)
    mkdir(outputDir);
end

resultSnapshot = results;
resultSnapshot.outputLevel = "full_export";
resultSnapshot.exportedAt = string(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss'));
resultSnapshot.exportFile = string(outputFile);
compactResult = removeFullField(resultSnapshot);
resultSnapshot.full = struct( ...
    'compact', compactResult, ...
    'timeSeries', getFieldOr(resultSnapshot, 'full', struct()), ...
    'signalManifest', getFieldOr(resultSnapshot, 'signalManifest', struct()));
% Preserve the extractor's explicit timeSeries fields while adding a
% non-recursive compact snapshot to the full export.
if isfield(results, 'full') && isstruct(results.full)
    resultSnapshot.full.timeSeries = getFieldOr(results.full, 'timeSeries', struct());
    resultSnapshot.full.signalManifest = getFieldOr(results.full, ...
        'signalManifest', resultSnapshot.signalManifest);
end
save(outputFile, 'resultSnapshot', '-v7.3');

loaded = load(outputFile, 'resultSnapshot');
if ~isfield(loaded, 'resultSnapshot') || ...
        ~isstruct(loaded.resultSnapshot)
    error('RouteA:ResultExportReadback', ...
        'Saved result file did not contain resultSnapshot.');
end
readbackSnapshot = loaded.resultSnapshot;
requiredFields = {'resultContractVersion', 'caseId', 'domains', ...
    'signalManifest', 'full', 'parameterSnapshot', 'failureStack'};
missing = requiredFields(~isfield(readbackSnapshot, requiredFields));
if ~isempty(missing)
    error('RouteA:ResultExportReadback', ...
        'Saved result is missing fields: %s.', strjoin(missing, ', '));
end
if string(readbackSnapshot.resultContractVersion) ~= ...
        string(resultSnapshot.resultContractVersion)
    error('RouteA:ResultExportReadback', ...
        'Result contract version changed during export readback.');
end
if ~isfield(readbackSnapshot.full, 'compact') || ...
        ~isstruct(readbackSnapshot.full.compact)
    error('RouteA:ResultExportReadback', ...
        'Full export does not contain a compact result snapshot.');
end
resultSnapshot = readbackSnapshot;
readback = struct( ...
    'passed', true, ...
    'file', string(outputFile), ...
    'contractVersion', string(resultSnapshot.resultContractVersion), ...
    'caseId', string(resultSnapshot.caseId), ...
    'compactIncluded', true, ...
    'signalManifestCount', numel(resultSnapshot.signalManifest), ...
    'fullExport', true);
end

function value = getFieldOr(parent, fieldName, fallback)
value = fallback;
if isstruct(parent) && isscalar(parent) && isfield(parent, fieldName)
    value = parent.(fieldName);
end
end

function value = removeFullField(result)
value = result;
if isfield(value, 'full')
    value = rmfield(value, 'full');
end
end
