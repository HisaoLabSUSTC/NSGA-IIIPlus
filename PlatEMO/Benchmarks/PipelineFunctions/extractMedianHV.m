function extractMedianHV(algorithmSpecs, problemNames, M, problemHandles, Dvec, IDvec)
%EXTRACTMEDIANHV Extract median HV runs for visualization
%
%   extractMedianHV(algorithmSpecs, problemNames, M)
%   extractMedianHV(algorithmSpecs, problemNames, M, problemHandles, Dvec, IDvec)
%
%   M can be a scalar (applied to all) or vector (one per problem).
%   problemNames are pipeline names (e.g. 'MOTSP_ID1').
%   For combinatorial problems, problemHandles/Dvec/IDvec are needed
%   to instantiate the problem and determine D.

    % Expand scalar M to vector
    if isscalar(M)
        M = repmat(M, 1, numel(problemNames));
    end

    if nargin < 4 || isempty(problemHandles)
        problemHandles = cellfun(@str2func, problemNames, 'UniformOutput', false);
    end

    if nargin < 5 || isempty(Dvec)
        Dvec = nan(1, numel(problemNames));
    end

    if nargin < 6 || isempty(IDvec)
        IDvec = nan(1, numel(problemNames));
    end

    rootDir = fullfile('./Info/FinalHV');
    outDir = fullfile('./Info/MedianHVResults');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    for ah = 1:numel(algorithmSpecs)
        algName = getAlgorithmName(algorithmSpecs{ah});

        prob2hvPath = fullfile(rootDir, algName, 'prob2hv.mat');
        if ~exist(prob2hvPath, 'file')
            warning('File "%s" does not exist. Skipped.', prob2hvPath);
            continue;
        end

        data = load(prob2hvPath);
        prob2hv_map = data.prob2hv_map;
        results = struct();

        for p = 1:numel(problemNames)
            prob = problemNames{p};
            M_p = M(p);
            ID_p = IDvec(p);
            fprintf("Processing %s - %s (%d/%d)\n", algName, prob, p, numel(problemNames));

            if ~isKey(prob2hv_map, prob)
                warning('No HV data for %s in %s. Skipped.', prob, algName);
                continue;
            end

            hvValues = prob2hv_map(prob);
            medHV = median(hvValues);
            [~, medianIdx] = min(abs(hvValues - medHV));

            % Instantiate problem to determine D
            ph = problemHandles{p};
            if ~isnan(ID_p)
                rawName = func2str(ph);
                paramCell = buildCombinatorialParam(rawName, ID_p);
                Problem = ph('M', M_p, 'D', Dvec(p), 'parameter', paramCell);
            else
                Problem = ph('M', M_p);
            end

            % Construct filename matching ALGORITHM.m output
            rawName = func2str(ph);
            if ~isnan(ID_p)
                medFile = sprintf('%s_%s_M%d_D%d_ID%d_%d.mat', algName, rawName, ...
                    Problem.M, Problem.D, ID_p, medianIdx);
            else
                medFile = sprintf('%s_%s_M%d_D%d_%d.mat', algName, rawName, ...
                    Problem.M, Problem.D, medianIdx);
            end

            fieldName = matlab.lang.makeValidName(prob);
            results.(fieldName).medianHV = medHV;
            results.(fieldName).medianIdx = medianIdx;
            results.(fieldName).allHV = hvValues;
            results.(fieldName).numRuns = numel(hvValues);
            results.(fieldName).medianFile = medFile;
        end

        outPath = fullfile(outDir, sprintf('MedianHV_%s.mat', algName));
        save(outPath, 'results');
        fprintf('Saved: %s\n', outPath);
    end
end
