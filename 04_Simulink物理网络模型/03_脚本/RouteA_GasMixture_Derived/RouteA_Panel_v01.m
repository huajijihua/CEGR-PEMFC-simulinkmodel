classdef RouteA_Panel_v01 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        LeftPanel                   matlab.ui.container.Panel
        RightPanel                  matlab.ui.container.Panel
        StatusLabel                 matlab.ui.control.Label
        
        % Mode toggle
        ModeButtonGroup             matlab.ui.container.ButtonGroup
        BasicModeButton             matlab.ui.control.ToggleButton
        AdvancedModeButton          matlab.ui.control.ToggleButton
        
        % Electrical boundary
        ElectricalPanel             matlab.ui.container.Panel
        BoundaryModeLabel           matlab.ui.control.Label
        BoundaryModeDropDown        matlab.ui.control.DropDown
        BoundaryCommandLabel        matlab.ui.control.Label
        BoundaryCommandEditField    matlab.ui.control.NumericEditField
        BoundaryUnitLabel           matlab.ui.control.Label
        RampDurationLabel           matlab.ui.control.Label
        RampDurationEditField       matlab.ui.control.NumericEditField
        RampUnitLabel               matlab.ui.control.Label
        
        % Air path
        AirPathPanel                matlab.ui.container.Panel
        OerLabel                    matlab.ui.control.Label
        OerEditField                matlab.ui.control.NumericEditField
        BackpressureLabel           matlab.ui.control.Label
        BackpressureEditField       matlab.ui.control.NumericEditField
        HumidifierRHLabel           matlab.ui.control.Label
        HumidifierRHEditField       matlab.ui.control.NumericEditField
        
        % cEGR
        CegrPanel                   matlab.ui.container.Panel
        CegrRatioLabel              matlab.ui.control.Label
        CegrRatioEditField          matlab.ui.control.NumericEditField
        CegrEnabledCheckBox         matlab.ui.control.CheckBox
        
        % Solver
        SolverPanel                 matlab.ui.container.Panel
        StopTimeLabel               matlab.ui.control.Label
        StopTimeEditField           matlab.ui.control.NumericEditField

        % Advanced controls
        AdvancedPanel                       matlab.ui.container.Panel
        AdvancedBoundaryModeLabel          matlab.ui.control.Label
        AdvancedBoundaryModeDropDown       matlab.ui.control.DropDown
        AdvancedBoundaryCommandLabel       matlab.ui.control.Label
        AdvancedBoundaryCommandEditField   matlab.ui.control.NumericEditField
        AdvancedBoundaryUnitLabel           matlab.ui.control.Label
        AdvancedRampDurationLabel           matlab.ui.control.Label
        AdvancedRampDurationEditField       matlab.ui.control.NumericEditField
        AdvancedOerLabel                    matlab.ui.control.Label
        AdvancedOerEditField                matlab.ui.control.NumericEditField
        AdvancedBackpressureLabel           matlab.ui.control.Label
        AdvancedBackpressureEditField       matlab.ui.control.NumericEditField
        AdvancedHumidifierRHLabel           matlab.ui.control.Label
        AdvancedHumidifierRHEditField       matlab.ui.control.NumericEditField
        AdvancedCegrRatioLabel              matlab.ui.control.Label
        AdvancedCegrRatioEditField          matlab.ui.control.NumericEditField
        AdvancedCegrEnabledCheckBox         matlab.ui.control.CheckBox
        AdvancedStopTimeLabel               matlab.ui.control.Label
        AdvancedStopTimeEditField           matlab.ui.control.NumericEditField
        AdvancedO2Label                     matlab.ui.control.Label
        AdvancedO2EditField                 matlab.ui.control.NumericEditField
        AdvancedH2OLabel                    matlab.ui.control.Label
        AdvancedH2OEditField                matlab.ui.control.NumericEditField
        AdvancedKpLabel                     matlab.ui.control.Label
        AdvancedKpEditField                 matlab.ui.control.NumericEditField
        AdvancedKiLabel                     matlab.ui.control.Label
        AdvancedKiEditField                 matlab.ui.control.NumericEditField
        AdvancedCurrentMinLabel             matlab.ui.control.Label
        AdvancedCurrentMinEditField         matlab.ui.control.NumericEditField
        AdvancedCurrentMaxLabel             matlab.ui.control.Label
        AdvancedCurrentMaxEditField         matlab.ui.control.NumericEditField
        
        % Case ID
        CaseIdLabel                 matlab.ui.control.Label
        CaseIdEditField             matlab.ui.control.EditField
        
        % Buttons
        RunButton                   matlab.ui.control.Button
        MatrixButton                matlab.ui.control.Button
        
        % Results
        KpiTable                    matlab.ui.control.Table
        TimeSeriesAxes              matlab.ui.control.UIAxes
        LogLabel                    matlab.ui.control.Label
        LogTextArea                 matlab.ui.control.TextArea
    end
    
    % App state properties
    properties (Access = private)
        simCase  % Current simCase struct
        isRunning = false
        lastMatrixStudy = struct()
    end
    
    % Callbacks (public for testing)
    methods (Access = public)

        % Button pushed function: RunButton
        function RunButtonPushed(app, event)
            if app.isRunning
                return;
            end
            app.isRunning = true;
            app.RunButton.Enable = 'off';
            app.MatrixButton.Enable = 'off';
            cleanup = onCleanup(@() app.finishRun()); %#ok<NASGU>
            try
                [app.simCase, rampDuration] = app.collectSimCaseFromUi();

                % Validate
                app.addLog(sprintf('> 校验 %s...', app.simCase.caseId));
                app.simCase = routeA_validate_case(app.simCase);
                app.addLog('  ✓ 校验通过');

                % Build SimulationInput
                app.addLog('> 构建仿真输入...');
                simIn = routeA_panel_build_simulation_input(app.simCase, rampDuration);
                app.addLog('  ✓ SimulationInput 已构建');

                % The helper loads the model when needed. A panel run only
                % applies SimulationInput overrides and does not save the
                % model as a side effect.
                model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
                if ~bdIsLoaded(model)
                    modelDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', ...
                        '01_模型', 'RouteA_GasMixture_Derived');
                    load_system(fullfile(modelDir, [model '.slx']));
                end
                app.addLog(sprintf('> 使用模型 %s...', model));

                % Run simulation
                app.addLog(sprintf('> 运行仿真（预计 %.0f s）...', app.simCase.solver.stopTime_s));
                app.StatusLabel.Text = sprintf('状态: 仿真运行中 | caseId: %s', app.simCase.caseId);
                app.StatusLabel.BackgroundColor = [1 1 0.8];
                drawnow;

                tic;
                out = sim(simIn);
                elapsed = toc;
                app.addLog(sprintf('  ✓ 仿真完成（耗时 %.1f s）', elapsed));

                % Extract results
                app.addLog('> 提取结果...');
                results = routeA_panel_extract_results(out, app.simCase);
                app.addLog(sprintf('  ✓ 尾窗电压: %.2f V, 电流: %.2f A, 功率: %.2f kW', ...
                    results.voltage_V, results.current_A, results.power_kW));

                % Update KPI table
                app.addResultToTable(results);

                % Plot time series
                app.plotTimeSeries(results);

                % Update status
                app.StatusLabel.Text = sprintf('状态: 完成 | caseId: %s | V=%.2f V', ...
                    app.simCase.caseId, results.voltage_V);
                app.StatusLabel.BackgroundColor = [0.8 1 0.8];

            catch ME
                app.addLog(sprintf('  ✗ 失败: %s', ME.message));
                app.StatusLabel.Text = sprintf('状态: 失败 | %s', ME.message);
                app.StatusLabel.BackgroundColor = [1 0.8 0.8];
                uialert(app.UIFigure, ME.message, '仿真失败', 'Icon', 'error');
            end
        end

        % Button pushed function: MatrixButton
        function MatrixButtonPushed(app, event)
            if app.isRunning
                return;
            end
            [accepted, axes, executionMode] = app.openMatrixDialog();
            if ~accepted
                return;
            end

            app.isRunning = true;
            app.RunButton.Enable = 'off';
            app.MatrixButton.Enable = 'off';
            cleanup = onCleanup(@() app.finishRun()); %#ok<NASGU>
            try
                [baseCase, ~] = app.collectSimCaseFromUi();
                baseCase = routeA_validate_case(baseCase);
                app.addLog(sprintf('> 矩阵运行: %s, %d x %d x %d x %d ...', ...
                    baseCase.controls.electrical.mode, ...
                    numel(axes.electricalCommand), numel(axes.cegrRatio), ...
                    numel(axes.targetOer), numel(axes.o2MoleFraction)));
                app.StatusLabel.Text = '状态: 矩阵仿真运行中';
                app.StatusLabel.BackgroundColor = [1 1 0.8];
                drawnow;
                tic;
                study = routeA_panel_run_matrix(baseCase, axes, executionMode);
                elapsed = toc;
                app.lastMatrixStudy = study;
                for idx = 1:study.caseCount
                    if study.cases(idx).passed
                        app.addResultToTable(study.cases(idx).results);
                    else
                        app.addLog(sprintf('  ✗ %s: %s', ...
                            study.cases(idx).caseId, study.cases(idx).errorMessage));
                    end
                end
                app.plotMatrixResults(study);
                app.addLog(sprintf('  ✓ 矩阵完成（%d cases，耗时 %.1f s）', ...
                    study.caseCount, elapsed));
                app.StatusLabel.Text = sprintf('状态: 矩阵完成 | PASS=%d/%d', ...
                    sum([study.cases.passed]), study.caseCount);
                if study.allPassed
                    app.StatusLabel.BackgroundColor = [0.8 1 0.8];
                else
                    app.StatusLabel.BackgroundColor = [1 0.8 0.8];
                end
            catch ME
                app.addLog(sprintf('  ✗ 矩阵失败: %s', ME.message));
                app.StatusLabel.Text = sprintf('状态: 矩阵失败 | %s', ME.message);
                app.StatusLabel.BackgroundColor = [1 0.8 0.8];
                uialert(app.UIFigure, ME.message, '矩阵失败', 'Icon', 'error');
            end
        end

        function [simCase, rampDuration] = collectSimCaseFromUi(app)
            simCase = routeA_simCase_template();
            simCase.caseId = app.CaseIdEditField.Value;
            advanced = strcmp(app.AdvancedPanel.Visible, 'on');
            if advanced
                mode = app.AdvancedBoundaryModeDropDown.Value;
                command = app.AdvancedBoundaryCommandEditField.Value;
                rampDuration = app.AdvancedRampDurationEditField.Value;
                oer = app.AdvancedOerEditField.Value;
                backpressure = app.AdvancedBackpressureEditField.Value;
                humidifierRH = app.AdvancedHumidifierRHEditField.Value;
                cegrRatio = app.AdvancedCegrRatioEditField.Value;
                cegrEnabled = app.AdvancedCegrEnabledCheckBox.Value;
                stopTime = app.AdvancedStopTimeEditField.Value;
                o2Fraction = app.AdvancedO2EditField.Value;
                h2oFraction = app.AdvancedH2OEditField.Value;
                simCase.controls.electrical.voltageController = struct( ...
                    'Kp_A_V', app.AdvancedKpEditField.Value, ...
                    'Ki_A_V_s', app.AdvancedKiEditField.Value, ...
                    'currentMin_A', app.AdvancedCurrentMinEditField.Value, ...
                    'currentMax_A', app.AdvancedCurrentMaxEditField.Value);
            else
                mode = app.BoundaryModeDropDown.Value;
                command = app.BoundaryCommandEditField.Value;
                rampDuration = app.RampDurationEditField.Value;
                oer = app.OerEditField.Value;
                backpressure = app.BackpressureEditField.Value;
                humidifierRH = app.HumidifierRHEditField.Value;
                cegrRatio = app.CegrRatioEditField.Value;
                cegrEnabled = app.CegrEnabledCheckBox.Value;
                stopTime = app.StopTimeEditField.Value;
                o2Fraction = simCase.controls.cathode.o2MoleFraction;
                h2oFraction = simCase.controls.cathode.h2oMoleFraction;
            end
            simCase.controls.electrical.mode = mode;
            simCase.controls.electrical.profile = command;
            simCase.controls.cathode.targetOer = oer;
            simCase.controls.cathode.outletPressure_MPa_abs = backpressure;
            simCase.controls.cathode.humidifierRH = humidifierRH;
            simCase.controls.cathode.o2MoleFraction = o2Fraction;
            simCase.controls.cathode.h2oMoleFraction = h2oFraction;
            simCase.controls.cegr.enabled = cegrEnabled;
            simCase.controls.cegr.targetRatio = cegrRatio;
            simCase.solver.stopTime_s = stopTime;
        end

        function [accepted, axes, executionMode] = openMatrixDialog(app)
            accepted = false;
            axes = struct();
            executionMode = 'serial';
            params = routeA_platform_default_parameters();
            if strcmp(app.AdvancedPanel.Visible, 'on')
                mode = string(app.AdvancedBoundaryModeDropDown.Value);
                defaultOer = app.AdvancedOerEditField.Value;
                defaultO2 = app.AdvancedO2EditField.Value;
                defaultCegr = app.AdvancedCegrRatioEditField.Value;
            else
                mode = string(app.BoundaryModeDropDown.Value);
                defaultOer = app.OerEditField.Value;
                defaultO2 = params.environment.o2_mole_fraction.value;
                defaultCegr = app.CegrRatioEditField.Value;
            end
            switch mode
                case "Current"
                    defaultCommand = params.controls.current_default_ref_A.value;
                case "Power"
                    defaultCommand = params.controls.power_default_ref_kW.value;
                case "Voltage"
                    defaultCommand = params.controls.voltage_default_ref_V.value;
            end
            dialog = uifigure('Name', 'Route A 矩阵运行', ...
                'Position', [450 300 430 300], 'WindowStyle', 'modal');
            grid = uigridlayout(dialog, [6 3]);
            grid.RowHeight = {22, 22, 22, 22, 22, 30};
            grid.ColumnWidth = {150, '1x', 80};
            labels = {'电边界命令', 'cEGR 比', '目标 OER', ...
                '入口 O2', '执行方式'};
            fields = cell(1, 5);
            defaults = {num2str(defaultCommand), ...
                sprintf('%g', defaultCegr), num2str(defaultOer), ...
                num2str(defaultO2), 'serial'};
            for idx = 1:4
                uilabel(grid, 'Text', labels{idx});
                fields{idx} = uieditfield(grid, 'text', ...
                    'Value', defaults{idx});
                fields{idx}.Layout.Column = [2 3];
                fields{idx}.Layout.Row = idx;
            end
            uilabel(grid, 'Text', labels{5});
            fields{5} = uidropdown(grid, 'Items', {'serial', 'parallel'}, ...
                'Value', 'serial');
            fields{5}.Layout.Column = [2 3];
            fields{5}.Layout.Row = 5;
            cancelButton = uibutton(grid, 'Text', '取消');
            cancelButton.Layout.Row = 6;
            cancelButton.Layout.Column = 2;
            runButton = uibutton(grid, 'Text', '运行矩阵', ...
                'ButtonPushedFcn', @acceptDialog);
            runButton.Layout.Row = 6;
            runButton.Layout.Column = 3;
            cancelButton.ButtonPushedFcn = @cancelDialog;
            dialog.CloseRequestFcn = @cancelDialog;
            uiwait(dialog);
            if isvalid(dialog)
                delete(dialog);
            end

            function acceptDialog(~, ~)
                try
                    axes.electricalCommand = app.parseNumericVector(fields{1}.Value);
                    axes.cegrRatio = app.parseNumericVector(fields{2}.Value);
                    axes.targetOer = app.parseNumericVector(fields{3}.Value);
                    axes.o2MoleFraction = app.parseNumericVector(fields{4}.Value);
                    executionMode = fields{5}.Value;
                    accepted = true;
                    uiresume(dialog);
                catch ME
                    uialert(dialog, ME.message, '矩阵输入无效', 'Icon', 'error');
                end
            end

            function cancelDialog(~, ~)
                accepted = false;
                uiresume(dialog);
            end
        end

        function values = parseNumericVector(~, textValue)
            if isnumeric(textValue)
                values = textValue;
            else
                tokens = split(strtrim(strrep(string(textValue), ',', ' ')));
                tokens(tokens == "") = [];
                values = str2double(tokens);
            end
            if isempty(values) || ~isvector(values) || ...
                    any(~isfinite(values))
                error('RouteA:PanelMatrixVector', ...
                    '请输入由空格或逗号分隔的有限数值向量。');
            end
            values = values(:).';
        end

        function finishRun(app)
            if isvalid(app.RunButton)
                app.RunButton.Enable = 'on';
            end
            if isvalid(app.MatrixButton)
                app.MatrixButton.Enable = 'on';
            end
            app.isRunning = false;
        end

        % Helper: Add log entry
        function addLog(app, text)
            currentLog = app.LogTextArea.Value;
            newLog = [currentLog; {text}];
            % Keep last 20 lines
            if numel(newLog) > 20
                newLog = newLog(end-19:end);
            end
            app.LogTextArea.Value = newLog;
            drawnow;
        end

        % Helper: Add result to KPI table
        function addResultToTable(app, results)
            % Get current table data
            currentData = app.KpiTable.Data;

            % Create new row
            newRow = {results.caseId, ...
                      sprintf('%.2f', results.voltage_V), ...
                      sprintf('%.2f', results.current_A), ...
                      sprintf('%.2f', results.power_kW), ...
                      sprintf('%.2f', results.oer), ...
                      sprintf('%.3f', results.cegr_ratio)};

            % Append to table
            if isempty(currentData)
                app.KpiTable.Data = newRow;
            else
                app.KpiTable.Data = [currentData; newRow];
            end
        end

        % Helper: Plot time series
        function plotTimeSeries(app, results)
            cla(app.TimeSeriesAxes);
            hold(app.TimeSeriesAxes, 'on');

            % Plot voltage (left axis)
            yyaxis(app.TimeSeriesAxes, 'left');
            plot(app.TimeSeriesAxes, results.voltage_ts.Time, results.voltage_ts.Data, ...
                'b-', 'LineWidth', 1.5, 'DisplayName', '电压');
            ylabel(app.TimeSeriesAxes, '电压 (V)');
            app.TimeSeriesAxes.YColor = 'b';

            % Plot current and power (right axis)
            yyaxis(app.TimeSeriesAxes, 'right');
            plot(app.TimeSeriesAxes, results.current_ts.Time, results.current_ts.Data, ...
                'r-', 'LineWidth', 1.5, 'DisplayName', '电流');
            plot(app.TimeSeriesAxes, results.power_ts.Time, results.power_ts.Data, ...
                'g-', 'LineWidth', 1.5, 'DisplayName', '功率');
            ylabel(app.TimeSeriesAxes, '电流 (A) / 功率 (kW)');
            app.TimeSeriesAxes.YColor = 'r';

            xlabel(app.TimeSeriesAxes, '时间 (s)');
            title(app.TimeSeriesAxes, sprintf('时序曲线 - %s', results.caseId));
            legend(app.TimeSeriesAxes, 'Location', 'best');
            grid(app.TimeSeriesAxes, 'on');
            hold(app.TimeSeriesAxes, 'off');
        end

        function plotMatrixResults(app, study)
            cla(app.TimeSeriesAxes);
            hold(app.TimeSeriesAxes, 'on');
            yyaxis(app.TimeSeriesAxes, 'left');
            for idx = 1:study.caseCount
                if ~study.cases(idx).passed
                    continue;
                end
                result = study.cases(idx).results;
                plot(app.TimeSeriesAxes, result.voltage_ts.Time, ...
                    result.voltage_ts.Data, 'DisplayName', ...
                    char(study.cases(idx).caseId));
            end
            ylabel(app.TimeSeriesAxes, '电压 (V)');
            yyaxis(app.TimeSeriesAxes, 'right');
            ylabel(app.TimeSeriesAxes, '电流 (A) / 功率 (kW)');
            xlabel(app.TimeSeriesAxes, '时间 (s)');
            title(app.TimeSeriesAxes, '矩阵电压对比');
            legend(app.TimeSeriesAxes, 'Location', 'best');
            grid(app.TimeSeriesAxes, 'on');
            hold(app.TimeSeriesAxes, 'off');
        end
    end

    % Component initialization
    methods (Access = private)

        function createComponents(app)
            % Create UIFigure and components
            params = routeA_platform_default_parameters();
            
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1200 700];
            app.UIFigure.Name = 'Route A cEGR-PEMFC 仿真平台';
            app.UIFigure.Color = [0.94 0.94 0.94];
            
            % Status bar
            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.Position = [10 10 1180 25];
            app.StatusLabel.Text = '状态: 就绪 | 模型: PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01 | 参数源: platform_default';
            app.StatusLabel.FontSize = 11;
            app.StatusLabel.BackgroundColor = [0.9 0.9 0.9];
            
            % Left panel
            app.LeftPanel = uipanel(app.UIFigure);
            app.LeftPanel.Title = '参数设置';
            app.LeftPanel.Position = [10 50 480 620];
            app.LeftPanel.BackgroundColor = [0.94 0.94 0.94];
            
            % Right panel
            app.RightPanel = uipanel(app.UIFigure);
            app.RightPanel.Title = '结果展示';
            app.RightPanel.Position = [500 50 690 620];
            app.RightPanel.BackgroundColor = [0.94 0.94 0.94];
            
            % Mode toggle
            app.ModeButtonGroup = uibuttongroup(app.LeftPanel);
            app.ModeButtonGroup.Position = [320 580 140 30];
            app.ModeButtonGroup.BorderType = 'none';
            app.ModeButtonGroup.BackgroundColor = [0.94 0.94 0.94];
            
            app.BasicModeButton = uitogglebutton(app.ModeButtonGroup);
            app.BasicModeButton.Text = '基础';
            app.BasicModeButton.Position = [0 0 70 30];
            app.BasicModeButton.Value = true;
            
            app.AdvancedModeButton = uitogglebutton(app.ModeButtonGroup);
            app.AdvancedModeButton.Text = '高级';
            app.AdvancedModeButton.Position = [70 0 70 30];
            app.ModeButtonGroup.SelectionChangedFcn = ...
                createCallbackFcn(app, @ModeSelectionChanged, true);
            
            % Electrical boundary panel
            app.ElectricalPanel = uipanel(app.LeftPanel);
            app.ElectricalPanel.Title = '电边界';
            app.ElectricalPanel.Position = [10 440 450 100];
            app.ElectricalPanel.BackgroundColor = [1 1 1];
            
            app.BoundaryModeLabel = uilabel(app.ElectricalPanel);
            app.BoundaryModeLabel.Position = [10 55 80 22];
            app.BoundaryModeLabel.Text = '模式:';
            
            app.BoundaryModeDropDown = uidropdown(app.ElectricalPanel);
            app.BoundaryModeDropDown.Items = {'Current', 'Power', 'Voltage'};
            app.BoundaryModeDropDown.Value = 'Current';
            app.BoundaryModeDropDown.Position = [90 55 120 22];
            app.BoundaryModeDropDown.ValueChangedFcn = ...
                createCallbackFcn(app, @BoundaryModeChanged, true);
            
            app.BoundaryCommandLabel = uilabel(app.ElectricalPanel);
            app.BoundaryCommandLabel.Position = [220 55 80 22];
            app.BoundaryCommandLabel.Text = '命令值:';
            
            app.BoundaryCommandEditField = uieditfield(app.ElectricalPanel, 'numeric');
            app.BoundaryCommandEditField.Position = [300 55 80 22];
            app.BoundaryCommandEditField.Value = ...
                params.controls.current_default_ref_A.value;
            
            app.BoundaryUnitLabel = uilabel(app.ElectricalPanel);
            app.BoundaryUnitLabel.Position = [385 55 40 22];
            app.BoundaryUnitLabel.Text = 'A';
            
            app.RampDurationLabel = uilabel(app.ElectricalPanel);
            app.RampDurationLabel.Position = [10 20 80 22];
            app.RampDurationLabel.Text = '斜坡时间:';
            
            app.RampDurationEditField = uieditfield(app.ElectricalPanel, 'numeric');
            app.RampDurationEditField.Position = [90 20 80 22];
            app.RampDurationEditField.Value = ...
                params.numerics.startupRampDuration_s.value;
            
            app.RampUnitLabel = uilabel(app.ElectricalPanel);
            app.RampUnitLabel.Position = [175 20 20 22];
            app.RampUnitLabel.Text = 's';
            
            % Air path panel
            app.AirPathPanel = uipanel(app.LeftPanel);
            app.AirPathPanel.Title = '气路';
            app.AirPathPanel.Position = [10 320 450 110];
            app.AirPathPanel.BackgroundColor = [1 1 1];
            
            app.OerLabel = uilabel(app.AirPathPanel);
            app.OerLabel.Position = [10 65 100 22];
            app.OerLabel.Text = 'OER:';
            
            app.OerEditField = uieditfield(app.AirPathPanel, 'numeric');
            app.OerEditField.Position = [110 65 100 22];
            app.OerEditField.Value = params.controls.target_oer.value;
            
            app.BackpressureLabel = uilabel(app.AirPathPanel);
            app.BackpressureLabel.Position = [10 35 100 22];
            app.BackpressureLabel.Text = '背压 (MPa):';
            
            app.BackpressureEditField = uieditfield(app.AirPathPanel, 'numeric');
            app.BackpressureEditField.Position = [110 35 100 22];
            app.BackpressureEditField.Value = ...
                params.controls.backpressure_MPa_abs.value;
            
            app.HumidifierRHLabel = uilabel(app.AirPathPanel);
            app.HumidifierRHLabel.Position = [10 5 100 22];
            app.HumidifierRHLabel.Text = '加湿器 RH:';
            
            app.HumidifierRHEditField = uieditfield(app.AirPathPanel, 'numeric');
            app.HumidifierRHEditField.Position = [110 5 100 22];
            app.HumidifierRHEditField.Value = ...
                params.cathode.humidifier.default_rh.value;
            
            % cEGR panel
            app.CegrPanel = uipanel(app.LeftPanel);
            app.CegrPanel.Title = 'cEGR';
            app.CegrPanel.Position = [10 230 450 80];
            app.CegrPanel.BackgroundColor = [1 1 1];
            
            app.CegrRatioLabel = uilabel(app.CegrPanel);
            app.CegrRatioLabel.Position = [10 35 100 22];
            app.CegrRatioLabel.Text = '目标比例:';
            
            app.CegrRatioEditField = uieditfield(app.CegrPanel, 'numeric');
            app.CegrRatioEditField.Position = [110 35 100 22];
            app.CegrRatioEditField.Value = params.controls.cegr_target_ratio.value;
            
            app.CegrEnabledCheckBox = uicheckbox(app.CegrPanel);
            app.CegrEnabledCheckBox.Text = '启用 cEGR';
            app.CegrEnabledCheckBox.Position = [10 5 100 22];
            app.CegrEnabledCheckBox.Value = logical(params.controls.cegr_enabled.value);
            
            % Solver panel
            app.SolverPanel = uipanel(app.LeftPanel);
            app.SolverPanel.Title = '求解器';
            app.SolverPanel.Position = [10 160 450 60];
            app.SolverPanel.BackgroundColor = [1 1 1];
            
            app.StopTimeLabel = uilabel(app.SolverPanel);
            app.StopTimeLabel.Position = [10 15 100 22];
            app.StopTimeLabel.Text = '仿真时长 (s):';
            
            app.StopTimeEditField = uieditfield(app.SolverPanel, 'numeric');
            app.StopTimeEditField.Position = [110 15 100 22];
            app.StopTimeEditField.Value = params.numerics.stopTime_s.value;

            % Advanced panel. It replaces the compact panels while selected,
            % keeping one active source for every field used by Run.
            app.AdvancedPanel = uipanel(app.LeftPanel);
            app.AdvancedPanel.Title = '高级参数';
            app.AdvancedPanel.Position = [10 140 450 400];
            app.AdvancedPanel.BackgroundColor = [1 1 1];
            app.AdvancedPanel.Visible = 'off';

            app.AdvancedBoundaryModeLabel = uilabel(app.AdvancedPanel);
            app.AdvancedBoundaryModeLabel.Position = [10 355 70 22];
            app.AdvancedBoundaryModeLabel.Text = '电模式:';
            app.AdvancedBoundaryModeDropDown = uidropdown(app.AdvancedPanel);
            app.AdvancedBoundaryModeDropDown.Items = {'Current', 'Power', 'Voltage'};
            app.AdvancedBoundaryModeDropDown.Value = 'Current';
            app.AdvancedBoundaryModeDropDown.Position = [80 355 100 22];
            app.AdvancedBoundaryModeDropDown.ValueChangedFcn = ...
                createCallbackFcn(app, @AdvancedBoundaryModeChanged, true);

            app.AdvancedBoundaryCommandLabel = uilabel(app.AdvancedPanel);
            app.AdvancedBoundaryCommandLabel.Position = [195 355 65 22];
            app.AdvancedBoundaryCommandLabel.Text = '命令:';
            app.AdvancedBoundaryCommandEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedBoundaryCommandEditField.Position = [260 355 80 22];
            app.AdvancedBoundaryCommandEditField.Value = ...
                params.controls.current_default_ref_A.value;
            app.AdvancedBoundaryUnitLabel = uilabel(app.AdvancedPanel);
            app.AdvancedBoundaryUnitLabel.Position = [345 355 45 22];
            app.AdvancedBoundaryUnitLabel.Text = 'A';

            app.AdvancedRampDurationLabel = uilabel(app.AdvancedPanel);
            app.AdvancedRampDurationLabel.Position = [10 320 70 22];
            app.AdvancedRampDurationLabel.Text = '斜坡 (s):';
            app.AdvancedRampDurationEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedRampDurationEditField.Position = [80 320 100 22];
            app.AdvancedRampDurationEditField.Value = ...
                params.numerics.startupRampDuration_s.value;

            app.AdvancedOerLabel = uilabel(app.AdvancedPanel);
            app.AdvancedOerLabel.Position = [195 320 65 22];
            app.AdvancedOerLabel.Text = 'OER:';
            app.AdvancedOerEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedOerEditField.Position = [260 320 100 22];
            app.AdvancedOerEditField.Value = params.controls.target_oer.value;

            app.AdvancedBackpressureLabel = uilabel(app.AdvancedPanel);
            app.AdvancedBackpressureLabel.Position = [10 285 100 22];
            app.AdvancedBackpressureLabel.Text = '背压 (MPa):';
            app.AdvancedBackpressureEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedBackpressureEditField.Position = [110 285 100 22];
            app.AdvancedBackpressureEditField.Value = ...
                params.controls.backpressure_MPa_abs.value;
            app.AdvancedHumidifierRHLabel = uilabel(app.AdvancedPanel);
            app.AdvancedHumidifierRHLabel.Position = [225 285 100 22];
            app.AdvancedHumidifierRHLabel.Text = '阴极 RH:';
            app.AdvancedHumidifierRHEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedHumidifierRHEditField.Position = [325 285 80 22];
            app.AdvancedHumidifierRHEditField.Value = ...
                params.cathode.humidifier.default_rh.value;

            app.AdvancedCegrRatioLabel = uilabel(app.AdvancedPanel);
            app.AdvancedCegrRatioLabel.Position = [10 250 100 22];
            app.AdvancedCegrRatioLabel.Text = 'cEGR 比:';
            app.AdvancedCegrRatioEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedCegrRatioEditField.Position = [110 250 100 22];
            app.AdvancedCegrRatioEditField.Value = ...
                params.controls.cegr_target_ratio.value;
            app.AdvancedCegrEnabledCheckBox = uicheckbox(app.AdvancedPanel);
            app.AdvancedCegrEnabledCheckBox.Text = '启用 cEGR';
            app.AdvancedCegrEnabledCheckBox.Position = [225 250 110 22];
            app.AdvancedCegrEnabledCheckBox.Value = ...
                logical(params.controls.cegr_enabled.value);

            app.AdvancedStopTimeLabel = uilabel(app.AdvancedPanel);
            app.AdvancedStopTimeLabel.Position = [10 215 100 22];
            app.AdvancedStopTimeLabel.Text = '时长 (s):';
            app.AdvancedStopTimeEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedStopTimeEditField.Position = [110 215 100 22];
            app.AdvancedStopTimeEditField.Value = params.numerics.stopTime_s.value;
            app.AdvancedO2Label = uilabel(app.AdvancedPanel);
            app.AdvancedO2Label.Position = [225 215 45 22];
            app.AdvancedO2Label.Text = 'O2:';
            app.AdvancedO2EditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedO2EditField.Position = [270 215 80 22];
            app.AdvancedO2EditField.Value = params.environment.o2_mole_fraction.value;

            app.AdvancedH2OLabel = uilabel(app.AdvancedPanel);
            app.AdvancedH2OLabel.Position = [10 180 100 22];
            app.AdvancedH2OLabel.Text = 'H2O:';
            app.AdvancedH2OEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedH2OEditField.Position = [110 180 100 22];
            app.AdvancedH2OEditField.Value = params.environment.h2o_mole_fraction.value;

            app.AdvancedKpLabel = uilabel(app.AdvancedPanel);
            app.AdvancedKpLabel.Position = [225 180 45 22];
            app.AdvancedKpLabel.Text = 'Kp:';
            app.AdvancedKpEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedKpEditField.Position = [270 180 80 22];
            app.AdvancedKpEditField.Value = params.controls.voltage_pi_Kp.value;

            app.AdvancedKiLabel = uilabel(app.AdvancedPanel);
            app.AdvancedKiLabel.Position = [10 145 100 22];
            app.AdvancedKiLabel.Text = 'Ki:';
            app.AdvancedKiEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedKiEditField.Position = [110 145 100 22];
            app.AdvancedKiEditField.Value = params.controls.voltage_pi_Ki.value;
            app.AdvancedCurrentMinLabel = uilabel(app.AdvancedPanel);
            app.AdvancedCurrentMinLabel.Position = [225 145 45 22];
            app.AdvancedCurrentMinLabel.Text = 'I min:';
            app.AdvancedCurrentMinEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedCurrentMinEditField.Position = [270 145 80 22];
            app.AdvancedCurrentMinEditField.Value = ...
                params.controls.voltage_current_min_A.value;

            app.AdvancedCurrentMaxLabel = uilabel(app.AdvancedPanel);
            app.AdvancedCurrentMaxLabel.Position = [10 110 100 22];
            app.AdvancedCurrentMaxLabel.Text = 'I max (A):';
            app.AdvancedCurrentMaxEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedCurrentMaxEditField.Position = [110 110 100 22];
            app.AdvancedCurrentMaxEditField.Value = ...
                params.controls.voltage_current_max_A.value;
            
            % Case ID
            app.CaseIdLabel = uilabel(app.LeftPanel);
            app.CaseIdLabel.Position = [10 125 100 22];
            app.CaseIdLabel.Text = 'Case ID:';
            
            app.CaseIdEditField = uieditfield(app.LeftPanel, 'text');
            app.CaseIdEditField.Position = [110 125 200 22];
            app.CaseIdEditField.Value = 'case1';
            
            % Buttons
            app.RunButton = uibutton(app.LeftPanel, 'push');
            app.RunButton.Position = [10 80 150 30];
            app.RunButton.Text = '运行单工况';
            app.RunButton.FontSize = 12;
            app.RunButton.FontWeight = 'bold';
            app.RunButton.BackgroundColor = [0.2 0.6 0.2];
            app.RunButton.FontColor = [1 1 1];
            app.RunButton.ButtonPushedFcn = createCallbackFcn(app, @RunButtonPushed, true);

            app.MatrixButton = uibutton(app.LeftPanel, 'push');
            app.MatrixButton.Position = [170 80 100 30];
            app.MatrixButton.Text = '矩阵...';
            app.MatrixButton.FontSize = 12;
            app.MatrixButton.ButtonPushedFcn = createCallbackFcn(app, @MatrixButtonPushed, true);
            
            % KPI table
            app.KpiTable = uitable(app.RightPanel);
            app.KpiTable.Position = [10 400 670 200];
            app.KpiTable.ColumnName = {'caseId', 'V (V)', 'I (A)', 'P (kW)', 'OER', 'cEGR'};
            app.KpiTable.ColumnWidth = {100, 80, 80, 80, 60, 60};
            app.KpiTable.Data = {};
            
            % Time series axes
            app.TimeSeriesAxes = uiaxes(app.RightPanel);
            app.TimeSeriesAxes.Position = [10 180 670 200];
            title(app.TimeSeriesAxes, '时序曲线');
            xlabel(app.TimeSeriesAxes, '时间 (s)');
            ylabel(app.TimeSeriesAxes, '电压 (V) / 电流 (A) / 功率 (kW)');
            grid(app.TimeSeriesAxes, 'on');
            
            % Log area
            app.LogLabel = uilabel(app.RightPanel);
            app.LogLabel.Position = [10 150 100 22];
            app.LogLabel.Text = '运行日志:';
            
            app.LogTextArea = uitextarea(app.RightPanel);
            app.LogTextArea.Position = [10 10 670 130];
            app.LogTextArea.Value = {' > 面板已就绪，请设置参数并点击"运行单工况"'};
            app.LogTextArea.Editable = 'off';
            app.LogTextArea.FontName = 'Consolas';
            
            % Show figure after all components are created
            app.UIFigure.Visible = 'on';
        end

        function BoundaryModeChanged(app, event)
            mode = string(app.BoundaryModeDropDown.Value);
            params = routeA_platform_default_parameters();
            switch mode
                case "Current"
                    app.BoundaryCommandEditField.Value = ...
                        params.controls.current_default_ref_A.value;
                    app.BoundaryUnitLabel.Text = 'A';
                case "Power"
                    app.BoundaryCommandEditField.Value = ...
                        params.controls.power_default_ref_kW.value;
                    app.BoundaryUnitLabel.Text = 'kW';
                case "Voltage"
                    app.BoundaryCommandEditField.Value = ...
                        params.controls.voltage_default_ref_V.value;
                    app.BoundaryUnitLabel.Text = 'V';
            end
            if isvalid(app.AdvancedPanel)
                app.syncBasicToAdvanced();
            end
        end

        function AdvancedBoundaryModeChanged(app, event)
            mode = string(app.AdvancedBoundaryModeDropDown.Value);
            params = routeA_platform_default_parameters();
            switch mode
                case "Current"
                    app.AdvancedBoundaryCommandEditField.Value = ...
                        params.controls.current_default_ref_A.value;
                    app.AdvancedBoundaryUnitLabel.Text = 'A';
                case "Power"
                    app.AdvancedBoundaryCommandEditField.Value = ...
                        params.controls.power_default_ref_kW.value;
                    app.AdvancedBoundaryUnitLabel.Text = 'kW';
                case "Voltage"
                    app.AdvancedBoundaryCommandEditField.Value = ...
                        params.controls.voltage_default_ref_V.value;
                    app.AdvancedBoundaryUnitLabel.Text = 'V';
            end
        end

        function ModeSelectionChanged(app, event)
            advanced = isequal(event.NewValue, app.AdvancedModeButton);
            if advanced
                app.syncBasicToAdvanced();
                app.ElectricalPanel.Visible = 'off';
                app.AirPathPanel.Visible = 'off';
                app.CegrPanel.Visible = 'off';
                app.SolverPanel.Visible = 'off';
                app.AdvancedPanel.Visible = 'on';
            else
                app.syncAdvancedToBasic();
                app.AdvancedPanel.Visible = 'off';
                app.ElectricalPanel.Visible = 'on';
                app.AirPathPanel.Visible = 'on';
                app.CegrPanel.Visible = 'on';
                app.SolverPanel.Visible = 'on';
            end
        end

        function syncBasicToAdvanced(app)
            app.AdvancedBoundaryModeDropDown.Value = app.BoundaryModeDropDown.Value;
            app.AdvancedBoundaryCommandEditField.Value = ...
                app.BoundaryCommandEditField.Value;
            app.AdvancedRampDurationEditField.Value = ...
                app.RampDurationEditField.Value;
            app.AdvancedOerEditField.Value = app.OerEditField.Value;
            app.AdvancedBackpressureEditField.Value = ...
                app.BackpressureEditField.Value;
            app.AdvancedHumidifierRHEditField.Value = ...
                app.HumidifierRHEditField.Value;
            app.AdvancedCegrRatioEditField.Value = app.CegrRatioEditField.Value;
            app.AdvancedCegrEnabledCheckBox.Value = app.CegrEnabledCheckBox.Value;
            app.AdvancedStopTimeEditField.Value = app.StopTimeEditField.Value;
            sc = routeA_simCase_template();
            app.AdvancedO2EditField.Value = sc.controls.cathode.o2MoleFraction;
            app.AdvancedH2OEditField.Value = sc.controls.cathode.h2oMoleFraction;
            app.AdvancedBoundaryUnitLabel.Text = app.BoundaryUnitLabel.Text;
        end

        function syncAdvancedToBasic(app)
            app.BoundaryModeDropDown.Value = app.AdvancedBoundaryModeDropDown.Value;
            app.BoundaryCommandEditField.Value = ...
                app.AdvancedBoundaryCommandEditField.Value;
            app.RampDurationEditField.Value = app.AdvancedRampDurationEditField.Value;
            app.OerEditField.Value = app.AdvancedOerEditField.Value;
            app.BackpressureEditField.Value = app.AdvancedBackpressureEditField.Value;
            app.HumidifierRHEditField.Value = ...
                app.AdvancedHumidifierRHEditField.Value;
            app.CegrRatioEditField.Value = app.AdvancedCegrRatioEditField.Value;
            app.CegrEnabledCheckBox.Value = app.AdvancedCegrEnabledCheckBox.Value;
            app.StopTimeEditField.Value = app.AdvancedStopTimeEditField.Value;
            app.BoundaryUnitLabel.Text = app.AdvancedBoundaryUnitLabel.Text;
        end
    end
    
    % App creation and deletion
    methods (Access = public)
        
        function app = RouteA_Panel_v01
            % Create UIFigure and components
            createComponents(app)
            
            % Initialize simCase with template
            app.simCase = routeA_simCase_template();
            app.simCase.caseId = app.CaseIdEditField.Value;
            app.BoundaryCommandEditField.Value = ...
                routeA_platform_default_parameters().controls.current_default_ref_A.value;
        end
        
        function delete(app)
            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
