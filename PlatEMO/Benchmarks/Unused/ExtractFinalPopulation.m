%% Parallel script to trim data files using parfor
% Run this once, then use TrimmedData for all future analyses

DataDir = './Data';
TrimmedDir = './TrimmedData';

%% 1. Build task list
subdirs = dir(DataDir);
subdirs = subdirs([subdirs.isdir]);
subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));

srcPaths = {};
dstPaths = {};

for i = 1:length(subdirs)
    algorithmName = subdirs(i).name;
    srcSubdir = fullfile(DataDir, algorithmName);
    dstSubdir = fullfile(TrimmedDir, algorithmName);
    
    % Create destination directory (must do this sequentially before parfor)
    if ~exist(dstSubdir, 'dir')
        mkdir(dstSubdir);
    end
    
    matFiles = dir(fullfile(srcSubdir, '*.mat'));
    for j = 1:length(matFiles)
        srcPath = fullfile(srcSubdir, matFiles(j).name);
        dstPath = fullfile(dstSubdir, matFiles(j).name);
        
        % Skip if already processed
        if ~exist(dstPath, 'file')
            srcPaths{end+1} = srcPath;
            dstPaths{end+1} = dstPath;
        end
    end
end

total = numel(srcPaths);
fprintf('Found %d files to process\n', total);

if total == 0
    fprintf('All files already trimmed!\n');
    return;
end

%% 2. Setup parallel pool
pool = gcp('nocreate');
if isempty(pool)
    pool = parpool;
end

%% 3. Process files with parfor
fprintf('Processing %d files...\n', total);
tic;

% Pre-allocate result array (parfor requires fixed-size output)
success = false(1, total);

parfor i = 1:total
    try
        % Load original data
        srcPaths{i}
        data = load(srcPaths{i});
        result = data.result;
        
        % Extract only the final population (last row, second column)
        finalPop = result{end, 2};
        
        % Save trimmed version
        parsave(dstPaths{i}, finalPop);
        
        success(i) = true;
    catch ME
        warning('Failed %s: %s', srcPaths{i}, ME.message);
        success(i) = false;
    end
end

%% 4. Report results
elapsed = toc;
successCount = sum(success);
failedCount = total - successCount;

fprintf('\nDone! %d/%d files trimmed successfully in %.1f sec\n', successCount, total, elapsed);
fprintf('Average: %.1f files/sec\n', total / elapsed);

if failedCount > 0
    fprintf('%d files failed:\n', failedCount);
    failedIdx = find(~success);
    for i = 1:min(10, failedCount)  % Show first 10 failures
        fprintf('  %s\n', srcPaths{failedIdx(i)});
    end
    if failedCount > 10
        fprintf('  ... and %d more\n', failedCount - 10);
    end
end

function parsave(filepath, finalPop)
%PARSAVE Save function for use inside parfor
%   parfor doesn't allow save() with dynamic filenames directly,
%   so we wrap it in a function.
    save(filepath, 'finalPop', '-v6');
end
