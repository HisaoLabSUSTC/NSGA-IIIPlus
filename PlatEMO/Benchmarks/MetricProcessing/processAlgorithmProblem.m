function [hvValues, igdValues, genSpreadValues, numRuns] = processAlgorithmProblem(algorithmName, problemName, HVDir, M, N, runs, D, pipelineName)
%PROCESSALGORITHMPROBLEM Compute normalized HV, IGD+, Generalized Spread for one (algorithm, problem) pair.
%
%   All metrics are computed in normalized [0,1] objective space using the
%   true ideal and nadir points derived from the stored reference PF.
%
%   For combinatorial problems (no reference PF), only HV is computed using
%   the stored reference point from GetOptimum.  IGD+ and Generalized Spread
%   are returned as NaN.
%
%   Input:
%     algorithmName - String name of the algorithm
%     problemName   - String name of the problem class (e.g. 'MOTSP')
%     HVDir         - Directory with trimmed data
%     M             - Number of objectives
%     N             - Population size (for HV reference point)
%     runs          - Number of runs
%     D             - (optional) Decision variables for file filtering (NaN = ignore)
%     pipelineName  - (optional) Pipeline name for ref data lookup (default: problemName)
%
%   Output:
%     hvValues        - 1 x numRuns array of HV values
%     igdValues       - 1 x numRuns array of IGD+ values (NaN for combinatorial)
%     genSpreadValues - 1 x numRuns array of Generalized Spread values (NaN for combinatorial)
%     numRuns         - Actual number of runs processed

    if nargin < 7, D = NaN; end
    if nargin < 8, pipelineName = problemName; end

    subdirPath = fullfile(HVDir, algorithmName);
    matFiles = dir(fullfile(subdirPath, '*.mat'));

    % Pre-allocate (will trim later)
    hvValues = zeros(1, runs);
    igdValues = zeros(1, runs);
    genSpreadValues = zeros(1, runs);
    runIdx = 1;

    % Determine whether a reference PF is available
    refPFFile = fullfile('./Info/ReferencePF', sprintf('RefPF-%s.mat', pipelineName));
    hasPF = exist(refPFFile, 'file') == 2;

    if hasPF
        % --- Continuous problem: full metric suite in normalized space ---
        [PF, ideal, nadir] = loadReferencePF(pipelineName);
        range = nadir - ideal;
        range(range < 1e-12) = 1e-12;

        PF_norm = (PF - ideal) ./ range;

        % HV reference point: 1 + 1/H (Ishibuchi et al.)
        H = getRefH(M, N);
        ref = ones(1, M) + ones(1, M) ./ H;
    else
        % --- Combinatorial problem: HV only with stored reference point ---
        refPointFile = fullfile('./Info/ReferencePF', sprintf('RefPoint-%s.mat', pipelineName));
        if exist(refPointFile, 'file') == 2
            refData = load(refPointFile);
            ref = refData.refPoint;
        else
            warning('processAlgorithmProblem:noRefData', ...
                'No reference PF or point for "%s". Skipping.', pipelineName);
            numRuns = 0;
            return;
        end
    end

    % Extract instance ID from pipelineName if present (e.g. 'MOTSP_ID1' -> 1)
    idTokens = regexp(pipelineName, '_ID(\d+)$', 'tokens');
    if ~isempty(idTokens)
        expectedID = str2double(idTokens{1}{1});
    else
        expectedID = NaN;
    end

    % Process only files matching this problem (and D/ID if specified)
    for j = 1:length(matFiles)
        % Parse filename: {Alg}_{Prob}_M{M}_D{D}[_ID{ID}]_{Run}.mat
        [~, fname, ~] = fileparts(matFiles(j).name);
        tokens = regexp(fname, '^.+?_(.+)_M(\d+)_D(\d+)_ID(\d+)_\d+$', 'tokens');
        if isempty(tokens)
            tokens = regexp(fname, '^.+?_(.+)_M(\d+)_D(\d+)_\d+$', 'tokens');
        end

        if isempty(tokens)
            continue
        end

        fileProblem = tokens{1}{1};
        fileM = str2double(tokens{1}{2});
        fileD = str2double(tokens{1}{3});
        if length(tokens{1}) < 4 || isempty(tokens{1}{4})
            fileID = NaN;
        else
            fileID = str2double(tokens{1}{4});
        end

        if ~strcmp(fileProblem, problemName)
            continue
        end

        % Filter by M
        if fileM ~= M
            continue
        end

        % Filter by D for combinatorial problems
        if ~isnan(D) && fileD ~= D
            continue
        end

        % Filter by ID for combinatorial problems
        if ~isnan(expectedID)
            if isnan(fileID) || fileID ~= expectedID
                continue
            end
        end

        data = load(fullfile(subdirPath, matFiles(j).name)).finalPop;
        popObj = data.objs;

        % Filter to non-dominated solutions
        frontRank = NDSort(popObj, 1);
        popObj = popObj(frontRank == 1, :);

        if hasPF
            % Normalize population to [0,1]
            popObj_norm = (popObj - ideal) ./ range;

            % Compute all three metrics in normalized space
            hvValues(runIdx) = computeHV(popObj_norm, ref);
            igdValues(runIdx) = computeIGDp(popObj_norm, PF_norm);
            genSpreadValues(runIdx) = computeGeneralizedSpread(popObj_norm, PF_norm);
        else
            % Compute HV only in original objective space
            hvValues(runIdx) = computeHV(popObj, ref);
            igdValues(runIdx) = NaN;
            genSpreadValues(runIdx) = NaN;
        end

        runIdx = runIdx + 1;
    end

    numRuns = runIdx - 1;
end

%% ==================== Metric Computations (Raw Matrices) ====================

function hv = computeHV(popObj, ref)
%COMPUTEHV Hypervolume indicator.
    if isempty(popObj)
        hv = 0;
        return;
    end
    % Clip objectives that exceed the reference point
    valid = all(popObj < ref, 2);
    if ~any(valid)
        hv = 0;
        return;
    end
    hv = stk_dominatedhv(popObj(valid, :), ref);
end

function score = computeIGDp(popObj, PF)
%COMPUTEIGDP Inverted Generational Distance Plus on normalized objectives.
    if size(popObj,2) ~= size(PF,2)
        score = nan;
    else
        [Nr,M] = size(PF);
        [N,~]  = size(popObj);
        delta  = zeros(Nr,1);
        for i = 1 : Nr
            delta(i) = min(sqrt(sum(max(popObj - repmat(PF(i,:),N,1),zeros(N,M)).^2,2)));
        end
        score = mean(delta);
    end
end

function score = computeGeneralizedSpread(PopObj, optimum)
%COMPUTEGENERALIZEDSPREAD Generalized Spread (Delta*) on normalized objectives.
%   Based on Zhou et al. (2006), uses squared Euclidean distances.
    if size(PopObj,2) ~= size(optimum,2)
        score = nan;
    else
        % Find extreme solutions in the reference PF
        [~, E] = max(optimum, [], 1);
        extreme_S_star = optimum(E, :);

        % Squared Euclidean distances from each PF point to nearest solution
        Dis = pdist2(optimum, PopObj, 'squaredeuclidean');
        d_X_S = min(Dis, [], 2);

        % Distances from extreme PF points to nearest solution
        Dis_e = pdist2(extreme_S_star, PopObj, 'squaredeuclidean');
        d_e_S = min(Dis_e, [], 2);
        sum_d_e_S = sum(d_e_S);

        % Mean distance
        d_bar = mean(d_X_S);

        % Generalized Spread
        numerator = sum_d_e_S + sum(abs(d_X_S - d_bar));
        denominator = sum_d_e_S + size(optimum, 1) * d_bar;
        score = numerator / denominator;
    end
end
