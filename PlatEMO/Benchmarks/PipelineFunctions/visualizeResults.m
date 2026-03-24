function visualizeResults(algorithmSpecs, problems, Mvec, Dvec, IDvec, problemNames)
%VISUALIZERESULTS Generate visualizations for median HV run populations
%
%   visualizeResults(algorithmSpecs, problems)
%   visualizeResults(algorithmSpecs, problems, Mvec, Dvec, IDvec, problemNames)
%
%   Input:
%     algorithmSpecs - Cell array of algorithm specs (handles or config cells)
%     problems       - Cell array of problem function handles
%     Mvec           - (optional) Numeric vector of M values (one per problem)
%     Dvec           - (optional) Numeric vector of D values (NaN = auto)
%     IDvec          - (optional) Numeric vector of instance IDs (NaN = none)
%     problemNames   - (optional) Cell array of pipeline names
%
%   Generates:
%     - Pareto front visualizations for each problem
%     - Median HV population visualizations for each algorithm

    fprintf('=== Generating Visualizations ===\n');

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

    % Build a lookup from pipeline name to problem spec
    probLookup = containers.Map();
    for i = 1:numel(problemNames)
        probLookup(matlab.lang.makeValidName(problemNames{i})) = struct( ...
            'handle', problems{i}, ...
            'D', Dvec(i), ...
            'ID', IDvec(i));
    end

    % Configuration
    config = struct(...
        'rootDirHV',   './Info/MedianHVResults', ...
        'rootDirData', './Data', ...
        'boundDir',    './Info/Bounds', ...
        'outputDir',   './Visualization/images');

    ensureDirExists(config.boundDir);
    ensureDirExists(config.outputDir);

    % Get algorithm names for all specs
    algorithmNames = cell(1, numel(algorithmSpecs));
    for i = 1:numel(algorithmSpecs)
        algorithmNames{i} = getAlgorithmName(algorithmSpecs{i});
    end

    % Load HV metadata for all algorithms
    [allResults, allProblems] = loadHVMetadata(algorithmNames, config);

    flag = 0;
    if isempty(allProblems)
        warning('No median HV data found. Skipping population visualization.');
    else
        % Visualize median populations for each problem
        for pi = 1:numel(allProblems)
            problem = allProblems{pi};

            % if (flag == 0) && (~strcmp(problem, "MinusWFG2"))
            %     continue
            % else
            %     flag = 1;
            % end

            fprintf('\n=============================================\n');
            fprintf('Processing Problem: %s (%d/%d)\n', problem, pi, numel(allProblems));
            fprintf('=============================================\n');

            % Load or compute bounds
            bounds = loadOrComputeBounds(problem, algorithmNames, allResults, config, probLookup);

            if isempty(bounds)
                warning('Could not obtain bounds for %s, skipping.', problem);
                continue;
            end

            % Visualize each algorithm
            for ai = 1:numel(algorithmSpecs)
                algName = algorithmNames{ai};

                if ~hasData(allResults, algName, problem)
                    continue;
                end

                visualizeSingleResult(algName, problem, bounds, allResults, config, probLookup);
            end
        end
    end

    % Visualize Pareto fronts
    fprintf('\n=== Drawing Pareto Fronts ===\n');
    for i = 1:numel(problems)
        M_i = Mvec(i);
        if M_i > 3
            continue;  % Skip problems with more than 3 objectives
        end
        if ~isnan(IDvec(i))
            % Combinatorial: draw from stored reference PF
            pipeName = problemNames{i};
            DrawParetoFrontFromRefPF(pipeName, M_i, config.outputDir);
        else
            ph = problems{i};
            Problem = ph('M', M_i);
            DrawParetoFront(Problem, config.outputDir);
        end
    end

    fprintf('\n=== Visualization completed ===\n');
end

%% ==================== HELPER FUNCTIONS ====================

function ensureDirExists(dirPath)
    if ~exist(dirPath, 'dir')
        mkdir(dirPath);
    end
end

function [allResults, allProblems] = loadHVMetadata(algorithmNames, config)
    % Load HV metadata (filenames) for all algorithms
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
        % Use valid field name for struct
        validName = matlab.lang.makeValidName(algName);
        allResults.(validName) = hvData.results;
        allResults.(validName).originalName = algName;  % Store original name
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

function bounds = loadOrComputeBounds(problem, algorithmNames, allResults, config, probLookup)
    boundPath = fullfile(config.boundDir, sprintf('bound-%s.mat', problem));

    % Try loading existing bounds first
    if exist(boundPath, 'file')
        fprintf('  Loading existing bounds: %s\n', problem);
        bounds = loadBounds(boundPath);
        return;
    end

    % Compute bounds from scratch
    fprintf('  Computing bounds: %s\n', problem);
    bounds = computeBounds(problem, algorithmNames, allResults, config, probLookup);

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
    XBounds = bounds.XBounds;
    YBounds = bounds.YBounds;

    if bounds.M >= 3
        ZBounds = bounds.ZBounds;
        save(boundPath, 'XBounds', 'YBounds', 'ZBounds');
    else
        save(boundPath, 'XBounds', 'YBounds');
    end
end

function bounds = computeBounds(problem, algorithmNames, allResults, config, probLookup)
    bounds = [];
    globalLow = [];
    globalHigh = [];
    M = 0;
    optimumIncluded = false;

    for ai = 1:numel(algorithmNames)
        algName = algorithmNames{ai};

        if ~hasData(allResults, algName, problem)
            continue;
        end

        dataPath = getDataPath(algName, problem, allResults, config);
        if ~exist(dataPath, 'file')
            continue;
        end

        % Load only 'result' variable
        data = load(dataPath, 'result');
        if ~isfield(data, 'result')
            continue;
        end

        resultMatrix = data.result;
        lastPop = resultMatrix{end, 2};
        objs = lastPop.objs;

        M = size(objs, 2);
        D = size(lastPop.decs, 2);

        % Instantiate problem (handle combinatorial via lookup)
        if isKey(probLookup, problem)
            spec = probLookup(problem);
            if ~isnan(spec.ID)
                rawName = func2str(spec.handle);
                paramCell = buildCombinatorialParam(rawName, spec.ID);
                Problem = spec.handle('M', M, 'D', D, 'parameter', paramCell);
            else
                Problem = spec.handle('M', M, 'D', D);
            end
        else
            ph = str2func(problem);
            Problem = ph('M', M, 'D', D);
        end

        % Include Pareto front once
        if ~optimumIncluded
            objs = [objs; getOptimumPoints(Problem, M, D)];
            optimumIncluded = true;
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

function visualizeSingleResult(algName, problem, bounds, allResults, config, probLookup)
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
    FE = resultMatrix{end, 1};

    M = size(lastPop.objs, 2);
    D = size(lastPop.decs, 2);
    N = size(lastPop, 2);

    % Setup problem and reference points (handle combinatorial via lookup)
    if isKey(probLookup, problem)
        spec = probLookup(problem);
        if ~isnan(spec.ID)
            rawName = func2str(spec.handle);
            paramCell = buildCombinatorialParam(rawName, spec.ID);
            Problem = spec.handle('M', M, 'D', D, 'parameter', paramCell);
        else
            Problem = spec.handle('M', M, 'D', D);
        end
    else
        Problem_handle = str2func(problem);
        Problem = Problem_handle('M', M, 'D', D);
    end
    [Z, ~] = UniformPoint(N, M);

    % Create normalization structure
    NormStruct = alg2norm(algName, N, M);

    % Run normalization through history
    runNormalization(algName, Problem, NormStruct, resultMatrix);

    % Render
    PreprocessProductionImage(2/3, 1, 8.8);
    Algorithm = str2func(algName);
    VisualizeMindistPopulation(Algorithm, lastPop, Z, Problem, FE, NormStruct);

    ax = gca;
    fig = gcf;

    applyAxisStyle(ax, bounds);
    DrawParetoFrontOverlay(Problem);
    drawnow;

    % Export and cleanup
    filename = fullfile(config.outputDir, ...
        sprintf('MP-%s-%s-M%d-D%d.png', algName, problem, M, D));
    exportgraphics(fig, filename, 'Resolution', 300);
    close(fig);

    clear data resultMatrix lastPop;
end

function runNormalization(algName, Problem, NormStruct, resultMatrix)
    n_gens = size(resultMatrix, 1);

    % First generation
    Pop = resultMatrix{1, 2};
    nds = nds_preprocess(Pop);
    norm_update(algName, Problem, NormStruct, Pop, nds);

    % Subsequent generations
    for g = 2:n_gens
        Pop = resultMatrix{g-1, 2};
        Offspring = resultMatrix{g, 3};
        Mixture = [Pop, Offspring];
        nds = nds_preprocess(Mixture);
        norm_update(algName, Problem, NormStruct, Mixture, nds);
    end
end

function applyAxisStyle(ax, bounds)
    M = bounds.M;
    XBounds = bounds.XBounds;
    YBounds = bounds.YBounds;

    set(ax.Title, 'String', '');
    axis(ax, 'square');

    set(ax, 'XLim', XBounds, 'XTick', XBounds);
    set(ax, 'YLim', YBounds, 'YTick', YBounds);
    set(ax, 'XTickLabelRotation', 0, 'YTickLabelRotation', 0);

    if M >= 3
        ZBounds = bounds.ZBounds;
        set(ax, 'ZLim', ZBounds, 'ZTick', ZBounds);
        set(ax, 'ZTickLabelRotation', 0);
    end

    if M == 2
        set(ax, 'Position', [0.32 0.35 0.36 0.57]);
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
    else
        set(ax, 'Position', [0.2 0.35 0.6 0.6]);
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
    end
end

function DrawParetoFrontOverlay(Problem)
    ax = gca;
    hold(ax, 'on');

    
    markersize2D = 3;
    markersize3D = 5;
    

    optimum = getOptimumPoints(Problem, Problem.M, Problem.D);
    optimum = optimum(NDSort(optimum, 1) == 1, :);

    if size(optimum, 1) > 1 && Problem.M < 4
        if Problem.M == 2
            plot(ax, optimum(:,1), optimum(:,2), '.k', 'MarkerSize', markersize2D, ...
                'HandleVisibility', 'off');
        elseif Problem.M == 3
            plot3(ax, optimum(:,1), optimum(:,2), optimum(:,3), '.k', 'MarkerSize', markersize3D, ...
                'HandleVisibility', 'off');
        end
    end

    hold(ax, 'off');
end

function DrawParetoFront(Problem, outputDir)
    fprintf('  Drawing PF: %s\n', class(Problem));

    PreprocessProductionImage(2/3, 1, 8.8);
    fig = gcf;
    ax = gca;
    cla(ax);
    hold(ax, 'on');
    grid(ax, 'on');
    box(ax, 'on');
    axis(ax, 'square');

    % Get Pareto front
    optimum = getOptimumPoints(Problem, Problem.M, Problem.D);

    if size(optimum, 1) > 1 && Problem.M < 4
        if Problem.M == 2
            plot(ax, optimum(:,1), optimum(:,2), '.k', 'MarkerSize', 20);
        elseif Problem.M == 3
            plot3(ax, optimum(:,1), optimum(:,2), optimum(:,3), '.k', 'MarkerSize', 25);
        end
    end

    xlabel(ax, '$f_1$', 'Interpreter', 'Latex');
    ylabel(ax, '$f_2$', 'Interpreter', 'Latex');

    if Problem.M == 3
        zlabel(ax, '$f_3$', 'Interpreter', 'Latex');
        view(ax, 135, 30);
        box(ax, 'on');
        lighting(ax, 'gouraud');
        light('Position', [1 1 1], 'Style', 'infinite');
    else
        view(ax, 2);
    end

    % Legend
    hold on
    h1 = plot(NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');
    h2 = plot(NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');
    legend([h1, h2], ...
        sprintf('Problem: %s', class(Problem)), ...
        sprintf('$m$ = %d, $n$ = %d', Problem.M, Problem.D), ...
        'Location', 'south', ...
        'Interpreter', 'latex');

    if Problem.M == 2
        set(ax, 'Position', [0.32 0.35 0.36 0.57]);
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
    else
        set(ax, 'Position', [0.2 0.35 0.6 0.6]);
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
    end

    % Save
    filename = fullfile(outputDir, sprintf('PF-%s-M%d-D%d.png', ...
        class(Problem), Problem.M, Problem.D));
    exportgraphics(fig, filename, 'Resolution', 150);
    close(fig);
end

function DrawParetoFrontFromRefPF(pipelineName, M, outputDir)
%DRAWPARETOFRONTFROMREFPF Draw approximate PF for combinatorial problems
%   Loads the stored reference PF and plots it (M <= 3 only).

    refPFFile = fullfile('./Info/ReferencePF', sprintf('RefPF-%s.mat', pipelineName));
    if ~exist(refPFFile, 'file')
        fprintf('  Skipping PF for %s: no reference PF found.\n', pipelineName);
        return;
    end

    fprintf('  Drawing PF: %s (from reference PF)\n', pipelineName);
    [PF, ~, ~] = loadReferencePF(pipelineName);

    PreprocessProductionImage(2/3, 1, 8.8);
    fig = gcf;
    ax = gca;
    cla(ax);
    hold(ax, 'on');
    grid(ax, 'on');
    box(ax, 'on');
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
    hold on
    h1 = plot(NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');
    h2 = plot(NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');
    legend([h1, h2], ...
        sprintf('Problem: %s', displayName), ...
        sprintf('$m$ = %d, Approx.\\ PF (%d pts)', M, size(PF, 1)), ...
        'Location', 'south', ...
        'Interpreter', 'latex');

    if M == 2
        set(ax, 'Position', [0.32 0.35 0.36 0.57]);
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
    else
        set(ax, 'Position', [0.2 0.35 0.6 0.6]);
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
    end

    % Save — use pipeline name with D=0 placeholder for combinatorial
    filename = fullfile(outputDir, sprintf('PF-%s-M%d-D0.png', pipelineName, M));
    exportgraphics(fig, filename, 'Resolution', 150);
    close(fig);
end
