function visualizeResultsGeneric(algorithmSpecs, problems, Mvec, Dvec, IDvec, problemNames, algDisplayNames)
%VISUALIZERESULTSGENERIC Algorithm-agnostic population visualization
%
%   visualizeResultsGeneric(algorithmSpecs, problems, Mvec, Dvec, IDvec, problemNames, algDisplayNames)
%
%   Drop-in replacement for visualizeResults.m that works with any algorithm.
%   Does NOT require alg2norm, NormStruct, reference vectors, or ComputeMindist.
%   Simply plots all solutions as red circles with PF overlay.
%
%   Input:
%     algorithmSpecs  - Cell array of algorithm specs (handles or config cells)
%     problems        - Cell array of problem function handles
%     Mvec            - Numeric vector of M values (one per problem)
%     Dvec            - Numeric vector of D values (NaN = auto)
%     IDvec           - Numeric vector of instance IDs (NaN = none)
%     problemNames    - Cell array of pipeline names
%     algDisplayNames - containers.Map of internal→display names
%
%   Output:
%     Saves PNG files to ./Visualization/images/GP-{alg}-{prob}-M{M}-D{D}.png

    fprintf('=== Generating Generic Visualizations ===\n');

    if nargin < 3 || isempty(Mvec)
        Mvec = [];
    end
    if nargin < 4 || isempty(Dvec)
        Dvec = nan(1, numel(problems));
    end
    if nargin < 5 || isempty(IDvec)
        IDvec = nan(1, numel(problems));
    end
    if nargin < 6 || isempty(problemNames)
        problemNames = cellfun(@func2str, problems, 'UniformOutput', false);
    end
    if nargin < 7
        algDisplayNames = containers.Map();
    end

    %% Configuration
    config = struct(...
        'rootDirHV',   './Info/MedianHVResults', ...
        'rootDirData', './Data', ...
        'boundDir',    './Info/Bounds', ...
        'outputDir',   './Visualization/images');

    ensureDirExists(config.boundDir);
    ensureDirExists(config.outputDir);

    %% Get algorithm names
    algorithmNames = cell(1, numel(algorithmSpecs));
    for i = 1:numel(algorithmSpecs)
        algorithmNames{i} = getAlgorithmName(algorithmSpecs{i});
    end

    %% Load HV metadata for all algorithms
    [allResults, allProblems] = loadHVMetadata(algorithmNames, config);

    if isempty(allProblems)
        warning('No median HV data found. Skipping population visualization.');
    else
        %% Visualize median populations for each problem
        for pi = 1:numel(allProblems)
            problem = allProblems{pi};

            fprintf('\n=============================================\n');
            fprintf('Processing Problem: %s (%d/%d)\n', problem, pi, numel(allProblems));
            fprintf('=============================================\n');

            % Load or compute bounds
            bounds = loadOrComputeBounds(problem, algorithmNames, allResults, config, ...
                problems, Dvec, IDvec, problemNames);

            if isempty(bounds)
                warning('Could not obtain bounds for %s, skipping.', problem);
                continue;
            end

            % Load PF for this problem
            PF = loadPFForProblem(problem);

            % Visualize each algorithm
            for ai = 1:numel(algorithmSpecs)
                algName = algorithmNames{ai};

                if ~hasData(allResults, algName, problem)
                    continue;
                end

                visualizeSingleResult(algName, problem, bounds, PF, ...
                    allResults, config, algDisplayNames);
            end
        end
    end

    %% Visualize Pareto fronts (reuse same logic as visualizeResults.m)
    fprintf('\n=== Drawing Pareto Fronts ===\n');
    for i = 1:numel(problems)
        M_i = Mvec(i);
        if M_i > 3
            continue;
        end

        probName = problemNames{i};
        PF = loadPFForProblem(probName);

        if isempty(PF)
            fprintf('  Skipping PF for %s: no reference PF found.\n', probName);
            continue;
        end

        DrawParetoFrontFromPF(probName, PF, M_i, config.outputDir);
    end

    fprintf('\n=== Generic visualization completed ===\n');
end

%% ==================== HELPER FUNCTIONS ====================

function ensureDirExists(dirPath)
    if ~exist(dirPath, 'dir')
        mkdir(dirPath);
    end
end

function [allResults, allProblems] = loadHVMetadata(algorithmNames, config)
    allResults = struct();
    allProblems = {};

    for ai = 1:numel(algorithmNames)
        algName = algorithmNames{ai};
        hvFile = fullfile(config.rootDirHV, sprintf('MedianHV_%s.mat', algName));

        if ~exist(hvFile, 'file')
            warning('Median HV file missing: %s', hvFile);
            continue;
        end

        hvData = load(hvFile);
        validName = matlab.lang.makeValidName(algName);
        allResults.(validName) = hvData.results;
        allResults.(validName).originalName = algName;
        allProblems = union(allProblems, fieldnames(hvData.results));
    end
end

function tf = hasData(allResults, algName, problem)
    validName = matlab.lang.makeValidName(algName);
    tf = isfield(allResults, validName) && isfield(allResults.(validName), problem);
end

function dataPath = getDataPath(algName, problem, allResults, config)
    validName = matlab.lang.makeValidName(algName);
    medianFilenameHV = allResults.(validName).(problem).medianFile;
    dataFilename = erase(medianFilenameHV, 'HV_');
    dataPath = fullfile(config.rootDirData, algName, dataFilename);
end

function PF = loadPFForProblem(probName)
%LOADPFFORPROBLEM Load reference PF with fallback
    PF = [];
    try
        [PF, ~, ~] = loadReferencePF(probName);
    catch
        fprintf('  Warning: Could not load reference PF for %s\n', probName);
    end
end

function bounds = loadOrComputeBounds(problem, algorithmNames, allResults, config, ...
    problems, Dvec, IDvec, problemNames)

    boundPath = fullfile(config.boundDir, sprintf('bound-%s.mat', problem));

    % Try loading existing bounds first
    if exist(boundPath, 'file')
        fprintf('  Loading existing bounds: %s\n', problem);
        bounds = loadBounds(boundPath);
        return;
    end

    % Compute bounds from scratch
    fprintf('  Computing bounds: %s\n', problem);
    bounds = computeBounds(problem, algorithmNames, allResults, config, ...
        problems, Dvec, IDvec, problemNames);

    if ~isempty(bounds)
        saveBounds(boundPath, bounds);
    end
end

function bounds = loadBounds(boundPath)
    data = load(boundPath);

    bounds = struct();
    bounds.XBounds = data.XBounds;
    bounds.YBounds = data.YBounds;

    if isfield(data, 'ZBounds')
        bounds.ZBounds = data.ZBounds;
        bounds.M = 3;
    else
        bounds.M = 2;
    end
end

function saveBounds(boundPath, bounds)
    XBounds = bounds.XBounds; %#ok<NASGU>
    YBounds = bounds.YBounds; %#ok<NASGU>

    if bounds.M >= 3
        ZBounds = bounds.ZBounds; %#ok<NASGU>
        save(boundPath, 'XBounds', 'YBounds', 'ZBounds');
    else
        save(boundPath, 'XBounds', 'YBounds');
    end
end

function bounds = computeBounds(problem, algorithmNames, allResults, config, ...
    problems, Dvec, IDvec, problemNames)

    bounds = [];
    globalLow = [];
    globalHigh = [];
    M = 0;
    pfIncluded = false;

    for ai = 1:numel(algorithmNames)
        algName = algorithmNames{ai};

        if ~hasData(allResults, algName, problem)
            continue;
        end

        dataPath = getDataPath(algName, problem, allResults, config);
        if ~exist(dataPath, 'file')
            continue;
        end

        data = load(dataPath, 'result');
        if ~isfield(data, 'result')
            continue;
        end

        resultMatrix = data.result;
        lastPop = resultMatrix{end, 2};
        objs = lastPop.objs;
        M = size(objs, 2);

        % Include PF once
        if ~pfIncluded
            PF = loadPFForProblem(problem);
            if ~isempty(PF)
                objs = [objs; PF]; %#ok<AGROW>
            end
            pfIncluded = true;
        end

        % Update global bounds
        [globalLow, globalHigh] = updateBounds(globalLow, globalHigh, objs);

        clear data resultMatrix lastPop;
    end

    if isempty(globalLow)
        return;
    end

    bounds = buildBoundsStruct(globalLow, globalHigh, M);
end

function [globalLow, globalHigh] = updateBounds(globalLow, globalHigh, objs)
    low = min(objs);
    high = max(objs);

    if isempty(globalLow)
        globalLow = low;
        globalHigh = high;
    else
        globalLow = min(globalLow, low);
        globalHigh = max(globalHigh, high);
    end
end

function bounds = buildBoundsStruct(globalLow, globalHigh, M)
    bounds = struct();
    bounds.M = M;
    bounds.XBounds = roundc([globalLow(1), globalHigh(1)]);
    bounds.YBounds = roundc([globalLow(2), globalHigh(2)]);

    if M >= 3
        bounds.ZBounds = roundc([globalLow(3), globalHigh(3)]);
    end
end

function new_interval = roundc(interval)
    range = diff(interval);
    if range == 0
        new_interval = interval;
        return;
    end
    scale = 10^floor(log10(range / 10));
    new_lower = floor(interval(1) / scale) * scale;
    new_upper = ceil(interval(2) / scale) * scale;
    new_interval = [new_lower, new_upper];
end

%% ==================== VISUALIZATION ====================

function visualizeSingleResult(algName, problem, bounds, PF, allResults, config, algDisplayNames)
    fprintf('  Visualizing: %s on %s\n', algName, problem);

    % Load data
    dataPath = getDataPath(algName, problem, allResults, config);
    if ~exist(dataPath, 'file')
        warning('Data file missing: %s', dataPath);
        return;
    end

    data = load(dataPath);
    if ~isfield(data, 'result')
        return;
    end

    resultMatrix = data.result;
    lastPop = resultMatrix{end, 2};
    objs = lastPop.objs;

    M = size(objs, 2);
    D = size(lastPop.decs, 2);

    if M > 3
        clear data resultMatrix lastPop;
        return;
    end

    % Get display names
    if isKey(algDisplayNames, algName)
        algDisplay = algDisplayNames(algName);
    else
        algDisplay = algName;
    end
    probDisplay = strrep(problem, '_', ' ');

    % Output path
    savePath = fullfile(config.outputDir, ...
        sprintf('GP-%s-%s-M%d-D%d.png', algName, problem, M, D));

    % Render with consistent axis bounds across algorithms
    reRenderWithBounds(algDisplay, probDisplay, objs, PF, bounds, savePath);

    clear data resultMatrix lastPop;
end

function reRenderWithBounds(algDisplay, probDisplay, objs, PF, bounds, savePath)
%RERENDERWITHBOUNDS Render with consistent axis bounds across algorithms

    M = size(objs, 2);
    N = size(objs, 1);

    PreprocessProductionImage(2/3, 1, 8.8);
    fig = gcf;
    ax = gca;
    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    if M >= 3
        view(ax, 135, 30);
    else
        view(ax, 2);
    end

    xlabel(ax, '$f_1$', 'Interpreter', 'Latex');
    ylabel(ax, '$f_2$', 'Interpreter', 'Latex');
    if M >= 3
        zlabel(ax, '$f_3$', 'Interpreter', 'Latex');
    end

    % Draw PF behind
    if ~isempty(PF)
        if M == 2
            plot(ax, PF(:,1), PF(:,2), '.k', 'MarkerSize', 3, ...
                'HandleVisibility', 'off');
        else
            plot3(ax, PF(:,1), PF(:,2), PF(:,3), '.k', 'MarkerSize', 5, ...
                'HandleVisibility', 'off');
        end
    end

    % Draw population
    if M == 2
        scatter(ax, objs(:,1), objs(:,2), 180, ...
            'r', 'filled', 'MarkerEdgeColor', 'k', ...
            'MarkerFaceAlpha', 1, 'MarkerEdgeAlpha', 1, 'LineWidth', 1.5);
    else
        scatter3(ax, objs(:,1), objs(:,2), objs(:,3), 180, ...
            'r', 'filled', 'MarkerEdgeColor', 'k', ...
            'MarkerFaceAlpha', 1, 'MarkerEdgeAlpha', 1, 'LineWidth', 1.5);
    end

    % Apply consistent bounds
    set(ax, 'XLim', bounds.XBounds, 'XTick', bounds.XBounds);
    set(ax, 'YLim', bounds.YBounds, 'YTick', bounds.YBounds);
    set(ax, 'XTickLabelRotation', 0, 'YTickLabelRotation', 0);

    if M >= 3 && isfield(bounds, 'ZBounds')
        set(ax, 'ZLim', bounds.ZBounds, 'ZTick', bounds.ZBounds);
        set(ax, 'ZTickLabelRotation', 0);
    end

    % Legend
    if M == 2
        h_pop = plot(ax, NaN, NaN, 'o', ...
            'MarkerSize', 20, 'MarkerEdgeColor', 'k', ...
            'MarkerFaceColor', [1 0 0], 'LineWidth', 1.5);
    else
        h_pop = plot3(ax, NaN, NaN, NaN, 'o', ...
            'MarkerSize', 20, 'MarkerEdgeColor', 'k', ...
            'MarkerFaceColor', [1 0 0], 'LineWidth', 1.5);
    end

    legend(ax, h_pop, sprintf('Algorithm: %s', algDisplay), ...
        'Location', 'southoutside');

    title(ax, sprintf('%s (%d solutions)', probDisplay, N));

    % Axis styling
    axis(ax, 'square');
    set(ax.Title, 'String', '');

    if M == 2
        set(ax, 'Position', [0.32 0.35 0.36 0.57]);
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
    else
        set(ax, 'Position', [0.2 0.35 0.6 0.6]);
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
    end

    % 3D lighting
    if M == 3
        axis(ax, 'vis3d');
        box(ax, 'on');
        lighting(ax, 'gouraud');
        light('Position', [1 1 1], 'Style', 'infinite');
        light('Position', [-1 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);
    end

    drawnow;

    % Export
    exportgraphics(fig, savePath, 'Resolution', 300);
    close(fig);
end

function DrawParetoFrontFromPF(pipelineName, PF, M, outputDir)
%DRAWPARETOFRONTFROMPF Draw Pareto front from loaded reference PF

    if M > 3
        return;
    end

    fprintf('  Drawing PF: %s\n', pipelineName);

    PreprocessProductionImage(2/3, 1, 8.8);
    fig = gcf;
    ax = gca;
    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    axis(ax, 'square');

    if M == 2
        plot(ax, PF(:,1), PF(:,2), '.k', 'MarkerSize', 20);
    elseif M == 3
        plot3(ax, PF(:,1), PF(:,2), PF(:,3), '.k', 'MarkerSize', 25);
    end

    xlabel(ax, '$f_1$', 'Interpreter', 'Latex');
    ylabel(ax, '$f_2$', 'Interpreter', 'Latex');

    if M == 3
        zlabel(ax, '$f_3$', 'Interpreter', 'Latex');
        view(ax, 135, 30);
        box(ax, 'on');
        lighting(ax, 'gouraud');
        light('Position', [1 1 1], 'Style', 'infinite');
    else
        view(ax, 2);
    end

    % Legend
    displayName = strrep(pipelineName, '_', '\_');
    hold on;
    h1 = plot(NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');
    h2 = plot(NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');
    legend([h1, h2], ...
        sprintf('Problem: %s', displayName), ...
        sprintf('$m$ = %d, PF (%d pts)', M, size(PF, 1)), ...
        'Location', 'south', ...
        'Interpreter', 'latex');

    if M == 2
        set(ax, 'Position', [0.32 0.35 0.36 0.57]);
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
    else
        set(ax, 'Position', [0.2 0.35 0.6 0.6]);
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
    end

    filename = fullfile(outputDir, sprintf('PF-%s-M%d-D0.png', pipelineName, M));
    exportgraphics(fig, filename, 'Resolution', 150);
    close(fig);
end
