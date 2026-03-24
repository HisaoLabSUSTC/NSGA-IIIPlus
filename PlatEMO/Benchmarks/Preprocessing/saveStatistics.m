function saveStatistics(stats, statsDir, algorithmName, problemName, pointType)
%SAVESTATISTICS Save stability statistics to a .mat file
%
%   saveStatistics(stats, statsDir, algorithmName, problemName, pointType)
%
%   Input:
%     stats         - Struct with stability statistics
%     statsDir      - Output directory path
%     algorithmName - Name of the algorithm
%     problemName   - Name of the problem
%     pointType     - 'Ideal' or 'Nadir'
%
%   Output:
%     Saves file: SS-{pointType}-{algorithmName}-{problemName}.mat

    % Ensure directory exists
    if ~exist(statsDir, 'dir')
        mkdir(statsDir);
    end

    % Extract key statistics for saving
    stable_runs = stats.stable_runs;
    total_runs = stats.total_runs;
    stability_rate = stats.stability_rate;
    avg_stable_gen = stats.avg_stable_gen;
    cluster_radius_med = stats.cluster_radius_med;
    bias_L2 = stats.bias_L2;
    bias_L1 = stats.bias_L1;
    centroids = stats.centroids;
    center = stats.center;

    % Build filename
    fileName = sprintf('SS-%s-%s-%s.mat', pointType, algorithmName, problemName);
    filePath = fullfile(statsDir, fileName);

    % Save
    save(filePath, 'stable_runs', 'total_runs', 'stability_rate', ...
        'avg_stable_gen', 'cluster_radius_med', 'bias_L2', 'bias_L1', ...
        'centroids', 'center');

    fprintf('  Saved: %s\n', filePath);
end
