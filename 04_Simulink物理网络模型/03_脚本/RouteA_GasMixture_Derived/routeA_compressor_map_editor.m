function [map, accepted] = routeA_compressor_map_editor(initialMap)
% Open a resizable editor for the compressor three-array lookup-table map.
%
% The function is intentionally independent of the main app class. It
% returns only after Apply or Cancel, so the caller can atomically replace
% its draft map without exposing partially edited lookup arrays.

map = routeA_validate_compressor_map(initialMap);
accepted = false;
defaults = routeA_simCase_template().controls.devices.cathode.compressorMap;

fig = uifigure( ...
    'Name', 'Route A 空压机图谱编辑器', ...
    'Position', [130 120 1080 700], ...
    'Resize', 'on', ...
    'Visible', 'off', ...
    'CloseRequestFcn', @cancelEditor);
layout = uigridlayout(fig, [4 2]);
layout.RowHeight = {34, '1x', 26, 34};
layout.ColumnWidth = {310, '1x'};
layout.Padding = [12 10 12 10];
layout.RowSpacing = 8;
layout.ColumnSpacing = 10;

titleLabel = uilabel(layout, ...
    'Text', '空压机特性图谱: 转速轴 + 压比轴 + 修正质量流量矩阵', ...
    'FontWeight', 'bold', 'FontSize', 15, ...
    'FontColor', [0.05 0.25 0.50]);
titleLabel.Layout.Row = 1;
titleLabel.Layout.Column = [1 2];

axisPanel = uipanel(layout, 'Title', '断点轴');
axisPanel.Layout.Row = 2;
axisPanel.Layout.Column = 1;
axisGrid = uigridlayout(axisPanel, [8 2]);
axisGrid.RowHeight = {22, '1x', 26, 22, '1x', 26, 24, 24};
axisGrid.ColumnWidth = {'1x', '1x'};
axisGrid.Padding = [8 6 8 6];

rpmLabel = uilabel(axisGrid, 'Text', '转速断点 (rpm)');
rpmLabel.Layout.Row = 1;
rpmLabel.Layout.Column = [1 2];
rpmTable = uitable(axisGrid, ...
    'Data', map.rpm_TLU(:), 'ColumnName', {'rpm'}, ...
    'ColumnEditable', true, 'RowName', {}, ...
    'CellEditCallback', @mapEdited);
rpmTable.Layout.Row = 2;
rpmTable.Layout.Column = [1 2];
addSpeedButton = uibutton(axisGrid, 'push', ...
    'Text', '增加转速列', 'ButtonPushedFcn', @addSpeed);
addSpeedButton.Layout.Row = 3;
addSpeedButton.Layout.Column = 1;
removeSpeedButton = uibutton(axisGrid, 'push', ...
    'Text', '删除末列', 'ButtonPushedFcn', @removeSpeed);
removeSpeedButton.Layout.Row = 3;
removeSpeedButton.Layout.Column = 2;

pressureLabel = uilabel(axisGrid, 'Text', '压比断点 (-)');
pressureLabel.Layout.Row = 4;
pressureLabel.Layout.Column = [1 2];
pressureTable = uitable(axisGrid, ...
    'Data', map.p_ratio_TLU(:), 'ColumnName', {'pressure ratio'}, ...
    'ColumnEditable', true, 'RowName', {}, ...
    'CellEditCallback', @mapEdited);
pressureTable.Layout.Row = 5;
pressureTable.Layout.Column = [1 2];
addPressureButton = uibutton(axisGrid, 'push', ...
    'Text', '增加压比行', 'ButtonPushedFcn', @addPressure);
addPressureButton.Layout.Row = 6;
addPressureButton.Layout.Column = 1;
removePressureButton = uibutton(axisGrid, 'push', ...
    'Text', '删除末行', 'ButtonPushedFcn', @removePressure);
removePressureButton.Layout.Row = 6;
removePressureButton.Layout.Column = 2;
axisHint = uilabel(axisGrid, ...
    'Text', '轴必须严格递增; 压比不得小于 1。', ...
    'FontColor', [0.35 0.35 0.35], 'FontSize', 10);
axisHint.Layout.Row = 7;
axisHint.Layout.Column = [1 2];
sourceLabel = uilabel(axisGrid, ...
    'Text', sprintf('当前来源: %s', string(map.source)), ...
    'FontColor', [0.35 0.35 0.35], 'FontSize', 10);
sourceLabel.Layout.Row = 8;
sourceLabel.Layout.Column = [1 2];

tablePanel = uipanel(layout, 'Title', '修正质量流量表 (kg/s)');
tablePanel.Layout.Row = 2;
tablePanel.Layout.Column = 2;
tableGrid = uigridlayout(tablePanel, [2 1]);
tableGrid.RowHeight = {260, '1x'};
tableGrid.Padding = [8 6 8 6];
mapTable = uitable(tableGrid, ...
    'Data', map.mdot_corr_TLU, ...
    'ColumnEditable', true(1, numel(map.rpm_TLU)), ...
    'CellEditCallback', @mapEdited);
mapTable.Layout.Row = 1;
previewAxes = uiaxes(tableGrid);
previewAxes.Layout.Row = 2;

statusLabel = uilabel(layout, ...
    'Text', '草稿已载入。编辑后点击“应用图谱”执行严格校验。', ...
    'FontColor', [0.20 0.25 0.30]);
statusLabel.Layout.Row = 3;
statusLabel.Layout.Column = [1 2];

buttonPanel = uipanel(layout, 'BorderType', 'none');
buttonPanel.Layout.Row = 4;
buttonPanel.Layout.Column = [1 2];
buttonGrid = uigridlayout(buttonPanel, [1 4]);
buttonGrid.ColumnWidth = {'1x', 130, 110, 90};
buttonGrid.Padding = [0 0 0 0];
restoreButton = uibutton(buttonGrid, 'push', ...
    'Text', '恢复官方默认图谱', 'ButtonPushedFcn', @restoreDefaults);
restoreButton.Layout.Row = 1;
restoreButton.Layout.Column = 2;
applyButton = uibutton(buttonGrid, 'push', ...
    'Text', '应用图谱', 'ButtonPushedFcn', @applyMap, ...
    'BackgroundColor', [0.10 0.45 0.75], 'FontColor', [1 1 1]);
applyButton.Layout.Row = 1;
applyButton.Layout.Column = 3;
cancelButton = uibutton(buttonGrid, 'push', ...
    'Text', '取消', 'ButtonPushedFcn', @cancelEditor);
cancelButton.Layout.Row = 1;
cancelButton.Layout.Column = 4;

refreshMapTable();
refreshPreview();
fig.Visible = 'on';
uiwait(fig);
if isvalid(fig)
    outcome = fig.UserData;
    if isstruct(outcome) && isfield(outcome, 'accepted') && outcome.accepted
        map = outcome.map;
        accepted = true;
    end
    delete(fig);
end

    function mapEdited(~, ~)
        refreshMapTable();
        refreshPreview();
        statusLabel.Text = '草稿已修改，尚未通过严格校验。';
        statusLabel.FontColor = [0.55 0.30 0.05];
    end

    function addSpeed(~, ~)
        data = numericData(rpmTable.Data);
        if numel(data) < 2
            increment = 1000;
        else
            increment = max(1, data(end) - data(end - 1));
        end
        rpmTable.Data = [data(:); data(end) + increment];
        flow = numericData(mapTable.Data);
        mapTable.Data = [flow, flow(:, end)];
        refreshMapTable();
        mapEdited([], []);
    end

    function removeSpeed(~, ~)
        data = numericData(rpmTable.Data);
        if numel(data) <= 2
            uialert(fig, '图谱至少需要两个转速断点。', '不能删除');
            return;
        end
        rpmTable.Data = data(1:end - 1);
        flow = numericData(mapTable.Data);
        mapTable.Data = flow(:, 1:end - 1);
        refreshMapTable();
        mapEdited([], []);
    end

    function addPressure(~, ~)
        data = numericData(pressureTable.Data);
        if numel(data) < 2
            increment = 0.1;
        else
            increment = max(0.01, data(end) - data(end - 1));
        end
        pressureTable.Data = [data(:); data(end) + increment];
        flow = numericData(mapTable.Data);
        mapTable.Data = [flow; flow(end, :)];
        refreshMapTable();
        mapEdited([], []);
    end

    function removePressure(~, ~)
        data = numericData(pressureTable.Data);
        if numel(data) <= 2
            uialert(fig, '图谱至少需要两个压比断点。', '不能删除');
            return;
        end
        pressureTable.Data = data(1:end - 1);
        flow = numericData(mapTable.Data);
        mapTable.Data = flow(1:end - 1, :);
        refreshMapTable();
        mapEdited([], []);
    end

    function restoreDefaults(~, ~)
        rpmTable.Data = defaults.rpm_TLU(:);
        pressureTable.Data = defaults.p_ratio_TLU(:);
        mapTable.Data = defaults.mdot_corr_TLU;
        sourceLabel.Text = sprintf('当前来源: %s', string(defaults.source));
        refreshMapTable();
        refreshPreview();
        statusLabel.Text = '已恢复官方默认图谱; 点击“应用图谱”提交。';
        statusLabel.FontColor = [0.20 0.25 0.30];
    end

    function applyMap(~, ~)
        try
            candidate = collectMap();
            candidate.source = "panel_user";
            candidate.schemaVersion = "RouteA_CompressorMap_v01";
            candidate = routeA_validate_compressor_map(candidate);
        catch err
            statusLabel.Text = "校验未通过: " + string(err.message);
            statusLabel.FontColor = [0.75 0.10 0.10];
            uialert(fig, err.message, '空压机图谱校验失败');
            return;
        end
        fig.UserData = struct('accepted', true, 'map', candidate);
        uiresume(fig);
    end

    function cancelEditor(~, ~)
        fig.UserData = struct('accepted', false);
        uiresume(fig);
    end

    function candidate = collectMap()
        candidate = struct();
        candidate.rpm_TLU = reshape(numericData(rpmTable.Data), 1, []);
        candidate.p_ratio_TLU = reshape(numericData(pressureTable.Data), [], 1);
        candidate.mdot_corr_TLU = numericData(mapTable.Data);
    end

    function refreshMapTable(updateLabels)
        if nargin < 1
            updateLabels = true;
        end
        rpm = numericData(rpmTable.Data);
        pressureRatio = numericData(pressureTable.Data);
        if updateLabels
            mapTable.ColumnName = cellstr(compose('%.6g rpm', rpm(:)'));
            mapTable.RowName = cellstr(compose('PR %.5g', pressureRatio(:)));
            mapTable.ColumnEditable = true(1, numel(rpm));
        end
    end

    function refreshPreview()
        rpm = numericData(rpmTable.Data);
        pressureRatio = numericData(pressureTable.Data);
        flow = numericData(mapTable.Data);
        cla(previewAxes);
        if isempty(rpm) || isempty(pressureRatio) || ...
                size(flow, 1) ~= numel(pressureRatio) || size(flow, 2) ~= numel(rpm)
            title(previewAxes, '等待匹配的表格尺寸');
            return;
        end
        hold(previewAxes, 'on');
        for row = 1:numel(pressureRatio)
            plot(previewAxes, rpm, flow(row, :), '-o', ...
                'DisplayName', sprintf('PR %.4g', pressureRatio(row)));
        end
        hold(previewAxes, 'off');
        title(previewAxes, '图谱预览');
        xlabel(previewAxes, '转速 (rpm)');
        ylabel(previewAxes, '修正质量流量 (kg/s)');
        grid(previewAxes, 'on');
        legend(previewAxes, 'Location', 'best');
    end
end

function values = numericData(data)
if iscell(data)
    values = cellfun(@double, data);
else
    values = double(data);
end
end
