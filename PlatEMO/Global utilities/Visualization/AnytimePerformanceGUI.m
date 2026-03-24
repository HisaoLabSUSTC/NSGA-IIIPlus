function AnytimePerformanceGUI(metricsDataDir)
%ANYTIMEPERFORMANCEGUI Interactive GUI for visualizing anytime performance
%
%   AnytimePerformanceGUI(metricsDataDir)
%
%   Input:
%     metricsDataDir - Directory containing anytime metrics data
%                      (default: './AnytimeMetrics')
%
%   This GUI displays HV, IGD+, Spread, and Spacing evolution over function
%   evaluations, allowing comparison of multiple algorithms on selected problems.

    % Default directory
    if nargin < 1
        metricsDataDir = fullfile('AnytimeMetrics');
    end

    %% Create main GUI window
    fprintf('Creating Anytime Performance Visualization Tool...\n');

    mainFig = figure('Name', 'Anytime Performance Analysis Tool', ...
                    'Position', [50, 50, 1600, 900], ...
                    'MenuBar', 'none', ...
                    'NumberTitle', 'off');

    % Create panels
    problemPanel = uipanel('Parent', mainFig, ...
                          'Title', 'Select Problems', ...
                          'Position', [0.01, 0.55, 0.18, 0.35]);

    algorithmPanel = uipanel('Parent', mainFig, ...
                            'Title', 'Select Algorithms', ...
                            'Position', [0.01, 0.15, 0.18, 0.38]);

    metricPanel = uipanel('Parent', mainFig, ...
                         'Title', 'Select Metric', ...
                         'Position', [0.01, 0.02, 0.18, 0.12]);

    plotPanel = uipanel('Parent', mainFig, ...
                       'Title', 'Anytime Performance', ...
                       'Position', [0.2000 0.1000 0.7900 0.8500]);

    if ~exist(metricsDataDir, 'dir')
        errordlg('AnytimeMetrics directory not found. Please run ComputeAnytimeMetrics first.', ...
                 'Missing Data');
        close(mainFig);
        return;
    end

    %% Get all algorithm subdirectories
    subdirs = dir(metricsDataDir);
    subdirs = subdirs([subdirs.isdir]);
    subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));

    % Load all metrics data files info
    metricsFileInfo = struct('filename', {}, 'algorithm', {}, 'problem_name', {}, ...
        'problem_instance', {}, 'M', {}, 'D', {}, 'run', {}, 'filepath', {});

    fileCount = 0;
    for i = 1:length(subdirs)
        algorithmName = subdirs(i).name;
        subdirPath = fullfile(metricsDataDir, algorithmName);
        matFiles = dir(fullfile(subdirPath, 'AM_*.mat'));

        for j = 1:length(matFiles)
            filename = matFiles(j).name;
            % Remove AM_ prefix for parsing
            originalFilename = filename(4:end);
            parts = strsplit(originalFilename, '_');

            if length(parts) >= 5
                fileCount = fileCount + 1;
                metricsFileInfo(fileCount).filename = filename;
                metricsFileInfo(fileCount).algorithm = parts{1};
                metricsFileInfo(fileCount).M = parts{3}(2:end);
                metricsFileInfo(fileCount).D = parts{4}(2:end);

                % Reconstruct pipeline name (e.g., MOTSP_ID3 for combinatorial)
                probName = parts{2};
                if length(parts) >= 6 && startsWith(parts{5}, 'ID')
                    pipelineName = sprintf('%s_%s', probName, parts{5});
                    instanceStr = sprintf('%s_M%s_D%s', pipelineName, ...
                        parts{3}(2:end), parts{4}(2:end));
                else
                    pipelineName = probName;
                    instanceStr = strjoin(parts(2:end-1), '_');
                end
                metricsFileInfo(fileCount).problem_name = pipelineName;
                metricsFileInfo(fileCount).problem_instance = instanceStr;

                runStr = parts{end};
                metricsFileInfo(fileCount).run = str2double(runStr(1:end-4));
                metricsFileInfo(fileCount).filepath = fullfile(subdirPath, filename);
            end
        end
    end

    if isempty(metricsFileInfo)
        errordlg('No anytime metrics files found. Please run ComputeAnytimeMetrics first.', ...
                 'No Data Files');
        close(mainFig);
        return;
    end

    % Get unique problems and algorithms
    uniqueProblems = unique({metricsFileInfo.problem_instance});
    uniqueAlgorithms = unique({metricsFileInfo.algorithm});

    fprintf('Found %d precomputed metrics files:\n', length(metricsFileInfo));
    fprintf('  - %d unique problems\n', length(uniqueProblems));
    fprintf('  - %d unique algorithms\n', length(uniqueAlgorithms));

    %% Create problem listbox
    problemListbox = uicontrol('Parent', problemPanel, ...
                              'Style', 'listbox', ...
                              'String', uniqueProblems, ...
                              'Units', 'normalized', ...
                              'Position', [0.05, 0.15, 0.9, 0.8], ...
                              'Max', 2, ...
                              'Value', 1);

    uicontrol('Parent', problemPanel, ...
             'Style', 'pushbutton', ...
             'String', 'Select All', ...
             'Units', 'normalized', ...
             'Position', [0.05, 0.02, 0.42, 0.08], ...
             'Callback', @(~,~) set(problemListbox, 'Value', 1:length(uniqueProblems)));

    uicontrol('Parent', problemPanel, ...
             'Style', 'pushbutton', ...
             'String', 'Clear', ...
             'Units', 'normalized', ...
             'Position', [0.53, 0.02, 0.42, 0.08], ...
             'Callback', @(~,~) set(problemListbox, 'Value', []));

    %% Create algorithm listbox
    algorithmListbox = uicontrol('Parent', algorithmPanel, ...
                                'Style', 'listbox', ...
                                'String', uniqueAlgorithms, ...
                                'Units', 'normalized', ...
                                'Position', [0.05, 0.15, 0.9, 0.8], ...
                                'Max', 2, ...
                                'Value', 1:min(3, length(uniqueAlgorithms)));

    uicontrol('Parent', algorithmPanel, ...
             'Style', 'pushbutton', ...
             'String', 'Select All', ...
             'Units', 'normalized', ...
             'Position', [0.05, 0.02, 0.42, 0.08], ...
             'Callback', @(~,~) set(algorithmListbox, 'Value', 1:length(uniqueAlgorithms)));

    uicontrol('Parent', algorithmPanel, ...
             'Style', 'pushbutton', ...
             'String', 'Clear', ...
             'Units', 'normalized', ...
             'Position', [0.53, 0.02, 0.42, 0.08], ...
             'Callback', @(~,~) set(algorithmListbox, 'Value', []));

    %% Create metric selection dropdown
    metricDropdown = uicontrol('Parent', metricPanel, ...
                               'Style', 'popupmenu', ...
                               'String', {'HV (Hypervolume)', 'IGD+ (Inverted Gen. Distance)', 'Generalized Spread (Δ*)'}, ...
                               'Units', 'normalized', ...
                               'Position', [0.05, 0.3, 0.9, 0.5], ...
                               'Value', 1);

    %% Create plot button
    plotButton = uicontrol('Parent', mainFig, ...
                          'Style', 'pushbutton', ...
                          'String', 'Generate Plots', ...
                          'Units', 'normalized', ...
                          'Position', [0.05, 0.92, 0.1, 0.06], ...
                          'FontSize', 12, ...
                          'FontWeight', 'bold', ...
                          'BackgroundColor', [0.3, 0.7, 0.3], ...
                          'ForegroundColor', 'white');

    %% Store data in figure
    mainData = struct();
    mainData.metricsFileInfo = metricsFileInfo;
    mainData.uniqueProblems = uniqueProblems;
    mainData.uniqueAlgorithms = uniqueAlgorithms;
    mainData.problemListbox = problemListbox;
    mainData.algorithmListbox = algorithmListbox;
    mainData.metricDropdown = metricDropdown;
    mainData.plotPanel = plotPanel;
    mainData.plotData = [];
    mainFig.UserData = mainData;

    % Set callbacks
    plotButton.Callback = @generatePlotsCallback;

    fprintf('Interactive visualization tool ready.\n');

    %% Callback function for generating plots
    function generatePlotsCallback(src, ~)
        fig = ancestor(src, 'figure');
        mainData = fig.UserData;

        % Get selections
        selectedProblemIdx = mainData.problemListbox.Value;
        selectedAlgorithmIdx = mainData.algorithmListbox.Value;
        selectedMetricIdx = mainData.metricDropdown.Value;

        if isempty(selectedProblemIdx)
            msgbox('Please select at least one problem.', 'No Problem Selected', 'warn');
            return;
        end

        if isempty(selectedAlgorithmIdx)
            msgbox('Please select at least one algorithm.', 'No Algorithm Selected', 'warn');
            return;
        end

        selectedProblems = mainData.uniqueProblems(selectedProblemIdx);
        selectedAlgorithms = mainData.uniqueAlgorithms(selectedAlgorithmIdx);

        % Map metric index to field name and display name
        metricFields = {'HV', 'IGDp', 'GenSpread'};
        metricNames = {'Hypervolume', 'IGD+', 'Generalized Spread (Δ*)'};
        metricDirections = {'higher is better', 'lower is better', 'lower is better'};

        metricField = metricFields{selectedMetricIdx};
        metricName = metricNames{selectedMetricIdx};
        metricDir = metricDirections{selectedMetricIdx};

        % Clear previous plots
        delete(mainData.plotPanel.Children);

        % Create tab group for multiple problems
        tabGroup = uitabgroup('Parent', mainData.plotPanel);

        % Process each selected problem
        for p = 1:length(selectedProblems)
            currentProblem = selectedProblems{p};

            % Create tab for this problem
            tab = uitab('Parent', tabGroup, 'Title', currentProblem);

            % Create axes
            ax = axes('Parent', tab, 'Position', [0.1, 0.15, 0.84, 0.75]);

            % Filter files for current problem
            problemFiles = mainData.metricsFileInfo(strcmp({mainData.metricsFileInfo.problem_instance}, currentProblem));

            if isempty(problemFiles)
                continue;
            end

            % Define colors
            colors = lines(length(selectedAlgorithms));

            % Get problem info from first file
            M = str2double(problemFiles(1).M);
            D = str2double(problemFiles(1).D);
            problemName = problemFiles(1).problem_name;

            % Storage for plot data (for export)
            plotDataStorage = struct();
            plotDataStorage.problem = currentProblem;
            plotDataStorage.problemName = problemName;
            plotDataStorage.M = M;
            plotDataStorage.D = D;
            plotDataStorage.metricField = metricField;
            plotDataStorage.metricName = metricName;
            plotDataStorage.algorithms = {};
            plotDataStorage.metricData = {};
            plotDataStorage.colors = colors;

            % Process each selected algorithm
            legendEntries = {};
            legendHandles = [];

            for a = 1:length(selectedAlgorithms)
                currentAlgorithm = selectedAlgorithms{a};

                % Filter files for current algorithm and problem
                algorithmFiles = problemFiles(strcmp({problemFiles.algorithm}, currentAlgorithm));

                if isempty(algorithmFiles)
                    continue;
                end

                % Store metric data for all runs
                allFE = {};
                allMetric = {};

                % Load precomputed data for each run
                for r = 1:length(algorithmFiles)
                    filepath = algorithmFiles(r).filepath;

                    try
                        data = load(filepath);
                        allFE{r} = data.metricsData.FE;
                        allMetric{r} = data.metricsData.(metricField);
                    catch ME
                        fprintf('Warning: Could not load %s: %s\n', filepath, ME.message);
                    end
                end

                % Plot metric
                if ~isempty(allFE)
                    % Find common FE points for interpolation
                    commonFE = unique(sort(cell2mat(allFE')));
                    interpolatedMetric = zeros(length(commonFE), length(allMetric));

                    for r = 1:length(allMetric)
                        interpolatedMetric(:, r) = interp1(allFE{r}, allMetric{r}, commonFE, 'linear', 'extrap');
                    end

                    meanMetric = mean(interpolatedMetric, 2);
                    stdMetric = std(interpolatedMetric, 0, 2);

                    % Store data for export
                    plotDataStorage.algorithms{end+1} = currentAlgorithm;
                    plotDataStorage.metricData{end+1} = struct('FE', commonFE, 'mean', meanMetric, 'std', stdMetric);

                    % Plot
                    hold(ax, 'on');
                    h = plot(ax, commonFE/10000, meanMetric, 'LineWidth', 2, ...
                        'Color', colors(a, :), 'DisplayName', currentAlgorithm);
                    fill(ax, [commonFE/10000; flipud(commonFE/10000)], ...
                         [meanMetric + stdMetric; flipud(meanMetric - stdMetric)], ...
                         colors(a, :), 'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
                         'HandleVisibility', 'off');

                    legendEntries{end+1} = currentAlgorithm;
                    legendHandles(end+1) = h;
                end
            end

            % Customize plot
            xlabel(ax, 'Function Evaluations (Unit: Ten Thousands)', 'FontSize', 24);
            ylabel(ax, metricName, 'FontSize', 24);
            titleStr = sprintf('%s (M=%d, D=%d) - %s (%s)', problemName, M, D, metricName, metricDir);
            title(ax, titleStr, 'FontSize', 28);
            grid(ax, 'on');
            if ~isempty(legendHandles)
                legend(ax, legendHandles, legendEntries, 'Location', 'best', 'FontSize', 20);
            end

            % Add export button
            uicontrol('Parent', mainFig, ...
                     'Style', 'pushbutton', ...
                     'String', 'Export Plot', ...
                     'Units', 'normalized', ...
                     'Position', [0.7900 0.0200 0.2000 0.0500], ...
                     'FontSize', 11, ...
                     'FontWeight', 'bold', ...
                     'BackgroundColor', [0.2, 0.5, 0.8], ...
                     'ForegroundColor', 'white', ...
                     'UserData', plotDataStorage, ...
                     'Callback', @exportPlot);
        end

        % Make the first tab active
        if ~isempty(tabGroup.Children)
            tabGroup.SelectedTab = tabGroup.Children(1);
        end
    end

    %% Export plot function
    function exportPlot(src, ~)
        plotData = src.UserData;

        % Create export directory if it doesn't exist
        exportDir = 'ExportedPlots';
        if ~exist(exportDir, 'dir')
            mkdir(exportDir);
        end

        timestamp = datestr(now, 'yyyymmdd_HHMMSS');

        % Create full-size figure
        exportFig = figure('Position', [100, 100, 1200, 800], ...
                          'Name', sprintf('%s - %s', plotData.metricName, plotData.problem));
        ax = axes('Parent', exportFig, 'Position', [0.1, 0.1, 0.85, 0.85]);

        % Plot data
        hold(ax, 'on');
        legendEntries = {};
        for a = 1:length(plotData.algorithms)
            alg = plotData.algorithms{a};
            metricInfo = plotData.metricData{a};
            color = plotData.colors(a, :);

            % Plot mean line
            plot(ax, metricInfo.FE, metricInfo.mean, 'LineWidth', 2.5, ...
                'Color', color, 'DisplayName', alg);

            % Plot confidence interval
            fill(ax, [metricInfo.FE; flipud(metricInfo.FE)], ...
                 [metricInfo.mean + metricInfo.std; flipud(metricInfo.mean - metricInfo.std)], ...
                 color, 'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
                 'HandleVisibility', 'off');

            legendEntries{end+1} = alg;
        end

        % Customize
        xlabel(ax, 'Function Evaluations', 'FontSize', 14, 'FontWeight', 'bold');
        ylabel(ax, plotData.metricName, 'FontSize', 14, 'FontWeight', 'bold');
        titleStr = sprintf('%s (M=%d, D=%d) - %s Evolution', ...
                          plotData.problemName, plotData.M, plotData.D, plotData.metricName);
        title(ax, titleStr, 'FontSize', 16, 'FontWeight', 'bold');
        grid(ax, 'on');
        legend(ax, legendEntries, 'Location', 'best', 'FontSize', 12);

        % Save figure
        filename = sprintf('%s/%s_%s_%s.png', exportDir, plotData.metricField, plotData.problem, timestamp);
        saveas(exportFig, filename);
        filename_fig = sprintf('%s/%s_%s_%s.fig', exportDir, plotData.metricField, plotData.problem, timestamp);
        saveas(exportFig, filename_fig);

        fprintf('%s plot exported to: %s\n', plotData.metricName, filename);
        close(exportFig);

        msgbox(sprintf('%s plot exported to:\n%s/', plotData.metricName, exportDir), 'Export Successful', 'help');
    end
end
