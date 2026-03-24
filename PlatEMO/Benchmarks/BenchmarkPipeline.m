%% BenchmarkPipeline - Clean modular benchmark pipeline
%
%   This is the refactored version of PipelineToStability.m, broken into
%   modular, reusable functions for better maintainability.
%
%   Configuration:
%     - Edit the 'algorithms' and 'problems' arrays below
%     - Adjust parameters (FE, N, M, runs) as needed
%     - Comment/uncomment tasks to run partial pipeline
%
%   Problem specification formats:
%     @Handle            - Continuous problem, uses params.M
%     {@Handle, M}       - Continuous problem, specified M
%     {@Handle, M, D, ID} - Combinatorial problem (e.g., MOTSP, MOKP)
%
%   Examples:
%     problems = {@MaF1, {@MaF8, 10}, {@MOTSP, 3, 5, 1}, {@MOKP, 3, 250, 2}};
%
%   Combinatorial problems:
%     - Have no known Pareto front; only HV is computed (via GetOptimum ref)
%     - Require D (decision variables) and ID (instance identifier)
%     - Instance data (C matrices, P/W matrices) is generated deterministically
%       from rng(ID) on first instantiation
%     - Heuristic initial populations are generated via greedy solvers
%
%   Supports config-based algorithms ({@ConfigurableNSGAIIIwH, config_struct})
%   created via generateAlgorithm() as well as legacy algorithms (@PyNSGAIIIwH).
%
%   Naming convention: [Area1]-[Area2]-[Area3]-NSGA-III
%   All tokens use title case (e.g., ZY, Tk, Dss).
%   Base algorithm is implicitly Py-NSGA-III; the Py prefix is omitted.
%
%   Area 1 (Implementation): Z/Y/X flags in reversed-alpha order
%     7 standard variants: (none), Z, Y, X, ZY, ZX, YX
%   Area 2 (Normalization): Tk (Tikhonov regularization)
%   Area 3 (Selection): Dss

%% ========================================================================
%  CONFIGURATION
%  ========================================================================

% Define algorithms to benchmark using generateAlgorithm():
%   generateAlgorithm()                                              % NSGA-III (baseline)
%   generateAlgorithm('area1', 'ZY')                                 % ZY-NSGA-III
%   generateAlgorithm('area1', 'ZY', 'momentum', 'tikhonov')           % ZY-Tk-NSGA-III
%   generateAlgorithm('area1', 'ZY', 'momentum', 'tikhonov', 'dss', true) % ZY-Tk-Dss-NSGA-III

%% Define problems to benchmark. Recommended problems:
% problems = {@BT9, @DTLZ4, @DTLZ6, @DTLZ7, @IDTLZ2 ...
%     @IMOP5, @IMOP6, @IMOP7, @MaF13,@MaF14, ...
%     @MaF15, @MinusDTLZ1, @MinusWFG1, ...
%     @MinusWFG2, @RWA2, @RWA3, @RWA4, @RWA5, @RWA6,...
%     @UF8, @UF10, @VNT1, @WFG1, @WFG2, @WFG8};

% Generate all 7 x 2 x 2 = 28 algorithm configurations
% area1Options = {'', 'Z', 'Y', 'X', 'ZY', 'ZX', 'YX'};
% area2Options = {'none', 'tikhonov'};
% area3Options = {false, true};
% 
% algorithms = {};
% for a1 = 1:numel(area1Options)
%     for a2 = 1:numel(area2Options)
%         for a3 = 1:numel(area3Options)
%             algorithms{end+1} = generateAlgorithm( ...
%                 'area1', area1Options{a1}, ...
%                 'momentum', area2Options{a2}, ...
%                 'dss', area3Options{a3}); %#ok<SAGROW>
%         end
%     end
% end

algorithms = {generateAlgorithm(), ...
            generateAlgorithm('area1', 'XYZ'), ...
            generateAlgorithm('area1', 'XYZ', 'momentum', 'tikhonov'), ...
            generateAlgorithm('area1', 'XYZ', 'momentum', 'tikhonov', 'useDSS', true)}

% Problems with per-problem M: use {handle, M} pairs or plain handles.
% Plain handles use params.M as default.
% Combinatorial problems: {handle, M, D, ID}
problems = {@MaF3}
% problems_combo = {@MaF1, {@MOTSP, 3, 12, 1}, {@MOKP, 3, 250, 1}}
% problems1 = {@DTLZ1, @DTLZ2, @DTLZ3, @DTLZ4, @DTLZ5, @DTLZ6, @DTLZ7};
% problems2 = {@RWA2, @RWA3, @RWA4, @RWA5, @RWA6};
% problems3 = {@MinusDTLZ1, @MinusDTLZ2, @MinusDTLZ3, @MinusDTLZ4, @MinusDTLZ5, @MinusDTLZ6};
% problems = [problems1, problems2, problems3];

% Benchmark parameters
params = struct(...
    'FE',   50000, ...   % Max function evaluations
    'N',    120, ...      % Population size
    'M',    3, ...        % Default number of objectives (used when not specified per-problem)
    'runs', 3 ...         % Independent runs
);

%% Parse problems into handles and per-problem M, D, ID vectors
[problemHandles, Mvec, Dvec, IDvec, problemNames] = parseProblemList(problems, params.M);

%% Initialize combinatorial problem instances (generate data files with fixed seeds)
initializeCombinatorialProblems(problemHandles, Mvec, Dvec, IDvec, problemNames);

%% Load algorithm display names for reports
%% Please modify in Info/Misc/alg...names.json
algDisplayNames = loadAlgDisplayNames();

%% ========================================================================
%%  TASK 0: CLEAN DATA (COMMENTED - USE WITH CAUTION)
%% ========================================================================
% disp("WARNING: WIPING DATA")
% pause(4)
% wipeDir('./Data')
% wipeDir('./TrimmedData')
% wipeDir('./IntermediateHV')
% wipeDir('./IntermediateIGDp')
% wipeDir('./IntermediateGenSpread')
% wipeDir('./IntermediateTime')
% wipeDir('./Info/FinalHV')
% wipeDir('./Info/FinalIGD')
% wipeDir('./Info/FinalGenSpread')
% wipeDir('./Info/FinalTime')
% wipeDir('./Info/MedianHVResults')
% wipeDir('./Info/IdealNadirHistory')
% wipeDir('./Info/TemporalDispersionPlot')
% 
% wipeDir('./Info/InitialPopulation')
% wipeDir('./Info/StableStatistics')
% wipeDir('./Info/Bounds')
% wipeDir('./Visualization/images')
% wipeDir('./AnytimeMetrics')
% return

%% ========================================================================
%%  TASK 1: RUN BENCHMARK EXPERIMENTS
%% ========================================================================
fprintf('\n=== Task 1: Running Benchmarks ===\n');
runBenchmarks(algorithms, problemHandles, params, Mvec, Dvec, IDvec);

%% If any of the files are unloadable after TASK 1, rerun using this:
rerunCorruptedExperiments(algorithms, params)

%% ========================================================================
%%  TASK 2: TRIM DATA
% %% ========================================================================
fprintf('\n=== Task 2: Trimming Data ===\n');
trimBenchmarkData(algorithms, './Data', './TrimmedData');

%% ========================================================================
%% TASK 2.5: COMPUTE REFERENCE PF AND METRICS
%%           Continuous: GetOptimum binary search (Class 1)
%%           Combinatorial: generateApproximatePF saves directly to ReferencePF
%%             (run generateApproximatePF first for combinatorial problems)
%% ========================================================================
%% Please call generateApproximatePF before evaluating MOCO instances. Example:
%% generateApproximatePF(@MOTSP, 3, 30, 1)
generateReferencePF(problemHandles, Mvec, 3000, problemNames)
GenerateRefHVfromPF(problemHandles, Mvec, params.N, problemNames)
%% ========================================================================
%% TASK 3: COMPUTE ALL METRICS (HV, IGD+, Generalized Spread)
%% ========================================================================
fprintf('\n=== Task 3: Computing HV/IGD+/Generalized Spread ===\n');
computeAllMetrics(algorithms, problemHandles, params, Mvec, Dvec, IDvec, problemNames);

%% ========================================================================
%% TASK 3.5: COMPUTE TIME METRICS
%% ========================================================================
fprintf('\n=== Task 3.5: Computing Time Metrics ===\n');
computeTimeMetrics(algorithms, problemHandles, params, problemNames);

%% ========================================================================
%%  TASK 4: SUMMARIZE METRICS (HV, IGD+, Generalized Spread, Time)
%% ========================================================================
fprintf('\n=== Task 4: Summarizing Metrics ===\n');
SummarizeMetrics(algorithms, problemHandles, Mvec, params.N, problemNames);

%% ========================================================================
%%  TASK 5: COMPUTE IDEAL/NADIR HISTORIES
%% ========================================================================
fprintf('\n=== Task 5: Computing Ideal/Nadir Histories ===\n');
GenerateIdealNadirHistoriesMethod(algorithms, problemHandles, Mvec, problemNames, Dvec, IDvec);


%% ========================================================================
%%  TASK 6: COMPUTE STABILITY STATISTICS
%% ========================================================================
fprintf('\n=== Task 6: Computing Stability Statistics ===\n');
runStabilityAnalysis(algorithms, problemHandles, Mvec, problemNames);

%% ========================================================================
%%  TASK 7: EXTRACT MEDIAN HV RUNS
%% ========================================================================
fprintf('\n=== Task 7: Extracting Median HV Runs ===\n');
extractMedianHV(algorithms, problemNames, Mvec, problemHandles, Dvec, IDvec);

%% ========================================================================
%%  TASK 8: VISUALIZE RESULTS
%% ========================================================================
fprintf('\n=== Task 8: Visualizing Results ===\n');
visualizeResults(algorithms, problemHandles, Mvec, Dvec, IDvec, problemNames);

%% ========================================================================
%%  TASK 8.5: COMPUTE ANYTIME METRICS (HV/IGD+/GenSpread per generation)
%% ========================================================================
fprintf('\n=== Task 8.5: Computing Anytime Metrics ===\n');
problemNames = cellfun(@func2str, problemHandles, 'UniformOutput', false);
ComputeAnytimeMetrics('./Data', './AnytimeMetrics', problemNames);
% %% Then launch GUI: AnytimePerformanceGUI('./AnytimeMetrics')
AnytimePerformanceGUI('./AnytimeMetrics');


%% ========================================================================
%%  TASK 9: GENERATE SUPPLEMENTARY MATERIALS
%% ========================================================================
fprintf('\n=== Task 9: Generating Supplementary Materials ===\n');
baseDir = './Info/StableStatistics';
hvSummaryPath = './Info/FinalHV/hvSummary.mat';
igdpSummaryPath = './Info/FinalIGD/igdSummary.mat';


generateSupplementaryMaterials(baseDir, hvSummaryPath, igdpSummaryPath, ...
    algorithms, problemNames, Mvec, algDisplayNames);

%% ========================================================================
%%  TASK 10: COMPILE LATEX
%% ========================================================================
fprintf('\n=== Task 10: Compiling LaTeX ===\n');
[status, cmdout] = system('pdflatex SupplementaryMaterials3.tex');
if status == 0
    fprintf('LaTeX compilation successful.\n');
else
    fprintf('LaTeX compilation failed:\n%s\n', cmdout);
end

fprintf('\n========================================\n');
fprintf('BENCHMARK PIPELINE COMPLETE\n');
fprintf('========================================\n');

%% ========================================================================
%%  HELPER FUNCTIONS
%% ========================================================================

function [problemHandles, Mvec, Dvec, IDvec, problemNames] = parseProblemList(problems, defaultM)
%PARSEPROBLEMLIST Parse problem list into handles, M/D/ID vectors, and names.
%
%   problems can contain:
%     - Function handles: @DTLZ1 (uses defaultM)
%     - {handle, M} pairs: {@DTLZ1, 5} (continuous, specified M)
%     - {handle, M, D, ID} quads: {@MOTSP, 3, 12, 1} (combinatorial)
%
%   Returns:
%     problemHandles - Cell array of function handles
%     Mvec           - Numeric vector of M values (one per problem)
%     Dvec           - Numeric vector of D values (NaN for continuous)
%     IDvec          - Numeric vector of ID values (NaN for continuous)
%     problemNames   - Cell array of unique pipeline names
%                      Continuous: 'MaF1', Combinatorial: 'MOTSP_ID1'
    n = numel(problems);
    problemHandles = cell(1, n);
    Mvec = zeros(1, n);
    Dvec = nan(1, n);
    IDvec = nan(1, n);
    problemNames = cell(1, n);
    for i = 1:n
        entry = problems{i};
        if iscell(entry)
            problemHandles{i} = entry{1};
            Mvec(i) = entry{2};
            if numel(entry) >= 4
                % Combinatorial: {handle, M, D, ID}
                Dvec(i) = entry{3};
                IDvec(i) = entry{4};
                problemNames{i} = sprintf('%s_ID%d', func2str(entry{1}), entry{4});
            else
                % Continuous with specified M: {handle, M}
                problemNames{i} = func2str(entry{1});
            end
        else
            problemHandles{i} = entry;
            Mvec(i) = defaultM;
            problemNames{i} = func2str(entry);
        end
    end
end

function initializeCombinatorialProblems(problemHandles, Mvec, Dvec, IDvec, problemNames)
%INITIALIZECOMBINATORIALPROBLEMS Generate instance data and HV reference points.
%
%   For each combinatorial problem (non-NaN ID), seeds the RNG with the ID
%   and instantiates the problem to generate its instance data file (e.g.,
%   C matrices for MOTSP, P/W matrices for MOKP).  Also stores the HV
%   reference point from GetOptimum for later metric computation.
    refPointDir = './Info/ReferencePF';
    if ~exist(refPointDir, 'dir'), mkdir(refPointDir); end

    for i = 1:numel(problemHandles)
        if isnan(IDvec(i)), continue; end

        probName = func2str(problemHandles{i});
        M_i = Mvec(i); D_i = Dvec(i); ID_i = IDvec(i);

        % Seed RNG for reproducible instance generation
        rng(ID_i);

        % Instantiate problem (creates and caches instance data file)
        paramCell = buildCombinatorialParam(probName, ID_i);
        pro = problemHandles{i}('M', M_i, 'D', D_i, 'parameter', paramCell);

        % Store HV reference point for metric computation
        refPoint = pro.GetOptimum(1);
        refFile = fullfile(refPointDir, sprintf('RefPoint-%s.mat', problemNames{i}));
        save(refFile, 'refPoint');

        fprintf('Initialized %s: M=%d, D=%d, ID=%d | ref=[%s]\n', ...
            problemNames{i}, M_i, D_i, ID_i, num2str(refPoint, '%.2f '));
    end
end

function algDisplayNames = loadAlgDisplayNames()
%LOADALGDISPLAYNAMES Load algorithm display name mappings from JSON
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
