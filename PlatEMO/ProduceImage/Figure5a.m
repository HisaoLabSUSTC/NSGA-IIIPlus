%% Figure 5a: Reference Pareto Front
%
%  Plots the stored reference PF for a single problem.
%  Uses bounds from ProduceImage/Bounds/ for consistent axis limits.

close all; clc;

%% ---- Configuration (change these) ----
ph = @RWA7;            % Problem handle
M  = 3;                % Number of objectives

%% ---- Sizing constants ----
S  = 8.8;
fs = 6.5 * S;
ms_pf = 25;            % PF marker size

%% ---- Data ----
problemName = func2str(ph);

% Load reference Pareto front
[PF, ~, ~] = loadReferencePF(problemName);

% Load bounds (from ProduceImage/Bounds/)
boundPath = fullfile('ProduceImage', 'Bounds', sprintf('bound-%s.mat', problemName));
bounds = load(boundPath);

%% ---- Figure ----
PreprocessProductionImage(0.5, 1, S);
fig = gcf; ax = gca;
cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
axis(ax, 'square');

cPF = [0 0 0];           % PF color
aPF = 0.3;               % PF transparency

if M == 2
    scatter(ax, PF(:,1), PF(:,2), ms_pf, cPF, 'filled', ...
        'MarkerFaceAlpha', aPF, 'MarkerEdgeAlpha', aPF);
    view(ax, 2);
elseif M == 3
    scatter3(ax, PF(:,1), PF(:,2), PF(:,3), ms_pf, cPF, 'filled', ...
        'MarkerFaceAlpha', aPF, 'MarkerEdgeAlpha', aPF);
    view(ax, 135, 30);
    box(ax, 'on');
    lighting(ax, 'gouraud');
    light('Position', [1 1 1], 'Style', 'infinite');
end

%% ---- Axes formatting ----
xlabel(ax, '$f_1$', 'Interpreter', 'latex', 'FontSize', fs * 1.1);
ylabel(ax, '$f_2$', 'Interpreter', 'latex', 'FontSize', fs * 1.1);
if M >= 3
    zlabel(ax, '$f_3$', 'Interpreter', 'latex', 'FontSize', fs * 1.1);
    set(ax.XLabel, 'Rotation', 0, 'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', 'center');
    set(ax.YLabel, 'Rotation', 0, 'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', 'center');
    set(ax.ZLabel, 'Rotation', 0, 'VerticalAlignment', 'middle', ...
        'HorizontalAlignment', 'center');
    set(ax, 'XTickLabel', {0, 1})
    set(ax, 'YTickLabel', {0, 1})
    set(ax, 'ZTickLabel', {0, 1})
end

set(ax.Title, 'String', '');
set(ax, 'XLim', bounds.XBounds, 'XTick', bounds.XBounds);
set(ax, 'YLim', bounds.YBounds, 'YTick', bounds.YBounds);
if M >= 3 && isfield(bounds, 'ZBounds')
    set(ax, 'ZLim', bounds.ZBounds, 'ZTick', bounds.ZBounds);
    set(ax, 'ZTickLabelRotation', 0);
end
set(ax, 'XTickLabelRotation', 0);
set(ax, 'YTickLabelRotation', 0);

if M == 2
    set(ax, 'Position', [0.32 0.35 0.36 0.57]);
else
    set(ax, 'Position', [0.2 0.35 0.6 0.6]);
end

%% ---- Legend ----
hold(ax, 'on');
h1 = plot(ax, NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');
h2 = plot(ax, NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');
% lgd = legend(ax, [h1, h2], ...
%     sprintf('PF of %s', problemName), ...
%     sprintf('%d pts shown', size(PF, 1)), ...
%     'Location', 'south', ...
%     'Interpreter', 'latex');
% 
% if M == 2
%     set(lgd, 'Position', [0.3 0.08 0.4 0.1]);
% else
%     set(lgd, 'Position', [0.315 0.08 0.365 0.12]);
% end

%% ---- Export ----
exportgraphics(fig, './ProduceImage/Images/FigureRWA7-PF.png', 'Resolution', 300);
close(fig);
