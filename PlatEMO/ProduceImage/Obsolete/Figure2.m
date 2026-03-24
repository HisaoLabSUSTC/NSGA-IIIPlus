%% Generate Pl-NSGA-III first.
%% Step 1: verify median HV run 
%% change N = {91, 105, 120}
% N=120;
% PlatEMODir = fullfile(sprintf('./Tentative/2025-11-20-IDTLZ2ThreePopulationSizes/N%d/NSGAIIIwH', N)); 
% PlatEMOFiles = dir(fullfile(PlatEMODir, '*.mat'));
% n_files = numel(PlatEMOFiles);
% ph = @IDTLZ2; Problem = ph(); M=Problem.M; D=Problem.D;
% [~, ref] = GetPFnRef(Problem);
% 
% HVs = zeros(1, n_files);
% for i = 1:n_files
%     PlatEMOData = load(fullfile(PlatEMODir, PlatEMOFiles(i).name));
%     objs = PlatEMOData.result{end, 2}.objs;
%     HVs(i) = stk_dominatedhv(objs, ref);
% end
% 
% medHV = median(HVs);
% [~, nearestIdx] = min(abs(HVs - medHV));
% disp(nearestIdx);

%% Step 2: Generate PlatEMO plots
%% Comment above & Change appropriate name below
% % nearestIdx = 7;
% MedFile = sprintf('NSGAIIIwH_IDTLZ2_M3_D12_%d.mat', nearestIdx);
% resultMatrix = load(fullfile(PlatEMODir, MedFile)).result;
% [Z, ~] = UniformPoint(N, M);
% NormStruct = PlNormalizationHistory(M,N);
% 
% algName = 'NSGAIIIwH'; Algorithm = str2func(algName);
% n_gens = size(resultMatrix, 1); 
% Population = resultMatrix{1, 2};
% nds = nds_preprocess(Population);
% norm_update(algName, Problem, NormStruct, Population, nds);
% 
% for g = 2:n_gens
%     Population = resultMatrix{g-1, 2};
%     Offspring = resultMatrix{g, 3};
%     Mixture = [Population, Offspring];
%     nds = nds_preprocess(Mixture);
%     norm_update(algName, Problem, NormStruct, Mixture, nds);
% end
% 
% Population = resultMatrix{end, 2}; FE = resultMatrix{end, 1};
% PreprocessProductionImage(1/3, 2, 8.8);
% VisualizeMindistPopulation(Algorithm, Population, Z, Problem, FE, NormStruct)
% fig = gcf; ax = gca;
% 
% % Customize plot attributes!
% % set(ax.Title, 'String', sprintf('Pl-NSGA-III\nat FE:%d', FE));
% set(ax.Title, 'String', '');
% lims = [0 1.1];
% set(ax, 'XLim', lims);set(ax, 'YLim', lims);set(ax, 'ZLim', lims);
% ticks = [0 1.00];
% set(ax, 'XTick', ticks);set(ax, 'YTick', ticks);set(ax, 'ZTick', ticks);
% set(ax.Legend, 'Position', [0.02 0.0000 0.9570 0.1993])
% set(ax, 'Position', [0.05 0.35 0.90 0.60])
% set(ax.Legend, 'Position', [0.02 0.05 0.9570 0.1093])
% % set(ax.Title, 'FontWeight','normal')
% set(ax, 'XTickLabelRotation', 0);
% set(ax, 'YTickLabelRotation', 0);
% set(ax, 'ZTickLabelRotation', 0);
% set(ax.XLabel, 'Rotation', 0, 'Position', [0.6, 1.2, 0.0])
% set(ax.YLabel, 'Rotation', 0, 'Position', [1.2, 0.6, 0.0])
% set(ax.ZLabel, 'Rotation', 0, 'Position', [0.7, -0.7, -0.1])
% 
% 
% filename = sprintf('./MP-NSGAIIIwH-IDTLZ2-M3-D12-N%d.png', N);
% exportgraphics(fig, filename, 'Resolution', 300);
% close(fig);

%% Step 3: Generate pymoo plots
%% change N = {91, 105, 120}
% N = 91;
% pymooDir = fullfile('./Tentative/2025-11-20-IDTLZ2ThreePopulationSizes/Pymoo'); 
% pymooFile = dir(fullfile(pymooDir, ...
%             sprintf('NSGA3_InvertedDTLZ2_N%d_FE100000_*.mat',N)));
% 
% n_files = numel(pymooFile);
% pymooData = load(fullfile(pymooDir, pymooFile(1).name));
% resultMatrix = pymooData.result;
% [Z, ~] = UniformPoint(N,M);
% NormStruct = PyNormalizationHistory(M);
% 
% algName = 'PyNSGAIIIwH'; Algorithm = str2func(algName);
% n_gens = size(resultMatrix, 1);
% Population = Problem.Evaluation(resultMatrix{1, 2});
% nds = nds_preprocess(Population);
% norm_update(algName, Problem, NormStruct, Population, nds);
% 
% for g = 2:n_gens
%     Population = Problem.Evaluation(resultMatrix{g-1, 2});
%     Offspring = Problem.Evaluation(resultMatrix{g, 3});
%     Mixture = [Population, Offspring];
%     nds = nds_preprocess(Mixture);
%     norm_update(algName, Problem, NormStruct, Mixture, nds);
% end
% 
% Population = Problem.Evaluation(resultMatrix{end, 2}); FE = resultMatrix{end, 1};
% PreprocessProductionImage(1/3, 2, 8.8);
% VisualizeMindistPopulation(Algorithm, Population, Z, Problem, FE, NormStruct)
% fig = gcf; ax = gca;
% 
% % Customize plot attributes!
% % set(fig, 'Position' )
% % set(ax.Title, 'String', sprintf('Py-NSGA-III\nat FE:%d', FE));
% set(ax.Title, 'String', '');
% lims = [0 1.1];
% set(ax, 'XLim', lims);set(ax, 'YLim', lims);set(ax, 'ZLim', lims);
% ticks = [0 1.00];
% set(ax, 'XTick', ticks);set(ax, 'YTick', ticks);set(ax, 'ZTick', ticks);
% set(ax, 'Position', [0.05 0.35 0.90 0.60])
% set(ax.Legend, 'Position', [0.02 0.05 0.9570 0.1093])
% % set(ax.Title, 'FontWeight','normal')
% set(ax, 'XTickLabelRotation', 0);
% set(ax, 'YTickLabelRotation', 0);
% set(ax, 'ZTickLabelRotation', 0);
% set(ax.XLabel, 'Rotation', 0, 'Position', [0.6, 1.2, 0.0])
% set(ax.YLabel, 'Rotation', 0, 'Position', [1.2, 0.6, 0.0])
% set(ax.ZLabel, 'Rotation', 0, 'Position', [0.7, -0.7, -0.1])
% 
% filename = sprintf('./MP-PyNSGAIIIwH-IDTLZ2-M3-D12-N%d.png', N);
% exportgraphics(fig, filename, 'Resolution', 300);
% close(fig);

