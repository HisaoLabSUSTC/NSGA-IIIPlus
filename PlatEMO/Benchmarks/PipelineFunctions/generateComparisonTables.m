function generateComparisonTables(algorithms, problemNames, Mvec, algDisplayNames, varargin)
%GENERATECOMPARISONTABLES Generate LaTeX comparison tables with Wilcoxon tests
%
%   generateComparisonTables(algorithms, problemNames, Mvec, algDisplayNames)
%   generateComparisonTables(..., 'refAlgIdx', 4, 'alpha', 0.05, 'outputFile', 'ComparisonTables.tex')
%
%   Produces three LaTeX tables (HV, IGD+, Time) in standard EMO paper format:
%     - Problems as rows, algorithms as columns
%     - Mean(Std) with Wilcoxon rank-sum test symbols: +/-/≈
%     - Bold best values per problem
%     - Summary row: w/t/l counts
%
%   Input:
%     algorithms      - Cell array of algorithm specs
%     problemNames    - Cell array of pipeline problem names
%     Mvec            - Numeric vector of M values (one per problem)
%     algDisplayNames - containers.Map of internal→display names
%
%   Name-value arguments:
%     refAlgIdx  - Index of reference algorithm for Wilcoxon test (default: last)
%     alpha      - Significance level (default: 0.05)
%     outputFile - Output .tex file path (default: 'ComparisonTables.tex')

%% Parse name-value arguments
p = inputParser;
addRequired(p, 'algorithms');
addRequired(p, 'problemNames');
addRequired(p, 'Mvec');
addRequired(p, 'algDisplayNames');
addParameter(p, 'refAlgIdx', numel(algorithms));
addParameter(p, 'alpha', 0.05);
addParameter(p, 'outputFile', 'ComparisonTables.tex');
parse(p, algorithms, problemNames, Mvec, algDisplayNames, varargin{:});

refAlgIdx = p.Results.refAlgIdx;
alpha = p.Results.alpha;
outputFile = p.Results.outputFile;

%% Extract algorithm names
numAlgs = numel(algorithms);
algorithmNames = cell(1, numAlgs);
for i = 1:numAlgs
    algorithmNames{i} = getAlgorithmName(algorithms{i});
end

%% Expand scalar Mvec
if isscalar(Mvec)
    Mvec = repmat(Mvec, 1, numel(problemNames));
end

%% Load summary data
hvSummary = loadSummary('./Info/FinalHV/hvSummary.mat', 'hvSummary');
igdSummary = loadSummary('./Info/FinalIGD/igdSummary.mat', 'igdSummary');
timeSummary = loadSummary('./Info/FinalTime/timeSummary.mat', 'timeSummary');

%% Problem display name mappings
probDisplayNames = buildProbDisplayNames();

%% Open output file
fid = fopen(outputFile, 'w');
if fid == -1
    error('Cannot open output file: %s', outputFile);
end

% Write preamble
writeComparisonPreamble(fid);

% Generate three tables
fprintf('  Generating HV table...\n');
writeComparisonTable(fid, 'HV', hvSummary, algorithmNames, problemNames, ...
    algDisplayNames, probDisplayNames, refAlgIdx, alpha, 'maximize', '%.4f');

fprintf(fid, '\\clearpage\n\n');

fprintf('  Generating IGD+ table...\n');
writeComparisonTable(fid, 'IGD$^+$', igdSummary, algorithmNames, problemNames, ...
    algDisplayNames, probDisplayNames, refAlgIdx, alpha, 'minimize', '%.2e');

fprintf(fid, '\\clearpage\n\n');

fprintf('  Generating Time table...\n');
writeComparisonTable(fid, 'Time (s)', timeSummary, algorithmNames, problemNames, ...
    algDisplayNames, probDisplayNames, refAlgIdx, alpha, 'minimize', '%.2f');

% Close document
fprintf(fid, '\\end{document}\n');
fclose(fid);

fprintf('  Comparison tables written to: %s\n', outputFile);
end

%% ========================================================================
%  TABLE GENERATION
%% ========================================================================

function writeComparisonTable(fid, metricLabel, summary, algorithmNames, ...
    problemNames, algDisplayNames, probDisplayNames, refAlgIdx, alpha, direction, fmt)
%WRITECOMPARISONTABLE Write one comparison table to the LaTeX file

numAlgs = numel(algorithmNames);
numProbs = numel(problemNames);

% Determine direction flag for symbol assignment
isMaximize = strcmp(direction, 'maximize');

% Get algorithm display names
algHeaders = cell(1, numAlgs);
for a = 1:numAlgs
    alg = algorithmNames{a};
    if isKey(algDisplayNames, alg)
        algHeaders{a} = algDisplayNames(alg);
    else
        algHeaders{a} = strrep(alg, '_', '\_');
    end
end

% Column spec: l for problem + c for each algorithm
colSpec = ['l' repmat('c', 1, numAlgs)];

% Table header
fprintf(fid, '\\begin{table*}[htbp]\n');
fprintf(fid, '\\centering\n');
fprintf(fid, '\\caption{%s comparison. Reference algorithm: %s. Symbols: $+$/$-$/$\\approx$ denote significantly better/worse/similar to reference (Wilcoxon rank-sum, $\\alpha=%.2f$). Best values in \\textbf{bold}.}\n', ...
    metricLabel, algHeaders{refAlgIdx}, alpha);
fprintf(fid, '\\small\n');
fprintf(fid, '\\setlength{\\tabcolsep}{4pt}\n');
fprintf(fid, '\\begin{tabular}{%s}\n', colSpec);
fprintf(fid, '\\toprule\n');

% Header row
fprintf(fid, '\\textbf{Problem}');
for a = 1:numAlgs
    fprintf(fid, ' & \\textbf{%s}', algHeaders{a});
end
fprintf(fid, ' \\\\\n');
fprintf(fid, '\\midrule\n');

% Initialize w/t/l counters per algorithm
wins = zeros(1, numAlgs);
ties = zeros(1, numAlgs);
losses = zeros(1, numAlgs);

% Write rows
for pi = 1:numProbs
    probName = problemNames{pi};
    probField = matlab.lang.makeValidName(probName);

    % Get problem display name
    if isKey(probDisplayNames, probName)
        probDisplay = probDisplayNames(probName);
    else
        probDisplay = strrep(probName, '_', '\_');
    end

    % Collect raw data for all algorithms
    rawData = cell(1, numAlgs);
    means = nan(1, numAlgs);
    stds = nan(1, numAlgs);

    for a = 1:numAlgs
        alg = algorithmNames{a};
        algField = matlab.lang.makeValidName(alg);

        if isfield(summary, probField) && isfield(summary.(probField), [algField '_raw'])
            rawData{a} = summary.(probField).([algField '_raw']);
            means(a) = summary.(probField).([algField '_mean']);
            stds(a) = summary.(probField).([algField '_std']);
        end
    end

    % Find best value
    if isMaximize
        [~, bestIdx] = max(means);
    else
        [~, bestIdx] = min(means);
    end
    if all(isnan(means))
        bestIdx = 0;
    end

    % Reference algorithm raw data
    refRaw = rawData{refAlgIdx};

    % Build row
    fprintf(fid, '%s', probDisplay);

    for a = 1:numAlgs
        algRaw = rawData{a};
        meanVal = means(a);
        stdVal = stds(a);

        if isnan(meanVal) || isempty(algRaw)
            fprintf(fid, ' & --');
            continue;
        end

        % Format mean(std)
        meanStr = sprintf(fmt, meanVal);
        stdStr = sprintf(fmt, stdVal);

        % Bold if best
        if a == bestIdx
            cellStr = sprintf('\\textbf{%s}(%s)', meanStr, stdStr);
        else
            cellStr = sprintf('%s(%s)', meanStr, stdStr);
        end

        % Wilcoxon test against reference
        if a == refAlgIdx
            % Reference column: no symbol
            fprintf(fid, ' & %s', cellStr);
        else
            symbol = runWilcoxon(algRaw, refRaw, alpha, isMaximize);

            % Update counters
            switch symbol
                case '+'
                    wins(a) = wins(a) + 1;
                case '-'
                    losses(a) = losses(a) + 1;
                case '\approx'
                    ties(a) = ties(a) + 1;
            end

            fprintf(fid, ' & %s$^{%s}$', cellStr, symbol);
        end
    end

    fprintf(fid, ' \\\\\n');
end

% Summary row: w/t/l
fprintf(fid, '\\midrule\n');
fprintf(fid, '$w/t/l$');
for a = 1:numAlgs
    if a == refAlgIdx
        fprintf(fid, ' & --');
    else
        fprintf(fid, ' & %d/%d/%d', wins(a), ties(a), losses(a));
    end
end
fprintf(fid, ' \\\\\n');

fprintf(fid, '\\bottomrule\n');
fprintf(fid, '\\end{tabular}\n');
fprintf(fid, '\\end{table*}\n\n');

% Console summary
fprintf('    %s: Ref=%s\n', metricLabel, algorithmNames{refAlgIdx});
for a = 1:numAlgs
    if a == refAlgIdx, continue; end
    fprintf('      %s: w=%d, t=%d, l=%d\n', algorithmNames{a}, wins(a), ties(a), losses(a));
end
end

%% ========================================================================
%  WILCOXON TEST
%% ========================================================================

function symbol = runWilcoxon(algRaw, refRaw, alpha, isMaximize)
%RUNWILCOXON Perform two-sided Wilcoxon rank-sum test and return symbol
%
%   Returns: '+' (alg significantly better), '-' (worse), '\approx' (similar)

% Handle edge cases
if isempty(algRaw) || isempty(refRaw) || all(isnan(algRaw)) || all(isnan(refRaw))
    symbol = '\approx';
    return;
end

% Ensure column vectors
algRaw = algRaw(:);
refRaw = refRaw(:);

% Two-sided Wilcoxon rank-sum test
pval = ranksum(algRaw, refRaw, 'alpha', alpha);

if pval >= alpha
    % Not significantly different
    symbol = '\approx';
else
    % Significant difference: determine direction via median comparison
    algMedian = median(algRaw);
    refMedian = median(refRaw);

    if isMaximize
        % Higher is better
        if algMedian > refMedian
            symbol = '+';    % alg better
        else
            symbol = '-';    % alg worse
        end
    else
        % Lower is better
        if algMedian < refMedian
            symbol = '+';    % alg better
        else
            symbol = '-';    % alg worse
        end
    end
end
end

%% ========================================================================
%  UTILITY FUNCTIONS
%% ========================================================================

function summary = loadSummary(filepath, varname)
%LOADSUMMARY Load a summary .mat file, return empty struct if missing
if exist(filepath, 'file')
    data = load(filepath, varname);
    summary = data.(varname);
else
    warning('Summary file not found: %s', filepath);
    summary = struct();
end
end

function writeComparisonPreamble(fid)
%WRITECOMPARISONPREAMBLE Write LaTeX document preamble
fprintf(fid, '\\documentclass[sigconf,nonacm]{acmart}\n\n');
fprintf(fid, '\\settopmatter{printacmref=false}\n');
fprintf(fid, '\\renewcommand\\footnotetextcopyrightpermission[1]{}\n');
fprintf(fid, '\\pagestyle{plain}\n\n');
fprintf(fid, '\\usepackage{booktabs}\n');
fprintf(fid, '\\usepackage{multirow}\n');
fprintf(fid, '\\usepackage{graphicx}\n');
fprintf(fid, '\\usepackage{float}\n\n');
fprintf(fid, '\\begin{document}\n\n');
fprintf(fid, '\\title{Comparison Tables with Wilcoxon Rank-Sum Tests}\n\n');
fprintf(fid, '\\author{Anonymous Author(s)}\n');
fprintf(fid, '\\affiliation{\\institution{Institution Name}\\city{City}\\country{Country}}\n');
fprintf(fid, '\\email{author@email.com}\n\n');
fprintf(fid, '\\maketitle\n\n');
end

function probDisplayNames = buildProbDisplayNames()
%BUILDPROBDISPLAYNAMES Build problem display name mappings for LaTeX
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
end
