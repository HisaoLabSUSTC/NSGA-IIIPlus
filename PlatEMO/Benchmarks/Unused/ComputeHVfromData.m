function ComputeHVfromData(source_dir, target_dir, pns, mode)
    % Define directories
    if nargin < 2
        target_dir = './HVData';
    end

    if nargin < 1
        source_dir = './Data';
    end

    if nargin < 4
        mode = 'hv';
    end

    % Create HVData directory if it doesn't exist
    if ~exist(target_dir, 'dir')
        mkdir(target_dir);
    end

    % Get all algorithm subdirectories
    subdirs = dir(source_dir);
    subdirs = subdirs([subdirs.isdir]);
    subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));

    % Collect all files to process
    allFiles = struct('filepath', {}, 'algorithm', {}, 'filename', {}, ...
                     'hvFilepath', {}, 'igdFilepath', {}, 'shouldProcess', {});
    fileIdx = 0;

    for i = 1:length(subdirs)
        algorithmName = subdirs(i).name;
        subdirPath = fullfile(source_dir, algorithmName);

        % Create corresponding directory in HVData
        hvAlgorithmDir = fullfile(target_dir, algorithmName);
        mkdir(hvAlgorithmDir);

        % Get all .mat files in this algorithm directory
        matFiles = dir(fullfile(subdirPath, '*.mat'));

        for j = 1:length(matFiles)
            fileIdx = fileIdx + 1;
            allFiles(fileIdx).filepath = fullfile(subdirPath, matFiles(j).name);
            allFiles(fileIdx).algorithm = algorithmName;
            allFiles(fileIdx).filename = matFiles(j).name;
            if strcmp(mode, 'igd')
                allFiles(fileIdx).igdFilepath = fullfile(hvAlgorithmDir, ['IGD_' matFiles(j).name]);
            else
                allFiles(fileIdx).hvFilepath = fullfile(hvAlgorithmDir, ['HV_' matFiles(j).name]);
            end
            
            fileParts = split(matFiles(j).name, '_');
            pn = fileParts{2};
            % Check if we need to reprocess (for CV addition)
            if ismember(pn, pns)
                needsReprocess = true;
                if strcmp(mode, 'igd')
                    igdFilePath = allFiles(fileIdx).igdFilepath;
                else
                    hvFilePath = allFiles(fileIdx).hvFilepath;
                end
                % if exist(hvFilePath, 'file') == 2  % Explicitly check for file (not directory)
                %     try
                %         existingData = load(hvFilePath);
                %         if isfield(existingData, 'hvData') && isfield(existingData.hvData, 'avgCV')
                %             needsReprocess = false;
                %         end
                %     catch
                %         % If we can't load the file, we need to reprocess
                %         needsReprocess = true;
                %     end
                % else
                %     needsReprocess = true;
                % end
                allFiles(fileIdx).shouldProcess = needsReprocess;
            else
                allFiles(fileIdx).shouldProcess = false;
            end
        end
    end

    % Filter files that need processing
    filesToProcess = allFiles([allFiles.shouldProcess]);

    alreadyProcessed = sum(~[allFiles.shouldProcess]);

    fprintf('Found %d total files:\n', length(allFiles));
    fprintf('  - %d already fully processed (will skip)\n', alreadyProcessed);
    fprintf('  - %d to process/update\n', length(filesToProcess));

    if isempty(filesToProcess)
        fprintf('All files already processed. Nothing to do.\n');
        return;
    end

    %% Construct tasks to parallelize this process
    if isempty(gcp('nocreate'))
        disp('Starting parallel pool...');
        parpool; % Start the default parallel pool if not already running
    end

    % Process files
    fprintf('\nProcessing %d files...\n', length(filesToProcess));

    % Pre-allocate results cell array
    results = cell(length(filesToProcess), 1);

    % Create progress display
    startTime = tic;

    % Parallel processing with parfor
    fprintf('Processing files in parallel...\n');
    for k = 1:length(filesToProcess)
        % results{k} = processOneFileWithCV(filesToProcess(k));
        if strcmp(mode, 'igd')
            results{k} = ProcessIGDofOneFile(filesToProcess(k));
        else
            results{k} = ProcessHVofOneFile(filesToProcess(k));
        end
    end

    % Count successful and failed processing
    successCount = sum(cellfun(@(x) x.success, results));
    failCount = sum(cellfun(@(x) ~x.success, results));

    % Save results from cell array to files
    fprintf('\nSaving computed HV and CV data...\n');
    for k = 1:length(filesToProcess)
        if results{k}.success
            if strcmp(mode, 'igd')
                igdData = results{k}.igdData;
                save(filesToProcess(k).igdFilepath, 'igdData')
            else
                hvData = results{k}.hvData;
                save(filesToProcess(k).hvFilepath, 'hvData')
            end
        end
    end

    % Report completion
    elapsedTime = toc(startTime);
    fprintf('\n========================================\n');
    fprintf('Hypervolume and CV precomputation complete!\n');
    fprintf('  Total time: %.2f seconds\n', elapsedTime);
    fprintf('  Files processed: %d\n', successCount);
    fprintf('  Files failed: %d\n', failCount);
    fprintf('  Files skipped (already exist): %d\n', alreadyProcessed);
    fprintf('  Average time per file: %.3f seconds\n', elapsedTime/length(filesToProcess));
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