function VisualizeNichedPopulationWithRefvec(Algorithm, Population, Z, Problem, FE, NormStruct, fixedIndex)

    if nargin < 5
        FE = Problem.FE;
    end

    if nargin < 6
        NormStruct = [];
    end

    if nargin < 7
        fixedString = 'Median';
    else
        fixedString = sprintf('ID=%d', fixedIndex);
    end

    N = numel(Population);
    M = Problem.M;

    %% Create figure for visualization
    % fig = figure('Position', [50, 50, 1200, 950], ...
    %              'Name', 'Mindist Visualization (Normalized Space)', 'Visible', 'on');
    % ax = axes('Position', [0.10, 0.32, 0.85, 0.60]);
    fig=gcf;ax=gca;

    %% Axes properties
    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    if M == 3
        % view(ax, 90, 0);
        view(ax, 167, 15);
    else
        view(ax, 2);
    end

    %% Labels & Titles
    xlabel(ax, '$\tilde{f}_1$', 'Interpreter', 'Latex');
    ylabel(ax, '$\tilde{f}_2$', 'Interpreter', 'Latex');

    if M == 3
        zlabel(ax, '$\tilde{f}_3$', 'Interpreter', 'Latex');
    end

    algName = func2str(Algorithm);
    if strcmp(algName, 'NSGAIIIwH')
        algName = 'Pl-NSGA-III';
    elseif strcmp(algName, 'PyNSGAIIIwH')
        algName = 'Py-NSGA-III';
    elseif strcmp(algName, 'GtNSGAIIIwH')
        algName = 'Gt-NSGA-III';
    else
        algName = 'Custom-NSGA-III';
    end

    % title(ax, sprintf('%s on %s (N=%d) for %s file at FE: %d (Normalized)', ...
    %     algName, class(Problem), N, fixedString, FE));
    title(ax, sprintf('%s on %s (N=%d) at FE: %d', ...
        algName, class(Problem), N, FE));

    %% Filter feasible solutions and compute mindist
    Population = Population(all(Population.cons <= 0, 2));
    
    if isempty(NormStruct)
        NormStruct = PyNormalizationHistory(M);
        F_all = Population.objs;
        [FrontNo, ~] = NDSort(F_all, 1);
        nds = find(FrontNo == 1);
        NormStruct.update(F_all, nds);
    end
    
    %% Get normalization info
    ideal_point = NormStruct.ideal_point;
    nadir_point = NormStruct.nadir_point;
    if ~strcmp(algName, 'Gt-NSGA-III')
        extreme_points = NormStruct.extreme_points;
    end


    %% Normalization function
    norm_const = 1e-6;
    disp(nadir_point);
    disp(ideal_point);
    denom = nadir_point - ideal_point + norm_const;
    normalize = @(F) (F - ideal_point + norm_const) ./ denom;
    % normalize = @(F) (F-ideal_point+norm_const);
    % shift = @(F) (F-ideal_point);

    %% Compute mindist assignment info (need full details for reference vector highlighting)
    [P_others, P_mindist, mindist_assignment] = ComputeMindistWithAssignment(Population, Problem, Z, NormStruct);

    O_others = P_others.objs;
    O_mindist = P_mindist.objs;


    %% Normalize all points
    O_others_norm = normalize(O_others);
    O_mindist_norm = normalize(O_mindist);
    if ~strcmp(algName, 'Gt-NSGA-III') && ~strcmp(algName, 'Custom-NSGA-III')
        extreme_points_norm = normalize(extreme_points);
    else
        extreme_points_norm = [];
    end
    
    % In normalized space: ideal -> origin, nadir -> (1,1,1)
    ideal_norm = zeros(1, M);
    nadir_norm = ones(1, M);

    %% Remove extreme points from O_others and O_mindist to avoid duplicate plotting
    tol = 1e-10;
    
    if ~isempty(extreme_points_norm) && ~isempty(O_others_norm)
        dist_others = pdist2(O_others_norm, extreme_points_norm);
        is_extreme_others = any(dist_others < tol, 2);
        O_others_norm = O_others_norm(~is_extreme_others, :);
    end
    
    if ~isempty(extreme_points_norm) && ~isempty(O_mindist_norm)
        dist_mindist = pdist2(O_mindist_norm, extreme_points_norm);
        is_extreme_mindist = any(dist_mindist < tol, 2);
        O_mindist_norm = O_mindist_norm(~is_extreme_mindist, :);
        % Also update assignment indices
        mindist_assignment.points_norm = mindist_assignment.points_norm;
        mindist_assignment.ref_indices = mindist_assignment.ref_indices;
    end

    %% Identify active reference vectors (those with niched solutions)
    active_ref_indices = unique(mindist_assignment.ref_indices);

    all_objs = [O_others_norm;O_mindist_norm;extreme_points_norm];
    all_objs = sortrows(all_objs, [3 2 1], 'descend');
    maxlim = max([all_objs; 1, 1, 1]);
    minlim = min([all_objs; 0, 0, 0]);

    %% ========== 2D or 3D VISUALIZATION ==========
    if M == 2
        %% ======== 2D visualization (normalized) ========
        
        % Draw unit simplex (line from (1,0) to (0,1))
        plot(ax, [1, 0], [0, 1], 'c-', 'LineWidth', 2);
        
        % Draw reference vectors (inactive: gray, active: red)
        drawReferenceVectors2D(ax, ideal_norm, Z, active_ref_indices);
        
        % Draw perpendicular lines from mindist solutions to their reference vectors
        drawPerpendicularLines2D(ax, mindist_assignment, Z);
        
        % Other solutions (green)
        if ~isempty(O_others_norm)
            scatter(ax, O_others_norm(:,1), O_others_norm(:,2), 60, ...
                'g', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 0.3, 'MarkerEdgeAlpha', 0.3, 'LineWidth', 1.5);
        end

        % Mindist solutions (red)
        if ~isempty(O_mindist_norm)
            scatter(ax, O_mindist_norm(:,1), O_mindist_norm(:,2), 60, ...
                'r', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 1, 'MarkerEdgeAlpha', 1, 'LineWidth', 1.5);
        end

        % Extreme points (yellow pentagram)
        if ~isempty(extreme_points_norm)
            scatter(ax, extreme_points_norm(:,1), extreme_points_norm(:,2), 300, ...
                'yellow', 'filled', 'pentagram', 'MarkerEdgeColor', 'k', ...
                'LineWidth', 1.5);
        end

        % Ideal point (green diamond) - at origin in normalized space
        scatter(ax, ideal_norm(1), ideal_norm(2), 200, ...
            'g', 'filled', 'diamond', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

        % Nadir point (green square) - at (1,1) in normalized space
        scatter(ax, nadir_norm(1), nadir_norm(2), 200, ...
            'g', 'filled', 'square', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

        % Set axis limits
        xlim(ax, [minlim(1), maxlim(1)]);
        ylim(ax, [minlim(2), maxlim(2)]);
        axis(ax, 'equal');

    else
        %% ======== 3D visualization (normalized) ========
        
        % Draw unit simplex (triangle with vertices at (1,0,0), (0,1,0), (0,0,1))
        simplex_vertices = eye(M);
        fill3(ax, simplex_vertices(:,1), simplex_vertices(:,2), simplex_vertices(:,3), ...
            'cyan', 'FaceAlpha', 0.25, 'EdgeColor', 'c', 'LineWidth', 1.5);
        
        % Draw reference vectors (inactive: gray, active: red)
        drawReferenceVectors3D(ax, ideal_norm, Z, active_ref_indices);
        
        % Draw perpendicular lines from mindist solutions to their reference vectors
        drawPerpendicularLines3D(ax, mindist_assignment, Z);
        
        % Other solutions (green)
        if ~isempty(O_others_norm)
            scatter3(ax, O_others_norm(:,1), O_others_norm(:,2), O_others_norm(:,3), 120, ...
                'g', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 0.3, 'MarkerEdgeAlpha', 0.3, 'LineWidth', 1.5);
        end

        % Mindist solutions (red)
        if ~isempty(O_mindist_norm)
            scatter3(ax, O_mindist_norm(:,1), O_mindist_norm(:,2), O_mindist_norm(:,3), 120, ...
                'r', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 1, 'MarkerEdgeAlpha', 1, 'LineWidth', 1.5);
        end

        % Extreme points (yellow pentagram)
        if ~isempty(extreme_points_norm)
            scatter3(ax, extreme_points_norm(:,1), extreme_points_norm(:,2), extreme_points_norm(:,3), 300, ...
                'yellow', 'filled', 'pentagram', 'MarkerEdgeColor', 'k', ...
                'LineWidth', 1.5);
        end

        if ~isempty(all_objs)
            x_shift = 0;
            y_shift = 0.05;
            z_shift = 0.02;

            for i=1:size(all_objs,1)
                text_x = all_objs(i,1);
                text_y = all_objs(i,2);
                text_z = all_objs(i,3);
                htext = text(ax, text_x+x_shift, text_y+y_shift, text_z+z_shift, ...
                    sprintf('%d', i), 'FontSize', 32);

                if i == 1
                    htext.Position = [text_x, text_y, text_z] + [0.015, -0.01, -0.055];
                end
                if i == 2
                    htext.Position = htext.Position + [0, 0.01, 0.02];
                end
                if i == 4
                    htext.Position = htext.Position + [0, 0.00, 0.035];
                end
                if i == 6
                    htext.Position = htext.Position + [0, 0.00, -0.035];
                end
                if i == 9
                    htext.Position = htext.Position + [0, 0.00, -0.035];
                end
                if i == 12
                    htext.Position = [text_x, text_y, text_z] + [0.045, 0.00, -0.055];
                end
                if i == 15
                    htext.Position = [text_x, text_y, text_z] + [0.08, -0.09, -0.055];
                end
                    
            end
        end

        % Ideal point (green diamond) - at origin in normalized space
        scatter3(ax, ideal_norm(1), ideal_norm(2), ideal_norm(3), 200, ...
            'g', 'filled', 'diamond', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

        % Nadir point (green square) - at (1,1,1) in normalized space
        scatter3(ax, nadir_norm(1), nadir_norm(2), nadir_norm(3), 200, ...
            'g', 'filled', 'square', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

        % Set axis limits
        xlim(ax, [minlim(1), maxlim(1)]);
        ylim(ax, [minlim(2), maxlim(2)]);
        zlim(ax, [minlim(3), maxlim(3)]);
    end

    %% ========== LEGEND ==========
    h_handles = [];
    h_labels = {};
    legend_marker_size = 12;

    if M == 2
        h_leg_others = plot(ax, NaN, NaN, 'o', ...
            'MarkerSize', legend_marker_size, ...
            'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k');
        h_handles(end+1) = h_leg_others;
        h_labels{end+1} = sprintf('Other solutions (%d)', size(O_others_norm, 1));

        h_leg_mindist = plot(ax, NaN, NaN, 'o', ...
            'MarkerSize', legend_marker_size, ...
            'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');
        h_handles(end+1) = h_leg_mindist;
        h_labels{end+1} = sprintf('Mindist solutions (%d)', size(O_mindist_norm, 1));

        if ~strcmp(algName, 'Gt-NSGA-III')
            h_leg_extreme = plot(ax, NaN, NaN, 'p', ...
                'MarkerSize', legend_marker_size + 4, ...
                'MarkerFaceColor', 'yellow', 'MarkerEdgeColor', 'k');
            h_handles(end+1) = h_leg_extreme;
            h_labels{end+1} = sprintf('Extreme points');
        end

        h_leg_ideal = plot(ax, NaN, NaN, 'd', ...
            'MarkerSize', legend_marker_size, ...
            'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k');
        h_handles(end+1) = h_leg_ideal;
        h_labels{end+1} = 'Ideal point';

        h_leg_nadir = plot(ax, NaN, NaN, 's', ...
            'MarkerSize', legend_marker_size, ...
            'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k');
        h_handles(end+1) = h_leg_nadir;
        h_labels{end+1} = 'Nadir point';

        h_leg_active = plot(ax, NaN, NaN, '-', ...
            'Color', 'r', 'LineWidth', 2);
        h_handles(end+1) = h_leg_active;
        h_labels{end+1} = sprintf('Active ref vectors (%d)', length(active_ref_indices));

        h_leg_inactive = plot(ax, NaN, NaN, '-', ...
            'Color', [0.7, 0.7, 0.7], 'LineWidth', 0.5);
        h_handles(end+1) = h_leg_inactive;
        h_labels{end+1} = sprintf('Inactive ref vectors (%d)', size(Z, 1) - length(active_ref_indices));

    else
        h_leg_ideal = plot3(ax, NaN, NaN, NaN, 'd', ...
            'MarkerSize', legend_marker_size, ...
            'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k');
        h_handles(end+1) = h_leg_ideal;
        h_labels{end+1} = 'Ideal point';

        h_leg_nadir = plot3(ax, NaN, NaN, NaN, 's', ...
            'MarkerSize', legend_marker_size, ...
            'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k');
        h_handles(end+1) = h_leg_nadir;
        h_labels{end+1} = 'Nadir point';

        h_leg_others = plot3(ax, NaN, NaN, NaN, 'o', ...
            'MarkerSize', legend_marker_size, ...
            'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k');
        h_handles(end+1) = h_leg_others;
        h_labels{end+1} = sprintf('Other solutions', size(O_others_norm, 1));

        h_leg_mindist = plot3(ax, NaN, NaN, NaN, 'o', ...
            'MarkerSize', legend_marker_size, ...
            'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');
        h_handles(end+1) = h_leg_mindist;
        h_labels{end+1} = sprintf('Niched solutions', size(O_mindist_norm, 1));

        h_leg_active = plot3(ax, NaN, NaN, NaN, '-', ...
            'Color', 'r', 'LineWidth', 2);
        h_handles(end+1) = h_leg_active;
        h_labels{end+1} = sprintf('Active niches', length(active_ref_indices));

        h_leg_inactive = plot3(ax, NaN, NaN, NaN, '-', ...
            'Color', [0.7, 0.7, 0.7], 'LineWidth', 1.5);
        h_handles(end+1) = h_leg_inactive;
        h_labels{end+1} = sprintf('Inactive niches', size(Z, 1) - length(active_ref_indices));

        h_leg_perp = plot3(ax, NaN, NaN, NaN, ':', ...
                'Color', [0.3, 0.3, 0.3], 'LineWidth', 2.0);
            h_handles(end+1) = h_leg_perp;
            h_labels{end+1} = sprintf('Distance line');

        if ~strcmp(algName, 'Gt-NSGA-III')

            h_leg_extreme = plot3(ax, NaN, NaN, NaN, 'p', ...
                'MarkerSize', legend_marker_size + 8, ...
                'MarkerFaceColor', 'yellow', 'MarkerEdgeColor', 'k');
            h_handles(end+1) = h_leg_extreme;
            h_labels{end+1} = sprintf('Extreme points', size(extreme_points_norm, 1));
        end
    end

    lgd = legend(ax, h_handles, h_labels, ...
        'Location', [0.3883 0.0900 0.2733 0.0732], ...
        'NumColumns', 2);



    %% 3D-specific settings
    if M == 3
        % axis(ax, 'vis3d');
        box(ax, 'on');
        lighting(ax, 'gouraud');
        light('Position', [1 1 1], 'Style', 'infinite');
        light('Position', [-1 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);
    end

    FontStruct = struct();
    FontStruct.fontSize = 20;
    FontStruct.axesSize = 26;
    FontStruct.legendSize = 26;
    % EnlargeFont(fig, FontStruct);

    filename = sprintf("./%s-%s-Niches-2D.png", ...
        algName, class(Problem));
    % exportgraphics(ancestor(ax, 'figure'), filename, 'Resolution', 600);
end

%% ========== COMPUTE MINDIST WITH ASSIGNMENT INFO ==========

function [P_others, P_mindist, assignment] = ComputeMindistWithAssignment(Population, Problem, Z, NormStruct)
    F = Population.objs;

    Zmin = NormStruct.ideal_point;
    Zmax = NormStruct.nadir_point;
    denom = Zmax - Zmin;
    denom(denom == 0) = 1e-12;
    FF = (F - Zmin) ./ denom;
    
    N = numel(Population);
    NZ = size(Z, 1);
    
    % Compute distances
    Cosine = 1 - pdist2(FF, Z, 'cosine');
    Distance = repmat(sqrt(sum(FF.^2, 2)), 1, NZ) .* sqrt(1 - Cosine.^2);
    
    % Assignment: pi(i) = reference vector index for solution i
    [d, pi] = min(Distance', [], 1);
    
    % Count solutions per reference vector
    rho = hist(pi(1:N), 1:NZ);
    
    % Identify mindist solutions
    l_mindist = zeros(1, N);
    for i = 1:NZ
        if rho(i) == 0
            continue
        elseif rho(i) == 1
            l_mindist(pi == i) = 1;
        else
            l_mindist(d == min(d(pi == i))) = 1;
        end
    end

    l = l_mindist == 1;
    P_mindist = Population(l);
    P_others = Population(~l);
    
    % Store assignment info for mindist solutions
    assignment.points_norm = FF(l, :);           % Normalized coordinates
    assignment.ref_indices = pi(l);              % Which reference vector each is assigned to
    assignment.distances = d(l);                 % Perpendicular distances
end

%% ========== REFERENCE VECTOR DRAWING FUNCTIONS ==========

function drawReferenceVectors2D(ax, origin, Z, active_indices)
    NZ = size(Z, 1);
    active_set = ismember(1:NZ, active_indices);
    
    % Scale to extend beyond unit simplex
    scale = 80;
    
    % Draw inactive vectors first (gray, thin)
    for i = 1:NZ
        if ~active_set(i)
            endpoint = origin + Z(i, :) * scale;
            plot(ax, [origin(1), endpoint(1)], [origin(2), endpoint(2)], ...
                '-', 'Color', [0.7, 0.7, 0.7], 'LineWidth', 1.5);
        end
    end
    
    % Draw active vectors on top (red, bold)
    for i = 1:NZ
        if active_set(i)
            endpoint = origin + Z(i, :) * scale;
            plot(ax, [origin(1), endpoint(1)], [origin(2), endpoint(2)], ...
                '-', 'Color', 'r', 'LineWidth', 2);
        end
    end
end

function drawReferenceVectors3D(ax, origin, Z, active_indices)
    NZ = size(Z, 1);
    active_set = ismember(1:NZ, active_indices);
    
    % Scale to extend beyond unit simplex
    scale = 80;
    
    % Draw inactive vectors first (gray, thin)
    for i = 1:NZ
        if ~active_set(i)
            endpoint = origin + Z(i, :) * scale;
            plot3(ax, [origin(1), endpoint(1)], [origin(2), endpoint(2)], [origin(3), endpoint(3)], ...
                '-', 'Color', [0.7, 0.7, 0.7], 'LineWidth', 1.5);
        end
    end
    
    % Draw active vectors on top (red, bold)
    for i = 1:NZ
        if active_set(i)
            endpoint = origin + Z(i, :) * scale;
            plot3(ax, [origin(1), endpoint(1)], [origin(2), endpoint(2)], [origin(3), endpoint(3)], ...
                '-', 'Color', 'r', 'LineWidth', 2);
        end
    end
end

%% ========== PERPENDICULAR LINE DRAWING FUNCTIONS ==========

function drawPerpendicularLines2D(ax, assignment, Z)
    n_mindist = size(assignment.points_norm, 1);
    
    for i = 1:n_mindist
        P = assignment.points_norm(i, :);       % Solution point (normalized)
        ref_idx = assignment.ref_indices(i);    % Assigned reference vector index
        z = Z(ref_idx, :);                      % Reference vector direction
        
        % Compute projection (foot of perpendicular) onto the reference ray
        % Ray: origin + t * z, foot at t = (P · z) / (z · z)
        t = dot(P, z) / dot(z, z);
        foot = t * z;
        
        % Draw dotted perpendicular line
        plot(ax, [P(1), foot(1)], [P(2), foot(2)], ...
            ':', 'Color', [0.3, 0.3, 0.3], 'LineWidth', 2);
    end
end

function drawPerpendicularLines3D(ax, assignment, Z)
    n_mindist = size(assignment.points_norm, 1);
    
    for i = 1:n_mindist
        P = assignment.points_norm(i, :);       % Solution point (normalized)
        ref_idx = assignment.ref_indices(i);    % Assigned reference vector index
        z = Z(ref_idx, :);                      % Reference vector direction
        
        % Compute projection (foot of perpendicular) onto the reference ray
        % Ray: origin + t * z, foot at t = (P · z) / (z · z)
        t = dot(P, z) / dot(z, z);
        foot = t * z;
        
        % Draw dotted perpendicular line
        plot3(ax, [P(1), foot(1)], [P(2), foot(2)], [P(3), foot(3)], ...
            ':', 'Color', [0.3, 0.3, 0.3], 'LineWidth', 2.0);
    end
end