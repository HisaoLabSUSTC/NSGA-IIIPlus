% %% Task 0: Clean DATA
% disp("WARNING: WIPING DATA")
% pause(4)
% wipeDir('./Data')
% wipeDir('./TrimmedData')
% wipeDir('./IntermediateHV')
% wipeDir('./IntermediateIGDp')
% wipeDir('./Info/FinalHV')
% wipeDir('./Info/FinalIGD')
% wipeDir('./Info/MedianHVResults')
% wipeDir('./Info/IdealNadirHistory')
% wipeDir('./Info/InitialPopulation')
% wipeDir('./Info/StableStatistics')
% wipeDir('./Info/Bounds')
% wipeDir('./Visualization/images')

%% Task 1: Run algorithms
fprintf('Task 1: Collecting data...\n');

algorithms = {@PyNSGAIIIwH, @DSSPyNSGAIIIwH};
problems = {@BT9, @DTLZ6, @DTLZ7, ...
    @IDTLZ1, @IMOP6, @IMOP7, @IMOP8, ...
    @MaF14,@MaF15,...
    @RWA5, @RWA6, @RWA7,...
    @UF8, @WFG8};
% problems = {@IDTLZ1, @IDTLZ2};
ahs = algorithms; phs = problems;
ans = cellfun(@func2str, ahs, 'UniformOutput', false);
pns = cellfun(@func2str, phs, 'UniformOutput', false);

algDisplayNames = loadAlgDisplayNames();

FE = 100000;
N = 120;
M = 3;  
save_interval = ceil(FE/N);
runs = 5;

%% Generate initial populations
generateInitialPopulations(problems, N, M, runs);

%% Create all combinations
[P, A, R] = ndgrid(1:length(problems), 1:length(algorithms), 1:runs); combinations = [P(:), A(:), R(:)];
total_tasks = size(combinations, 1); fprintf('Starting %d parallel tasks...\n', total_tasks);

parfor idx = 1:total_tasks
    prob_idx = combinations(idx, 1); algo_idx = combinations(idx, 2); run_num = combinations(idx, 3);
    prob_name = func2str(problems{prob_idx}); algo_name = func2str(algorithms{algo_idx});
    pro_inst = problems{prob_idx}('M', M);

    initial_pop_path = fullfile('Info', 'InitialPopulation', ...
        sprintf('HS-%s_M%d_D%d_%d.mat', prob_name, pro_inst.M, pro_inst.D, run_num))
    prev_folder = fullfile('Data',algo_name);
    prev_file   = fullfile(prev_folder,sprintf( ...
        '%s_%s_M%d_D%d_%d.mat',algo_name,prob_name,pro_inst.M,pro_inst.D,run_num));

    %% Check if this run is evaluated already
    if isfile(prev_file)
        continue
    else
        %% If algorithm contains 'wH', we use initial population
        if contains(algo_name, 'wH')
            % Pass the file path as a parameter
            algorithm_with_param = {algorithms{algo_idx}, initial_pop_path}
        else
            % Use the original algorithm handle without parameters
            algorithm_with_param = algorithms{algo_idx};
            warning('MATLAB:PlatEMO', 'Algorithm %s does not use heuristic initial population.', algo_name);
        end
        platemo('problem', problems{prob_idx}, 'N', N, 'M', M, ...
            'save', save_interval, 'maxFE', FE, ...
            'algorithm', algorithm_with_param, 'run', run_num);
    end
    fprintf('Completed: %s with %s (Run %d)\n', prob_name, algo_name, run_num);
end

% Post-processing to count successes and errors
% Check which files were actually created
disp("Task completed.")




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Task 2: Trim Data
%% Parallel script to trim data files using parfor
% Run this once, then use TrimmedData for all future analyses
DataDir = './Data';
TrimmedDir = './TrimmedData';
ahs = algorithms; 
algorithmNames = cellfun(@func2str, ahs, 'UniformOutput', false);
%% Build task list
subdirs = dir(DataDir); subdirs = subdirs([subdirs.isdir]); 
subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));
srcPaths = {}; dstPaths = {};
for i = 1:length(subdirs)
    algorithmName = subdirs(i).name;
    if ~ismember(algorithmName, algorithmNames)
        continue
    end
    srcSubdir = fullfile(DataDir, algorithmName);
    dstSubdir = fullfile(TrimmedDir, algorithmName);    
    %% Create destination directory
    if ~exist(dstSubdir, 'dir')
        mkdir(dstSubdir);
    end    
    matFiles = dir(fullfile(srcSubdir, '*.mat'));
    for j = 1:length(matFiles)
        srcPath = fullfile(srcSubdir, matFiles(j).name);
        dstPath = fullfile(dstSubdir, matFiles(j).name);
        %% Skip if already processed
        if ~exist(dstPath, 'file')
            srcPaths{end+1} = srcPath;
            dstPaths{end+1} = dstPath;
        end
    end
end
total = numel(srcPaths); fprintf('Found %d files to process\n', total);

%% Process files with parfor
fprintf('Processing %d files...\n', total);
success = false(1, total);
parfor i = 1:total
    data = load(srcPaths{i});
    result = data.result;    
    finalPop = result{end, 2};    
    parsave(dstPaths{i}, finalPop);
    success(i) = true;
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Task 3: Precompute HV and IGDp
phs = problems; 
ahs = algorithms;
pns = cellfun(@func2str, phs, 'UniformOutput', false);
hpns = {};

subdirs = dir(TrimmedDir); subdirs = subdirs([subdirs.isdir]);
subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));

algorithmNames = cellfun(@func2str, ahs, 'UniformOutput', false);
numAlgorithms = length(algorithmNames); numProblems = numel(pns);
numPairs = numAlgorithms * numProblems;
pairAlgorithms = cell(1, numPairs);
pairProblems = cell(1, numPairs);

idx = 1;
for i = 1:numAlgorithms
    for k = 1:numProblems
        pairAlgorithms{idx} = algorithmNames{i};
        pairProblems{idx} = pns{k};
        idx = idx + 1;
    end
end

%% Set up intermediate directory
intermediateHVDir = './IntermediateHV';
if ~exist(intermediateHVDir, 'dir')
    mkdir(intermediateHVDir);
end
intermediateIGDDir = './IntermediateIGDp';
if ~exist(intermediateIGDDir, 'dir')
    mkdir(intermediateIGDDir);
end

%% Progress tracking
progressQueue = parallel.pool.DataQueue;
startTime = tic;
afterEach(progressQueue, @(data) progressCallback(data, numPairs, startTime));

fprintf('Phase 1: Computing HV/IGDp for %d (algorithm, problem) pairs...\n', numPairs);

%% Phase 1: Parallel HV/IGDp computation per (algorithm, problem) pair
parfor i = 1:numPairs
    alg = pairAlgorithms{i};
    prob = pairProblems{i};

    [hvValues, igdValues, numRuns] = processAlgorithmProblem(alg, prob, TrimmedDir, hpns, M, runs);

    % Save intermediate result
    outHVFile = fullfile(intermediateHVDir, sprintf('%s_%s.mat', alg, prob));
    saveIntermediateHV(outHVFile, hvValues);
    outIGDFile = fullfile(intermediateIGDDir, sprintf('%s_%s.mat', alg, prob));
    saveIntermediateIGD(outIGDFile, igdValues);

    send(progressQueue, struct('alg', alg, 'prob', prob, 'runs', numRuns));
end

fprintf('\nPhase 1 complete! Elapsed: %.1fs\n', toc(startTime));

intermediateHVDir = './IntermediateHV';
intermediateIGDDir = './IntermediateIGDp';

algorithmNames = cellfun(@func2str, algorithms, 'UniformOutput', false);
numAlgorithms = numel(algorithmNames);
numProblems = numel(pns);

for i = 1:numAlgorithms
    alg = algorithmNames{i};
    prob2hv_map = containers.Map();
    prob2igd = containers.Map();

    for k = 1:numProblems
        prob = pns{k};

        % Load intermediate HV
        intermediateHVFile = fullfile(intermediateHVDir, sprintf('%s_%s.mat', alg, prob));
        if exist(intermediateHVFile, 'file')
            HVdata = load(intermediateHVFile);
            prob2hv_map(prob) = HVdata.hvValues;
        end

        % Load intermediate IGD
        intermediateFile = fullfile(intermediateIGDDir, sprintf('%s_%s.mat', alg, prob));
        if exist(intermediateFile, 'file')
            IGDdata = load(intermediateFile);
            prob2igd(prob) = IGDdata.igdValues;
        end
    end

    % Save final HV result
    targetHVDir = sprintf('./Info/FinalHV/%s', alg);
    if ~exist(targetHVDir, 'dir')
        mkdir(targetHVDir);
    end
    save(fullfile(targetHVDir, 'prob2hv.mat'), 'prob2hv_map');
    fprintf('  Saved: %s\n', targetHVDir);

    % Save final IGD result
    targetIGDDir = sprintf('./Info/FinalIGD/%s', alg);
    if ~exist(targetIGDDir, 'dir')
        mkdir(targetIGDDir);
    end
    save(fullfile(targetIGDDir, 'prob2igdp.mat'), 'prob2igd');
    fprintf('  Saved: %s\n', targetIGDDir);
end

%% Phase 2: Collect intermediate results into final structure
fprintf('Phase 2: Collecting results...\n');

for i = 1:numAlgorithms
    alg = algorithmNames{i};
    prob2hv_map = containers.Map();
    prob2igd = containers.Map();

    for k = 1:numProblems
        prob = pns{k};
        intermediateHVFile = fullfile(intermediateHVDir, sprintf('%s_%s.mat', alg, prob));
        HVdata = load(intermediateHVFile);
        prob2hv_map(prob) = HVdata.hvValues;

        intermediateIGDFile = fullfile(intermediateIGDDir, sprintf('%s_%s.mat', alg, prob));
        IGDdata = load(intermediateIGDFile);
        prob2igd(prob) = IGDdata.igdValues;
    end

    % Save final result
    targetHVDir = sprintf('./Info/FinalHV/%s', alg);
    if ~exist(targetHVDir, 'dir')
        mkdir(targetHVDir);
    end
    save(fullfile(targetHVDir, 'prob2hv.mat'), 'prob2hv_map');
    fprintf('  Saved: %s\n', targetHVDir);

    targetIGDDir = sprintf('./Info/FinalIGD/%s', alg);
    if ~exist(targetIGDDir, 'dir')
        mkdir(targetIGDDir);
    end
    save(fullfile(targetIGDDir, 'prob2igdp.mat'), 'prob2igd');
    fprintf('  Saved: %s\n', targetIGDDir);
end

fprintf('\nAll done! Total time: %.1fs\n', toc(startTime));

%% Task 4: Summarize HV/IGD
fprintf('\nTask 4: Summarizing metrics...\n');
SummarizeMetrics(algorithms, problems, M);
%% Task 5: Compute Ideal/Nadir Statistics
phins = {};
for i=1:numel(problems)
    phin = {};
    phin{end+1} = func2str(problems{i});
    phin{end+1} = num2str(M);
    phins{end+1} = phin';
end
GenerateIdealNadirHistoriesMethod(algorithms, phins);


%% Task 6: Compute Stability Statistics
for ai = 1:numel(algorithms)
    algorithmName = algorithmNames{ai};
    fprintf('\n========================================\n');
    fprintf('Processing Algorithm: %s\n', algorithmName);
    fprintf('========================================\n');

    % Create output directories
    statsDir = sprintf('./Info/StableStatistics/%s', algorithmName);
    if ~exist(statsDir, 'dir'), mkdir(statsDir); end

    for pi = 1:numel(problems)
        problemHandle = problems{pi};
        problemName = func2str(problemHandle);
        fprintf('\nProcessing %s on %s...\n', algorithmName, problemName);
        processAlgorithmProblemPair(algorithmName, problemName, problemHandle, statsDir, M);
    end
end

fprintf('\n========================================\n');
fprintf('Analysis Complete!\n');
fprintf('========================================\n');

%% Task 7: Extract median HV run
extractMedianHV(algorithms,pns,M)

%% Task 8: Visualize median HV run
mkdir('./Visualization/images');
%% If you want change visualized problems, you have to change
%% extractMedianHV's pns
VisualizeMedianPopulationsMethod(algorithms) 
for i=1:numel(phs)
    ph = phs{i};
    Problem = ph();
    if Problem.M <= 3
        DrawParetoFrontMethod(Problem);
    end
end

%% Task 9: Generate Supplementary Materials

baseDir = './Info/StableStatistics';
hvSummaryPath = './Info/FinalHV/hvSummary.mat';
igdpSummaryPath = './Info/FinalIGD/igdSummary.mat';


generateSupplementaryMaterials(baseDir, hvSummaryPath, igdpSummaryPath, ...
    algorithms, problems, M, algDisplayNames);


%% Task 10: Automatically compiles LaTeX file
[status, cmdout] = system('pdflatex SupplementaryMaterials3.tex');



















function DrawParetoFrontMethod(Problem, PF)
    %% Create figure for visualization
    % fig = figure('Position', [100, 50, 1000, 800], ...
    %              'Name', 'PF Visualization', 'Visible', 'on');
    % ax = axes('Position', [0.13, 0.1, 0.8, 0.8]);

    PreprocessProductionImage(2/3, 1, 8.8);
    fig = gcf; ax = gca;
    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    axis(ax, 'square'); 
    boundDir = fullfile('./Info/Bounds'); mkdir(boundDir)


    if nargin < 2
        optimum = getOptimumPoints(Problem, Problem.M, Problem.D);
        PF = optimum;
    end
    save(sprintf('./Info/ReferencePF/%s.mat', class(Problem)), "PF");
    
    optimum = PF;

    if size(optimum,1) > 1 && Problem.M < 4
        if Problem.M == 2
            plot(ax,optimum(:,1),optimum(:,2),'.k', 'MarkerSize', 20);
        elseif Problem.M == 3
            plot3(ax,optimum(:,1),optimum(:,2),optimum(:,3),'.k', 'MarkerSize', 25);
        end
    end

    xlabel(ax, '$f_1$', 'Interpreter', 'Latex');
    ylabel(ax, '$f_2$', 'Interpreter', 'Latex');
    % title(ax, sprintf('Pareto Front of %s', class(Problem)));

    hold on
    h1 = plot(NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');
    h2 = plot(NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');

    % Create legend with these handles
    legend([h1, h2], ...
        sprintf('Problem: %s', class(Problem)), ...
        sprintf('m = %d, n = %d', Problem.M, Problem.D), ...
        'Location', 'best');
    hold off

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


    set(ax.Title, 'String', '');

    lastObjs = optimum;

    low_lims = min(lastObjs);
    high_lims = max(lastObjs);

    %% LIMLIM
    boundFile = sprintf('bound-%s.mat', class(Problem));
    boundData = fullfile(boundDir, boundFile);

    if Problem.M == 2
        XBounds = roundc([low_lims(1), high_lims(1)]);
        YBounds = roundc([low_lims(2), high_lims(2)]);
        if ~isfile(boundData)
            % save(boundData, 'XBounds', 'YBounds')
        else
            data = load(boundData, 'XBounds', 'YBounds');
            combined = [XBounds; data.XBounds];
            XBounds = [min(combined(:,1)), max(combined(:,2))];
            combined = [YBounds; data.YBounds];
            YBounds = [min(combined(:,1)), max(combined(:,2))];
            % save(boundData, 'XBounds', 'YBounds')
        end
        set(ax, 'XLim', XBounds); low_lims(1) = XBounds(1); high_lims(1) = XBounds(2);
        set(ax, 'YLim', YBounds); low_lims(2) = YBounds(1); high_lims(2) = YBounds(2);
    else 
        XBounds = roundc([low_lims(1), high_lims(1)]);
        YBounds = roundc([low_lims(2), high_lims(2)]);
        ZBounds = roundc([low_lims(3), high_lims(3)]);
        if ~isfile(boundData)
            % save(boundData, 'XBounds', 'YBounds', 'ZBounds')
        else
            data = load(boundData, 'XBounds', 'YBounds', 'ZBounds');
            combined = [XBounds; data.XBounds];
            XBounds = [min(combined(:,1)), max(combined(:,2))];
            combined = [YBounds; data.YBounds];
            YBounds = [min(combined(:,1)), max(combined(:,2))];
            combined = [ZBounds; data.ZBounds];
            ZBounds = [min(combined(:,1)), max(combined(:,2))];
            % save(boundData, 'XBounds', 'YBounds', 'ZBounds')
        end
        set(ax, 'XLim', XBounds); low_lims(1) = XBounds(1); high_lims(1) = XBounds(2);
        set(ax, 'YLim', YBounds); low_lims(2) = YBounds(1); high_lims(2) = YBounds(2);
        set(ax, 'ZLim', ZBounds); low_lims(3) = ZBounds(1); high_lims(3) = ZBounds(2);
    end

    if Problem.M == 2
        set(ax, 'XTick', XBounds);
        set(ax, 'YTick', YBounds);
    else 
        set(ax, 'XTick', XBounds);
        set(ax, 'YTick', YBounds);
        set(ax, 'ZTick', ZBounds);
    end

    shift = high_lims - low_lims;
    if Problem.M==2
        set(ax, 'Position', [0.32 0.35 0.36 0.57])
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1])
        set(ax, 'XTickLabelRotation', 0);
        set(ax, 'YTickLabelRotation', 0);
        set(ax.XLabel, 'Rotation', 0, 'Position', ...
            [low_lims(1) + 1/2 * shift(1), low_lims(2) - 0.05 * shift(2)]);
        set(ax.YLabel, 'Rotation', 0, 'Position', ...
            [low_lims(1) - 0.1 * shift(1), low_lims(2) + 0.4 * shift(2)]);
    else
        set(ax, 'Position', [0.2 0.35 0.6 0.6])
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1])
        set(ax, 'XTickLabelRotation', 0);
        set(ax, 'YTickLabelRotation', 0);
        set(ax.XLabel, 'Rotation', 0, 'Position', ...
            [low_lims(1) + 1/2 * shift(1), ...
            low_lims(2) + 1.1 * shift(2), ...
            low_lims(3)])
        set(ax.YLabel, 'Rotation', 0, 'Position', ...
            [low_lims(1) + 1.1 * shift(1), ...
            low_lims(2) + 1/2 * shift(2), ...
            low_lims(3)])
        set(ax, 'ZTickLabelRotation', 0);
        set(ax.ZLabel, 'Rotation', 0, 'Position', ...
            [low_lims(1) + 0.62 * shift(1), ...
            low_lims(2) - 0.62 * shift(2), ...
            low_lims(3)])
        FormatMatrix('%.8g\n' ,[low_lims(1) + 0.62 * shift(1), ...
            low_lims(2) - 0.62 * shift(2), ...
            low_lims(3)])
    end

    filename = sprintf("./Visualization/images/PF-%s-M%d-D%d.png", ...
        class(Problem), Problem.M, Problem.D);
    exportgraphics(gcf, filename, 'Resolution', 300);
    close(fig);

end

















function VisualizeMedianPopulationsMethod(algorithmHandles)
    % Configuration
    config = struct(...
        'rootDirHV',   './Info/MedianHVResults', ...
        'rootDirData', './Data', ...
        'boundDir',    './Info/Bounds', ...
        'outputDir',   './Visualization/images');
    
    ensureDirExists(config.boundDir);
    ensureDirExists(config.outputDir);
    
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

%% ==================== DATA LOADING ====================

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
        algName = func2str(algorithmHandles{ah});
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

%% ==================== BOUNDS ====================

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

function optimum = getOptimumPoints(Problem, M, D)
    pn = class(Problem);
    
    % Load config
    config = loadOptimumConfig();
    
    % Get num_opt: use override if exists, otherwise default
    if isfield(config.overrides, pn)
        num_opt = config.overrides.(pn);
    else
        num_opt = config.default_num_opt;
    end
    
    target = config.target_points;
    
    % Get optimum points
    disp(num_opt)
    optimum = Problem.GetOptimum(num_opt);
    disp(size(optimum))
    optimum = optimum(NDSort(optimum, 1) == 1, :);
    % idx = getLeastCrowdedPoints(optimum, target);
    % optimum = optimum(idx, :);
    disp(size(optimum))
end

function config = loadOptimumConfig()
    persistent cachedConfig;
    
    if isempty(cachedConfig)
        configPath = './Info/Misc/optimum_config.json';
        
        if exist(configPath, 'file')
            jsonText = fileread(configPath);
            cachedConfig = jsondecode(jsonText);
        else
            % Fallback defaults if file doesn't exist
            warning('Config file not found: %s. Using defaults.', configPath);
            cachedConfig = struct(...
                'default_num_opt', 120, ...
                'target_points', 120, ...
                'overrides', struct());
        end
    end
    
    config = cachedConfig;
end

function algDisplayNames = loadAlgDisplayNames()
    persistent cachedNames;
    
    if isempty(cachedNames)
        configPath = './Info/Misc/algorithm_display_names.json';
        
        if exist(configPath, 'file')
            jsonText = fileread(configPath);
            nameStruct = jsondecode(jsonText);
            
            % Convert struct to containers.Map
            fields = fieldnames(nameStruct);
            cachedNames = containers.Map();
            for i = 1:numel(fields)
                cachedNames(fields{i}) = nameStruct.(fields{i});
            end
        else
            warning('Config file not found: %s. Using empty map.', configPath);
            cachedNames = containers.Map();
        end
    end
    
    algDisplayNames = cachedNames;
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

%% ==================== VISUALIZATION ====================

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


function extractMedianHV(algorithmHandles,problemNames,M)
% extractMedianHV - Computes median HV across runs for each problem.
%
% INPUT:
%   algorithmHandles : cell array of function handles, e.g. {@NSGAII, @PyNSGAII}
%
% OUTPUT:
%   Writes result files under ./Info/MedianHVResults/
%
% The function loads HV values from ./Info/FinalHV/{algorithmName}/prob2hv.mat
% which contains a prob2hv_map (containers.Map) mapping problem names to 
% a vector of hypervolume values across runs.

    rootDir = fullfile('./Info/FinalHV');
    outDir  = fullfile('./Info/MedianHVResults');
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    for ah = 1:numel(algorithmHandles)

        algName = func2str(algorithmHandles{ah});
        
        % Load prob2hv.mat for this algorithm
        prob2hvPath = fullfile(rootDir, algName, 'prob2hv.mat');
        
        if ~exist(prob2hvPath, 'file')
            warning('File "%s" does not exist. Skipped.', prob2hvPath);
            continue;
        end
        
        % Load the containers.Map
        data = load(prob2hvPath);
        prob2hv_map = data.prob2hv_map;

        
        % Storage for results
        results = struct();

        % ---------------------------------------------------------
        % Process each problem
        % ---------------------------------------------------------
        for p = 1:numel(problemNames)
            prob = problemNames{p};
            fprintf("Processing %s - %s (%d/%d)\n", algName, prob, p, numel(problemNames));

            % Get HV values for this problem (vector across runs)
            hvValues = prob2hv_map(prob);
            numRuns = numel(hvValues);

            % ----------------------------------------------
            % Compute median HV & find index
            % ----------------------------------------------
            medHV = median(hvValues);

            % Find the index of the run closest to the median
            [~, medianIdx] = min(abs(hvValues - medHV));

            ph = str2func(prob);
            Problem = ph('M', M);
            medFile = sprintf('%s_%s_M%d_D%d_%d.mat', algName, prob, ...
                Problem.M, Problem.D, medianIdx);

            % Store results
            results.(matlab.lang.makeValidName(prob)).medianHV = medHV;
            results.(matlab.lang.makeValidName(prob)).medianIdx = medianIdx;
            results.(matlab.lang.makeValidName(prob)).allHV = hvValues;
            results.(matlab.lang.makeValidName(prob)).numRuns = numRuns;
            results.(matlab.lang.makeValidName(prob)).medianFile = medFile;
        end

        % ---------------------------------------------------------
        % Save output as .mat
        % ---------------------------------------------------------
        outPath = fullfile(outDir, sprintf('MedianHV_%s.mat', algName));
        save(outPath, 'results');
        fprintf('Saved: %s\n', outPath);
        fprintf('Finished %s\n\n', algName);
    end
end

function generateSupplementaryMaterials(baseDir, hvSummaryPath, igdpSummaryPath, algorithms, problems, M, algDisplayNames)
% generateSupplementaryMaterials - Generate ACM-format supplementary materials
%
% Usage: 
%   algorithms = {@MeNSGAIIIwH, @OrmeNSGAIIIwH};
%   problems = {@BT9, @DTLZ4, @DTLZ5, ...};
%   M = 3;
%   algDisplayNames = containers.Map();
%   algDisplayNames('MeNSGAIIIwH') = 'Me-NSGA-III';
%   algDisplayNames('OrmeNSGAIIIwH') = 'Orme-NSGA-III';
%   
%   generateSupplementaryMaterials('./Info/StableStatistics', ...
%       './Info/FinalHV/hvSummary.mat', './Info/FinalIGD/igdSummary.mat', ...
%       algorithms, problems, M, algDisplayNames);
%
% Generates a complete LaTeX document with stability tables split across
% multiple pages (max 30 problems per table).

%% Validate inputs
if nargin < 7
    error('Usage: generateSupplementaryMaterials(baseDir, hvSummaryPath, igdpSummaryPath, algorithms, problems, M, algDisplayNames)');
end

%% Load HV and IGD+ summaries
hvData = load(hvSummaryPath, 'hvSummary');
hvSummary = hvData.hvSummary;
igdpData = load(igdpSummaryPath, 'igdSummary');
igdpSummary = igdpData.igdSummary;

%% Extract problem names from function handles
problemNames = cell(1, numel(problems));
for i = 1:numel(problems)
    problemNames{i} = func2str(problems{i});
end

%% Extract algorithm names from function handles
algorithmNames = cell(1, numel(algorithms));
for i = 1:numel(algorithms)
    algorithmNames{i} = func2str(algorithms{i});
end

%% Create problems array based on M (number of objectives)
% All problems go into problemsMD where M is the number of objectives
if M == 2
    problems2D = problemNames;
    problems3D = {};
elseif M == 3
    problems2D = {};
    problems3D = problemNames;
else
    % For M > 3, treat as many-objective (put in 3D section with appropriate label)
    problems2D = {};
    problems3D = problemNames;
end

%% Create verdicts map with all "XXX"
verdicts = containers.Map();
for i = 1:numel(problemNames)
    verdicts(problemNames{i}) = 'XXX';
end

%% Problem display name mappings (for Minus problems)
probDisplayNames = containers.Map();
probDisplayNames('MinusDTLZ1') = '$-$DTLZ1';
probDisplayNames('MinusDTLZ2') = '$-$DTLZ2';
probDisplayNames('MinusDTLZ3') = '$-$DTLZ3';
probDisplayNames('MinusDTLZ4') = '$-$DTLZ4';
probDisplayNames('MinusDTLZ5') = '$-$DTLZ5';
probDisplayNames('MinusDTLZ6') = '$-$DTLZ6';
probDisplayNames('MinusWFG1') = '$-$WFG1';
probDisplayNames('MinusWFG2') = '$-$WFG2';
probDisplayNames('MinusWFG3') = '$-$WFG3';
probDisplayNames('MinusWFG4') = '$-$WFG4';
probDisplayNames('MinusWFG5') = '$-$WFG5';
probDisplayNames('MinusWFG6') = '$-$WFG6';
probDisplayNames('MinusWFG7') = '$-$WFG7';
probDisplayNames('MinusWFG8') = '$-$WFG8';
probDisplayNames('MinusWFG9') = '$-$WFG9';

%% Parse all mat files
allData = parseAllMatFiles(baseDir, algorithmNames);

if isempty(allData)
    error('No data found in %s', baseDir);
end

%% Generate the supplementary materials LaTeX document
generateSupplementaryLaTeX(allData, problems2D, problems3D, M, ...
    verdicts, algDisplayNames, probDisplayNames, hvSummary, igdpSummary, algorithmNames);

fprintf('Supplementary materials generated successfully!\n');
end

%% ========================================================================
%  PARSING FUNCTIONS
%  ========================================================================

function allData = parseAllMatFiles(baseDir, algorithmNames)
% Parse all SS-*.mat files from algorithm subdirectories

allData = struct('problem', {}, 'algorithm', {}, 'type', {}, ...
                 'stable_runs', {}, 'total_runs', {}, ...
                 'cluster_radius_med', {}, 'bias_L2', {}, 'avg_stable_gen', {});

% Use provided algorithm names instead of scanning directories
for i = 1:length(algorithmNames)
    algName = algorithmNames{i};
    algPath = fullfile(baseDir, algName);
    
    if ~exist(algPath, 'dir')
        warning('Algorithm directory not found: %s', algPath);
        continue;
    end
    
    matFiles = dir(fullfile(algPath, 'SS-*.mat'));
    
    for j = 1:length(matFiles)
        fname = matFiles(j).name;
        % Parse filename: SS-{Type}-{Alg}-{Prob}.mat
        tokens = regexp(fname, 'SS-(\w+)-(\w+)-(\w+)\.mat', 'tokens');
        if isempty(tokens)
            warning('Could not parse filename: %s', fname);
            continue;
        end
        
        pointType = tokens{1}{1};  % Ideal or Nadir
        probName = tokens{1}{3};
        
        % Load data
        data = load(fullfile(algPath, fname));
        
        % Store entry
        entry.problem = probName;
        entry.algorithm = algName;
        entry.type = pointType;
        entry.stable_runs = data.stable_runs;
        entry.total_runs = data.total_runs;
        entry.cluster_radius_med = data.cluster_radius_med;
        entry.bias_L2 = data.bias_L2;
        entry.avg_stable_gen = data.avg_stable_gen;
        
        allData(end+1) = entry;
    end
end
end

%% ========================================================================
%  LATEX GENERATION
%  ========================================================================

function generateSupplementaryLaTeX(allData, problems2D, problems3D, M, ...
    verdicts, algDisplayNames, probDisplayNames, hvSummary, igdpSummary, algorithmNames)

filename = './SupplementaryMaterials3.tex';
fid = fopen(filename, 'w');

% Write document preamble
writeDocumentPreamble(fid);

% Sort all problems
sorted2D = problems2D(getNaturalOrder(problems2D));
sorted3D = problems3D(getNaturalOrder(problems3D));

% Combine all problems with dimension labels
allProblems = {};
problemDims = {};
for i = 1:length(sorted2D)
    allProblems{end+1} = sorted2D{i};
    problemDims{end+1} = '2D';
end
for i = 1:length(sorted3D)
    allProblems{end+1} = sorted3D{i};
    problemDims{end+1} = '3D';
end

% Split into chunks of max 30 problems
maxProblemsPerTable = 6;
numProblems = length(allProblems);
numTables = ceil(numProblems / maxProblemsPerTable);

tableNum = 1;
probIdx = 1;

while probIdx <= numProblems
    % Determine problems for this table
    endIdx = min(probIdx + maxProblemsPerTable - 1, numProblems);
    tableProblems = allProblems(probIdx:endIdx);
    tableDims = problemDims(probIdx:endIdx);
    
    % Determine table title based on M
    if M == 2
        objLabel = '2-Objective';
    elseif M == 3
        objLabel = '3-Objective';
    else
        objLabel = sprintf('%d-Objective', M);
    end
    
    if tableNum == 1
        tableTitle = sprintf('%s Problems', objLabel);
    else
        tableTitle = sprintf('%s Problems (continued)', objLabel);
    end
    
    % Write page break before new table (except first)
    if tableNum > 1
        fprintf(fid, '\\clearpage\n\n');
    end
    
    % Write table
    writeTable(fid, allData, tableProblems, tableDims, tableNum, numTables, ...
        tableTitle, verdicts, algDisplayNames, probDisplayNames, ...
        probIdx, sorted2D, hvSummary, igdpSummary, algorithmNames, M);
    
    probIdx = endIdx + 1;
    tableNum = tableNum + 1;
end

%% Insert contents here:
% 1. Define the command to run Python inside the 'Research' environment
% 'conda run -n EnvName' executes the command in that isolated environment
pyScript = './Visualization/batch_insert.py';
pyOutput = 'figures.tex'; % Ensure your Python script saves to this name
cmd = sprintf('conda run -n Research python "%s"', pyScript);

% 2. Execute the Python script
% -echo ensures you see any Python print statements in the MATLAB Command Window
[status, cmdout] = system(cmd, '-echo');

if status ~= 0
    error('Python execution failed. Check if Conda is in PATH and environment exists.');
end

% 3. Read the generated .tex file and append it to your current FID
if exist(pyOutput, 'file')
    % Read the entire file into a character array
    texContent = fileread(pyOutput);
    
    % Append it to your open file identifier (fid)
    % CRITICAL: Use '%s' specifier so fprintf doesn't interpret LaTeX '%' or '\' as code
    fprintf(fid, '\n%% --- Content generated by Python ---\n');
    fprintf(fid, '%s', texContent);
    fprintf(fid, '\n%% -----------------------------------\n');
else
    warning('Python script ran, but the expected output file "%s" was not found.', pyOutput);
end


% Write document end
fprintf(fid, '\\end{document}\n');

fclose(fid);
fprintf('Generated: %s\n', filename);
end

function writeDocumentPreamble(fid)
% Write the LaTeX document preamble

fprintf(fid, '\\documentclass[sigconf,nonacm]{acmart}\n\n');
fprintf(fid, '%% Remove ACM reference format and other unnecessary elements for supplementary\n');
fprintf(fid, '\\settopmatter{printacmref=false}\n');
fprintf(fid, '\\renewcommand\\footnotetextcopyrightpermission[1]{}\n');
fprintf(fid, '\\pagestyle{plain}\n\n');
fprintf(fid, '\\usepackage{booktabs}\n');
fprintf(fid, '\\usepackage{multirow}\n');
fprintf(fid, '\\usepackage{graphicx}\n');
fprintf(fid, '\\usepackage{float}\n\n');
fprintf(fid, '\\begin{document}\n\n');

% Title
fprintf(fid, '%%%% Title\n');
fprintf(fid, '\\title{Supplementary Materials for: \\\\ A Comparative Study on Reference Point Estimation Stability in NSGA-III Implementations}\n\n');

% Authors (placeholders)
fprintf(fid, '%%%% Authors (placeholders)\n');
fprintf(fid, '\\author{First Author}\n');
fprintf(fid, '\\affiliation{%%\n');
fprintf(fid, '  \\institution{Institution Name}\n');
fprintf(fid, '  \\city{City}\n');
fprintf(fid, '  \\country{Country}\n');
fprintf(fid, '}\n');
fprintf(fid, '\\email{first.author@email.com}\n\n');

fprintf(fid, '\\author{Second Author}\n');
fprintf(fid, '\\affiliation{%%\n');
fprintf(fid, '  \\institution{Institution Name}\n');
fprintf(fid, '  \\city{City}\n');
fprintf(fid, '  \\country{Country}\n');
fprintf(fid, '}\n');
fprintf(fid, '\\email{second.author@email.com}\n\n');

fprintf(fid, '\\author{Third Author}\n');
fprintf(fid, '\\affiliation{%%\n');
fprintf(fid, '  \\institution{Institution Name}\n');
fprintf(fid, '  \\city{City}\n');
fprintf(fid, '  \\country{Country}\n');
fprintf(fid, '}\n');
fprintf(fid, '\\email{third.author@email.com}\n\n');

fprintf(fid, '\\maketitle\n\n');

% Overview section
fprintf(fid, '\\section*{Overview}\n');
fprintf(fid, 'This supplementary material provides the complete stability analysis results for all benchmark problems examined in our study.\n\n');
fprintf(fid, '\\textbf{Legend:}\n');
fprintf(fid, '\\begin{itemize}\n');
fprintf(fid, '    \\item \\textbf{Symbols}: $\\bigcirc$ consistent/unbiased, \\scalebox{1.35}{$\\triangle$} semi-consistent/marginally biased, \\scalebox{1.2}{$\\times$} inconsistent/biased\n');
fprintf(fid, '    \\item \\textbf{--} (en-dash): No stable runs were observed\n');
fprintf(fid, '    \\item \\textbf{Verdict}: ``Both'''' = both implementations are okay, ``Neither'''' = neither performs well, otherwise the more stable implementation is listed\n');
fprintf(fid, '\\end{itemize}\n\n');
fprintf(fid, '\\clearpage\n\n');
end

function writeTable(fid, allData, problems, dims, tableNum, totalTables, ...
    tableTitle, verdicts, algDisplayNames, probDisplayNames, startIdx, sorted2D, hvSummary, igdpSummary, algorithmNames, M)
% Write a single table

numAlgorithms = length(algorithmNames);

% Calculate total number of columns: Problem + Algorithm + IGD+ + HV + 4*Ideal + 4*Nadir + Verdict = 13
totalCols = 13;

% Table header
fprintf(fid, '\\begin{table*}[htbp]\n');
fprintf(fid, '\\centering\n');
fprintf(fid, '\\caption{Stability Analysis of Ideal and Nadir Point Estimation (Part %d of %d)}\n', tableNum, totalTables);
fprintf(fid, '\\label{tab:stability_part%d}\n', tableNum);
fprintf(fid, '\\scriptsize\n');
fprintf(fid, '\\setlength{\\tabcolsep}{5pt}\n');
fprintf(fid, '\\begin{tabular}{ll cc cccc cccc c}\n');
fprintf(fid, '\\toprule\n');

% Column headers (13 columns total)
fprintf(fid, ' & & & & \\multicolumn{4}{c}{\\textbf{Ideal Point}} & \\multicolumn{4}{c}{\\textbf{Nadir Point}} & \\\\\n');
fprintf(fid, '\\cmidrule(lr){5-8} \\cmidrule(lr){9-12}\n');
fprintf(fid, '\\textbf{Problem} & \\textbf{Algorithm} & \\textbf{Final IGD$^+$ $(\\downarrow)$} & \\textbf{Final HV $(\\uparrow)$} & ');
fprintf(fid, '\\textbf{\\%%Stable} & \\textbf{Average} & \\textbf{Spatial} & \\textbf{Bias} & ');
fprintf(fid, '\\textbf{\\%%Stable} & \\textbf{Average} & \\textbf{Spatial} & \\textbf{Bias} & \\textbf{Verdict} \\\\\n');
fprintf(fid, ' & & & & ');
fprintf(fid, ' & \\textbf{Stable Gen.} & \\textbf{Consistency} & & ');
fprintf(fid, ' & \\textbf{Stable Gen.} & \\textbf{Consistency} & & \\\\\n');
fprintf(fid, '\\midrule\n');

% Track current dimension for section headers
currentDim = '';
num2D = length(sorted2D);

% Determine objective label based on M
if M == 2
    objLabel = '2-Objective';
elseif M == 3
    objLabel = '3-Objective';
else
    objLabel = sprintf('%d-Objective', M);
end

for p = 1:length(problems)
    prob = problems{p};
    dim = dims{p};
    isLastInTable = (p == length(problems));
    
    % Check if we need a section header
    if ~strcmp(dim, currentDim)
        if strcmp(dim, '2D')
            fprintf(fid, '\\multicolumn{%d}{l}{\\textbf{2-Objective Problems}} \\\\\n', totalCols);
            fprintf(fid, '\\midrule\n');
        else
            if ~isempty(currentDim)
                fprintf(fid, '\\midrule\n');
            end
            fprintf(fid, '\\multicolumn{%d}{l}{\\textbf{%s Problems}} \\\\\n', totalCols, objLabel);
            fprintf(fid, '\\midrule\n');
        end
        currentDim = dim;
    end
    
    % Write problem rows
    writeProblemRows(fid, allData, prob, verdicts, algDisplayNames, probDisplayNames, isLastInTable, hvSummary, igdpSummary, algorithmNames, totalCols);
end

% Table footer
fprintf(fid, '\\bottomrule\n');
fprintf(fid, '\\end{tabular}\n');
fprintf(fid, '\\vspace{2mm}\n');
fprintf(fid, '\\\\\\footnotesize \\textbf{Symbols}: $\\bigcirc$ consistent/unbiased, \\scalebox{1.35}{$\\triangle$} semi-consistent/marginally biased, \\scalebox{1.2}{$\\times$} inconsistent/biased.\n');
fprintf(fid, '\\end{table*}\n\n');
end

function writeProblemRows(fid, allData, prob, verdicts, algDisplayNames, probDisplayNames, isLastInSection, hvSummary, igdpSummary, algorithmNames, totalCols)
% Write rows for a single problem

% Use provided algorithm names
algNames = algorithmNames;
numAlgs = length(algNames);

% Get data for all algorithms
algData = struct();
for a = 1:numAlgs
    alg = algNames{a};
    
    idxIdeal = find(strcmp({allData.problem}, prob) & ...
                    strcmp({allData.algorithm}, alg) & ...
                    strcmp({allData.type}, 'Ideal'));
    
    idxNadir = find(strcmp({allData.problem}, prob) & ...
                    strcmp({allData.algorithm}, alg) & ...
                    strcmp({allData.type}, 'Nadir'));
    
    algData(a).name = alg;
    algData(a).ideal = [];
    algData(a).nadir = [];
    
    if ~isempty(idxIdeal)
        algData(a).ideal = allData(idxIdeal);
    end
    if ~isempty(idxNadir)
        algData(a).nadir = allData(idxNadir);
    end
end

% Filter out algorithms with no data for this problem
validAlgs = [];
for a = 1:numAlgs
    if ~isempty(algData(a).ideal) || ~isempty(algData(a).nadir)
        validAlgs(end+1) = a;
    end
end

if isempty(validAlgs)
    % No data for this problem, write placeholder row
    if isKey(probDisplayNames, prob)
        probDisplay = probDisplayNames(prob);
    else
        probDisplay = prob;
    end
    fprintf(fid, '%s & -- & -- & -- & -- & -- & -- & -- & -- & -- & -- & -- & XXX \\\\\n', probDisplay);
    if ~isLastInSection
        fprintf(fid, '\\cmidrule{1-%d}\n', totalCols);
    end
    return;
end

numValidAlgs = length(validAlgs);

% Get verdict (always "XXX" now)
if isKey(verdicts, prob)
    verdictText = verdicts(prob);
else
    verdictText = 'XXX';
end

% Get display name
if isKey(probDisplayNames, prob)
    probDisplay = probDisplayNames(prob);
else
    probDisplay = prob;
end

probField = matlab.lang.makeValidName(prob);

% Write rows
for i = 1:numValidAlgs
    a = validAlgs(i);
    alg = algData(a).name;
    
    if isKey(algDisplayNames, alg)
        algDisplay = algDisplayNames(alg);
    else
        algDisplay = alg;
    end

    % Get Final IGD+ and HV for this algorithm
    finalIGDp = getIGDpString(igdpSummary, probField, alg);
    finalHV = getHVString(hvSummary, probField, alg);
    
    % Format Ideal columns
    if ~isempty(algData(a).ideal)
        idealCols = formatDataColumns(algData(a).ideal);
    else
        idealCols = {'--', '--', '--', '--'};
    end
    
    % Format Nadir columns
    if ~isempty(algData(a).nadir)
        nadirCols = formatDataColumns(algData(a).nadir);
    else
        nadirCols = {'--', '--', '--', '--'};
    end
    
    % Write row (13 columns)
    if i == 1
        fprintf(fid, '\\multirow{%d}{*}{%s} & %s & %s & %s & %s & %s & %s & %s & %s & %s & %s & %s & \\multirow{%d}{*}{%s} \\\\\n', ...
            numValidAlgs, probDisplay, algDisplay, finalIGDp, finalHV, ...
            idealCols{1}, idealCols{2}, idealCols{3}, idealCols{4}, ...
            nadirCols{1}, nadirCols{2}, nadirCols{3}, nadirCols{4}, ...
            numValidAlgs, verdictText);
    else
        fprintf(fid, ' & %s & %s & %s & %s & %s & %s & %s & %s & %s & %s & %s & \\\\\n', ...
            algDisplay, finalIGDp, finalHV, ...
            idealCols{1}, idealCols{2}, idealCols{3}, idealCols{4}, ...
            nadirCols{1}, nadirCols{2}, nadirCols{3}, nadirCols{4});
    end
end

% Add horizontal rule after problem (unless it's the last in the section)
if ~isLastInSection
    fprintf(fid, '\\cmidrule{1-%d}\n', totalCols);
end
end

function cols = formatDataColumns(d)
% Format the 4 data columns: %Stable, Avg Gen, Spatial, Bias

pctStable = 100 * d.stable_runs / d.total_runs;
col1 = sprintf('%.0f\\%%', pctStable);

if d.stable_runs == 0
    col2 = '--';
    col3 = '--';
    col4 = '--';
else
    col2 = sprintf('%d', round(d.avg_stable_gen));
    
    [spatialSym, ~] = classifySpatialStability(d.cluster_radius_med);
    spatialNum = formatScientific(d.cluster_radius_med);
    col3 = sprintf('%s %s', spatialSym, spatialNum);
    
    [biasSym, ~] = classifyBias(d.bias_L2);
    biasNum = formatScientific(d.bias_L2);
    col4 = sprintf('%s %s', biasSym, biasNum);
end

cols = {col1, col2, col3, col4};
end

%% ========================================================================
%  CLASSIFICATION FUNCTIONS
%  ========================================================================

function [symbol, text] = classifySpatialStability(rho_med)
if rho_med < 0.01
    symbol = '$\bigcirc$';
    text = 'stable';
elseif rho_med < 0.1
    symbol = '\scalebox{1.35}{$\triangle$}';
    text = 'semi-stable';
else
    symbol = '\scalebox{1.2}{$\times$}';
    text = 'unstable';
end
end

function [symbol, text] = classifyBias(bias)
if bias < 0.01
    symbol = '$\bigcirc$';
    text = 'unbiased';
elseif bias < 0.1
    symbol = '\scalebox{1.35}{$\triangle$}';
    text = 'marginally biased';
else
    symbol = '\scalebox{1.2}{$\times$}';
    text = 'biased';
end
end

function str = formatScientific(val)
if val == 0
    str = '0.0e+00';
    return;
end

exponent = floor(log10(abs(val)));
mantissa = val / (10^exponent);

if exponent >= 0
    str = sprintf('%.1fe+%02d', mantissa, exponent);
else
    str = sprintf('%.1fe%03d', mantissa, exponent);
end
end

%% ========================================================================
%  METRIC STRING FUNCTIONS
%  ========================================================================

function hvStr = getHVString(hvSummary, probField, alg)
% Get the HV string (mean ± std) for a problem-algorithm pair

hvStr = 'N/A';

if isempty(fieldnames(hvSummary))
    return;
end

if isfield(hvSummary, probField)
    probData = hvSummary.(probField);
    if isfield(probData, alg)
        hvStr = probData.(alg);
        % Convert ± to LaTeX $\pm$
        hvStr = strrep(hvStr, '±', '$\pm$');
    end
end
end

function igdpStr = getIGDpString(igdpSummary, probField, alg)
% Get the IGD+ string (mean ± std) for a problem-algorithm pair
% Formats values in scientific notation for consistent string lengths

igdpStr = 'N/A';

if isempty(fieldnames(igdpSummary))
    return;
end

if isfield(igdpSummary, probField)
    probData = igdpSummary.(probField);
    if isfield(probData, alg)
        rawStr = probData.(alg);
        
        % Try to parse "mean ± std" or "mean ± std" format
        % Handle both ± and ± characters
        if contains(rawStr, '±')
            parts = strsplit(rawStr, '±');
        elseif contains(rawStr, char(177))  % ± character
            parts = strsplit(rawStr, char(177));
        else
            % Can't parse, return with LaTeX formatting attempt
            igdpStr = strrep(rawStr, '±', '$\\pm$');
            return;
        end
        
        if length(parts) == 2
            meanVal = str2double(strtrim(parts{1}));
            stdVal = str2double(strtrim(parts{2}));
            
            if ~isnan(meanVal) && ~isnan(stdVal)
                % Format both in scientific notation for consistent length
                meanStr = formatScientificIGDp(meanVal);
                stdStr = formatScientificIGDp(stdVal);
                igdpStr = sprintf('%s $\\pm$ %s', meanStr, stdStr);
            else
                % Parsing failed, return original with LaTeX ±
                igdpStr = strrep(rawStr, '±', '$\\pm$');
            end
        else
            igdpStr = strrep(rawStr, '±', '$\\pm$');
        end
    end
end
end

function str = formatScientificIGDp(val)
% Format IGD+ value in scientific notation with consistent length
% Output format: X.XXe±YY (e.g., 1.23e-02, 4.56e+01)

if val == 0
    str = '0.00e+00';
    return;
end

exponent = floor(log10(abs(val)));
mantissa = val / (10^exponent);

% Use 2 decimal places for mantissa for consistent length
if exponent >= 0
    str = sprintf('%.2fe+%02d', mantissa, exponent);
else
    str = sprintf('%.2fe%03d', mantissa, exponent);  % e-01, e-02, etc.
end
end

%% ========================================================================
%  UTILITY FUNCTIONS
%  ========================================================================

function sortedIndices = getNaturalOrder(strList)
if isempty(strList)
    sortedIndices = [];
    return;
end

tokens = regexp(strList, '^(.*?)(-?\d+)$', 'tokens', 'once');

hasMatch = ~cellfun(@isempty, tokens);
if ~all(hasMatch)
    for i = find(~hasMatch)
        tokens{i} = {strList{i}, '0'};
    end
end

extracted = vertcat(tokens{:});
prefixes = extracted(:, 1);
numbers = str2double(extracted(:, 2));

[~, sortedIndices] = sortrows(table(prefixes, numbers));
sortedIndices = sortedIndices(:)';
end



%% ============ Helper Functions ============
function processAlgorithmProblemPair(algorithmName, problemName, problemHandle, statsDir, M)
    % Load data
    dataDir = sprintf('./Info/IdealNadirHistory/%s', algorithmName);
    fileName = sprintf('IN-%s-%s.mat', algorithmName, problemName);
    filePath = fullfile(dataDir, fileName);
    
    if ~exist(filePath, 'file')
        fprintf('  Warning: File not found: %s\n', filePath);
        return;
    end
    
    fileData = load(filePath);
    idealHistories = fileData.ideal_history;
    nadirHistories = fileData.nadir_history;
    
    % Get ground truth
    Problem = problemHandle('M', M);
    PF = Problem.GetOptimum(1000);
    gt_ideal = min(PF);
    gt_nadir = max(PF);

    M = Problem.M;  % Number of objectives
    
    % Normalize histories
    norm_idealHistories = cellfun(@(c) (c-gt_ideal+eps)./(gt_nadir-gt_ideal+eps), ...
        idealHistories, 'UniformOutput', false);
    norm_nadirHistories = cellfun(@(c) (c-gt_ideal+eps)./(gt_nadir-gt_ideal+eps), ...
        nadirHistories, 'UniformOutput', false);
    
    % Detect stability and compute statistics
    ideal_stats = computeStabilityStatistics(norm_idealHistories, 'ideal', M);
    nadir_stats = computeStabilityStatistics(norm_nadirHistories, 'nadir', M);

    % Save statistics
    saveStatistics(ideal_stats, statsDir, algorithmName, problemName, 'Ideal');
    saveStatistics(nadir_stats, statsDir, algorithmName, problemName, 'Nadir');

    % Print summary
    printSummary(ideal_stats, nadir_stats, algorithmName, problemName);
end

function GenerateIdealNadirHistoriesMethod(Algorithms, Problems)
    targetDir = fullfile('./Info/IdealNadirHistory'); mkdir(targetDir);
    sourceDirData = fullfile('./Data');

    if nargin < 2 || isempty(Problems)
        Problems = preprocessProblemHandles(Algorithms, sourceDirData);
    end


    AllPairs = {};
    for ph = 1:numel(Problems)
        for ah = 1:numel(Algorithms)
            AllPairs{end+1} = struct('AlgHandle', Algorithms{ah}, ...
                                     'ProbHandle', Problems(ph));
        end
    end
    
    fprintf('Starting parallel processing of %d tasks...\n', numel(AllPairs));
    
    % Use parfor to distribute the work of processing each file pair
    parfor i = 1:numel(AllPairs)
        currentPair = AllPairs{i};
        algHandle = currentPair.AlgHandle;
        problemHandle = currentPair.ProbHandle;

        algName = func2str(algHandle);
        
        % 1. Find the specific data file for this Alg/Problem combination
        dataFilePath = fullfile(sourceDirData, algName, [algName, '_', problemHandle{1}, '_', '*.mat']);
        dataFiles = dir(dataFilePath);
        
        % Processing logic moved to a helper function
        processStabilityData(dataFiles, algName, problemHandle, targetDir);
    end
    
    disp('Parallel processing complete.');
end

function processStabilityData(dataFiles, algName, problemHandle, targetDir)
    ideal_history = cell(1,numel(dataFiles));
    nadir_history = cell(1,numel(dataFiles));

    ph = str2func(problemHandle{1});
    Problem = ph('M', str2num(problemHandle{2})); M = Problem.M; D = Problem.D; proName = class(Problem);
    PF = Problem.GetOptimum(1000); 
    true_ideal_point = min(PF, [], 1);
    true_nadir_point = max(PF, [], 1);

    for fi=1:numel(dataFiles)
        disp(fi);

        dataPath = fullfile(dataFiles(fi).folder, dataFiles(fi).name);
        % --- 1. Load Data ---
        data = load(dataPath);
        resultMatrix = data.result;
        n_gens = size(resultMatrix, 1);
        N = numel(resultMatrix{1, 2});

        NormStruct = alg2norm(algName, N, M);

        SS = initializeStabilityStruct(M, n_gens);
        
        Population = resultMatrix{1, 2};
        nds = nds_preprocess(Population);
        norm_update(algName, Problem, NormStruct, Population, nds);
        SS.ideal_point_history(1, :) = NormStruct.ideal_point;
        SS.nadir_point_history(1, :) = NormStruct.nadir_point;
        SS.FE_history(1) = resultMatrix{1, 1};

        for g = 2:n_gens
            Population = resultMatrix{g-1, 2};
            Offspring = resultMatrix{g, 3};
            Mixture = [Population, Offspring];
            nds = nds_preprocess(Mixture);
            norm_update(algName, Problem, NormStruct, Mixture, nds);
            
            SS.ideal_point_history(g, :) = NormStruct.ideal_point;
            SS.nadir_point_history(g, :) = NormStruct.nadir_point;
            SS.FE_history(g) = resultMatrix{g, 1};
        end
        ideal_history{fi} = SS.ideal_point_history;
        nadir_history{fi} = SS.nadir_point_history;
    end
    
    targetAlgDir = fullfile(targetDir, algName);
    mkdir(targetAlgDir); 

    % [~, rawName] = fileparts(dataPath);
    outputFileName = ['IN-', algName, '-',proName, '.mat'];
    outputFilePath = fullfile(targetAlgDir, outputFileName);

    % Save the final stability struct
    save(outputFilePath, 'ideal_history', 'nadir_history');
end


function SS = initializeStabilityStruct(M, n_gens)
    SS = struct();
    
    % History tracking (for computing relative stability)
    SS.ideal_point_history = nan(n_gens, M);
    SS.nadir_point_history = nan(n_gens, M);
    SS.FE_history = nan(n_gens,1);
    
    % Final metrics (will store the FE value)
    SS.abs_stability_ideal_gen = NaN; % FE of first gen that stabilized, or NaN
    SS.abs_stability_nadir_gen = NaN;
    SS.rel_stability_ideal_gen = NaN; % FE of last gen that began a stable window, or NaN
    SS.rel_stability_nadir_gen = NaN;
end

function printSummary(ideal_stats, nadir_stats, algorithmName, problemName)
    fprintf('\n  === %s on %s ===\n', algorithmName, problemName);
    
    fprintf('  Ideal Point:\n');
    if ideal_stats.stable_runs > 0
        fprintf('    Stable: %d/%d (%.1f%%)\n', ideal_stats.stable_runs, ...
            ideal_stats.total_runs, ideal_stats.stability_rate * 100);
        fprintf('    Avg Gen: %.1f, Bias L2: %.4g, Radius: %.4g\n', ...
            ideal_stats.avg_stable_gen, ideal_stats.bias_L2, ideal_stats.cluster_radius_med);
    else
        fprintf('    No stable runs\n');
    end
    
    fprintf('  Nadir Point:\n');
    if nadir_stats.stable_runs > 0
        fprintf('    Stable: %d/%d (%.1f%%)\n', nadir_stats.stable_runs, ...
            nadir_stats.total_runs, nadir_stats.stability_rate * 100);
        fprintf('    Avg Gen: %.1f, Bias L2: %.4g, Radius: %.4g\n', ...
            nadir_stats.avg_stable_gen, nadir_stats.bias_L2, nadir_stats.cluster_radius_med);
    else
        fprintf('    No stable runs\n');
    end
end

function result = detect_tail_stability(trajectory, varargin)
    p = inputParser;
    p.addParameter('max_abs',      1e-3, @(x) isempty(x) || isscalar(x));
    p.addParameter('rel_max',      1e-6, @(x) isempty(x) || (isscalar(x) && x > 0));
    p.addParameter('min_tail_len', 30, @(x) isscalar(x) && x >= 1);
    p.parse(varargin{:});

    max_abs      = p.Results.max_abs;
    rel_max      = p.Results.rel_max;
    min_tail_len = p.Results.min_tail_len;

    [T, M] = size(trajectory);

    if min_tail_len > T
        error('min_tail_len (%d) cannot exceed trajectory length T=%d.', min_tail_len, T);
    end

    X = trajectory;
    cs1 = zeros(T, M);
    cs2 = zeros(T, M);

    cs1(T, :) = X(T, :);
    cs2(T, :) = X(T, :).^2;
    for t = T-1:-1:1
        cs1(t, :) = cs1(t+1, :) + X(t, :);
        cs2(t, :) = cs2(t+1, :) + X(t, :).^2;
    end

    max_tail = zeros(T, 1);

    for t = 1:T
        n = T - t + 1;
        mu = cs1(t, :) / n;
        vals = X(t:T, :);
        diffs = vals - mu;
        d = vecnorm(diffs, 2, 2);
        max_tail(t) = max(d);
    end

    max_start = T - min_tail_len + 1;
    tail_mask = (1:T)' <= max_start;

    stable_gen_max_abs = NaN;
    is_stable_max_abs  = false;

    if ~isempty(max_abs)
        idx_max = find(max_tail <= max_abs & tail_mask, 1, 'first');
        if ~isempty(idx_max)
            stable_gen_max_abs = idx_max;
            is_stable_max_abs  = true;
        end
    end

    stable_gen_max_rel = NaN;
    is_stable_max_rel  = false;

    if ~isempty(rel_max)
        max0 = max_tail(1);

        if max0 <= max_abs
            stable_gen_max_rel = 1;
            is_stable_max_rel  = true;
        else
            thresh_max_rel = max(rel_max * max0, max_abs);
            idx_max_rel = find(max_tail <= thresh_max_rel & tail_mask, 1, 'first');
            if ~isempty(idx_max_rel)
                stable_gen_max_rel = idx_max_rel;
                is_stable_max_rel  = true;
            end
        end
    end

    result.max_tail            = max_tail;
    result.stable_gen_max_abs  = stable_gen_max_abs;
    result.is_stable_max_abs   = is_stable_max_abs;
    result.stable_gen_max_rel  = stable_gen_max_rel;
    result.is_stable_max_rel   = is_stable_max_rel;
end

%% Save statistics to mat file
function saveStatistics(stats, statsDir, algorithmName, problemName, pointType)
    if isempty(stats)
        return;
    end
    
    % Create filename
    fileName = sprintf('SS-%s-%s-%s.mat', pointType, algorithmName, problemName);
    filePath = fullfile(statsDir, fileName);
    
    % Save key statistics
    stable_runs = stats.stable_runs;
    total_runs = stats.total_runs;
    stability_rate = stats.stability_rate;
    avg_stable_gen = stats.avg_stable_gen;
    cluster_radius_med = stats.cluster_radius_med;
    cluster_radius_max = stats.cluster_radius_max;
    bias_L2 = stats.bias_L2;
    bias_L1 = stats.bias_L1;
    spread_trace = stats.spread_trace;
    spread_max_eig = stats.spread_max_eig;
    
    % Also save full centroids for potential future analysis
    centroids = stats.centroids;
    center = stats.center;
    covariance = stats.covariance;
    
    save(filePath, 'stable_runs', 'total_runs', 'stability_rate', ...
        'avg_stable_gen', 'cluster_radius_med', 'cluster_radius_max', ...
        'bias_L2', 'bias_L1', 'spread_trace', 'spread_max_eig', ...
        'centroids', 'center', 'covariance');
end

%% Compute stability statistics
function stats = computeStabilityStatistics(norm_histories, type, M)
    % Initialize
    stats = struct();
    stats.type = type;
    stats.M = M;
    
    % Detect stability for each run
    results = cellfun(@(c) detect_tail_stability(c, 'rel_max', 1e-6, 'min_tail_len', 30), ...
        norm_histories, 'UniformOutput', false);
    
    % Process stable runs
    stable_runs = 0;
    avg_stable_gen = 0;
    centroids = [];
    
    for ri = 1:numel(results)
        result = results{ri};
        if result.is_stable_max_rel == 1
            stable_gen = result.stable_gen_max_rel;
            estimated_centroid = mean(norm_histories{ri}(stable_gen:end,:), 1);
            stable_runs = stable_runs + 1;
            avg_stable_gen = avg_stable_gen + (stable_gen - avg_stable_gen) / stable_runs;
            centroids = [centroids; estimated_centroid];
        end
    end
    
    stats.stable_runs = stable_runs;
    stats.total_runs = numel(results);
    stats.stability_rate = stable_runs / numel(results);
    stats.avg_stable_gen = avg_stable_gen;
    
    if stable_runs == 0
        stats.centroids = [];
        stats.center = [];
        stats.cluster_radius_max = NaN;
        stats.cluster_radius_med = NaN;
        stats.cluster_radius_mean = NaN;
        stats.bias_L2 = NaN;
        stats.bias_L1 = NaN;
        stats.spread_trace = NaN;
        stats.spread_max_eig = NaN;
        stats.covariance = [];
        stats.median_dist_idx = NaN;
        return;
    end
    
    % Compute spatial statistics
    [N, ~] = size(centroids);
    stats.centroids = centroids;
    stats.center = mean(centroids, 1);
    
    % True points in normalized space
    if strcmpi(type, 'ideal')
        true_point = zeros(1, M);
    else  % nadir
        true_point = ones(1, M);
    end
    
    % Cluster metrics
    d_center = vecnorm(centroids - stats.center, 2, 2);
    stats.cluster_radius_max = max(d_center);
    stats.cluster_radius_med = median(d_center);
    stats.cluster_radius_mean = mean(d_center);
    
    % Find the point closest to median distance
    [~, med_idx] = min(abs(d_center - stats.cluster_radius_med));
    stats.median_dist_idx = med_idx;
    
    % Bias metrics
    stats.bias_L2 = norm(stats.center - true_point, 2);
    stats.bias_L1 = mean(abs(stats.center - true_point));
    
    % Spread metrics (covariance-based)
    if N > 1
        C = cov(centroids, 1);
        stats.covariance = C;
        stats.spread_trace = trace(C);
        eigvals = eig(C);
        stats.spread_max_eig = max(eigvals);
    else
        stats.covariance = zeros(M);
        stats.spread_trace = 0;
        stats.spread_max_eig = 0;
    end
end

function problemHandles = preprocessProblemHandles(algorithmHandles, sourceDirData)
    problemHandles = {};
    for ah = 1:numel(algorithmHandles)
        algName = func2str(algorithmHandles{ah});
        dataFile = dir(fullfile(sourceDirData, algName, '*.mat'));
        FileNames = {dataFile.name};
        
        for fi = 1:numel(FileNames)
            FileName = FileNames{fi};
            [~,rawName,~] = fileparts(FileName);
            tokens = strsplit(rawName,'_');
            
            % Ensure there's a token at index 2
            if length(tokens) >= 2
                problemHandles{end+1} = [tokens{2}, '-', tokens{3}(2:end)];
            end
        end
    end
    % Apply str2func to unique names to get a cell array of function handles

    uniqueProblemNames = unique(problemHandles);

    problemHandles = cellfun(@(f) split(f, '-'), uniqueProblemNames, 'UniformOutput', false);
end

function [hvValues, igdValues, numRuns] = processAlgorithmProblem(algorithmName, problemName, HVDir, hpns, M, runs)
    subdirPath = fullfile(HVDir, algorithmName);
    matFiles = dir(fullfile(subdirPath, '*.mat'));
    
    % Pre-allocate (will trim later)
    igdValues = zeros(1, runs);
    hvValues = zeros(1, runs);
    runIdx = 1;
    
    % Get reference point once for this problem
    ph = str2func(problemName);
    Problem = ph('M', M);
    
    if ismember(problemName, hpns)
        ref = load(sprintf('./Info/ReferencePF/PF-%s.mat', problemName), 'PF').PF;
    else
        [PF, ref] = GetPFnRef(Problem);
    end
    
    % Process only files matching this problem
    for j = 1:length(matFiles)
        fileParts = split(matFiles(j).name, '_');
        fileProblem = fileParts{2};
        
        if ~strcmp(fileProblem, problemName)
            continue
        end
        
        data = load(fullfile(subdirPath, matFiles(j).name)).finalPop;
        finalHV = stk_dominatedhv(data.objs, ref);
        finalIGD = IGDp(data, PF);
        
        hvValues(runIdx) = finalHV;
        igdValues(runIdx) = finalIGD;
        runIdx = runIdx + 1;
    end
    
    numRuns = runIdx - 1;
end

function saveIntermediateHV(filepath, hvValues)
    save(filepath, 'hvValues');
end

function saveIntermediateIGD(filepath, igdValues)
    save(filepath, 'igdValues');
end

function progressCallback(data, total, startTime)
    persistent completed;
    if isempty(completed)
        completed = 0;
    end
    completed = completed + 1;
    elapsed = toc(startTime);
    eta = (elapsed / completed) * (total - completed);
    fprintf('[%d/%d] %s × %s (%d runs) | %.1fs | ETA %.1fs\n', ...
        completed, total, data.alg, data.prob, data.runs, elapsed, eta);
    drawnow;
end

function parsave(filepath, finalPop)
%PARSAVE Save function for use inside parfor
%   parfor doesn't allow save() with dynamic filenames directly,
%   so we wrap it in a function.
    save(filepath, 'finalPop', '-v6');
end

function wipeDir(dirPath)
    dataDir = fullfile(dirPath);
    
    % Delete subdirectories
    subdirs = dir(dataDir);
    subdirs = subdirs([subdirs.isdir]);
    subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));
    for i = 1:length(subdirs)
        subdirPath = fullfile(dataDir, subdirs(i).name);
        fprintf('Deleting directory: %s\n', subdirPath);
        rmdir(subdirPath, 's');
    end
    
    % Delete .mat files
    matFiles = dir(fullfile(dataDir, '*.mat'));
    for i = 1:length(matFiles)
        filePath = fullfile(dataDir, matFiles(i).name);
        fprintf('Deleting file: %s\n', filePath);
        delete(filePath);
    end
    
    % Delete .png files
    pngFiles = dir(fullfile(dataDir, '*.png'));
    for i = 1:length(pngFiles)
        filePath = fullfile(dataDir, pngFiles(i).name);
        fprintf('Deleting file: %s\n', filePath);
        delete(filePath);
    end
    
    fprintf('Task completed: All subdirectories, .mat, and .png files removed.\n\n');
end

function SummarizeMetrics(algorithmHandles, problemHandles, M)
% SummarizeMetrics - Compute reference HV, HV summary, and IGD+ summary
%
% INPUT:
%   algorithmHandles : cell array of algorithm function handles, e.g. {@MeNSGAIIIwH, @OrmeNSGAIIIwH}
%   problemHandles   : cell array of problem function handles, e.g. {@DTLZ1, @IDTLZ1}
%   M                : number of objectives
%
% OUTPUT:
%   Saves:
%     - ./Info/FinalHV/ReferenceHV/prob2rhv.mat (reference hypervolumes)
%     - ./Info/FinalHV/hvSummary.mat (normalized HV summary)
%     - ./Info/FinalIGD/igdSummary.mat (IGD+ summary)

    %% Extract names from function handles
    algorithmNames = cellfun(@func2str, algorithmHandles, 'UniformOutput', false);
    problemNames = cellfun(@func2str, problemHandles, 'UniformOutput', false);
    
    numAlgorithms = numel(algorithmNames);
    numProblems = numel(problemNames);
    
    %% Directory setup
    hvBaseDir = './Info/FinalHV';
    igdBaseDir = './Info/FinalIGD';
    refDir = fullfile(hvBaseDir, 'ReferenceHV');
    
    if ~exist(refDir, 'dir'); mkdir(refDir); end

    %% ================================================================
    %  PHASE 1: Compute Reference Hypervolumes
    %% ================================================================
    fprintf('\n========== Phase 1: Computing Reference Hypervolumes ==========\n');
    
    prob2rhv = containers.Map();
    
    for i = 1:numProblems
        ph = problemHandles{i};
        pn = problemNames{i};
        
        fprintf('  Computing reference HV for %s (%d/%d)...\n', pn, i, numProblems);
        
        % Create problem instance
        Problem = ph('M', M);
        
        % Get Pareto front and reference point
        [PF, ref] = GetPFnRef(Problem);
        
        % Compute hypervolume of the Pareto front
        hv = stk_dominatedhv(PF, ref);
        prob2rhv(pn) = hv;
        
        fprintf('    Reference HV: %.6f\n', hv);
    end
    
    % Save reference hypervolumes
    refPath = fullfile(refDir, 'prob2rhv.mat');
    save(refPath, 'prob2rhv');
    fprintf('  Saved reference HVs to: %s\n', refPath);

    %% ================================================================
    %  PHASE 2: Generate Normalized HV Summary
    %% ================================================================
    fprintf('\n========== Phase 2: Generating HV Summary ==========\n');
    
    hvSummary = struct();
    
    for i = 1:numProblems
        probName = problemNames{i};
        
        % Get reference HV for this problem
        rhv = prob2rhv(probName);
        
        % Create a struct for this problem's results
        probResult = struct();
        
        for j = 1:numAlgorithms
            alg = algorithmNames{j};
            
            % Load algorithm's prob2hv map
            algPath = fullfile(hvBaseDir, alg, 'prob2hv.mat');
            
            if ~exist(algPath, 'file')
                warning('HV file not found: %s', algPath);
                probResult.(alg) = 'N/A';
                probResult.([alg '_mean']) = NaN;
                probResult.([alg '_std']) = NaN;
                probResult.([alg '_raw']) = [];
                continue;
            end
            
            algData = load(algPath, 'prob2hv_map');
            prob2hv = algData.prob2hv_map;
            
            % Check if this problem exists for this algorithm
            if isKey(prob2hv, probName)
                hvList = prob2hv(probName);
                
                % Normalize by reference HV
                normalizedHV = hvList / rhv;
                
                % Compute statistics
                meanHV = mean(normalizedHV);
                stdHV = std(normalizedHV);
                
                % Store as formatted string (mean ± std)
                probResult.(alg) = sprintf('%.4f ± %.4f', meanHV, stdHV);
                
                % Also store raw values if needed later
                probResult.([alg '_mean']) = meanHV;
                probResult.([alg '_std']) = stdHV;
                probResult.([alg '_raw']) = normalizedHV;
            else
                probResult.(alg) = 'N/A';
                probResult.([alg '_mean']) = NaN;
                probResult.([alg '_std']) = NaN;
                probResult.([alg '_raw']) = [];
            end
        end
        
        % Use valid field name
        validFieldName = matlab.lang.makeValidName(probName);
        hvSummary.(validFieldName) = probResult;
    end
    
    % Display HV summary table
    fprintf('\n---------- Normalized HV Summary (Mean ± Std) ----------\n\n');
    
    % Build header
    headerFormat = '%-20s';
    headerArgs = {'Problem'};
    for j = 1:numAlgorithms
        headerFormat = [headerFormat ' | %-20s'];
        headerArgs{end+1} = algorithmNames{j};
    end
    fprintf([headerFormat '\n'], headerArgs{:});
    fprintf('%s\n', repmat('-', 1, 22 + 23*numAlgorithms));
    
    % Print rows
    probFields = fieldnames(hvSummary);
    for i = 1:length(probFields)
        prob = probFields{i};
        result = hvSummary.(prob);
        
        rowFormat = '%-20s';
        rowArgs = {prob};
        for j = 1:numAlgorithms
            rowFormat = [rowFormat ' | %-20s'];
            rowArgs{end+1} = result.(algorithmNames{j});
        end
        fprintf([rowFormat '\n'], rowArgs{:});
    end
    
    % Save HV summary
    hvSummaryPath = fullfile(hvBaseDir, 'hvSummary.mat');
    save(hvSummaryPath, 'hvSummary');
    fprintf('\nSaved HV summary to: %s\n', hvSummaryPath);

    %% ================================================================
    %  PHASE 3: Generate IGD+ Summary
    %% ================================================================
    fprintf('\n========== Phase 3: Generating IGD+ Summary ==========\n');
    
    igdSummary = struct();
    
    for i = 1:numProblems
        probName = problemNames{i};
        
        % Create a struct for this problem's results
        probResult = struct();
        
        for j = 1:numAlgorithms
            alg = algorithmNames{j};
            
            % Load algorithm's prob2igdp map
            algPath = fullfile(igdBaseDir, alg, 'prob2igdp.mat');
            
            if ~exist(algPath, 'file')
                warning('IGD+ file not found: %s', algPath);
                probResult.(alg) = 'N/A';
                probResult.([alg '_mean']) = NaN;
                probResult.([alg '_std']) = NaN;
                probResult.([alg '_raw']) = [];
                continue;
            end
            
            algData = load(algPath, 'prob2igd');
            prob2igd = algData.prob2igd;
            
            % Check if this problem exists for this algorithm
            if isKey(prob2igd, probName)
                igdList = prob2igd(probName);
                
                % Compute statistics
                meanIGD = mean(igdList);
                stdIGD = std(igdList);
                
                % Store as formatted string (mean ± std)
                probResult.(alg) = sprintf('%.3g ± %.3g', meanIGD, stdIGD);
                
                % Also store raw values if needed later
                probResult.([alg '_mean']) = meanIGD;
                probResult.([alg '_std']) = stdIGD;
                probResult.([alg '_raw']) = igdList;
            else
                probResult.(alg) = 'N/A';
                probResult.([alg '_mean']) = NaN;
                probResult.([alg '_std']) = NaN;
                probResult.([alg '_raw']) = [];
            end
        end
        
        % Use valid field name
        validFieldName = matlab.lang.makeValidName(probName);
        igdSummary.(validFieldName) = probResult;
    end
    
    % Display IGD+ summary table
    fprintf('\n---------- IGD+ Summary (Mean ± Std) ----------\n\n');
    
    % Build header
    headerFormat = '%-20s';
    headerArgs = {'Problem'};
    for j = 1:numAlgorithms
        headerFormat = [headerFormat ' | %-20s'];
        headerArgs{end+1} = algorithmNames{j};
    end
    fprintf([headerFormat '\n'], headerArgs{:});
    fprintf('%s\n', repmat('-', 1, 22 + 23*numAlgorithms));
    
    % Print rows
    probFields = fieldnames(igdSummary);
    for i = 1:length(probFields)
        prob = probFields{i};
        result = igdSummary.(prob);
        
        rowFormat = '%-20s';
        rowArgs = {prob};
        for j = 1:numAlgorithms
            rowFormat = [rowFormat ' | %-20s'];
            rowArgs{end+1} = result.(algorithmNames{j});
        end
        fprintf([rowFormat '\n'], rowArgs{:});
    end
    
    % Save IGD+ summary
    igdSummaryPath = fullfile(igdBaseDir, 'igdSummary.mat');
    save(igdSummaryPath, 'igdSummary');
    fprintf('\nSaved IGD+ summary to: %s\n', igdSummaryPath);
    
    %% ================================================================
    %  DONE
    %% ================================================================
    fprintf('\n========== SummarizeMetrics Complete ==========\n');
    fprintf('Outputs:\n');
    fprintf('  - %s\n', refPath);
    fprintf('  - %s\n', hvSummaryPath);
    fprintf('  - %s\n', igdSummaryPath);
end
