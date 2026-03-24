function [timeValues, numRuns] = processTimeMetric(algorithmName, problemName, dataDir, runs, pipelineName)
%PROCESSTIMEMETRIC Extract runtime for one (algorithm, problem) pair
%   Reads metric.runtime from ./Data/{algName}/*.mat files.
%
%   Input:
%     algorithmName - String name of the algorithm
%     problemName   - String name of the problem class (e.g. 'MOTSP')
%     dataDir       - Directory with raw Data files (default: './Data')
%     runs          - Number of runs (pre-allocation size)
%     pipelineName  - (optional) Pipeline name for ID filtering (e.g. 'MOTSP_ID1')
%
%   Output:
%     timeValues    - 1 x numRuns array of runtimes in seconds
%     numRuns       - Actual number of runs processed

    if nargin < 5, pipelineName = problemName; end

    subdirPath = fullfile(dataDir, algorithmName);
    matFiles = dir(fullfile(subdirPath, '*.mat'));

    % Pre-allocate (will trim later)
    timeValues = zeros(1, runs);
    runIdx = 1;

    % Extract expected ID from pipelineName if present
    idTokens = regexp(pipelineName, '_ID(\d+)$', 'tokens');
    if ~isempty(idTokens)
        expectedID = str2double(idTokens{1}{1});
    else
        expectedID = NaN;
    end

    % Process only files matching this problem
    for j = 1:length(matFiles)
        % Parse: {Alg}_{Prob}_M{M}_D{D}[_ID{ID}]_{Run}.mat
        [~, fname, ~] = fileparts(matFiles(j).name);
        tokens = regexp(fname, '^.+?_(.+)_M(\d+)_D(\d+)_ID(\d+)_\d+$', 'tokens');
        if isempty(tokens)
            tokens = regexp(fname, '^.+?_(.+)_M(\d+)_D(\d+)_\d+$', 'tokens');
        end

        if isempty(tokens)
            continue
        end

        fileProblem = tokens{1}{1};
        if ~strcmp(fileProblem, problemName)
            continue
        end

        % Filter by ID for combinatorial problems
        if ~isnan(expectedID)
            if length(tokens{1}) < 4 || isempty(tokens{1}{4})
                continue
            end
            fileID = str2double(tokens{1}{4});
            if fileID ~= expectedID
                continue
            end
        end

        data = load(fullfile(subdirPath, matFiles(j).name), 'metric');
        if isfield(data, 'metric') && isfield(data.metric, 'runtime')
            timeValues(runIdx) = data.metric.runtime;
        else
            timeValues(runIdx) = NaN;
        end

        runIdx = runIdx + 1;
    end

    numRuns = runIdx - 1;
    timeValues = timeValues(1:numRuns);
end
