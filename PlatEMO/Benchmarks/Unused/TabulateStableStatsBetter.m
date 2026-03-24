generateSupplementaryMaterials('./Info/StableStatistics')
hvSummaryPath = './Info/FinalHV/hvSummary.mat';
igdpSummaryPath = './Info/FinalIGD/igdSummary.mat';

for ph=1:numel(phs)
    problemName = func2str(ph);
end

function generateSupplementaryMaterials(baseDir, hvSummaryPath, igdpSummaryPath)
% generateSupplementaryMaterials - Generate ACM-format supplementary materials
%
% Usage: generateSupplementaryMaterials('./StableStatistics')
%
% Generates a complete LaTeX document with stability tables split across
% multiple pages (max 30 problems per table).

if nargin < 1
    baseDir = './StableStatistics';
end

hvData = load(hvSummaryPath, 'hvSummary');
hvSummary = hvData.hvSummary;
igdpData = load(igdpSummaryPath, 'igdSummary');
igdpSummary = igdpData.igdSummary;

%% Define Problem Lists
% % 2D Problems
problems2D = {'UF7', 'UF5', 'UF6', 'BT1', 'BT2', 'BT3', 'BT4', 'BT6', 'BT7', 'BT8', ...
    'ZDT1', 'ZDT4', 'IMOP1', 'UF1', 'UF2', 'UF3', 'IMOP2', 'UF4', 'ZDT2', 'ZDT6', ...
    'RWA1', 'BT5', 'IMOP3', 'ZDT3'};
% 
% % 3D Problems
% problems3D = {'DTLZ1', 'IDTLZ1', 'MaF1', 'MaF14', 'MinusDTLZ1', 'MinusWFG3', 'SDTLZ1', ...
%     'IDTLZ2', 'MaF3', 'MaF4', 'MaF15', 'MinusDTLZ2', 'MinusDTLZ3', 'MinusDTLZ4', ...
%     'MinusDTLZ5', 'MinusDTLZ6', 'MinusWFG4', 'MinusWFG5', 'MinusWFG6', 'MinusWFG7', ...
%     'MinusWFG8', 'MinusWFG9', 'VNT1', 'BT9', 'DTLZ2', 'DTLZ3', 'DTLZ4', 'MaF2', ...
%     'MaF5', 'MaF13', 'SDTLZ2', 'UF8', 'UF10', 'WFG4', 'WFG5', 'WFG6', 'WFG7', ...
%     'WFG8', 'WFG9', 'DTLZ5', 'DTLZ6', 'IMOP4', 'DTLZ7', 'IMOP5', 'IMOP6', 'IMOP7', ...
%     'IMOP8', 'MinusWFG1', 'MinusWFG2', 'RWA2', 'RWA3', 'RWA4', 'RWA5', 'RWA6', ...
%     'RWA7', 'UF9', 'VNT2', 'VNT3', 'WFG1', 'WFG2', 'WFG3'};

% % % Filtered 2D Problems
% problems2D = {'UF1', 'UF4', 'UF5', 'UF6', ...
%     'BT1', 'BT3', 'BT5', 'BT6', ...
%     'IMOP1', 'ZDT2', 'ZDT3', 'ZDT4', 'RWA1'};
% % 
% % % Filtered 3D Problems
% problems3D = {'DTLZ1', 'DTLZ2', 'DTLZ6', 'DTLZ7', ...
%     'IDTLZ1', 'IDTLZ2', 'MinusDTLZ1', 'MinusDTLZ2', ...
%     'SDTLZ1', 'SDTLZ2', 'MaF4', 'MaF5', ...
%     'MinusWFG9', 'MinusWFG1', 'MinusWFG2', ...
%     'WFG9', 'WFG1', 'WFG2', 'VNT1', 'BT9', ...
%     'UF10', 'UF9', 'IMOP4', 'IMOP5', ...
%     'RWA2', 'RWA3', 'RWA4', 'RWA5'};



problems2D = {'DTLZ1'};

% Filtered 3D Problems
problems3D = {'DTLZ1', 'DTLZ2', ...
    'IDTLZ1', 'IDTLZ2', ...
    'WFG1', 'WFG2', ...
    'RWA9'};

%% Define Verdicts Map
verdicts = containers.Map();
% 2D Problems
verdicts('BT1') = 'Py-NSGA-III';
verdicts('BT2') = 'Py-NSGA-III';
verdicts('BT3') = 'Py-NSGA-III';
verdicts('BT4') = 'Py-NSGA-III';
verdicts('BT5') = 'Py-NSGA-III';
verdicts('BT6') = 'Pl-NSGA-III';
verdicts('BT7') = 'Neither';
verdicts('BT8') = 'Py-NSGA-III';
verdicts('IMOP1') = 'Py-NSGA-III';
verdicts('IMOP2') = 'Both';
verdicts('IMOP3') = 'Both';
verdicts('RWA1') = 'Both';
verdicts('UF1') = 'Neither';
verdicts('UF2') = 'Both';
verdicts('UF3') = 'Py-NSGA-III';
verdicts('UF4') = 'Py-NSGA-III';
verdicts('UF5') = 'Neither';
verdicts('UF6') = 'Neither';
verdicts('UF7') = 'Neither';
verdicts('ZDT1') = 'Both';
verdicts('ZDT2') = 'Both';
verdicts('ZDT3') = 'Pl-NSGA-III';
verdicts('ZDT4') = 'Pl-NSGA-III';
verdicts('ZDT6') = 'Both';

% 3D Problems
verdicts('BT9') = 'Py-NSGA-III';
verdicts('DTLZ1') = 'Both';
verdicts('DTLZ2') = 'Both';
verdicts('DTLZ3') = 'Py-NSGA-III';
verdicts('DTLZ4') = 'Py-NSGA-III';
verdicts('DTLZ5') = 'Py-NSGA-III';
verdicts('DTLZ6') = 'Py-NSGA-III';
verdicts('DTLZ7') = 'Py-NSGA-III';
verdicts('IDTLZ1') = 'Py-NSGA-III';
verdicts('IDTLZ2') = 'Py-NSGA-III';
verdicts('IMOP4') = 'Py-NSGA-III';
verdicts('IMOP5') = 'Py-NSGA-III';
verdicts('IMOP6') = 'Py-NSGA-III';
verdicts('IMOP7') = 'Py-NSGA-III';
verdicts('IMOP8') = 'Py-NSGA-III';
verdicts('MaF1') = 'Py-NSGA-III';
verdicts('MaF2') = 'Py-NSGA-III';
verdicts('MaF3') = 'Both';
verdicts('MaF4') = 'Py-NSGA-III';
verdicts('MaF5') = 'Py-NSGA-III';
verdicts('MaF13') = 'Py-NSGA-III';
verdicts('MaF14') = 'Both';
verdicts('MaF15') = 'Py-NSGA-III';
verdicts('MinusDTLZ1') = 'Py-NSGA-III';
verdicts('MinusDTLZ2') = 'Py-NSGA-III';
verdicts('MinusDTLZ3') = 'Py-NSGA-III';
verdicts('MinusDTLZ4') = 'Py-NSGA-III';
verdicts('MinusDTLZ5') = 'Py-NSGA-III';
verdicts('MinusDTLZ6') = 'Py-NSGA-III';
verdicts('MinusWFG1') = 'Py-NSGA-III';
verdicts('MinusWFG2') = 'Both';
verdicts('MinusWFG3') = 'Py-NSGA-III';
verdicts('MinusWFG4') = 'Py-NSGA-III';
verdicts('MinusWFG5') = 'Py-NSGA-III';
verdicts('MinusWFG6') = 'Py-NSGA-III';
verdicts('MinusWFG7') = 'Py-NSGA-III';
verdicts('MinusWFG8') = 'Py-NSGA-III';
verdicts('MinusWFG9') = 'Py-NSGA-III';
verdicts('RWA2') = 'Py-NSGA-III';
verdicts('RWA3') = 'Py-NSGA-III';
verdicts('RWA4') = 'Both';
verdicts('RWA5') = 'Pl-NSGA-III';
verdicts('RWA6') = 'Py-NSGA-III';
verdicts('RWA7') = 'Py-NSGA-III';
verdicts('SDTLZ1') = 'Py-NSGA-III';
verdicts('SDTLZ2') = 'Both';
verdicts('UF8') = 'Py-NSGA-III';
verdicts('UF9') = 'Py-NSGA-III';
verdicts('UF10') = 'Neither';
verdicts('VNT1') = 'Py-NSGA-III';
verdicts('VNT2') = 'Both';
verdicts('VNT3') = 'Both';
verdicts('WFG1') = 'Py-NSGA-III';
verdicts('WFG2') = 'Pl-NSGA-III';
verdicts('WFG3') = 'Py-NSGA-III';
verdicts('WFG4') = 'Both';
verdicts('WFG5') = 'Both';
verdicts('WFG6') = 'Both';
verdicts('WFG7') = 'Both';
verdicts('WFG8') = 'Py-NSGA-III';
verdicts('WFG9') = 'Py-NSGA-III';
verdicts('RWA9') = 'Py-NSGA-III';

%% Algorithm and Problem Name Mappings
algDisplayNames = containers.Map();
algDisplayNames('NSGAIIIwH') = 'Pl-NSGA-III';
algDisplayNames('PyNSGAIIIwH') = 'Py-NSGA-III';

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

%% Parse all mat files
allData = parseAllMatFiles(baseDir);

if isempty(allData)
    error('No data found in %s', baseDir);
end

%% Generate the supplementary materials LaTeX document
generateSupplementaryLaTeX(allData, problems2D, problems3D, ...
    verdicts, algDisplayNames, probDisplayNames, hvSummary, igdpSummary);

fprintf('Supplementary materials generated successfully!\n');
end

%% ========================================================================
%  PARSING FUNCTIONS
%  ========================================================================

function allData = parseAllMatFiles(baseDir)
% Parse all SS-*.mat files from algorithm subdirectories

allData = struct('problem', {}, 'algorithm', {}, 'type', {}, ...
                 'stable_runs', {}, 'total_runs', {}, ...
                 'cluster_radius_med', {}, 'bias_L2', {}, 'avg_stable_gen', {});

% Get algorithm directories
algDirs = dir(baseDir);
algDirs = algDirs([algDirs.isdir] & ~startsWith({algDirs.name}, '.'));
algNames = {algDirs.name};

for i = 1:length(algNames)
    algName = algNames{i};
    algPath = fullfile(baseDir, algName);
    matFiles = dir(fullfile(algPath, 'SS-*.mat'));
    
    for j = 1:length(matFiles)
        fname = matFiles(j).name;
        % Parse filename: SS-{Type}-{Alg}-{Prob}.mat
        tokens = regexp(fname, 'SS-(\w+)-(\w+)-(\w+)\.mat', 'tokens');
        if isempty(tokens)
            warning('Could not parse filename: %s', fname);
            continue;
        end
        
        pointType = tokens{1}{1};  % Ideal or Nadir
        probName = tokens{1}{3};
        
        % Load data
        data = load(fullfile(algPath, fname));
        
        % Store entry
        entry.problem = probName;
        entry.algorithm = algName;
        entry.type = pointType;
        entry.stable_runs = data.stable_runs;
        entry.total_runs = data.total_runs;
        entry.cluster_radius_med = data.cluster_radius_med;
        entry.bias_L2 = data.bias_L2;
        entry.avg_stable_gen = data.avg_stable_gen;
        
        allData(end+1) = entry;
    end
end
end

%% ========================================================================
%  LATEX GENERATION
%  ========================================================================

function generateSupplementaryLaTeX(allData, problems2D, problems3D, ...
    verdicts, algDisplayNames, probDisplayNames, hvSummary, igdpSummary)

filename = 'SupplementaryMaterials.tex';
fid = fopen(filename, 'w');

% Write document preamble
writeDocumentPreamble(fid);

% Sort all problems
sorted2D = problems2D(getNaturalOrder(problems2D));
sorted3D = problems3D(getNaturalOrder(problems3D));

% Combine all problems with dimension labels
allProblems = {};
problemDims = {};
for i = 1:length(sorted2D)
    allProblems{end+1} = sorted2D{i};
    problemDims{end+1} = '2D';
end
for i = 1:length(sorted3D)
    allProblems{end+1} = sorted3D{i};
    problemDims{end+1} = '3D';
end

% Split into chunks of max 30 problems
maxProblemsPerTable = 30;
numProblems = length(allProblems);
numTables = ceil(numProblems / maxProblemsPerTable);

tableNum = 1;
probIdx = 1;

while probIdx <= numProblems
    % Determine problems for this table
    endIdx = min(probIdx + maxProblemsPerTable - 1, numProblems);
    tableProblems = allProblems(probIdx:endIdx);
    tableDims = problemDims(probIdx:endIdx);
    
    % Determine table title
    if tableNum == 1
        if strcmp(tableDims{1}, '2D')
            tableTitle = '2-Objective Problems';
        else
            tableTitle = '3-Objective Problems';
        end
    else
        % Check if this table starts with 3D after 2D
        if probIdx > length(sorted2D)
            tableTitle = '3-Objective Problems (continued)';
        else
            tableTitle = '2-Objective Problems (continued)';
        end
    end
    
    % Write page break before new table (except first)
    if tableNum > 1
        fprintf(fid, '\\clearpage\n\n');
    end
    
    % Write table
    writeTable(fid, allData, tableProblems, tableDims, tableNum, numTables, ...
        tableTitle, verdicts, algDisplayNames, probDisplayNames, ...
        probIdx, sorted2D, hvSummary, igdpSummary);
    
    probIdx = endIdx + 1;
    tableNum = tableNum + 1;
end

% Write document end
fprintf(fid, '\\end{document}\n');

fclose(fid);
fprintf('Generated: %s\n', filename);
end

function writeDocumentPreamble(fid)
% Write the LaTeX document preamble

fprintf(fid, '\\documentclass[sigconf,nonacm]{acmart}\n\n');
fprintf(fid, '%% Remove ACM reference format and other unnecessary elements for supplementary\n');
fprintf(fid, '\\settopmatter{printacmref=false}\n');
fprintf(fid, '\\renewcommand\\footnotetextcopyrightpermission[1]{}\n');
fprintf(fid, '\\pagestyle{plain}\n\n');
fprintf(fid, '\\usepackage{booktabs}\n');
fprintf(fid, '\\usepackage{multirow}\n');
fprintf(fid, '\\usepackage{graphicx}\n');
fprintf(fid, '\\usepackage{float}\n\n');
fprintf(fid, '\\begin{document}\n\n');

% Title
fprintf(fid, '%%%% Title\n');
fprintf(fid, '\\title{Supplementary Materials for: \\\\ A Comparative Study on Reference Point Estimation Stability in NSGA-III Implementations}\n\n');

% Authors (placeholders)
fprintf(fid, '%%%% Authors (placeholders)\n');
fprintf(fid, '\\author{First Author}\n');
fprintf(fid, '\\affiliation{%%\n');
fprintf(fid, '  \\institution{Institution Name}\n');
fprintf(fid, '  \\city{City}\n');
fprintf(fid, '  \\country{Country}\n');
fprintf(fid, '}\n');
fprintf(fid, '\\email{first.author@email.com}\n\n');

fprintf(fid, '\\author{Second Author}\n');
fprintf(fid, '\\affiliation{%%\n');
fprintf(fid, '  \\institution{Institution Name}\n');
fprintf(fid, '  \\city{City}\n');
fprintf(fid, '  \\country{Country}\n');
fprintf(fid, '}\n');
fprintf(fid, '\\email{second.author@email.com}\n\n');

fprintf(fid, '\\author{Third Author}\n');
fprintf(fid, '\\affiliation{%%\n');
fprintf(fid, '  \\institution{Institution Name}\n');
fprintf(fid, '  \\city{City}\n');
fprintf(fid, '  \\country{Country}\n');
fprintf(fid, '}\n');
fprintf(fid, '\\email{third.author@email.com}\n\n');

fprintf(fid, '\\maketitle\n\n');

% Overview section
fprintf(fid, '\\section*{Overview}\n');
fprintf(fid, 'This supplementary material provides the complete stability analysis results for all benchmark problems examined in our study.\n\n');
fprintf(fid, '\\textbf{Legend:}\n');
fprintf(fid, '\\begin{itemize}\n');
fprintf(fid, '    \\item \\textbf{Symbols}: $\\bigcirc$ consistent/unbiased, \\scalebox{1.35}{$\\triangle$} semi-consistent/marginally biased, \\scalebox{1.2}{$\\times$} inconsistent/biased\n');
fprintf(fid, '    \\item \\textbf{--} (en-dash): No stable runs were observed\n');
fprintf(fid, '    \\item \\textbf{Verdict}: ``Both'''' = both implementations are okay, ``Neither'''' = neither performs well, otherwise the more stable implementation is listed\n');
fprintf(fid, '\\end{itemize}\n\n');
fprintf(fid, '\\clearpage\n\n');
end

function writeTable(fid, allData, problems, dims, tableNum, totalTables, ...
    tableTitle, verdicts, algDisplayNames, probDisplayNames, startIdx, sorted2D, hvSummary, igdpSummary)
% Write a single table

% Table header
fprintf(fid, '\\begin{table*}[htbp]\n');
fprintf(fid, '\\centering\n');
fprintf(fid, '\\caption{Stability Analysis of Ideal and Nadir Point Estimation (Part %d of %d)}\n', tableNum, totalTables);
fprintf(fid, '\\label{tab:stability_part%d}\n', tableNum);
fprintf(fid, '\\scriptsize\n');
fprintf(fid, '\\setlength{\\tabcolsep}{5pt}\n');
fprintf(fid, '\\begin{tabular}{ll cc cccc cccc c}\n');
fprintf(fid, '\\toprule\n');

% Column headers (13 columns total)
fprintf(fid, ' & & & & \\multicolumn{4}{c}{\\textbf{Ideal Point}} & \\multicolumn{4}{c}{\\textbf{Nadir Point}} & \\\\\n');
fprintf(fid, '\\cmidrule(lr){5-8} \\cmidrule(lr){9-12}\n');
fprintf(fid, '\\textbf{Problem} & \\textbf{Algorithm} & \\textbf{Final IGD$^+$ $(\\downarrow)$} & \\textbf{Final HV $(\\uparrow)$} & ');
fprintf(fid, '\\textbf{\\%%Stable} & \\textbf{Average} & \\textbf{Spatial} & \\textbf{Bias} & ');
fprintf(fid, '\\textbf{\\%%Stable} & \\textbf{Average} & \\textbf{Spatial} & \\textbf{Bias} & \\textbf{Verdict} \\\\\n');
fprintf(fid, ' & & & & ');
fprintf(fid, ' & \\textbf{Stable Gen.} & \\textbf{Consistency} & & ');
fprintf(fid, ' & \\textbf{Stable Gen.} & \\textbf{Consistency} & & \\\\\n');
fprintf(fid, '\\midrule\n');

% Track current dimension for section headers
currentDim = '';
num2D = length(sorted2D);

for p = 1:length(problems)
    prob = problems{p};
    dim = dims{p};
    isLastInTable = (p == length(problems));
    
    % Check if we need a section header
    if ~strcmp(dim, currentDim)
        if strcmp(dim, '2D')
            fprintf(fid, '\\multicolumn{13}{l}{\\textbf{2-Objective Problems}} \\\\\n');
            fprintf(fid, '\\midrule\n');
        else
            if ~isempty(currentDim)
                fprintf(fid, '\\midrule\n');
            end
            fprintf(fid, '\\multicolumn{13}{l}{\\textbf{3-Objective Problems}} \\\\\n');
            fprintf(fid, '\\midrule\n');
        end
        currentDim = dim;
    end
    
    % Write problem rows
    writeProblemRows(fid, allData, prob, verdicts, algDisplayNames, probDisplayNames, isLastInTable, hvSummary, igdpSummary);
end

% Table footer
fprintf(fid, '\\bottomrule\n');
fprintf(fid, '\\end{tabular}\n');
fprintf(fid, '\\vspace{2mm}\n');
fprintf(fid, '\\\\\\footnotesize \\textbf{Symbols}: $\\bigcirc$ consistent/unbiased, \\scalebox{1.35}{$\\triangle$} semi-consistent/marginally biased, \\scalebox{1.2}{$\\times$} inconsistent/biased.\n');
fprintf(fid, '\\end{table*}\n\n');
end

function writeProblemRows(fid, allData, prob, verdicts, algDisplayNames, probDisplayNames, isLastInSection, hvSummary, igdpSummary)
% Write rows for a single problem

% Get algorithms available for this problem
algNames = unique({allData.algorithm});
algNames = sort(algNames);

% Get data for both algorithms
algData = struct();
for a = 1:length(algNames)
    alg = algNames{a};
    
    idxIdeal = find(strcmp({allData.problem}, prob) & ...
                    strcmp({allData.algorithm}, alg) & ...
                    strcmp({allData.type}, 'Ideal'));
    
    idxNadir = find(strcmp({allData.problem}, prob) & ...
                    strcmp({allData.algorithm}, alg) & ...
                    strcmp({allData.type}, 'Nadir'));
    
    if ~isempty(idxIdeal) || ~isempty(idxNadir)
        algData(a).name = alg;
        algData(a).ideal = [];
        algData(a).nadir = [];
        
        if ~isempty(idxIdeal)
            algData(a).ideal = allData(idxIdeal);
        end
        if ~isempty(idxNadir)
            algData(a).nadir = allData(idxNadir);
        end
    end
end

% Filter out empty entries
validAlgs = [];
for a = 1:length(algData)
    if ~isempty(algData(a).name)
        validAlgs(end+1) = a;
    end
end

if isempty(validAlgs)
    return;
end

numAlgs = length(validAlgs);

% Get verdict
if isKey(verdicts, prob)
    verdictText = verdicts(prob);
else
    verdictText = '???';  % Unknown verdict
    warning('No verdict defined for problem: %s', prob);
end

% Get display name
if isKey(probDisplayNames, prob)
    probDisplay = probDisplayNames(prob);
else
    probDisplay = prob;
end

probField = matlab.lang.makeValidName(prob);

% Write rows
for i = 1:numAlgs
    a = validAlgs(i);
    alg = algData(a).name;
    
    if isKey(algDisplayNames, alg)
        algDisplay = algDisplayNames(alg);
    else
        algDisplay = alg;
    end

    % Get Final IGD+ and HV for this algorithm
    finalIGDp = getIGDpString(igdpSummary, probField, alg);
    finalHV = getHVString(hvSummary, probField, alg);
    
    % Format Ideal columns
    if ~isempty(algData(a).ideal)
        idealCols = formatDataColumns(algData(a).ideal);
    else
        idealCols = {'--', '--', '--', '--'};
    end
    
    % Format Nadir columns
    if ~isempty(algData(a).nadir)
        nadirCols = formatDataColumns(algData(a).nadir);
    else
        nadirCols = {'--', '--', '--', '--'};
    end
    
    % Write row (13 columns)
    if i == 1
        fprintf(fid, '\\multirow{%d}{*}{%s} & %s & %s & %s & %s & %s & %s & %s & %s & %s & %s & %s & \\multirow{%d}{*}{%s} \\\\\n', ...
            numAlgs, probDisplay, algDisplay, finalIGDp, finalHV, ...
            idealCols{1}, idealCols{2}, idealCols{3}, idealCols{4}, ...
            nadirCols{1}, nadirCols{2}, nadirCols{3}, nadirCols{4}, ...
            numAlgs, verdictText);
    else
        fprintf(fid, ' & %s & %s & %s & %s & %s & %s & %s & %s & %s & %s & %s & \\\\\n', ...
            algDisplay, finalIGDp, finalHV, ...
            idealCols{1}, idealCols{2}, idealCols{3}, idealCols{4}, ...
            nadirCols{1}, nadirCols{2}, nadirCols{3}, nadirCols{4});
    end
end

% Add horizontal rule after problem (unless it's the last in the section)
if ~isLastInSection
    fprintf(fid, '\\cmidrule{1-13}\n');
end
end

function cols = formatDataColumns(d)
% Format the 4 data columns: %Stable, Avg Gen, Spatial, Bias

pctStable = 100 * d.stable_runs / d.total_runs;
col1 = sprintf('%.0f\\%%', pctStable);

if d.stable_runs == 0
    col2 = '--';
    col3 = '--';
    col4 = '--';
else
    col2 = sprintf('%d', round(d.avg_stable_gen));
    
    [spatialSym, ~] = classifySpatialStability(d.cluster_radius_med);
    spatialNum = formatScientific(d.cluster_radius_med);
    col3 = sprintf('%s %s', spatialSym, spatialNum);
    
    [biasSym, ~] = classifyBias(d.bias_L2);
    biasNum = formatScientific(d.bias_L2);
    col4 = sprintf('%s %s', biasSym, biasNum);
end

cols = {col1, col2, col3, col4};
end

%% ========================================================================
%  CLASSIFICATION FUNCTIONS
%  ========================================================================

function [symbol, text] = classifySpatialStability(rho_med)
if rho_med < 0.01
    symbol = '$\bigcirc$';
    text = 'stable';
elseif rho_med < 0.1
    symbol = '\scalebox{1.35}{$\triangle$}';
    text = 'semi-stable';
else
    symbol = '\scalebox{1.2}{$\times$}';
    text = 'unstable';
end
end

function [symbol, text] = classifyBias(bias)
if bias < 0.01
    symbol = '$\bigcirc$';
    text = 'unbiased';
elseif bias < 0.1
    symbol = '\scalebox{1.35}{$\triangle$}';
    text = 'marginally biased';
else
    symbol = '\scalebox{1.2}{$\times$}';
    text = 'biased';
end
end

function str = formatScientific(val)
if val == 0
    str = '0.0e+00';
    return;
end

exponent = floor(log10(abs(val)));
mantissa = val / (10^exponent);

if exponent >= 0
    str = sprintf('%.1fe+%02d', mantissa, exponent);
else
    str = sprintf('%.1fe%03d', mantissa, exponent);
end
end

%% ========================================================================
%  METRIC STRING FUNCTIONS
%  ========================================================================

function hvStr = getHVString(hvSummary, probField, alg)
% Get the HV string (mean ± std) for a problem-algorithm pair

hvStr = 'N/A';

if isempty(fieldnames(hvSummary))
    return;
end

if isfield(hvSummary, probField)
    probData = hvSummary.(probField);
    if isfield(probData, alg)
        hvStr = probData.(alg);
        % Convert ± to LaTeX $\pm$
        hvStr = strrep(hvStr, '±', '$\pm$');
    end
end
end

function igdpStr = getIGDpString(igdpSummary, probField, alg)
% Get the IGD+ string (mean ± std) for a problem-algorithm pair
% Formats values in scientific notation for consistent string lengths

igdpStr = 'N/A';

if isempty(fieldnames(igdpSummary))
    return;
end

if isfield(igdpSummary, probField)
    probData = igdpSummary.(probField);
    if isfield(probData, alg)
        rawStr = probData.(alg);
        
        % Try to parse "mean ± std" or "mean ± std" format
        % Handle both ± and ± characters
        if contains(rawStr, '±')
            parts = strsplit(rawStr, '±');
        elseif contains(rawStr, char(177))  % ± character
            parts = strsplit(rawStr, char(177));
        else
            % Can't parse, return with LaTeX formatting attempt
            igdpStr = strrep(rawStr, '±', '$\\pm$');
            return;
        end
        
        if length(parts) == 2
            meanVal = str2double(strtrim(parts{1}));
            stdVal = str2double(strtrim(parts{2}));
            
            if ~isnan(meanVal) && ~isnan(stdVal)
                % Format both in scientific notation for consistent length
                meanStr = formatScientificIGDp(meanVal);
                stdStr = formatScientificIGDp(stdVal);
                igdpStr = sprintf('%s $\\pm$ %s', meanStr, stdStr);
            else
                % Parsing failed, return original with LaTeX ±
                igdpStr = strrep(rawStr, '±', '$\\pm$');
            end
        else
            igdpStr = strrep(rawStr, '±', '$\\pm$');
        end
    end
end
end

function str = formatScientificIGDp(val)
% Format IGD+ value in scientific notation with consistent length
% Output format: X.XXe±YY (e.g., 1.23e-02, 4.56e+01)

if val == 0
    str = '0.00e+00';
    return;
end

exponent = floor(log10(abs(val)));
mantissa = val / (10^exponent);

% Use 2 decimal places for mantissa for consistent length
if exponent >= 0
    str = sprintf('%.2fe+%02d', mantissa, exponent);
else
    str = sprintf('%.2fe%03d', mantissa, exponent);  % e-01, e-02, etc.
end
end

%% ========================================================================
%  UTILITY FUNCTIONS
%  ========================================================================

function sortedIndices = getNaturalOrder(strList)
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