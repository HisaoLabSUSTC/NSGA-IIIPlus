function rerunCorruptedExperiments(algorithms, params, logPath, deleteCorrupted)
%RERUNCORRUPTEDEXPERIMENTS Re-run experiments that failed during trimming
%
%   rerunCorruptedExperiments(algorithms, params)
%   rerunCorruptedExperiments(algorithms, params, logPath)
%   rerunCorruptedExperiments(algorithms, params, logPath, deleteCorrupted)
%
%   Input:
%     algorithms      - Cell array of algorithm specs (same as used in runBenchmarks)
%     params          - Struct with fields: FE, N, M, runs (same as runBenchmarks)
%     logPath         - Path to error log (default: './Info/Logs/corrupted_files.mat')
%     deleteCorrupted - If true, delete corrupted files before re-running (default: true)
%
%   This function:
%     1. Reads the error log created by trimBenchmarkData
%     2. Deletes the corrupted .mat files (so runBenchmarks will regenerate them)
%     3. Groups experiments by algorithm and problem
%     4. Calls runBenchmarks for each affected algorithm-problem pair
%
%   Example:
%     algorithms = {generateAlgorithm(), generateAlgorithm('area1','ZY'), ...};
%     params = struct('FE', 100000, 'N', 120, 'M', 3, 'runs', 5);
%     rerunCorruptedExperiments(algorithms, params);

    if nargin < 3
        logPath = './Info/Logs/corrupted_files.mat';
    end
    if nargin < 4
        deleteCorrupted = true;
    end

    fprintf('=== Re-running Corrupted Experiments ===\n');

    %% Load error log
    if ~exist(logPath, 'file')
        fprintf('No error log found at: %s\n', logPath);
        fprintf('Nothing to re-run.\n');
        return;
    end

    data = load(logPath, 'errorLog');
    errorLog = data.errorLog;

    if isempty(errorLog)
        fprintf('Error log is empty. Nothing to re-run.\n');
        return;
    end

    fprintf('Found %d corrupted files in log\n', numel(errorLog));

    %% Build algorithm name to spec mapping
    algNameToSpec = containers.Map();
    for i = 1:numel(algorithms)
        algName = getAlgorithmName(algorithms{i});
        algNameToSpec(algName) = algorithms{i};
    end

    %% Group by algorithm and problem
    % Structure: algProblemRuns{algName}{problemName} = [runNumbers]
    algProblemRuns = containers.Map();

    for i = 1:numel(errorLog)
        entry = errorLog(i);
        algName = entry.algName;
        problemName = entry.problemName;
        runNumber = entry.runNumber;

        if ~isKey(algProblemRuns, algName)
            algProblemRuns(algName) = containers.Map();
        end

        probMap = algProblemRuns(algName);
        if ~isKey(probMap, problemName)
            probMap(problemName) = [];
        end
        probMap(problemName) = [probMap(problemName), runNumber];
        algProblemRuns(algName) = probMap;
    end

    %% Delete corrupted files
    if deleteCorrupted
        fprintf('\nDeleting corrupted files...\n');
        deletedCount = 0;
        for i = 1:numel(errorLog)
            filePath = errorLog(i).filePath;
            if exist(filePath, 'file')
                try
                    delete(filePath);
                    fprintf('  Deleted: %s\n', filePath);
                    deletedCount = deletedCount + 1;
                catch ME
                    fprintf('  [ERROR] Could not delete %s: %s\n', filePath, ME.message);
                end
            end
        end
        fprintf('Deleted %d corrupted files\n', deletedCount);
    end

    %% Re-run experiments
    algNames = keys(algProblemRuns);
    fprintf('\nRe-running experiments for %d algorithm(s)...\n', numel(algNames));

    totalRerun = 0;

    for a = 1:numel(algNames)
        algName = algNames{a};

        % Check if we have the algorithm spec
        if ~isKey(algNameToSpec, algName)
            fprintf('\n[WARNING] Algorithm "%s" not found in provided algorithms. Skipping.\n', algName);
            continue;
        end

        algSpec = algNameToSpec(algName);
        probMap = algProblemRuns(algName);
        problemNames = keys(probMap);

        fprintf('\n--- Algorithm: %s (%d problems) ---\n', algName, numel(problemNames));

        % Build problem handles, Mvec, Dvec, IDvec for this algorithm
        problemHandles = {};
        rerunMvec = [];
        rerunDvec = [];
        rerunIDvec = [];
        for p = 1:numel(problemNames)
            problemName = problemNames{p};
            runNumbers = probMap(problemName);

            fprintf('  Problem: %s (runs: %s)\n', problemName, mat2str(runNumbers));

            try
                % Extract class name and ID from pipeline name (e.g. 'MOTSP_ID1' -> 'MOTSP', 1)
                idTokens = regexp(problemName, '^(.+)_ID(\d+)$', 'tokens');
                if ~isempty(idTokens)
                    className = idTokens{1}{1};
                    probID = str2double(idTokens{1}{2});
                else
                    className = problemName;
                    probID = NaN;
                end
                problemHandle = str2func(className);
                problemHandles{end+1} = problemHandle; %#ok<AGROW>

                % Reconstruct M and D from error log entries for this problem
                entryM = params.M;  % default
                entryD = NaN;
                for ei = 1:numel(errorLog)
                    if strcmp(errorLog(ei).algName, algName) && strcmp(errorLog(ei).problemName, className)
                        entryM = errorLog(ei).M;
                        entryD = errorLog(ei).D;
                        if isfield(errorLog(ei), 'ID') && ~isnan(errorLog(ei).ID)
                            probID = errorLog(ei).ID;
                        end
                        break;
                    end
                end
                rerunMvec(end+1) = entryM; %#ok<AGROW>
                rerunDvec(end+1) = entryD; %#ok<AGROW>
                rerunIDvec(end+1) = probID; %#ok<AGROW>

                totalRerun = totalRerun + numel(runNumbers);
            catch
                fprintf('    [WARNING] Could not create handle for problem: %s\n', problemName);
            end
        end

        if isempty(problemHandles)
            fprintf('  No valid problems to re-run for this algorithm.\n');
            continue;
        end

        % Run benchmarks for this algorithm with affected problems
        % Note: runBenchmarks will only regenerate missing files
        fprintf('  Running benchmarks...\n');
        try
            runBenchmarks({algSpec}, problemHandles, params, rerunMvec, rerunDvec, rerunIDvec);
        catch ME
            fprintf('  [ERROR] runBenchmarks failed: %s\n', ME.message);
        end
    end

    fprintf('\n=== Re-run Summary ===\n');
    fprintf('Total experiments to re-run: %d\n', totalRerun);

    %% Clear the error log after successful re-run
    clearLog = input('Clear error log? (y/n): ', 's');
    if strcmpi(clearLog, 'y')
        if exist(logPath, 'file')
            delete(logPath);
            fprintf('Error log cleared.\n');
        end
    else
        fprintf('Error log kept at: %s\n', logPath);
    end

    fprintf('=== Re-run completed ===\n');
    fprintf('Run trimBenchmarkData again to process the regenerated files.\n');
end
