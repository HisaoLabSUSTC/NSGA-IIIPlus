function ComputeAnytimeMetrics(source_dir, target_dir, problemNames)
%COMPUTEANYTIMEMETRICS Compute HV, IGD+, Generalized Spread for each generation
%
%   ComputeAnytimeMetrics(source_dir, target_dir, problemNames)
%
%   Input:
%     source_dir   - Directory containing full benchmark data (default: './Data')
%     target_dir   - Directory to save anytime metrics (default: './AnytimeMetrics')
%     problemNames - Cell array or string array of problem names to process
%
%   This function computes HV, IGD+, and Generalized Spread for each generation,
%   enabling anytime performance visualization.

    % Default directories
    if nargin < 2 || isempty(target_dir)
        target_dir = './AnytimeMetrics';
    end

    if nargin < 1 || isempty(source_dir)
        source_dir = './Data';
    end

    if nargin < 3
        problemNames = {};  % Process all problems
    end

    % Convert to cell array if needed
    if isstring(problemNames)
        problemNames = cellstr(problemNames);
    end

    % Create target directory if it doesn't exist
    if ~exist(target_dir, 'dir')
        mkdir(target_dir);
    end

    % Get all algorithm subdirectories
    subdirs = dir(source_dir);
    subdirs = subdirs([subdirs.isdir]);
    subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));

    % Collect all files to process
    % status: 0 = filtered out, 1 = to process, 2 = already done
    allFiles = struct('filepath', {}, 'algorithm', {}, 'filename', {}, ...
                     'metricsFilepath', {}, 'status', {});
    fileIdx = 0;

    for i = 1:length(subdirs)
        algorithmName = subdirs(i).name;
        subdirPath = fullfile(source_dir, algorithmName);

        % Create corresponding directory in target
        metricsAlgorithmDir = fullfile(target_dir, algorithmName);
        if ~exist(metricsAlgorithmDir, 'dir')
            mkdir(metricsAlgorithmDir);
        end

        % Get all .mat files in this algorithm directory
        matFiles = dir(fullfile(subdirPath, '*.mat'));

        for j = 1:length(matFiles)
            fileIdx = fileIdx + 1;
            allFiles(fileIdx).filepath = fullfile(subdirPath, matFiles(j).name);
            allFiles(fileIdx).algorithm = algorithmName;
            allFiles(fileIdx).filename = matFiles(j).name;
            allFiles(fileIdx).metricsFilepath = fullfile(metricsAlgorithmDir, ['AM_' matFiles(j).name]);

            % Parse filename to get problem/pipeline name
            % Filename: Alg_Problem_M3_D30_ID3_9.mat or Alg_Problem_M3_D30_9.mat
            fileParts = split(matFiles(j).name, '_');
            if length(fileParts) >= 2
                pn = fileParts{2};
                % Check for combinatorial ID field (e.g., _ID3_)
                if length(fileParts) >= 6 && startsWith(fileParts{5}, 'ID')
                    pn = sprintf('%s_ID%s', pn, fileParts{5}(3:end));
                end
            else
                pn = '';
            end

            % Determine file status
            if ~isempty(problemNames) && ~ismember(pn, problemNames)
                % Not in the requested problem list
                allFiles(fileIdx).status = 0;  % filtered out
            elseif exist(allFiles(fileIdx).metricsFilepath, 'file')
                allFiles(fileIdx).status = 2;  % already done
            else
                allFiles(fileIdx).status = 1;  % to process
            end
        end
    end

    % Filter files that need processing
    filesToProcess = allFiles([allFiles.status] == 1);
    alreadyDone = sum([allFiles.status] == 2);
    filteredOut = sum([allFiles.status] == 0);

    fprintf('Found %d total files:\n', length(allFiles));
    fprintf('  - %d already processed (will skip)\n', alreadyDone);
    if filteredOut > 0
        fprintf('  - %d not in problem list (filtered out)\n', filteredOut);
    end
    fprintf('  - %d to process\n', length(filesToProcess));

    if isempty(filesToProcess)
        fprintf('All files already processed. Nothing to do.\n');
        return;
    end

    %% Start parallel pool if not already started
    if isempty(gcp('nocreate'))
        disp('Starting parallel pool...');
        parpool;
    end

    % Process files
    fprintf('\nProcessing %d files...\n', length(filesToProcess));

    % Pre-allocate results cell array
    results = cell(length(filesToProcess), 1);

    % Create progress display
    startTime = tic;

    % Parallel processing with parfor
    fprintf('Processing files in parallel...\n');
    parfor k = 1:length(filesToProcess)
        results{k} = ProcessAnytimeMetricsOfOneFile(filesToProcess(k));
    end

    % Count successful and failed processing
    successCount = sum(cellfun(@(x) x.success, results));
    failCount = sum(cellfun(@(x) ~x.success, results));

    % Save results from cell array to files
    fprintf('\nSaving computed anytime metrics...\n');
    for k = 1:length(filesToProcess)
        if results{k}.success
            metricsData = results{k}.metricsData;
            save(filesToProcess(k).metricsFilepath, 'metricsData');
        end
    end

    % Report completion
    elapsedTime = toc(startTime);
    fprintf('\n========================================\n');
    fprintf('Anytime metrics computation complete!\n');
    fprintf('  Total time: %.2f seconds\n', elapsedTime);
    fprintf('  Files processed: %d\n', successCount);
    fprintf('  Files failed: %d\n', failCount);
    fprintf('  Files skipped (already exist): %d\n', alreadyDone);
    fprintf('  Average time per file: %.3f seconds\n', elapsedTime/max(1, length(filesToProcess)));
    fprintf('  Data saved in: %s\n', target_dir);
    fprintf('========================================\n');

    % Report any failures
    if failCount > 0
        fprintf('\nFailed files:\n');
        for k = 1:length(results)
            if ~results{k}.success
                fprintf('  - %s: %s\n', filesToProcess(k).filename, results{k}.error);
            end
        end
    end
end
