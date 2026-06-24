function T = load_testbench_10kw_recommended_conditions()
%LOAD_TESTBENCH_10KW_RECOMMENDED_CONDITIONS Read stack datasheet recommended conditions.
% 读取 `电堆信息及推荐测试工况.xlsx` 中的推荐测试工况表，并转成便于脚本使用的数值表。

scriptDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(scriptDir);
projectRoot = fileparts(fileparts(rootDir));
xlsxFile = fullfile(projectRoot, '00_支撑材料', '实验数据-设备说明书', ...
    '电堆信息及推荐测试工况.xlsx');
if ~isfile(xlsxFile)
    error('CEGR:SimplifiedBench:MissingRecommendedXlsx', ...
        'Cannot find %s', xlsxFile);
end

C = readcell(xlsxFile, 'Sheet', 'Sheet1');
if size(C, 1) < 4 || size(C, 2) < 13
    error('CEGR:SimplifiedBench:BadRecommendedXlsx', ...
        'Unexpected shape for %s.', xlsxFile);
end

raw = C(4:end, 1:13);
keep = cellfun(@(x) isnumeric(x) && isfinite(x), raw(:, 2));
raw = raw(keep, :);

T = table();
T.sequence_index = numericColumn(raw(:, 1));
T.current_A = numericColumn(raw(:, 2));
T.anode_stoich = numericColumn(raw(:, 3));
T.cathode_stoich = numericColumn(raw(:, 4));
T.anode_p_kPa_g = numericColumn(raw(:, 5));
T.cathode_p_kPa_g = numericColumn(raw(:, 6));
T.water_in_p_kPa_g = numericColumn(raw(:, 7));
T.anode_in_T_C = numericColumn(raw(:, 8));
T.cathode_in_T_C = numericColumn(raw(:, 9));
T.anode_RH_pct = numericColumn(raw(:, 10));
T.cathode_RH_pct = numericColumn(raw(:, 11));
T.water_in_T_C = numericColumn(raw(:, 12));
T.water_dT_C = numericColumn(raw(:, 13));
T.current_density_A_cm2 = T.current_A / 380.0;
T = sortrows(T, 'current_A');
end

function v = numericColumn(col)
n = numel(col);
v = nan(n, 1);
for k = 1:n
    item = col{k};
    if isnumeric(item)
        v(k) = item;
    elseif ismissing(item) || isempty(item)
        v(k) = NaN;
    else
        value = str2double(string(item));
        if isnan(value)
            error('CEGR:SimplifiedBench:BadRecommendedCell', ...
                'Cannot convert recommended-condition cell "%s" to numeric.', string(item));
        end
        v(k) = value;
    end
end
end
