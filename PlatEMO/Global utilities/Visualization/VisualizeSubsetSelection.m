function VisualizeSubsetSelection(PopObj1, PopObj2, DSSSelectedIdx, NichedIdx, savePath)
% VisualizeSubsetSelection - Visualize DSS selection procedure
%
% INPUT:
%   PopObj1       : [N1 x M] objectives of solutions from higher fronts (already selected)
%   PopObj2       : [N2 x M] objectives of solutions from last front
%   DSSSelectedIdx: indices (into PopObj2) of solutions selected via DSS
%   NichedIdx     : indices (into PopObj2) of solutions selected via niching (rho==0)
%   savePath      : (optional) path to save the figure
%
% VISUALIZATION:
%   GREEN: DSS-selected solutions (non-niched, selected via max-min distance)
%   RED: Other survivors (niched solutions + higher-domination-level solutions)

    if nargin < 5
        savePath = '';
    end

    M = size(PopObj1, 2);
    if isempty(PopObj1) && ~isempty(PopObj2)
        M = size(PopObj2, 2);
    end

    %% Prepare data
    % RED: Higher front solutions + niched solutions from last front
    RedObjs = PopObj1;
    
    BlueObjs = [];
    if ~isempty(NichedIdx)
        BlueObjs = PopObj2(NichedIdx, :);
    end

    % GREEN: DSS-selected solutions from last front
    GreenObjs = [];
    if ~isempty(DSSSelectedIdx)
        GreenObjs = PopObj2(DSSSelectedIdx, :);
    end

    %% Create figure

    PreprocessProductionImage(1/3, 1, 8.8);
    fig = gcf; ax = gca;

    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    if M == 3
        view(ax, 135, 30);
    else
        view(ax, 2);
    end

    %% Labels
    xlabel(ax, '$f_1$', 'Interpreter', 'Latex');
    ylabel(ax, '$f_2$', 'Interpreter', 'Latex');
    if M == 3
        zlabel(ax, '$f_3$', 'Interpreter', 'Latex');
    end

    title(ax, 'DSS Selection Visualization');

    %% Plot
    markerSizeRed = 60;
    markerSizeBlue = 120;
    markerSizeGreen = 180;

    if M == 2
        % 2D visualization
        if ~isempty(RedObjs)
            scatter(ax, RedObjs(:,1), RedObjs(:,2), markerSizeRed, ...
                'r', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 1);
        end

        if ~isempty(BlueObjs)
            scatter(ax, BlueObjs(:,1), BlueObjs(:,2), markerSizeBlue, ...
                'b', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 1);
        end

        if ~isempty(GreenObjs)
            scatter(ax, GreenObjs(:,1), GreenObjs(:,2), markerSizeGreen, ...
                'g', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 1, 'MarkerEdgeAlpha', 1, 'LineWidth', 1.5);
        end

    elseif M == 3
        % 3D visualization
        if ~isempty(RedObjs)
            scatter3(ax, RedObjs(:,1), RedObjs(:,2), RedObjs(:,3), markerSizeRed, ...
                'r', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 1);
        end

        if ~isempty(BlueObjs)
            scatter3(ax, BlueObjs(:,1), BlueObjs(:,2), BlueObjs(:,3), markerSizeBlue, ...
                'b', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 1);
        end

        if ~isempty(GreenObjs)
            scatter3(ax, GreenObjs(:,1), GreenObjs(:,2), GreenObjs(:,3), markerSizeGreen, ...
                'g', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 1, 'MarkerEdgeAlpha', 1, 'LineWidth', 1.5);
        end
    else
        % Many-objective: use parallel coordinates or just first 3 dimensions
        warning('Visualization only supports 2D and 3D. Showing first 3 objectives.');
        if ~isempty(RedObjs)
            scatter3(ax, RedObjs(:,1), RedObjs(:,2), RedObjs(:,3), markerSizeRed, ...
                'r', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 1);
        end

        if ~isempty(BlueObjs)
            scatter3(ax, BlueObjs(:,1), BlueObjs(:,2), BlueObjs(:,3), markerSizeBlue, ...
                'b', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 1);
        end

        if ~isempty(GreenObjs)
            scatter3(ax, GreenObjs(:,1), GreenObjs(:,2), GreenObjs(:,3), markerSizeGreen, ...
                'g', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 1, 'MarkerEdgeAlpha', 1, 'LineWidth', 1.5);
        end
    end

    %% Set axis limits
    AllObjs = [RedObjs; BlueObjs; GreenObjs];
    if ~isempty(AllObjs)
        ax_max = max(AllObjs, [], 1);
        ax_min = min(AllObjs, [], 1);

        eps_factor = 0.05;
        abs_epsilon = 1e-6;

        range = ax_max - ax_min;
        for d = 1:min(M, 3)
            if range(d) <= 0 || ~isfinite(range(d))
                val = ax_min(d);
                eps_val = max(abs(val) * eps_factor, abs_epsilon);
                ax_min(d) = val - eps_val;
                ax_max(d) = val + eps_val;
            else
                margin = range(d) * eps_factor;
                ax_min(d) = ax_min(d) - margin;
                ax_max(d) = ax_max(d) + margin;
            end
        end

        xlim(ax, [ax_min(1) ax_max(1)]);
        ylim(ax, [ax_min(2) ax_max(2)]);
        if M >= 3
            zlim(ax, [ax_min(3) ax_max(3)]);
        end
    end

    %% Legend
    h_handles = [];
    h_labels = {};

    nRed = size(RedObjs, 1);
    nBlue = size(BlueObjs, 1);
    nGreen = size(GreenObjs, 1);
    nTotal = nRed + nBlue + nGreen;

    if M == 2
        h_red = plot(ax, NaN, NaN, 'o', ...
            'MarkerSize', 12, ...
            'MarkerEdgeColor', 'k', ...
            'MarkerFaceColor', 'r');
        h_handles(end+1) = h_red;
        h_labels{end+1} = sprintf('Other survivors (%d/%d)', nRed, nTotal);

        h_blue = plot(ax, NaN, NaN, 'o', ...
            'MarkerSize', 12, ...
            'MarkerEdgeColor', 'k', ...
            'MarkerFaceColor', 'b');
        h_handles(end+1) = h_blue;
        h_labels{end+1} = sprintf('Niched survivors (%d/%d)', nBlue, nTotal);

        h_green = plot(ax, NaN, NaN, 'o', ...
            'MarkerSize', 14, ...
            'MarkerEdgeColor', 'k', ...
            'MarkerFaceColor', 'g', ...
            'LineWidth', 1.5);
        h_handles(end+1) = h_green;
        h_labels{end+1} = sprintf('DSS-selected (%d/%d)', nGreen, nTotal);
    else
        h_red = plot3(ax, NaN, NaN, NaN, 'o', ...
            'MarkerSize', 12, ...
            'MarkerEdgeColor', 'k', ...
            'MarkerFaceColor', 'r');
        h_handles(end+1) = h_red;
        h_labels{end+1} = sprintf('Other survivors (%d/%d)', nRed, nTotal);

        h_blue = plot3(ax, NaN, NaN, NaN, 'o', ...
            'MarkerSize', 12, ...
            'MarkerEdgeColor', 'k', ...
            'MarkerFaceColor', 'b');
        h_handles(end+1) = h_blue;
        h_labels{end+1} = sprintf('Niched survivors (%d/%d)', nBlue, nTotal);

        h_green = plot3(ax, NaN, NaN, NaN, 'o', ...
            'MarkerSize', 14, ...
            'MarkerEdgeColor', 'k', ...
            'MarkerFaceColor', 'g', ...
            'LineWidth', 1.5);
        h_handles(end+1) = h_green;
        h_labels{end+1} = sprintf('DSS-selected (%d/%d)', nGreen, nTotal);
    end

    legend(ax, h_handles, h_labels, 'Location', 'southoutside');

    %% 3D settings
    if M >= 3
        axis(ax, 'vis3d');
        box(ax, 'on');
        lighting(ax, 'gouraud');
        light('Position', [1 1 1], 'Style', 'infinite');
        light('Position', [-1 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);
    end

    %% Customize position
    set(ax, 'Position', [0.12 0.25 0.80 0.68]);
    set(ax.Legend, 'Position', [0.02 0.02 0.96 0.10]);

    %% Save if path provided
    if ~isempty(savePath)
        exportgraphics(fig, savePath, 'Resolution', 300);
        close(fig);
    end
end
