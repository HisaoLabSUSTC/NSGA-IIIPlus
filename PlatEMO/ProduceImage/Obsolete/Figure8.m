

algorithms = {@PyNSGAIIIwH};
algorithmNames = {'PyNSGAIIIwH'};

%% Main processing loop
for ai = 1:numel(algorithms)
    algorithmName = algorithmNames{ai};
    
    % Create output directories
    plotDir = './';
    if ~exist(plotDir, 'dir'), mkdir(plotDir); end
    
    ph = @VNT1;
    pn = func2str(ph);
        
    PublishPlot(algorithmName, pn, ph, plotDir);
end

fprintf('\n========================================\n');
fprintf('Analysis Complete!\n');
fprintf('========================================\n');

%% Main processing function
function PublishPlot(algorithmName, problemName, problemHandle, plotDir)
    % Load data
    dataDir = sprintf('./Info/IdealNadirHistory/%s', algorithmName);
    fileName = sprintf('IN-%s-%s.mat', algorithmName, problemName);
    filePath = fullfile(dataDir, fileName);
    
    if ~exist(filePath, 'file')
        fprintf('  Warning: File not found: %s\n', filePath);
        return;
    end
    
    fileData = load(filePath);
    idealHistories = fileData.ideal_history;
    nadirHistories = fileData.nadir_history;
    
    % Get ground truth
    % Problem = problemHandle(); M = Problem.M;
    M = 3;

    % PF = Problem.GetOptimum(1000);
    PF = load('./ProduceImage/VNT-PF.mat').PF;
    gt_ideal = min(PF);
    gt_nadir = max(PF);

    
    
    % Normalize histories
    norm_idealHistories = cellfun(@(c) (c-gt_ideal+eps)./(gt_nadir-gt_ideal+eps), ...
        idealHistories, 'UniformOutput', false);
    norm_nadirHistories = cellfun(@(c) (c-gt_ideal+eps)./(gt_nadir-gt_ideal+eps), ...
        nadirHistories, 'UniformOutput', false);
    
    % Detect stability and compute statistics
    ideal_stats = computeStabilityStatistics(norm_idealHistories, 'ideal', M);
    nadir_stats = computeStabilityStatistics(norm_nadirHistories, 'nadir', M);
    
    % Generate visualization
    generateSpatialPlot(ideal_stats, nadir_stats, M, plotDir, algorithmName, problemName);
    
    % Print summary
    printSummary(ideal_stats, nadir_stats, algorithmName, problemName);
end

%% Compute stability statistics
function stats = computeStabilityStatistics(norm_histories, type, M)
    % Initialize
    stats = struct();
    stats.type = type;
    stats.M = M;
    
    % Detect stability for each run
    % results = cellfun(@(c) detect_tail_stability(c, 'rel_max', 1e-6, 'min_tail_len', 30), ...
    %     norm_histories, 'UniformOutput', false);

    if strcmpi(type, 'ideal')
        results = load('./ProduceImage/VNT-Ideal.mat').results;
    else
        results = load('./ProduceImage/VNT-Nadir.mat').results;
    end
    
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
            centroids = [centroids; estimated_centroid];
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

%% Generate spatial stability plots (separate for ideal and nadir)
function generateSpatialPlot(ideal_stats, nadir_stats, M, plotDir, algorithmName, problemName)
    % Generate ideal point plot
    generateSinglePlot(ideal_stats, 'Ideal', M, plotDir, algorithmName, problemName, zeros(1, M));
    % return
    
    % Generate nadir point plot
    generateSinglePlot(nadir_stats, 'Nadir', M, plotDir, algorithmName, problemName, ones(1, M));
end

%% Generate a single stability plot
function generateSinglePlot(stats, pointType, M, plotDir, algorithmName, problemName, true_point)
    PreprocessProductionImage(1/2, 1.5, 8.8);

    fig=gcf;ax=gca;
    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); 

    plot3DStability(ax, stats, sprintf('%s Point', pointType), true_point, pointType);

    
    % Algorithm name formatting
    % dispAlgoName = algorithmName;
    % if strcmp(algorithmName, 'NSGAIIIwH')
    %     dispAlgoName = 'Pl-NSGA-III';
    % elseif strcmp(algorithmName, 'PyNSGAIIIwH')
    %     dispAlgoName = 'Py-NSGA-III';
    % end

    % Add title with proper positioning
    % title(ax, sprintf('%s on %s\n%s point', dispAlgoName, problemName, pointType), ...
    %     'Interpreter', 'none', 'FontSize', 18, 'FontWeight', 'bold');
    
    % Add stats textbox
    % addStatsTextbox(fig, stats, pointType);
    
    % Apply font enlargement
    % fc = struct();
    % fc.fontSize = 28;
    % fc.axesSize = 22;
    % fc.legendSize = 20;
    % EnlargeFont(fig, fc);
    % statsbox = findall(gcf, 'Tag', 'StatsTextbox');
    % statsbox.FontSize = 20;
    

    % Save figure
    % fileName = sprintf('SS-%s-%s-%s.png', pointType, dispAlgoName, problemName);
    % filePath = fullfile(plotDir, fileName);
    % saveas(fig, filePath);
    % close(fig);
end

%% 3D plotting function
function plot3DStability(ax, stats, label, true_point, pointType)
    axes(ax);
    hold on;
    grid on;
    box on;

    isIdeal = strcmpi(pointType, 'Ideal');
    if isIdeal
        mark = 'd';
        biasLabel = 'b_{*}';
    else
        mark = 's';
        biasLabel = 'b_{nad}';
    end
    
    % Plot true point - green filled diamond
    scatter3(true_point(1), true_point(2), true_point(3), ...
        400, ...
        'g', ...
        'Marker', mark, ...
        'MarkerFaceColor', 'green', ...
        'MarkerFaceAlpha', 0.7, ...
        'MarkerEdgeColor', [0 0.5 0], ...
        'LineWidth', 2, ...
        'DisplayName', sprintf('True %s', label));
    
    % For nadir point, add reference lines at [1,1,1]
    % if ~isIdeal
    %     % Draw dotted lines along each axis at the nadir point
    %     lineLen = stats.bias_L2;
    %     plot3([1-lineLen, 1+lineLen], [1, 1], [1, 1], '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5, 'HandleVisibility', 'off');
    %     plot3([1, 1], [1-lineLen, 1+lineLen], [1, 1], '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5, 'HandleVisibility', 'off');
    %     plot3([1, 1], [1, 1], [1-lineLen, 1+lineLen], '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5, 'HandleVisibility', 'off');
    % end
    
    if stats.stable_runs > 0
        % Define colors
        lightBlue = [0.4 0.7 1.0];
        salmon = [0.98 0.5 0.45];
        
        medIdx = stats.median_dist_idx;
        size(stats.centroids)
        medMask = true(1, size(stats.centroids, 1));


        medMask(medIdx) = false;
        centroids = stats.centroids(medMask,:);
        medPoint = stats.centroids(medIdx,:);
        % Plot centroids (larger size)
        scatter3(centroids(:,1), centroids(:,2), centroids(:,3), ...
            100, 'MarkerFaceColor', lightBlue, ...
            'MarkerFaceAlpha', 0.4, 'MarkerEdgeColor', 'none', 'LineWidth', 0.5);
        
        % Highlight median-distance point in light blue

        scatter3(medPoint(1), medPoint(2), medPoint(3), ...
            240, 'b', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 2.5);
        
        % Plot center as filled circle
        plot3(stats.center(1), stats.center(2), stats.center(3), 'o', ...
            'MarkerSize', 18, 'LineWidth', 2.5, ...
            'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k', ...
            'DisplayName', 'Spatial Center');
        
        % Draw gradient ray from center to median-distance point
        drawGradientRay3D(stats.center, stats.centroids(medIdx, :), 'r', 'b', 100);
        drawGradientRay3D(stats.center, true_point, 'r', 'g', 100);
        
        % Draw confidence ellipsoid and semiaxes if enough points
        if stats.stable_runs > 3 && ~isnan(stats.spread_trace)
            try
                drawEllipsoid3D(stats.center, stats.covariance, 2, 'r', 0.11);
                % drawSemiaxes3D(stats.center, stats.covariance, 2, salmon, 3);
            catch ME
                warning(ME.identifier, 'Ellipsoid could not be drawn: %s', ME.message);
            end
        end
    else
        text(0.5, 0.5, 0.5, 'No stable runs', 'Units', 'normalized', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
    end
    
    xlabel(sprintf('$\\tilde{z}_1$'), 'Interpreter', 'latex');
    ylabel(sprintf('$\\tilde{z}_2$'), 'Interpreter', 'latex');
    zlabel(sprintf('$\\tilde{z}_3$'), 'Interpreter', 'latex');

    legend_marker_size = 24;
    hI = plot3(ax, NaN, NaN, NaN, mark, ...
        'MarkerSize', legend_marker_size, ...
        'MarkerFaceColor', 'green', ...
        'MarkerEdgeColor', [0 0.5 0], 'LineWidth', 2);
    hT = plot3(ax, NaN, NaN, NaN, 'o', ...
        'MarkerSize', legend_marker_size-8, ...
        'MarkerFaceColor', min([1, 1, 1], lightBlue + [0.3, 0.2, 0]), 'MarkerEdgeColor', 'none', 'LineWidth', 1.5);
    hS = plot3(ax, NaN, NaN, NaN, 'o', ...
        'MarkerSize', legend_marker_size-2, ...
        'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k', 'LineWidth', 2.5);
    hE = patch(ax, NaN, NaN, 'r', ...
        'FaceColor', 'r', ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.2);
    hM = plot3(ax, NaN, NaN, NaN, 'o', ...
        'MarkerSize', legend_marker_size-2, ...
        'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'k', 'LineWidth', 2.5);
    hN1 = plot3(ax, NaN, NaN, NaN, 'o', ...
        'MarkerSize', legend_marker_size, ...
        'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'w');
    hN2 = plot3(ax, NaN, NaN, NaN, 'o', ...
        'MarkerSize', legend_marker_size, ...
        'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'w');
    hN3 = plot3(ax, NaN, NaN, NaN, 'o', ...
        'MarkerSize', legend_marker_size, ...
        'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'w');

    h_handles = [hI, hT, hS, hE, hM, hN1, hN2, hN3];
    string_numStable = sprintf("# Stable: %d/%d", stats.stable_runs, stats.total_runs);
    string_rhoMedian = sprintf("\\rho_{med}: %.3g", stats.cluster_radius_med);
    string_bias = sprintf("%s: %.3g", biasLabel, stats.bias_L2);
    h_labels = {sprintf('%s Point', pointType), 'Nadir Centroids', ...
        'Spatial Center', '2\sigma Ellipsoid', 'Median Centroid', ...
        string_numStable, ...
        string_rhoMedian, string_bias};

    

    leg = legend(ax, h_handles, h_labels);
    % set(leg, 'Box', 'off');
    
    view(45, 30);
    
    % Axis limits
    % setAxisLimits3D(ax, stats.centroids, true_point);
    
    % Lighting
    lighting(ax, 'gouraud');
    light('Position', [1 1 1], 'Style', 'infinite');
    light('Position', [-1 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);

    %% Customize plot attributes!
    % set(ax.Title, 'String', sprintf('Pl-NSGA-III\nat FE:%d', FE));
    set(ax, 'Position', [0.335 0.45 0.35 0.535])
    set(ax.Legend, 'NumColumns', 2);
    set(ax.Legend, 'Position', [0.16 0.135 0.7 0.085])

    if isIdeal
        lims = [-2 6]*1e-5;
        set(ax, 'XLim', lims);set(ax, 'YLim', lims);set(ax, 'ZLim', lims);
        ticks = [-2 2 6]*1e-5;
        set(ax, 'XTick', ticks);set(ax, 'YTick', ticks);set(ax, 'ZTick', ticks);
    else
        lims = [0.9 1.1];
        % set(ax, 'XLim', [0.95 1.05]);set(ax, 'YLim', [0.95 1.05]);set(ax, 'ZLim', [0.9 1.1]);
        set(ax, 'XLim', lims);set(ax, 'YLim', lims);set(ax, 'ZLim', lims);
        ticks = [0.9 1.0 1.1];
        set(ax, 'XTick', ticks);set(ax, 'YTick', ticks);set(ax, 'ZTick', ticks);
        % set(ax, 'XTick', [0.95 1.00 1.05]);
        % set(ax, 'YTick', [0.95 1.00 1.05]);
        % set(ax, 'ZTick', [0.90 1.00 1.10]);
    end

    
    
    % set(ax.Title, 'FontWeight','normal')
    set(ax, 'XTickLabelRotation', 0);
    set(ax, 'YTickLabelRotation', 0);
    set(ax, 'ZTickLabelRotation', 0);

    dist = lims(2)-lims(1);
    XLabelCoord = [lims(2)-dist/3.6, lims(1)-dist/1.7, lims(1)+dist/10];
    YLabelCoord = [lims(2)+dist/1.7, lims(1)+dist/3.6, lims(1)+dist/10];
    ZLabelCoord = [lims(1)-dist/4, lims(1)-dist/4, lims(1)+3*dist/10];
    set(ax.XLabel, 'Rotation', 0, 'Position', XLabelCoord)
    set(ax.YLabel, 'Rotation', 0, 'Position', YLabelCoord)
    set(ax.ZLabel, 'Rotation', 0, 'Position', ZLabelCoord)

    filename = sprintf('./SS-%s-Py-NSGA-III-VNT1.png', pointType);
    exportgraphics(gcf, filename, 'Resolution', 300);
end

function setAxisLimits3D(ax, centroids, true_point)
    % Combine all points to find the full extent of data + reference point
    all_data = [centroids; true_point];
    
    % Find the geometric center of the data cloud
    min_vals = min(all_data, [], 1);
    max_vals = max(all_data, [], 1);
    center = (min_vals + max_vals) / 2;
    
    % Find the maximum spread across any single dimension
    ranges = max_vals - min_vals;
    max_range = max(ranges);
    
    % Add padding (10% of the range)
    pad = max(max_range * 0.1, 0.05); 
    half_span = (max_range / 2) + pad;
    
    % Apply the same span to all axes relative to their specific centers
    xlim(ax, [center(1) - half_span, center(1) + half_span]);
    ylim(ax, [center(2) - half_span, center(2) + half_span]);
    zlim(ax, [center(3) - half_span, center(3) + half_span]);
    
    % Force equal unit scaling and freeze aspect ratio for rotation
    axis(ax, 'equal');
    axis(ax, 'vis3d'); 
    axis(ax, 'square'); 
    
    % Optional: Force the plot box specifically to be cubic
    pbaspect(ax, [1 1 1]); 
end


%% Draw gradient ray in 3D
function drawGradientRay3D(startPt, endPt, startColor, endColor, nSegments)
    if ischar(startColor), startColor = colorNameToRGB(startColor); end
    if ischar(endColor), endColor = colorNameToRGB(endColor); end
    
    t = linspace(0, 1, nSegments + 1);
    for i = 1:nSegments
        t1 = t(i); t2 = t(i+1);
        p1 = startPt + t1 * (endPt - startPt);
        p2 = startPt + t2 * (endPt - startPt);
        color = startColor + (t1 + t2)/2 * (endColor - startColor);
        plot3([p1(1), p2(1)], [p1(2), p2(2)], [p1(3), p2(3)], '-', ...
            'Color', color, 'LineWidth', 5, 'HandleVisibility', 'off');
    end
end

%% Draw semiaxes for 3D ellipsoid
function drawSemiaxes3D(center, C, nStd, color, lineWidth)
    [V, D] = eig(C);
    
    for i = 1:3
        eigval = D(i, i);
        if eigval < 0, continue; end
        
        semiaxis_len = sqrt(eigval) * nStd;
        direction = V(:, i)';
        
        endPt1 = center + semiaxis_len * direction;
        endPt2 = center - semiaxis_len * direction;
        
        plot3([endPt2(1), endPt1(1)], [endPt2(2), endPt1(2)], [endPt2(3), endPt1(3)], '-', ...
            'Color', color, 'LineWidth', lineWidth, 'HandleVisibility', 'off');
    end
end


%% Helper function to draw 3D ellipsoid
function drawEllipsoid3D(center, C, nStd, color, alpha)
    [x, y, z] = sphere(30);
    points = [x(:), y(:), z(:)]';
    
    [V, D] = eig(C);
    D(D < 0) = 0;  % Ensure non-negative
    transform = V * sqrt(D) * nStd;
    ellipsoid = transform * points;
    
    x_e = reshape(ellipsoid(1,:) + center(1), size(x));
    y_e = reshape(ellipsoid(2,:) + center(2), size(y));
    z_e = reshape(ellipsoid(3,:) + center(3), size(z));
    
    surf(x_e, y_e, z_e, 'FaceColor', color, 'EdgeColor', 'none', ...
        'FaceAlpha', alpha, 'DisplayName', sprintf('%d\\sigma Ellipsoid', nStd));
end


%% Convert color name to RGB
function rgb = colorNameToRGB(colorName)
    switch lower(colorName)
        case 'r', rgb = [1 0 0];
        case 'g', rgb = [0 1 0];
        case 'b', rgb = [0 0 1];
        case 'k', rgb = [0 0 0];
        case 'w', rgb = [1 1 1];
        case 'c', rgb = [0 1 1];
        case 'm', rgb = [1 0 1];
        case 'y', rgb = [1 1 0];
        otherwise, rgb = [0 0 0];
    end
end


%% Print summary
function printSummary(ideal_stats, nadir_stats, algorithmName, problemName)
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

%% Include the detect_tail_stability function
function result = detect_tail_stability(trajectory, varargin)
    p = inputParser;
    p.addParameter('max_abs',      1e-3, @(x) isempty(x) || isscalar(x));
    p.addParameter('rel_max',      1e-6, @(x) isempty(x) || (isscalar(x) && x > 0));
    p.addParameter('min_tail_len', 30, @(x) isscalar(x) && x >= 1);
    p.parse(varargin{:});

    max_abs      = p.Results.max_abs;
    rel_max      = p.Results.rel_max;
    min_tail_len = p.Results.min_tail_len;

    [T, M] = size(trajectory);

    if min_tail_len > T
        error('min_tail_len (%d) cannot exceed trajectory length T=%d.', min_tail_len, T);
    end

    X = trajectory;
    cs1 = zeros(T, M);
    cs2 = zeros(T, M);

    cs1(T, :) = X(T, :);
    cs2(T, :) = X(T, :).^2;
    for t = T-1:-1:1
        cs1(t, :) = cs1(t+1, :) + X(t, :);
        cs2(t, :) = cs2(t+1, :) + X(t, :).^2;
    end

    max_tail = zeros(T, 1);

    for t = 1:T
        n = T - t + 1;
        mu = cs1(t, :) / n;
        vals = X(t:T, :);
        diffs = vals - mu;
        d = vecnorm(diffs, 2, 2);
        max_tail(t) = max(d);
    end

    max_start = T - min_tail_len + 1;
    tail_mask = (1:T)' <= max_start;

    stable_gen_max_abs = NaN;
    is_stable_max_abs  = false;

    if ~isempty(max_abs)
        idx_max = find(max_tail <= max_abs & tail_mask, 1, 'first');
        if ~isempty(idx_max)
            stable_gen_max_abs = idx_max;
            is_stable_max_abs  = true;
        end
    end

    stable_gen_max_rel = NaN;
    is_stable_max_rel  = false;

    if ~isempty(rel_max)
        max0 = max_tail(1);

        if max0 <= max_abs
            stable_gen_max_rel = 1;
            is_stable_max_rel  = true;
        else
            thresh_max_rel = max(rel_max * max0, max_abs);
            idx_max_rel = find(max_tail <= thresh_max_rel & tail_mask, 1, 'first');
            if ~isempty(idx_max_rel)
                stable_gen_max_rel = idx_max_rel;
                is_stable_max_rel  = true;
            end
        end
    end

    result.max_tail            = max_tail;
    result.stable_gen_max_abs  = stable_gen_max_abs;
    result.is_stable_max_abs   = is_stable_max_abs;
    result.stable_gen_max_rel  = stable_gen_max_rel;
    result.is_stable_max_rel   = is_stable_max_rel;
end

