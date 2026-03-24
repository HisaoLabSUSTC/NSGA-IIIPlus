%% Figure 5b: Algorithm population on a single problem (median-HV run)
%
%  Loads the median-HV run from ProduceImage/MedianHVResults/,
%  reconstructs normalization state from ProduceImage/Data/,
%  and plots the final population with PF overlay.

% close all; clc;

%% ---- Configuration (change these) ----
algSpec = generateAlgorithm();           
% algSpec = generateAlgorithm('area1', 'XYZ');           
% algSpec = generateAlgorithm('area1', 'XYZ', 'momentum', 'tikhonov');           
% algSpec = generateAlgorithm('area1', 'XYZ', 'momentum', 'tikhonov', 'useDSS', true);           

ph      = @RWA7;                         
M       = 3;                             % Number of objectives

%% ---- Sizing constants ----
S  = 8.8;
fs = 6.5 * S;
ms_pf = 25;                              % PF overlay marker size

%% ---- Derived names ----
algName     = getAlgorithmName(algSpec);
problemName = func2str(ph);

%% ---- Paths (all relative to ProduceImage/) ----
hvFile    = fullfile('ProduceImage', 'MedianHVResults', sprintf('MedianHV_%s.mat', algName));
dataDir   = fullfile('ProduceImage', 'Data', algName);
boundPath = fullfile('ProduceImage', 'Bounds', sprintf('bound-%s.mat', problemName));

%% ---- Load median HV metadata ----
hvData = load(hvFile);  % contains 'results' struct
if ~isfield(hvData.results, problemName)
    error('Problem %s not found in median HV data for %s.', problemName, algName);
end
medianFileHV = hvData.results.(problemName).medianFile;
dataFilename = erase(medianFileHV, 'HV_');
dataPath     = fullfile(dataDir, dataFilename);

%% ---- Load population data ----
data = load(dataPath, 'result');
resultMatrix = data.result;
lastPop = resultMatrix{end, 2};
FE      = resultMatrix{end, 1};
D       = size(lastPop.decs, 2);
N       = size(lastPop, 2);

%% ---- Load bounds ----
bounds = load(boundPath);

%% ---- Create problem instance ----
Problem = ph('M', M, 'D', D);

%% ---- Reference vectors ----
[Z, ~] = UniformPoint(N, M);

%% ---- Reconstruct normalization state ----
NormStruct = alg2norm(algName, N, M);

% First generation
Pop = resultMatrix{1, 2};
nds = nds_preprocess(Pop);
norm_update(algName, Problem, NormStruct, Pop, nds);

% Subsequent generations
n_gens = size(resultMatrix, 1);
for g = 2:n_gens
    Pop       = resultMatrix{g-1, 2};
    Offspring = resultMatrix{g, 3};
    Mixture   = [Pop, Offspring];
    nds       = nds_preprocess(Mixture);
    norm_update(algName, Problem, NormStruct, Mixture, nds);
end

%% ---- Visualize (creates its own figure via PreprocessProductionImage) ----
Algorithm = str2func(algName);
VisualizeMindistPopulation(Algorithm, lastPop, Z, Problem, FE, NormStruct);

fig = gcf; ax = gca;

%% ---- Axes formatting (using bounds) ----
set(ax.Title, 'String', '');
axis(ax, 'square');

set(ax, 'XLim', bounds.XBounds, 'XTick', bounds.XBounds);
set(ax, 'YLim', bounds.YBounds, 'YTick', bounds.YBounds);
set(ax, 'XTickLabelRotation', 0);
set(ax, 'YTickLabelRotation', 0);

if M >= 3 && isfield(bounds, 'ZBounds')
    set(ax, 'ZLim', bounds.ZBounds, 'ZTick', bounds.ZBounds);
    set(ax, 'ZTickLabelRotation', 0);
end

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

if M == 2
    set(ax, 'Position', [0.32 0.35 0.36 0.57]);
    set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
else
    set(ax, 'Position', [0.2 0.35 0.6 0.6]);
    set(ax.Legend, 'Position', [0.315 0.08 0.365 0.12]);
end

%% ---- Annotations ----
%% RWA4
% algo_text = text(-499.2791480294836,2442.426388472508,-326.6685537389894, ...
%     "NSGA-III$^+$", ...
%     'Interpreter', 'latex', 'FontSize', fs*0.9, 'Color', cPF, 'HorizontalAlignment', 'center');

%% RWA4
% algo_text = text(-499.2791480294836,2442.426388472508,-326.6685537389894, ...
%     "NSGA-III", ...
%     'Interpreter', 'latex', 'FontSize', fs*0.9, 'Color', cPF, 'HorizontalAlignment', 'center');


%% RWA7
% algo_text = text(0.313195893908254,0.239527100112774,-0.936832754427691, ...
%     "NSGA-III$^+$", ...
%     'Interpreter', 'latex', 'FontSize', fs*0.9, 'Color', cPF, 'HorizontalAlignment', 'center');


%% RWA7
algo_text = text(0.313195893908254,0.239527100112774,-0.936832754427691, ...
    "NSGA-III", ...
    'Interpreter', 'latex', 'FontSize', fs*0.9, 'Color', cPF, 'HorizontalAlignment', 'center');

%% ---- PF overlay ----
hold(ax, 'on');
optimum = getOptimumPoints(Problem, Problem.M, Problem.D);
optimum = optimum(NDSort(optimum, 1) == 1, :);

aPF = 0.3;  % PF transparency
if size(optimum, 1) > 1 && M < 4
    if M == 2
        scatter(ax, optimum(:,1), optimum(:,2), ms_pf, [0 0 0], 'filled', ...
            'MarkerFaceAlpha', aPF, 'MarkerEdgeAlpha', aPF, ...
            'HandleVisibility', 'off');
    elseif M == 3
        scatter3(ax, optimum(:,1), optimum(:,2), optimum(:,3), ms_pf, [0 0 0], 'filled', ...
            'MarkerFaceAlpha', aPF, 'MarkerEdgeAlpha', aPF, ...
            'HandleVisibility', 'off');
    end
end
hold(ax, 'off');

drawnow;

%% ---- Export ----
exportgraphics(fig, './ProduceImage/Images/FigureRWA7-NSGAIII.png', 'Resolution', 300);
close(fig);
