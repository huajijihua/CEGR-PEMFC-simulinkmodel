function map = routeA_validate_compressor_map(map)
% Validate and normalize the compressor three-array lookup-table contract.
%
% rpm_TLU is a nonnegative, strictly increasing row vector. p_ratio_TLU is
% a pressure-ratio column vector with values >= 1. mdot_corr_TLU is an
% M-by-N finite nonnegative matrix whose dimensions match the two axes.

if ~isstruct(map) || ~isscalar(map)
    error('RouteA:CompressorMapType', ...
        'compressorMap must be a scalar struct.');
end
required = {'rpm_TLU', 'p_ratio_TLU', 'mdot_corr_TLU'};
for idx = 1:numel(required)
    if ~isfield(map, required{idx})
        error('RouteA:CompressorMapField', ...
            'compressorMap.%s is required.', required{idx});
    end
end
rpm = double(map.rpm_TLU);
pressureRatio = double(map.p_ratio_TLU);
mdot = double(map.mdot_corr_TLU);
if ~isvector(rpm) || isempty(rpm) || ~isreal(rpm) || any(~isfinite(rpm(:)))
    error('RouteA:CompressorMapRpm', ...
        'rpm_TLU must be a finite real vector.');
end
if ~isvector(pressureRatio) || isempty(pressureRatio) || ...
        ~isreal(pressureRatio) || any(~isfinite(pressureRatio(:)))
    error('RouteA:CompressorMapPressureRatio', ...
        'p_ratio_TLU must be a finite real vector.');
end
if ~ismatrix(mdot) || isempty(mdot) || ~isreal(mdot) || ...
        any(~isfinite(mdot(:)))
    error('RouteA:CompressorMapMdot', ...
        'mdot_corr_TLU must be a finite real matrix.');
end
rpm = reshape(rpm, 1, []);
pressureRatio = reshape(pressureRatio, [], 1);
if numel(rpm) < 2 || numel(pressureRatio) < 2
    error('RouteA:CompressorMapResolution', ...
        'The compressor map requires at least two speed and two pressure-ratio breakpoints.');
end
if any(rpm < 0) || any(diff(rpm) <= 0)
    error('RouteA:CompressorMapRpmOrder', ...
        'rpm_TLU must be nonnegative and strictly increasing.');
end
if any(pressureRatio < 1) || any(diff(pressureRatio) <= 0)
    error('RouteA:CompressorMapPressureRatioOrder', ...
        'p_ratio_TLU must be >= 1 and strictly increasing.');
end
if ~isequal(size(mdot), [numel(pressureRatio), numel(rpm)])
    error('RouteA:CompressorMapSize', ...
        'mdot_corr_TLU must be %d-by-%d to match the lookup axes.', ...
        numel(pressureRatio), numel(rpm));
end
if any(mdot(:) < 0)
    error('RouteA:CompressorMapMdotSign', ...
        'mdot_corr_TLU must be nonnegative.');
end
map.rpm_TLU = rpm;
map.p_ratio_TLU = pressureRatio;
map.mdot_corr_TLU = mdot;
if ~isfield(map, 'source') || isempty(map.source)
    map.source = "panel_user";
else
    map.source = string(map.source);
end
if ~isfield(map, 'schemaVersion') || isempty(map.schemaVersion)
    map.schemaVersion = "RouteA_CompressorMap_v01";
else
    map.schemaVersion = string(map.schemaVersion);
end
end
