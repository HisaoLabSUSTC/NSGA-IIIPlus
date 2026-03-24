function computeTimeMetrics(algorithms, problems, config, problemNames)
%COMPUTETIMEMETRICS Extract runtime metrics from raw benchmark data
%
%   computeTimeMetrics(algorithms, problems, config)
%   computeTimeMetrics(algorithms, problems, config, problemNames)
%
%   Reads metric.runtime from ./Data/ files (not TrimmedData) and saves
%   per-algorithm time maps in ./Info/FinalTime/.
%
%   Input:
%     algorithms    - Cell array of algorithm specs
%     problems      - Cell array of problem function handles
%     config        - Struct with fields:
%                       runs    - Number of runs (default: 5)
%                       dataDir - Raw data directory (default: './Data')
%     problemNames  - (optional) Cell array of pipeline names.
%                     Defaults to func2str of each handle.

    if nargin < 3
        config = struct();
    end
    runs = getFieldDefault(config, 'runs', 5);
    dataDir = getFieldDefault(config, 'dataDir', './Data');

    fprintf('=== Computing Time Metrics ===\n');

    % Get names
    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, 'UniformOutput', false);
    if nargin < 4 || isempty(problemNames)
        problemNames = cellfun(@func2str, problems, 'UniformOutput', false);
    end

    % Raw class names for file matching in processTimeMetric
    rawClassNames = cellfun(@func2str, problems, 'UniformOutput', false);

    numAlgorithms = numel(algorithmNames);
    numProblems = numel(problemNames);
    numPairs = numAlgorithms * numProblems;

    % Build pair lists
    pairAlgorithms = cell(1, numPairs);
    pairRawNames = cell(1, numPairs);
    pairPipelineNames = cell(1, numPairs);
    idx = 1;
    for i = 1:numAlgorithms
        for k = 1:numProblems
            pairAlgorithms{idx} = algorithmNames{i};
            pairRawNames{idx} = rawClassNames{k};
            pairPipelineNames{idx} = problemNames{k};
            idx = idx + 1;
        end
    end

    %% Setup intermediate directory
    intermediateTimeDir = './IntermediateTime';
    ensureDir(intermediateTimeDir);

    %% Progress tracking
    progressQueue = parallel.pool.DataQueue;
    startTime = tic;
    afterEach(progressQueue, @(data) progressCallback(data, numPairs, startTime));

    fprintf('Phase 1: Extracting runtimes for %d (algorithm, problem) pairs...\n', numPairs);

    %% Phase 1: Parallel time extraction
    parfor i = 1:numPairs
        alg = pairAlgorithms{i};
        rawName = pairRawNames{i};
        pipeName = pairPipelineNames{i};

        [timeValues, numRuns] = processTimeMetric(alg, rawName, dataDir, runs, pipeName);

        % Save intermediate results (use pipeline name for unique keys)
        outFile = fullfile(intermediateTimeDir, sprintf('%s_%s.mat', alg, pipeName));
        saveIntermediateMetric(outFile, timeValues, 'timeValues');

        send(progressQueue, struct('alg', alg, 'prob', pipeName, 'runs', numRuns));
    end

    fprintf('\nPhase 1 complete! Elapsed: %.1fs\n', toc(startTime));

    %% Phase 2: Collect intermediate results
    fprintf('Phase 2: Collecting results into final structure...\n');

    for i = 1:numAlgorithms
        alg = algorithmNames{i};
        prob2time = containers.Map();

        for k = 1:numProblems
            prob = problemNames{k};

            intermediateFile = fullfile(intermediateTimeDir, sprintf('%s_%s.mat', alg, prob));
            if exist(intermediateFile, 'file')
                data = load(intermediateFile);
                prob2time(prob) = data.timeValues;
            end
        end

        % Save final time result
        targetDir = sprintf('./Info/FinalTime/%s', alg);
        ensureDir(targetDir);
        save(fullfile(targetDir, 'prob2time.mat'), 'prob2time');
        fprintf('  Saved Time: %s\n', targetDir);
    end

    fprintf('\nAll done! Total time: %.1fs\n', toc(startTime));
    fprintf('=== Time metric extraction completed ===\n');
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
