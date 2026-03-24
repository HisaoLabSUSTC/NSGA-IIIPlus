function runBenchmarks(algorithms, problems, config, Mvec, Dvec, IDvec, useParallel)
%RUNBENCHMARKS Execute benchmark experiments for all algorithm-problem combinations
%
%   runBenchmarks(algorithms, problems, config, Mvec)
%   runBenchmarks(algorithms, problems, config, Mvec, Dvec, IDvec)
%   runBenchmarks(algorithms, problems, config, Mvec, Dvec, IDvec, useParallel)
%
%   Input:
%     algorithms  - Cell array of algorithm specs (handles or config cells)
%     problems    - Cell array of problem function handles
%     config      - Struct with fields:
%                     FE   - Max function evaluations (default: 100000)
%                     N    - Population size (default: 120)
%                     M    - Default number of objectives (default: 3)
%                     runs - Number of independent runs (default: 5)
%     Mvec        - (optional) Numeric vector of M values, one per problem.
%                   If omitted, config.M is used for all problems.
%     Dvec        - (optional) Numeric vector of D values (NaN = auto).
%     IDvec       - (optional) Numeric vector of instance IDs (NaN = none).
%     useParallel - (optional) Use parfor (default: true)
%
%   Supports both legacy algorithms (@PyNSGAIIIwH) and config-based algorithms
%   ({@ConfigurableNSGAIIIwH, config_struct}).
%
%   Combinatorial problems (non-NaN ID) are instantiated with explicit D
%   and 'parameter' cell so that the correct instance data is loaded.

    %% Parse config with defaults
    if nargin < 3
        config = struct();
    end

    FE = getFieldDefault(config, 'FE', 100000);
    N = getFieldDefault(config, 'N', 120);
    defaultM = getFieldDefault(config, 'M', 3);
    runs = getFieldDefault(config, 'runs', 5);

    if nargin < 4 || isempty(Mvec)
        Mvec = repmat(defaultM, 1, numel(problems));
    end

    if nargin < 5 || isempty(Dvec)
        Dvec = nan(1, numel(problems));
    end

    if nargin < 6 || isempty(IDvec)
        IDvec = nan(1, numel(problems));
    end

    if nargin < 7
        useParallel = true;
    end

    save_interval = ceil(FE / N);

    fprintf('=== Running Benchmarks ===\n');
    fprintf('Algorithms: %d, Problems: %d, Runs: %d\n', ...
        numel(algorithms), numel(problems), runs);

    %% Generate initial populations
    generateInitialPopulations(problems, N, Mvec, runs, ...
        './Info/InitialPopulation', Dvec, IDvec);

    %% Create all combinations
    [P, A, R] = ndgrid(1:length(problems), 1:length(algorithms), 1:runs);
    combinations = [P(:), A(:), R(:)];
    total_tasks = size(combinations, 1);
    fprintf('Starting %d parallel tasks...\n', total_tasks);

    %% Run experiments
    if useParallel
        parfor idx = 1:total_tasks
            runOneTask(idx, combinations, algorithms, problems, ...
                Mvec, Dvec, IDvec, N, FE, save_interval, runs);
        end
    else
        for idx = 1:total_tasks
            runOneTask(idx, combinations, algorithms, problems, ...
                Mvec, Dvec, IDvec, N, FE, save_interval, runs);
        end
    end

    fprintf('=== Benchmark completed ===\n');
end

%% ==================== Local Functions ====================

function runOneTask(idx, combinations, algorithms, problems, ...
        Mvec, Dvec, IDvec, N, FE, save_interval, ~)

    prob_idx = combinations(idx, 1);
    algo_idx = combinations(idx, 2);
    run_num = combinations(idx, 3);

    % Get algorithm and problem info
    algorithmSpec = algorithms{algo_idx};
    problemHandle = problems{prob_idx};
    prob_name = func2str(problemHandle);
    algo_name = getAlgorithmName(algorithmSpec);
    M_i = Mvec(prob_idx);
    D_i = Dvec(prob_idx);
    ID_i = IDvec(prob_idx);
    isCombinatorial = ~isnan(ID_i);

    % Create problem instance for dimensions
    if isCombinatorial
        paramCell = buildCombinatorialParam(prob_name, ID_i);
        pro_inst = problemHandle('M', M_i, 'D', D_i, 'parameter', paramCell);
    else
        pro_inst = problemHandle('M', M_i);
    end

    % Build file paths
    if isCombinatorial
        initial_pop_path = fullfile('Info', 'InitialPopulation', ...
            sprintf('HS-%s_ID%d_M%d_D%d_%d.mat', prob_name, ID_i, pro_inst.M, pro_inst.D, run_num));
    else
        initial_pop_path = fullfile('Info', 'InitialPopulation', ...
            sprintf('HS-%s_M%d_D%d_%d.mat', prob_name, pro_inst.M, pro_inst.D, run_num));
    end
    prev_folder = fullfile('Data', algo_name);
    if isCombinatorial
        prev_file = fullfile(prev_folder, sprintf('%s_%s_M%d_D%d_ID%d_%d.mat', ...
            algo_name, prob_name, pro_inst.M, pro_inst.D, ID_i, run_num));
    else
        prev_file = fullfile(prev_folder, sprintf('%s_%s_M%d_D%d_%d.mat', ...
            algo_name, prob_name, pro_inst.M, pro_inst.D, run_num));
    end

    % Skip if already evaluated
    if isfile(prev_file)
        fprintf('Skipping (exists): %s with %s (Run %d)\n', prob_name, algo_name, run_num);
        return
    end

    % Prepare algorithm with heuristic path if needed
    algorithm_with_param = prepareAlgorithmForPlatemo(algorithmSpec, initial_pop_path);

    % Run platemo
    if isCombinatorial
        platemo('problem', problemHandle, 'N', N, 'M', M_i, 'D', D_i, ...
            'parameter', paramCell, ...
            'save', save_interval, 'maxFE', FE, ...
            'algorithm', algorithm_with_param, 'run', run_num);
    else
        platemo('problem', problemHandle, 'N', N, 'M', M_i, ...
            'save', save_interval, 'maxFE', FE, ...
            'algorithm', algorithm_with_param, 'run', run_num);
    end

    fprintf('Completed: %s with %s (Run %d)\n', prob_name, algo_name, run_num);
end

function val = getFieldDefault(s, field, default)
    if isfield(s, field)
        val = s.(field);
    else
        val = default;
    end
end
