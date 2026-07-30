classdef RouteA_Panel_v01 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        NavigationPanel             matlab.ui.container.Panel
        DomainNavigationListBox     matlab.ui.control.ListBox
        DomainNavigationStatusLabel matlab.ui.control.Label
        LeftPanel                   matlab.ui.container.Panel
        ConfigScrollPanel           matlab.ui.container.Panel
        ConfigCanvas                matlab.ui.container.Panel
        RightPanel                  matlab.ui.container.Panel
        HeaderTitleLabel            matlab.ui.control.Label
        HeaderMetaLabel             matlab.ui.control.Label
        StatusLabel                 matlab.ui.control.Label
        
        % Mode toggle
        ModeButtonGroup             matlab.ui.container.ButtonGroup
        BasicModeButton             matlab.ui.control.ToggleButton
        AdvancedModeButton          matlab.ui.control.ToggleButton
        ModelParameterModeButton    matlab.ui.control.ToggleButton
        HelpModeButton              matlab.ui.control.ToggleButton
        
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
        AirControlModeLabel         matlab.ui.control.Label
        AirControlModeDropDown      matlab.ui.control.DropDown
        OerLabel                    matlab.ui.control.Label
        OerEditField                matlab.ui.control.NumericEditField
        TargetMdotLabel             matlab.ui.control.Label
        TargetMdotEditField         matlab.ui.control.NumericEditField
        DirectCommandLabel          matlab.ui.control.Label
        DirectCommandEditField      matlab.ui.control.NumericEditField
        BackpressureLabel           matlab.ui.control.Label
        BackpressureEditField       matlab.ui.control.NumericEditField
        HumidifierRHLabel           matlab.ui.control.Label
        HumidifierRHEditField       matlab.ui.control.NumericEditField
        SourceTemperatureLabel       matlab.ui.control.Label
        SourceTemperatureEditField   matlab.ui.control.NumericEditField
        HumidifierEnabledCheckBox   matlab.ui.control.CheckBox
        
        % cEGR
        CegrPanel                   matlab.ui.container.Panel
        CegrRatioLabel              matlab.ui.control.Label
        CegrRatioEditField          matlab.ui.control.NumericEditField
        CegrEnabledCheckBox         matlab.ui.control.CheckBox
        
        % Solver
        SolverPanel                 matlab.ui.container.Panel
        StopTimeLabel               matlab.ui.control.Label
        StopTimeEditField           matlab.ui.control.NumericEditField

        % Thermal boundary
        ThermalPanel                matlab.ui.container.Panel
        StackTemperatureLabel       matlab.ui.control.Label
        StackTemperatureEditField   matlab.ui.control.NumericEditField
        FutureDomainsPanel          matlab.ui.container.Panel
        AnodeSourcePressureEditField       matlab.ui.control.NumericEditField
        AnodeSourceTemperatureEditField    matlab.ui.control.NumericEditField
        AnodeH2EditField                   matlab.ui.control.NumericEditField
        AnodeInletPressureEditField        matlab.ui.control.NumericEditField
        AnodeHumidifierRHEditField         matlab.ui.control.NumericEditField
        AnodeRecirculationBaseEditField    matlab.ui.control.NumericEditField
        AnodeRecirculationGainEditField    matlab.ui.control.NumericEditField
        AnodePurgeEnabledCheckBox          matlab.ui.control.CheckBox
        AnodePurgeOnN2EditField            matlab.ui.control.NumericEditField
        AnodePurgeOffN2EditField           matlab.ui.control.NumericEditField
        AnodeControlStatusLabel            matlab.ui.control.Label
        ParameterCatalogIntroLabel         matlab.ui.control.Label
        ParameterCatalogTable              matlab.ui.control.Table
        ParameterCatalogStatusLabel        matlab.ui.control.Label

        % Advanced controls
        AdvancedPanel                       matlab.ui.container.Panel
        HelpPanel                           matlab.ui.container.Panel
        HelpTextArea                        matlab.ui.control.TextArea
        AdvancedBoundaryModeLabel          matlab.ui.control.Label
        AdvancedBoundaryModeDropDown       matlab.ui.control.DropDown
        AdvancedBoundaryCommandLabel       matlab.ui.control.Label
        AdvancedBoundaryCommandEditField   matlab.ui.control.NumericEditField
        AdvancedBoundaryUnitLabel           matlab.ui.control.Label
        AdvancedRampDurationLabel           matlab.ui.control.Label
        AdvancedRampDurationEditField       matlab.ui.control.NumericEditField
        AdvancedAirControlModeLabel         matlab.ui.control.Label
        AdvancedAirControlModeDropDown      matlab.ui.control.DropDown
        AdvancedOerLabel                    matlab.ui.control.Label
        AdvancedOerEditField                matlab.ui.control.NumericEditField
        AdvancedTargetMdotLabel             matlab.ui.control.Label
        AdvancedTargetMdotEditField         matlab.ui.control.NumericEditField
        AdvancedDirectCommandLabel          matlab.ui.control.Label
        AdvancedDirectCommandEditField      matlab.ui.control.NumericEditField
        AdvancedSourcePressureLabel         matlab.ui.control.Label
        AdvancedSourcePressureEditField     matlab.ui.control.NumericEditField
        AdvancedSourceTemperatureLabel      matlab.ui.control.Label
        AdvancedSourceTemperatureEditField  matlab.ui.control.NumericEditField
        AdvancedBackpressureLabel           matlab.ui.control.Label
        AdvancedBackpressureEditField       matlab.ui.control.NumericEditField
        AdvancedHumidifierRHLabel           matlab.ui.control.Label
        AdvancedHumidifierRHEditField       matlab.ui.control.NumericEditField
        AdvancedHumidifierEnabledCheckBox   matlab.ui.control.CheckBox
        AdvancedCegrRatioLabel              matlab.ui.control.Label
        AdvancedCegrRatioEditField          matlab.ui.control.NumericEditField
        AdvancedCegrEnabledCheckBox         matlab.ui.control.CheckBox
        AdvancedStopTimeLabel               matlab.ui.control.Label
        AdvancedStopTimeEditField           matlab.ui.control.NumericEditField
        AdvancedSolverLabel                 matlab.ui.control.Label
        AdvancedSolverDropDown              matlab.ui.control.DropDown
        AdvancedRelTolLabel                 matlab.ui.control.Label
        AdvancedRelTolEditField             matlab.ui.control.NumericEditField
        AdvancedAbsTolLabel                 matlab.ui.control.Label
        AdvancedAbsTolEditField             matlab.ui.control.NumericEditField
        AdvancedMaxStepLabel                matlab.ui.control.Label
        AdvancedMaxStepEditField            matlab.ui.control.NumericEditField
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
        AdvancedCegrValveModeLabel          matlab.ui.control.Label
        AdvancedCegrValveModeDropDown       matlab.ui.control.DropDown
        AdvancedCegrControlModeLabel        matlab.ui.control.Label
        AdvancedCegrControlModeDropDown     matlab.ui.control.DropDown
        AdvancedCegrTargetInputModeLabel    matlab.ui.control.Label
        AdvancedCegrTargetInputModeDropDown matlab.ui.control.DropDown
        AdvancedStackTemperatureLabel       matlab.ui.control.Label
        AdvancedStackTemperatureEditField   matlab.ui.control.NumericEditField
        AdvancedPerformanceStatusLabel      matlab.ui.control.Label
        AdvancedCegrKpLabel                  matlab.ui.control.Label
        AdvancedCegrKpEditField              matlab.ui.control.NumericEditField
        AdvancedCegrKiLabel                  matlab.ui.control.Label
        AdvancedCegrKiEditField              matlab.ui.control.NumericEditField
        AdvancedCegrActuatorTauLabel         matlab.ui.control.Label
        AdvancedCegrActuatorTauEditField     matlab.ui.control.NumericEditField
        AdvancedStackNumCellsLabel           matlab.ui.control.Label
        AdvancedStackNumCellsEditField       matlab.ui.control.NumericEditField
        AdvancedStackAreaLabel               matlab.ui.control.Label
        AdvancedStackAreaEditField           matlab.ui.control.NumericEditField
        AdvancedStackILabel                  matlab.ui.control.Label
        AdvancedStackIEditField              matlab.ui.control.NumericEditField
        AdvancedStackIoLabel                 matlab.ui.control.Label
        AdvancedStackIoEditField             matlab.ui.control.NumericEditField
        
        % Case ID
        CaseIdLabel                 matlab.ui.control.Label
        CaseIdEditField             matlab.ui.control.EditField
        
        % Buttons
        RunButton                   matlab.ui.control.Button
        MatrixButton                matlab.ui.control.Button
        ClearResultsButton          matlab.ui.control.Button
        OutputLevelLabel            matlab.ui.control.Label
        OutputLevelDropDown         matlab.ui.control.DropDown
        ExportButton                matlab.ui.control.Button

        % Results
        ResultTabGroup              matlab.ui.container.TabGroup
        OverviewTab                 matlab.ui.container.Tab
        CathodeResultTab            matlab.ui.container.Tab
        CegrResultTab               matlab.ui.container.Tab
        ThermalWaterResultTab       matlab.ui.container.Tab
        TraceTab                    matlab.ui.container.Tab
        DiagnosticsTab              matlab.ui.container.Tab
        DomainStatusTable            matlab.ui.control.Table
        KpiTable                    matlab.ui.control.Table
        OverviewSummaryTextArea      matlab.ui.control.TextArea
        CathodeResultTable           matlab.ui.control.Table
        CegrResultTable              matlab.ui.control.Table
        ThermalWaterResultTable      matlab.ui.control.Table
        DiagnosticsTable             matlab.ui.control.Table
        TimeSeriesAxes              matlab.ui.control.UIAxes
        PlotModeButtonGroup          matlab.ui.container.ButtonGroup
        CurrentPlotButton            matlab.ui.control.ToggleButton
        PowerPlotButton              matlab.ui.control.ToggleButton
        VoltagePlotButton            matlab.ui.control.ToggleButton
        ClearPlotHistoryButton       matlab.ui.control.Button
        LogLabel                    matlab.ui.control.Label
        LogTextArea                 matlab.ui.control.TextArea
    end
    
    % App state properties
    properties (Access = private)
        simCase  % Current simCase struct
        isRunning = false
        activeConfigMode = "basic"
        lastMatrixStudy = struct()
        lastResults = struct()
        plotHistory = struct('caseId', {}, 'voltage_ts', {}, ...
            'current_ts', {}, 'power_ts', {})
        plotMetric = "current"
        platformPaths
    end
    
    % Callbacks (public for testing)
    methods (Access = public)

        % Button pushed function: RunButton
        function RunButtonPushed(app, ~)
            if app.isRunning
                return;
            end
            app.isRunning = true;
            app.setInputEnabled(false);
            cleanup = onCleanup(@() app.finishRun());
            try
                [app.simCase, rampDuration] = app.collectSimCaseFromUi();

                % Validate
                app.addLog(sprintf('> 校验 %s...', app.simCase.caseId));
                app.simCase = routeA_validate_case(app.simCase);
                app.addLog('  ✓ 校验通过');

                % Build SimulationInput
                app.addLog('> 构建仿真输入...');
                [simIn, context] = routeA_panel_build_simulation_input( ...
                    app.simCase, rampDuration);
                app.addLog('  ✓ SimulationInput 已构建');

                % The helper loads the model when needed. A panel run only
                % applies SimulationInput overrides and does not save the
                % model as a side effect.
                app.ensurePlatformContract();
                model = app.platformPaths.modelName;
                if ~bdIsLoaded(model)
                    load_system(app.platformPaths.modelFile);
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

                observationReport = routeA_validate_observation_output(out, ...
                    routeA_observation_registry(app.platformPaths));
                if ~observationReport.passed
                    error('RouteA:ObservationContractFailed', '%s', ...
                        strjoin(cellstr(observationReport.errors), newline));
                end
                app.addLog(sprintf('  ✓ 观测量契约通过（%d signals）', ...
                    numel(observationReport.present)));

                % Extract results
                app.addLog('> 提取结果...');
                results = routeA_panel_extract_results(out, app.simCase, context);
                app.lastResults = results;
                app.addLog(sprintf('  ✓ 尾窗电压: %.2f V, 电流: %.2f A, 功率: %.2f kW', ...
                    results.voltage_V, results.current_A, results.power_kW));
                app.addLog(sprintf('  cEGR 目标/实际: %.4f / %.4f, 回流量: %.5f kg/s, 阀压差: %.5f MPa', ...
                    results.target_cegr_ratio, results.actual_cegr_ratio, ...
                    results.domains.cegr.massFlow_kg_s.mean, ...
                    results.domains.cegr.valveDeltaP_MPa.mean));
                app.addLog(sprintf('  状态: %s | gas closure=%d | L2液水=%s', ...
                    results.status, results.gasClosurePassed, ...
                    results.waterCapability.status));
                if ~isempty(results.warnings)
                    app.addLog(sprintf('  警告: %s', strjoin(cellstr(results.warnings), ' | ')));
                end

                % Update KPI table
                app.addResultToTable(results);

                % Plot time series
                app.plotTimeSeries(results);

                % Update status
                app.StatusLabel.Text = sprintf('状态: %s | caseId: %s | V=%.2f V', ...
                    results.status, app.simCase.caseId, results.voltage_V);
                if results.passed
                    app.StatusLabel.BackgroundColor = [0.8 1 0.8];
                else
                    app.StatusLabel.BackgroundColor = [1 0.8 0.8];
                end

            catch ME
                app.lastResults = routeA_panel_failure_result(ME, app.simCase);
                app.renderFailureResult(app.lastResults);
                app.addLog(sprintf('  ✗ 失败: %s', ME.message));
                app.StatusLabel.Text = sprintf('状态: 失败 | %s', ME.message);
                app.StatusLabel.BackgroundColor = [1 0.8 0.8];
                uialert(app.UIFigure, ME.message, '仿真失败', 'Icon', 'error');
            end
        end

        % Button pushed function: MatrixButton
        function MatrixButtonPushed(app, ~)
            if app.isRunning
                return;
            end
            [accepted, axes, executionMode] = app.openMatrixDialog();
            if ~accepted
                return;
            end

            app.isRunning = true;
            app.setInputEnabled(false);
            cleanup = onCleanup(@() app.finishRun());
            try
                [baseCase, ~] = app.collectSimCaseFromUi();
                baseCase = routeA_validate_case(baseCase);
                app.ensurePlatformContract();
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
                        message = study.cases(idx).errorMessage;
                        if strlength(string(message)) == 0 && ...
                                isfield(study.cases(idx).results, 'failureCategory')
                            message = study.cases(idx).results.failureCategory;
                        end
                        app.addLog(sprintf('  ✗ %s: %s', ...
                            study.cases(idx).caseId, message));
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

        % Button pushed function: ExportButton
        function ExportButtonPushed(app, ~)
            if isempty(app.lastResults) || ~isstruct(app.lastResults) || ...
                    ~isfield(app.lastResults, 'simCompleted')
                uialert(app.UIFigure, '当前没有可导出的结果。', ...
                    '结果导出', 'Icon', 'warning');
                return;
            end
            if string(app.OutputLevelDropDown.Value) ~= "full_export"
                uialert(app.UIFigure, ...
                    '请先将结果级别切换为“完整版（显式导出）”，再执行导出。', ...
                    '结果级别', 'Icon', 'warning');
                return;
            end

            defaultDir = app.platformPaths.panelResultRoot;
            if ~isfolder(defaultDir)
                mkdir(defaultDir);
            end
            defaultName = sprintf('%s_RouteA_P1_result.mat', ...
                char(app.lastResults.caseId));
            [fileName, filePath] = uiputfile( ...
                fullfile(defaultDir, defaultName), ...
                '导出 Route A 完整结果');
            if isequal(fileName, 0)
                return;
            end

            outputFile = fullfile(filePath, fileName);
            try
                [resultSnapshot, readback] = routeA_panel_export_result( ...
                    app.lastResults, outputFile);
                app.lastResults = resultSnapshot;
                app.addLog(sprintf( ...
                    '  ✓ 完整结果保存后回读通过: %s (%d signals)', ...
                    outputFile, readback.signalManifestCount));
                app.addLog(sprintf('  ✓ 完整结果已导出: %s', outputFile));
                app.StatusLabel.Text = sprintf( ...
                    '状态: 完整结果已导出 | caseId: %s', ...
                    char(app.lastResults.caseId));
            catch ME
                snapshotCase = routeA_simCase_template();
                if isfield(app.lastResults, 'case') && ...
                        isstruct(app.lastResults.case)
                    snapshotCase = app.lastResults.case;
                end
                app.lastResults = routeA_panel_failure_result(ME, snapshotCase);
                app.renderFailureResult(app.lastResults);
                app.addLog(sprintf('  ✗ 完整结果导出失败: %s', ME.message));
                uialert(app.UIFigure, ME.message, '结果导出失败', ...
                    'Icon', 'error');
            end
        end

        % Button pushed function: ClearResultsButton
        function ClearResultsButtonPushed(app, ~)
            app.lastResults = struct();
            app.KpiTable.Data = {};
            app.DomainStatusTable.Data = app.defaultDomainStatusRows();
            app.CathodeResultTable.Data = {};
            app.CegrResultTable.Data = {};
            app.ThermalWaterResultTable.Data = {};
            app.DiagnosticsTable.Data = {};
            app.OverviewSummaryTextArea.Value = { ...
                '尚未运行面板单工况。'; ...
                '结果将按系统域写入右侧分区。'};
            app.OutputLevelDropDown.Value = 'compact_panel';
            app.ExportButton.Enable = 'off';
            app.StatusLabel.Text = '状态: 就绪 | 结果表已清空 | 结果图像历史保留';
            app.StatusLabel.BackgroundColor = [0.9 0.9 0.9];
            app.addLog('> 已清空面板结果表；当前输入和模型未修改，结果图像历史未清除。');
        end

        % Button pushed function: ClearPlotHistoryButton
        function ClearPlotHistoryButtonPushed(app, ~)
            app.plotHistory = struct('caseId', {}, 'voltage_ts', {}, ...
                'current_ts', {}, 'power_ts', {});
            app.renderPlotHistory();
            app.addLog('> 已清空结果图像历史；结果表和当前输入未修改。');
            app.StatusLabel.Text = '状态: 就绪 | 结果图像已清空';
            app.StatusLabel.BackgroundColor = [0.9 0.9 0.9];
        end

        % Selection changed function: PlotModeButtonGroup
        function PlotModeSelectionChanged(app, event)
            if isequal(event.NewValue, app.CurrentPlotButton)
                app.plotMetric = "current";
            elseif isequal(event.NewValue, app.PowerPlotButton)
                app.plotMetric = "power";
            elseif isequal(event.NewValue, app.VoltagePlotButton)
                app.plotMetric = "voltage";
            end
            app.renderPlotHistory();
        end

        function [simCase, rampDuration] = collectSimCaseFromUi(app)
            % Keep advanced-only controls when the user temporarily switches
            % to basic mode. The selected mode changes which controls are
            % authoritative; it must not silently reset the other domain.
            simCase = app.uiBaseCase();
            simCase.controls.anode = app.collectAnodeControls();
            simCase.caseId = app.CaseIdEditField.Value;
            % The model-parameter page is read-only, so the last basic or
            % advanced configuration remains authoritative while it is open.
            advanced = app.activeConfigMode == "advanced";
            if advanced
                mode = app.AdvancedBoundaryModeDropDown.Value;
                command = app.AdvancedBoundaryCommandEditField.Value;
                rampDuration = app.AdvancedRampDurationEditField.Value;
                airControlMode = app.AdvancedAirControlModeDropDown.Value;
                oer = app.AdvancedOerEditField.Value;
                targetMdot = app.AdvancedTargetMdotEditField.Value;
                directCommand = app.AdvancedDirectCommandEditField.Value;
                sourcePressure = app.AdvancedSourcePressureEditField.Value;
                sourceTemperature = app.AdvancedSourceTemperatureEditField.Value;
                backpressure = app.AdvancedBackpressureEditField.Value;
                humidifierRH = app.AdvancedHumidifierRHEditField.Value;
                humidifierEnabled = app.AdvancedHumidifierEnabledCheckBox.Value;
                cegrRatio = app.AdvancedCegrRatioEditField.Value;
                cegrEnabled = app.AdvancedCegrEnabledCheckBox.Value;
                cegrValveMode = app.AdvancedCegrValveModeDropDown.Value;
                cegrControlMode = app.AdvancedCegrControlModeDropDown.Value;
                cegrTargetInputMode = app.AdvancedCegrTargetInputModeDropDown.Value;
                stopTime = app.AdvancedStopTimeEditField.Value;
                solverName = app.AdvancedSolverDropDown.Value;
                relTol = app.AdvancedRelTolEditField.Value;
                absTol = app.AdvancedAbsTolEditField.Value;
                maxStep = app.AdvancedMaxStepEditField.Value;
                stackTemperature = app.AdvancedStackTemperatureEditField.Value;
                o2Fraction = app.AdvancedO2EditField.Value;
                h2oFraction = app.AdvancedH2OEditField.Value;
                simCase.controls.electrical.voltageController = struct( ...
                    'Kp_A_V', app.AdvancedKpEditField.Value, ...
                    'Ki_A_V_s', app.AdvancedKiEditField.Value, ...
                    'currentMin_A', app.AdvancedCurrentMinEditField.Value, ...
                    'currentMax_A', app.AdvancedCurrentMaxEditField.Value);
                performance = app.collectPerformanceControls();
                simCase.controls.cegr.controller = performance.cegrController;
                simCase.controls.stack = performance.stack;
            else
                mode = app.BoundaryModeDropDown.Value;
                command = app.BoundaryCommandEditField.Value;
                rampDuration = app.RampDurationEditField.Value;
                airControlMode = app.AirControlModeDropDown.Value;
                oer = app.OerEditField.Value;
                targetMdot = app.TargetMdotEditField.Value;
                directCommand = app.DirectCommandEditField.Value;
                sourcePressure = simCase.controls.cathode.sourcePressure_MPa_abs;
                sourceTemperature = simCase.controls.cathode.sourceTemperature_C;
                backpressure = app.BackpressureEditField.Value;
                humidifierRH = app.HumidifierRHEditField.Value;
                humidifierEnabled = app.HumidifierEnabledCheckBox.Value;
                cegrRatio = app.CegrRatioEditField.Value;
                cegrEnabled = app.CegrEnabledCheckBox.Value;
                cegrValveMode = simCase.controls.cegr.valveMode;
                cegrControlMode = simCase.controls.cegr.controlMode;
                cegrTargetInputMode = simCase.controls.cegr.targetInputMode;
                stopTime = app.StopTimeEditField.Value;
                solverName = simCase.solver.solver;
                relTol = simCase.solver.relTol;
                absTol = simCase.solver.absTol;
                maxStep = simCase.solver.maxStep_s;
                % Basic page shows the same T_stack setpoint twice: once in
                % the cathode humidifier row (the RH temperature reference)
                % and once in the thermal row.  StackTemperatureEditField is
                % the canonical basic-page readback for this shared input.
                stackTemperature = app.StackTemperatureEditField.Value;
                o2Fraction = simCase.controls.cathode.o2MoleFraction;
                h2oFraction = simCase.controls.cathode.h2oMoleFraction;
            end
            simCase.controls.electrical.mode = mode;
            simCase.controls.electrical.profile = command;
            simCase.controls.cathode.airControlMode = airControlMode;
            simCase.controls.cathode.targetOer = oer;
            simCase.controls.cathode.targetMdot_kg_s = targetMdot;
            simCase.controls.cathode.directCommand = directCommand;
            simCase.controls.cathode.sourcePressure_MPa_abs = sourcePressure;
            simCase.controls.cathode.sourceTemperature_C = sourceTemperature;
            simCase.controls.cathode.outletPressure_MPa_abs = backpressure;
            simCase.controls.cathode.humidifierRH = humidifierRH;
            simCase.controls.cathode.humidifierEnabled = humidifierEnabled;
            simCase.controls.cathode.o2MoleFraction = o2Fraction;
            simCase.controls.cathode.h2oMoleFraction = h2oFraction;
            simCase.controls.cegr.enabled = cegrEnabled;
            simCase.controls.cegr.targetRatio = cegrRatio;
            simCase.controls.cegr.valveMode = cegrValveMode;
            simCase.controls.cegr.controlMode = cegrControlMode;
            simCase.controls.cegr.targetInputMode = cegrTargetInputMode;
            simCase.controls.thermal.stackTemperatureSet_C = stackTemperature;
            simCase.solver.stopTime_s = stopTime;
            simCase.solver.solver = solverName;
            simCase.solver.relTol = relTol;
            simCase.solver.absTol = absTol;
            simCase.solver.maxStep_s = maxStep;
            app.simCase = simCase;
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
            app.isRunning = false;
            app.setInputEnabled(true);
        end

        function setInputEnabled(app, enabled)
            state = app.enableState(logical(enabled));
            controls = { ...
                app.DomainNavigationListBox, app.BasicModeButton, ...
                app.AdvancedModeButton, app.ModelParameterModeButton, ...
                app.HelpModeButton, ...
                app.BoundaryModeDropDown, ...
                app.BoundaryCommandEditField, app.RampDurationEditField, ...
                app.AirControlModeDropDown, app.OerEditField, ...
                app.TargetMdotEditField, app.DirectCommandEditField, ...
                app.BackpressureEditField, app.HumidifierRHEditField, ...
                app.SourceTemperatureEditField, ...
                app.HumidifierEnabledCheckBox, app.CegrRatioEditField, ...
                app.CegrEnabledCheckBox, app.StopTimeEditField, ...
                app.StackTemperatureEditField, app.CaseIdEditField, ...
                app.AdvancedBoundaryModeDropDown, ...
                app.AdvancedBoundaryCommandEditField, ...
                app.AdvancedRampDurationEditField, ...
                app.AdvancedAirControlModeDropDown, app.AdvancedOerEditField, ...
                app.AdvancedTargetMdotEditField, ...
                app.AdvancedDirectCommandEditField, ...
                app.AdvancedSourcePressureEditField, ...
                app.AdvancedSourceTemperatureEditField, ...
                app.AdvancedBackpressureEditField, ...
                app.AdvancedHumidifierRHEditField, ...
                app.AdvancedHumidifierEnabledCheckBox, ...
                app.AdvancedCegrRatioEditField, ...
                app.AdvancedCegrEnabledCheckBox, ...
                app.AdvancedStopTimeEditField, app.AdvancedSolverDropDown, ...
                app.AdvancedRelTolEditField, ...
                app.AdvancedAbsTolEditField, app.AdvancedMaxStepEditField, ...
                app.AdvancedO2EditField, app.AdvancedH2OEditField, ...
                app.AdvancedKpEditField, app.AdvancedKiEditField, ...
                app.AdvancedCurrentMinEditField, ...
                app.AdvancedCurrentMaxEditField, ...
                app.AdvancedCegrValveModeDropDown, ...
                app.AdvancedCegrControlModeDropDown, ...
                app.AdvancedCegrTargetInputModeDropDown, ...
                app.AdvancedStackTemperatureEditField, ...
                app.AdvancedCegrKpEditField, app.AdvancedCegrKiEditField, ...
                app.AdvancedCegrActuatorTauEditField, ...
                app.AdvancedStackNumCellsEditField, app.AdvancedStackAreaEditField, ...
                app.AdvancedStackIEditField, app.AdvancedStackIoEditField, ...
                app.AnodeSourcePressureEditField, ...
                app.AnodeSourceTemperatureEditField, app.AnodeH2EditField, ...
                app.AnodeInletPressureEditField, app.AnodeHumidifierRHEditField, ...
                app.AnodeRecirculationBaseEditField, ...
                app.AnodeRecirculationGainEditField, ...
                app.AnodePurgeEnabledCheckBox, app.AnodePurgeOnN2EditField, ...
                app.AnodePurgeOffN2EditField, app.OutputLevelDropDown, ...
                app.ClearResultsButton, app.ClearPlotHistoryButton, ...
                app.ExportButton, app.RunButton, ...
                app.MatrixButton};
            for idx = 1:numel(controls)
                control = controls{idx};
                if isvalid(control) && isprop(control, 'Enable')
                    control.Enable = state;
                end
            end

            % Restore mode-dependent availability after the run. The solver
            % selector remains disabled because P1 exposes one valid solver.
            if logical(enabled)
                advanced = strcmp(app.AdvancedPanel.Visible, 'on');
                app.updateAirControlControls(advanced);
                app.updateHumidifierControls(advanced);
                app.updateCegrControls(advanced);
                app.updateVoltageControllerControls();
                app.updateAnodeControls();
                app.AdvancedSolverDropDown.Enable = 'off';
                hasExportableResult = isstruct(app.lastResults) && ...
                    isfield(app.lastResults, 'simCompleted') && ...
                    logical(app.lastResults.simCompleted);
                app.ExportButton.Enable = app.enableState(hasExportableResult);
            end
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
            % uitable.Data accepts character values for text cells; the result
            % contract uses scalar string values for case metadata.
            cathode = results.domains.cathode;
            cegr = results.domains.cegr;
            newRow = {char(results.caseId), ...
                      sprintf('%.2f', results.voltage_V), ...
                      sprintf('%.2f', results.current_A), ...
                      sprintf('%.2f', results.power_kW), ...
                      sprintf('%.2f', results.oer), ...
                       sprintf('%.3f', results.target_cegr_ratio), ...
                       sprintf('%.3f', results.actual_cegr_ratio), ...
                       sprintf('%.5f', results.domains.cegr.massFlow_kg_s.mean), ...
                       sprintf('%.5f', cathode.compressorInletMassFlow_kg_s.mean), ...
                      sprintf('%.5f', cathode.cathodeOutletPressure_MPa.mean), ...
                      sprintf('%.3f', cathode.inletRelativeHumidity.mean), ...
                      sprintf('%.3f', cathode.outletRelativeHumidity.mean), ...
                      sprintf('%.5f', cathode.waterSeparationRate_kg_s.mean), ...
                      char(cegr.abilityStatus), char(results.status)};

            % Append to table
            if isempty(currentData)
                app.KpiTable.Data = newRow;
            else
                app.KpiTable.Data = [currentData; newRow];
            end
            app.updateResultViews(results);
            app.refreshDomainStatus(results);
        end

        function renderFailureResult(app, results)
            % Keep a failed run visible in the same result shell without
            % treating unavailable domain values as zeros or verified data.
            app.OverviewSummaryTextArea.Value = { ...
                sprintf('状态: failed | caseId: %s', char(results.caseId)); ...
                sprintf('失败分类: %s | errorId: %s', ...
                    char(results.failureCategory), char(results.errorId)); ...
                sprintf('错误: %s', char(results.errorMessage)); ...
                sprintf('模型: %s | 参数层: %s', char(results.model), ...
                    char(results.parameterLayer)); ...
                '仿真未完成；各系统域保持 not_available。'; ...
                'failureStack 已写入追溯/诊断页并随结果对象导出。'};
            rows = app.defaultDomainStatusRows();
            rows(:, 2) = {'not_available'; 'not_available'; 'not_available'; ...
                char(results.waterCapability.status); 'not_available'; ...
                'not_available'; 'readonly / P4'; 'inventory / P5'; 'failed'};
            app.DomainStatusTable.Data = rows;
            row = repmat({''}, 1, 15);
            row{1} = char(results.caseId);
            row{15} = char(results.failureCategory);
            app.KpiTable.Data = row;
            app.CathodeResultTable.Data = { ...
                '阴极域', '-', 'not available', 'failure: no completed output'};
            app.CegrResultTable.Data = { ...
                'cEGR 域', '-', 'not available', 'failure: no completed output'};
            app.ThermalWaterResultTable.Data = { ...
                '热 / 水域', '-', 'not available', 'failure: no completed output'; ...
                '水能力状态', '-', char(results.waterCapability.status), ...
                    'capability boundary'};
            stackText = char(results.failureStack);
            if strlength(string(stackText)) > 1200
                stackText = [stackText(1:1200) ' ...'];
            end
            app.DiagnosticsTable.Data = { ...
                '结果状态', '-', char(results.status), 'result'; ...
                '失败分类', '-', char(results.failureCategory), 'result'; ...
                'errorId', '-', char(results.errorId), 'failure'; ...
                'errorMessage', '-', char(results.errorMessage), 'failure'; ...
                'failureStack', '-', stackText, 'failure'; ...
                '模型版本', '-', app.formatModelVersion(results.modelVersion), ...
                    'provenance'; ...
                '拓扑 hash', '-', char(results.topologyHash), 'provenance'};
            app.ExportButton.Enable = 'off';
            app.StatusLabel.BackgroundColor = [1 0.8 0.8];
        end

        function updateResultViews(app, results)
            cathode = results.domains.cathode;
            cegr = results.domains.cegr;
            thermal = results.domains.thermal;
            water = results.domains.water;

            app.OverviewSummaryTextArea.Value = { ...
                sprintf('状态: %s | caseId: %s', ...
                    char(results.status), char(results.caseId)); ...
                sprintf('模型: %s | 参数层: %s | 初态: %s', ...
                    char(results.model), char(results.parameterLayer), ...
                    char(results.initialStateMode)); ...
                sprintf('尾窗: %.1f-%.1f s | V=%.2f V | I=%.2f A | P=%.2f kW', ...
                    results.tailLogicalWindow_s(1), results.tailLogicalWindow_s(2), ...
                    results.voltage_V, results.current_A, results.power_kW); ...
                sprintf('观测契约: %s | 气体闭合: %s | 水能力: %s', ...
                    app.passText(results.observationReport.passed), ...
                    app.passText(results.gasClosurePassed), ...
                    char(results.waterCapability.status)); ...
                sprintf('cEGR 能力: %s | 警告: %d | 失败分类: %s', ...
                    char(cegr.abilityStatus), numel(results.warnings), ...
                    char(results.failureCategory))};

            app.CathodeResultTable.Data = { ...
                '入口质量流量', 'kg/s', app.formatResultValue( ...
                    cathode.compressorInletMassFlow_kg_s.mean, '%.6g'), 'tail mean'; ...
                '入口压力', 'Pa', app.formatResultValue( ...
                    cathode.compressorInletPressure_Pa.mean, '%.6g'), 'tail mean'; ...
                '入口温度', 'K', app.formatResultValue( ...
                    cathode.compressorInletTemperature_K.mean, '%.6g'), 'tail mean'; ...
                '出口温度', 'K', app.formatResultValue( ...
                    cathode.cathodeOutletTemperature_K.mean, '%.6g'), 'tail mean'; ...
                '出口背压', 'MPa(abs)', app.formatResultValue( ...
                    cathode.cathodeOutletPressure_MPa.mean, '%.6g'), 'tail mean'; ...
                '入口 RH', '-', app.formatResultValue( ...
                    cathode.inletRelativeHumidity.mean, '%.5f'), 'tail mean'; ...
                '出口 RH', '-', app.formatResultValue( ...
                    cathode.outletRelativeHumidity.mean, '%.5f'), 'tail mean'; ...
                '入口组分 [N2 O2 H2 H2O]', '-', app.formatComposition( ...
                    cathode.inletComposition), 'tail mean'; ...
                '出口组分 [N2 O2 H2 H2O]', '-', app.formatComposition( ...
                    cathode.outletComposition), 'tail mean'; ...
                '入口氧过量系数', '-', app.formatResultValue( ...
                    cathode.inletOxygenStoich.mean, '%.5f'), 'tail mean'; ...
                '气体闭合', '-', app.passText(results.gasClosurePassed), 'audit'};

            app.CegrResultTable.Data = { ...
                '目标比例', '-', app.formatResultValue(cegr.targetRatio, '%.6f'), 'command'; ...
                '实际比例', '-', app.formatResultValue(cegr.actualRatio, '%.6f'), 'tail mean'; ...
                '比例误差', '-', app.formatResultValue( ...
                    cegr.actualRatio - cegr.targetRatio, '%.6f'), 'actual-target'; ...
                '回流质量流量', 'kg/s', app.formatResultValue( ...
                    cegr.massFlow_kg_s.mean, '%.6g'), 'tail mean'; ...
                '阀面积', 'm^2', app.formatResultValue( ...
                    cegr.valveArea_m2.mean, '%.6g'), 'tail mean'; ...
                '阀面积上限', 'm^2', app.formatResultValue( ...
                    cegr.valveAreaLimit_m2, '%.6g'), 'context'; ...
                '阀上游压力', 'Pa', app.formatResultValue( ...
                    cegr.valveUpstreamPressure_Pa.mean, '%.6g'), 'tail mean'; ...
                '阀下游压力', 'Pa', app.formatResultValue( ...
                    cegr.valveDownstreamPressure_Pa.mean, '%.6g'), 'tail mean'; ...
                '阀压差', 'MPa', app.formatResultValue( ...
                    cegr.valveDeltaP_MPa.mean, '%.6g'), 'tail mean'; ...
                '能力分类', '-', char(cegr.abilityStatus), 'diagnostic'; ...
                '控制模式', '-', app.formatResultValue( ...
                    cegr.controlMode, '%.0f'), 'compile-time'; ...
                '控制跟踪', '-', app.passText(results.cegrPassed), 'audit'; ...
                '饱和状态', '-', app.passText(results.saturationPassed), 'audit'};

            app.ThermalWaterResultTable.Data = { ...
                '堆温', 'degC', app.formatResultValue( ...
                    thermal.stackTemperature_C.mean, '%.6g'), 'tail mean'; ...
                '水分离通量', 'kg/s', app.formatResultValue( ...
                    cathode.waterSeparationRate_kg_s.mean, '%.6g'), 'tail mean'; ...
                '水能力状态', '-', char(water.status), 'capability'; ...
                '水结论范围', '-', char(water.scope), 'capability'; ...
                '阴极出口温度', 'K', app.formatResultValue( ...
                    thermal.cathodeOutletTemperature_K.mean, '%.6g'), 'tail mean'; ...
                '完整水衡算', '-', app.passText(water.fullWaterBalanceClosed), ...
                    'not an acceptance claim'};

            app.DiagnosticsTable.Data = { ...
                '结果状态', '-', char(results.status), 'result'; ...
                '失败分类', '-', char(results.failureCategory), 'result'; ...
                '观测契约', '-', app.passText(results.observationReport.passed), 'contract'; ...
                '稳定性', '-', app.passText(results.steadyPassed), 'audit'; ...
                '尾窗 purge-free', '-', app.passText(results.tailPurgeFree), 'audit'; ...
                '拓扑 hash', '-', char(results.topologyHash), 'provenance'; ...
                '模型版本', '-', app.formatModelVersion(results.modelVersion), 'provenance'; ...
                '结果级别', '-', char(results.outputLevel), 'display'; ...
                'signalManifest', '-', sprintf('%d signals', ...
                    numel(results.signalManifest)), 'contract'; ...
                'warnings', '-', app.formatTextList(results.warnings), ...
                    'classified'; ...
                'errors', '-', app.formatTextList(results.errors), 'contract'; ...
                'failureStack', '-', app.formatTextList(results.failureStack), ...
                    'empty on completed run'};

            if results.simCompleted
                app.ExportButton.Enable = 'on';
            else
                app.ExportButton.Enable = 'off';
            end
        end

        function rows = defaultDomainStatusRows(~)
            rows = { ...
                '工况与电边界', 'available'; ...
                '阴极进气与空气控制', 'available'; ...
                '温度控制', 'observed'; ...
                '水管理与水检测', 'L2_not_closed'; ...
                'cEGR 系统', 'available'; ...
                '电堆与电化学', 'observed'; ...
                '阳极系统', 'inputs active / results P4'; ...
                '设备与控制器', 'partial active / inventory readonly'; ...
                '结果与诊断', 'available'};
        end

        function text = passText(~, value)
            if logical(value)
                text = 'verified';
            else
                text = 'not_verified';
            end
        end

        function text = formatResultValue(~, value, formatSpec)
            if isstruct(value) && isfield(value, 'mean')
                value = value.mean;
            end
            if isnumeric(value) && isscalar(value) && isfinite(value)
                text = sprintf(formatSpec, double(value));
            elseif isstring(value) || ischar(value)
                text = char(string(value));
            else
                text = 'not available';
            end
        end

        function text = formatComposition(~, value)
            if isstruct(value) && isscalar(value)
                fields = {'N2', 'O2', 'H2', 'H2O'};
                if builtin('all', isfield(value, fields))
                    values = cellfun(@(name) double(value.(name)), fields);
                    if builtin('all', isfinite(values))
                        text = sprintf('[%.4f %.4f %.4f %.4f]', values);
                        return;
                    end
                end
            elseif isnumeric(value) && isvector(value) && numel(value) == 4 && ...
                    builtin('all', isfinite(value))
                text = sprintf('[%.4f %.4f %.4f %.4f]', double(value(:).'));
                return;
            end
            text = 'not available';
        end

        function text = formatTextList(~, values)
            values = string(values(:));
            values(strlength(values) == 0) = [];
            if isempty(values)
                text = 'none';
                return;
            end
            text = char(strjoin(values, ' | '));
            if numel(text) > 1000
                text = [text(1:1000) ' ...'];
            end
        end

        function text = formatModelVersion(~, value)
            if isstruct(value) && isscalar(value)
                parts = strings(0, 1);
                if isfield(value, 'fileName')
                    parts(end + 1, 1) = string(value.fileName);
                end
                if isfield(value, 'modified')
                    parts(end + 1, 1) = "modified=" + string(value.modified);
                end
                if isfield(value, 'bytes') && isnumeric(value.bytes)
                    parts(end + 1, 1) = sprintf('bytes=%g', double(value.bytes));
                end
                if ~isempty(parts)
                    text = char(strjoin(parts, ' | '));
                    return;
                end
            end
            if isstring(value) || ischar(value)
                text = char(string(value));
            else
                text = 'not available';
            end
        end

        function values = defaultHelpText(~)
            values = { ...
                '面板-模型操作说明'; ...
                ''; ...
                '一、基本操作'; ...
                '1. 在基础页选择电边界、空气控制模式、加湿器/cEGR开关并填写数值。'; ...
                '2. 高级页用于控制器、入口边界、组分、求解器、阳极输入和 P3 系统性能参数。'; ...
                '3. 系统模型参数页是完整设备参数目录；P3 已开放的输入在高级页编辑，其余目录项仍只读。'; ...
                '4. 帮助页只解释输入含义，不改变当前 simCase。'; ...
                ''; ...
                '二、电边界控制原理'; ...
                'Current：模型直接接收电流命令，输出电压和功率反馈。单位 A。'; ...
                'Power：模型接收功率命令，统一装配层换算为电流边界，输出实际 V/I/P。单位 kW。'; ...
                'Voltage：模型接收电压目标，由电压 PI 调整电流命令；Kp、Ki 和电流上下限只在 Voltage 下生效。单位 V。'; ...
                '斜坡时间用于启动时平滑引入命令，不能替代求解器设置。'; ...
                ''; ...
                '三、空气控制和湿度'; ...
                '空气模式一次只能选一个主控制源：质量流量闭环、OER闭环或空压机执行命令。非当前源的输入框灰显且不作为本次控制输入。'; ...
                '空压机目标流量是空压机入口质量流量目标 (kg/s)；OER 是无量纲氧过量比，模型按电流换算目标流量后仍走空压机流量闭环。'; ...
                '空压机执行命令是 0 到 1 的归一化空压机命令，跳过目标流量/OER换算和流量PI，但仍经过空压机及压缩机图谱，不是直接给电堆气体；它是第三种低层控制源。'; ...
                'RH 是加湿器出口/阴极入口相对湿度，填写 0 到 1 的比例值；温度参考使用“加湿温度 (C)”，当前模型由 T_stack 路径提供。'; ...
                '新鲜空气源温度在高级页单独设置，不能与加湿温度混用。关闭加湿器时 RH 数值保留，但本次运行不生效；压力使用 MPa(abs)。'; ...
                ''; ...
                '四、cEGR 和结果'; ...
                'P1/P2 当前主入口是目标 cEGR 比例；关闭 cEGR 时目标按 0 处理，阀状态仅作为结果诊断。'; ...
                'P3 首轮开放 cEGR PI 增益、阀执行器时间常数和电堆单体参数；这些值会经过校验并写入 SimulationInput。'; ...
                '阳极输入已接入统一 command profile；阳极压力、回流、吹扫等结果信号仍保持 status-only，待后续观测契约确认。'; ...
                '运行按钮会依次执行校验、SimulationInput 装配、模型仿真和结果提取。失败也会进入追溯/诊断页。'; ...
                '结果图像页可在电流-时间、功率-时间、电压-时间之间切换，并保留本次 MATLAB 会话中的 caseId 历史。'; ...
                '清空结果只清除结果表；清空图像单独清除曲线历史；两者都不修改当前输入和模型。'; ...
                ''; ...
                '五、输入生效链'; ...
                'UI -> simCase -> routeA_validate_case -> SimulationInput -> 当前正式模型 -> SimulationOutput -> 结果/诊断。'; ...
                '模型不收敛属于实际模型结果；面板负责显示状态、错误信息和失败栈，不预设必然收敛。'};
        end

        function refreshDomainStatus(app, results)
            cegrStatus = string(results.domains.cegr.abilityStatus);
            if cegrStatus == "tracking_verified" && ...
                    results.cegrPassed && results.passed
                cegrStatus = "verified / tracking_verified";
            elseif cegrStatus == "tracking_verified"
                cegrStatus = "tracking_verified / not_verified";
            end
            rows = app.defaultDomainStatusRows();
            rows{1, 2} = 'verified';
            rows{2, 2} = 'verified';
            rows{3, 2} = 'observed';
            rows{4, 2} = char(results.waterCapability.status);
            rows{5, 2} = char(cegrStatus);
            rows{6, 2} = 'observed';
            rows{9, 2} = char(results.status);
            app.DomainStatusTable.Data = rows;
        end

        % Helper: Plot time series
        function plotTimeSeries(app, results)
            if isfield(results, 'simCompleted') && logical(results.simCompleted)
                app.appendPlotHistory(results);
                app.ResultTabGroup.SelectedTab = app.TraceTab;
                app.renderPlotHistory();
            end
        end

        function appendPlotHistory(app, results)
            required = {'caseId', 'voltage_ts', 'current_ts', 'power_ts'};
            if ~builtin('all', isfield(results, required))
                return;
            end
            item = struct( ...
                'caseId', char(string(results.caseId)), ...
                'voltage_ts', results.voltage_ts, ...
                'current_ts', results.current_ts, ...
                'power_ts', results.power_ts);
            if isempty(app.plotHistory)
                app.plotHistory = item;
            else
                app.plotHistory(end + 1) = item;
            end
        end

        function renderPlotHistory(app)
            cla(app.TimeSeriesAxes);
            hold(app.TimeSeriesAxes, 'on');
            switch string(app.plotMetric)
                case "current"
                    fieldName = 'current_ts';
                    titleText = '电流-时间';
                    yLabelText = '电流 (A)';
                case "power"
                    fieldName = 'power_ts';
                    titleText = '功率-时间';
                    yLabelText = '功率 (kW)';
                otherwise
                    fieldName = 'voltage_ts';
                    titleText = '电压-时间';
                    yLabelText = '电压 (V)';
            end

            plotted = false;
            labels = strings(0, 1);
            for idx = 1:numel(app.plotHistory)
                ts = app.plotHistory(idx).(fieldName);
                [time, data, available] = app.timeSeriesVectors(ts);
                if ~available
                    continue;
                end
                caseId = string(app.plotHistory(idx).caseId);
                occurrence = sum(labels == caseId) + 1;
                if occurrence > 1
                    displayName = sprintf('%s (#%d)', char(caseId), occurrence);
                else
                    displayName = char(caseId);
                end
                plot(app.TimeSeriesAxes, time, data, 'LineWidth', 1.4, ...
                    'DisplayName', displayName);
                labels(end + 1, 1) = caseId;
                plotted = true;
            end
            xlabel(app.TimeSeriesAxes, '时间 (s)');
            ylabel(app.TimeSeriesAxes, yLabelText);
            title(app.TimeSeriesAxes, titleText);
            grid(app.TimeSeriesAxes, 'on');
            if plotted
                legend(app.TimeSeriesAxes, 'show', 'Location', 'best');
            else
                text(app.TimeSeriesAxes, 0.5, 0.5, '暂无可显示的结果图像', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'Color', [0.35 0.35 0.35]);
            end
            hold(app.TimeSeriesAxes, 'off');
        end

        function [time, data, available] = timeSeriesVectors(~, ts)
            time = [];
            data = [];
            available = false;
            if isa(ts, 'timeseries')
                time = double(ts.Time(:));
                data = double(ts.Data);
            elseif isstruct(ts) && isfield(ts, 'Time') && isfield(ts, 'Data')
                time = double(ts.Time(:));
                data = double(ts.Data);
            else
                return;
            end
            if isempty(time) || isempty(data) || ~builtin('all', isfinite(time))
                return;
            end
            if ~isvector(data)
                data = data(:, 1);
            else
                data = data(:);
            end
            n = min(numel(time), numel(data));
            time = time(1:n);
            data = data(1:n);
            available = n > 1 && builtin('all', isfinite(data));
        end

        function plotMatrixResults(app, study)
            for idx = 1:study.caseCount
                if ~study.cases(idx).passed
                    continue;
                end
                result = study.cases(idx).results;
                app.appendPlotHistory(result);
            end
            app.ResultTabGroup.SelectedTab = app.TraceTab;
            app.renderPlotHistory();
        end
    end

    % Component initialization
    methods (Access = private)

        function layoutFigure(app, ~)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure) || ...
                    isempty(app.ConfigScrollPanel) || ...
                    ~isvalid(app.ConfigScrollPanel) || ...
                    isempty(app.ConfigCanvas) || ~isvalid(app.ConfigCanvas) || ...
                    isempty(app.NavigationPanel) || ~isvalid(app.NavigationPanel) || ...
                    isempty(app.LeftPanel) || ~isvalid(app.LeftPanel) || ...
                    isempty(app.RightPanel) || ~isvalid(app.RightPanel) || ...
                    isempty(app.ModeButtonGroup) || ...
                    ~isvalid(app.ModeButtonGroup) || ...
                    isempty(app.ResultTabGroup) || ~isvalid(app.ResultTabGroup) || ...
                    isempty(app.OutputLevelDropDown) || ...
                    ~isvalid(app.OutputLevelDropDown) || ...
                    isempty(app.LogTextArea) || ~isvalid(app.LogTextArea)
                return;
            end

            figPosition = app.UIFigure.Position;
            figWidth = max(900, figPosition(3));
            figHeight = max(650, figPosition(4));
            margin = 14;
            headerHeight = 54;
            statusHeight = 28;
            panelY = statusHeight + margin;
            panelHeight = max(420, figHeight - panelY - headerHeight - margin);
            % P2 uses a stable two-column shell. The former domain navigator
            % remains only as an internal compatibility object and is hidden.
            leftWidth = min(760, max(620, round(figWidth * 0.38)));
            leftX = margin;
            rightX = leftX + leftWidth + margin;
            rightWidth = max(360, figWidth - rightX - margin);
            leftContentWidth = max(580, leftWidth - 30);
            rightContentWidth = max(320, rightWidth - 20);
            % Keep enough content height for the advanced and catalog pages;
            % the mode bar itself is outside this canvas.
            configHeight = max(1480, panelHeight + 180);

            app.HeaderTitleLabel.Position = [margin figHeight - 32 500 24];
            app.HeaderMetaLabel.Position = [margin + 505 figHeight - 31 ...
                max(280, figWidth - 535) 22];
            app.StatusLabel.Position = [margin 8 figWidth - 2 * margin statusHeight - 3];
            app.NavigationPanel.Visible = 'off';
            app.NavigationPanel.Position = [0 0 1 1];
            app.LeftPanel.Position = [leftX panelY leftWidth panelHeight];
            app.RightPanel.Position = [rightX panelY rightWidth panelHeight];

            configViewportHeight = max(100, panelHeight - 68);
            app.ConfigScrollPanel.Position = ...
                [0 0 leftContentWidth configViewportHeight];
            app.ConfigCanvas.Position = [0 0 leftContentWidth configHeight];
            % The mode bar is a fixed child of LeftPanel.  The scrollable
            % content stops below it, so every configuration page shares one
            % stable switch surface.
            app.ModeButtonGroup.Position = [leftContentWidth - 350, ...
                panelHeight - 60, 330, 30];
            for panel = [app.ElectricalPanel, app.AirPathPanel, ...
                    app.CegrPanel, app.SolverPanel, app.ThermalPanel, ...
                    app.FutureDomainsPanel, app.HelpPanel, ...
                    app.AdvancedPanel]
                panelPosition = panel.Position;
                panel.Position = [panelPosition(1:2) leftContentWidth - 20 panelPosition(4)];
            end
            catalogWidth = max(430, leftContentWidth - 40);
            app.ParameterCatalogIntroLabel.Position(3) = catalogWidth;
            app.ParameterCatalogStatusLabel.Position(3) = catalogWidth;
            app.ParameterCatalogTable.Position(3) = catalogWidth;
            app.CaseIdEditField.Position(3) = max(180, leftContentWidth - 260);
            app.RunButton.Position(3) = 170;

            rightContentHeight = max(620, panelHeight);
            app.OutputLevelLabel.Position = [10 rightContentHeight - 34 80 22];
            app.OutputLevelDropDown.Position = [90 rightContentHeight - 34 160 22];
            app.ClearResultsButton.Position = [rightContentWidth - 235 rightContentHeight - 34 105 24];
            app.ExportButton.Position = [rightContentWidth - 120 rightContentHeight - 34 110 24];
            resultTabWidth = max(300, rightContentWidth - 20);
            resultTabHeight = max(330, rightContentHeight - 174);
            app.ResultTabGroup.Position = [10 130 resultTabWidth resultTabHeight];
            % uitab content is shorter than the tab group by its tab header;
            % size the stacked overview controls against the content area so
            % the summary, status table, and KPI table never overlap.
            tabContentWidth = max(260, resultTabWidth - 20);
            tabContentHeight = max(300, resultTabHeight - 36);
            summaryHeight = 68;
            summaryY = tabContentHeight - summaryHeight - 10;
            app.OverviewSummaryTextArea.Position = ...
                [10 summaryY tabContentWidth summaryHeight];
            domainHeight = min(132, max(94, round(tabContentHeight * 0.24)));
            domainY = summaryY - domainHeight - 12;
            app.DomainStatusTable.Position = ...
                [10 domainY tabContentWidth domainHeight];
            kpiY = 10;
            kpiHeight = max(96, domainY - kpiY - 12);
            app.KpiTable.Position = [10 kpiY tabContentWidth kpiHeight];
            resultTableHeight = max(200, tabContentHeight - 20);
            app.CathodeResultTable.Position = [10 10 tabContentWidth resultTableHeight];
            app.CegrResultTable.Position = [10 10 tabContentWidth resultTableHeight];
            app.ThermalWaterResultTable.Position = [10 10 tabContentWidth resultTableHeight];
            app.DiagnosticsTable.Position = [10 10 tabContentWidth resultTableHeight];
            plotToolbarY = tabContentHeight - 32;
            app.PlotModeButtonGroup.Position = [10 plotToolbarY 300 26];
            app.ClearPlotHistoryButton.Position = ...
                [max(10, tabContentWidth - 105) plotToolbarY 105 24];
            app.TimeSeriesAxes.Position = [10 10 tabContentWidth ...
                max(180, tabContentHeight - 56)];
            app.LogLabel.Position = [10 100 120 22];
            app.LogTextArea.Position = [10 10 rightContentWidth 90];
        end

        function ensurePlatformContract(app)
            [~, report] = routeA_model_contract(app.platformPaths, ...
                struct('loadModel', true, 'strict', true));
            if ~report.passed
                error('RouteA:ModelContractCheckFailed', '%s', ...
                    strjoin(cellstr(report.errors), newline));
            end
        end

        function createComponents(app)
            % Create UIFigure and components
            params = routeA_platform_default_parameters();
            
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1720 1020];
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @layoutFigure, true);
            app.UIFigure.Name = 'Route A cEGR-PEMFC 仿真平台';
            app.UIFigure.Color = [0.94 0.94 0.94];

            % System-domain navigation column
            app.NavigationPanel = uipanel(app.UIFigure);
            app.NavigationPanel.Title = '系统域导航';
            app.NavigationPanel.Position = [10 50 190 620];
            app.NavigationPanel.BackgroundColor = [0.94 0.94 0.94];
            app.NavigationPanel.Visible = 'off';
            if isprop(app.NavigationPanel, 'AutoResizeChildren')
                app.NavigationPanel.AutoResizeChildren = 'off';
            end
            app.DomainNavigationListBox = uilistbox(app.NavigationPanel);
            app.DomainNavigationListBox.Items = { ...
                '工况与电边界', ...
                '阴极进气与空气控制', ...
                '温度控制', ...
                '水管理与水检测', ...
                'cEGR 系统', ...
                '电堆与电化学', ...
                '阳极系统 / 当前扩展', ...
                '系统模型参数 / 设备目录', ...
                '结果与诊断'};
            app.DomainNavigationListBox.Value = '工况与电边界';
            app.DomainNavigationListBox.Position = [10 70 170 520];
            app.DomainNavigationListBox.ValueChangedFcn = ...
                createCallbackFcn(app, @DomainNavigationChanged, true);
            app.DomainNavigationStatusLabel = uilabel(app.NavigationPanel);
            app.DomainNavigationStatusLabel.Position = [10 10 170 45];
            app.DomainNavigationStatusLabel.Text = {'P2 面板'; '单工况 / cold-start-only'};
            app.DomainNavigationStatusLabel.FontSize = 10;
            
            % Header and status bar
            app.HeaderTitleLabel = uilabel(app.UIFigure);
            app.HeaderTitleLabel.Text = 'Route A | 完整燃料电池系统面板';
            app.HeaderTitleLabel.FontSize = 18;
            app.HeaderTitleLabel.FontWeight = 'bold';
            app.HeaderTitleLabel.FontColor = [0.12 0.20 0.28];

            app.HeaderMetaLabel = uilabel(app.UIFigure);
            app.HeaderMetaLabel.Text = 'P3 首轮参数开放 | 当前模型直驱 | cold-start';
            app.HeaderMetaLabel.HorizontalAlignment = 'right';
            app.HeaderMetaLabel.FontSize = 11;
            app.HeaderMetaLabel.FontColor = [0.30 0.35 0.40];

            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.Position = [10 10 1180 25];
            app.StatusLabel.Text = '状态: 就绪 | 模型: PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01 | 参数源: platform_default';
            app.StatusLabel.FontSize = 11;
            app.StatusLabel.BackgroundColor = [0.9 0.9 0.9];
            
            % Left panel
            app.LeftPanel = uipanel(app.UIFigure);
            app.LeftPanel.Title = '系统配置（可滚动）';
            app.LeftPanel.Position = [10 50 480 620];
            app.LeftPanel.BackgroundColor = [0.94 0.94 0.94];
            if isprop(app.LeftPanel, 'AutoResizeChildren')
                app.LeftPanel.AutoResizeChildren = 'off';
            end
            if isprop(app.LeftPanel, 'Scrollable')
                app.LeftPanel.Scrollable = 'off';
            end
            % Keep the mode bar outside the scrollable content.  This avoids
            % nested scroll ownership between the left shell and each page.
            app.ConfigScrollPanel = uipanel(app.LeftPanel);
            app.ConfigScrollPanel.Position = [0 0 560 552];
            app.ConfigScrollPanel.BorderType = 'none';
            app.ConfigScrollPanel.BackgroundColor = [0.94 0.94 0.94];
            if isprop(app.ConfigScrollPanel, 'AutoResizeChildren')
                app.ConfigScrollPanel.AutoResizeChildren = 'off';
            end
            if isprop(app.ConfigScrollPanel, 'Scrollable')
                app.ConfigScrollPanel.Scrollable = 'on';
            end
            app.ConfigCanvas = uipanel(app.ConfigScrollPanel);
            app.ConfigCanvas.Position = [0 0 560 1480];
            app.ConfigCanvas.BorderType = 'none';
            app.ConfigCanvas.BackgroundColor = [0.94 0.94 0.94];
            if isprop(app.ConfigCanvas, 'AutoResizeChildren')
                app.ConfigCanvas.AutoResizeChildren = 'off';
            end
            
            % Right panel
            app.RightPanel = uipanel(app.UIFigure);
            app.RightPanel.Title = '结果与诊断 | 按系统域查看';
            app.RightPanel.Position = [500 50 690 620];
            app.RightPanel.BackgroundColor = [0.94 0.94 0.94];
            if isprop(app.RightPanel, 'AutoResizeChildren')
                app.RightPanel.AutoResizeChildren = 'off';
            end
            if isprop(app.RightPanel, 'Scrollable')
                app.RightPanel.Scrollable = 'on';
            end
            
            % Mode toggle
            % Keep the four mode buttons fixed in the left shell, above the
            % single scrollable configuration viewport.
            app.ModeButtonGroup = uibuttongroup(app.LeftPanel);
            app.ModeButtonGroup.Position = [140 560 330 30];
            app.ModeButtonGroup.BorderType = 'none';
            app.ModeButtonGroup.BackgroundColor = [0.94 0.94 0.94];
            
            app.BasicModeButton = uitogglebutton(app.ModeButtonGroup);
            app.BasicModeButton.Text = '基础';
            app.BasicModeButton.Position = [0 0 70 30];
            app.BasicModeButton.Value = true;
            
            app.AdvancedModeButton = uitogglebutton(app.ModeButtonGroup);
            app.AdvancedModeButton.Text = '高级';
            app.AdvancedModeButton.Position = [70 0 70 30];

            app.ModelParameterModeButton = uitogglebutton(app.ModeButtonGroup);
            app.ModelParameterModeButton.Text = '系统模型参数';
            app.ModelParameterModeButton.Position = [140 0 120 30];
            app.ModelParameterModeButton.Value = false;
            app.HelpModeButton = uitogglebutton(app.ModeButtonGroup);
            app.HelpModeButton.Text = '帮助';
            app.HelpModeButton.Position = [260 0 70 30];
            app.HelpModeButton.Value = false;
            app.ModeButtonGroup.SelectionChangedFcn = ...
                createCallbackFcn(app, @ModeSelectionChanged, true);
            
            % Electrical boundary panel
            app.ElectricalPanel = uipanel(app.ConfigCanvas);
            app.ElectricalPanel.Title = '电边界';
            app.ElectricalPanel.Position = [10 990 450 100];
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
            app.AirPathPanel = uipanel(app.ConfigCanvas);
            app.AirPathPanel.Title = '阴极进气与空气控制';
            app.AirPathPanel.Position = [10 750 450 225];
            app.AirPathPanel.BackgroundColor = [1 1 1];

            app.AirControlModeLabel = uilabel(app.AirPathPanel);
            app.AirControlModeLabel.Position = [10 180 100 22];
            app.AirControlModeLabel.Text = '空气模式:';
            app.AirControlModeDropDown = uidropdown(app.AirPathPanel);
            app.AirControlModeDropDown.Items = {'质量流量', 'OER', '空压机命令'};
            app.AirControlModeDropDown.ItemsData = [1 2 3];
            app.AirControlModeDropDown.Value = params.controls.air_control_mode.value;
            app.AirControlModeDropDown.Position = [110 180 130 22];
            app.AirControlModeDropDown.ValueChangedFcn = ...
                createCallbackFcn(app, @AirControlModeChanged, true);
            
            app.OerLabel = uilabel(app.AirPathPanel);
            app.OerLabel.Position = [300 180 70 22];
            app.OerLabel.Text = 'OER (-):';
            
            app.OerEditField = uieditfield(app.AirPathPanel, 'numeric');
            app.OerEditField.Position = [375 180 80 22];
            app.OerEditField.Value = params.controls.target_oer.value;
            app.OerEditField.Tooltip = ...
                '模式 2：OER 为无量纲氧过量比，模型按电流换算目标流量后驱动空压机';

            app.TargetMdotLabel = uilabel(app.AirPathPanel);
            app.TargetMdotLabel.Position = [10 145 130 22];
            app.TargetMdotLabel.Text = '目标流量 (kg/s):';
            app.TargetMdotEditField = uieditfield(app.AirPathPanel, 'numeric');
            app.TargetMdotEditField.Position = [145 145 85 22];
            app.TargetMdotEditField.Value = params.controls.target_mdot_kg_s.value;
            app.TargetMdotEditField.Tooltip = ...
                '模式 1：空压机入口质量流量目标；模型再经流量控制环驱动空压机';

            app.DirectCommandLabel = uilabel(app.AirPathPanel);
            app.DirectCommandLabel.Position = [300 145 115 22];
            app.DirectCommandLabel.Text = '空压机命令 (0-1):';
            app.DirectCommandEditField = uieditfield(app.AirPathPanel, 'numeric');
            app.DirectCommandEditField.Position = [420 145 80 22];
            app.DirectCommandEditField.Value = params.controls.air_direct_command.value;
            app.DirectCommandEditField.Tooltip = ...
                ['模式 3：直接给空压机归一化执行命令；仍经过压缩机图谱，', ...
                 '不是直接给电堆气体'];
            
            app.BackpressureLabel = uilabel(app.AirPathPanel);
            app.BackpressureLabel.Position = [10 110 145 22];
            app.BackpressureLabel.Text = '背压 (MPa(abs)):';
            
            app.BackpressureEditField = uieditfield(app.AirPathPanel, 'numeric');
            app.BackpressureEditField.Position = [155 110 85 22];
            app.BackpressureEditField.Value = ...
                params.controls.backpressure_MPa_abs.value;
            
            app.HumidifierRHLabel = uilabel(app.AirPathPanel);
            app.HumidifierRHLabel.Position = [300 110 115 22];
            app.HumidifierRHLabel.Text = '加湿器出口 RH (-):';
            
            app.HumidifierRHEditField = uieditfield(app.AirPathPanel, 'numeric');
            app.HumidifierRHEditField.Position = [420 110 80 22];
            app.HumidifierRHEditField.Value = ...
                params.cathode.humidifier.default_rh.value;

            app.HumidifierEnabledCheckBox = uicheckbox(app.AirPathPanel);
            app.HumidifierEnabledCheckBox.Text = '启用加湿器';
            app.SourceTemperatureLabel = uilabel(app.AirPathPanel);
            app.SourceTemperatureLabel.Position = [300 75 115 22];
            app.SourceTemperatureLabel.Text = '加湿温度 (C):';
            app.SourceTemperatureEditField = uieditfield(app.AirPathPanel, 'numeric');
            app.SourceTemperatureEditField.Position = [420 75 80 22];
            app.SourceTemperatureEditField.Value = ...
                params.thermal.stack_temperature_set_C.value;
            app.SourceTemperatureEditField.Tooltip = ...
                ['加湿器出口/阴极入口 RH 的温度参考；当前模型的加湿器 TIn ', ...
                 '接入 T_stack 路径，并写入 thermal.stackTemperatureSet_C'];
            app.SourceTemperatureEditField.ValueChangedFcn = ...
                createCallbackFcn(app, @HumidifierTemperatureChanged, true);

            app.HumidifierEnabledCheckBox.Position = [10 75 120 22];
            app.HumidifierEnabledCheckBox.Value = ...
                logical(params.cathode.humidifier.enabled.value);
            app.HumidifierEnabledCheckBox.ValueChangedFcn = ...
                createCallbackFcn(app, @HumidifierEnabledChanged, true);
            
            % cEGR panel
            app.CegrPanel = uipanel(app.ConfigCanvas);
            app.CegrPanel.Title = 'cEGR';
            app.CegrPanel.Position = [10 700 450 80];
            app.CegrPanel.BackgroundColor = [1 1 1];
            
            app.CegrRatioLabel = uilabel(app.CegrPanel);
            app.CegrRatioLabel.Position = [10 35 100 22];
            app.CegrRatioLabel.Text = '目标比例 (-):';
            
            app.CegrRatioEditField = uieditfield(app.CegrPanel, 'numeric');
            app.CegrRatioEditField.Position = [110 35 100 22];
            app.CegrRatioEditField.Value = params.controls.cegr_target_ratio.value;
            
            app.CegrEnabledCheckBox = uicheckbox(app.CegrPanel);
            app.CegrEnabledCheckBox.Text = '启用 cEGR';
            app.CegrEnabledCheckBox.Position = [10 5 100 22];
            app.CegrEnabledCheckBox.Value = logical(params.controls.cegr_enabled.value);
            app.CegrEnabledCheckBox.ValueChangedFcn = ...
                createCallbackFcn(app, @CegrEnabledChanged, true);
            
            % Solver panel
            app.SolverPanel = uipanel(app.ConfigCanvas);
            app.SolverPanel.Title = '求解器';
            app.SolverPanel.Position = [10 630 450 60];
            app.SolverPanel.BackgroundColor = [1 1 1];
            
            app.StopTimeLabel = uilabel(app.SolverPanel);
            app.StopTimeLabel.Position = [10 15 100 22];
            app.StopTimeLabel.Text = '仿真时长 (s):';
            
            app.StopTimeEditField = uieditfield(app.SolverPanel, 'numeric');
            app.StopTimeEditField.Position = [110 15 100 22];
            app.StopTimeEditField.Value = params.numerics.stopTime_s.value;

            % Thermal boundary panel
            app.ThermalPanel = uipanel(app.ConfigCanvas);
            app.ThermalPanel.Title = '温度边界';
            app.ThermalPanel.Position = [10 550 450 65];
            app.ThermalPanel.BackgroundColor = [1 1 1];
            app.StackTemperatureLabel = uilabel(app.ThermalPanel);
            app.StackTemperatureLabel.Position = [10 20 145 22];
            app.StackTemperatureLabel.Text = '堆温/加湿温度 (C):';
            app.StackTemperatureEditField = ...
                uieditfield(app.ThermalPanel, 'numeric');
            app.StackTemperatureEditField.Position = [155 20 85 22];
            app.StackTemperatureEditField.Value = ...
                params.thermal.stack_temperature_set_C.value;
            app.StackTemperatureEditField.ValueChangedFcn = ...
                createCallbackFcn(app, @StackTemperatureChanged, true);

            % The third configuration mode keeps the full platform inventory
            % separate from condition and control inputs.
            app.FutureDomainsPanel = uipanel(app.ConfigCanvas);
            app.FutureDomainsPanel.Title = '系统模型参数（设备参数目录）';
            app.FutureDomainsPanel.Position = [10 100 450 1200];
            app.FutureDomainsPanel.BackgroundColor = [0.97 0.97 0.97];
            app.ParameterCatalogIntroLabel = uilabel(app.FutureDomainsPanel);
            app.ParameterCatalogIntroLabel.Position = [10 1155 430 34];
            app.ParameterCatalogIntroLabel.Text = { ...
                '设备性能参数：电堆 / 空压机 / 加湿器 / 阀门 / 热管理'; ...
                '工况与控制输入仍在基础、高级页设置；本页按接入状态展示'};
            app.ParameterCatalogIntroLabel.FontColor = [0.20 0.25 0.30];
            app.ParameterCatalogIntroLabel.FontSize = 10;
            app.ParameterCatalogStatusLabel = uilabel(app.FutureDomainsPanel);
            app.ParameterCatalogStatusLabel.Position = [10 1125 430 20];
            app.ParameterCatalogStatusLabel.FontColor = [0.35 0.35 0.35];
            registry = routeA_parameter_registry(app.platformPaths);
            app.ParameterCatalogStatusLabel.Text = sprintf( ...
                '目录：active %d 可沿统一链应用；inventory %d 只读待设备接口接入', ...
                registry.activeCount, registry.inventoryCount);
            app.ParameterCatalogTable = uitable(app.FutureDomainsPanel);
            app.ParameterCatalogTable.Position = [10 10 430 1095];
            app.ParameterCatalogTable.ColumnName = { ...
                'canonicalName', '参数含义（中文）', '设备 / 域', '单位', ...
                '默认', '开放状态', '应用方式', '模型映射'};
            app.ParameterCatalogTable.ColumnWidth = ...
                {195, 190, 105, 70, 85, 100, 110, 230};
            app.ParameterCatalogTable.RowName = {};
            app.ParameterCatalogTable.ColumnEditable = false(1, 8);
            app.ParameterCatalogTable.Data = app.buildParameterCatalogData(registry);
            app.FutureDomainsPanel.Visible = 'off';

            app.HelpPanel = uipanel(app.ConfigCanvas);
            app.HelpPanel.Title = '帮助与输入说明';
            app.HelpPanel.Position = [10 100 450 1200];
            app.HelpPanel.BackgroundColor = [1 1 1];
            if isprop(app.HelpPanel, 'Scrollable')
                app.HelpPanel.Scrollable = 'off';
            end
            app.HelpTextArea = uitextarea(app.HelpPanel);
            app.HelpTextArea.Position = [10 10 430 1155];
            app.HelpTextArea.Editable = 'off';
            app.HelpTextArea.FontSize = 11;
            app.HelpTextArea.Value = app.defaultHelpText();
            app.HelpPanel.Visible = 'off';

            % Advanced panel. It replaces the compact panels while selected,
            % keeping one active source for every field used by Run.
            app.AdvancedPanel = uipanel(app.ConfigCanvas);
            app.AdvancedPanel.Title = '高级参数（按域分组）';
            app.AdvancedPanel.Position = [10 100 450 1320];
            app.AdvancedPanel.BackgroundColor = [1 1 1];
            app.AdvancedPanel.Visible = 'off';
            if isprop(app.AdvancedPanel, 'Scrollable')
                app.AdvancedPanel.Scrollable = 'off';
            end

            sectionLabel = uilabel(app.AdvancedPanel);
            sectionLabel.Position = [10 1285 420 22];
            sectionLabel.Text = '0  系统性能参数（P3 首轮开放）';
            sectionLabel.FontWeight = 'bold';
            sectionLabel.FontColor = [0.12 0.25 0.38];

            app.AdvancedCegrKpLabel = uilabel(app.AdvancedPanel);
            app.AdvancedCegrKpLabel.Position = [10 1250 135 22];
            app.AdvancedCegrKpLabel.Text = 'cEGR PI Kp (m^2):';
            app.AdvancedCegrKpEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedCegrKpEditField.Position = [145 1250 80 22];
            app.AdvancedCegrKpEditField.Value = params.cegr.control.Kp_area.value;
            app.AdvancedCegrKpEditField.Limits = [eps Inf];
            app.AdvancedCegrKpEditField.Tooltip = ...
                'cEGR 目标比例 PI 比例增益；合法范围为正值；写入 routeA_egr_control_Kp_area。';

            app.AdvancedCegrKiLabel = uilabel(app.AdvancedPanel);
            app.AdvancedCegrKiLabel.Position = [240 1250 110 22];
            app.AdvancedCegrKiLabel.Text = 'cEGR PI Ki (m^2/s):';
            app.AdvancedCegrKiEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedCegrKiEditField.Position = [350 1250 90 22];
            app.AdvancedCegrKiEditField.Value = params.cegr.control.Ki_area.value;
            app.AdvancedCegrKiEditField.Limits = [eps Inf];
            app.AdvancedCegrKiEditField.Tooltip = ...
                'cEGR 目标比例 PI 积分增益；合法范围为正值；写入 routeA_egr_control_Ki_area。';

            app.AdvancedCegrActuatorTauLabel = uilabel(app.AdvancedPanel);
            app.AdvancedCegrActuatorTauLabel.Position = [10 1215 135 22];
            app.AdvancedCegrActuatorTauLabel.Text = '阀执行器 tau (s):';
            app.AdvancedCegrActuatorTauEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedCegrActuatorTauEditField.Position = [145 1215 80 22];
            app.AdvancedCegrActuatorTauEditField.Value = params.cegr.actuator_tau_s.value;
            app.AdvancedCegrActuatorTauEditField.Limits = [eps Inf];
            app.AdvancedCegrActuatorTauEditField.Tooltip = ...
                'cEGR 阀一阶执行器时间常数；合法范围为正值；写入 routeA_egr_valve_actuator_tau。';

            app.AdvancedStackNumCellsLabel = uilabel(app.AdvancedPanel);
            app.AdvancedStackNumCellsLabel.Position = [240 1215 110 22];
            app.AdvancedStackNumCellsLabel.Text = '单体数量 (-):';
            app.AdvancedStackNumCellsEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedStackNumCellsEditField.Position = [350 1215 90 22];
            app.AdvancedStackNumCellsEditField.Value = params.stack.num_cells.value;
            app.AdvancedStackNumCellsEditField.Limits = [1 1000];
            app.AdvancedStackNumCellsEditField.Tooltip = ...
                '电堆串联单体数量；合法范围为 1-1000 的整数；写入 stack_num_cells。';

            app.AdvancedStackAreaLabel = uilabel(app.AdvancedPanel);
            app.AdvancedStackAreaLabel.Position = [10 1180 135 22];
            app.AdvancedStackAreaLabel.Text = '单体面积 (cm^2):';
            app.AdvancedStackAreaEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedStackAreaEditField.Position = [145 1180 80 22];
            app.AdvancedStackAreaEditField.Value = params.stack.area_cm2.value;
            app.AdvancedStackAreaEditField.Limits = [1 1000];
            app.AdvancedStackAreaEditField.Tooltip = ...
                '每个电堆单体的有效活性面积；合法范围为 1-1000 cm^2；写入 stack_area。';

            app.AdvancedStackILabel = uilabel(app.AdvancedPanel);
            app.AdvancedStackILabel.Position = [240 1180 110 22];
            app.AdvancedStackILabel.Text = '极限 iL (A/cm^2):';
            app.AdvancedStackIEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedStackIEditField.Position = [350 1180 90 22];
            app.AdvancedStackIEditField.Value = params.stack.iL_A_cm2.value;
            app.AdvancedStackIEditField.Limits = [1e-3 5];
            app.AdvancedStackIEditField.Tooltip = ...
                '电化学极限电流密度；合法范围为 0.001-5 A/cm^2；写入 stack_iL。';

            app.AdvancedStackIoLabel = uilabel(app.AdvancedPanel);
            app.AdvancedStackIoLabel.Position = [10 1145 135 22];
            app.AdvancedStackIoLabel.Text = '交换 i0 (A/cm^2):';
            app.AdvancedStackIoEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedStackIoEditField.Position = [145 1145 80 22];
            app.AdvancedStackIoEditField.Value = params.stack.io_A_cm2.value;
            app.AdvancedStackIoEditField.Limits = [1e-8 0.1];
            app.AdvancedStackIoEditField.Tooltip = ...
                '电化学交换电流密度；合法范围为 1e-8-0.1 A/cm^2；写入 stack_io。';

            app.AdvancedPerformanceStatusLabel = uilabel(app.AdvancedPanel);
            app.AdvancedPerformanceStatusLabel.Position = [10 1105 430 30];
            app.AdvancedPerformanceStatusLabel.FontSize = 9;
            app.AdvancedPerformanceStatusLabel.FontColor = [0.35 0.35 0.35];
            app.AdvancedPerformanceStatusLabel.Text = ...
                '系统性能：7 项输入已接入 SimulationInput；设备目录其余项保持只读。';

            sectionLabel = uilabel(app.AdvancedPanel);
            sectionLabel.Position = [10 1018 420 22];
            sectionLabel.Text = '1  电边界与电压控制';
            sectionLabel.FontWeight = 'bold';
            sectionLabel.FontColor = [0.12 0.25 0.38];
            sectionLabel = uilabel(app.AdvancedPanel);
            sectionLabel.Position = [10 830 420 22];
            sectionLabel.Text = '2  阴极进气、组分与湿度';
            sectionLabel.FontWeight = 'bold';
            sectionLabel.FontColor = [0.12 0.25 0.38];
            sectionLabel = uilabel(app.AdvancedPanel);
            sectionLabel.Position = [10 575 420 22];
            sectionLabel.Text = '3  cEGR 目标比例与阀控制';
            sectionLabel.FontWeight = 'bold';
            sectionLabel.FontColor = [0.12 0.25 0.38];
            sectionLabel = uilabel(app.AdvancedPanel);
            sectionLabel.Position = [10 430 420 22];
            sectionLabel.Text = '4  热边界与数值求解';
            sectionLabel.FontWeight = 'bold';
            sectionLabel.FontColor = [0.12 0.25 0.38];
            sectionLabel = uilabel(app.AdvancedPanel);
            sectionLabel.Position = [10 280 420 22];
            sectionLabel.Text = '5  阳极系统输入（10 项已接入）';
            sectionLabel.FontWeight = 'bold';
            sectionLabel.FontColor = [0.12 0.25 0.38];

            app.AdvancedBoundaryModeLabel = uilabel(app.AdvancedPanel);
            app.AdvancedBoundaryModeLabel.Position = [10 985 70 22];
            app.AdvancedBoundaryModeLabel.Text = '电边界:';
            app.AdvancedBoundaryModeDropDown = uidropdown(app.AdvancedPanel);
            app.AdvancedBoundaryModeDropDown.Items = {'Current', 'Power', 'Voltage'};
            app.AdvancedBoundaryModeDropDown.Value = 'Current';
            app.AdvancedBoundaryModeDropDown.Position = [80 985 100 22];
            app.AdvancedBoundaryModeDropDown.ValueChangedFcn = ...
                createCallbackFcn(app, @AdvancedBoundaryModeChanged, true);

            app.AdvancedBoundaryCommandLabel = uilabel(app.AdvancedPanel);
            app.AdvancedBoundaryCommandLabel.Position = [195 985 65 22];
            app.AdvancedBoundaryCommandLabel.Text = '命令:';
            app.AdvancedBoundaryCommandEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedBoundaryCommandEditField.Position = [260 985 80 22];
            app.AdvancedBoundaryCommandEditField.Value = ...
                params.controls.current_default_ref_A.value;
            app.AdvancedBoundaryUnitLabel = uilabel(app.AdvancedPanel);
            app.AdvancedBoundaryUnitLabel.Position = [345 985 45 22];
            app.AdvancedBoundaryUnitLabel.Text = 'A';

            app.AdvancedRampDurationLabel = uilabel(app.AdvancedPanel);
            app.AdvancedRampDurationLabel.Position = [10 950 70 22];
            app.AdvancedRampDurationLabel.Text = '斜坡 (s):';
            app.AdvancedRampDurationEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedRampDurationEditField.Position = [80 950 100 22];
            app.AdvancedRampDurationEditField.Value = ...
                params.numerics.startupRampDuration_s.value;

            app.AdvancedOerLabel = uilabel(app.AdvancedPanel);
            app.AdvancedOerLabel.Position = [300 795 70 22];
            app.AdvancedOerLabel.Text = 'OER (-):';
            app.AdvancedOerEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedOerEditField.Position = [375 795 80 22];
            app.AdvancedOerEditField.Value = params.controls.target_oer.value;
            app.AdvancedOerEditField.Tooltip = ...
                '模式 2：OER 为无量纲氧过量比，模型按电流换算目标流量后驱动空压机';

            app.AdvancedBackpressureLabel = uilabel(app.AdvancedPanel);
            app.AdvancedBackpressureLabel.Position = [10 690 145 22];
            app.AdvancedBackpressureLabel.Text = '背压 (MPa(abs)):';
            app.AdvancedBackpressureEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedBackpressureEditField.Position = [155 690 85 22];
            app.AdvancedBackpressureEditField.Value = ...
                params.controls.backpressure_MPa_abs.value;
            app.AdvancedHumidifierRHLabel = uilabel(app.AdvancedPanel);
            app.AdvancedHumidifierRHLabel.Position = [300 690 115 22];
            app.AdvancedHumidifierRHLabel.Text = '加湿器出口 RH (-):';
            app.AdvancedHumidifierRHEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedHumidifierRHEditField.Position = [420 690 80 22];
            app.AdvancedHumidifierRHEditField.Value = ...
                params.cathode.humidifier.default_rh.value;

            app.AdvancedCegrRatioLabel = uilabel(app.AdvancedPanel);
            app.AdvancedCegrRatioLabel.Position = [10 540 100 22];
            app.AdvancedCegrRatioLabel.Text = 'cEGR 比 (-):';
            app.AdvancedCegrRatioEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedCegrRatioEditField.Position = [110 540 100 22];
            app.AdvancedCegrRatioEditField.Value = ...
                params.controls.cegr_target_ratio.value;
            app.AdvancedCegrEnabledCheckBox = uicheckbox(app.AdvancedPanel);
            app.AdvancedCegrEnabledCheckBox.Text = '启用 cEGR';
            app.AdvancedCegrEnabledCheckBox.Position = [300 540 120 22];
            app.AdvancedCegrEnabledCheckBox.Value = ...
                logical(params.controls.cegr_enabled.value);
            app.AdvancedCegrEnabledCheckBox.ValueChangedFcn = ...
                createCallbackFcn(app, @AdvancedCegrEnabledChanged, true);

            app.AdvancedStopTimeLabel = uilabel(app.AdvancedPanel);
            app.AdvancedStopTimeLabel.Position = [300 390 70 22];
            app.AdvancedStopTimeLabel.Text = '时长 (s):';
            app.AdvancedStopTimeEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedStopTimeEditField.Position = [375 390 80 22];
            app.AdvancedStopTimeEditField.Value = params.numerics.stopTime_s.value;
            app.AdvancedO2Label = uilabel(app.AdvancedPanel);
            app.AdvancedO2Label.Position = [10 655 100 22];
            app.AdvancedO2Label.Text = 'O2 分数 (-):';
            app.AdvancedO2EditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedO2EditField.Position = [115 655 85 22];
            app.AdvancedO2EditField.Value = params.environment.o2_mole_fraction.value;

            app.AdvancedH2OLabel = uilabel(app.AdvancedPanel);
            app.AdvancedH2OLabel.Position = [300 655 115 22];
            app.AdvancedH2OLabel.Text = 'H2O 分数 (-):';
            app.AdvancedH2OEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedH2OEditField.Position = [420 655 80 22];
            app.AdvancedH2OEditField.Value = params.environment.h2o_mole_fraction.value;

            app.AdvancedKpLabel = uilabel(app.AdvancedPanel);
            app.AdvancedKpLabel.Position = [10 915 90 22];
            app.AdvancedKpLabel.Text = 'Kp (A/V):';
            app.AdvancedKpEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedKpEditField.Position = [105 915 95 22];
            app.AdvancedKpEditField.Value = params.controls.voltage_pi_Kp.value;

            app.AdvancedKiLabel = uilabel(app.AdvancedPanel);
            app.AdvancedKiLabel.Position = [300 915 115 22];
            app.AdvancedKiLabel.Text = 'Ki (A/V/s):';
            app.AdvancedKiEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedKiEditField.Position = [420 915 80 22];
            app.AdvancedKiEditField.Value = params.controls.voltage_pi_Ki.value;
            app.AdvancedCurrentMinLabel = uilabel(app.AdvancedPanel);
            app.AdvancedCurrentMinLabel.Position = [10 880 90 22];
            app.AdvancedCurrentMinLabel.Text = 'I min (A):';
            app.AdvancedCurrentMinEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedCurrentMinEditField.Position = [105 880 95 22];
            app.AdvancedCurrentMinEditField.Value = ...
                params.controls.voltage_current_min_A.value;

            app.AdvancedCurrentMaxLabel = uilabel(app.AdvancedPanel);
            app.AdvancedCurrentMaxLabel.Position = [300 880 115 22];
            app.AdvancedCurrentMaxLabel.Text = 'I max (A):';
            app.AdvancedCurrentMaxEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedCurrentMaxEditField.Position = [420 880 80 22];
            app.AdvancedCurrentMaxEditField.Value = ...
                params.controls.voltage_current_max_A.value;

            app.AdvancedStackTemperatureLabel = uilabel(app.AdvancedPanel);
            app.AdvancedStackTemperatureLabel.Position = [10 390 130 22];
            app.AdvancedStackTemperatureLabel.Text = '堆温/加湿温度 (C):';
            app.AdvancedStackTemperatureEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedStackTemperatureEditField.Position = [145 390 85 22];
            app.AdvancedStackTemperatureEditField.Value = ...
                params.thermal.stack_temperature_set_C.value;
            app.AdvancedStackTemperatureEditField.Tooltip = ...
                ['当前模型同一 T_stack 信号同时作为冷却控制温度和阴极加湿器 ', ...
                 'TIn 温度参考；写入 stack_temperature_set_C'];

            % Advanced air path controls. They remain in one scrollable domain
            % panel so adding future controls does not compress the run area.
            app.AdvancedAirControlModeLabel = uilabel(app.AdvancedPanel);
            app.AdvancedAirControlModeLabel.Position = [10 795 100 22];
            app.AdvancedAirControlModeLabel.Text = '空气模式:';
            app.AdvancedAirControlModeDropDown = uidropdown(app.AdvancedPanel);
            app.AdvancedAirControlModeDropDown.Items = ...
                {'质量流量', 'OER', '空压机命令'};
            app.AdvancedAirControlModeDropDown.ItemsData = [1 2 3];
            app.AdvancedAirControlModeDropDown.Value = ...
                params.controls.air_control_mode.value;
            app.AdvancedAirControlModeDropDown.Position = [110 795 130 22];
            app.AdvancedAirControlModeDropDown.ValueChangedFcn = ...
                createCallbackFcn(app, @AdvancedAirControlModeChanged, true);

            app.AdvancedTargetMdotLabel = uilabel(app.AdvancedPanel);
            app.AdvancedTargetMdotLabel.Position = [10 760 130 22];
            app.AdvancedTargetMdotLabel.Text = '目标流量 (kg/s):';
            app.AdvancedTargetMdotEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedTargetMdotEditField.Position = [145 760 85 22];
            app.AdvancedTargetMdotEditField.Value = ...
                params.controls.target_mdot_kg_s.value;
            app.AdvancedTargetMdotEditField.Tooltip = ...
                '模式 1：空压机入口质量流量目标；模型再经流量控制环驱动空压机';

            app.AdvancedDirectCommandLabel = uilabel(app.AdvancedPanel);
            app.AdvancedDirectCommandLabel.Position = [10 725 130 22];
            app.AdvancedDirectCommandLabel.Text = '空压机命令 (0-1):';
            app.AdvancedDirectCommandEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedDirectCommandEditField.Position = [145 725 85 22];
            app.AdvancedDirectCommandEditField.Value = ...
                params.controls.air_direct_command.value;
            app.AdvancedDirectCommandEditField.Tooltip = ...
                ['模式 3：直接给空压机归一化执行命令；仍经过压缩机图谱，', ...
                 '不是直接给电堆气体'];

            app.AdvancedSourcePressureLabel = uilabel(app.AdvancedPanel);
            app.AdvancedSourcePressureLabel.Position = [300 760 115 22];
            app.AdvancedSourcePressureLabel.Text = '源压力 (MPa(abs)):';
            app.AdvancedSourcePressureEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedSourcePressureEditField.Position = [420 760 80 22];
            app.AdvancedSourcePressureEditField.Value = ...
                params.controls.cathode_source_pressure_MPa_abs.value;

            app.AdvancedSourceTemperatureLabel = uilabel(app.AdvancedPanel);
            app.AdvancedSourceTemperatureLabel.Position = [300 725 115 22];
            app.AdvancedSourceTemperatureLabel.Text = '源温度 (C):';
            app.AdvancedSourceTemperatureEditField = ...
                uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedSourceTemperatureEditField.Position = [420 725 80 22];
            app.AdvancedSourceTemperatureEditField.Value = ...
                params.controls.cathode_source_temperature_C.value;
            app.AdvancedSourceTemperatureEditField.Tooltip = ...
                '新鲜空气源边界温度；不是加湿器出口/阴极入口 RH 的温度参考';

            app.AdvancedHumidifierEnabledCheckBox = uicheckbox(app.AdvancedPanel);
            app.AdvancedHumidifierEnabledCheckBox.Text = '启用加湿器';
            app.AdvancedHumidifierEnabledCheckBox.Position = [300 620 150 22];
            app.AdvancedHumidifierEnabledCheckBox.Value = ...
                logical(params.cathode.humidifier.enabled.value);
            app.AdvancedHumidifierEnabledCheckBox.ValueChangedFcn = ...
                createCallbackFcn(app, @AdvancedHumidifierEnabledChanged, true);

            % Solver controls are explicit advanced inputs; the model remains
            % untouched and receives them only through SimulationInput.
            app.AdvancedSolverLabel = uilabel(app.AdvancedPanel);
            app.AdvancedSolverLabel.Position = [10 355 70 22];
            app.AdvancedSolverLabel.Text = '求解器:';
            app.AdvancedSolverDropDown = uidropdown(app.AdvancedPanel);
            % The active Route A assembly validates and runs one solver
            % contract only. Do not expose solver choices that fail later.
            app.AdvancedSolverDropDown.Items = {'VariableStepAuto'};
            app.AdvancedSolverDropDown.Value = char(params.numerics.solver.value);
            app.AdvancedSolverDropDown.Position = [80 355 130 22];
            app.AdvancedSolverDropDown.Enable = 'off';
            app.AdvancedSolverDropDown.Tooltip = ...
                '当前模型固定使用 VariableStepAuto；后续扩展 runner 后再开放选择';
            app.AdvancedRelTolLabel = uilabel(app.AdvancedPanel);
            app.AdvancedRelTolLabel.Position = [300 355 70 22];
            app.AdvancedRelTolLabel.Text = 'RelTol:';
            app.AdvancedRelTolEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedRelTolEditField.Position = [375 355 80 22];
            app.AdvancedRelTolEditField.Value = params.numerics.relTol.value;

            app.AdvancedAbsTolLabel = uilabel(app.AdvancedPanel);
            app.AdvancedAbsTolLabel.Position = [10 320 70 22];
            app.AdvancedAbsTolLabel.Text = 'AbsTol:';
            app.AdvancedAbsTolEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedAbsTolEditField.Position = [80 320 130 22];
            app.AdvancedAbsTolEditField.Value = params.numerics.absTol.value;
            app.AdvancedMaxStepLabel = uilabel(app.AdvancedPanel);
            app.AdvancedMaxStepLabel.Position = [300 320 70 22];
            app.AdvancedMaxStepLabel.Text = 'MaxStep:';
            app.AdvancedMaxStepEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AdvancedMaxStepEditField.Position = [375 320 80 22];
            app.AdvancedMaxStepEditField.Value = params.numerics.maxStep_s.value;

            app.AdvancedCegrValveModeLabel = uilabel(app.AdvancedPanel);
            app.AdvancedCegrValveModeLabel.Position = [10 505 100 22];
            app.AdvancedCegrValveModeLabel.Text = 'cEGR 阀模式:';
            app.AdvancedCegrValveModeDropDown = uidropdown(app.AdvancedPanel);
            app.AdvancedCegrValveModeDropDown.Items = {'开度', '压力'};
            app.AdvancedCegrValveModeDropDown.ItemsData = [1 2];
            app.AdvancedCegrValveModeDropDown.Value = ...
                params.controls.cegr_valve_mode.value;
            app.AdvancedCegrValveModeDropDown.Position = [110 505 100 22];
            app.AdvancedCegrControlModeLabel = uilabel(app.AdvancedPanel);
            app.AdvancedCegrControlModeLabel.Position = [300 505 70 22];
            app.AdvancedCegrControlModeLabel.Text = '控制模式:';
            app.AdvancedCegrControlModeDropDown = uidropdown(app.AdvancedPanel);
            app.AdvancedCegrControlModeDropDown.Items = {'目标比例'};
            app.AdvancedCegrControlModeDropDown.ItemsData = 1;
            app.AdvancedCegrControlModeDropDown.Value = ...
                params.controls.cegr_control_mode.value;
            app.AdvancedCegrControlModeDropDown.Position = [375 505 80 22];

            app.AdvancedCegrTargetInputModeLabel = uilabel(app.AdvancedPanel);
            app.AdvancedCegrTargetInputModeLabel.Position = [10 470 100 22];
            app.AdvancedCegrTargetInputModeLabel.Text = '目标输入:';
            app.AdvancedCegrTargetInputModeDropDown = uidropdown(app.AdvancedPanel);
            app.AdvancedCegrTargetInputModeDropDown.Items = {'cEGR 比例'};
            app.AdvancedCegrTargetInputModeDropDown.ItemsData = 1;
            app.AdvancedCegrTargetInputModeDropDown.Value = 1;
            app.AdvancedCegrTargetInputModeDropDown.Position = [110 470 100 22];

            % Anode controls are part of the current advanced interface.
            % They feed the same runtime profile assembled by the panel
            % runner; the result side remains status-only until signals are
            % confirmed in the active model.
            anodeSectionLabel = uilabel(app.AdvancedPanel);
            anodeSectionLabel.Position = [10 260 420 16];
            anodeSectionLabel.Text = '输入已接入统一 profile；观测保持 status-only';
            anodeSectionLabel.FontSize = 9;
            anodeSectionLabel.FontWeight = 'normal';
            anodeSectionLabel.FontColor = [0.15 0.25 0.35];

            anodeSourcePressureLabel = uilabel(app.AdvancedPanel);
            anodeSourcePressureLabel.Position = [10 240 135 22];
            anodeSourcePressureLabel.Text = '源压力 (MPa(abs)):';
            anodeSourcePressureLabel.FontSize = 10;
            app.AnodeSourcePressureEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AnodeSourcePressureEditField.Position = [145 240 85 22];
            app.AnodeSourcePressureEditField.Value = params.controls.anode_source_pressure_MPa_abs.value;
            app.AnodeSourcePressureEditField.Limits = [0.2 0.5];
            app.AnodeSourcePressureEditField.Tooltip = ...
                '阳极氢源压力；合法范围 0.2-0.5 MPa(abs)；写入 routeA_command_profile.anode_source_pressure_MPa_abs。';

            anodeSourceTemperatureLabel = uilabel(app.AdvancedPanel);
            anodeSourceTemperatureLabel.Position = [230 240 110 22];
            anodeSourceTemperatureLabel.Text = '源温度 (degC):';
            anodeSourceTemperatureLabel.FontSize = 10;
            app.AnodeSourceTemperatureEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AnodeSourceTemperatureEditField.Position = [345 240 85 22];
            app.AnodeSourceTemperatureEditField.Value = params.controls.anode_source_temperature_C.value;
            app.AnodeSourceTemperatureEditField.Limits = [10 60];
            app.AnodeSourceTemperatureEditField.Tooltip = ...
                '阳极氢源温度；合法范围 10-60 degC；写入 routeA_command_profile.anode_source_temperature_C。';

            anodeH2Label = uilabel(app.AdvancedPanel);
            anodeH2Label.Position = [10 205 105 22];
            anodeH2Label.Text = 'H2 分数 (-):';
            anodeH2Label.FontSize = 10;
            app.AnodeH2EditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AnodeH2EditField.Position = [115 205 85 22];
            app.AnodeH2EditField.Value = params.anode.tank.yH2.value;
            app.AnodeH2EditField.Limits = [0.9 1];
            app.AnodeH2EditField.Tooltip = ...
                '阳极氢气摩尔分数；合法范围 0.9-1.0；写入 tank_yH2，并同步保留在阳极 profile 字段。';

            anodeInletPressureLabel = uilabel(app.AdvancedPanel);
            anodeInletPressureLabel.Position = [230 205 110 22];
            anodeInletPressureLabel.Text = '入口压力 (MPa(abs)):';
            anodeInletPressureLabel.FontSize = 10;
            app.AnodeInletPressureEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AnodeInletPressureEditField.Position = [345 205 85 22];
            app.AnodeInletPressureEditField.Value = params.anode.default_pressure_MPa_abs.value;
            app.AnodeInletPressureEditField.Limits = [0.1 0.3];
            app.AnodeInletPressureEditField.Tooltip = ...
                '阳极入口压力设定；合法范围 0.1-0.3 MPa(abs)，且必须低于源压力；写入 routeA_command_profile.anode_inlet_pressure_MPa_abs。';

            anodeRhLabel = uilabel(app.AdvancedPanel);
            anodeRhLabel.Position = [10 170 115 22];
            anodeRhLabel.Text = '阳极 RH (-):';
            anodeRhLabel.FontSize = 10;
            app.AnodeHumidifierRHEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AnodeHumidifierRHEditField.Position = [130 170 70 22];
            app.AnodeHumidifierRHEditField.Value = params.anode.humidifier.default_rh.value;
            app.AnodeHumidifierRHEditField.Limits = [0 1];
            app.AnodeHumidifierRHEditField.Tooltip = ...
                '阳极加湿器出口/入口相对湿度比例；合法范围 0-1；写入 routeA_command_profile.anode_humidifier_rh。';

            anodeRecircBaseLabel = uilabel(app.AdvancedPanel);
            anodeRecircBaseLabel.Position = [230 170 110 22];
            anodeRecircBaseLabel.Text = '回流基础 (-):';
            anodeRecircBaseLabel.FontSize = 10;
            app.AnodeRecirculationBaseEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AnodeRecirculationBaseEditField.Position = [345 170 85 22];
            app.AnodeRecirculationBaseEditField.Value = params.anode.recirculation.base_command.value;
            app.AnodeRecirculationBaseEditField.Limits = [0 1];
            app.AnodeRecirculationBaseEditField.Tooltip = ...
                '阳极回流基础归一化命令；合法范围 0-1；写入 routeA_command_profile.anode_recirculation_base。';

            anodeRecircGainLabel = uilabel(app.AdvancedPanel);
            anodeRecircGainLabel.Position = [10 135 130 22];
            anodeRecircGainLabel.Text = '回流增益 (1/A):';
            anodeRecircGainLabel.FontSize = 10;
            app.AnodeRecirculationGainEditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AnodeRecirculationGainEditField.Position = [140 135 70 22];
            app.AnodeRecirculationGainEditField.Value = params.anode.recirculation.current_gain_A_inv.value;
            app.AnodeRecirculationGainEditField.Limits = [0 1];
            app.AnodeRecirculationGainEditField.Tooltip = ...
                '阳极回流电流补偿增益；合法范围 0-1 1/A；写入 routeA_command_profile.anode_recirculation_current_gain_A_inv。';

            app.AnodePurgeEnabledCheckBox = uicheckbox(app.AdvancedPanel);
            app.AnodePurgeEnabledCheckBox.Position = [230 135 200 22];
            app.AnodePurgeEnabledCheckBox.Text = '启用阳极吹扫';
            app.AnodePurgeEnabledCheckBox.Value = logical(params.anode.purge.enabled.value);
            app.AnodePurgeEnabledCheckBox.Tooltip = ...
                '阳极吹扫开关；关闭时阈值保留但本次不生效；写入 routeA_command_profile.anode_purge_enable。';
            app.AnodePurgeEnabledCheckBox.ValueChangedFcn = ...
                createCallbackFcn(app, @AnodePurgeEnabledChanged, true);

            anodePurgeOnLabel = uilabel(app.AdvancedPanel);
            anodePurgeOnLabel.Position = [10 100 130 22];
            anodePurgeOnLabel.Text = '吹扫开阈值 (-):';
            anodePurgeOnLabel.FontSize = 10;
            app.AnodePurgeOnN2EditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AnodePurgeOnN2EditField.Position = [140 100 70 22];
            app.AnodePurgeOnN2EditField.Value = params.anode.purge.on_n2_mole_fraction.value;
            app.AnodePurgeOnN2EditField.Limits = [0 1];
            app.AnodePurgeOnN2EditField.Tooltip = ...
                '阳极吹扫开启 N2 摩尔分数阈值；合法范围 0-1，且必须高于关闭阈值；写入 command profile。';

            anodePurgeOffLabel = uilabel(app.AdvancedPanel);
            anodePurgeOffLabel.Position = [230 100 110 22];
            anodePurgeOffLabel.Text = '吹扫关阈值 (-):';
            anodePurgeOffLabel.FontSize = 10;
            app.AnodePurgeOffN2EditField = uieditfield(app.AdvancedPanel, 'numeric');
            app.AnodePurgeOffN2EditField.Position = [345 100 85 22];
            app.AnodePurgeOffN2EditField.Value = params.anode.purge.off_n2_mole_fraction.value;
            app.AnodePurgeOffN2EditField.Limits = [0 1];
            app.AnodePurgeOffN2EditField.Tooltip = ...
                '阳极吹扫关闭 N2 摩尔分数阈值；合法范围 0-1，且必须低于开启阈值；写入 command profile。';

            app.AnodeControlStatusLabel = uilabel(app.AdvancedPanel);
            app.AnodeControlStatusLabel.Position = [10 65 420 22];
            app.AnodeControlStatusLabel.FontSize = 9;
            app.AnodeControlStatusLabel.FontColor = [0.35 0.35 0.35];
            app.AnodeControlStatusLabel.Text = ...
                '阳极输入：10 项已接入统一 profile；阳极观测：status-only，待 P4 确认';
            
            % Case ID
            app.CaseIdLabel = uilabel(app.ConfigCanvas);
            app.CaseIdLabel.Position = [10 60 100 22];
            app.CaseIdLabel.Text = 'Case ID:';
            
            app.CaseIdEditField = uieditfield(app.ConfigCanvas, 'text');
            app.CaseIdEditField.Position = [110 60 200 22];
            app.CaseIdEditField.Value = 'case1';
            
            % Buttons
            app.RunButton = uibutton(app.ConfigCanvas, 'push');
            app.RunButton.Position = [10 15 170 30];
            app.RunButton.Text = '运行单工况';
            app.RunButton.FontSize = 12;
            app.RunButton.FontWeight = 'bold';
            app.RunButton.BackgroundColor = [0.2 0.6 0.2];
            app.RunButton.FontColor = [1 1 1];
            app.RunButton.ButtonPushedFcn = createCallbackFcn(app, @RunButtonPushed, true);

            app.MatrixButton = uibutton(app.ConfigCanvas, 'push');
            app.MatrixButton.Position = [190 15 100 30];
            app.MatrixButton.Text = '矩阵...';
            app.MatrixButton.FontSize = 12;
            app.MatrixButton.ButtonPushedFcn = createCallbackFcn(app, @MatrixButtonPushed, true);
            % P1 validates panel functions one independent case at a time;
            % retain the research helper but do not expose matrix execution yet.
            app.MatrixButton.Visible = 'off';
            % Result controls live in the result panel so the input canvas can
            % grow independently as new system domains are added.
            
            % Result controls live in the result panel. The selected output
            % level controls whether the explicit full result export is allowed.
            app.OutputLevelLabel = uilabel(app.RightPanel);
            app.OutputLevelLabel.Text = '结果级别:';
            app.OutputLevelDropDown = uidropdown(app.RightPanel, ...
                'Items', {'精简版（仅面板）', '完整版（显式导出）'}, ...
                'ItemsData', {'compact_panel', 'full_export'}, ...
                'Value', 'compact_panel');
            app.ClearResultsButton = uibutton(app.RightPanel, 'push');
            app.ClearResultsButton.Text = '清空结果';
            app.ClearResultsButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @ClearResultsButtonPushed, true);
            app.ExportButton = uibutton(app.RightPanel, 'push');
            app.ExportButton.Text = '导出完整结果';
            app.ExportButton.Enable = 'off';
            app.ExportButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @ExportResultButtonPushed, true);

            % Domain result tabs. New result domains should add a tab and a
            % registry-backed table here without changing the main shell.
            app.ResultTabGroup = uitabgroup(app.RightPanel);
            app.OverviewTab = uitab(app.ResultTabGroup, 'Title', '总览');
            app.CathodeResultTab = uitab(app.ResultTabGroup, 'Title', '阴极');
            app.CegrResultTab = uitab(app.ResultTabGroup, 'Title', 'cEGR');
            app.ThermalWaterResultTab = uitab(app.ResultTabGroup, 'Title', '热 / 水');
            app.TraceTab = uitab(app.ResultTabGroup, 'Title', '结果图像');
            app.DiagnosticsTab = uitab(app.ResultTabGroup, 'Title', '追溯 / 诊断');

            app.DomainStatusTable = uitable(app.OverviewTab);
            app.DomainStatusTable.ColumnName = {'系统域', '能力状态'};
            app.DomainStatusTable.ColumnWidth = {210, 440};
            app.DomainStatusTable.RowName = {};
            app.DomainStatusTable.Data = app.defaultDomainStatusRows();

            app.OverviewSummaryTextArea = uitextarea(app.OverviewTab);
            app.OverviewSummaryTextArea.Editable = 'off';
            app.OverviewSummaryTextArea.Value = { ...
                '尚未运行面板单工况。'; ...
                '结果将按系统域写入右侧分区。'};

            app.KpiTable = uitable(app.OverviewTab);
            app.KpiTable.ColumnName = {'caseId', 'V (V)', 'I (A)', 'P (kW)', ...
                'OER', 'cEGR tgt', 'cEGR act', 'EGR mdot (kg/s)', ...
                'Air mdot (kg/s)', 'Pca out (MPa)', ...
                'RH in', 'RH out', 'Water sep (kg/s)', ...
                'cEGR ability', 'status'};
            app.KpiTable.ColumnWidth = {100, 65, 65, 65, 55, 65, 65, 90, ...
                90, 90, 65, 65, 95, 130, 150};
            app.KpiTable.Data = {};

            app.CathodeResultTable = uitable(app.CathodeResultTab);
            app.CathodeResultTable.ColumnName = {'指标', '单位', 'tail mean', '来源 / 状态'};
            app.CathodeResultTable.ColumnWidth = {220, 100, 160, 250};
            app.CathodeResultTable.Data = {};

            app.CegrResultTable = uitable(app.CegrResultTab);
            app.CegrResultTable.ColumnName = {'指标', '单位', 'tail mean', '来源 / 状态'};
            app.CegrResultTable.ColumnWidth = {220, 100, 160, 250};
            app.CegrResultTable.Data = {};

            app.ThermalWaterResultTable = uitable(app.ThermalWaterResultTab);
            app.ThermalWaterResultTable.ColumnName = {'指标', '单位', '值', '来源 / 状态'};
            app.ThermalWaterResultTable.ColumnWidth = {220, 100, 160, 250};
            app.ThermalWaterResultTable.Data = {};

            app.DiagnosticsTable = uitable(app.DiagnosticsTab);
            app.DiagnosticsTable.ColumnName = {'字段', '单位', '值', '追溯语义'};
            app.DiagnosticsTable.ColumnWidth = {220, 100, 360, 250};
            app.DiagnosticsTable.Data = {};

            app.PlotModeButtonGroup = uibuttongroup(app.TraceTab);
            app.PlotModeButtonGroup.BorderType = 'none';
            app.PlotModeButtonGroup.SelectionChangedFcn = ...
                createCallbackFcn(app, @PlotModeSelectionChanged, true);
            app.CurrentPlotButton = uitogglebutton(app.PlotModeButtonGroup);
            app.CurrentPlotButton.Text = '电流-时间';
            app.CurrentPlotButton.Position = [0 0 95 26];
            app.CurrentPlotButton.Value = true;
            app.PowerPlotButton = uitogglebutton(app.PlotModeButtonGroup);
            app.PowerPlotButton.Text = '功率-时间';
            app.PowerPlotButton.Position = [95 0 95 26];
            app.VoltagePlotButton = uitogglebutton(app.PlotModeButtonGroup);
            app.VoltagePlotButton.Text = '电压-时间';
            app.VoltagePlotButton.Position = [190 0 95 26];
            app.ClearPlotHistoryButton = uibutton(app.TraceTab, 'push');
            app.ClearPlotHistoryButton.Text = '清空图像';
            app.ClearPlotHistoryButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @ClearPlotHistoryButtonPushed, true);
            app.TimeSeriesAxes = uiaxes(app.TraceTab);
            title(app.TimeSeriesAxes, '电流-时间');
            xlabel(app.TimeSeriesAxes, '时间 (s)');
            ylabel(app.TimeSeriesAxes, '电流 (A)');
            grid(app.TimeSeriesAxes, 'on');

            % Log area stays outside the tabs so it remains visible while
            % switching between result domains.
            app.LogLabel = uilabel(app.RightPanel);
            app.LogLabel.Text = '运行日志:';
            app.LogTextArea = uitextarea(app.RightPanel);
            app.LogTextArea.Value = {' > 面板已就绪，请设置参数并点击"运行单工况"'};
            app.LogTextArea.Editable = 'off';
            app.LogTextArea.FontName = 'Consolas';
            
            % Show figure after all components are created
            app.BasicModeButton.Value = true;
            app.AdvancedModeButton.Value = false;
            app.ModelParameterModeButton.Value = false;
            app.HelpModeButton.Value = false;
            app.activeConfigMode = "basic";
            app.ModeSelectionChanged(struct('NewValue', app.BasicModeButton));
            app.UIFigure.WindowState = 'maximized';
            % Lay out the maximized frame before the first visible draw so
            % the mode bar and the active page cannot flash at stale sizes.
            app.layoutFigure([]);
            app.UIFigure.Visible = 'on';
            app.updateAirControlControls(false);
            app.updateAirControlControls(true);
            app.updateHumidifierControls(false);
            app.updateHumidifierControls(true);
            app.updateCegrControls(false);
            app.updateCegrControls(true);
            app.updateVoltageControllerControls();
            app.updateAnodeControls();
            drawnow;
            app.layoutFigure([]);
            if isprop(app.ConfigScrollPanel, 'Scrollable')
                scroll(app.ConfigScrollPanel, 'top');
            end
            app.renderPlotHistory();
        end

        function BoundaryModeChanged(app, ~)
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

        function AdvancedBoundaryModeChanged(app, ~)
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
            app.updateVoltageControllerControls();
        end

        function AirControlModeChanged(app, ~)
            app.updateAirControlControls(false);
            if isvalid(app.AdvancedPanel)
                app.syncBasicToAdvanced();
            end
        end

        function AdvancedAirControlModeChanged(app, ~)
            app.updateAirControlControls(true);
        end

        function HumidifierEnabledChanged(app, ~)
            app.updateHumidifierControls(false);
            if isvalid(app.AdvancedPanel)
                app.syncBasicToAdvanced();
            end
        end

        function AdvancedHumidifierEnabledChanged(app, ~)
            app.updateHumidifierControls(true);
        end

        function HumidifierTemperatureChanged(app, ~)
            % Basic-page RH temperature is the active model's T_stack path,
            % which is also the temperature entering the cathode humidifier.
            app.StackTemperatureEditField.Value = ...
                app.SourceTemperatureEditField.Value;
        end

        function StackTemperatureChanged(app, ~)
            % Keep the duplicate basic-page presentation synchronized. Both
            % controls represent thermal.stackTemperatureSet_C; neither is a
            % second independent temperature input.
            app.SourceTemperatureEditField.Value = ...
                app.StackTemperatureEditField.Value;
        end

        function CegrEnabledChanged(app, ~)
            app.updateCegrControls(false);
            if isvalid(app.AdvancedPanel)
                app.syncBasicToAdvanced();
            end
        end

        function AdvancedCegrEnabledChanged(app, ~)
            app.updateCegrControls(true);
        end

        function updateAirControlControls(app, advanced)
            if advanced
                mode = double(app.AdvancedAirControlModeDropDown.Value);
                oer = app.AdvancedOerEditField;
                mdot = app.AdvancedTargetMdotEditField;
                direct = app.AdvancedDirectCommandEditField;
            else
                mode = double(app.AirControlModeDropDown.Value);
                oer = app.OerEditField;
                mdot = app.TargetMdotEditField;
                direct = app.DirectCommandEditField;
            end
            oer.Enable = app.enableState(mode == 2);
            mdot.Enable = app.enableState(mode == 1);
            direct.Enable = app.enableState(mode == 3);
        end

        function updateHumidifierControls(app, advanced)
            if advanced
                rh = app.AdvancedHumidifierRHEditField;
                enabled = app.AdvancedHumidifierEnabledCheckBox.Value;
            else
                rh = app.HumidifierRHEditField;
                enabled = app.HumidifierEnabledCheckBox.Value;
            end
            rh.Enable = app.enableState(logical(enabled));
            if logical(enabled)
                rh.Tooltip = ...
                    '加湿器出口/阴极入口 RH (0-1)；温度参考为同一 simCase 的加湿温度';
            else
                rh.Tooltip = '加湿器未启用；该 RH 值保留但本次运行不生效';
            end
        end

        function updateCegrControls(app, advanced)
            if advanced
                ratio = app.AdvancedCegrRatioEditField;
                enabled = app.AdvancedCegrEnabledCheckBox.Value;
                valve = app.AdvancedCegrValveModeDropDown;
                control = app.AdvancedCegrControlModeDropDown;
                targetInput = app.AdvancedCegrTargetInputModeDropDown;
            else
                ratio = app.CegrRatioEditField;
                enabled = app.CegrEnabledCheckBox.Value;
                valve = [];
                control = [];
                targetInput = [];
            end
            state = app.enableState(logical(enabled));
            ratio.Enable = state;
            if logical(enabled)
                ratio.Tooltip = '目标 cEGR 比例；运行时写入 cegr_ratio';
            else
                ratio.Tooltip = 'cEGR 未启用；本次运行目标自动按 0 处理';
            end
            if advanced
                valve.Enable = state;
                % P1 exposes only the target-ratio input and controller mode.
                % Keep these selectors visible for traceability, but prevent
                % an unsupported alternate source from being selected.
                control.Enable = 'off';
                targetInput.Enable = 'off';
                control.Tooltip = 'P1 固定为目标比例控制';
                targetInput.Tooltip = 'P1 固定使用 cEGR 比例输入';
            end
        end

        function simCase = uiBaseCase(app)
            if isstruct(app.simCase) && isscalar(app.simCase) && ...
                    isfield(app.simCase, 'controls')
                simCase = app.simCase;
            else
                simCase = routeA_simCase_template();
            end
        end

        function captureAdvancedControls(app)
            app.simCase = app.uiBaseCase();
            app.simCase.controls.electrical.mode = ...
                app.AdvancedBoundaryModeDropDown.Value;
            app.simCase.controls.electrical.profile = ...
                app.AdvancedBoundaryCommandEditField.Value;
            app.simCase.controls.electrical.voltageController = struct( ...
                'Kp_A_V', app.AdvancedKpEditField.Value, ...
                'Ki_A_V_s', app.AdvancedKiEditField.Value, ...
                'currentMin_A', app.AdvancedCurrentMinEditField.Value, ...
                'currentMax_A', app.AdvancedCurrentMaxEditField.Value);
            app.simCase.controls.cathode.airControlMode = ...
                app.AdvancedAirControlModeDropDown.Value;
            app.simCase.controls.cathode.targetOer = app.AdvancedOerEditField.Value;
            app.simCase.controls.cathode.targetMdot_kg_s = ...
                app.AdvancedTargetMdotEditField.Value;
            app.simCase.controls.cathode.directCommand = ...
                app.AdvancedDirectCommandEditField.Value;
            app.simCase.controls.cathode.sourcePressure_MPa_abs = ...
                app.AdvancedSourcePressureEditField.Value;
            app.simCase.controls.cathode.sourceTemperature_C = ...
                app.AdvancedSourceTemperatureEditField.Value;
            app.simCase.controls.cathode.outletPressure_MPa_abs = ...
                app.AdvancedBackpressureEditField.Value;
            app.simCase.controls.cathode.humidifierRH = ...
                app.AdvancedHumidifierRHEditField.Value;
            app.simCase.controls.cathode.humidifierEnabled = ...
                app.AdvancedHumidifierEnabledCheckBox.Value;
            app.simCase.controls.cathode.o2MoleFraction = ...
                app.AdvancedO2EditField.Value;
            app.simCase.controls.cathode.h2oMoleFraction = ...
                app.AdvancedH2OEditField.Value;
            app.simCase.controls.cegr.enabled = ...
                app.AdvancedCegrEnabledCheckBox.Value;
            app.simCase.controls.cegr.targetRatio = ...
                app.AdvancedCegrRatioEditField.Value;
            app.simCase.controls.cegr.valveMode = ...
                app.AdvancedCegrValveModeDropDown.Value;
            app.simCase.controls.cegr.controlMode = ...
                app.AdvancedCegrControlModeDropDown.Value;
            app.simCase.controls.cegr.targetInputMode = ...
                app.AdvancedCegrTargetInputModeDropDown.Value;
            app.simCase.controls.thermal.stackTemperatureSet_C = ...
                app.AdvancedStackTemperatureEditField.Value;
            app.simCase.controls.anode = app.collectAnodeControls();
            performance = app.collectPerformanceControls();
            app.simCase.controls.cegr.controller = performance.cegrController;
            app.simCase.controls.stack = performance.stack;
            app.simCase.solver.stopTime_s = app.AdvancedStopTimeEditField.Value;
            app.simCase.solver.solver = app.AdvancedSolverDropDown.Value;
            app.simCase.solver.relTol = app.AdvancedRelTolEditField.Value;
            app.simCase.solver.absTol = app.AdvancedAbsTolEditField.Value;
            app.simCase.solver.maxStep_s = app.AdvancedMaxStepEditField.Value;
        end

        function updateVoltageControllerControls(app)
            enabled = string(app.AdvancedBoundaryModeDropDown.Value) == "Voltage";
            value = app.enableState(enabled);
            app.AdvancedKpEditField.Enable = value;
            app.AdvancedKiEditField.Enable = value;
            app.AdvancedCurrentMinEditField.Enable = value;
            app.AdvancedCurrentMaxEditField.Enable = value;
        end

        function AnodePurgeEnabledChanged(app, ~)
            app.updateAnodeControls();
        end

        function updateAnodeControls(app)
            enabled = logical(app.AnodePurgeEnabledCheckBox.Value);
            state = app.enableState(enabled);
            app.AnodePurgeOnN2EditField.Enable = state;
            app.AnodePurgeOffN2EditField.Enable = state;
            if enabled
                app.AnodeControlStatusLabel.Text = ...
                    '阳极输入：10 项已接入统一 profile；吹扫阈值当前生效；观测 status-only';
            else
                app.AnodeControlStatusLabel.Text = ...
                    '阳极输入：10 项已接入统一 profile；吹扫关闭，阈值保留但本次不生效；观测 status-only';
            end
        end

        function anode = collectAnodeControls(app)
            anode = struct( ...
                'sourcePressure_MPa_abs', app.AnodeSourcePressureEditField.Value, ...
                'sourceTemperature_C', app.AnodeSourceTemperatureEditField.Value, ...
                'h2MoleFraction', app.AnodeH2EditField.Value, ...
                'inletPressure_MPa_abs', app.AnodeInletPressureEditField.Value, ...
                'humidifierRH', app.AnodeHumidifierRHEditField.Value, ...
                'recirculationBaseCommand', app.AnodeRecirculationBaseEditField.Value, ...
                'recirculationCurrentGain_A_inv', app.AnodeRecirculationGainEditField.Value, ...
                'purgeEnabled', app.AnodePurgeEnabledCheckBox.Value, ...
                'purgeOnN2MoleFraction', app.AnodePurgeOnN2EditField.Value, ...
                'purgeOffN2MoleFraction', app.AnodePurgeOffN2EditField.Value);
        end

        function performance = collectPerformanceControls(app)
            performance = struct();
            performance.cegrController = struct( ...
                'Kp_area', app.AdvancedCegrKpEditField.Value, ...
                'Ki_area', app.AdvancedCegrKiEditField.Value, ...
                'actuatorTau_s', app.AdvancedCegrActuatorTauEditField.Value);
            performance.stack = struct( ...
                'numCells', app.AdvancedStackNumCellsEditField.Value, ...
                'area_cm2', app.AdvancedStackAreaEditField.Value, ...
                'iL_A_cm2', app.AdvancedStackIEditField.Value, ...
                'io_A_cm2', app.AdvancedStackIoEditField.Value);
        end

        function data = buildParameterCatalogData(app, registry)
            entries = registry.entries;
            % Put equipment-performance rows first. Control defaults and
            % numerical/environment rows remain in the same complete catalog.
            deviceMask = arrayfun(@(entry) ...
                app.isDeviceCatalogEntry(entry), entries);
            entries = [entries(deviceMask), entries(~deviceMask)];
            data = cell(numel(entries), 8);
            for idx = 1:numel(entries)
                entry = entries(idx);
                mapping = strings(0, 1);
                if strlength(entry.modelWorkspaceVariable) > 0
                    mapping(end + 1) = entry.modelWorkspaceVariable;
                end
                if strlength(entry.blockParameter) > 0
                    mapping(end + 1) = entry.blockParameter;
                end
                if strlength(entry.profileField) > 0
                    mapping(end + 1) = entry.profileField;
                end
                if isempty(mapping)
                    mappingText = '-';
                else
                    mappingText = char(strjoin(mapping, ' | '));
                end
                if entry.status == "active"
                    statusText = app.catalogPanelState(entry);
                else
                    statusText = '目录只读';
                end
                data(idx, :) = {char(entry.canonicalName), ...
                    app.catalogMeaningZh(entry), ...
                    app.catalogDeviceZh(entry), char(entry.unit), ...
                    app.formatCatalogValue(entry.defaultValue), ...
                    statusText, app.catalogApplyText(entry), mappingText};
            end
        end

        function isDevice = isDeviceCatalogEntry(~, entry)
            isDevice = startsWith(string(entry.canonicalName), "platform.") && ...
                any(string(entry.domain) == ...
                ["stack", "cathode", "cegr", "anode", "thermal"]);
        end

        function textValue = catalogPanelState(~, entry)
            switch string(entry.panelExposure)
                case "basic"
                    textValue = '基础页可编辑';
                case "advanced"
                    textValue = '高级页可编辑';
                otherwise
                    textValue = '已接入';
            end
        end

        function textValue = catalogApplyText(~, entry)
            if entry.status ~= "active"
                textValue = '只读：待模型接口接入';
            elseif entry.requiresCompile == "compile"
                textValue = '运行前写入并编译';
            elseif entry.tunableClass == "study"
                textValue = '运行配置';
            else
                textValue = '运行前写入 profile';
            end
        end

        function textValue = catalogDeviceZh(app, entry)
            key = string(entry.canonicalName);
            if contains(key, ".compressor.")
                textValue = '阴极 / 空压机';
            elseif contains(key, ".intercooler.")
                textValue = '阴极 / 中冷器';
            elseif contains(key, ".humidifier.")
                if startsWith(key, "platform.anode.")
                    textValue = '阳极 / 加湿器';
                else
                    textValue = '阴极 / 加湿器';
                end
            elseif contains(key, ".separator.")
                if startsWith(key, "platform.anode.")
                    textValue = '阳极 / 分离器';
                else
                    textValue = '阴极 / 分离器';
                end
            elseif contains(key, ".radiator.")
                textValue = '热管理 / 散热器';
            elseif contains(key, ".coolant.")
                textValue = '热管理 / 冷却回路';
            elseif contains(key, ".pipe.")
                textValue = 'cEGR / 回流管路';
            elseif contains(key, ".valve") || contains(key, ".actuator")
                textValue = 'cEGR / 阀与执行器';
            elseif startsWith(key, "platform.stack.")
                textValue = '电堆 / MEA';
            elseif startsWith(key, "platform.cathode.")
                textValue = '阴极气路';
            elseif startsWith(key, "platform.anode.")
                textValue = '阳极气路';
            elseif startsWith(key, "platform.cegr.")
                textValue = 'cEGR 系统';
            elseif startsWith(key, "platform.thermal.")
                textValue = '热管理';
            else
                textValue = app.catalogDomainZh(entry);
            end
        end

        function textValue = catalogDomainZh(~, entry)
            switch string(entry.domain)
                case "electrical"
                    textValue = '电边界 / 电控';
                case "cathode"
                    textValue = '阴极气路';
                case "cegr"
                    textValue = 'cEGR 系统';
                case "anode"
                    textValue = '阳极气路';
                case "thermal"
                    textValue = '热管理';
                case "stack"
                    textValue = '电堆 / MEA';
                case "solver"
                    textValue = '求解设置';
                case "controls"
                    textValue = '控制默认值';
                case "numerics"
                    textValue = '数值设置';
                case "environment"
                    textValue = '环境参数';
                otherwise
                    textValue = char(entry.domain);
            end
        end

        function textValue = catalogMeaningZh(app, entry)
            key = string(entry.canonicalName);
            switch key
                case "electrical.mode"
                    textValue = '选择恒电流、恒功率或恒电压边界';
                case "electrical.current.profile"
                    textValue = '恒电流命令值或时序';
                case "electrical.power.profile"
                    textValue = '恒功率命令值或时序';
                case "electrical.voltage.profile"
                    textValue = '恒电压命令值或时序';
                case "electrical.voltageController.Kp_A_V"
                    textValue = '电压控制器比例增益';
                case "electrical.voltageController.Ki_A_V_s"
                    textValue = '电压控制器积分增益';
                case "electrical.voltageController.currentMin_A"
                    textValue = '电压控制器电流下限';
                case "electrical.voltageController.currentMax_A"
                    textValue = '电压控制器电流上限';
                case "cathode.airControlMode"
                    textValue = '选择质量流量、OER或直接命令控制';
                case "cathode.targetOer"
                    textValue = '新鲜空气目标氧过量比';
                case "cathode.targetMdot_kg_s"
                    textValue = '阴极新鲜空气目标质量流量';
                case "cathode.directCommand"
                    textValue = '阴极空气直接控制命令';
                case "cathode.sourcePressure_MPa_abs"
                    textValue = '阴极新鲜空气源压力';
                case "cathode.sourceTemperature_C"
                    textValue = '阴极新鲜空气源温度';
                case "cathode.outletPressure_MPa_abs"
                    textValue = '阴极出口背压设定';
                case "cathode.humidifierRH"
                    textValue = '阴极加湿器相对湿度设定';
                case "cathode.humidifierEnabled"
                    textValue = '阴极加湿器启用或旁路';
                case "cathode.o2MoleFraction"
                    textValue = '阴极入口氧气摩尔分数';
                case "cathode.h2oMoleFraction"
                    textValue = '阴极入口水蒸气摩尔分数';
                case "cegr.enabled"
                    textValue = '启用或关闭cEGR支路';
                case "cegr.targetRatio"
                    textValue = 'cEGR目标回流比例';
                case "cegr.valveMode"
                    textValue = 'cEGR阀控制方式';
                case "cegr.controlMode"
                    textValue = 'cEGR控制器工作模式';
                case "cegr.targetInputMode"
                    textValue = 'cEGR目标输入来源';
                case "cegr.controller.Kp_area"
                    textValue = 'cEGR目标比例控制器比例增益';
                case "cegr.controller.Ki_area"
                    textValue = 'cEGR目标比例控制器积分增益';
                case "cegr.actuatorTau_s"
                    textValue = 'cEGR阀一阶执行器时间常数';
                case "anode.sourcePressure_MPa_abs"
                    textValue = '氢源入口压力';
                case "anode.sourceTemperature_C"
                    textValue = '氢源入口温度';
                case "anode.h2MoleFraction"
                    textValue = '阳极氢气摩尔分数';
                case "anode.inletPressure_MPa_abs"
                    textValue = '阳极入口压力';
                case "anode.humidifierRH"
                    textValue = '阳极加湿器相对湿度设定';
                case "anode.recirculationBaseCommand"
                    textValue = '阳极回流基础命令';
                case "anode.recirculationCurrentGain_A_inv"
                    textValue = '阳极回流电流补偿增益';
                case "anode.purgeEnabled"
                    textValue = '阳极吹扫启用状态';
                case "anode.purgeOnN2MoleFraction"
                    textValue = '触发吹扫的氮气分数阈值';
                case "anode.purgeOffN2MoleFraction"
                    textValue = '停止吹扫的氮气分数阈值';
                case "stack.numCells"
                    textValue = '电堆串联单体数量';
                case "stack.area_cm2"
                    textValue = '每个单体的有效活性面积';
                case "stack.iL_A_cm2"
                    textValue = '电化学极限电流密度';
                case "stack.io_A_cm2"
                    textValue = '电化学交换电流密度';
                case "thermal.stackTemperatureSet_C"
                    textValue = '电堆冷却出口温度设定';
                case "solver.stopTime_s"
                    textValue = '仿真停止时间';
                case "solver.solver"
                    textValue = '变量步长求解器名称';
                case "solver.relTol"
                    textValue = '求解器相对容差';
                case "solver.absTol"
                    textValue = '求解器绝对容差';
                case "solver.maxStep_s"
                    textValue = '求解器最大步长';
                otherwise
                    if startsWith(key, "platform.")
                        textValue = app.catalogPlatformMeaningZh( ...
                            extractAfter(key, "platform."));
                    else
                        textValue = '模型接口参数';
                    end
            end
        end

        function textValue = catalogPlatformMeaningZh(~, path)
            path = string(path);
            switch path
                case "stack.num_cells"
                    textValue = '电堆单体数量';
                case "stack.area_cm2"
                    textValue = '单体有效活性面积';
                case "stack.iL_A_cm2"
                    textValue = '电化学极限电流密度';
                case "stack.io_A_cm2"
                    textValue = '电化学交换电流密度';
                case "stack.alpha"
                    textValue = '电荷传递系数';
                case "stack.t_gdl_um"
                    textValue = '气体扩散层厚度';
                case "stack.t_membrane_um"
                    textValue = '质子交换膜厚度';
                case "stack.num_channels"
                    textValue = '每个单体的流道数量';
                case "stack.w_channels"
                    textValue = '流道宽度';
                case "stack.mea_cp"
                    textValue = 'MEA比热容';
                case "stack.mea_rho"
                    textValue = 'MEA密度';
                case "cathode.compressor.rpm_TLU"
                    textValue = '空压机转速特性断点';
                case "cathode.compressor.p_ratio_TLU"
                    textValue = '空压机压比特性断点';
                case "cathode.compressor.mdot_corr_TLU"
                    textValue = '空压机修正流量特性表';
                case "cathode.intercooler.Dh_m"
                    textValue = '中冷器水力直径';
                case "cathode.intercooler.length_m"
                    textValue = '中冷器流道长度';
                case "cathode.intercooler.area_m2"
                    textValue = '中冷器流通面积';
                case "cathode.intercooler.mdot_nominal_kg_s"
                    textValue = '中冷器额定质量流量';
                case "cathode.intercooler.dp_nominal_MPa"
                    textValue = '中冷器额定压降';
                case "cathode.intercooler.T0_C"
                    textValue = '中冷器初始温度';
                case "cathode.mixer.volume_L"
                    textValue = '空压机入口混合腔体积';
                case "cathode.outlet_chamber.volume_L"
                    textValue = '阴极出口腔体积';
                case "cathode.backpressure.default_MPa_abs"
                    textValue = '阴极背压默认设定';
                case "cathode.humidifier.default_rh"
                    textValue = '阴极加湿器默认相对湿度';
                case "cathode.humidifier.enabled"
                    textValue = '阴极加湿器默认启用状态';
                case "cathode.separator.D_m"
                    textValue = '阴极分离器直径';
                case "cathode.separator.length_m"
                    textValue = '阴极分离器长度';
                case "cathode.separator.mdot_nominal_kg_s"
                    textValue = '阴极分离器额定流量';
                case "cathode.separator.dp_nominal_MPa"
                    textValue = '阴极分离器额定压降';
                case "cegr.valve_max_area_m2"
                    textValue = 'cEGR阀最大开口面积';
                case "cegr.valve_open_min_area_m2"
                    textValue = 'cEGR阀最小开口面积';
                case "cegr.pipe.length_m"
                    textValue = 'cEGR回流管长度';
                case "cegr.pipe.D_m"
                    textValue = 'cEGR回流管直径';
                case "cegr.pipe.area_m2"
                    textValue = 'cEGR回流管流通面积';
                case "cegr.pipe.roughness_m"
                    textValue = 'cEGR回流管表面粗糙度';
                case "cegr.actuator_tau_s"
                    textValue = 'cEGR阀执行器时间常数';
                case "cegr.control.Kp_area"
                    textValue = 'cEGR比例控制器比例增益';
                case "cegr.control.Ki_area"
                    textValue = 'cEGR比例控制器积分增益';
                case "anode.tank.p_MPa"
                    textValue = '氢气储罐压力';
                case "anode.tank.V_L"
                    textValue = '氢气储罐容积';
                case "anode.tank.T_C"
                    textValue = '氢气储罐温度';
                case "anode.tank.yH2"
                    textValue = '储罐氢气摩尔分数';
                case "anode.default_pressure_MPa_abs"
                    textValue = '阳极入口默认压力';
                case "anode.humidifier.default_rh"
                    textValue = '阳极加湿器默认相对湿度';
                case "anode.recirculation.base_command"
                    textValue = '阳极回流基础命令';
                case "anode.recirculation.current_gain_A_inv"
                    textValue = '阳极回流电流增益';
                case "anode.purge.enabled"
                    textValue = '阳极吹扫默认启用状态';
                case "anode.purge.on_n2_mole_fraction"
                    textValue = '阳极吹扫开启氮气阈值';
                case "anode.purge.off_n2_mole_fraction"
                    textValue = '阳极吹扫关闭氮气阈值';
                case "anode.separator.D_m"
                    textValue = '阳极分离器直径';
                case "anode.separator.length_m"
                    textValue = '阳极分离器长度';
                case "thermal.stack_temperature_set_C"
                    textValue = '电堆冷却出口温度设定';
                case "thermal.coolant.num_layers"
                    textValue = '冷却层数量';
                case "thermal.coolant.num_passes"
                    textValue = '冷却流道往返次数';
                case "thermal.coolant.tube_D_m"
                    textValue = '冷却管直径';
                case "thermal.radiator.H_m"
                    textValue = '散热器高度';
                case "thermal.radiator.L_m"
                    textValue = '散热器长度';
                case "thermal.radiator.N_fins"
                    textValue = '散热器翅片数量';
                case "thermal.radiator.N_tubes"
                    textValue = '散热器管路数量';
                case "controls.current_default_ref_A"
                    textValue = '面板恒电流默认命令';
                case "controls.power_default_ref_kW"
                    textValue = '面板恒功率默认命令';
                case "controls.air_control_mode"
                    textValue = '面板空气控制默认模式';
                case "controls.target_oer"
                    textValue = '面板目标OER默认值';
                case "controls.target_mdot_kg_s"
                    textValue = '面板目标空气流量默认值';
                case "controls.backpressure_MPa_abs"
                    textValue = '面板背压默认值';
                case "controls.voltage_pi_Kp"
                    textValue = '面板电压控制比例增益默认值';
                case "controls.voltage_pi_Ki"
                    textValue = '面板电压控制积分增益默认值';
                case "controls.voltage_current_min_A"
                    textValue = '面板电压控制电流下限';
                case "controls.voltage_current_max_A"
                    textValue = '面板电压控制电流上限';
                case "controls.voltage_default_ref_V"
                    textValue = '面板恒电压默认命令';
                case "controls.voltage_startup_ref_V"
                    textValue = '冷启动电压初始命令';
                case "controls.current_startup_A"
                    textValue = '冷启动电流初始命令';
                case "controls.power_startup_kW"
                    textValue = '冷启动功率初始命令';
                case "controls.cegr_enabled"
                    textValue = 'cEGR默认启用状态';
                case "controls.cegr_valve_mode"
                    textValue = 'cEGR默认阀模式';
                case "controls.cegr_control_mode"
                    textValue = 'cEGR默认控制模式';
                case "controls.cegr_target_ratio"
                    textValue = 'cEGR默认目标比例';
                case "controls.cegr_direct_area_m2"
                    textValue = 'cEGR默认直接阀面积命令';
                case "controls.anode_purge_enable"
                    textValue = '阳极吹扫默认启用状态';
                case "controls.anode_purge_on_n2"
                    textValue = '阳极吹扫开启默认阈值';
                case "controls.anode_purge_off_n2"
                    textValue = '阳极吹扫关闭默认阈值';
                case "controls.anode_recirc_base"
                    textValue = '阳极回流默认基础命令';
                case "controls.anode_recirc_gain_A_inv"
                    textValue = '阳极回流默认电流增益';
                case "controls.cathode_source_pressure_MPa_abs"
                    textValue = '阴极空气源压力默认值';
                case "controls.cathode_source_temperature_C"
                    textValue = '阴极空气源温度默认值';
                case "controls.anode_source_pressure_MPa_abs"
                    textValue = '阳极氢源压力默认值';
                case "controls.anode_source_temperature_C"
                    textValue = '阳极氢源温度默认值';
                case "controls.air_direct_command"
                    textValue = '空气直接控制默认命令';
                case "numerics.solver"
                    textValue = '默认Simulink求解器';
                case "numerics.relTol"
                    textValue = '默认相对容差';
                case "numerics.absTol"
                    textValue = '默认绝对容差';
                case "numerics.maxStep_s"
                    textValue = '默认最大步长';
                case "numerics.stopTime_s"
                    textValue = '默认仿真停止时间';
                case "numerics.startupRampDuration_s"
                    textValue = '默认启动斜坡时间';
                case "environment.ambient_p_MPa_abs"
                    textValue = '环境标准大气压力';
                case "environment.ambient_T_C"
                    textValue = '环境默认温度';
                case "environment.ambient_RH"
                    textValue = '环境默认相对湿度';
                case "environment.o2_mole_fraction"
                    textValue = '环境氧气摩尔分数';
                case "environment.h2o_mole_fraction"
                    textValue = '环境水蒸气摩尔分数';
                otherwise
                    textValue = '平台设备或系统参数';
            end
        end

        function textValue = formatCatalogValue(~, value)
            if isempty(value)
                textValue = '-';
            elseif islogical(value) && isscalar(value)
                textValue = char(string(value));
            elseif isnumeric(value) && isscalar(value)
                textValue = num2str(value, '%.6g');
            elseif isnumeric(value) && isvector(value) && numel(value) <= 12
                textValue = ['[' strjoin(cellstr(compose('%.6g', value(:))), ...
                    ' ') ']'];
            elseif ischar(value) || (isstring(value) && isscalar(value))
                textValue = char(string(value));
            else
                textValue = class(value);
            end
        end

        function DomainNavigationChanged(app, event)
            selected = string(event.Value);
            target = [];

            basicDomains = ["工况与电边界", "阴极进气与空气控制", ...
                "温度控制", "水管理与水检测", "cEGR 系统"];
            if any(selected == basicDomains)
                if strcmp(app.ElectricalPanel.Visible, 'off')
                    app.BasicModeButton.Value = true;
                    app.AdvancedModeButton.Value = false;
                    app.ModelParameterModeButton.Value = false;
                    app.ModeSelectionChanged(struct('NewValue', ...
                        app.BasicModeButton));
                end
            end

            if selected == "工况与电边界"
                target = app.ElectricalPanel;
            elseif selected == "阴极进气与空气控制"
                target = app.AirPathPanel;
            elseif selected == "温度控制"
                target = app.ThermalPanel;
            elseif selected == "水管理与水检测"
                target = app.AirPathPanel;
            elseif selected == "cEGR 系统"
                target = app.CegrPanel;
            elseif selected == "电堆与电化学"
                app.ResultTabGroup.SelectedTab = app.OverviewTab;
                target = app.RightPanel;
            elseif selected == "阳极系统 / 当前扩展"
                if strcmp(app.AdvancedPanel.Visible, 'off')
                    app.AdvancedModeButton.Value = true;
                    app.BasicModeButton.Value = false;
                    app.ModelParameterModeButton.Value = false;
                    app.ModeSelectionChanged(struct('NewValue', app.AdvancedModeButton));
                end
                target = app.AdvancedPanel;
            elseif selected == "系统模型参数 / 设备目录"
                if strcmp(app.FutureDomainsPanel.Visible, 'off')
                    app.BasicModeButton.Value = false;
                    app.AdvancedModeButton.Value = false;
                    app.ModelParameterModeButton.Value = true;
                    app.ModeSelectionChanged(struct('NewValue', ...
                        app.ModelParameterModeButton));
                end
                target = app.FutureDomainsPanel;
            elseif selected == "结果与诊断"
                app.ResultTabGroup.SelectedTab = app.DiagnosticsTab;
                if isprop(app.RightPanel, 'Scrollable')
                    scroll(app.RightPanel, 'top');
                end
            end

            if ~isempty(target) && isvalid(target) && target ~= app.RightPanel
                if strcmp(app.AdvancedPanel.Visible, 'on') && ...
                        target ~= app.AdvancedPanel && target ~= app.RightPanel
                    app.BasicModeButton.Value = true;
                    app.AdvancedModeButton.Value = false;
                    app.ModelParameterModeButton.Value = false;
                    app.ModeSelectionChanged(struct('NewValue', app.BasicModeButton));
                elseif strcmp(app.FutureDomainsPanel.Visible, 'on') && ...
                        target ~= app.FutureDomainsPanel
                    app.BasicModeButton.Value = true;
                    app.AdvancedModeButton.Value = false;
                    app.ModelParameterModeButton.Value = false;
                    app.ModeSelectionChanged(struct('NewValue', app.BasicModeButton));
                end
                scroll(app.ConfigScrollPanel, target);
            end
            app.DomainNavigationStatusLabel.Text = {char(selected); '定位完成'};
        end

        function ModeSelectionChanged(app, event)
            currentAdvanced = strcmp(app.AdvancedPanel.Visible, 'on');
            advanced = isequal(event.NewValue, app.AdvancedModeButton);
            modelParameters = isequal(event.NewValue, app.ModelParameterModeButton);
            helpMode = isequal(event.NewValue, app.HelpModeButton);

            if helpMode
                if currentAdvanced
                    app.captureAdvancedControls();
                    app.syncAdvancedToBasic();
                end
                app.activeConfigMode = "help";
                app.ElectricalPanel.Visible = 'off';
                app.AirPathPanel.Visible = 'off';
                app.CegrPanel.Visible = 'off';
                app.SolverPanel.Visible = 'off';
                app.ThermalPanel.Visible = 'off';
                app.AdvancedPanel.Visible = 'off';
                app.FutureDomainsPanel.Visible = 'off';
                app.HelpPanel.Visible = 'on';
                scroll(app.ConfigScrollPanel, 'top');
                return;
            end

            if modelParameters
                % Preserve the latest advanced values before opening the
                % read-only model-parameter page. Basic controls are then the
                % stable fallback for a run launched from this page.
                if currentAdvanced
                    app.captureAdvancedControls();
                    app.syncAdvancedToBasic();
                end
                app.activeConfigMode = "model_parameters";
                app.ElectricalPanel.Visible = 'off';
                app.AirPathPanel.Visible = 'off';
                app.CegrPanel.Visible = 'off';
                app.SolverPanel.Visible = 'off';
                app.ThermalPanel.Visible = 'off';
                app.AdvancedPanel.Visible = 'off';
                app.FutureDomainsPanel.Visible = 'on';
                app.HelpPanel.Visible = 'off';
                scroll(app.ConfigScrollPanel, 'top');
                return;
            end

            if advanced
                % Values are already synchronized when coming from the model
                % parameter page; this also handles basic -> advanced.
                if ~currentAdvanced
                    app.syncBasicToAdvanced();
                end
                app.activeConfigMode = "advanced";
                app.syncBasicToAdvanced();
                app.ElectricalPanel.Visible = 'off';
                app.AirPathPanel.Visible = 'off';
                app.CegrPanel.Visible = 'off';
                app.SolverPanel.Visible = 'off';
                app.ThermalPanel.Visible = 'off';
                app.FutureDomainsPanel.Visible = 'off';
                app.HelpPanel.Visible = 'off';
                app.AdvancedPanel.Visible = 'on';
                scroll(app.ConfigScrollPanel, 'top');
            else
                if currentAdvanced
                    app.captureAdvancedControls();
                    app.syncAdvancedToBasic();
                end
                app.activeConfigMode = "basic";
                app.AdvancedPanel.Visible = 'off';
                app.ElectricalPanel.Visible = 'on';
                app.AirPathPanel.Visible = 'on';
                app.CegrPanel.Visible = 'on';
                app.SolverPanel.Visible = 'on';
                app.ThermalPanel.Visible = 'on';
                app.FutureDomainsPanel.Visible = 'off';
                app.HelpPanel.Visible = 'off';
                scroll(app.ConfigScrollPanel, 'top');
            end
        end

        function syncBasicToAdvanced(app)
            app.AdvancedBoundaryModeDropDown.Value = app.BoundaryModeDropDown.Value;
            app.AdvancedBoundaryCommandEditField.Value = ...
                app.BoundaryCommandEditField.Value;
            app.AdvancedRampDurationEditField.Value = ...
                app.RampDurationEditField.Value;
            app.AdvancedOerEditField.Value = app.OerEditField.Value;
            app.AdvancedAirControlModeDropDown.Value = app.AirControlModeDropDown.Value;
            app.AdvancedTargetMdotEditField.Value = app.TargetMdotEditField.Value;
            app.AdvancedDirectCommandEditField.Value = app.DirectCommandEditField.Value;
            app.AdvancedSourceTemperatureEditField.Value = ...
                app.simCase.controls.cathode.sourceTemperature_C;
            app.AdvancedBackpressureEditField.Value = ...
                app.BackpressureEditField.Value;
            app.AdvancedHumidifierRHEditField.Value = ...
                app.HumidifierRHEditField.Value;
            app.AdvancedHumidifierEnabledCheckBox.Value = ...
                app.HumidifierEnabledCheckBox.Value;
            app.AdvancedCegrRatioEditField.Value = app.CegrRatioEditField.Value;
            app.AdvancedCegrEnabledCheckBox.Value = app.CegrEnabledCheckBox.Value;
            app.AdvancedStopTimeEditField.Value = app.StopTimeEditField.Value;
            app.AdvancedStackTemperatureEditField.Value = ...
                app.StackTemperatureEditField.Value;
            app.AdvancedCegrKpEditField.Value = ...
                app.simCase.controls.cegr.controller.Kp_area;
            app.AdvancedCegrKiEditField.Value = ...
                app.simCase.controls.cegr.controller.Ki_area;
            app.AdvancedCegrActuatorTauEditField.Value = ...
                app.simCase.controls.cegr.controller.actuatorTau_s;
            app.AdvancedStackNumCellsEditField.Value = ...
                app.simCase.controls.stack.numCells;
            app.AdvancedStackAreaEditField.Value = ...
                app.simCase.controls.stack.area_cm2;
            app.AdvancedStackIEditField.Value = ...
                app.simCase.controls.stack.iL_A_cm2;
            app.AdvancedStackIoEditField.Value = ...
                app.simCase.controls.stack.io_A_cm2;
            app.AdvancedBoundaryUnitLabel.Text = app.BoundaryUnitLabel.Text;
            app.updateAirControlControls(true);
            app.updateHumidifierControls(true);
            app.updateCegrControls(true);
            app.updateVoltageControllerControls();
        end

        function syncAdvancedToBasic(app)
            app.BoundaryModeDropDown.Value = app.AdvancedBoundaryModeDropDown.Value;
            app.BoundaryCommandEditField.Value = ...
                app.AdvancedBoundaryCommandEditField.Value;
            app.RampDurationEditField.Value = app.AdvancedRampDurationEditField.Value;
            app.OerEditField.Value = app.AdvancedOerEditField.Value;
            app.AirControlModeDropDown.Value = app.AdvancedAirControlModeDropDown.Value;
            app.TargetMdotEditField.Value = app.AdvancedTargetMdotEditField.Value;
            app.DirectCommandEditField.Value = app.AdvancedDirectCommandEditField.Value;
            app.SourceTemperatureEditField.Value = ...
                app.AdvancedStackTemperatureEditField.Value;
            app.BackpressureEditField.Value = app.AdvancedBackpressureEditField.Value;
            app.HumidifierRHEditField.Value = ...
                app.AdvancedHumidifierRHEditField.Value;
            app.HumidifierEnabledCheckBox.Value = ...
                app.AdvancedHumidifierEnabledCheckBox.Value;
            app.CegrRatioEditField.Value = app.AdvancedCegrRatioEditField.Value;
            app.CegrEnabledCheckBox.Value = app.AdvancedCegrEnabledCheckBox.Value;
            app.StopTimeEditField.Value = app.AdvancedStopTimeEditField.Value;
            app.StackTemperatureEditField.Value = ...
                app.AdvancedStackTemperatureEditField.Value;
            app.BoundaryUnitLabel.Text = app.AdvancedBoundaryUnitLabel.Text;
            app.updateAirControlControls(false);
            app.updateHumidifierControls(false);
            app.updateCegrControls(false);
        end

        function value = enableState(~, enabled)
            if enabled
                value = 'on';
            else
                value = 'off';
            end
        end
    end
    
    % App creation and deletion
    methods (Access = public)
        
        function app = RouteA_Panel_v01
            app.platformPaths = routeA_project_paths();
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
