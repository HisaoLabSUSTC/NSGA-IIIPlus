%% ComparisonPipeline - Generate comparison tables and generic visualizations
%
%   Self-contained pipeline for producing:
%     1. LaTeX comparison tables with Wilcoxon rank-sum tests (HV, IGD+, Time)
%     2. Algorithm-agnostic population scatter plots (GP-*.png)
%
%   Prerequisites: Run BenchmarkPipeline.m tasks 1-4 first to generate
%   metric data (hvSummary.mat, igdSummary.mat, timeSummary.mat, MedianHV).
%
%   Usage:
%     1. Edit the 'algorithms' and 'problems' arrays below
%     2. Run this script
%     3. Check ./ComparisonTables.tex and ./Visualization/images/GP-*.png

%% ========================================================================
%  CONFIGURATION
%% ========================================================================

% Define algorithms (same format as BenchmarkPipeline.m)
algorithms = {generateAlgorithm(), ...
              generateAlgorithm('area1', 'ZYX', 'momentum', 'tikhonov', 'useDSS', true), ...
              @NSGAIIwH};

% Problems (same format as BenchmarkPipeline.m)
problems = {@RWA2};

% Benchmark parameters
params = struct(...
    'FE',   1000 * 120, ...
    'N',    120, ...
    'M',    3, ...
    'runs', 5 ...
);

%% Parse problems
[problemHandles, Mvec, Dvec, IDvec, problemNames] = parseProblemList(problems, params.M);

%% Load algorithm display names
algDisplayNames = loadAlgDisplayNames();

%% ========================================================================
%  TASK 1: GENERATE COMPARISON TABLES (Wilcoxon rank-sum)
%% ========================================================================
fprintf('\n=== Generating Comparison Tables ===\n');
generateComparisonTables(algorithms, problemNames, Mvec, algDisplayNames, ...
    'refAlgIdx', numel(algorithms), ...
    'alpha', 0.05, ...
    'outputFile', 'ComparisonTables.tex');

%% ========================================================================
%  TASK 2: GENERIC POPULATION VISUALIZATION
%% ========================================================================
fprintf('\n=== Generating Generic Population Visualizations ===\n');
visualizeResultsGeneric(algorithms, problemHandles, Mvec, Dvec, IDvec, problemNames, algDisplayNames);

fprintf('\n========================================\n');
fprintf('COMPARISON PIPELINE COMPLETE\n');
fprintf('========================================\n');

%% ========================================================================
%  HELPER FUNCTIONS (copied from BenchmarkPipeline.m for self-containment)
%% ========================================================================

function [problemHandles, Mvec, Dvec, IDvec, problemNames] = parseProblemList(problems, defaultM)
%PARSEPROBLEMLIST Parse problem list into handles, M/D/ID vectors, and names.
    n = numel(problems);
    problemHandles = cell(1, n);
    Mvec = zeros(1, n);
    Dvec = nan(1, n);
    IDvec = nan(1, n);
    problemNames = cell(1, n);
    for i = 1:n
        entry = problems{i};
        if iscell(entry)
            problemHandles{i} = entry{1};
            Mvec(i) = entry{2};
            if numel(entry) >= 4
                Dvec(i) = entry{3};
                IDvec(i) = entry{4};
                problemNames{i} = sprintf('%s_ID%d', func2str(entry{1}), entry{4});
            else
                problemNames{i} = func2str(entry{1});
            end
        else
            problemHandles{i} = entry;
            Mvec(i) = defaultM;
            problemNames{i} = func2str(entry);
        end
    end
end

function algDisplayNames = loadAlgDisplayNames()
%LOADALGDISPLAYNAMES Load algorithm display name mappings from JSON
    persistent cachedNames;

    if isempty(cachedNames)
        configPath = './Info/Misc/algorithm_display_names.json';

        if exist(configPath, 'file')
            jsonText = fileread(configPath);
            nameStruct = jsondecode(jsonText);

            fields = fieldnames(nameStruct);
            cachedNames = containers.Map();
            for i = 1:numel(fields)
                cachedNames(fields{i}) = nameStruct.(fields{i});
            end
        else
            warning('Config file not found: %s. Using empty map.', configPath);
            cachedNames = containers.Map();
        end
    end

    algDisplayNames = cachedNames;
end
