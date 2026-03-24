%% Comprehensive Spatial Stability Analysis for Multi-Objective Optimization
% This script analyzes temporal stability results and generates:
% 1. Statistical summaries saved as .mat files
% 2. Spatial stability visualization plots
%
% Author: Ken
% Date: December 2024

% clear; clc; close all;

%% Define all problems and algorithms
% problems = {@MinusWFG1,@MinusWFG2,@MinusWFG3,@MinusWFG4,@MinusWFG5,@MinusWFG6,@MinusWFG7,@MinusWFG8,@MinusWFG9,...
%     @RWA1,@RWA2,


% problems = {@MinusWFG1,@MinusWFG2,@MinusWFG3,@MinusWFG4,@MinusWFG5,@MinusWFG6,@MinusWFG7,@MinusWFG8,@MinusWFG9,...
%     @RWA1,@RWA2,@RWA3,@RWA4,@RWA5,@RWA6,@RWA7, @VNT1, @VNT2, @VNT3,...
%     @WFG1,@WFG2,@WFG3,@WFG4,@WFG5,@WFG6,@WFG7,@WFG8,@WFG9,@ZDT1,@ZDT2,@ZDT3,@ZDT4,@ZDT6, ...
%     @BT1, @BT2, @BT3, @BT4, @BT5, @BT6, @BT7, @BT8, @BT9, ...
%     @DTLZ1, @DTLZ2, @DTLZ3, @DTLZ4, @DTLZ5, @DTLZ6, @DTLZ7, @IDTLZ1, @IDTLZ2, ...
%     @SDTLZ1, @SDTLZ2, @IMOP1, @IMOP2, @IMOP3, @IMOP4, @IMOP5, @IMOP6, @IMOP7, @IMOP8, ...
%     @MaF1,@MaF2,@MaF3,@MaF4,@MaF5, @MaF13,@MaF14,@MaF15,...
%     @UF1, @UF2, @UF3, @UF4, @UF5, @UF6, @UF7, @UF8, @UF9, @UF10, ...
%     @MinusDTLZ1,@MinusDTLZ2,@MinusDTLZ3,@MinusDTLZ4,@MinusDTLZ5,@MinusDTLZ6};

% problems = {@UF1, @UF2, @UF3, @UF4, @UF5, @UF6, @UF7, @UF8, @UF9, @UF10, ...
    % @MaF10, @MaF11, @MaF12, @MaF13,@MaF14, @MaF15};
% problems = {@ZDT1};
problems = {@DTLZ1, @DTLZ2, @IDTLZ1, @IDTLZ2, @WFG1, @WFG2, @RWA9};
algorithms = {@PyNSGAIIIwH, @NSGAIIIwH};
algorithmNames = {'PyNSGAIIIwH', 'NSGAIIIwH'};
% algorithms = {@PyNSGAIIIwH};
% algorithmNames = {'PyNSGAIIIwH'};

%% Main processing loop
for ai = 1:numel(algorithms)
    algorithmName = algorithmNames{ai};
    fprintf('\n========================================\n');
    fprintf('Processing Algorithm: %s\n', algorithmName);
    fprintf('========================================\n');
    
    % Create output directories
    statsDir = sprintf('./Info/StableStatistics/%s', algorithmName);
    plotDir = './Info/SpatialStabilityPlot';
    if ~exist(statsDir, 'dir'), mkdir(statsDir); end
    if ~exist(plotDir, 'dir'), mkdir(plotDir); end
    
    for pi = 1:numel(problems)
        problemHandle = problems{pi};
        problemName = func2str(problemHandle);
        
        fprintf('\nProcessing %s on %s...\n', algorithmName, problemName);
        
        processAlgorithmProblemPair(algorithmName, problemName, problemHandle, statsDir, plotDir);
    end
end

fprintf('\n========================================\n');
fprintf('Analysis Complete!\n');
fprintf('========================================\n');

%% Main processing function
function processAlgorithmProblemPair(algorithmName, problemName, problemHandle, statsDir, plotDir)
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
    Problem = problemHandle('M', 5);
    PF = Problem.GetOptimum(1000);
    gt_ideal = min(PF);
    gt_nadir = max(PF);

    M = Problem.M;  % Number of objectives
    
    % Normalize histories
    norm_idealHistories = cellfun(@(c) (c-gt_ideal+eps)./(gt_nadir-gt_ideal+eps), ...
        idealHistories, 'UniformOutput', false);
    norm_nadirHistories = cellfun(@(c) (c-gt_ideal+eps)./(gt_nadir-gt_ideal+eps), ...
        nadirHistories, 'UniformOutput', false);
    
    % Detect stability and compute statistics
    ideal_stats = computeStabilityStatistics(norm_idealHistories, 'ideal', M);
    nadir_stats = computeStabilityStatistics(norm_nadirHistories, 'nadir', M);

    % Save statistics
    saveStatistics(ideal_stats, statsDir, algorithmName, problemName, 'Ideal');
    saveStatistics(nadir_stats, statsDir, algorithmName, problemName, 'Nadir');
    
    % Generate visualization
    % generateSpatialPlot(ideal_stats, nadir_stats, M, plotDir, algorithmName, problemName);
    
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
    
    % Generate nadir point plot
    generateSinglePlot(nadir_stats, 'Nadir', M, plotDir, algorithmName, problemName, ones(1, M));
end

%% Generate a single stability plot
function generateSinglePlot(stats, pointType, M, plotDir, algorithmName, problemName, true_point)
    % Create figure with better proportions
    fig = figure('Position', [50, 20, 1000, 1000], 'Visible', 'on');
    
    % Create axes with controlled position (leave room for legend and textbox on right)
    ax = axes('Position', [0.100 0.1000 0.8500 0.8000]);
    
    % Plot based on dimensionality
    if M == 2
        plot2DStability(ax, stats, sprintf('%s Point', pointType), true_point, pointType);
    elseif M == 3
        plot3DStability(ax, stats, sprintf('%s Point', pointType), true_point, pointType);
    else
        plotPCAStability(ax, stats, sprintf('%s Point', pointType), true_point, pointType);
    end
    
    % Algorithm name formatting
    dispAlgoName = algorithmName;
    if strcmp(algorithmName, 'NSGAIIIwH')
        dispAlgoName = 'Pl-NSGA-III';
    elseif strcmp(algorithmName, 'PyNSGAIIIwH')
        dispAlgoName = 'Py-NSGA-III';
    end

    % Add title with proper positioning
    title(ax, sprintf('%s on %s\n%s point', dispAlgoName, problemName, pointType), ...
        'Interpreter', 'none', 'FontSize', 18, 'FontWeight', 'bold');
    
    % Add stats textbox
    addStatsTextbox(fig, stats, pointType);
    
    % Apply font enlargement
    fc = struct();
    fc.fontSize = 28;
    fc.axesSize = 22;
    fc.legendSize = 20;
    EnlargeFont(fig, fc);
    statsbox = findall(gcf, 'Tag', 'StatsTextbox');
    statsbox.FontSize = 20;
    
    %% HARD FIX FOR 3D
    ax.OuterPosition = [-0.04258064516129,-0.007975460122699,1.096774193548387,0.98159509202454];
    ax.InnerPosition = [0.1,0.1,0.85,0.8];
    ax.PositionConstraint = 'innerposition';
    ax.View = [45, 30];
    ax.CameraViewAngle = 10.395086052710406;

    % Save figure
    fileName = sprintf('SS-%s-%s-%s.png', pointType, dispAlgoName, problemName);
    filePath = fullfile(plotDir, fileName);
    saveas(fig, filePath);
    close(fig);
end

%% 2D plotting function
function plot2DStability(ax, stats, label, true_point, pointType)
    axes(ax);
    hold on;
    grid on;
    box on;
    
    isIdeal = strcmpi(pointType, 'Ideal');
    
    % Plot true point - green filled diamond
    if isIdeal
        mark = 'd';
    else
        mark = 's';
    end

    scatter(true_point(1), true_point(2), ...
        400, ...
        'g', ...
        'Marker', mark, ...
        'MarkerFaceColor', 'green', ...
        'MarkerFaceAlpha', 0.7, ...
        'MarkerEdgeColor', [0 0.5 0], ...
        'LineWidth', 2, ...
        'DisplayName', sprintf('True %s', label));
    
    % For nadir point, add reference lines at [1,1]
    if ~isIdeal
        xline(1, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5, 'HandleVisibility', 'off');
        yline(1, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5, 'HandleVisibility', 'off');
    end
    
    if stats.stable_runs > 0
        % Define colors
        lightBlue = [0.4 0.7 1.0];
        salmon = [0.98 0.5 0.45];
        
        % Plot centroids (larger size)
        scatter(stats.centroids(:,1), stats.centroids(:,2), 60, 'b', 'filled', ...
            'MarkerFaceAlpha', 0.7, 'DisplayName', 'Temporally Stable Estimates');
        
        % Highlight median-distance point in light blue
        medIdx = stats.median_dist_idx;
        scatter(stats.centroids(medIdx, 1), stats.centroids(medIdx, 2), 150, ...
            lightBlue, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5, ...
            'DisplayName', 'Median-Distance Point');
        
        % Plot center as filled circle
        plot(stats.center(1), stats.center(2), 'o', ...
            'MarkerSize', 12, 'LineWidth', 2, ...
            'MarkerFaceColor', 'r', 'MarkerEdgeColor', [0.5 0 0], ...
            'DisplayName', 'Spatial Center');
        
        % Draw gradient ray from center to median-distance point
        drawGradientRay2D(stats.center, stats.centroids(medIdx, :), 'r', lightBlue, 50);
        
        % Draw confidence ellipse and semiaxes if enough points
        if stats.stable_runs > 2 && ~isnan(stats.spread_trace)
            try
                drawEllipse2D(stats.center, stats.covariance, 2, 'r-', 2);
                % drawSemiaxes2D(stats.center, stats.covariance, 2, salmon, 2.5);
            catch ME
                warning(ME.identifier, 'Ellipse could not be drawn: %s', ME.message);
            end
        end
    else
        text(0.5, 0.5, 'No stable runs', 'Units', 'normalized', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
    end
    
    xlabel('$f_1$', 'Interpreter', 'latex');
    ylabel('$f_2$', 'Interpreter', 'latex');
    leg = legend('Location', 'northeast');
    % set(leg, 'Box', 'off');
    
    % Axis limits
    setAxisLimits2D(ax, isIdeal, true_point);
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
    else
        mark = 's';
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
    if ~isIdeal
        % Draw dotted lines along each axis at the nadir point
        lineLen = stats.bias_L2;
        plot3([1-lineLen, 1+lineLen], [1, 1], [1, 1], '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5, 'HandleVisibility', 'off');
        plot3([1, 1], [1-lineLen, 1+lineLen], [1, 1], '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5, 'HandleVisibility', 'off');
        plot3([1, 1], [1, 1], [1-lineLen, 1+lineLen], '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5, 'HandleVisibility', 'off');
    end
    
    if stats.stable_runs > 0
        % Define colors
        lightBlue = [0.4 0.7 1.0];
        salmon = [0.98 0.5 0.45];
        
        % Plot centroids (larger size)
        scatter3(stats.centroids(:,1), stats.centroids(:,2), stats.centroids(:,3), ...
            60, 'b', 'filled', 'MarkerFaceAlpha', 0.7, 'DisplayName', 'Temporally Stable Estimates');
        
        % Highlight median-distance point in light blue
        medIdx = stats.median_dist_idx;
        scatter3(stats.centroids(medIdx, 1), stats.centroids(medIdx, 2), stats.centroids(medIdx, 3), ...
            180, lightBlue, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5, ...
            'DisplayName', 'Median-Distance Point');
        
        % Plot center as filled circle
        plot3(stats.center(1), stats.center(2), stats.center(3), 'o', ...
            'MarkerSize', 12, 'LineWidth', 2, ...
            'MarkerFaceColor', 'r', 'MarkerEdgeColor', [0.5 0 0], ...
            'DisplayName', 'Spatial Center');
        
        % Draw gradient ray from center to median-distance point
        drawGradientRay3D(stats.center, stats.centroids(medIdx, :), 'r', lightBlue, 50);
        
        % Draw confidence ellipsoid and semiaxes if enough points
        if stats.stable_runs > 3 && ~isnan(stats.spread_trace)
            try
                drawEllipsoid3D(stats.center, stats.covariance, 2, 'r', 0.12);
                % drawSemiaxes3D(stats.center, stats.covariance, 2, salmon, 3);
            catch ME
                warning(ME.identifier, 'Ellipsoid could not be drawn: %s', ME.message);
            end
        end
    else
        text(0.5, 0.5, 0.5, 'No stable runs', 'Units', 'normalized', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
    end

    xlabel('$f_1$', 'Interpreter', 'latex');
    ylabel('$f_2$', 'Interpreter', 'latex');
    zlabel('$f_3$', 'Interpreter', 'latex');
    leg = legend('Location', 'north');
    % set(leg, 'Box', 'off');
    
    view(45, 30);
    
    % Axis limits
    setAxisLimits3D(ax, stats.centroids, true_point);
    
    % Lighting
    lighting(ax, 'gouraud');
    light('Position', [1 1 1], 'Style', 'infinite');
    light('Position', [-1 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);
end

%% PCA plotting function for high-dimensional cases
function plotPCAStability(ax, stats, label, true_point, pointType)
    axes(ax);
    hold on;
    grid on;
    box on;
    
    isIdeal = strcmpi(pointType, 'Ideal');
    if isIdeal
        mark = 'd';
    else
        mark = 's';
    end
    
    if stats.stable_runs > 0
        lightBlue = [0.4 0.7 1.0];
        
        % Perform PCA
        centroids_centered = stats.centroids - mean(stats.centroids, 1);
        [coeff, score, ~, ~, explained] = pca(centroids_centered);
        
        % Project true point and center
        true_proj = (true_point - mean(stats.centroids, 1)) * coeff(:, 1:2);
        center_proj = (stats.center - mean(stats.centroids, 1)) * coeff(:, 1:2);
        medIdx = stats.median_dist_idx;
        med_proj = score(medIdx, 1:2);
        
        % Plot stable estimates
        scatter(score(:,1), score(:,2), 60, 'b', 'filled', ...
            'MarkerFaceAlpha', 0.7, 'DisplayName', 'Temporally Stable Estimates');
        
        % Highlight median-distance point
        scatter(med_proj(1), med_proj(2), 150, lightBlue, 'filled', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1.5, 'DisplayName', 'Median-Distance Point');
        
        % Plot center
        plot(center_proj(1), center_proj(2), 'o', 'MarkerSize', 12, 'LineWidth', 2, ...
            'MarkerFaceColor', 'r', 'MarkerEdgeColor', [0.5 0 0], 'DisplayName', 'Spatial Center');
        
        % Plot true point
        scatter(true_proj(1), true_proj(2), 400, 'g', mark, 'filled', ...
            'MarkerFaceAlpha', 0.7, 'MarkerEdgeColor', [0 0.5 0], 'LineWidth', 2, ...
            'DisplayName', sprintf('True %s', label));
        
        % Draw gradient ray
        drawGradientRay2D(center_proj, med_proj, 'r', lightBlue, 50);
        
        xlabel(sprintf('PC1 (%.1f%%)', explained(1)));
        ylabel(sprintf('PC2 (%.1f%%)', explained(2)));
    else
        text(0.5, 0.5, sprintf('No stable runs\n(M=%d)', stats.M), ...
            'Units', 'normalized', 'HorizontalAlignment', 'center', 'FontSize', 14);
    end
    
    leg = legend('Location', 'north');
    % set(leg, 'Box', 'off');
    axis equal;
end

%% Set axis limits for 2D
function setAxisLimits2D(ax, isIdeal, true_point)
    children = ax.Children;
    allX = []; allY = [];
    
    for h = reshape(children, 1, [])
        if isprop(h, 'XData')
            allX = [allX; get(h, 'XData')'];
            allY = [allY; get(h, 'YData')'];
        end
    end
    
    allX = allX(~isnan(allX));
    allY = allY(~isnan(allY));
    
    if isempty(allX), return; end
    
    if isIdeal
        % Force lower bound at origin
        minX = 0; minY = 0;
        maxX = max(allX); maxY = max(allY);
    else
        minX = min(allX); maxX = max(allX);
        minY = min(allY); maxY = max(allY);
    end
    
    rangeX = maxX - minX;
    rangeY = maxY - minY;
    maxRange = max([rangeX, rangeY]);
    pad = max(0.08 * maxRange, 0.02);
    
    if isIdeal
        xlim(ax, [minX - pad*0.2, maxX + pad]);
        ylim(ax, [minY - pad*0.2, maxY + pad]);
    else
        xlim(ax, [minX - pad, maxX + pad]);
        ylim(ax, [minY - pad, maxY + pad]);
    end
    
    axis equal;
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

%% Draw gradient ray in 2D
function drawGradientRay2D(startPt, endPt, startColor, endColor, nSegments)
    if ischar(startColor), startColor = colorNameToRGB(startColor); end
    if ischar(endColor), endColor = colorNameToRGB(endColor); end
    
    t = linspace(0, 1, nSegments + 1);
    for i = 1:nSegments
        t1 = t(i); t2 = t(i+1);
        p1 = startPt + t1 * (endPt - startPt);
        p2 = startPt + t2 * (endPt - startPt);
        color = startColor + (t1 + t2)/2 * (endColor - startColor);
        plot([p1(1), p2(1)], [p1(2), p2(2)], '-', 'Color', color, 'LineWidth', 2.5, ...
            'HandleVisibility', 'off');
    end
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
            'Color', color, 'LineWidth', 2.5, 'HandleVisibility', 'off');
    end
end

%% Draw semiaxes for 2D ellipse
function drawSemiaxes2D(center, C, nStd, color, lineWidth)
    [V, D] = eig(C);
    
    for i = 1:2
        eigval = D(i, i);
        if eigval < 0, continue; end
        
        semiaxis_len = sqrt(eigval) * nStd;
        direction = V(:, i)';
        
        endPt1 = center + semiaxis_len * direction;
        endPt2 = center - semiaxis_len * direction;
        
        plot([endPt2(1), endPt1(1)], [endPt2(2), endPt1(2)], '-', ...
            'Color', color, 'LineWidth', lineWidth, 'HandleVisibility', 'off');
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

%% Helper function to draw 2D ellipse
function drawEllipse2D(center, C, nStd, lineStyle, lineWidth)
    theta = linspace(0, 2*pi, 100);
    circle = [cos(theta); sin(theta)];
    
    [V, D] = eig(C);
    D(D < 0) = 0;  % Ensure non-negative
    transform = V * sqrt(D) * nStd;
    ellipse = transform * circle;
    
    plot(ellipse(1,:) + center(1), ellipse(2,:) + center(2), ...
        lineStyle, 'LineWidth', lineWidth, 'DisplayName', sprintf('%d\\sigma Ellipse', nStd));
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

%% Save statistics to mat file
function saveStatistics(stats, statsDir, algorithmName, problemName, pointType)
    if isempty(stats)
        return;
    end
    
    % Create filename
    fileName = sprintf('SS-%s-%s-%s.mat', pointType, algorithmName, problemName);
    filePath = fullfile(statsDir, fileName);
    
    % Save key statistics
    stable_runs = stats.stable_runs;
    total_runs = stats.total_runs;
    stability_rate = stats.stability_rate;
    avg_stable_gen = stats.avg_stable_gen;
    cluster_radius_med = stats.cluster_radius_med;
    cluster_radius_max = stats.cluster_radius_max;
    bias_L2 = stats.bias_L2;
    bias_L1 = stats.bias_L1;
    spread_trace = stats.spread_trace;
    spread_max_eig = stats.spread_max_eig;
    
    % Also save full centroids for potential future analysis
    centroids = stats.centroids;
    center = stats.center;
    covariance = stats.covariance;
    
    save(filePath, 'stable_runs', 'total_runs', 'stability_rate', ...
        'avg_stable_gen', 'cluster_radius_med', 'cluster_radius_max', ...
        'bias_L2', 'bias_L1', 'spread_trace', 'spread_max_eig', ...
        'centroids', 'center', 'covariance');
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

%% Add statistics textbox with improved layout
function addStatsTextbox(fig, stats, pointType)
    % Determine bias label based on point type (non-LaTeX)
    if strcmpi(pointType, 'Ideal')
        biasLabel = 'b_{*}';
    else
        biasLabel = 'b_{nad}';
    end
    
    % Build compact stats string with TeX interpreter
    if stats.stable_runs > 0
        textStr = sprintf(['# stable: %d/%d\n' ...
                           '\\rho_{med}: %.3g\n' ...
                           '%s: %.3g'], ...
            stats.stable_runs, stats.total_runs, ...
            stats.cluster_radius_med, ...
            biasLabel, stats.bias_L2);
    else
        textStr = sprintf('# stable: 0/%d', stats.total_runs);
    end
    
    % Remove any previous stats box
    delete(findall(fig, 'Tag', 'StatsTextbox'));
    
    % Position: right side, below legend area
    statsPos = [0.4000 0.1400 0.2525 0.1390];
    
    annotation(fig, 'textbox', statsPos, ...
        'String', textStr, ...
        'Tag', 'StatsTextbox', ...
        'Interpreter', 'tex', ...
        'FontSize', 20, ...
        'FontWeight', 'bold', ...
        'BackgroundColor', 'white', ...
        'EdgeColor', [0.7 0.7 0.7], ...
        'LineWidth', 1.5, ...
        'VerticalAlignment', 'middle', ...
        'HorizontalAlignment', 'center', ...
        'FitBoxToText', 'on', ...
        'Margin', 8);
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

