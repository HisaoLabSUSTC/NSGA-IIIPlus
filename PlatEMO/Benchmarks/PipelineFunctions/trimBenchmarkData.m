function [successCount, errorLog] = trimBenchmarkData(algorithms, dataDir, trimmedDir)
%TRIMBENCHMARKDATA Extract final populations from full benchmark data
%
%   trimBenchmarkData(algorithms, dataDir, trimmedDir)
%   [successCount, errorLog] = trimBenchmarkData(...)
%
%   Input:
%     algorithms  - Cell array of algorithm specs
%     dataDir     - Source directory (default: './Data')
%     trimmedDir  - Destination directory (default: './TrimmedData')
%
%   Output:
%     successCount - Number of successfully processed files
%     errorLog     - Struct array of files that failed to process
%
%   Extracts only the final population from each run's result file,
%   significantly reducing storage requirements for metric computation.
%
%   Corrupted files are logged to './Info/Logs/corrupted_files.mat' and
%   can be reprocessed using rerunCorruptedExperiments().

    if nargin < 2
        dataDir = './Data';
    end
    if nargin < 3
        trimmedDir = './TrimmedData';
    end

    fprintf('=== Trimming Benchmark Data ===\n');

    % Get algorithm names
    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, 'UniformOutput', false);

    %% Build task list
    subdirs = dir(dataDir);
    subdirs = subdirs([subdirs.isdir]);
    subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));

    srcPaths = {};
    dstPaths = {};

    for i = 1:length(subdirs)
        algorithmName = subdirs(i).name;
        if ~ismember(algorithmName, algorithmNames)
            continue
        end

        srcSubdir = fullfile(dataDir, algorithmName);
        dstSubdir = fullfile(trimmedDir, algorithmName);

        % Create destination directory
        if ~exist(dstSubdir, 'dir')
            mkdir(dstSubdir);
        end

        matFiles = dir(fullfile(srcSubdir, '*.mat'));
        for j = 1:length(matFiles)
            srcPath = fullfile(srcSubdir, matFiles(j).name);
            dstPath = fullfile(dstSubdir, matFiles(j).name);

            % Skip if already processed
            if ~exist(dstPath, 'file')
                srcPaths{end+1} = srcPath; %#ok<AGROW>
                dstPaths{end+1} = dstPath; %#ok<AGROW>
            end
        end
    end

    total = numel(srcPaths);
    fprintf('Found %d files to process\n', total);

    if total == 0
        fprintf('No files to trim.\n');
        successCount = 0;
        errorLog = struct('filePath', {}, 'errorMsg', {}, 'algName', {}, ...
                          'problemName', {}, 'M', {}, 'D', {}, 'ID', {}, 'runNumber', {});
        return;
    end

    %% Process files with parfor (with error handling)
    fprintf('Processing %d files...\n', total);
    success = false(1, total);
    errorMessages = cell(1, total);

    parfor i = 1:total
        try
            data = load(srcPaths{i});
            result = data.result;
            finalPop = result{end, 2};
            parsave(dstPaths{i}, finalPop);
            success(i) = true;
        catch ME
            success(i) = false;
            errorMessages{i} = ME.message;
        end
    end

    successCount = sum(success);
    failCount = sum(~success);

    fprintf('Successfully trimmed %d/%d files\n', successCount, total);

    %% Log failed files
    errorLog = struct('filePath', {}, 'errorMsg', {}, 'algName', {}, ...
                      'problemName', {}, 'M', {}, 'D', {}, 'ID', {}, 'runNumber', {});

    if failCount > 0
        fprintf('\n=== %d files failed to process ===\n', failCount);

        failedIndices = find(~success);
        for i = 1:numel(failedIndices)
            idx = failedIndices(i);
            filePath = srcPaths{idx};
            errorMsg = errorMessages{idx};

            % Parse filename to extract metadata
            [algName, problemName, M, D, runNumber, ID] = parseDataFilename(filePath);

            entry = struct(...
                'filePath', filePath, ...
                'errorMsg', errorMsg, ...
                'algName', algName, ...
                'problemName', problemName, ...
                'M', M, ...
                'D', D, ...
                'ID', ID, ...
                'runNumber', runNumber);
            errorLog(end+1) = entry; %#ok<AGROW>

            fprintf('  [ERROR] %s\n    -> %s\n', filePath, errorMsg);
        end

        % Save error log
        logDir = './Info/Logs';
        if ~exist(logDir, 'dir')
            mkdir(logDir);
        end

        logPath = fullfile(logDir, 'corrupted_files.mat');

        % Append to existing log if present
        if exist(logPath, 'file')
            existingLog = load(logPath, 'errorLog');
            errorLog = [existingLog.errorLog, errorLog];
        end

        save(logPath, 'errorLog');
        fprintf('\nError log saved to: %s\n', logPath);
        fprintf('Run rerunCorruptedExperiments() to re-run failed experiments.\n');
    end

    fprintf('=== Trimming completed ===\n');
end

function [algName, problemName, M, D, runNumber, ID] = parseDataFilename(filePath)
%PARSEDATAFILENAME Extract metadata from data file path
%   Format: {AlgName}_{Problem}_M{M}_D{D}[_ID{ID}]_{Run}.mat

    [~, fileName, ~] = fileparts(filePath);

    % Pattern: {AlgName}_{Problem}_M{M}_D{D}[_ID{ID}]_{Run}
    pattern = '^(.+?)_(.+)_M(\d+)_D(\d+)(?:_ID(\d+))?_(\d+)$';
    tokens = regexp(fileName, pattern, 'tokens');

    if ~isempty(tokens)
        algName = tokens{1}{1};
        problemName = tokens{1}{2};
        M = str2double(tokens{1}{3});
        D = str2double(tokens{1}{4});
        % Group 5 is ID (empty string if absent), group 6 is run number
        if ~isempty(tokens{1}{5})
            ID = str2double(tokens{1}{5});
        else
            ID = NaN;
        end
        runNumber = str2double(tokens{1}{6});
    else
        % Fallback: extract from directory structure
        [parentDir, ~, ~] = fileparts(filePath);
        [~, algName] = fileparts(parentDir);
        problemName = 'Unknown';
        M = NaN;
        D = NaN;
        ID = NaN;
        runNumber = NaN;
    end
end
