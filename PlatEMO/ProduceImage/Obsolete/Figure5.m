%% Stage 0: Generate initial population
% problems = {@DTLZ2}; ph = problems{1}; Problem = ph(); M = Problem.M;
% [W, N] = UniformPoint(20, M);
% runs = 1;
% generateInitialPopulations(problems, N, runs, ...
%     './Info/InitialPopulationForRefVis');

%% Stage 1: Initial Population
dataFile = "./Info/InitialPopulationForRefVis/HS-DTLZ2_M3_D12_1.mat";
ph = @DTLZ2; Problem = ph(); M = Problem.M;
N = 20; [Z, N] = UniformPoint(N, M); FE = N; 

data = load(dataFile);
hs = data.heuristic_solutions;

%% Switch 1: algorithm used
% algName = "NSGAIIIwH"; Algorithm = str2func(algName); NormStruct = PlNormalizationHistory(M,N);
% algName = "PyNSGAIIIwH"; Algorithm = str2func(algName); NormStruct = PyNormalizationHistory(M);
% algName = "GtNSGAIIIwH"; Algorithm = str2func(algName); NormStruct = PyNormalizationHistory(M);
% algName = 'MedNSGAIIIwH'; Algorithm = str2func(algName); NormStruct = MedNormHist(M);
algName = 'MedNSGAIIIwH'; Algorithm = str2func(algName); NormStruct = OrthoMedNormHist(M);
%% Switch 2: mode
mode = 'normal';
% mode = 'projection';
% mode = 'original';

Population = Problem.Evaluation(hs);
nds = nds_preprocess(Population);
norm_update(algName, Problem, NormStruct, Population, nds);

if strcmp(algName, 'GtNSGAIIIwH')
    % PopObjs = Population.objs;
    [PF, ~] = GetPFnRef(Problem, 10000);
    NormStruct.nadir_point = max(PF);
    NormStruct.ideal_point = min(PF);
end

PreprocessProductionImage(1/3.5, 1.2, 8.8);
if strcmp(mode, 'original')
    VisualizeOriginalPopulation(Algorithm, Population, Problem, FE);
else
    VisualizeNichedPopulationWithRefvec(Algorithm, Population, Z, Problem, FE, NormStruct);
end

fig=gcf; ax=gca;
% Customize plot attributes!
set(ax.Title, 'String', '');
lims = [0 1];
set(ax, 'XLim', lims);set(ax, 'YLim', lims);set(ax, 'ZLim', lims);
ticks = [0 1.00];
set(ax, 'XTick', ticks);set(ax, 'YTick', ticks);set(ax, 'ZTick', ticks);
set(ax, 'Position', [0.2 0.35 0.6 0.6])
set(ax.Legend, 'Position', [0.02 0.073 0.9570 0.0793])
% set(ax.Legend, 'Position', [0.02 0.073 0.9570 0.1093])
set(ax, 'XTickLabelRotation', 0);
set(ax, 'YTickLabelRotation', 0);
set(ax, 'ZTickLabelRotation', 0);
% set(ax.XLabel, 'Rotation', 0, 'Position', [0.6, 1.2, 0.0])
% set(ax.YLabel, 'Rotation', 0, 'Position', [1.23, 0.61, 0.0])
% set(ax.ZLabel, 'Rotation', 0, 'Position', [1.15, 0, 0.5])

if strcmp(mode, 'normal')
    if strcmp(algName, 'NSGAIIIwH')
        textArray = flip(ax.Children(13:27))
    elseif strcmp(algName, 'PyNSGAIIIwH')
        textArray = flip(ax.Children(13:27))
        textArray(8).Position = textArray(8).Position + [+0.065, -0.01, 0];
        textArray(15).Position = textArray(15).Position + [0, 0, 0.05];
        textArray(3).Position = textArray(3).Position + [0.02, 0, -0.05];
    elseif strcmp(algName, 'GtNSGAIIIwH')
        lims = [0 2.5];
        set(ax, 'XLim', lims);set(ax, 'YLim', lims);set(ax, 'ZLim', lims);
        ticks = [0 1.00 2.00];
        set(ax, 'XTick', ticks);set(ax, 'YTick', ticks);set(ax, 'ZTick', ticks);
        set(ax.XLabel, 'Rotation', 0, 'Position', 2.5*[0.3, 1.5, 0.05])
        set(ax.YLabel, 'Rotation', 0, 'Position', 2.5*[1.23, 0.61, 0.0])
        set(ax.ZLabel, 'Rotation', 0, 'Position', 2.5*[1.15, 0, 0.5])
        textArray = flip(ax.Children(12:26))
        textArray(1).Position = textArray(1).Position + [0.1, -0.02, 0];
        textArray(2).Position = textArray(2).Position + [-0.02, 0, 0.01];
        textArray(3).Position = textArray(3).Position + [0.02, 0, -0.12];
        textArray(4).Position = textArray(4).Position + [-0.02, 0, 0];
        textArray(5).Position = textArray(5).Position + [-0.02, 0, 0];
        textArray(6).Position = textArray(6).Position + [0.06, 0, -0.08];
        textArray(7).Position = textArray(7).Position + [-0.02, 0, 0];
        textArray(8).Position = textArray(8).Position + [-0.02, 0, 0];
        textArray(9).Position = textArray(9).Position + [0.06, 0, -0.08];
        textArray(10).Position = textArray(10).Position + [0.06, -0.14, 0.085];
        textArray(11).Position = textArray(11).Position + [-0.01, 0, 0.04];
        textArray(12).Position = textArray(12).Position + [0.03, 0, -0.09];
        textArray(13).Position = textArray(13).Position + [-0.04, -0.06, 0];
        textArray(14).Position = textArray(14).Position + [0.25, 0, 0.1];
        textArray(15).Position = textArray(15).Position + [0.13, -0.15, 0];
    end
end

if strcmp(mode, 'projection')
    view(ax, 90, 0);
    lims = [-0.5e-3 1];
    set(ax, 'XLim', lims);set(ax, 'YLim', lims);set(ax, 'ZLim', lims);
    set(ax.YLabel, 'Rotation', 0, 'Position', [0, 0.5, -0.03])
    set(ax.ZLabel, 'Rotation', 0, 'Position', [0, -0.1, 0.45])
    if strcmp(algName, 'NSGAIIIwH')
        textArray = flip(ax.Children(13:27))
        textArray(1).Position = textArray(1).Position + [0, 0, 0.01];
        textArray(2).Position = textArray(2).Position + [0, -0.047, -0.03];
        textArray(3).Position = textArray(3).Position + [0, -0.036, -0.02];
        textArray(4).Position = textArray(4).Position + [0, -0.037, -0.026];
        textArray(5).Position = textArray(5).Position + [0, -0.092, -0.044];
        textArray(6).Position = textArray(6).Position + [0, -0.035, +0.02];
        textArray(7).Position = textArray(7).Position + [0, -0.03, -0.017];
        textArray(8).Position = textArray(8).Position + [0, -0.03, -0.01];
        textArray(9).Position = textArray(9).Position + [0, -0.04, +0.05];
        textArray(10).Position = textArray(10).Position + [0, -0.04, -0.01];
        textArray(11).Position = textArray(11).Position + [0, -0.044, -0.01];
        textArray(12).Position = textArray(12).Position + [0, -0.02, +0.016];
        textArray(13).Position = textArray(13).Position + [0, -0.04, -0.02];
        textArray(14).Position = textArray(14).Position + [0, -0.04, -0.01];
        textArray(15).Position = textArray(15).Position + [0, +0.09, +0.09];
    elseif strcmp(algName, 'PyNSGAIIIwH')
        textArray = flip(ax.Children(13:27))
        textArray(1).Position = textArray(1).Position + [0, 0.01, 0.02];
        textArray(2).Position = textArray(2).Position + [0, -0.08, +0.007];
        textArray(3).Position = textArray(3).Position + [0, -0.053, +0.016];
        textArray(4).Position = textArray(4).Position + [0, -0.037, -0.026];
        textArray(5).Position = textArray(5).Position + [0, -0.08, -0.055];
        textArray(6).Position = textArray(6).Position + [0, -0.035, +0.02];
        textArray(7).Position = textArray(7).Position + [0, -0.03, -0.017];
        textArray(8).Position = textArray(8).Position + [0, -0.03, +0.01];
        textArray(9).Position = textArray(9).Position + [0, -0.04, +0.05];
        textArray(10).Position = textArray(10).Position + [0, -0.04, -0.01];
        textArray(11).Position = textArray(11).Position + [0, -0.044, +0.01];
        textArray(12).Position = textArray(12).Position + [0, -0.075, +0.026];
        textArray(13).Position = textArray(13).Position + [0, -0.04, -0.02];
        textArray(14).Position = textArray(14).Position + [0, -0.04, -0.01];
        textArray(15).Position = textArray(15).Position + [0, +0.09, +0.09];
    end
end

if strcmp(mode, 'original')
    if strcmp(algName, 'GtNSGAIIIwH')
        lims = [0 2.5];
        set(ax, 'XLim', lims);set(ax, 'YLim', lims);set(ax, 'ZLim', lims);
        ticks = [0 1.00 2.00];
        set(ax, 'XTick', ticks);set(ax, 'YTick', ticks);set(ax, 'ZTick', ticks);
        set(ax.XLabel, 'Rotation', 0, 'Position', 2.5*[0.3, 1.5, 0.05])
        set(ax.YLabel, 'Rotation', 0, 'Position', 2.5*[1.23, 0.61, 0.0])
        set(ax.ZLabel, 'Rotation', 0, 'Position', 2.5*[1.15, 0, 0.5])
        textArray = flip(ax.Children(4:18))
        textArray(1).Position = textArray(1).Position + 1.4*[0.1, -0.02, 0];
        textArray(2).Position = textArray(2).Position + 1.4*[0.12, 0, 0.01];
        textArray(3).Position = textArray(3).Position + 1.4*[0.02, 0, -0.10];
        textArray(4).Position = textArray(4).Position + 1.4*[-0.02, 0, 0];
        textArray(5).Position = textArray(5).Position + 1.4*[-0.02, 0, 0];
        textArray(6).Position = textArray(6).Position + 1.4*[0.06, 0, -0.1];
        textArray(7).Position = textArray(7).Position + 1.4*[-0.02, 0, 0];
        textArray(8).Position = textArray(8).Position + 1.4*[-0.02, 0, 0];
        textArray(9).Position = textArray(9).Position + 1.4*[0.06, 0, -0.1];
        textArray(10).Position = textArray(10).Position + 1.4*[0.06, -0.14, 0.085];
        textArray(11).Position = textArray(11).Position + 1.4*[-0.01, 0, 0.04];
        textArray(12).Position = textArray(12).Position + 1.4*[0.03, 0, -0.09];
        textArray(13).Position = textArray(13).Position + 1.4*[-0.04, -0.06, 0];
        textArray(14).Position = textArray(14).Position + 1.4*[0.15, 0, 0.12];
        textArray(15).Position = textArray(15).Position + 1.4*[0.17, -0.12, 0];
    end
end


if strcmp(mode, 'normal')
    if strcmp(algName, 'NSGAIIIwH')
        filename = './Pl-NSGA-III-DTLZ2-Niches.png';
    elseif strcmp(algName, 'PyNSGAIIIwH')
        filename = './Py-NSGA-III-DTLZ2-Niches.png';
    elseif strcmp(algName, 'GtNSGAIIIwH')
        filename = './Gt-NSGA-III-DTLZ2-Niches.png';
    end
elseif strcmp(mode, 'projection')
    if strcmp(algName, 'NSGAIIIwH')
        filename = './Pl-NSGA-III-DTLZ2-Niches-2D.png';
    elseif strcmp(algName, 'PyNSGAIIIwH')
        filename = './Py-NSGA-III-DTLZ2-Niches-2D.png';
    end
elseif strcmp(mode, 'original')
    filename = './Original-DTLZ2.png';
end
% exportgraphics(fig, filename, 'Resolution', 300);
% close(fig);
