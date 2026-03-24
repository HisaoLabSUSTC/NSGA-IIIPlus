%%%
% fileInfo contains:
% 'filepath': str -- Example: './Data/Alg/a.mat'
% 'algorithm': str -- Example: NSGA-III
% 'filename': str -- Example: 'a.mat'
% 'metricsFilepath': str -- Example: './AnytimeMetrics/Alg/AM_a.mat'
% 'shouldProcess': bool -- Example: false
%%%

function result = ProcessAnytimeMetricsOfOneFile(fileInfo)
    result = struct('success', false, 'metricsData', [], 'error', '');

    try
        % Load original data
        data = load(fileInfo.filepath);

        % Parse filename to get problem information
        parts = strsplit(fileInfo.filename, '_');
        if length(parts) < 5
            result.error = 'Invalid filename format';
            return;
        end

        problemName = parts{2};
        M = str2double(parts{3}(2:end));
        D = str2double(parts{4}(2:end));

        % Check for combinatorial ID field: ..._M3_D30_ID3_9.mat
        % parts{5} would be 'ID3' or the run number
        pipelineName = problemName;
        if length(parts) >= 6 && startsWith(parts{5}, 'ID')
            ID = str2double(parts{5}(3:end));
            pipelineName = sprintf('%s_ID%d', problemName, ID);
        end

        % Load reference PF and normalization bounds
        [PF, ideal, nadir] = loadReferencePF(pipelineName);
        range = nadir - ideal;
        range(range < 1e-12) = 1e-12;

        % Normalize PF to [0,1]
        PF_norm = (PF - ideal) ./ range;

        % HV reference point in normalized space
        ref = ones(1, M);

        % Compute all metrics for each generation
        resultData = data.result;
        numGenerations = size(resultData, 1);
        FE = zeros(numGenerations, 1);
        HVarray = zeros(numGenerations, 1);
        IGDparray = zeros(numGenerations, 1);
        GenSpreadVals = zeros(numGenerations, 1);
        avgCV = zeros(numGenerations, 1);
        feasibleCount = zeros(numGenerations, 1);

        for g = 1:numGenerations
            FE(g) = resultData{g, 1};
            Population = resultData{g, 2};

            % Constraint violation
            cons = Population.cons;
            cons(cons < 0) = 0;
            CV = sum(cons, 2);
            avgCV(g) = sum(CV) / numel(CV);

            % Get feasible population for metric computation
            feas_pop = GetFeasible(Population);
            objs = feas_pop.objs;

            if isempty(objs)
                HVarray(g) = 0;
                IGDparray(g) = inf;
                GenSpreadVals(g) = inf;
                feasibleCount(g) = 0;
                continue;
            end

            % Filter to non-dominated
            frontRank = NDSort(objs, 1);
            objs = objs(frontRank == 1, :);

            % Normalize to [0,1]
            objs_norm = (objs - ideal) ./ range;

            % Compute HV in normalized space
            valid = all(objs_norm < ref, 2);
            if any(valid)
                HVarray(g) = stk_dominatedhv(objs_norm(valid, :), ref);
            else
                HVarray(g) = 0;
            end

            % Compute IGD+ in normalized space
            IGDparray(g) = computeIGDp(objs_norm, PF_norm);

            % Compute Generalized Spread in normalized space
            GenSpreadVals(g) = computeGeneralizedSpread(objs_norm, PF_norm);

            feasibleCount(g) = size(objs, 1);
        end

        % Create structure to return
        metricsData = struct();
        metricsData.FE = FE;
        metricsData.HV = HVarray;
        metricsData.IGDp = IGDparray;
        metricsData.GenSpread = GenSpreadVals;
        metricsData.avgCV = avgCV;
        metricsData.feasibleCount = feasibleCount;
        metricsData.referencePoint = ref;
        metricsData.ideal = ideal;
        metricsData.nadir = nadir;
        metricsData.problemInfo = struct(...
            'algorithm', fileInfo.algorithm, ...
            'problemName', pipelineName, ...
            'M', M, ...
            'D', D, ...
            'originalFile', fileInfo.filename);

        fprintf("Processed: %s on %s\n", fileInfo.algorithm, pipelineName);
        metricsData.computationDate = datetime('now');

        result.metricsData = metricsData;
        result.success = true;

    catch ME
        result.error = ME.message;
        result.success = false;
    end
end

%% ==================== Metric Computations (Raw Matrices) ====================

function score = computeIGDp(popObj, PF)
    [Nr, M] = size(PF);
    N = size(popObj, 1);
    delta = zeros(Nr, 1);
    for i = 1:Nr
        delta(i) = min(sqrt(sum(max(popObj - repmat(PF(i,:), N, 1), ...
                              zeros(N, M)).^2, 2)));
    end
    score = mean(delta);
end

function score = computeGeneralizedSpread(popObj, PF)
%COMPUTEGENERALIZEDSPREAD Generalized Spread (Delta*) on normalized objectives.
    if size(popObj,2) ~= size(PF,2) || size(popObj,1) < 2
        score = inf;
        return;
    end
    [~, E] = max(PF, [], 1);
    extreme_S_star = PF(E, :);
    Dis = pdist2(PF, popObj, 'squaredeuclidean');
    d_X_S = min(Dis, [], 2);
    Dis_e = pdist2(extreme_S_star, popObj, 'squaredeuclidean');
    d_e_S = min(Dis_e, [], 2);
    sum_d_e_S = sum(d_e_S);
    d_bar = mean(d_X_S);
    numerator = sum_d_e_S + sum(abs(d_X_S - d_bar));
    denominator = sum_d_e_S + size(PF, 1) * d_bar;
    score = numerator / denominator;
end
