%% Figure 2: Corner solutions vs. Expected corner solutions

close all; clc;

%% ---- Colours ----
cPop     = [0.85  0.15  0.15];   % population (all red)
cEst     = [0.85  0.55  0.15];   % estimated points (orange)
cTrue    = [0.13  0.55  0.20];   % true points (green)
cPF      = [0.00  0.00  0.00];   % Pareto front

%% ---- Sizing constants ----
S  = 8.8;                   % scale factor (matches PreprocessProductionImage)
% fs = 6.5 * S; % at home               % annotation font size
fs = 4.0 * S;               % annotation font size
ms_pop     = 300;            % population marker area (scatter)
ms_special = 1500;            % special point marker area (scatter)
lms = 26;                    % legend marker size (plot-based, controls icon size)
lw_pf     = 8;               % Pareto front line width
lw_conn   = 5;               % connection lines (dotted)
lw_edge   = 1.5;             % marker edge width

%% ---- Data ----
% Population
ph = @DTLZ1;
Problem = ph();

HS = load('ProduceImage/DTLZ1-Corner.mat');

pobjs1 = HS.PopObj1;
pobjs = HS.PopObj2;
pobjs = [pobjs;pobjs1];

exp_corner_idx = [42, 15, 49];
mask = true(1,size(pobjs,1));
mask(exp_corner_idx) = false;

pobjs2 = pobjs(~mask,:);
pobjs = pobjs(mask,:);

%% ---- Figure ----
PreprocessProductionImage(0.35, 1, S, true);
% PreprocessProductionImage(0.5, 1, S, false); % AT HOME
fig = gcf; ax = gca;
cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

% --- Layer 1: Population (all red circles) ---
scatter3(ax, pobjs(:,1), pobjs(:,2), pobjs(:,3), ms_pop/2, cPop, 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', lw_edge, 'HandleVisibility', 'off');

scatter3(ax, pobjs2(:,1), pobjs2(:,2), pobjs2(:,3), ms_pop*2, cTrue, 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', lw_edge, 'HandleVisibility', 'off');

%% ---- Annotations ----
% 
xmin_objs = pobjs2(1,:);
ymin_objs = pobjs2(2,:);
zmin_objs = pobjs2(3,:);

xmin_text = text(xmin_objs(1)+0.16, xmin_objs(2)-0.16, xmin_objs(3)-0.08, ...
    "$[0, 0.63, 0]$", ...
    'Interpreter', 'latex', 'FontSize', fs*0.8, 'Color', cTrue);

ymin_text = text(ymin_objs(1)-0.01, ymin_objs(2)+0.01, ymin_objs(3)-0.06, ...
    "$[0, 0, 0.59]$", ...
    'Interpreter', 'latex', 'FontSize', fs*0.8, 'Color', cTrue);

zmin_text = text(zmin_objs(1)-0.0, zmin_objs(2)+0.0, zmin_objs(3)-0.08, ...
    "$[0.62, 0, 0]$", ...
    'Interpreter', 'latex', 'FontSize', fs*0.8, 'Color', cTrue);


%% ---- Axes formatting ----
xlabel(ax, "$f_1$", 'Interpreter', 'latex', 'FontSize', fs * 1.2);
ylabel(ax, "$f_2$", 'Interpreter', 'latex', 'FontSize', fs * 1.2);
zlabel(ax, "$f_3$", 'Interpreter', 'latex', 'FontSize', fs * 1.2);
% set(ax.YLabel, 'Rotation', 0, 'VerticalAlignment', 'middle');
% set(ax.YLabel, 'Position', ax.YLabel.Position - [0.6, 0, 0])
set(ax.ZLabel, 'Rotation', 0, 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left');
set(ax.XLabel, 'Position', [0.25, 0.75, -0.1]);
set(ax.YLabel, 'Position', [0.75, 0.25, -0.1]);
% set(ax.ZLabel, 'Position', ax.ZLabel.Position)

set(ax.Title, 'String', '');
set(ax, 'XLim', [-0.1 0.7], 'XTick', [0 0.5], 'XTickLabel', {0, 0.5});
set(ax, 'YLim', [-0.1 0.7], 'YTick', [0 0.5], 'YTickLabel', {0, 0.5});
set(ax, 'ZLim', [-0.1 0.7], 'ZTick', [0 0.5], 'ZTickLabel', {0, 0.5});

set(ax, 'XTickLabelRotation', 0);
set(ax, 'YTickLabelRotation', 0);
set(ax, 'ZTickLabelRotation', 0);
% set(ax, 'Position', [0.10 0.10 0.85 0.86]);

view(ax, 135, 35);

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
% set(lgd, 'Position', [0.39784711388456,0.726422823701537,0.22418096723869,0.146130760790054]);

%% ---- Export ----
exportgraphics(fig, './ProduceImage/Images/Figure2b.png', 'Resolution', 300);
close(fig);
