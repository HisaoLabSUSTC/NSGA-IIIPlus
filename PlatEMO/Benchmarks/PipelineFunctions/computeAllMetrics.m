function computeAllMetrics(algorithms, problems, config, Mvec, Dvec, IDvec, problemNames)
%COMPUTEALLMETRICS Precompute HV, IGD+, and Generalized Spread metrics
%
%   computeAllMetrics(algorithms, problems, config, Mvec)
%   computeAllMetrics(algorithms, problems, config, Mvec, Dvec, IDvec, problemNames)
%
%   Input:
%     algorithms    - Cell array of algorithm specs
%     problems      - Cell array of problem function handles
%     config        - Struct with fields:
%                       FE     - Maximum number of function evaluations
%                       M      - Default number of objectives
%                       N      - Number of solutions
%                       runs   - Number of runs
%     Mvec          - (optional) Numeric vector of M values, one per problem.
%                     If omitted, config.M is used for all problems.
%     Dvec          - (optional) Numeric vector of D values (NaN = auto).
%     IDvec         - (optional) Numeric vector of instance IDs (NaN = none).
%     problemNames  - (optional) Cell array of unique pipeline names.
%                     Defaults to func2str of each problem handle.

    if nargin < 3
        config = struct();
    end
    defaultM = getFieldDefault(config, 'M', 3);
    N = getFieldDefault(config, 'N', 120);
    runs = getFieldDefault(config, 'runs', 5);
    trimmedDir = getFieldDefault(config, 'trimmedDir', './TrimmedData');

    if nargin < 4 || isempty(Mvec)
        Mvec = repmat(defaultM, 1, numel(problems));
    end

    if nargin < 5 || isempty(Dvec)
        Dvec = nan(1, numel(problems));
    end

    if nargin < 6 || isempty(IDvec)
        IDvec = nan(1, numel(problems));
    end

    % Default pipeline names = raw class names
    if nargin < 7 || isempty(problemNames)
        problemNames = cellfun(@func2str, problems, 'UniformOutput', false);
    end

    % Raw class names (for file matching in processAlgorithmProblem)
    rawClassNames = cellfun(@func2str, problems, 'UniformOutput', false);

    fprintf('=== Computing HV, IGD+, and Generalized Spread Metrics ===\n');
    fprintf('  Continuous problems: normalized [0,1] space.\n');
    fprintf('  Combinatorial problems: HV only (original space).\n');

    % Get names
    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, 'UniformOutput', false);

    numAlgorithms = numel(algorithmNames);
    numProblems = numel(problemNames);
    numPairs = numAlgorithms * numProblems;

    % Build pair lists
    pairAlgorithms = cell(1, numPairs);
    pairRawNames = cell(1, numPairs);       % class names for file matching
    pairPipelineNames = cell(1, numPairs);  % unique pipeline names for keys
    pairM = zeros(1, numPairs);
    pairD = nan(1, numPairs);
    idx = 1;
    for i = 1:numAlgorithms
        for k = 1:numProblems
            pairAlgorithms{idx} = algorithmNames{i};
            pairRawNames{idx} = rawClassNames{k};
            pairPipelineNames{idx} = problemNames{k};
            pairM(idx) = Mvec(k);
            pairD(idx) = Dvec(k);
            idx = idx + 1;
        end
    end

    %% Setup intermediate directories
    intermediateHVDir = './IntermediateHV';
    intermediateIGDDir = './IntermediateIGDp';
    intermediateGenSpreadDir = './IntermediateGenSpread';
    ensureDir(intermediateHVDir);
    ensureDir(intermediateIGDDir);
    ensureDir(intermediateGenSpreadDir);

    %% Progress tracking
    progressQueue = parallel.pool.DataQueue;
    startTime = tic;
    afterEach(progressQueue, @(data) progressCallback(data, numPairs, startTime));

    fprintf('Phase 1: Computing metrics for %d (algorithm, problem) pairs...\n', numPairs);

    %% Phase 1: Parallel metric computation
    parfor i = 1:numPairs
        alg = pairAlgorithms{i};
        rawName = pairRawNames{i};
        pipeName = pairPipelineNames{i};
        M_i = pairM(i);
        D_i = pairD(i);

        [hvValues, igdValues, genSpreadValues, numRuns] = ...
            processAlgorithmProblem(alg, rawName, trimmedDir, M_i, N, runs, D_i, pipeName);

        % Save intermediate results (use pipeline name for unique keys)
        outHVFile = fullfile(intermediateHVDir, sprintf('%s_%s.mat', alg, pipeName));
        saveIntermediateMetric(outHVFile, hvValues, 'hvValues');

        outIGDFile = fullfile(intermediateIGDDir, sprintf('%s_%s.mat', alg, pipeName));
        saveIntermediateMetric(outIGDFile, igdValues, 'igdValues');

        outGenSpreadFile = fullfile(intermediateGenSpreadDir, sprintf('%s_%s.mat', alg, pipeName));
        saveIntermediateMetric(outGenSpreadFile, genSpreadValues, 'genSpreadValues');

        send(progressQueue, struct('alg', alg, 'prob', pipeName, 'runs', numRuns));
    end

    fprintf('\nPhase 1 complete! Elapsed: %.1fs\n', toc(startTime));

    %% Phase 2: Collect intermediate results
    fprintf('Phase 2: Collecting results into final structure...\n');

    for i = 1:numAlgorithms
        alg = algorithmNames{i};
        prob2hv_map = containers.Map();
        prob2igd = containers.Map();
        prob2genspread = containers.Map();

        for k = 1:numProblems
            prob = problemNames{k};

            % Load intermediate HV
            intermediateHVFile = fullfile(intermediateHVDir, sprintf('%s_%s.mat', alg, prob));
            if exist(intermediateHVFile, 'file')
                HVdata = load(intermediateHVFile);
                prob2hv_map(prob) = HVdata.hvValues;
            end

            % Load intermediate IGD
            intermediateIGDFile = fullfile(intermediateIGDDir, sprintf('%s_%s.mat', alg, prob));
            if exist(intermediateIGDFile, 'file')
                IGDdata = load(intermediateIGDFile);
                prob2igd(prob) = IGDdata.igdValues;
            end

            % Load intermediate Generalized Spread
            intermediateGenSpreadFile = fullfile(intermediateGenSpreadDir, sprintf('%s_%s.mat', alg, prob));
            if exist(intermediateGenSpreadFile, 'file')
                GenSpreaddata = load(intermediateGenSpreadFile);
                prob2genspread(prob) = GenSpreaddata.genSpreadValues;
            end
        end

        % Save final HV result
        targetHVDir = sprintf('./Info/FinalHV/%s', alg);
        ensureDir(targetHVDir);
        save(fullfile(targetHVDir, 'prob2hv.mat'), 'prob2hv_map');
        fprintf('  Saved HV: %s\n', targetHVDir);

        % Save final IGD result
        targetIGDDir = sprintf('./Info/FinalIGD/%s', alg);
        ensureDir(targetIGDDir);
        save(fullfile(targetIGDDir, 'prob2igdp.mat'), 'prob2igd');
        fprintf('  Saved IGD+: %s\n', targetIGDDir);

        % Save final Generalized Spread result
        targetGenSpreadDir = sprintf('./Info/FinalGenSpread/%s', alg);
        ensureDir(targetGenSpreadDir);
        save(fullfile(targetGenSpreadDir, 'prob2genspread.mat'), 'prob2genspread');
        fprintf('  Saved Generalized Spread: %s\n', targetGenSpreadDir);
    end

    fprintf('\nAll done! Total time: %.1fs\n', toc(startTime));
    fprintf('=== Metric computation completed ===\n');
end

function val = getFieldDefault(s, field, default)
    if isfield(s, field)
        val = s.(field);
    else
        val = default;
    end
end

function ensureDir(dirPath)
    if ~exist(dirPath, 'dir')
        mkdir(dirPath);
    end
end

function saveIntermediateMetric(filepath, values, varName)
    % Generic function to save intermediate metric values
    S = struct();
    S.(varName) = values;
    save(filepath, '-struct', 'S');
end

function progressCallback(data, total, startTime)
    persistent completed;
    if isempty(completed)
        completed = 0;
    end
    completed = completed + 1;
    elapsed = toc(startTime);
    avgTime = elapsed / completed;
    remaining = (total - completed) * avgTime;
    fprintf('  [%d/%d] %s - %s (%d runs) | ETA: %.0fs\n', ...
        completed, total, data.alg, data.prob, data.runs, remaining);
end
