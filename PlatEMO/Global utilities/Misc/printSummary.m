function printSummary(ideal_stats, nadir_stats, algorithmName, problemName)
%PRINTSUMMARY Print summary of stability statistics
%
%   printSummary(ideal_stats, nadir_stats, algorithmName, problemName)
%
%   Input:
%     ideal_stats   - Stability statistics for ideal point
%     nadir_stats   - Stability statistics for nadir point
%     algorithmName - Name of the algorithm
%     problemName   - Name of the problem

    fprintf('\n  === %s on %s ===\n', algorithmName, problemName);

    fprintf('  Ideal Point:\n');
    if ideal_stats.stable_runs > 0
        fprintf('    Stable: %d/%d (%.1f%%)\n', ideal_stats.stable_runs, ...
            ideal_stats.total_runs, ideal_stats.stability_rate * 100);
        fprintf('    Avg Gen: %.1f, Bias L2: %.4g, Radius: %.4g\n', ...
            ideal_stats.avg_stable_gen, ideal_stats.bias_L2, ideal_stats.cluster_radius_med);
    else
        fprintf('    No stable runs\n');
    end

    fprintf('  Nadir Point:\n');
    if nadir_stats.stable_runs > 0
        fprintf('    Stable: %d/%d (%.1f%%)\n', nadir_stats.stable_runs, ...
            nadir_stats.total_runs, nadir_stats.stability_rate * 100);
        fprintf('    Avg Gen: %.1f, Bias L2: %.4g, Radius: %.4g\n', ...
            nadir_stats.avg_stable_gen, nadir_stats.bias_L2, nadir_stats.cluster_radius_med);
    else
        fprintf('    No stable runs\n');
    end
end
