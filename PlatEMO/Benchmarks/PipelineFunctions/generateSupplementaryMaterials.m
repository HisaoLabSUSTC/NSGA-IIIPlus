function generateSupplementaryMaterials(baseDir, hvSummaryPath, igdpSummaryPath, algorithms, problemNames, Mvec, algDisplayNames, options)
% generateSupplementaryMaterials - Generate ACM-format supplementary materials
%
% Usage:
%   algorithms = {generateAlgorithm(), generateAlgorithm('area1','ZY'), ...};
%   problemNames = {'DTLZ1', 'DTLZ4', 'MOTSP_ID1', ...};
%   M = 3;
%   algDisplayNames = containers.Map();
%
%   generateSupplementaryMaterials('./Info/StableStatistics', ...
%       './Info/FinalHV/hvSummary.mat', './Info/FinalIGD/igdSummary.mat', ...
%       algorithms, problemNames, M, algDisplayNames);
%
% Input:
%   baseDir      - (unused, kept for backward compatibility)
%   problemNames - Cell array of pipeline names (e.g. 'DTLZ1', 'MOTSP_ID1').
%                  Previously accepted function handles; now accepts strings.
%                  For backward compatibility, function handles are converted
%                  to strings via func2str.
%
% Generates a complete LaTeX document with performance tables (HV, IGD+,
% Generalized Spread, Time) split across multiple pages.

%% Validate inputs and set defaults
if nargin < 7
    error('Usage: generateSupplementaryMaterials(baseDir, hvSummaryPath, igdpSummaryPath, algorithms, problems, M, algDisplayNames, [options])');
end

% Default options
if nargin < 8
    options = struct();
end

numAlgorithms = numel(algorithms);

% Set adaptive defaults based on algorithm count
if ~isfield(options, 'draftMode')
    options.draftMode = numAlgorithms > 50;  % Auto-enable for large counts
end
if ~isfield(options, 'maxProblemsPerTable')
    if numAlgorithms > 100
        options.maxProblemsPerTable = 1;
    elseif numAlgorithms > 50
        options.maxProblemsPerTable = 2;
    elseif numAlgorithms > 20
        options.maxProblemsPerTable = 3;
    else
        options.maxProblemsPerTable = 4;
    end
end
if ~isfield(options, 'maxImagesPerRow')
    options.maxImagesPerRow = min(4, max(2, floor(10 / sqrt(numAlgorithms))));
end
if ~isfield(options, 'imageScale')
    if numAlgorithms > 100
        options.imageScale = 0.6;
    elseif numAlgorithms > 50
        options.imageScale = 0.7;
    elseif numAlgorithms > 20
        options.imageScale = 0.8;
    else
        options.imageScale = 1.0;
    end
end
if ~isfield(options, 'figuresPerPage')
    options.figuresPerPage = max(1, floor(4 / ceil(numAlgorithms / options.maxImagesPerRow)));
end

fprintf('Options: draftMode=%d, maxProblemsPerTable=%d, maxImagesPerRow=%d, imageScale=%.2f\n', ...
    options.draftMode, options.maxProblemsPerTable, options.maxImagesPerRow, options.imageScale);

%% Load all metric summaries
hvData = load(hvSummaryPath, 'hvSummary');
hvSummary = hvData.hvSummary;
igdpData = load(igdpSummaryPath, 'igdSummary');
igdpSummary = igdpData.igdSummary;

% Load Generalized Spread summary
genSpreadSummaryPath = './Info/FinalGenSpread/genSpreadSummary.mat';
if exist(genSpreadSummaryPath, 'file')
    genSpreadData = load(genSpreadSummaryPath, 'genSpreadSummary');
    genSpreadSummary = genSpreadData.genSpreadSummary;
else
    genSpreadSummary = struct();
    warning('Generalized Spread summary not found: %s', genSpreadSummaryPath);
end

% Load Time summary
timeSummaryPath = './Info/FinalTime/timeSummary.mat';
if exist(timeSummaryPath, 'file')
    timeData = load(timeSummaryPath, 'timeSummary');
    timeSummary = timeData.timeSummary;
else
    timeSummary = struct();
    warning('Time summary not found: %s', timeSummaryPath);
end

% Load reference HV (computed from reference PF)
refHVPath = './Info/FinalHV/ReferenceHV/prob2rhv.mat';
if exist(refHVPath, 'file')
    refHVData = load(refHVPath, 'prob2rhv');
    prob2rhv = refHVData.prob2rhv;
else
    prob2rhv = containers.Map();
    warning('Reference HV file not found: %s', refHVPath);
end

%% Ensure problemNames are strings (backward compat: accept handles)
for i = 1:numel(problemNames)
    if isa(problemNames{i}, 'function_handle')
        problemNames{i} = func2str(problemNames{i});
    end
end

%% Extract algorithm names (supports both legacy handles and config-based specs)
algorithmNames = cell(1, numel(algorithms));
for i = 1:numel(algorithms)
    algorithmNames{i} = getAlgorithmName(algorithms{i});
end

%% Expand scalar Mvec to vector
if isscalar(Mvec)
    Mvec = repmat(Mvec, 1, numel(problemNames));
end

%% Create problems array based on per-problem M
problems2D = problemNames(Mvec == 2);
problems3D = problemNames(Mvec >= 3);

%% Problem display name mappings (for Minus problems)
probDisplayNames = containers.Map();
probDisplayNames('MinusDTLZ1') = '$-$DTLZ1';
probDisplayNames('MinusDTLZ2') = '$-$DTLZ2';
probDisplayNames('MinusDTLZ3') = '$-$DTLZ3';
probDisplayNames('MinusDTLZ4') = '$-$DTLZ4';
probDisplayNames('MinusDTLZ5') = '$-$DTLZ5';
probDisplayNames('MinusDTLZ6') = '$-$DTLZ6';
probDisplayNames('MinusWFG1') = '$-$WFG1';
probDisplayNames('MinusWFG2') = '$-$WFG2';
probDisplayNames('MinusWFG3') = '$-$WFG3';
probDisplayNames('MinusWFG4') = '$-$WFG4';
probDisplayNames('MinusWFG5') = '$-$WFG5';
probDisplayNames('MinusWFG6') = '$-$WFG6';
probDisplayNames('MinusWFG7') = '$-$WFG7';
probDisplayNames('MinusWFG8') = '$-$WFG8';
probDisplayNames('MinusWFG9') = '$-$WFG9';

%% Generate the supplementary materials LaTeX document
generateSupplementaryLaTeX(problems2D, problems3D, Mvec, ...
    algDisplayNames, probDisplayNames, hvSummary, igdpSummary, ...
    genSpreadSummary, timeSummary, algorithmNames, options, prob2rhv);

fprintf('Supplementary materials generated successfully!\n');
end

%% ========================================================================
%  LATEX GENERATION
%% ========================================================================

function generateSupplementaryLaTeX(problems2D, problems3D, Mvec, ...
    algDisplayNames, probDisplayNames, hvSummary, igdpSummary, ...
    genSpreadSummary, timeSummary, algorithmNames, options, prob2rhv)

filename = './SupplementaryMaterials3.tex';
fid = fopen(filename, 'w');

% Write document preamble
writeDocumentPreamble(fid, options.draftMode);

% Sort all problems
sorted2D = problems2D(getNaturalOrder(problems2D));
sorted3D = problems3D(getNaturalOrder(problems3D));

% Combine all problems
allProblems = [sorted2D, sorted3D];

% Split into chunks based on options
maxProblemsPerTable = options.maxProblemsPerTable;
numProblems = length(allProblems);
numTables = ceil(numProblems / maxProblemsPerTable);

tableNum = 1;
probIdx = 1;

while probIdx <= numProblems
    endIdx = min(probIdx + maxProblemsPerTable - 1, numProblems);
    tableProblems = allProblems(probIdx:endIdx);

    uniqueM = unique(Mvec);
    if numel(uniqueM) == 1
        objLabel = sprintf('%d-Objective', uniqueM);
    else
        objLabel = 'Multi-Objective';
    end

    if tableNum == 1
        tableTitle = sprintf('%s Problems', objLabel);
    else
        tableTitle = sprintf('%s Problems (continued)', objLabel);
    end

    if tableNum > 1
        fprintf(fid, '\\clearpage\n\n');
    end

    % Write table with 4 metrics (HV, IGD+, Δ*, Time)
    writeMetricsTable(fid, tableProblems, tableNum, numTables, ...
        tableTitle, algDisplayNames, probDisplayNames, ...
        hvSummary, igdpSummary, genSpreadSummary, timeSummary, algorithmNames, prob2rhv);

    probIdx = endIdx + 1;
    tableNum = tableNum + 1;
end

%% Insert figure contents via Python script
pyScript = './Visualization/batch_insert.py';
pyOutput = 'figures.tex';

draftFlag = '';
if options.draftMode
    draftFlag = '--draft';
end

cmd = sprintf('conda run -n Research python "%s" --max-per-row %d --image-scale %.2f --per-page %d %s', ...
    pyScript, options.maxImagesPerRow, options.imageScale, options.figuresPerPage, draftFlag);

fprintf('Running Python script: %s\n', cmd);
[status, cmdout] = system(cmd, '-echo');

if status ~= 0
    warning('Python execution failed (status=%d). Figures section may be incomplete.', status);
    fprintf('Command output: %s\n', cmdout);
end

if exist(pyOutput, 'file')
    texContent = fileread(pyOutput);
    fprintf(fid, '\n%% --- Content generated by Python ---\n');
    fprintf(fid, '%s', texContent);
    fprintf(fid, '\n%% -----------------------------------\n');
else
    warning('Python script ran, but the expected output file "%s" was not found.', pyOutput);
end

fprintf(fid, '\\end{document}\n');
fclose(fid);
fprintf('Generated: %s\n', filename);
end

function writeDocumentPreamble(fid, draftMode)
fprintf(fid, '\\documentclass[sigconf,nonacm]{acmart}\n\n');
fprintf(fid, '\\settopmatter{printacmref=false}\n');
fprintf(fid, '\\renewcommand\\footnotetextcopyrightpermission[1]{}\n');
fprintf(fid, '\\pagestyle{plain}\n\n');
fprintf(fid, '\\usepackage{booktabs}\n');
fprintf(fid, '\\usepackage{multirow}\n');

if draftMode
    fprintf(fid, '\\usepackage[draft]{graphicx}\n');
else
    fprintf(fid, '\\usepackage{graphicx}\n');
end

fprintf(fid, '\\usepackage{float}\n\n');

if draftMode
    fprintf(fid, '\\pdfminorversion=5\n');
    fprintf(fid, '\\pdfcompresslevel=9\n\n');
end

fprintf(fid, '\\begin{document}\n\n');
fprintf(fid, '\\title{Supplementary Materials for: \\\\ Improving NSGA-III Stability}\n\n');
fprintf(fid, '\\author{Anonymous Author(s)}\n');
fprintf(fid, '\\affiliation{\\institution{Institution Name}\\city{City}\\country{Country}}\n');
fprintf(fid, '\\email{author@email.com}\n\n');
fprintf(fid, '\\maketitle\n\n');

fprintf(fid, '\\section*{Overview}\n');
fprintf(fid, 'This supplementary material provides complete metrics for all algorithm-problem combinations.\n\n');
fprintf(fid, '\\textbf{Metrics:}\n');
fprintf(fid, '\\begin{itemize}\n');
fprintf(fid, '    \\item \\textbf{HV}: Normalized Hypervolume $(\\uparrow)$ - higher is better\n');
fprintf(fid, '    \\item \\textbf{IGD$^+$}: Inverted Generational Distance Plus $(\\downarrow)$ - lower is better\n');
fprintf(fid, '    \\item \\textbf{$\\Delta^*$}: Generalized Spread $(\\downarrow)$ - lower is better\n');
fprintf(fid, '    \\item \\textbf{Time}: Wall-clock runtime in seconds $(\\downarrow)$ - lower is better\n');
fprintf(fid, '\\end{itemize}\n');
fprintf(fid, '\\textbf{Bold} values indicate the best algorithm for each metric per problem.\n\n');
fprintf(fid, '\\clearpage\n\n');
end

function writeMetricsTable(fid, problems, tableNum, totalTables, ...
    tableTitle, algDisplayNames, probDisplayNames, hvSummary, igdpSummary, ...
    genSpreadSummary, timeSummary, algorithmNames, prob2rhv)

numAlgorithms = length(algorithmNames);

% Table header
fprintf(fid, '\\begin{table*}[htbp]\n');
fprintf(fid, '\\centering\n');
fprintf(fid, '\\caption{Performance Metrics (Part %d of %d)}\n', tableNum, totalTables);
fprintf(fid, '\\label{tab:metrics_part%d}\n', tableNum);
fprintf(fid, '\\tiny\n');
fprintf(fid, '\\setlength{\\tabcolsep}{3pt}\n');

% 6 columns: Problem, Algorithm, HV, IGD+, Δ*, Time
fprintf(fid, '\\begin{tabular}{ll cccc}\n');
fprintf(fid, '\\toprule\n');
fprintf(fid, '\\textbf{Problem} & \\textbf{Algorithm} & \\textbf{HV $(\\uparrow)$} & \\textbf{IGD$^+$ $(\\downarrow)$} & \\textbf{$\\Delta^*$ $(\\downarrow)$} & \\textbf{Time $(\\downarrow)$} \\\\\n');
fprintf(fid, '\\midrule\n');

for p = 1:length(problems)
    prob = problems{p};
    probField = matlab.lang.makeValidName(prob);
    isLastProblem = (p == length(problems));

    % Get display name
    if isKey(probDisplayNames, prob)
        probDisplay = probDisplayNames(prob);
    else
        probDisplay = strrep(prob, '_', '\_');
    end

    % Append reference HV under the problem name if available
    if isKey(prob2rhv, prob)
        refHV = prob2rhv(prob);
        probDisplay = sprintf('\\begin{tabular}[t]{@{}l@{}}%s\\\\ {\\scriptsize Ref.\\ HV: %.4f}\\end{tabular}', probDisplay, refHV);
    end

    % Collect metrics for all algorithms for this problem to find best values
    metrics = collectMetricsForProblem(prob, probField, algorithmNames, ...
        hvSummary, igdpSummary, genSpreadSummary, timeSummary);

    % Find best values for each metric
    bestIdx = findBestMetrics(metrics);

    % Count valid algorithms
    validAlgs = find(~cellfun(@isempty, {metrics.alg}));
    numValidAlgs = length(validAlgs);

    if numValidAlgs == 0
        fprintf(fid, '%s & -- & -- & -- & -- & -- \\\\\n', probDisplay);
        continue;
    end

    % Write rows for each algorithm
    for i = 1:numValidAlgs
        a = validAlgs(i);
        alg = metrics(a).alg;

        if isKey(algDisplayNames, alg)
            algDisplay = algDisplayNames(alg);
        else
            algDisplay = strrep(alg, '_', '\_');
        end

        % Format each metric with bolding if best
        hvStr = formatMetricCellWithStd(metrics(a).hv, metrics(a).hv_std, a == bestIdx.hv, '%.4f');
        igdStr = formatMetricCellWithStd(metrics(a).igdp, metrics(a).igdp_std, a == bestIdx.igdp, '%.2e');
        genSpreadStr = formatMetricCellWithStd(metrics(a).genspread, metrics(a).genspread_std, a == bestIdx.genspread, '%.4f');
        timeStr = formatMetricCellWithStd(metrics(a).time, metrics(a).time_std, a == bestIdx.time, '%.2f');

        if i == 1
            fprintf(fid, '\\multirow{%d}{*}{%s} & %s & %s & %s & %s & %s \\\\\n', ...
                numValidAlgs, probDisplay, algDisplay, hvStr, igdStr, genSpreadStr, timeStr);
        else
            fprintf(fid, ' & %s & %s & %s & %s & %s \\\\\n', ...
                algDisplay, hvStr, igdStr, genSpreadStr, timeStr);
        end
    end

    if ~isLastProblem
        fprintf(fid, '\\midrule\n');
    end
end

fprintf(fid, '\\bottomrule\n');
fprintf(fid, '\\end{tabular}\n');
fprintf(fid, '\\end{table*}\n\n');
end

function metrics = collectMetricsForProblem(prob, probField, algorithmNames, ...
    hvSummary, igdpSummary, genSpreadSummary, timeSummary)
% Collect all metrics for a problem across all algorithms

numAlgs = length(algorithmNames);
metrics = struct('alg', cell(1, numAlgs), 'hv', [], 'hv_std', [], ...
                 'igdp', [], 'igdp_std', [], ...
                 'genspread', [], 'genspread_std', [], ...
                 'time', [], 'time_std', []);

for a = 1:numAlgs
    alg = algorithmNames{a};
    algField = matlab.lang.makeValidName(alg);

    metrics(a).alg = alg;

    % HV (normalized)
    if isfield(hvSummary, probField) && isfield(hvSummary.(probField), [algField '_mean'])
        metrics(a).hv = hvSummary.(probField).([algField '_mean']);
        metrics(a).hv_std = hvSummary.(probField).([algField '_std']);
    else
        metrics(a).hv = NaN;
        metrics(a).hv_std = NaN;
    end

    % IGD+
    if isfield(igdpSummary, probField) && isfield(igdpSummary.(probField), [algField '_mean'])
        metrics(a).igdp = igdpSummary.(probField).([algField '_mean']);
        metrics(a).igdp_std = igdpSummary.(probField).([algField '_std']);
    else
        metrics(a).igdp = NaN;
        metrics(a).igdp_std = NaN;
    end

    % Generalized Spread
    if ~isempty(fieldnames(genSpreadSummary)) && isfield(genSpreadSummary, probField) && isfield(genSpreadSummary.(probField), [algField '_mean'])
        metrics(a).genspread = genSpreadSummary.(probField).([algField '_mean']);
        metrics(a).genspread_std = genSpreadSummary.(probField).([algField '_std']);
    else
        metrics(a).genspread = NaN;
        metrics(a).genspread_std = NaN;
    end

    % Time
    if ~isempty(fieldnames(timeSummary)) && isfield(timeSummary, probField) && isfield(timeSummary.(probField), [algField '_mean'])
        metrics(a).time = timeSummary.(probField).([algField '_mean']);
        metrics(a).time_std = timeSummary.(probField).([algField '_std']);
    else
        metrics(a).time = NaN;
        metrics(a).time_std = NaN;
    end
end
end

function bestIdx = findBestMetrics(metrics)
% Find index of algorithm with best value for each metric
% HV: maximize; IGD+, Δ*, Time: minimize

bestIdx = struct();

% Extract values
hvVals = [metrics.hv];
igdpVals = [metrics.igdp];
genSpreadVals = [metrics.genspread];
timeVals = [metrics.time];

% Find best (handle NaN)
[~, bestIdx.hv] = max(hvVals);               % maximize
[~, bestIdx.igdp] = min(igdpVals);           % minimize
[~, bestIdx.genspread] = min(genSpreadVals); % minimize
[~, bestIdx.time] = min(timeVals);           % minimize

% Handle all-NaN cases
if all(isnan(hvVals)), bestIdx.hv = 0; end
if all(isnan(igdpVals)), bestIdx.igdp = 0; end
if all(isnan(genSpreadVals)), bestIdx.genspread = 0; end
if all(isnan(timeVals)), bestIdx.time = 0; end
end

function str = formatMetricCell(value, isBest, formatStr)
% Format a metric value, with optional bolding

if isnan(value) || isempty(value)
    str = '--';
    return;
end

% Format the number
if contains(formatStr, '%%')
    % Percentage format
    str = sprintf(formatStr, value);
else
    str = sprintf(formatStr, value);
end

% Bold if best
if isBest
    str = sprintf('\\textbf{%s}', str);
end
end

function str = formatMetricCellWithStd(meanVal, stdVal, isBest, formatStr)
% Format a metric value as "mean $\pm$ std", with optional bolding on mean

if isnan(meanVal) || isempty(meanVal)
    str = '--';
    return;
end

meanStr = sprintf(formatStr, meanVal);
stdStr = sprintf(formatStr, stdVal);

if isBest
    str = sprintf('\\textbf{%s} $\\pm$ %s', meanStr, stdStr);
else
    str = sprintf('%s $\\pm$ %s', meanStr, stdStr);
end
end

%% ========================================================================
%  UTILITY FUNCTIONS
%% ========================================================================

function sortedIndices = getNaturalOrder(strList)
if isempty(strList)
    sortedIndices = [];
    return;
end

tokens = regexp(strList, '^(.*?)(-?\d+)$', 'tokens', 'once');

hasMatch = ~cellfun(@isempty, tokens);
if ~all(hasMatch)
    for i = find(~hasMatch)
        tokens{i} = {strList{i}, '0'};
    end
end

extracted = vertcat(tokens{:});
prefixes = extracted(:, 1);
numbers = str2double(extracted(:, 2));

[~, sortedIndices] = sortrows(table(prefixes, numbers));
sortedIndices = sortedIndices(:)';
end
