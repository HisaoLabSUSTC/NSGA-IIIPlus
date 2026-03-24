function runStabilityAnalysis(algorithmSpecs, problems, M, problemNames)
%RUNSTABILITYANALYSIS Run stability analysis for all algorithm-problem pairs
%
%   runStabilityAnalysis(algorithmSpecs, problems, M)
%   runStabilityAnalysis(algorithmSpecs, problems, M, problemNames)
%
%   Input:
%     algorithmSpecs - Cell array of algorithm specs (handles or config cells)
%     problems       - Cell array of problem function handles
%     M              - Number of objectives. Scalar (applied to all) or
%                      vector with one value per problem.
%     problemNames   - (optional) Cell array of pipeline names.
%                      Defaults to func2str of each handle.
%
%   This is the Task 6 wrapper that loops over all algorithms and problems
%   and calls processAlgorithmProblemPair for each pair.

    fprintf('=== Running Stability Analysis ===\n');

    % Expand scalar M to vector
    if isscalar(M)
        M = repmat(M, 1, numel(problems));
    end

    % Default pipeline names
    if nargin < 4 || isempty(problemNames)
        problemNames = cellfun(@func2str, problems, 'UniformOutput', false);
    end

    % Get algorithm names (supports both legacy handles and config-based)
    algorithmNames = cell(1, numel(algorithmSpecs));
    for i = 1:numel(algorithmSpecs)
        algorithmNames{i} = getAlgorithmName(algorithmSpecs{i});
    end

    for ai = 1:numel(algorithmSpecs)
        algorithmName = algorithmNames{ai};
        fprintf('\n========================================\n');
        fprintf('Processing Algorithm: %s\n', algorithmName);
        fprintf('========================================\n');

        % Create output directory
        statsDir = sprintf('./Info/StableStatistics/%s', algorithmName);
        if ~exist(statsDir, 'dir')
            mkdir(statsDir);
        end

        for pi = 1:numel(problems)
            problemHandle = problems{pi};
            pipeName = problemNames{pi};
            fprintf('\nProcessing %s on %s...\n', algorithmName, pipeName);
            processAlgorithmProblemPair(algorithmName, pipeName, problemHandle, statsDir, M(pi));
        end
    end

    fprintf('\n========================================\n');
    fprintf('Stability Analysis Complete!\n');
    fprintf('========================================\n');
end
