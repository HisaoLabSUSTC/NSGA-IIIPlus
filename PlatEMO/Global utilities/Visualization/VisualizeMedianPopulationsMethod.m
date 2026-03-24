function VisualizeMedianPopulationsMethod(algorithmHandles)
    % Configuration
    config = struct(...
        'rootDirHV',   './Info/MedianHVResults', ...
        'rootDirData', './Data', ...
        'boundDir',    './Info/Bounds', ...
        'outputDir',   './Visualization/images');
    
    mkdir(config.boundDir);
    mkdir(config.outputDir);
    
    % Load lightweight metadata only (no population data)
    [allResults, allProblems] = loadHVMetadata(algorithmHandles, config);
    
    if isempty(allProblems)
        warning('No problems found to visualize.');
        return;
    end
    
    % Process each problem
    for pi = 1:numel(allProblems)
        problem = allProblems{pi};
        
        fprintf('\n=============================================\n');
        fprintf('Processing Problem: %s (%d/%d)\n', problem, pi, numel(allProblems));
        fprintf('=============================================\n');
        
        % Step 1: Load or compute bounds
        bounds = loadOrComputeBounds(problem, algorithmHandles, allResults, config);
        
        if isempty(bounds)
            warning('Could not obtain bounds for %s, skipping.', problem);
            continue;
        end
        
        % Step 2: Visualize each algorithm
        for ah = 1:numel(algorithmHandles)
            algName = func2str(algorithmHandles{ah});
            
            if ~hasData(allResults, algName, problem)
                continue;
            end
            
            visualizeSingleResult(algName, problem, bounds, allResults, config);
        end
    end
    
    fprintf('\nVisualization complete.\n');
end

function ensureDirExists(dirPath)
    if ~exist(dirPath, 'dir')
        mkdir(dirPath);
    end
end

function [allResults, allProblems] = loadHVMetadata(algorithmHandles, config)
    % Load only HV metadata (filenames), not population data
    allResults = struct();
    allProblems = {};
    

    for ah = 1:numel(algorithmHandles)
        algorithmHandles{ah}
        getAlgorithmName(algorithmHandles{ah})
        algName = func2str(algorithmHandles{ah}{:});
        hvFile = fullfile(config.rootDirHV, sprintf('MedianHV_%s.mat', algName));
        
        if ~exist(hvFile, 'file')
            warning('Median HV file missing: %s', hvFile);
            continue;
        end
        
        hvData = load(hvFile);
        allResults.(algName) = hvData.results;
        allProblems = union(allProblems, fieldnames(hvData.results));
    end
end

function tf = hasData(allResults, algName, problem)
    tf = isfield(allResults, algName) && isfield(allResults.(algName), problem);
end

function dataPath = getDataPath(algName, problem, allResults, config)
    medianFilenameHV = allResults.(algName).(problem).medianFile;
    dataFilename = erase(medianFilenameHV, 'HV_');
    dataPath = fullfile(config.rootDirData, algName, dataFilename);
end

function bounds = loadOrComputeBounds(problem, algorithmHandles, allResults, config)
    boundPath = fullfile(config.boundDir, sprintf('bound-%s.mat', problem));
    
    % Try loading existing bounds first
    if exist(boundPath, 'file')
        fprintf('  Loading existing bounds: %s\n', problem);
        bounds = loadBounds(boundPath);
        return;
    end
    
    % Compute bounds from scratch
    fprintf('  Computing bounds: %s\n', problem);
    bounds = computeBounds(problem, algorithmHandles, allResults, config);
    
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

function bounds = computeBounds(problem, algorithmHandles, allResults, config)
    bounds = [];
    globalLow = [];
    globalHigh = [];
    M = 0;
    optimumIncluded = false;
    
    for ah = 1:numel(algorithmHandles)
        algName = func2str(algorithmHandles{ah});
        
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
        ph = str2func(problem);
        Problem = ph('M', M, 'D', D);
        % Include Pareto front once
        if ~optimumIncluded
            objs = [objs; getOptimumPoints(Problem, M, D)];
            optimumIncluded = true;
        end
        
        % Update global bounds
        [globalLow, globalHigh] = updateBounds(globalLow, globalHigh, objs);
        
        % Free memory immediately
        clear data resultMatrix lastPop;
    end
    
    if isempty(globalLow)
        return;
    end
    
    bounds = buildBoundsStruct(globalLow, globalHigh, M);
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



function visualizeSingleResult(algName, problem, bounds, allResults, config)
    fprintf('  Visualizing: %s\n', algName);
    
    % Load data for this visualization only
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
    
    M = bounds.M;
    D = size(lastPop.decs, 2);
    N = size(lastPop, 2);
    
    % Setup
    Problem_handle = str2func(problem);
    Problem = Problem_handle('M', M, 'D', D);
    [Z, ~] = UniformPoint(N, M);
    NormStruct = alg2norm(algName, N, M);
    
    % Process normalization
    runNormalization(algName, Problem, NormStruct, resultMatrix);
    
    % Render
    PreprocessProductionImage(2/3, 1, 8.8);
    Algorithm = str2func(algName);
    VisualizeMindistPopulation(Algorithm, lastPop, Z, Problem, FE, NormStruct);
    
    ax = gca;
    fig = gcf;
    
    applyAxisStyle(ax, bounds);
    DrawParetoFrontMethodAugment(Problem);
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
    
    low = [XBounds(1), YBounds(1)];
    high = [XBounds(2), YBounds(2)];
    
    if M >= 3
        ZBounds = bounds.ZBounds;
        set(ax, 'ZLim', ZBounds, 'ZTick', ZBounds);
        set(ax, 'ZTickLabelRotation', 0);
        low(3) = ZBounds(1);
        high(3) = ZBounds(2);
    end
    
    shift = high - low;
    
    if M == 2
        set(ax, 'Position', [0.32 0.35 0.36 0.57]);
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
        set(ax.XLabel, 'Rotation', 0, 'Position', ...
            [low(1) + 0.5*shift(1), low(2) - 0.05*shift(2)]);
        set(ax.YLabel, 'Rotation', 0, 'Position', ...
            [low(1) - 0.1*shift(1), low(2) + 0.4*shift(2)]);
    else
        set(ax, 'Position', [0.2 0.35 0.6 0.6]);
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
        set(ax.XLabel, 'Rotation', 0, 'Position', ...
            [low(1) + 0.5*shift(1), low(2) + 1.1*shift(2), low(3)]);
        set(ax.YLabel, 'Rotation', 0, 'Position', ...
            [low(1) + 1.1*shift(1), low(2) + 0.5*shift(2), low(3)]);
        set(ax.ZLabel, 'Rotation', 0, 'Position', ...
            [low(1) + 0.62*shift(1), low(2) - 0.62*shift(2), low(3)]);
    end
end


function DrawParetoFrontMethodAugment(Problem, PF)
    %% Create figure for visualization
    fig = gcf; ax = gca;
    % cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); axis(ax, 'square'); 
    boundDir = fullfile('./Info/Bounds'); mkdir(boundDir)

    if nargin < 2
        %% LIMLIM
        optimum = getOptimumPoints(Problem, Problem.M, Problem.D);
        optimum = optimum(NDSort(optimum, 1)==1,:);
        optimumI = getLeastCrowdedPoints(optimum, 120);
        optimum = optimum(optimumI,:);
        PF = optimum;
    end
    
    optimum = PF;

    hold on
    if size(optimum,1) > 1 && Problem.M < 4
        if Problem.M == 2
            plot(ax,optimum(:,1),optimum(:,2),'.k', 'MarkerSize', 10, ...
                'HandleVisibility', 'off');
        elseif Problem.M == 3
            plot3(ax,optimum(:,1),optimum(:,2),optimum(:,3),'.k', 'MarkerSize', 15, ...
                'HandleVisibility', 'off');
        end
    end
    hold off

    xlabel(ax, '$f_1$', 'Interpreter', 'Latex');
    ylabel(ax, '$f_2$', 'Interpreter', 'Latex');

    if Problem.M == 3
        view(ax, 135, 30);
    else
        view(ax, 2); % top-down 2D view
    end


    if Problem.M == 3
        box(ax, 'on');
        zlabel(ax, '$f_3$', 'Interpreter', 'Latex');

        lighting(ax, 'gouraud');
        light('Position', [1 1 1], 'Style', 'infinite');
        light('Position', [-1 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);
    end

end

%% helper function
function new_interval = roundc(interval)
    % 1. Calculate the 'Scale'
    % We take the range, divide by 10, and find the nearest lower power of 10.
    range = diff(interval);
    scale = 10^floor(log10(range / 10));

    % 2. Round the limits
    % Floor the lower limit and Ceil the upper limit to expand the interval
    new_lower = floor(interval(1) / scale) * scale;
    new_upper = ceil(interval(2) / scale) * scale;

    new_interval = [new_lower, new_upper];
end


% function new_interval = roundc(interval)
%     new_interval = interval;
% end
