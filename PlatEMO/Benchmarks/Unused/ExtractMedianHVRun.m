Algorithms = {@NSGAIIIwH, @PyNSGAIIIwH};

% pause(7200);
extractMedianHV(Algorithms, true);

function extractMedianHV(algorithmHandles, saveAsMat)
% extractMedianHV - Computes median HV across 30 runs for each problem.
%
% INPUT:
%   algorithmHandles : cell array of function handles, e.g. {@NSGAII, @PyNSGAII}
%   saveAsMat        : true -> save .mat output
%                       false -> save .txt output
%
% OUTPUT:
%   Writes result files under ./MedianHVResults/

    if nargin < 2
        saveAsMat = true;   % Default
    end

    rootDir = fullfile('./HVData');
    outDir  = fullfile('./Info/MedianHVResults');
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    for ah = 1:numel(algorithmHandles)

        algName = func2str(algorithmHandles{ah});
        disp(algName);
        algDir  = fullfile(rootDir, algName);

        if ~exist(algDir, 'dir')
            warning('Directory "%s" does not exist. Skipped.', algDir);
            continue;
        end

        % ---------------------------------------------------------
        % 1. GET ALL MAT FILES
        % ---------------------------------------------------------
        matFiles = dir(fullfile(algDir, '*.mat'));
        if isempty(matFiles)
            warning('No .mat files found under %s', algDir);
            continue;
        end

        % ---------------------------------------------------------
        % 2. PARSE PROBLEM NAMES
        % ---------------------------------------------------------
        % Expected filename:"
        % HV_<ALG>_<PROBLEM>_M?_D?_RUN.mat
        %
        % Example:
        % HV_PyNSGAIII_BT1_M2_D30_3.mat
        %
        % → Problem name = BT1
        % ---------------------------------------------------------

        problemNames = cell(numel(matFiles),1);
        for i = 1:numel(matFiles)
            fname = matFiles(i).name;
            parts = strsplit(fname, '_'); 
            % parts = ["HV","PyNSGAIII","BT1","M2","D30","3.mat"]
            problemNames{i} = parts{3};  
        end

        uniqueProblems = unique(problemNames, 'stable')

        % Storage for results
        results = struct();

        % ---------------------------------------------------------
        % 3. PROCESS EACH PROBLEM
        % ---------------------------------------------------------
        for p = 1:numel(uniqueProblems)
            prob = uniqueProblems{p};
            fprintf("On problem %s (%d/%d)\n", prob,p,numel(uniqueProblems))

            % Get all files of this problem
            idx = strcmp(problemNames, prob);
            probFiles = matFiles(idx);

            % Expect 30 runs, but code supports fewer/more
            numRuns = numel(probFiles);

            lastHV = zeros(numRuns,1);

            % ----------------------------------------------
            % Extract last HV from each file
            % ----------------------------------------------
            for r = 1:numRuns
                matPath = fullfile(algDir, probFiles(r).name);
                data = load(matPath);

                lastHV(r) = data.hvData.HV(end);
            end

            % ----------------------------------------------
            % Compute median HV & find filename
            % ----------------------------------------------
            medHV = median(lastHV);

            % Find the *closest* file to the median
            [~, nearestIdx] = min(abs(lastHV - medHV));

            medianFile = probFiles(nearestIdx).name;

            % Store results
            results.(prob).medianHV = medHV;
            results.(prob).medianFile = medianFile;
            results.(prob).allFiles = {probFiles.name}';
            results.(prob).allLastHV = lastHV;
        end

        % ---------------------------------------------------------
        % 4. SAVE OUTPUT
        % ---------------------------------------------------------
        outName = fullfile(outDir, sprintf('MedianHV_%s', algName));

        if saveAsMat
            save(outName, 'results');
            fprintf('✅ Saved MAT results: %s.mat\n', outName);
        else
            % Save as text
            txtFile = fopen([outName '.txt'], 'w');
            fprintf(txtFile, 'Median Hypervolume Results for %s\n\n', algName);

            fields = fieldnames(results);
            for k = 1:numel(fields)
                f = fields{k};
                fprintf(txtFile, 'Problem: %s\n', f);
                fprintf(txtFile, '   Median HV: %.16f\n', results.(f).medianHV);
                fprintf(txtFile, '   Median File: %s\n\n', results.(f).medianFile);
            end

            fclose(txtFile);
            fprintf('✅ Saved TXT results: %s.txt\n', outName);
        end

        fprintf('✅ Finished %s\n', algName);
    end
end

