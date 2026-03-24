function HVCVGUI(hvDataDir)
    % Load and parse HV data
    if nargin < 1
        hvDataDir = fullfile('HVData');
    end



    %% Task 4: Visualize hypervolume using interactive tool with Export functionality
    fprintf('Step 4: Creating interactive visualization tool with export feature...\n');
    
    % Create main GUI window
    mainFig = figure('Name', 'Hypervolume & CV Analysis Tool (with Export)', ...
                    'Position', [50, 50, 1600, 900], ...
                    'MenuBar', 'none', ...
                    'NumberTitle', 'off');
    
    % Create panels
    problemPanel = uipanel('Parent', mainFig, ...
                          'Title', 'Select Problems', ...
                          'Position', [0.01, 0.55, 0.18, 0.35]);
    
    algorithmPanel = uipanel('Parent', mainFig, ...
                            'Title', 'Select Algorithms', ...
                            'Position', [0.01, 0.02, 0.18, 0.5]);
    
    plotPanel = uipanel('Parent', mainFig, ...
                       'Title', 'Hypervolume Evolution', ...
                       'Position', [0.2, 0.02, 0.79, 0.96]);
        
    if ~exist(hvDataDir, 'dir')
        errordlg('HVData directory not found. Please run Step 1 first to precompute hypervolume data.', ...
                 'Missing Data');
        close(mainFig);
        return;
    end
    
    % Get all algorithm subdirectories
    subdirs = dir(hvDataDir);
    subdirs = subdirs([subdirs.isdir]);
    subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));
    
    % Load all HV data files
    hvFileInfo = struct('filename', {}, 'algorithm', {}, 'problem_name', {}, ...
        'problem_instance', {}, 'M', {}, 'D', {}, 'run', {}, 'filepath', {});
    
    fileCount = 0;
    for i = 1:length(subdirs)
        algorithmName = subdirs(i).name;
        subdirPath = fullfile(hvDataDir, algorithmName);
        matFiles = dir(fullfile(subdirPath, 'HV_*.mat'));
    
        for j = 1:length(matFiles)
            filename = matFiles(j).name;
            % Remove HV_ prefix for parsing
            originalFilename = filename(4:end);
            parts = strsplit(originalFilename, '_');
    
            if length(parts) >= 5
                fileCount = fileCount + 1;
                hvFileInfo(fileCount).filename = filename;
                hvFileInfo(fileCount).algorithm = parts{1};
                hvFileInfo(fileCount).problem_name = parts{2};
                hvFileInfo(fileCount).M = parts{3}(2:end);
                hvFileInfo(fileCount).D = parts{4}(2:end);
    
                problemParts = parts(2:end-1);
                hvFileInfo(fileCount).problem_instance = strjoin(problemParts, '_');
    
                runStr = parts{end};
                hvFileInfo(fileCount).run = str2double(runStr(1:end-4));
                hvFileInfo(fileCount).filepath = fullfile(subdirPath, filename);
            end
        end
    end
    
    if isempty(hvFileInfo)
        errordlg('No HV data files found. Please run Step 1 first to precompute hypervolume data.', ...
                 'No Data Files');
        close(mainFig);
        return;
    end
    
    % Get unique problems and algorithms
    uniqueProblems = unique({hvFileInfo.problem_instance});
    uniqueAlgorithms = unique({hvFileInfo.algorithm});
    
    fprintf('Found %d precomputed HV files:\n', length(hvFileInfo));
    fprintf('  - %d unique problems\n', length(uniqueProblems));
    fprintf('  - %d unique algorithms\n', length(uniqueAlgorithms));
    
    % Create problem listbox
    problemListbox = uicontrol('Parent', problemPanel, ...
                              'Style', 'listbox', ...
                              'String', uniqueProblems, ...
                              'Units', 'normalized', ...
                              'Position', [0.05, 0.15, 0.9, 0.8], ...
                              'Max', 2, ... % Enable multi-selection
                              'Value', 1);
    
    % Add Select All/Clear buttons for problems
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
    
    % Create algorithm listbox
    algorithmListbox = uicontrol('Parent', algorithmPanel, ...
                                'Style', 'listbox', ...
                                'String', uniqueAlgorithms, ...
                                'Units', 'normalized', ...
                                'Position', [0.05, 0.25, 0.9, 0.7], ...
                                'Max', 2, ...
                                'Value', 1:min(3, length(uniqueAlgorithms)));
    
    % Add reference algorithm selection dropdown
    uicontrol('Parent', algorithmPanel, ...
             'Style', 'text', ...
             'String', 'Reference Algorithm:', ...
             'Units', 'normalized', ...
             'Position', [0.05, 0.14, 0.9, 0.08], ...
             'HorizontalAlignment', 'left', ...
             'FontWeight', 'bold');
    
    referenceDropdown = uicontrol('Parent', algorithmPanel, ...
                                  'Style', 'popupmenu', ...
                                  'String', ['None (Compare All)', uniqueAlgorithms], ...
                                  'Units', 'normalized', ...
                                  'Position', [0.05, 0.08, 0.9, 0.08], ...
                                  'Value', 1);
    
    % Add Select All/Clear buttons for algorithms
    uicontrol('Parent', algorithmPanel, ...
             'Style', 'pushbutton', ...
             'String', 'Select All', ...
             'Units', 'normalized', ...
             'Position', [0.05, 0.02, 0.42, 0.05], ...
             'Callback', @(~,~) set(algorithmListbox, 'Value', 1:length(uniqueAlgorithms)));
    
    uicontrol('Parent', algorithmPanel, ...
             'Style', 'pushbutton', ...
             'String', 'Clear', ...
             'Units', 'normalized', ...
             'Position', [0.53, 0.02, 0.42, 0.05], ...
             'Callback', @(~,~) set(algorithmListbox, 'Value', []));
    
    % Create plot button
    plotButton = uicontrol('Parent', mainFig, ...
                          'Style', 'pushbutton', ...
                          'String', 'Generate Plots', ...
                          'Units', 'normalized', ...
                          'Position', [0.05, 0.92, 0.1, 0.06], ...
                          'FontSize', 12, ...
                          'FontWeight', 'bold', ...
                          'BackgroundColor', [0.3, 0.7, 0.3], ...
                          'ForegroundColor', 'white');
    
    
    % Store data in figure
    mainData = struct();
    mainData.hvFileInfo = hvFileInfo;
    mainData.uniqueProblems = uniqueProblems;
    mainData.uniqueAlgorithms = uniqueAlgorithms;
    mainData.problemListbox = problemListbox;
    mainData.algorithmListbox = algorithmListbox;
    mainData.referenceDropdown = referenceDropdown;
    mainData.plotPanel = plotPanel;
    mainData.plotData = []; % Store plot data for export
    mainFig.UserData = mainData;
    
    % Set callbacks
    plotButton.Callback = @generatePlotsCallbackOptimized;
    
    fprintf('Interactive visualization tool ready with export feature.\n');
    
    %% Callback function for generating plots using precomputed data
    function generatePlotsCallbackOptimized(src, ~)
        fig = ancestor(src, 'figure');
        mainData = fig.UserData;
    
        % Get selected problems and algorithms
        selectedProblemIdx = mainData.problemListbox.Value;
        selectedAlgorithmIdx = mainData.algorithmListbox.Value;
    
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
    
        % Clear previous plots
        delete(mainData.plotPanel.Children);
    
        % Initialize plot data storage
        plotDataCollection = struct('problems', {}, 'data', {});
    
        % Create tab group for multiple problems
        tabGroup = uitabgroup('Parent', mainData.plotPanel);
    
        % Process each selected problem
        for p = 1:length(selectedProblems)
            currentProblem = selectedProblems{p};
    
            % Create tab for this problem
            tab = uitab('Parent', tabGroup, 'Title', currentProblem);
    
            % Create subplot layout with export buttons
            ax1 = subplot(2, 2, [1 2], 'Parent', tab); % HV plot spans top
            ax2 = subplot(2, 2, 3, 'Parent', tab); % CV plot bottom left
            
            % Create export buttons panel in bottom right
            buttonPanel = uipanel('Parent', tab, ...
                                 'Position', [0.55, 0.05, 0.4, 0.35], ...
                                 'BorderType', 'none');
    
            % Filter files for current problem
            problemFiles = mainData.hvFileInfo(strcmp({mainData.hvFileInfo.problem_instance}, currentProblem));
    
            if isempty(problemFiles)
                continue;
            end
    
            % Define colors
            colors = lines(length(selectedAlgorithms));
    
            % Get problem info from first file
            M = str2double(problemFiles(1).M);
            D = str2double(problemFiles(1).D);
            problemName = problemFiles(1).problem_name;
    
            % Initialize storage for this problem's data
            problemPlotData = struct();
            problemPlotData.problem = currentProblem;
            problemPlotData.problemName = problemName;
            problemPlotData.M = M;
            problemPlotData.D = D;
            problemPlotData.algorithms = {};
            problemPlotData.hvData = {};
            problemPlotData.cvData = {};
            problemPlotData.colors = colors;
    
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
    
                % Store HV and CV data for all runs
                allFE = {};
                allHV = {};
                allCV = {};
    
                % Load precomputed data for each run
                for r = 1:length(algorithmFiles)
                    filepath = algorithmFiles(r).filepath;
    
                    try
                        data = load(filepath);
                        allFE{r} = data.hvData.FE;
                        allHV{r} = data.hvData.HV;
                        allCV{r} = data.hvData.avgCV;
                    catch ME
                        fprintf('Warning: Could not load %s: %s\n', filepath, ME.message);
                    end
                end
    
                % Plot HV
                if ~isempty(allFE)
                    % Find common FE points for interpolation
                    commonFE = unique(sort(cell2mat(allFE')));
                    interpolatedHV = zeros(length(commonFE), length(allHV));
                    interpolatedCV = zeros(length(commonFE), length(allCV));
    
                    for r = 1:length(allHV)
                        interpolatedHV(:, r) = interp1(allFE{r}, allHV{r}, commonFE, 'linear', 'extrap');
                        interpolatedCV(:, r) = interp1(allFE{r}, allCV{r}, commonFE, 'linear', 'extrap');
                    end
    
                    meanHV = mean(interpolatedHV, 2);
                    stdHV = std(interpolatedHV, 0, 2);
                    meanCV = mean(interpolatedCV, 2);
                    stdCV = std(interpolatedCV, 0, 2);
    
                    % Store data for export
                    problemPlotData.algorithms{end+1} = currentAlgorithm;
                    problemPlotData.hvData{end+1} = struct('FE', commonFE, 'mean', meanHV, 'std', stdHV);
                    problemPlotData.cvData{end+1} = struct('FE', commonFE, 'mean', meanCV, 'std', stdCV);
    
                    % Plot HV
                    hold(ax1, 'on');
                    h1 = plot(ax1, commonFE, meanHV, 'LineWidth', 2, ...
                        'Color', colors(a, :), 'DisplayName', currentAlgorithm);
                    fill(ax1, [commonFE; flipud(commonFE)], ...
                         [meanHV + stdHV; flipud(meanHV - stdHV)], ...
                         colors(a, :), 'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
                         'HandleVisibility', 'off');
    
                    % Plot CV
                    hold(ax2, 'on');
                    plot(ax2, commonFE, meanCV, 'LineWidth', 2, ...
                        'Color', colors(a, :), 'DisplayName', currentAlgorithm);
                    fill(ax2, [commonFE; flipud(commonFE)], ...
                         [meanCV + stdCV; flipud(meanCV - stdCV)], ...
                         colors(a, :), 'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
                         'HandleVisibility', 'off');
    
                    legendEntries{end+1} = currentAlgorithm;
                    legendHandles(end+1) = h1;
                end
            end
    
            % Store problem data - use dynamic indexing instead of direct assignment
            if isempty(plotDataCollection)
                plotDataCollection = problemPlotData;
            else
                plotDataCollection(end+1) = problemPlotData;
            end
    
            % Customize HV plot
            xlabel(ax1, 'Function Evaluations', 'FontSize', 12);
            ylabel(ax1, 'Hypervolume', 'FontSize', 12);
            titleStr = sprintf('%s (M=%d, D=%d) - Hypervolume', problemName, M, D);
            title(ax1, titleStr, 'FontSize', 14, 'FontWeight', 'bold');
            grid(ax1, 'on');
            if ~isempty(legendHandles)
                legend(ax1, legendHandles, legendEntries, 'Location', 'southeast', 'FontSize', 10);
            end
    
            % Customize CV plot
            xlabel(ax2, 'Function Evaluations', 'FontSize', 12);
            ylabel(ax2, 'Average CV', 'FontSize', 12);
            title(ax2, 'Constraint Violation', 'FontSize', 14, 'FontWeight', 'bold');
            grid(ax2, 'on');
            legend(ax2, legendEntries, 'Location', 'northeast', 'FontSize', 10);
    
            % Add export buttons
            uicontrol('Parent', buttonPanel, ...
                     'Style', 'pushbutton', ...
                     'String', 'Export HV Plot', ...
                     'Units', 'normalized', ...
                     'Position', [0.1, 0.7, 0.8, 0.25], ...
                     'FontSize', 11, ...
                     'FontWeight', 'bold', ...
                     'BackgroundColor', [0.2, 0.5, 0.8], ...
                     'ForegroundColor', 'white', ...
                     'UserData', struct('plotData', problemPlotData, 'plotType', 'HV'), ...
                     'Callback', @exportFullSizePlot);
    
            uicontrol('Parent', buttonPanel, ...
                     'Style', 'pushbutton', ...
                     'String', 'Export CV Plot', ...
                     'Units', 'normalized', ...
                     'Position', [0.1, 0.4, 0.8, 0.25], ...
                     'FontSize', 11, ...
                     'FontWeight', 'bold', ...
                     'BackgroundColor', [0.8, 0.5, 0.2], ...
                     'ForegroundColor', 'white', ...
                     'UserData', struct('plotData', problemPlotData, 'plotType', 'CV'), ...
                     'Callback', @exportFullSizePlot);
    
            uicontrol('Parent', buttonPanel, ...
                     'Style', 'pushbutton', ...
                     'String', 'Export Both Plots', ...
                     'Units', 'normalized', ...
                     'Position', [0.1, 0.1, 0.8, 0.25], ...
                     'FontSize', 11, ...
                     'FontWeight', 'bold', ...
                     'BackgroundColor', [0.5, 0.2, 0.8], ...
                     'ForegroundColor', 'white', ...
                     'UserData', struct('plotData', problemPlotData, 'plotType', 'Both'), ...
                     'Callback', @exportFullSizePlot);
        end
    
        % Store plot data in figure
        mainData.plotData = plotDataCollection;
        fig.UserData = mainData;
    
        % Make the first tab active
        if ~isempty(tabGroup.Children)
            tabGroup.SelectedTab = tabGroup.Children(1);
        end
    end
    
    %% Export full-size plot function
    function exportFullSizePlot(src, ~)
        buttonData = src.UserData;
        plotData = buttonData.plotData;
        plotType = buttonData.plotType;
        
        % Create export directory if it doesn't exist
        exportDir = 'ExportedPlots';
        if ~exist(exportDir, 'dir')
            mkdir(exportDir);
        end
        
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        
        if strcmp(plotType, 'HV') || strcmp(plotType, 'Both')
            % Create full-size HV figure
            hvFig = figure('Position', [100, 100, 1200, 800], ...
                          'Name', sprintf('HV - %s', plotData.problem));
            ax = axes('Parent', hvFig, 'Position', [0.1, 0.1, 0.85, 0.85]);
            
            % Plot HV data
            hold(ax, 'on');
            legendEntries = {};
            for a = 1:length(plotData.algorithms)
                alg = plotData.algorithms{a};
                hvInfo = plotData.hvData{a};
                color = plotData.colors(a, :);
                
                % Plot mean line
                plot(ax, hvInfo.FE, hvInfo.mean, 'LineWidth', 2.5, ...
                    'Color', color, 'DisplayName', alg);
                
                % Plot confidence interval
                fill(ax, [hvInfo.FE; flipud(hvInfo.FE)], ...
                     [hvInfo.mean + hvInfo.std; flipud(hvInfo.mean - hvInfo.std)], ...
                     color, 'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
                     'HandleVisibility', 'off');
                
                legendEntries{end+1} = alg;
            end
            
            % Customize
            xlabel(ax, 'Function Evaluations', 'FontSize', 14, 'FontWeight', 'bold');
            ylabel(ax, 'Hypervolume', 'FontSize', 14, 'FontWeight', 'bold');
            titleStr = sprintf('%s (M=%d, D=%d) - Hypervolume Evolution', ...
                              plotData.problemName, plotData.M, plotData.D);
            title(ax, titleStr, 'FontSize', 16, 'FontWeight', 'bold');
            grid(ax, 'on');
            legend(ax, legendEntries, 'Location', 'best', 'FontSize', 12);
            EnlargeFont();
            
            % Save figure
            filename = sprintf('%s/HV_%s_%s.png', exportDir, plotData.problem, timestamp);
            saveas(hvFig, filename);
            filename_fig = sprintf('%s/HV_%s_%s.fig', exportDir, plotData.problem, timestamp);
            saveas(hvFig, filename_fig);
            
            fprintf('HV plot exported to: %s\n', filename);
            close(hvFig);
        end
        
        if strcmp(plotType, 'CV') || strcmp(plotType, 'Both')
            % Create full-size CV figure
            cvFig = figure('Position', [100, 100, 1200, 800], ...
                          'Name', sprintf('CV - %s', plotData.problem));
            ax = axes('Parent', cvFig, 'Position', [0.1, 0.1, 0.85, 0.85]);
            
            % Plot CV data
            hold(ax, 'on');
            legendEntries = {};
            for a = 1:length(plotData.algorithms)
                alg = plotData.algorithms{a};
                cvInfo = plotData.cvData{a};
                color = plotData.colors(a, :);
                
                % Plot mean line
                plot(ax, cvInfo.FE, cvInfo.mean, 'LineWidth', 2.5, ...
                    'Color', color, 'DisplayName', alg);
                
                % Plot confidence interval
                fill(ax, [cvInfo.FE; flipud(cvInfo.FE)], ...
                     [cvInfo.mean + cvInfo.std; flipud(cvInfo.mean - cvInfo.std)], ...
                     color, 'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
                     'HandleVisibility', 'off');
                
                legendEntries{end+1} = alg;
            end
            
            % Customize
            xlabel(ax, 'Function Evaluations', 'FontSize', 14, 'FontWeight', 'bold');
            ylabel(ax, 'Average Constraint Violation', 'FontSize', 14, 'FontWeight', 'bold');
            titleStr = sprintf('%s (M=%d, D=%d) - Constraint Violation Evolution', ...
                              plotData.problemName, plotData.M, plotData.D);
            title(ax, titleStr, 'FontSize', 16, 'FontWeight', 'bold');
            grid(ax, 'on');
            legend(ax, legendEntries, 'Location', 'best', 'FontSize', 12);
            EnlargeFont();
            
            % Save figure
            filename = sprintf('%s/CV_%s_%s.png', exportDir, plotData.problem, timestamp);
            saveas(cvFig, filename);
            filename_fig = sprintf('%s/CV_%s_%s.fig', exportDir, plotData.problem, timestamp);
            saveas(cvFig, filename_fig);
            
            fprintf('CV plot exported to: %s\n', filename);
            close(cvFig);
        end
        
        if strcmp(plotType, 'Both')
            msgbox(sprintf('Both plots exported to:\n%s/', exportDir), 'Export Successful', 'help');
        else
            msgbox(sprintf('%s plot exported to:\n%s/', plotType, exportDir), 'Export Successful', 'help');
        end
    end
end