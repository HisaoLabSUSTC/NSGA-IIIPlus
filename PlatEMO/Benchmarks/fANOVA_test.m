%% fANOVA_test - Functional ANOVA analysis for NSGA-III configuration space
%
%   MATLAB-native implementation of fANOVA (Hutter et al., 2014).
%   No Python dependency required.
%
%   Workflow:
%     1. Define full configuration space (Area1 x Area2 x Area3)
%     2. Sample a subset of configurations (stratified random)
%     3. Evaluate only sampled configs via existing pipeline
%     4. Collect metric values for sampled configs
%     5. Train random forest surrogates (TreeBagger)
%     6. Predict on full config space + fANOVA decomposition
%     7. Generate marginal prediction plots
%     8. Save results (CSV, LaTeX, plots)
%
%   Configuration space:
%     Area 1 (Implementation): none, Z, Y, X, ZY, ZX, YX, ZYX  (8 levels)
%     Area 2 (Normalization): none, tikhonov  (2 levels)
%     Area 3 (Selection):        none, dss     (2 levels)
%     Total: 8 x 2 x 2 = 32 configurations
%
%   Sampling: Only ~50 configs are evaluated. Random forest surrogates
%   interpolate the rest, enabling variance decomposition over the
%   full space without exhaustive evaluation.
%
%   Reference:
%     Hutter, F., Hoos, H., & Leyton-Brown, K. (2014). An Efficient
%     Approach for Assessing Hyperparameter Importance. ICML 2014.

%% ========================================================================
%  CONFIGURATION
%  ========================================================================

% Evaluation mode:
%   'full'         - Run benchmarks, trim, compute metrics, summarize
%   'metrics_only' - Skip benchmarks/trim, recompute metrics from existing TrimmedData
%   'collect_only' - Skip all computation, just collect existing summaries
evaluationMode = 'full';

% Factor levels (full configuration space)
% area1Levels = {'none', 'Z', 'Y', 'X', 'ZY', 'ZX', 'YX', 'ZYX'};
% area2Levels = {'none', 'tikhonov'};
% area3Levels = {'none', 'dss'};

area1Levels = {'none', 'Z', 'Y', 'X', 'ZY', 'ZX', 'YX', 'ZYX'};
area2Levels = {'none', 'tikhonov'};
area3Levels = {'none', 'dss'};
area4Levels = {'none'};
area5Levels = {'none'};

% Number of configurations to sample and evaluate
% Set to Inf to evaluate all (falls back to exhaustive)
nSamples = 300;

% Problems for evaluation
problems = {@DTLZ1, @DTLZ7};

% Benchmark parameters
% FE = N * M * 1000;
params = struct(...
    'FE',   360000, ...   % Max function evaluations
    'N',    120, ...      % Population size
    'M',    3, ...        % Number of objectives
    'runs', 3 ...         % Independent runs
);

% Random forest settings
nTrees = 16;             % Number of trees in ensemble
rngSeed = 42;             % Reproducibility

% Output directory
outputDir = './Info/fANOVA-DTLZ';

% Configuration space file path (saved/loaded automatically)
configSpaceFile = fullfile(outputDir, 'configSpace.mat');

% Index range for distributed evaluation (empty = all sampled configs)
% Set to [startIdx, endIdx] to evaluate a subset, e.g., [1, 166]
evalRange = [];

%% ========================================================================
%%  STEPS 1-2: LOAD OR GENERATE CONFIGURATION SPACE + SAMPLE
%% ========================================================================

% Check if a saved config space exists with the right sample count
canLoad = false;
if exist(configSpaceFile, 'file')
    csInfo = whos('-file', configSpaceFile);
    csVarNames = {csInfo.name};
    if ismember('nSampled', csVarNames) && ismember('sampleIdx', csVarNames)
        tmp = load(configSpaceFile, 'nSampled');
        if tmp.nSampled == min(nSamples, numel(area1Levels)*numel(area2Levels)* ...
                numel(area3Levels)*numel(area4Levels)*numel(area5Levels))
            canLoad = true;
        else
            fprintf('  configSpace.mat has %d samples but need %d, regenerating.\n', ...
                tmp.nSampled, nSamples);
        end
    else
        fprintf('  configSpace.mat missing sample data, regenerating.\n');
    end
end

if canLoad
    %% --- LOAD from saved file ---
    fprintf('\n========== Steps 1-2: Loading Saved Configuration Space ==========\n');
    loaded = load(configSpaceFile);
    allArea1Idx = loaded.allArea1Idx;
    allArea2Idx = loaded.allArea2Idx;
    allArea3Idx = loaded.allArea3Idx;
    allArea4Idx = loaded.allArea4Idx;
    allArea5Idx = loaded.allArea5Idx;
    allArea1    = loaded.allArea1;
    allArea2    = loaded.allArea2;
    allArea3    = loaded.allArea3;
    allArea4    = loaded.allArea4;
    allArea5    = loaded.allArea5;
    allAlgNames = loaded.allAlgNames;
    allAlgSpecs = loaded.allAlgSpecs;
    Xall        = loaded.Xall;
    totalConfigs = loaded.totalConfigs;
    n1 = loaded.n1; n2 = loaded.n2; n3 = loaded.n3;
    n4 = loaded.n4; n5 = loaded.n5;
    area1Levels = loaded.area1Levels;
    area2Levels = loaded.area2Levels;
    area3Levels = loaded.area3Levels;
    area4Levels = loaded.area4Levels;
    area5Levels = loaded.area5Levels;
    sampleIdx    = loaded.sampleIdx;
    sampledNames = loaded.sampledNames;
    nSampled     = loaded.nSampled;
    sampledSpecs = allAlgSpecs(sampleIdx);

    fprintf('  Loaded %d sampled configs from: %s\n', nSampled, configSpaceFile);
    fprintf('  Total configuration space: %d\n', totalConfigs);
else
    %% --- GENERATE: Step 1 + Step 2 ---
    fprintf('\n========== Step 1: Defining Configuration Space ==========\n');

    n1 = numel(area1Levels);
    n2 = numel(area2Levels);
    n3 = numel(area3Levels);
    n4 = numel(area4Levels);
    n5 = numel(area5Levels);
    totalConfigs = n1 * n2 * n3 * n4 * n5;

    fprintf('  Area 1 (Implementation): %d levels\n', n1);
    fprintf('  Area 2 (Momentum):       %d levels\n', n2);
    fprintf('  Area 3 (Selection):      %d levels\n', n3);
    fprintf('  Area 4 (Ref. Vectors):   %d levels\n', n4);
    fprintf('  Area 5 (Offspring):      %d levels\n', n5);
    fprintf('  Total configuration space: %d\n', totalConfigs);

    % Enumerate ALL configs (for RF prediction later)
    allArea1Idx = zeros(totalConfigs, 1);
    allArea2Idx = zeros(totalConfigs, 1);
    allArea3Idx = zeros(totalConfigs, 1);
    allArea4Idx = zeros(totalConfigs, 1);
    allArea5Idx = zeros(totalConfigs, 1);
    allArea1    = cell(totalConfigs, 1);
    allArea2    = cell(totalConfigs, 1);
    allArea3    = cell(totalConfigs, 1);
    allArea4    = cell(totalConfigs, 1);
    allArea5    = cell(totalConfigs, 1);
    allAlgNames = cell(totalConfigs, 1);
    allAlgSpecs = cell(totalConfigs, 1);

    idx = 0;
    for i1 = 1:n1
        for i2 = 1:n2
            for i3 = 1:n3
                for i4 = 1:n4
                    for i5 = 1:n5
                        idx = idx + 1;
                        allArea1Idx(idx) = i1;
                        allArea2Idx(idx) = i2;
                        allArea3Idx(idx) = i3;
                        allArea4Idx(idx) = i4;
                        allArea5Idx(idx) = i5;
                        allArea1{idx} = area1Levels{i1};
                        allArea2{idx} = area2Levels{i2};
                        allArea3{idx} = area3Levels{i3};
                        allArea4{idx} = area4Levels{i4};
                        allArea5{idx} = area5Levels{i5};

                        config = buildConfig(area1Levels{i1}, area2Levels{i2}, ...
                            area3Levels{i3}, area4Levels{i4}, area5Levels{i5});
                        spec = {@ConfigurableNSGAIIIwH, config};
                        allAlgNames{idx} = getAlgorithmName(spec);
                        allAlgSpecs{idx} = spec;
                    end
                end
            end
        end
    end

    % Feature matrix for full space (integer-encoded categoricals)
    Xall = [allArea1Idx, allArea2Idx, allArea3Idx, allArea4Idx, allArea5Idx];

    % Save full config space for reproducibility and cluster distribution
    ensureDir(fileparts(configSpaceFile));
    save(configSpaceFile, 'allArea1Idx', 'allArea2Idx', 'allArea3Idx', ...
        'allArea4Idx', 'allArea5Idx', 'allArea1', 'allArea2', 'allArea3', ...
        'allArea4', 'allArea5', 'allAlgNames', 'allAlgSpecs', 'Xall', ...
        'totalConfigs', 'area1Levels', 'area2Levels', 'area3Levels', ...
        'area4Levels', 'area5Levels', 'n1', 'n2', 'n3', 'n4', 'n5');
    fprintf('  Saved full config space to: %s\n', configSpaceFile);

    %% --- Step 2: Sample ---
    fprintf('\n========== Step 2: Sampling Configurations ==========\n');

    rng(rngSeed);

    if nSamples >= totalConfigs
        sampleIdx = (1:totalConfigs)';
        fprintf('  nSamples (%d) >= totalConfigs (%d): evaluating ALL configs.\n', ...
            nSamples, totalConfigs);
    else
        sampleIdx = stratifiedSample(n1, n2, n3, n4, n5, nSamples, totalConfigs, ...
            allArea1Idx, allArea2Idx, allArea3Idx, allArea4Idx, allArea5Idx);
        fprintf('  Sampled %d / %d configurations (%.0f%%).\n', ...
            numel(sampleIdx), totalConfigs, 100*numel(sampleIdx)/totalConfigs);
    end

    nSampled = numel(sampleIdx);

    % Coverage report
    for f = 1:5
        factorNamesLocal = {'Area 1', 'Area 2', 'Area 3', 'Area 4', 'Area 5'};
        nLevels = [n1, n2, n3, n4, n5];
        factorIdx = Xall(sampleIdx, f);
        covered = numel(unique(factorIdx));
        fprintf('  %s: %d/%d levels covered\n', factorNamesLocal{f}, covered, nLevels(f));
    end

    % Extract sampled algorithm specs
    sampledSpecs = allAlgSpecs(sampleIdx);
    sampledNames = allAlgNames(sampleIdx);

    fprintf('  3 Exemplar Sample configs:\n');
    showIdx = unique([1, round(nSampled/2), nSampled]);
    for s = showIdx
        ci = sampleIdx(s);
        fprintf('    [%3d] Area1=%-5s Area2=%-10s Area3=%-4s Area4=%-8s Area5=%-8s -> %s\n', ...
            ci, allArea1{ci}, allArea2{ci}, allArea3{ci}, allArea4{ci}, allArea5{ci}, allAlgNames{ci});
    end

    % Save sample indices for reproducibility and cluster distribution
    save(configSpaceFile, 'sampleIdx', 'sampledNames', 'nSampled', '-append');
    fprintf('  Saved sample indices to: %s\n', configSpaceFile);
end

%% ========================================================================
%%  STEP 3: RUN EVALUATIONS (only sampled configs)
%% ========================================================================

% Subset for distributed evaluation if evalRange is set
if ~isempty(evalRange)
    runIdx = evalRange(1):evalRange(2);
    evalSpecs = sampledSpecs(runIdx);
    evalNames = sampledNames(runIdx);
    fprintf('  Evaluating subset: configs %d to %d (%d of %d configs)\n', ...
        evalRange(1), evalRange(2), numel(runIdx), nSampled);
else
    evalSpecs = sampledSpecs;
    evalNames = sampledNames;
end

if ismember(evaluationMode, {'full'})
    fprintf('\n========== Step 3: Running Benchmarks (%d configs) ==========\n', numel(evalSpecs));
    runBenchmarks(evalSpecs, problems, params);

    fprintf('\n========== Step 3b: Trimming Data ==========\n');
    trimBenchmarkData(evalSpecs, './Data', './TrimmedData');

    fprintf('\n========== Step 3c: Generating Reference PFs ==========\n');
    generateReferencePF(problems, params.M, 3000);
    GenerateRefHVfromPF(problems, params.M, params.N);
else
    fprintf('\n========== Step 3: Skipped (mode: %s) ==========\n', evaluationMode);
end

% Time metrics read from ./Data/ (not TrimmedData), so always compute
if ismember(evaluationMode, {'full', 'metrics_only'})
    fprintf('\n========== Step 3d: Computing Time Metrics ==========\n');
    computeTimeMetrics(evalSpecs, problems, params);
end

generateReferencePF(problems, params.M, 3000)
GenerateRefHVfromPF(problems, params.M, params.N)

%% ========================================================================
%%  STEP 4: COMPUTE AND SUMMARIZE METRICS (only sampled configs)
%% ========================================================================
if ismember(evaluationMode, {'full', 'metrics_only'})
    fprintf('\n========== Step 4: Computing Metrics ==========\n');
    computeAllMetrics(evalSpecs, problems, params);

    fprintf('\n========== Step 4b: Summarizing Metrics ==========\n');
    SummarizeMetrics(evalSpecs, problems, params.M, params.N);
else
    fprintf('\n========== Step 4: Skipped (mode: %s) ==========\n', evaluationMode);
end

%% ========================================================================
%%  STEP 5: COLLECT METRIC VALUES FOR SAMPLED CONFIGS
%% ========================================================================
fprintf('\n========== Step 5: Collecting Metrics ==========\n');

% Reload full sample data when evalRange was used (aggregation needs all configs)
if ~isempty(evalRange)
    loaded = load(configSpaceFile, 'sampledNames', 'nSampled', 'sampleIdx', 'Xall');
    sampledNames = loaded.sampledNames;
    nSampled     = loaded.nSampled;
    sampleIdx    = loaded.sampleIdx;
    Xall         = loaded.Xall;
    fprintf('  Restored full sample data from: %s (%d configs)\n', configSpaceFile, nSampled);
end

problemNames = cellfun(@func2str, problems, 'UniformOutput', false);
numProblems = numel(problemNames);

% Load metric summaries
hvSummary      = loadSummary('./Info/FinalHV/hvSummary.mat', 'hvSummary');
igdSummary     = loadSummary('./Info/FinalIGD/igdSummary.mat', 'igdSummary');
spreadSummary  = loadSummary('./Info/FinalSpread/spreadSummary.mat', 'spreadSummary');
spacingSummary = loadSummary('./Info/FinalSpacing/spacingSummary.mat', 'spacingSummary');
timeSummary    = loadSummary('./Info/FinalTime/timeSummary.mat', 'timeSummary');

% Collect per-config aggregated metrics (average across problems)
sampledHV      = nan(nSampled, 1);
sampledIGDp    = nan(nSampled, 1);
sampledSpread  = nan(nSampled, 1);
sampledSpacing = nan(nSampled, 1);
sampledTime    = nan(nSampled, 1);

for s = 1:nSampled
    algField = matlab.lang.makeValidName(sampledNames{s});

    hvVals   = nan(numProblems, 1);
    igdVals  = nan(numProblems, 1);
    spdVals  = nan(numProblems, 1);
    spcVals  = nan(numProblems, 1);
    timeVals = nan(numProblems, 1);

    for p = 1:numProblems
        probField = matlab.lang.makeValidName(problemNames{p});
        hvVals(p)   = extractMean(hvSummary, probField, algField);
        igdVals(p)  = extractMean(igdSummary, probField, algField);
        spdVals(p)  = extractMean(spreadSummary, probField, algField);
        spcVals(p)  = extractMean(spacingSummary, probField, algField);
        timeVals(p) = extractMean(timeSummary, probField, algField);
    end

    sampledHV(s)      = mean(hvVals, 'omitnan');
    sampledIGDp(s)    = mean(igdVals, 'omitnan');
    sampledSpread(s)  = mean(spdVals, 'omitnan');
    sampledSpacing(s) = mean(spcVals, 'omitnan');
    sampledTime(s)    = mean(timeVals, 'omitnan');
end

fprintf('  Collected metrics for %d sampled configs x %d problems.\n', nSampled, numProblems);

% Training features: integer-encoded categoricals for sampled configs
Xsampled = Xall(sampleIdx, :);

%% ========================================================================
%  ENHANCED fANOVA: Per-Tree Decomposition + Visualization
%  ========================================================================
%  This script replaces Steps 6-8 of the fANOVA pipeline.
%
%  Key correction: Decompose variance PER TREE, then average fractions
%  across trees (faithful to Hutter et al. 2014, Algorithm 2).
%
%  Assumes the following variables are already in the workspace:
%    Xsampled, Xall       - sampled/full configuration matrices (N x 3)
%    sampledHV, etc.       - metric vectors for sampled configs
%    area1Levels, etc.     - cell arrays of level names
%    n1, n2, n3            - number of levels per factor
%    nTrees                - number of trees in the forest
%    totalConfigs           - total number of configs in full factorial
%    outputDir              - output directory path
%  ========================================================================

fprintf('\n========== Step 6: fANOVA (Per-Tree Decomposition) ==========\n');

metricNames   = {'HV', 'IGDp', 'Spread', 'Spacing', 'Time'};
metricDisplay = {'HV', 'IGD$^+$', 'Spread', 'Spacing', 'Time'};
metricDisplayPlain = {'HV', 'IGD+', 'Spread', 'Spacing', 'Time'};  % for plot titles
higherBetter  = [true, false, false, false, false];
metricValues  = [sampledHV, sampledIGDp, sampledSpread, sampledSpacing, sampledTime];

nMetrics = numel(metricNames);
nFactors = 5;
factorNames   = {'area1', 'area2', 'area3', 'area4', 'area5'};
factorDisplay = {'Area 1 (Implementation)', 'Area 2 (Normalization)', 'Area 3 (Selection)', 'Area 4 (Ref. Vectors)', 'Area 5 (Offspring)'};
factorShort   = {'Area 1', 'Area 2', 'Area 3', 'Area 4', 'Area 5'};
nLevelsAll    = [n1, n2, n3, n4, n5];
allLevelNames = {area1Levels, area2Levels, area3Levels, area4Levels, area5Levels};

% Detect fixed vs. active factors for graceful single-area-sweep support.
% Fixed factors (nL==1) have no variance contribution by definition and must
% be excluded from the RF feature matrix, otherwise random feature selection
% overwhelmingly picks constant columns -> degenerate trees -> all-NaN output.
activeFactors  = find(nLevelsAll > 1);
nActiveFactors = numel(activeFactors);
if nActiveFactors == 0
    error('fANOVA:noVariance', ...
        'All factors have only 1 level; nothing to analyse.');
end
if nActiveFactors < nFactors
    fixedNames = factorShort(nLevelsAll == 1);
    fprintf('  Fixed factors (excluded from RF): %s\n', strjoin(fixedNames, ', '));
end
% Reduced feature matrix: only the varying columns (used for RF training/predict)
XallActive = Xall(:, activeFactors);

%% --- Storage ---
% Per-tree approach: store F_U per tree, then report mean +/- std
mainEffects_mean = nan(nFactors, nMetrics);
mainEffects_std  = nan(nFactors, nMetrics);
nPairs = nchoosek(nFactors, 2);  % 10 pairs for 5 factors
interactions_mean = nan(nPairs, nMetrics);
interactions_std  = nan(nPairs, nMetrics);
marginalMeans    = cell(nFactors, nMetrics);
marginalStds     = cell(nFactors, nMetrics);
oobR2            = nan(nMetrics, 1);

pairIdx = nchoosek(1:nFactors, 2);  % [1 2; 1 3; 1 4; 2 3; 2 4; 3 4]

for m = 1:nMetrics
    Y = metricValues(:, m);
    validMask = ~isnan(Y);

    if sum(validMask) < 10
        warning('Only %d valid samples for %s, skipping.', sum(validMask), metricNames{m});
        continue;
    end

    Xtrain = Xsampled(validMask, activeFactors);  % only varying columns
    Ytrain = Y(validMask);
    fprintf('\n  --- %s (%d samples) ---\n', metricDisplayPlain{m}, sum(validMask));

    % Train random forest
    rf = TreeBagger(nTrees, Xtrain, Ytrain, ...
        'Method', 'regression', ...
        'CategoricalPredictors', 1:nActiveFactors, ...
        'MinLeafSize', max(3, floor(sum(validMask)/5)), ...
        'OOBPrediction', 'on');

    oobErrVec = oobError(rf);
    oobR2(m) = 1 - oobErrVec(end);
    fprintf('    OOB R^2 = %.4f\n', oobR2(m));

    % Predict on full grid using EACH tree individually
    treePreds = nan(totalConfigs, nTrees);
    for t = 1:nTrees
        treePreds(:, t) = predict(rf.Trees{t}, XallActive);  % active columns only
    end

    % =====================================================================
    %  PER-TREE fANOVA DECOMPOSITION (Algorithm 2 from Hutter et al.)
    % =====================================================================
    F_main_perTree = nan(nFactors, nTrees);   % F_i per tree
    F_pair_perTree = nan(nPairs, nTrees);     % F_{ij} per tree

    for t = 1:nTrees
        Yt = treePreds(:, t);
        mu_t = mean(Yt);
        Vtotal_t = var(Yt, 1);  % population variance

        if Vtotal_t < 1e-16
            continue;  % skip degenerate trees
        end

        % Main effects for this tree
        Vi_t = nan(nFactors, 1);
        for f = 1:nFactors
            nL = nLevelsAll(f);
            condMeans = nan(nL, 1);
            for l = 1:nL
                mask = Xall(:, f) == l;
                condMeans(l) = mean(Yt(mask));
            end
            Vi_t(f) = mean((condMeans - mu_t).^2);
            F_main_perTree(f, t) = Vi_t(f) / Vtotal_t;
        end

        % Pairwise interactions for this tree
        for pi = 1:nPairs
            fi = pairIdx(pi, 1);
            fj = pairIdx(pi, 2);
            nLi = nLevelsAll(fi);
            nLj = nLevelsAll(fj);

            jointMeans = nan(nLi * nLj, 1);
            idx = 0;
            for li = 1:nLi
                for lj = 1:nLj
                    idx = idx + 1;
                    mask = Xall(:, fi) == li & Xall(:, fj) == lj;
                    if any(mask)
                        jointMeans(idx) = mean(Yt(mask));
                    end
                end
            end

            valid = ~isnan(jointMeans);
            VijTotal_t = var(jointMeans(valid), 1);
            Vij_t = max(0, VijTotal_t - Vi_t(fi) - Vi_t(fj));
            F_pair_perTree(pi, t) = Vij_t / Vtotal_t;
        end
    end

    % Average fractions across trees (as in Hutter et al.)
    for f = 1:nFactors
        validTrees = ~isnan(F_main_perTree(f, :));
        mainEffects_mean(f, m) = mean(F_main_perTree(f, validTrees));
        mainEffects_std(f, m)  = std(F_main_perTree(f, validTrees));
    end
    for pi = 1:nPairs
        validTrees = ~isnan(F_pair_perTree(pi, :));
        interactions_mean(pi, m) = mean(F_pair_perTree(pi, validTrees));
        interactions_std(pi, m)  = std(F_pair_perTree(pi, validTrees));
    end

    % Marginal predictions (from ensemble mean, with per-tree uncertainty)
    Ypred = mean(treePreds, 2);
    mu = mean(Ypred);

    for f = 1:nFactors
        nL = nLevelsAll(f);
        mMean = nan(nL, 1);
        mStd  = nan(nL, 1);
        for l = 1:nL
            mask = Xall(:, f) == l;
            mMean(l) = mean(Ypred(mask));
            treeMargins = nan(nTrees, 1);
            for t = 1:nTrees
                treeMargins(t) = mean(treePreds(mask, t));
            end
            mStd(l) = std(treeMargins);
        end
        marginalMeans{f, m} = mMean;
        marginalStds{f, m}  = mStd;
    end

    % Print results
    for f = 1:nFactors
        fprintf('    %s: F = %.4f +/- %.4f\n', ...
            factorShort{f}, mainEffects_mean(f, m), mainEffects_std(f, m));
    end
    for pi = 1:3
        fprintf('    %s x %s: F = %.4f +/- %.4f\n', ...
            factorShort{pairIdx(pi,1)}, factorShort{pairIdx(pi,2)}, ...
            interactions_mean(pi, m), interactions_std(pi, m));
    end
end

%% ========================================================================
%% STEP 7: ENHANCED VISUALIZATION
%% ========================================================================
fprintf('\n========== Step 7: Generating Enhanced Plots ==========\n');

plotDir = fullfile(outputDir, 'plots');
if ~exist(plotDir, 'dir'), mkdir(plotDir); end

% ---- Color palette (colorblind-friendly) ----
cDefault  = [0.400 0.580 0.780];   % steel blue (normal bars)
cBest     = [0.900 0.380 0.180];   % vermilion  (best variant)
cGrid     = [0.920 0.920 0.920];   % light gray  (grid lines)
cEdge     = [0.300 0.300 0.300];   % dark gray   (bar edges)
cError    = [0.200 0.200 0.200];   % near-black  (error bars)

% ---- (A) Individual marginal bar plots (publication quality) ----
for m = 1:nMetrics
    for f = 1:nFactors
        if isempty(marginalMeans{f, m}), continue; end

        means  = marginalMeans{f, m};
        stds   = marginalStds{f, m};
        nL     = nLevelsAll(f);
        labels = allLevelNames{f};

        % Identify best variant
        if higherBetter(m)
            [~, bestIdx] = max(means);
        else
            [~, bestIdx] = min(means);
        end

        fig = figure('Visible', 'off', 'Position', [100 100 max(480, nL*70) 340]);
        ax = axes(fig);

        % Draw bars one by one so we can color the best differently
        hold(ax, 'on');
        for l = 1:nL
            if l == bestIdx
                bar(ax, l, means(l), 0.65, ...
                    'FaceColor', cBest, 'EdgeColor', cEdge, 'LineWidth', 1.2);
            else
                bar(ax, l, means(l), 0.65, ...
                    'FaceColor', cDefault, 'EdgeColor', cEdge, 'LineWidth', 0.8);
            end
        end

        % Error bars
        errorbar(ax, 1:nL, means, stds, ...
            'LineStyle', 'none', 'Color', cError, ...
            'LineWidth', 1.2, 'CapSize', 5);

        % Annotate variance fraction
        Fval = mainEffects_mean(f, m);
        Fstd = mainEffects_std(f, m);
        text(ax, nL, max(means + stds) * 1.01, ...
            sprintf('$F_{%d}$ = %.1f%% $\\pm$ %.1f%%', f, Fval*100, Fstd*100), ...
            'Interpreter', 'latex', 'FontSize', 9, ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');

        hold(ax, 'off');

        % Formatting
        set(ax, 'XTick', 1:nL, 'XTickLabel', labels, 'XTickLabelRotation', 35);
        set(ax, 'FontSize', 9, 'FontName', 'Helvetica', 'Box', 'on');
        set(ax, 'YGrid', 'on', 'GridColor', cGrid, 'GridAlpha', 1);
        xlabel(ax, factorDisplay{f}, 'FontSize', 10);
        ylabel(ax, sprintf('Predicted %s', metricDisplayPlain{m}), 'FontSize', 10);
        title(ax, sprintf('%s  vs.  %s', metricDisplayPlain{m}, factorShort{f}), ...
            'FontSize', 11, 'FontWeight', 'bold');

        % Tight y-axis with some headroom
        yRange = max(means + stds) - min(means - stds);
        if yRange < eps
            yRange = abs(mean(means)) * 0.1 + eps;
        end
        ylim(ax, [min(means - stds) - 0.1*yRange, max(means + stds) + 0.15*yRange]);

        if nLevelsAll(f) <= 1, continue; end

        exportgraphics(fig, fullfile(plotDir, ...
            sprintf('marginal_%s_%s.pdf', metricNames{m}, factorNames{f})), ...
            'ContentType', 'vector', 'Resolution', 300);
        saveas(fig, fullfile(plotDir, ...
            sprintf('marginal_%s_%s.png', metricNames{m}, factorNames{f})));
        close(fig);
    end
end
fprintf('  Saved %d individual marginal plots (PDF + PNG).\n', nMetrics * nFactors);

% ---- (B) Combined overview figure (4 rows x 3 cols) ----
fig = figure('Visible', 'off', 'Position', [30 30 1350 950]);
tiledlayout(nMetrics, nFactors, 'TileSpacing', 'compact', 'Padding', 'compact');

for m = 1:nMetrics
    for f = 1:nFactors
        if isempty(marginalMeans{f, m}), continue; end

        nexttile;
        means  = marginalMeans{f, m};
        stds   = marginalStds{f, m};
        nL     = nLevelsAll(f);
        labels = allLevelNames{f};

        if higherBetter(m)
            [~, bestIdx] = max(means);
        else
            [~, bestIdx] = min(means);
        end

        hold on;
        for l = 1:nL
            if l == bestIdx
                bar(l, means(l), 0.65, ...
                    'FaceColor', cBest, 'EdgeColor', cEdge, 'LineWidth', 1.0);
            else
                bar(l, means(l), 0.65, ...
                    'FaceColor', cDefault, 'EdgeColor', cEdge, 'LineWidth', 0.6);
            end
        end
        errorbar(1:nL, means, stds, ...
            'LineStyle', 'none', 'Color', cError, 'LineWidth', 0.9, 'CapSize', 3);
        hold off;

        set(gca, 'XTick', 1:nL, 'XTickLabel', labels, ...
            'XTickLabelRotation', 40, 'FontSize', 7, 'FontName', 'Helvetica');
        grid on; box on;
        set(gca, 'GridColor', cGrid, 'GridAlpha', 1);

        % Row/column labels
        if m == 1
            title(factorShort{f}, 'FontSize', 9, 'FontWeight', 'bold');
        end
        if f == 1
            ylabel(metricDisplayPlain{m}, 'FontSize', 9, 'FontWeight', 'bold');
        end

        % Variance fraction annotation (top-right corner)
        Fval = mainEffects_mean(f, m);
        yLims = ylim;
        text(nL * 0.98, yLims(2) - 0.02*(yLims(2)-yLims(1)), ...
            sprintf('%.1f%%', Fval*100), ...
            'FontSize', 7, 'FontWeight', 'bold', 'Color', [0.3 0.3 0.3], ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
    end
end

sgtitle('fANOVA Marginal Predictions Across Configuration Space', ...
    'FontSize', 12, 'FontWeight', 'bold');

exportgraphics(fig, fullfile(plotDir, 'marginal_overview.pdf'), ...
    'ContentType', 'vector', 'Resolution', 300);
saveas(fig, fullfile(plotDir, 'marginal_overview.png'));
close(fig);
fprintf('  Saved combined overview figure.\n');

% ---- (C) Variance decomposition heatmap ----
fig = figure('Visible', 'off', 'Position', [100 100 700 400]);

pairRowLabels = cell(1, nPairs);
for pi = 1:nPairs
    pairRowLabels{pi} = sprintf('A%d x A%d', pairIdx(pi,1), pairIdx(pi,2));
end
rowLabels = [factorShort, pairRowLabels];
dataMatrix = [mainEffects_mean; interactions_mean] * 100;  % percent

hm = heatmap(metricDisplayPlain, rowLabels, dataMatrix, ...
    'Colormap', flipud(bone(256)), ...
    'ColorLimits', [0 max(dataMatrix(:)) * 1.1], ...
    'CellLabelFormat', '%.1f%%', ...
    'FontSize', 9);
title('Variance Explained (%) by Each Factor and Interaction');
xlabel('Performance Metric');
ylabel('Factor / Interaction');

exportgraphics(fig, fullfile(plotDir, 'variance_heatmap.pdf'), ...
    'ContentType', 'vector', 'Resolution', 300);
saveas(fig, fullfile(plotDir, 'variance_heatmap.png'));
close(fig);
fprintf('  Saved variance decomposition heatmap.\n');

%% ========================================================================
%  STEP 8: TABLES (Console + LaTeX)
%  ========================================================================
fprintf('\n========== Step 8: Generating Tables ==========\n');

if ~exist(outputDir, 'dir'), mkdir(outputDir); end

% ---- TABLE 1 STYLE: Top-k most important factors per metric ----
fprintf('\n  --- Table 1: Most Important Factors Per Metric ---\n');
fprintf('  %-12s  %-30s  %-30s  %-30s  %-30s\n', 'Metric', '1st', '2nd', '3rd', '4th');
fprintf('  %s\n', repmat('-', 1, 136));

table1Data = cell(nMetrics, nFactors);  % top-k per metric

for m = 1:nMetrics
    [sortedF, sortIdx] = sort(mainEffects_mean(:, m), 'descend');
    fprintf('  %-12s', metricDisplayPlain{m});
    for k = 1:nFactors
        entry = sprintf('%s (%.1f%%)', factorShort{sortIdx(k)}, sortedF(k)*100);
        table1Data{m, k} = entry;
        fprintf('  %-30s', entry);
    end
    fprintf('\n');
end

% ---- TABLE 2 STYLE: Full variance decomposition ----
fprintf('\n  --- Table 2: Variance Decomposition (main + pairwise) ---\n');
fprintf('  %-28s', 'Factor');
for m = 1:nMetrics
    fprintf(' %14s', metricDisplayPlain{m});
end
fprintf('\n  %s\n', repmat('-', 1, 28 + 15*nMetrics));

for f = 1:nFactors
    fprintf('  %-28s', factorDisplay{f});
    for m = 1:nMetrics
        fprintf(' %6.1f%% (%4.1f)', mainEffects_mean(f,m)*100, mainEffects_std(f,m)*100);
    end
    fprintf('\n');
end

fprintf('  %s\n', repmat('-', 1, 28 + 15*nMetrics));

pairDisplay = cell(1, nPairs);
for pi = 1:nPairs
    pairDisplay{pi} = sprintf('Area %d x Area %d', pairIdx(pi,1), pairIdx(pi,2));
end
for pi = 1:nPairs
    fprintf('  %-28s', pairDisplay{pi});
    for m = 1:nMetrics
        fprintf(' %6.1f%% (%4.1f)', interactions_mean(pi,m)*100, interactions_std(pi,m)*100);
    end
    fprintf('\n');
end

fprintf('  %s\n', repmat('-', 1, 28 + 15*nMetrics));

% Sum check
fprintf('  %-28s', 'Sum (main + pairwise)');
for m = 1:nMetrics
    total = sum(mainEffects_mean(:,m)) + sum(interactions_mean(:,m));
    fprintf(' %14.1f%%', total * 100);
end
fprintf('\n');

fprintf('\n  OOB R^2:');
for m = 1:nMetrics
    fprintf('  %s = %.3f', metricNames{m}, oobR2(m));
end
fprintf('\n');

%% ---- LaTeX: Table 1 (most important factors) ----
tex1Path = fullfile(outputDir, 'table1_importance_ranking.tex');
fid = fopen(tex1Path, 'w');

fprintf(fid, '\\documentclass[sigconf,nonacm]{acmart}\n\n');
fprintf(fid, '\\settopmatter{printacmref=false}\n');
fprintf(fid, '\\renewcommand\\footnotetextcopyrightpermission[1]{}\n');
fprintf(fid, '\\pagestyle{plain}\n\n');
fprintf(fid, '\\usepackage{booktabs}\n');
fprintf(fid, '\\usepackage{multirow}\n');
fprintf(fid, '\\usepackage{graphicx}\n');
fprintf(fid, '\\usepackage{float}\n\n');

fprintf(fid, '\\begin{document}\n\n');
fprintf(fid, '\\title{Supplementary Materials for: \\\\ Improving NSGA-III Stability}\n\n');
fprintf(fid, '\\author{Anonymous Author(s)}\n');
fprintf(fid, '\\affiliation{\\institution{Institution Name}\\city{City}\\country{Country}}\n');
fprintf(fid, '\\email{author@email.com}\n\n');
fprintf(fid, '\\maketitle\n\n');

fprintf(fid, '\\begin{table}[htbp]\n');
fprintf(fid, '  \\centering\n');
fprintf(fid, '  \\caption{Top three most important improvement areas per metric, ');
fprintf(fid, 'with the fraction of variance explained by main effects. ');
fprintf(fid, 'Results are averaged across %d trees in the random forest ensemble.}\n', nTrees);
fprintf(fid, '  \\label{tab:importance-ranking}\n');
fprintf(fid, '  \\begin{tabular}{l%s}\n', repmat('c', 1, nFactors));
fprintf(fid, '    \\toprule\n');
fprintf(fid, '    Metric');
for k = 1:nFactors
    fprintf(fid, ' & %s', ordinalStr(k));
end
fprintf(fid, ' \\\\\n');
fprintf(fid, '    \\midrule\n');
for m = 1:nMetrics
    [sortedF, sortIdx] = sort(mainEffects_mean(:, m), 'descend');
    fprintf(fid, '    %s', metricDisplay{m});
    for k = 1:nFactors
        fprintf(fid, ' & %s (%.1f\\%%)', factorShort{sortIdx(k)}, sortedF(k)*100);
    end
    fprintf(fid, ' \\\\\n');
end
fprintf(fid, '    \\bottomrule\n');
fprintf(fid, '  \\end{tabular}\n');
fprintf(fid, '\\end{table}\n');
fprintf(fid, '\\end{document}\n');
fclose(fid);
fprintf('  Saved: %s\n', tex1Path);

%% ---- LaTeX: Table 2 (full variance decomposition) ----
tex2Path = fullfile(outputDir, 'table2_variance_decomposition.tex');
fid = fopen(tex2Path, 'w');
fprintf(fid, '\\documentclass[sigconf,nonacm]{acmart}\n\n');
fprintf(fid, '\\settopmatter{printacmref=false}\n');
fprintf(fid, '\\renewcommand\\footnotetextcopyrightpermission[1]{}\n');
fprintf(fid, '\\pagestyle{plain}\n\n');
fprintf(fid, '\\usepackage{booktabs}\n');
fprintf(fid, '\\usepackage{multirow}\n');
fprintf(fid, '\\usepackage{graphicx}\n');
fprintf(fid, '\\usepackage{float}\n\n');

fprintf(fid, '\\begin{document}\n\n');
fprintf(fid, '\\title{Supplementary Materials for: \\\\ Improving NSGA-III Stability}\n\n');
fprintf(fid, '\\author{Anonymous Author(s)}\n');
fprintf(fid, '\\affiliation{\\institution{Institution Name}\\city{City}\\country{Country}}\n');
fprintf(fid, '\\email{author@email.com}\n\n');
fprintf(fid, '\\maketitle\n\n');

fprintf(fid, '\\begin{table}[htbp]\n');
fprintf(fid, '  \\centering\n');
fprintf(fid, '  \\caption{Fractions of variance explained by main effects and pairwise ');
fprintf(fid, 'interaction effects ($F_U = V_U / V$), averaged across %d trees. ', nTrees);
fprintf(fid, 'Standard deviations across trees are shown in parentheses. ');
fprintf(fid, 'Small interaction effects indicate that the improvement areas ');
fprintf(fid, 'can be addressed independently.}\n');
fprintf(fid, '  \\label{tab:fanova-decomposition}\n');
fprintf(fid, '  \\begin{tabular}{l%s}\n', repmat('c', 1, nMetrics));
fprintf(fid, '    \\toprule\n');

% Header
fprintf(fid, '    Factor');
for m = 1:nMetrics
    fprintf(fid, ' & %s', metricDisplay{m});
end
fprintf(fid, ' \\\\\n');
fprintf(fid, '    \\midrule\n');

% Main effects with bold for largest per column
for f = 1:nFactors
    fprintf(fid, '    %s', factorDisplay{f});
    for m = 1:nMetrics
        val = mainEffects_mean(f, m);
        sd  = mainEffects_std(f, m);
        [~, maxF] = max(mainEffects_mean(:, m));
        if f == maxF
            fprintf(fid, ' & \\textbf{%.1f\\%%} (%.1f)', val*100, sd*100);
        else
            fprintf(fid, ' & %.1f\\%% (%.1f)', val*100, sd*100);
        end
    end
    fprintf(fid, ' \\\\\n');
end

fprintf(fid, '    \\midrule\n');

% Pairwise interactions
pairDisplayTex = cell(1, nPairs);
for pi = 1:nPairs
    pairDisplayTex{pi} = sprintf('Area %d $\\times$ %d', pairIdx(pi,1), pairIdx(pi,2));
end
for pi = 1:nPairs
    fprintf(fid, '    %s', pairDisplayTex{pi});
    for m = 1:nMetrics
        val = interactions_mean(pi, m);
        sd  = interactions_std(pi, m);
        fprintf(fid, ' & %.1f\\%% (%.1f)', val*100, sd*100);
    end
    fprintf(fid, ' \\\\\n');
end

fprintf(fid, '    \\midrule\n');

% Sum row
fprintf(fid, '    Total explained');
for m = 1:nMetrics
    total = sum(mainEffects_mean(:,m)) + sum(interactions_mean(:,m));
    fprintf(fid, ' & %.1f\\%%', total*100);
end
fprintf(fid, ' \\\\\n');

fprintf(fid, '    \\bottomrule\n');
fprintf(fid, '  \\end{tabular}\n');
fprintf(fid, '\\end{table}\n');
fprintf(fid, '\\end{document}\n');
fclose(fid);
fprintf('  Saved: %s\n', tex2Path);

%% ---- CSV export ----
csvPath = fullfile(outputDir, 'variance_decomposition.csv');
fid = fopen(csvPath, 'w');
fprintf(fid, 'Factor,Type');
for m = 1:nMetrics
    fprintf(fid, ',%s_mean,%s_std', metricNames{m}, metricNames{m});
end
fprintf(fid, '\n');
for f = 1:nFactors
    fprintf(fid, '%s,main', factorNames{f});
    for m = 1:nMetrics
        fprintf(fid, ',%.6f,%.6f', mainEffects_mean(f,m), mainEffects_std(f,m));
    end
    fprintf(fid, '\n');
end
pairLabels = cell(1, nPairs);
for pi = 1:nPairs
    pairLabels{pi} = sprintf('area%d:area%d', pairIdx(pi,1), pairIdx(pi,2));
end
for pi = 1:nPairs
    fprintf(fid, '%s,interaction', pairLabels{pi});
    for m = 1:nMetrics
        fprintf(fid, ',%.6f,%.6f', interactions_mean(pi,m), interactions_std(pi,m));
    end
    fprintf(fid, '\n');
end
fclose(fid);
fprintf('  Saved: %s\n', csvPath);

fprintf('\n========== fANOVA Pipeline Complete ==========\n');
fprintf('  Results:  %s\n', outputDir);
fprintf('  Plots:    %s\n', plotDir);
fprintf('  Tables:   table1_importance_ranking.tex\n');
fprintf('            table2_variance_decomposition.tex\n');

%% ========================================================================
%  LOCAL FUNCTIONS
%  ========================================================================

function config = buildConfig(area1, area2, area3, area4, area5) %#ok<INUSD>
%BUILDCONFIG Maps categorical level names to ConfigurableNSGAIIIwH config struct

    config = struct(...
        'removeThreshold', false, ...
        'useArchive', false, ...
        'preserveCorners', false, ...
        'momentum', 'none', ...
        'useDSS', false);

    % Area 1: parse implementation flags from level string (Z/Y/X)
    if ~strcmp(area1, 'none')
        config.removeThreshold = contains(area1, 'Z');
        config.preserveCorners = contains(area1, 'Y');
        config.useArchive      = contains(area1, 'X');
    end

    % Area 2: momentum string directly ('none' or 'tikhonov')
    config.momentum = area2;

    % Area 3: DSS flag
    config.useDSS = strcmp(area3, 'dss');
end

function indices = stratifiedSample(n1, n2, n3, n4, n5, nSamples, totalConfigs, ...
    allIdx1, allIdx2, allIdx3, allIdx4, allIdx5)
%STRATIFIEDSAMPLE Sample configs ensuring all factor levels are covered
%
%   Phase 1: Greedily include configs that cover uncovered levels.
%   Phase 2: Fill remaining budget with uniform random selection.
%   Guarantees every level of every factor appears at least once.

    % Phase 1: Coverage guarantee
    mandatory = [];
    covered1 = false(n1, 1);
    covered2 = false(n2, 1);
    covered3 = false(n3, 1);
    covered4 = false(n4, 1);
    covered5 = false(n5, 1);

    perm = randperm(totalConfigs);
    for p = perm
        needed = ~covered1(allIdx1(p)) || ~covered2(allIdx2(p)) || ...
                 ~covered3(allIdx3(p)) || ~covered4(allIdx4(p)) || ...
                 ~covered5(allIdx5(p));
        if needed
            mandatory(end+1) = p; %#ok<AGROW>
            covered1(allIdx1(p)) = true;
            covered2(allIdx2(p)) = true;
            covered3(allIdx3(p)) = true;
            covered4(allIdx4(p)) = true;
            covered5(allIdx5(p)) = true;
        end
        if all(covered1) && all(covered2) && all(covered3) && all(covered4) && all(covered5)
            break;
        end
    end

    % Phase 2: Fill remaining with random selection
    nMandatory = numel(mandatory);
    nExtra = min(nSamples, totalConfigs) - nMandatory;

    if nExtra > 0
        available = setdiff(1:totalConfigs, mandatory);
        extra = available(randperm(numel(available), min(nExtra, numel(available))));
        indices = sort([mandatory, extra]);
    else
        indices = sort(mandatory(1:min(nSamples, totalConfigs)));
    end

    indices = indices(:);
end

function val = extractMean(summary, probField, algField)
%EXTRACTMEAN Extract numeric mean from a metric summary struct

    meanField = [algField '_mean'];
    val = NaN;

    if isfield(summary, probField)
        probData = summary.(probField);
        if isfield(probData, meanField)
            val = probData.(meanField);
        end
    end
end

function summary = loadSummary(filepath, varName)
%LOADSUMMARY Load a summary .mat file with error handling

    if ~exist(filepath, 'file')
        error('Summary file not found: %s\nRun with evaluationMode=''full'' first.', filepath);
    end
    data = load(filepath, varName);
    summary = data.(varName);
end

function s = ordinalStr(k)
%ORDINALSTR Return ordinal string (1st, 2nd, 3rd, 4th, ...)
    switch k
        case 1, s = '1st';
        case 2, s = '2nd';
        case 3, s = '3rd';
        otherwise, s = sprintf('%dth', k);
    end
end

function generateLatexTable(texPath, mainEffects, interactions, ...
    metricDisplay, factorDisplay, pairLabels)
%GENERATELATEXTABLE Generate LaTeX variance decomposition table

    nPairsLocal = size(interactions, 1);
    nFactorsLocal = size(mainEffects, 1);
    pairIdxLocal = nchoosek(1:nFactorsLocal, 2);
    pairDisplayTex = cell(nPairsLocal, 1);
    for pi = 1:nPairsLocal
        pairDisplayTex{pi} = sprintf('Area %d $\\times$ %d', pairIdxLocal(pi,1), pairIdxLocal(pi,2));
    end

    nMetrics = numel(metricDisplay);

    fid = fopen(texPath, 'w');
    fprintf(fid, '\\begin{table}[htbp]\n');
    fprintf(fid, '  \\centering\n');
    fprintf(fid, '  \\caption{Variance decomposition ($F_U$) of algorithm performance across improvement areas. ');
    fprintf(fid, 'Main effects (top) and pairwise interactions (bottom). ');
    fprintf(fid, 'Values represent the fraction of total variance explained.}\n');
    fprintf(fid, '  \\label{tab:fanova}\n');
    fprintf(fid, '  \\begin{tabular}{l%s}\n', repmat('r', 1, nMetrics));
    fprintf(fid, '    \\toprule\n');

    % Header
    fprintf(fid, '    Factor');
    for m = 1:nMetrics
        fprintf(fid, ' & %s', metricDisplay{m});
    end
    fprintf(fid, ' \\\\\n');
    fprintf(fid, '    \\midrule\n');

    % Main effects
    for f = 1:size(mainEffects, 1)
        fprintf(fid, '    %s', factorDisplay{f});
        for m = 1:nMetrics
            if isnan(mainEffects(f, m))
                fprintf(fid, ' & ---');
            else
                fprintf(fid, ' & %.4f', mainEffects(f, m));
            end
        end
        fprintf(fid, ' \\\\\n');
    end

    fprintf(fid, '    \\midrule\n');

    % Interactions
    for pi = 1:size(interactions, 1)
        fprintf(fid, '    %s', pairDisplayTex{pi});
        for m = 1:nMetrics
            if isnan(interactions(pi, m))
                fprintf(fid, ' & ---');
            else
                fprintf(fid, ' & %.4f', interactions(pi, m));
            end
        end
        fprintf(fid, ' \\\\\n');
    end

    fprintf(fid, '    \\bottomrule\n');
    fprintf(fid, '  \\end{tabular}\n');
    fprintf(fid, '\\end{table}\n');
    fclose(fid);
end

function ensureDir(dirPath)
%ENSUREDIR Create directory if it does not exist
    if ~exist(dirPath, 'dir')
        mkdir(dirPath);
    end
end
