function VisualizeMindistPopulation(Algorithm, Population, Z, Problem, FE, NormStruct, fixedIndex)

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

    %% Create figure for visualization
    PreprocessProductionImage(0.5, 1, 8.8);
    % fig = figure('Position', [100, 50, 1000, 800], ...
    %              'Name', 'Mindist Visualization', 'Visible', 'on');
    % ax = axes('Position', [0.13, 0.1, 0.9, 0.9]);
    fig=gcf;ax=gca;

    %% Axes properties
    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    M = Problem.M;   % number of objectives

    if M >= 3
        view(ax, 135, 30);
    else
        view(ax, 2); % top-down 2D view
    end

    %% Labels & Titles
    xlabel(ax, '$f_1$', 'Interpreter', 'Latex');
    ylabel(ax, '$f_2$', 'Interpreter', 'Latex');

    if M >= 3
        zlabel(ax, '$f_3$', 'Interpreter', 'Latex');
    end

    title(ax, sprintf('%s on %s (N=%d) for %s file at FE: %d', ...
        func2str(Algorithm), class(Problem), N, fixedString, FE));

    %% Filter feasible solutions
    Population = Population(all(Population.cons <= 0, 2));
    if isempty(NormStruct)
        [P_others, P_mindist] = ComputeMindist(Population, Problem, Z);
    else
        [P_others, P_mindist] = ComputeMindist(Population, Problem, Z, NormStruct);
    end

    O_others = P_others.objs;
    O_mindist = P_mindist.objs;

    %% ========== 2D or 3D SCATTER ==========

    if M == 2
        % ======== 2D visualization ========
        if ~isempty(O_others)
            scatter(ax, O_others(:,1), O_others(:,2), 180, ...
                'g', 'filled', 'MarkerEdgeColor','k', ...
                'MarkerFaceAlpha',0.3, 'MarkerEdgeAlpha',0.3);
        end

        if ~isempty(O_mindist)
            scatter(ax, O_mindist(:,1), O_mindist(:,2), 180, ...
                'r', 'filled', 'MarkerEdgeColor','k', ...
                'MarkerFaceAlpha',1, 'MarkerEdgeAlpha',1, 'LineWidth', 1.5);
        end

        A = [O_others; O_mindist];
        ax_max = max(A, [], 1);
        ax_min = min(A, [], 1);
        
        % --- Fix degenerate axes ---
        eps_factor = 1e-6;      % relative expansion
        abs_epsilon = 1e-12;    % fallback for magnitude=0
        
        range = ax_max - ax_min;
        for d = 1:length(range)
            if range(d) <= 0 || ~isfinite(range(d))
                % Expand around the single value
                val = ax_min(d);
                eps_val = max(abs(val) * eps_factor, abs_epsilon);
                ax_min(d) = val - eps_val;
                ax_max(d) = val + eps_val;
            end
        end
        
        % Now ALWAYS safe:
        xlim([ax_min(1) ax_max(1)]);
        ylim([ax_min(2) ax_max(2)]);

    else
        % ======== 3D visualization (your original code) ========
        if ~isempty(O_others)
            scatter3(ax, O_others(:,1), O_others(:,2), O_others(:,3), 180, ...
                'g', 'filled', 'MarkerEdgeColor','k', ...
                'MarkerFaceAlpha',0.3, 'MarkerEdgeAlpha',0.3);
        end

        if ~isempty(O_mindist)
            scatter3(ax, O_mindist(:,1), O_mindist(:,2), O_mindist(:,3), 180, ...
                'r', 'filled', 'MarkerEdgeColor','k', ...
                'MarkerFaceAlpha',1, 'MarkerEdgeAlpha',1, 'LineWidth', 1.5);
        end

        A = [O_others; O_mindist];
        ax_max = max(A, [], 1);
        ax_min = min(A, [], 1);
        
        % --- Fix degenerate axes ---
        eps_factor = 1e-6;      % relative expansion
        abs_epsilon = 1e-12;    % fallback for magnitude=0
        
        range = ax_max - ax_min;
        for d = 1:length(range)
            if range(d) <= 0 || ~isfinite(range(d))
                % Expand around the single value
                val = ax_min(d);
                eps_val = max(abs(val) * eps_factor, abs_epsilon);
                ax_min(d) = val - eps_val;
                ax_max(d) = val + eps_val;
            end
        end
        
        % Now ALWAYS safe:
        xlim([ax_min(1) ax_max(1)]);
        ylim([ax_min(2) ax_max(2)]);
        zlim([ax_min(3) ax_max(3)]);
    end

    %% ========== LEGEND (consistent with your 3D style) ==========
    h_handles = [];
    h_labels = {};

    if M == 2
        % Other (2D)
        fakeTransparentGreen = [0.6, 1.0, 0.6];
        h_others = plot(ax, NaN, NaN, 'o', ... % Remove 'g' here
            'MarkerSize', 20, ...
            'MarkerEdgeColor', 'k', ... % Keep edge black
            'MarkerFaceColor', fakeTransparentGreen);
        h_handles(end+1) = h_others;
        h_labels{end+1} = sprintf('Other solutions (%d/%d)', numel(P_others), N);

        % Mindist (2D)
        fakeTransparentRed = [1.0, 0, 0];
        h_mindist = plot(ax, NaN, NaN, 'o', ...
            'MarkerSize', 20, ...
            'MarkerEdgeColor', 'k', ...
            'MarkerFaceColor', fakeTransparentRed, ...
            'LineWidth', 1.5);
        h_handles(end+1) = h_mindist;
        h_labels{end+1} = sprintf('Niched solutions (%d/%d)', numel(P_mindist), N);

    else
        % Other (3D)
        fakeTransparentGreen = [0.6, 1.0, 0.6];
        h_others = plot3(ax, NaN, NaN, NaN, 'o', ... % Remove 'g' here
            'MarkerSize', 20, ...
            'MarkerEdgeColor', 'k', ... % Keep edge black
            'MarkerFaceColor', fakeTransparentGreen);
        h_handles(end+1) = h_others;
        h_labels{end+1} = sprintf('Other solutions (%d/%d)', numel(P_others), N);

        % Mindist (3D)
        fakeTransparentRed = [1.0, 0, 0];
        h_mindist = plot3(ax, NaN, NaN, NaN, 'o', ...
            'MarkerSize', 20, ...
            'MarkerEdgeColor', 'k', ...
            'MarkerFaceColor', fakeTransparentRed, ...
            'LineWidth', 1.5);
        h_handles(end+1) = h_mindist;
        h_labels{end+1} = sprintf('Niched solutions (%d/%d)', numel(P_mindist), N);
    end

    legend(ax, h_handles, h_labels, 'Location', 'southoutside');

    %% 3D-specific settings
    if M == 3
        axis(ax, 'vis3d');
        box(ax, 'on');

        lighting(ax, 'gouraud');
        light('Position', [1 1 1], 'Style', 'infinite');
        light('Position', [-1 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);
    end

    % EnlargeFont(fig)

    filename = sprintf("./Visualization/images/MP-%s-%s-M%d-D%d.png", ...
        func2str(Algorithm), class(Problem), Problem.M, Problem.D);
    % exportgraphics(ancestor(ax, 'figure'), filename, 'Resolution', 600);
    % close(fig);
end