%% Figure 1: Worst-of-nondominated-front prior in translated objective space
%
%  Key message: The prior nadir z^circ_p is the bounding box of the
%  nondominated front. As corner solutions converge to the PF corners,
%  the prior converges to the true nadir.
%
%  Pareto front: f'_2 = (2 - sqrt(f'_1))^2,  domain [0, 4]
%  True ideal (translated): (0, 0)
%  True nadir (translated): (4, 4)

close all; clc;

%% ---- Colours ----
cPop     = [0.85  0.15  0.15];   % population (all red)
cEst     = [0.85  0.55  0.15];   % estimated points (orange)
cTrue    = [0.13  0.55  0.20];   % true points (green)
cPF      = [0.00  0.00  0.00];   % Pareto front

%% ---- Sizing constants ----
S  = 8.8;                   % scale factor (matches PreprocessProductionImage)
fs = 6.5 * S;               % annotation font size
ms_pop     = 700;            % population marker area (scatter)
ms_special = 1500;            % special point marker area (scatter)
lms = 26;                    % legend marker size (plot-based, controls icon size)
lw_pf     = 8;               % Pareto front line width
lw_conn   = 5;               % connection lines (dotted)
lw_edge   = 1.5;             % marker edge width

%% ---- Data ----
% Pareto front
t   = linspace(0, 4, 500);
pf1 = t;
pf2 = (2 - sqrt(t)).^2;

% Population on the front (7 solutions, two near corners)
pop_f1 = [0.12,  0.50,  1.10,  1.80,  2.50,  3.20,  3.70];
pop_f2 = (2 - sqrt(pop_f1)).^2;

% Corner solutions (the two extremes)
corners_x = [pop_f1(1), pop_f1(end)];
corners_y = [pop_f2(1), pop_f2(end)];

% Estimated ideal = min per objective from population
ideal_est = [min(pop_f1), min(pop_f2)];

% Estimated nadir (prior) = max per objective from population
nadir_est = [max(pop_f1), max(pop_f2)];

% True points
ideal_true = [0, 0];
nadir_true = [4, 4];

%% ---- Figure ----
PreprocessProductionImage(0.6, 0.5, S);
fig = gcf; ax = gca;
cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

% --- Layer 1: Connection lines (dotted, orange) ---
% From estimated ideal to the two corner solutions
for i = 1:2
    plot(ax, [ideal_est(1) corners_x(i)], [ideal_est(2) corners_y(i)], ':', ...
         'Color', cEst, 'LineWidth', lw_conn, 'HandleVisibility', 'off');
end
% From estimated nadir to the two corner solutions
for i = 1:2
    plot(ax, [nadir_est(1) corners_x(i)], [nadir_est(2) corners_y(i)], ':', ...
         'Color', cEst, 'LineWidth', lw_conn, 'HandleVisibility', 'off');
end

% --- Layer 2: Pareto front ---
plot(ax, pf1, pf2, '-', 'Color', cPF, 'LineWidth', lw_pf, ...
     'HandleVisibility', 'off');

% --- Layer 3: Population (all red circles) ---
scatter(ax, pop_f1, pop_f2, ms_pop, cPop, 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', lw_edge, 'HandleVisibility', 'off');

% --- Layer 4: Special points ---
% True ideal (green diamond)
scatter(ax, ideal_true(1), ideal_true(2), ms_special, cTrue, 'filled', 'd', ...
        'MarkerEdgeColor', 'k', 'LineWidth', lw_edge, 'HandleVisibility', 'off');

% True nadir (green square)
scatter(ax, nadir_true(1), nadir_true(2), ms_special, cTrue, 'filled', 's', ...
        'MarkerEdgeColor', 'k', 'LineWidth', lw_edge, 'HandleVisibility', 'off');

% Estimated ideal (orange diamond)
scatter(ax, ideal_est(1), ideal_est(2), ms_special, cEst, 'filled', 'd', ...
        'MarkerEdgeColor', 'k', 'LineWidth', lw_edge, 'HandleVisibility', 'off');

% Estimated nadir / prior (orange square)
scatter(ax, nadir_est(1), nadir_est(2), ms_special, cEst, 'filled', 's', ...
        'MarkerEdgeColor', 'k', 'LineWidth', lw_edge, 'HandleVisibility', 'off');

%% ---- Annotations ----
% Prior first objective
% text(0.88, 3.15, ...
%     "$\max_{\mathbf{x} \in h_{1}^{(t)}} f'_{1}(\mathbf{x})$", ...
%     'Interpreter', 'latex', 'FontSize', fs*0.8, 'Color', cPop);
% 
% text(1.59, 1.47, ...
%     "$\max_{\mathbf{x} \in h_{1}^{(t)}} f'_{2}(\mathbf{x})$", ...
%     'Interpreter', 'latex', 'FontSize', fs*0.8, 'Color', cPop);

% % True ideal label
% text(ideal_true(1) + 0.30, ideal_true(2) + 0.35, ...
%      '$\mathbf{z}^*$', ...
%      'Interpreter', 'latex', 'FontSize', fs, 'Color', cTrue);
% 
% % True nadir label
% text(nadir_true(1) + 0.15, nadir_true(2) - 0.50, ...
%      '$\mathbf{z}^\circ$', ...
%      'Interpreter', 'latex', 'FontSize', fs, 'Color', cTrue, ...
%      'HorizontalAlignment', 'left');
% 
% % Estimated ideal label
% text(ideal_est(1) + 0.35, ideal_est(2) - 0.45, ...
%      '$\mathbf{z}^*_t$', ...
%      'Interpreter', 'latex', 'FontSize', fs, 'Color', cEst);
% 
% % Estimated nadir label
% text(nadir_est(1) - 0.15, nadir_est(2) + 0.55, ...
%      '$\mathbf{z}^\circ_p$', ...
%      'Interpreter', 'latex', 'FontSize', fs, 'Color', cEst, ...
%      'HorizontalAlignment', 'center');

%% ---- Axes formatting ----
xlabel(ax, "$f'_1$", 'Interpreter', 'latex', 'FontSize', fs * 1.1);
ylabel(ax, "$f'_2$", 'Interpreter', 'latex', 'FontSize', fs * 1.1);

set(ax.XLabel, 'Rotation', 0, 'VerticalAlignment', 'top');
set(ax.YLabel, 'Rotation', 0, 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'Right');
% set(ax.YLabel, 'Position', ax.YLabel.Position - [0.6, 0, 0])

set(ax.Title, 'String', '');
set(ax, 'XLim', [-0.6 4.8], 'XTick', [0 1 2 3 4], 'XTickLabel', {});
set(ax, 'YLim', [-0.6 4.8], 'YTick', [0 1 2 3 4], 'YTickLabel', {});
set(ax, 'XTickLabelRotation', 0);
set(ax, 'YTickLabelRotation', 0);
set(ax, 'Position', [0.07 0.13 0.92 0.86]);

%% ---- Legend (plot-based proxy handles for large icons) ----
h_pf = plot(ax, NaN, NaN, '-', 'Color', cPF, 'LineWidth', lw_pf);

h_pop = plot(ax, NaN, NaN, 'o', ...
             'MarkerSize', lms, ...
             'MarkerFaceColor', cPop, 'MarkerEdgeColor', 'k');

h_tideal = plot(ax, NaN, NaN, 'd', ...
                'MarkerSize', lms, ...
                'MarkerFaceColor', cTrue, 'MarkerEdgeColor', 'k');

h_tnadir = plot(ax, NaN, NaN, 's', ...
                'MarkerSize', lms, ...
                'MarkerFaceColor', cTrue, 'MarkerEdgeColor', 'k');

h_eideal = plot(ax, NaN, NaN, 'd', ...
                'MarkerSize', lms, ...
                'MarkerFaceColor', cEst, 'MarkerEdgeColor', 'k');

h_enadir = plot(ax, NaN, NaN, 's', ...
                'MarkerSize', lms, ...
                'MarkerFaceColor', cEst, 'MarkerEdgeColor', 'k');

lgd = legend(ax, [h_pf, h_pop, h_tideal, h_tnadir, h_eideal, h_enadir], ...
       {'Pareto front', 'Nondominated front ($h_1^{(t)}$)', ...
        'True ideal point $\mathbf{z}^*$', 'True nadir point $\mathbf{z}^\circ$', ...
        'Estimated ideal point $\mathbf{z}^*_t$', 'Inverse of prior $\mathbf{1}^m \oslash \mathbf{p}^*$'}, ...
       'Interpreter', 'latex', 'FontSize', fs * 0.6, ...
       'EdgeColor', [0.8 0.8 0.8], ...
       'Location', 'eastoutside');

%% ---- Export ----
exportgraphics(fig, './ProduceImage/Images/prior_depiction.png', 'Resolution', 300);
close(fig);
