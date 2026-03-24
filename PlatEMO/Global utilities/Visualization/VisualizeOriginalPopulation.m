function VisualizeOriginalPopulation(Algorithm, Population, Problem, FE)

    if nargin < 4
        FE = Problem.FE;
    end

    N = numel(Population);
    M = Problem.M;

    %% Create figure for visualization
    % fig = figure('Position', [50, 50, 1200, 950], ...
    %              'Name', 'Mindist Visualization (Normalized Space)', 'Visible', 'on');
    % ax = axes('Position', [0.10, 0.22, 0.85, 0.70]);
    fig=gcf;ax=gca;

    %% Axes properties
    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    if M == 3
        view(ax, 167, 15);
    else
        view(ax, 2);
    end

    %% Labels & Titles
    xlabel(ax, '$f_1$', 'Interpreter', 'Latex');
    ylabel(ax, '$f_2$', 'Interpreter', 'Latex');

    if M == 3
        zlabel(ax, '$f_3$', 'Interpreter', 'Latex');
    end

    algName = func2str(Algorithm);
    if strcmp(algName, 'NSGAIIIwH')
        algName = 'Pl-NSGA-III';
    elseif strcmp(algName, 'PyNSGAIIIwH')
        algName = 'Py-NSGA-III';
    elseif strcmp(algName, 'GtNSGAIIIwH')
        algName = 'Gt-NSGA-III';
    end

    % title(ax, sprintf('%s on %s (N=%d) for %s file at FE: %d (Normalized)', ...
    %     algName, class(Problem), N, fixedString, FE));
    title(ax, sprintf('Original population on %s (N=%d) at FE: %d', ...
        class(Problem), N, FE));

    %% Filter feasible solutions and compute mindist
    Population = Population(all(Population.cons <= 0, 2));
    
    pop_objs = Population.objs;
    pop_objs = sortrows(pop_objs, [3 2 1], 'descend');
    maxlim = max([pop_objs; 1, 1, 1]);
    minlim = min([pop_objs; 0, 0, 0]);

    %% ========== 2D or 3D VISUALIZATION ==========
    if M == 2
        %% ======== 2D visualization (normalized) ========
        
        % Draw unit simplex (line from (1,0) to (0,1))
        plot(ax, [1, 0], [0, 1], 'c-', 'LineWidth', 2);

        % Solutions (red)
        if ~isempty(pop_objs)
            scatter(ax, pop_objs(:,1), pop_objs(:,2), 60, ...
                'r', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 1, 'MarkerEdgeAlpha', 1);
        end

        % Set axis limits
        xlim(ax, [minlim(1), maxlim(1)]);
        ylim(ax, [minlim(2), maxlim(2)]);
        axis(ax, 'equal');

    else
        %% ======== 3D visualization (normalized) ========
        

        % Solutions (red)
        if ~isempty(pop_objs)
            scatter3(ax, pop_objs(:,1), pop_objs(:,2), pop_objs(:,3), 120, ...
                'r', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 1, 'MarkerEdgeAlpha', 1, 'LineWidth', 1.5);
        end


        if ~isempty(pop_objs)
            x_shift = 0;
            y_shift = 0.05;
            z_shift = 0.02;

            for i=1:size(pop_objs,1)
                text_x = pop_objs(i,1);
                text_y = pop_objs(i,2);
                text_z = pop_objs(i,3);
                text(ax, text_x+x_shift, text_y+y_shift, text_z+z_shift, ...
                    sprintf('%d', i), 'FontSize', 32)
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
        h_leg_mindist = plot(ax, NaN, NaN, 'o', ...
            'MarkerSize', legend_marker_size, ...
            'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');
        h_handles(end+1) = h_leg_mindist;
        h_labels{end+1} = sprintf('Solutions (%d)', size(pop_objs, 1));
    else
        h_leg_mindist = plot3(ax, NaN, NaN, NaN, 'o', ...
            'MarkerSize', legend_marker_size, ...
            'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');
        h_handles(end+1) = h_leg_mindist;
        h_labels{end+1} = sprintf('Solutions (%d)', size(pop_objs, 1));
    end

    lgd = legend(ax, h_handles, h_labels, ...
        'Location', [0.3883 0.0200 0.2733 0.0732], ...
        'NumColumns', 2);

    %% 3D-specific settings
    if M == 3
        axis(ax, 'vis3d');
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

    filename = sprintf("./Original-DTLZ2.png");
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
                '-', 'Color', [0.7, 0.7, 0.7], 'LineWidth', 0.5);
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
                '-', 'Color', [0.7, 0.7, 0.7], 'LineWidth', 0.5);
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
            ':', 'Color', [0.3, 0.3, 0.3], 'LineWidth', 1.2);
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