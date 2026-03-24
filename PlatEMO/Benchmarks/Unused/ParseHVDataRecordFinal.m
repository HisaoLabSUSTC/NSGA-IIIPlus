phs = {@DTLZ1, @DTLZ2, @IDTLZ1, @IDTLZ2, @WFG1, @WFG2, @RWA9};
pns = cellfun(@func2str, phs, 'UniformOutput', false);
hpns = {};

HVDir = './TrimmedData';
subdirs = dir(HVDir);
subdirs = subdirs([subdirs.isdir]);
subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));

algorithmNames = {subdirs.name};
numAlgorithms = length(algorithmNames);
numProblems = numel(pns);

M = 5;

%% Create all (algorithm, problem) pairs as parallel arrays
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
intermediateDir = './IntermediateHV';
if ~exist(intermediateDir, 'dir')
    mkdir(intermediateDir);
end

%% Set up pool
pool = gcp('nocreate');
if isempty(pool)
    fprintf('Starting parallel pool...\n');
    pool = parpool;
end
fprintf('Pool ready with %d workers.\n', pool.NumWorkers);

%% Progress tracking
progressQueue = parallel.pool.DataQueue;
startTime = tic;
afterEach(progressQueue, @(data) progressCallback(data, numPairs, startTime));

fprintf('Phase 1: Computing HV for %d (algorithm, problem) pairs...\n', numPairs);

%% Phase 1: Parallel HV computation per (algorithm, problem) pair
parfor i = 1:numPairs
    alg = pairAlgorithms{i};
    prob = pairProblems{i};
    
    [hvValues, numRuns] = processAlgorithmProblem(alg, prob, HVDir, hpns, M);
    
    % Save intermediate result
    outFile = fullfile(intermediateDir, sprintf('%s_%s.mat', alg, prob));
    saveIntermediate(outFile, hvValues);
    
    send(progressQueue, struct('alg', alg, 'prob', prob, 'runs', numRuns));
end

fprintf('\nPhase 1 complete! Elapsed: %.1fs\n', toc(startTime));

%% Phase 2: Collect intermediate results into final structure
fprintf('Phase 2: Collecting results...\n');

for i = 1:numAlgorithms
    alg = algorithmNames{i};
    prob2hv_map = containers.Map();
    
    for k = 1:numProblems
        prob = pns{k};
        intermediateFile = fullfile(intermediateDir, sprintf('%s_%s.mat', alg, prob));
        data = load(intermediateFile);
        prob2hv_map(prob) = data.hvValues;
    end
    
    % Save final result
    targetDir = sprintf('./Info/FinalHV/%s', alg);
    if ~exist(targetDir, 'dir')
        mkdir(targetDir);
    end
    save(fullfile(targetDir, 'prob2hv.mat'), 'prob2hv_map');
    fprintf('  Saved: %s\n', targetDir);
end

fprintf('\nAll done! Total time: %.1fs\n', toc(startTime));
fprintf('Intermediate files in: %s (can delete if not needed)\n', intermediateDir);

%% ============ Helper Functions ============

function [hvValues, numRuns] = processAlgorithmProblem(algorithmName, problemName, HVDir, hpns, M)
    subdirPath = fullfile(HVDir, algorithmName);
    matFiles = dir(fullfile(subdirPath, '*.mat'));
    
    % Pre-allocate (will trim later)
    hvValues = zeros(1, 101);
    runIdx = 1;
    
    % Get reference point once for this problem
    ph = str2func(problemName);
    Problem = ph('M', M);
    
    if ismember(problemName, hpns)
        ref = load(sprintf('./Info/ReferencePF/PF-%s.mat', problemName), 'PF').PF;
    else
        [~, ref] = GetPFnRef(Problem);
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
        
        hvValues(runIdx) = finalHV;
        runIdx = runIdx + 1;
    end
    
    numRuns = runIdx - 1;
    % Trim to actual size (keep full array if you need exactly 101 entries)
    % hvValues = hvValues(1:numRuns);
end

function saveIntermediate(filepath, hvValues)
    save(filepath, 'hvValues');
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