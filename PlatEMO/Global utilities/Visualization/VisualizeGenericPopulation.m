function VisualizeGenericPopulation(algDisplayName, probDisplayName, PopObj, PF, savePath)
%VISUALIZEGENERICPOPULATION Algorithm-agnostic population scatter plot
%
%   VisualizeGenericPopulation(algDisplayName, probDisplayName, PopObj, PF, savePath)
%
%   Input:
%     algDisplayName  - Algorithm display name (e.g. 'ZY-Tk-NSGA-III')
%     probDisplayName - Problem display name (e.g. 'DTLZ1')
%     PopObj          - N×M population objective matrix
%     PF              - P×M reference Pareto front matrix (can be empty)
%     savePath        - Full file path for exported PNG (can be empty to skip export)
%
%   Renders:
%     - Black dots: PF (behind, small markers, hidden from legend)
%     - Red filled circles: population (size 180, black edge)
%     - Legend: "Algorithm: X" + "Problem: Y (N solutions)"
%
%   Styling matches VisualizeMindistPopulation.m conventions.

    M = size(PopObj, 2);

    %% M > 3: warn and return
    if M > 3
        warning('VisualizeGenericPopulation: M=%d > 3, skipping (only 2D/3D supported).', M);
        return;
    end

    N = size(PopObj, 1);

    %% Create figure
    PreprocessProductionImage(2/3, 1, 8.8);
    fig = gcf;
    ax = gca;
    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    %% View
    if M >= 3
        view(ax, 135, 30);
    else
        view(ax, 2);
    end

    %% Labels
    xlabel(ax, '$f_1$', 'Interpreter', 'Latex');
    ylabel(ax, '$f_2$', 'Interpreter', 'Latex');
    if M >= 3
        zlabel(ax, '$f_3$', 'Interpreter', 'Latex');
    end

    %% Draw PF behind (small black dots, hidden from legend)
    if ~isempty(PF)
        if M == 2
            plot(ax, PF(:,1), PF(:,2), '.k', 'MarkerSize', 3, ...
                'HandleVisibility', 'off');
        else
            plot3(ax, PF(:,1), PF(:,2), PF(:,3), '.k', 'MarkerSize', 5, ...
                'HandleVisibility', 'off');
        end
    end

    %% Draw population (red filled circles)
    if M == 2
        scatter(ax, PopObj(:,1), PopObj(:,2), 180, ...
            'r', 'filled', 'MarkerEdgeColor', 'k', ...
            'MarkerFaceAlpha', 1, 'MarkerEdgeAlpha', 1, 'LineWidth', 1.5);
    else
        scatter3(ax, PopObj(:,1), PopObj(:,2), PopObj(:,3), 180, ...
            'r', 'filled', 'MarkerEdgeColor', 'k', ...
            'MarkerFaceAlpha', 1, 'MarkerEdgeAlpha', 1, 'LineWidth', 1.5);
    end

    %% Compute axis limits (include both PF and population)
    allObj = PopObj;
    if ~isempty(PF)
        allObj = [allObj; PF];
    end

    ax_max = max(allObj, [], 1);
    ax_min = min(allObj, [], 1);

    % Fix degenerate axes
    eps_factor = 1e-6;
    abs_epsilon = 1e-12;
    range = ax_max - ax_min;
    for d = 1:length(range)
        if range(d) <= 0 || ~isfinite(range(d))
            val = ax_min(d);
            eps_val = max(abs(val) * eps_factor, abs_epsilon);
            ax_min(d) = val - eps_val;
            ax_max(d) = val + eps_val;
        end
    end

    xlim([ax_min(1) ax_max(1)]);
    ylim([ax_min(2) ax_max(2)]);
    if M >= 3
        zlim([ax_min(3) ax_max(3)]);
    end

    %% Legend
    if M == 2
        fakeRed = [1.0, 0, 0];
        h_pop = plot(ax, NaN, NaN, 'o', ...
            'MarkerSize', 20, ...
            'MarkerEdgeColor', 'k', ...
            'MarkerFaceColor', fakeRed, ...
            'LineWidth', 1.5);
    else
        fakeRed = [1.0, 0, 0];
        h_pop = plot3(ax, NaN, NaN, NaN, 'o', ...
            'MarkerSize', 20, ...
            'MarkerEdgeColor', 'k', ...
            'MarkerFaceColor', fakeRed, ...
            'LineWidth', 1.5);
    end

    legend(ax, h_pop, ...
        {sprintf('Algorithm: %s', algDisplayName)}, ...
        'Location', 'southoutside');

    % Add text annotation for problem info
    title(ax, sprintf('%s (%d solutions)', probDisplayName, N));

    %% 3D-specific settings
    if M == 3
        axis(ax, 'vis3d');
        box(ax, 'on');
        lighting(ax, 'gouraud');
        light('Position', [1 1 1], 'Style', 'infinite');
        light('Position', [-1 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);
    end

    %% Export if savePath provided
    if nargin >= 5 && ~isempty(savePath)
        exportgraphics(fig, savePath, 'Resolution', 300);
        close(fig);
    end
end
