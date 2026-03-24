function generateApproximatePF(problemHandle, M, D, ID, varargin)
%GENERATEAPPROXIMATEPF Approximate the Pareto front by running multiple MOEAs.
%
%   generateApproximatePF(problemHandle, M, D, ID)
%   generateApproximatePF(problemHandle, M, D, ID, 'Name', Value, ...)
%
%   Runs several multi-objective algorithms (wH variants with heuristic
%   initialization) with an extended budget on a combinatorial problem
%   instance, pools their final populations, performs non-dominated sorting,
%   truncates to ~targetN points, and saves the result directly to
%   ./Info/ReferencePF/RefPF-{pipelineName}.mat.
%
%   This eliminates the intermediate .mat file that previously lived in the
%   problem's source directory (e.g. Real-world MOPs/), which caused race
%   conditions when multiple machines shared the same working directory.
%
%   Heuristic initialization:
%     Greedy solutions are generated (M+1 per run: one per axis + uniform
%     weight) using problem-specific solvers (greedy_motsp, greedy_mokp).
%     These are saved to a worker-local temporary .mat file and passed to
%     wH algorithm variants via the HID parameter.
%
%   Input (required):
%     problemHandle  - Function handle (e.g. @MOTSP, @MOKP)
%     M              - Number of objectives
%     D              - Number of decision variables (cities / items)
%     ID             - Instance identifier
%
%   Name-Value Parameters:
%     'algorithms'      - Cell array of algorithm handles (wH variants)
%                         Default: {@NSGAIIwH, @SMSEMOAwH, @MOEADwH, @SPEA2wH}
%     'N'               - Population size (default: 120)
%     'maxGenerations'  - Number of generations per run (default: 3000)
%     'runs'            - Independent runs per algorithm (default: 11)
%     'targetN'         - Target number of reference PF points (default: 3000)
%
%   Output:
%     Saves RefPF-{pipelineName}.mat (variable 'PF') directly to
%     ./Info/ReferencePF/.  No intermediate file is created.
%
%   Example:
%     generateApproximatePF(@MOTSP, 3, 12, 1)
%     generateApproximatePF(@MOTSP, 3, 100, 2, 'runs', 10, 'maxGenerations', 2000)

    p = inputParser;
    addParameter(p, 'algorithms', {@NSGAIIwH, @SMSEMOAwH, {@MOEADwH, 1}, @SPEA2wH}, @iscell);
    addParameter(p, 'N', 120, @isnumeric);
    addParameter(p, 'maxGenerations', 3000, @isnumeric);
    addParameter(p, 'runs', 11, @isnumeric);
    addParameter(p, 'targetN', 3000, @isnumeric);
    parse(p, varargin{:});

    algorithms = p.Results.algorithms;
    N = p.Results.N;
    maxFE = p.Results.maxGenerations * N;
    runs = p.Results.runs;
    targetN = p.Results.targetN;

    probName = func2str(problemHandle);
    pipelineName = sprintf('%s_ID%d', probName, ID);
    paramCell = buildCombinatorialParam(probName, ID);

    fprintf('=== Generating Approximate PF for %s ===\n', pipelineName);
    fprintf('  M=%d, D=%d, ID=%d\n', M, D, ID);
    fprintf('  Algorithms: %d, Runs: %d, maxFE: %d (= %d generations x %d)\n', ...
        numel(algorithms), runs, maxFE, p.Results.maxGenerations, N);
    fprintf('  Target reference PF size: %d\n', targetN);

    % Seed RNG for reproducible instance data (C/P/W matrices)
    rng(ID);
    pro_inst = problemHandle('M', M, 'D', D, 'parameter', paramCell);

    % Generate heuristic solutions and save to a worker-local temp file
    % Include PID to avoid collisions between machines/processes
    heuristicPath = generateHeuristicFile(probName, pro_inst, N);
    fprintf('  Heuristic solutions saved to: %s\n', heuristicPath);

    % Build all (algorithm, run) job pairs
    jobAlgSpecs = {};
    jobAlgNames = {};
    jobRunNums  = [];

    for a = 1:numel(algorithms)
        algHandle = algorithms{a};
        if iscell(algorithms{a})
            algName = func2str(algHandle{1});
        else
            algName = func2str(algHandle);
        end

        if exist(algName, 'file') ~= 2
            fprintf('  WARNING: Algorithm "%s" not found, skipping.\n', algName);
            continue;
        end

        algSpec = buildAlgSpec(algHandle, algName, heuristicPath);

        for r = 1:runs
            jobAlgSpecs{end+1} = algSpec;   %#ok<AGROW>
            jobAlgNames{end+1} = algName;   %#ok<AGROW>
            jobRunNums(end+1)  = r;         %#ok<AGROW>
        end
    end

    totalJobs = numel(jobAlgSpecs);
    fprintf('  Total jobs: %d (parallel)\n', totalJobs);

    % Run all jobs in parallel
    jobResults = cell(1, totalJobs);
    progressQueue = parallel.pool.DataQueue;
    startTime = tic;
    afterEach(progressQueue, @(d) reportProgress(d, totalJobs, startTime));

    parfor j = 1:totalJobs
        try
            [~, objs, ~] = platemo(...
                'algorithm', jobAlgSpecs{j}, ...
                'problem', problemHandle, ...
                'N', N, 'M', M, 'D', D, ...
                'parameter', paramCell, ...
                'maxFE', maxFE);

            jobResults{j} = objs;
            send(progressQueue, struct('idx', j, 'alg', jobAlgNames{j}, ...
                'run', jobRunNums(j), 'n', size(objs, 1)));
        catch ME
            jobResults{j} = [];
            send(progressQueue, struct('idx', j, 'alg', jobAlgNames{j}, ...
                'run', jobRunNums(j), 'n', -1));
            warning('generateApproximatePF:runFailed', ...
                'Job %d (%s run %d) failed: %s', ...
                j, jobAlgNames{j}, jobRunNums(j), ME.message);
        end
    end

    % Clean up temporary heuristic file
    if exist(heuristicPath, 'file')
        delete(heuristicPath);
    end

    % Concatenate all results
    allObj = vertcat(jobResults{~cellfun(@isempty, jobResults)});

    if isempty(allObj)
        fprintf('WARNING: No solutions collected. Approximate PF not saved.\n');
        return;
    end

    % Non-dominated sorting: keep rank-1 only
    fprintf('  Collected %d total solutions. Running NDSort ... ', size(allObj, 1));
    frontRank = NDSort(allObj, 1);
    PF = allObj(frontRank == 1, :);
    fprintf('%d non-dominated.\n', size(PF, 1));

    % Truncate to targetN if needed (preserve corners)
    if size(PF, 1) > targetN
        fprintf('  Truncating from %d to ~%d points (preserving corners) ... ', ...
            size(PF, 1), targetN);
        PF = truncateToTarget(PF, targetN);
        fprintf('%d points retained.\n', size(PF, 1));
    end

    % Save directly to ReferencePF directory
    outputDir = './Info/ReferencePF';
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    outFile = fullfile(outputDir, sprintf('RefPF-%s.mat', pipelineName));
    save(outFile, 'PF');

    fprintf('=== Saved %d points to %s ===\n', size(PF, 1), outFile);
end

%% ==================== Local Functions ====================

function PF = truncateToTarget(PF, targetN)
%TRUNCATETOTARGET Truncate PF to ~targetN points, preserving corner solutions.

    M = size(PF, 2);

    % Identify corner solutions (min on each objective)
    cornerIdx = zeros(M, 1);
    for j = 1:M
        [~, cornerIdx(j)] = min(PF(:, j));
    end
    cornerIdx = unique(cornerIdx);
    numCorners = numel(cornerIdx);

    % Separate corners from candidates
    allIdx = (1:size(PF, 1))';
    candidateIdx = setdiff(allIdx, cornerIdx);
    candidates = PF(candidateIdx, :);

    % Select remaining points uniformly via crowding distance
    numToSelect = targetN - numCorners;
    if numToSelect > 0 && size(candidates, 1) > numToSelect
        [selectedSubIdx, ~] = getLeastCrowdedPoints(candidates, numToSelect);
        selectedIdx = candidateIdx(selectedSubIdx);
    elseif numToSelect > 0
        selectedIdx = candidateIdx;
    else
        selectedIdx = [];
    end

    % Combine corners + selected
    finalIdx = [cornerIdx; selectedIdx];
    PF = PF(finalIdx, :);
end

function heuristicPath = generateHeuristicFile(probName, pro_inst, N)
%GENERATEHEURISTICFILE Generate greedy heuristic solutions and save to temp file.
%
%   Produces M+1 greedy solutions (one per axis + uniform weight) and pads
%   with random solutions to fill N rows. Saves as a temporary .mat file.
%   Uses PID in filename to avoid collisions between parallel processes
%   on shared filesystems.

    M = pro_inst.M;
    D = pro_inst.D;

    % Weight vectors: axis-aligned + uniform
    weight_vectors = [eye(M); ones(1, M) / M];
    nGreedy = size(weight_vectors, 1);

    heuristic_solutions = zeros(max(N, nGreedy), D);

    switch probName
        case 'MOTSP'
            C = pro_inst.C;
            for i = 1:nGreedy
                [p, ~] = greedy_motsp(C, weight_vectors(i, :));
                heuristic_solutions(i, :) = p;
            end
            % Fill remaining with random permutations
            for i = (nGreedy + 1):N
                heuristic_solutions(i, :) = randperm(D);
            end

        case 'MOKP'
            P = pro_inst.P;
            W = pro_inst.W;
            for i = 1:nGreedy
                [x, ~] = greedy_mokp(P, W, weight_vectors(i, :));
                heuristic_solutions(i, :) = x;
            end
            % Fill remaining with random binary vectors
            for i = (nGreedy + 1):N
                heuristic_solutions(i, :) = randi([0, 1], 1, D);
            end

        otherwise
            warning('generateApproximatePF:noGreedy', ...
                'No greedy solver for "%s"; using random initialization.', probName);
            Population = pro_inst.Initialization(N);
            heuristic_solutions = Population.decs;
    end

    heuristic_solutions = heuristic_solutions(1:N, :);

    % Save to temporary file with PID to avoid collisions on shared filesystems
    pid = feature('getpid');
    heuristicPath = fullfile(tempdir, sprintf('approxPF_heuristic_%s_pid%d.mat', probName, pid));
    save(heuristicPath, 'heuristic_solutions');
end

function algSpec = buildAlgSpec(algHandle, algName, heuristicPath)
%BUILDALGSPEC Build platemo algorithm spec with heuristic path for wH variants.
%
%   For wH algorithms, appends the heuristic file path as the HID parameter.
%   MOEADwH requires its 'type' parameter (default 1) before HID.
%   Non-wH algorithms are returned unchanged.

    if ~endsWith(algName, 'wH')
        % Not a wH variant: no heuristic initialization
        algSpec = algHandle;
        return;
    end

    if strcmp(algName, 'MOEADwH')
        % MOEADwH: [type, HID] = Algorithm.ParameterSet(1, "")
        algSpec = {algHandle{1}, algHandle{2}, heuristicPath};
    else
        % All other wH variants: [HID] = Algorithm.ParameterSet("")
        algSpec = {algHandle, heuristicPath};
    end
end

function reportProgress(d, totalJobs, startTime)
    elapsed = toc(startTime);
    if d.n >= 0
        fprintf('  [%d/%d] %s run %d: %d solutions (%.0fs)\n', ...
            d.idx, totalJobs, d.alg, d.run, d.n, elapsed);
    else
        fprintf('  [%d/%d] %s run %d: FAILED (%.0fs)\n', ...
            d.idx, totalJobs, d.alg, d.run, elapsed);
    end
end
