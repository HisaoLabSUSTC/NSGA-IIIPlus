%% Figure 2: Corner solutions vs. Expected corner solutions

close all; clc;

%% ---- Colours ----
cPop     = [0.85  0.15  0.15];   % population (all red)
cEst     = [0.85  0.55  0.15];   % estimated points (orange)
cTrue    = [0.13  0.55  0.20];   % true points (green)
cPF      = [0.00  0.00  0.00];   % Pareto front

%% ---- Sizing constants ----
S  = 8.8;                   % scale factor (matches PreprocessProductionImage)
% fs = 6.5 * S;               % annotation font size
fs = 4.0 * S;               % annotation font size
ms_pop     = 300;            % population marker area (scatter)
ms_special = 1500;            % special point marker area (scatter)
lms = 26;                    % legend marker size (plot-based, controls icon size)
lw_pf     = 8;               % Pareto front line width
lw_conn   = 5;               % connection lines (dotted)
lw_edge   = 1.5;             % marker edge width

%% ---- Data ----
% Population
ph = @IDTLZ1;
ah = {generateAlgorithm('area1', '', 'useDSS', true)};

params = struct('FE', 100000, 'N', 120, 'M', 3, 'runs', 1);
FE = getFieldDefault(params, 'FE', 10000);
N = getFieldDefault(params, 'N', 120);
M = getFieldDefault(params, 'M', 3);
run_num = 1; runs = run_num;
save_interval = 0;

generateInitialPopulations({ph}, N, M, runs);
pro_inst = ph('M', M); prob_name = func2str(ph);
initial_pop_path = fullfile('Info', 'InitialPopulation', ...
    sprintf('HS-%s_M%d_D%d_%d.mat', prob_name, pro_inst.M, pro_inst.D, run_num));
algorithmSpec = ah{1};
algorithm_with_param = prepareAlgorithmForPlatemo(algorithmSpec, initial_pop_path);
platemo('problem', ph, 'N', N, 'M', M, ...
                'save', save_interval, 'maxFE', FE, ...
                'algorithm', algorithm_with_param, 'run', run_num);


%% ---- Figure ----
fig = gcf; ax = gca;
axis('square')
%% ---- Annotations ----
algo_text = text(0.0, 0.0, 0.37, ...
    "Dss-NSGA-III", ...
    'Interpreter', 'latex', 'FontSize', fs*0.9, 'Color', cPF, 'HorizontalAlignment', 'center');


%% ---- Axes formatting ----
xlabel(ax, "$f_1$", 'Interpreter', 'latex', 'FontSize', fs * 1.1);
ylabel(ax, "$f_2$", 'Interpreter', 'latex', 'FontSize', fs * 1.1);
zlabel(ax, "$f_3$", 'Interpreter', 'latex', 'FontSize', fs * 1.1);
% set(ax.YLabel, 'Rotation', 0, 'VerticalAlignment', 'middle');
set(ax.XLabel, 'Position', [0.25, 0.5, 0])
set(ax.YLabel, 'Position', [0.5, 0.25, 0])
set(ax.ZLabel, 'Rotation', 0, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left');
% set(ax.ZLabel, 'Position', ax.ZLabel.Position)

set(ax.Title, 'String', '');
set(ax, 'XLim', [-0.001 0.501], 'XTick', [0 0.5], 'XTickLabel', {0 0.5});
set(ax, 'YLim', [-0.001 0.501], 'YTick', [0 0.5], 'YTickLabel', {0 0.5});
set(ax, 'ZLim', [-0.001 0.501], 'ZTick', [0 0.5], 'ZTickLabel', {0 0.5});

set(ax, 'XTickLabelRotation', 0);
set(ax, 'YTickLabelRotation', 0);
set(ax, 'ZTickLabelRotation', 0);
set(ax, 'Position', [0.10 0.2 0.85 0.80]);

view(ax, 135, 30);

%% ---- Legend (plot-based proxy handles for large icons) ----
% h_pf = plot(ax, NaN, NaN, '-', 'Color', cPF, 'LineWidth', lw_pf);
% 
% h_pop = plot(ax, NaN, NaN, 'o', ...
%              'MarkerSize', lms, ...
%              'MarkerFaceColor', cPop, 'MarkerEdgeColor', 'k');
% 
% h_tideal = plot(ax, NaN, NaN, 'd', ...
%                 'MarkerSize', lms, ...
%                 'MarkerFaceColor', cTrue, 'MarkerEdgeColor', 'k');
% 
% h_tnadir = plot(ax, NaN, NaN, 's', ...
%                 'MarkerSize', lms, ...
%                 'MarkerFaceColor', cTrue, 'MarkerEdgeColor', 'k');
% 
% h_eideal = plot(ax, NaN, NaN, 'd', ...
%                 'MarkerSize', lms, ...
%                 'MarkerFaceColor', cEst, 'MarkerEdgeColor', 'k');
% 
% h_enadir = plot(ax, NaN, NaN, 's', ...
%                 'MarkerSize', lms, ...
%                 'MarkerFaceColor', cEst, 'MarkerEdgeColor', 'k');
% 
% lgd = legend(ax, [h_pf, h_pop, h_tideal, h_tnadir, h_eideal, h_enadir], ...
%        {'Pareto front', 'Nondominated front ($h_1^{(t)}$)', ...
%         'True ideal point $\mathbf{z}^*$', 'True nadir point $\mathbf{z}^\circ$', ...
%         'Estimated ideal point $\mathbf{z}^*_t$', 'Inverse of prior $\mathbf{1}^m \oslash p^*$'}, ...
%        'Interpreter', 'latex', 'FontSize', fs * 0.6, ...
%        'EdgeColor', [0.8 0.8 0.8]);
% 
lgd = ax.Legend;
set(lgd, 'Position', [0.3139 0.0296 0.4122 0.0926]);

%% ---- Export ----
exportgraphics(fig, './ProduceImage/Images/Figure3b.png', 'Resolution', 300);
close(fig);

function val = getFieldDefault(s, field, default)
    if isfield(s, field)
        val = s.(field);
    else
        val = default;
    end
end