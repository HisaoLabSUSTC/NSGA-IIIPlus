function stats = computeStabilityStatistics(norm_histories, type, M)
%COMPUTESTABILITYSTATISTICS Compute stability statistics from normalized histories
%
%   stats = computeStabilityStatistics(norm_histories, type, M)
%
%   Input:
%     norm_histories - Cell array of normalized trajectory matrices
%     type           - 'ideal' or 'nadir' (determines true point reference)
%     M              - Number of objectives
%
%   Output:
%     stats - Struct with stability statistics:
%       .stable_runs       - Number of runs that stabilized
%       .total_runs        - Total number of runs
%       .stability_rate    - Ratio of stable runs
%       .avg_stable_gen    - Average generation of stabilization
%       .centroids         - Estimated centroids from stable runs
%       .center            - Mean of centroids
%       .cluster_radius_*  - Clustering metrics (max, med, mean)
%       .bias_L2, .bias_L1 - Bias from true point
%       .spread_trace      - Trace of covariance
%       .spread_max_eig    - Maximum eigenvalue of covariance

    % Initialize
    stats = struct();
    stats.type = type;
    stats.M = M;

    % Detect stability for each run
    results = cellfun(@(c) detect_tail_stability(c, 'rel_max', 1e-6, 'min_tail_len', 30), ...
        norm_histories, 'UniformOutput', false);

    % Process stable runs
    stable_runs = 0;
    avg_stable_gen = 0;
    centroids = [];

    for ri = 1:numel(results)
        result = results{ri};
        if result.is_stable_max_rel == 1
            stable_gen = result.stable_gen_max_rel;
            estimated_centroid = mean(norm_histories{ri}(stable_gen:end,:), 1);
            stable_runs = stable_runs + 1;
            avg_stable_gen = avg_stable_gen + (stable_gen - avg_stable_gen) / stable_runs;
            centroids = [centroids; estimated_centroid]; %#ok<AGROW>
        end
    end

    stats.stable_runs = stable_runs;
    stats.total_runs = numel(results);
    stats.stability_rate = stable_runs / numel(results);
    stats.avg_stable_gen = avg_stable_gen;

    if stable_runs == 0
        stats.centroids = [];
        stats.center = [];
        stats.cluster_radius_max = NaN;
        stats.cluster_radius_med = NaN;
        stats.cluster_radius_mean = NaN;
        stats.bias_L2 = NaN;
        stats.bias_L1 = NaN;
        stats.spread_trace = NaN;
        stats.spread_max_eig = NaN;
        stats.covariance = [];
        stats.median_dist_idx = NaN;
        return;
    end

    % Compute spatial statistics
    [N, ~] = size(centroids);
    stats.centroids = centroids;
    stats.center = mean(centroids, 1);

    % True points in normalized space
    if strcmpi(type, 'ideal')
        true_point = zeros(1, M);
    else  % nadir
        true_point = ones(1, M);
    end

    % Cluster metrics
    d_center = vecnorm(centroids - stats.center, 2, 2);
    stats.cluster_radius_max = max(d_center);
    stats.cluster_radius_med = median(d_center);
    stats.cluster_radius_mean = mean(d_center);

    % Find the point closest to median distance
    [~, med_idx] = min(abs(d_center - stats.cluster_radius_med));
    stats.median_dist_idx = med_idx;

    % Bias metrics
    stats.bias_L2 = norm(stats.center - true_point, 2);
    stats.bias_L1 = mean(abs(stats.center - true_point));

    % Spread metrics (covariance-based)
    if N > 1
        C = cov(centroids, 1);
        stats.covariance = C;
        stats.spread_trace = trace(C);
        eigvals = eig(C);
        stats.spread_max_eig = max(eigvals);
    else
        stats.covariance = zeros(M);
        stats.spread_trace = 0;
        stats.spread_max_eig = 0;
    end
end
