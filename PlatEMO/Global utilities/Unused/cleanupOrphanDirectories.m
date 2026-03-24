function cleanupOrphanDirectories(dryRun)
%CLEANUPORPHANDIRECTORIES Remove Info directories that have no corresponding Data
%
%   cleanupOrphanDirectories()        - Dry run (preview only)
%   cleanupOrphanDirectories(false)   - Actually delete orphan directories
%
%   Compares directories in ./Data with directories in:
%     - ./Info/FinalHV
%     - ./Info/FinalIGD
%     - ./Info/StableStatistics
%     - ./Info/IdealNadirHistory
%     - ./Info/MedianHVResults
%
%   Directories in Info folders that don't exist in Data are considered orphans.

if nargin < 1
    dryRun = true;
end

if dryRun
    fprintf('=== DRY RUN MODE (no files will be deleted) ===\n');
    fprintf('Call cleanupOrphanDirectories(false) to actually delete.\n\n');
end

% Define paths
dataDir = './Data';
infoDirs = {
    './Info/FinalHV';
    './Info/FinalIGD';
    './Info/StableStatistics';
    './Info/IdealNadirHistory';
};

% Get valid algorithm names from Data
dataSubdirs = dir(dataDir);
dataSubdirs = dataSubdirs([dataSubdirs.isdir]);
dataSubdirs = dataSubdirs(~ismember({dataSubdirs.name}, {'.', '..'}));
validNames = {dataSubdirs.name};

fprintf('Found %d valid algorithm directories in Data\n\n', numel(validNames));

totalOrphans = 0;
totalDeleted = 0;

% Check each Info directory
for i = 1:numel(infoDirs)
    infoDir = infoDirs{i};

    if ~exist(infoDir, 'dir')
        fprintf('Skipping (not found): %s\n', infoDir);
        continue;
    end

    subdirs = dir(infoDir);
    subdirs = subdirs([subdirs.isdir]);
    subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));

    orphans = subdirs(~ismember({subdirs.name}, validNames));

    fprintf('%s: %d total, %d orphans\n', infoDir, numel(subdirs), numel(orphans));

    for j = 1:numel(orphans)
        orphanPath = fullfile(infoDir, orphans(j).name);
        totalOrphans = totalOrphans + 1;

        if dryRun
            fprintf('  [WOULD DELETE] %s\n', orphanPath);
        else
            try
                rmdir(orphanPath, 's');
                fprintf('  [DELETED] %s\n', orphanPath);
                totalDeleted = totalDeleted + 1;
            catch ME
                fprintf('  [FAILED] %s: %s\n', orphanPath, ME.message);
            end
        end
    end
end

% Also check for orphan .mat files in MedianHVResults
medianHVDir = './Info/MedianHVResults';
if exist(medianHVDir, 'dir')
    matFiles = dir(fullfile(medianHVDir, 'MedianHV_*.mat'));
    orphanMats = 0;

    for j = 1:numel(matFiles)
        fname = matFiles(j).name;
        % Extract algorithm name from MedianHV_{AlgName}.mat
        tokens = regexp(fname, 'MedianHV_(.+)\.mat', 'tokens');
        if ~isempty(tokens)
            algName = tokens{1}{1};
            if ~ismember(algName, validNames)
                orphanMats = orphanMats + 1;
                totalOrphans = totalOrphans + 1;
                filePath = fullfile(medianHVDir, fname);

                if dryRun
                    fprintf('  [WOULD DELETE] %s\n', filePath);
                else
                    try
                        delete(filePath);
                        fprintf('  [DELETED] %s\n', filePath);
                        totalDeleted = totalDeleted + 1;
                    catch ME
                        fprintf('  [FAILED] %s: %s\n', filePath, ME.message);
                    end
                end
            end
        end
    end

    fprintf('%s: %d orphan files\n', medianHVDir, orphanMats);
end

fprintf('\n=== Summary ===\n');
fprintf('Total orphans found: %d\n', totalOrphans);
if dryRun
    fprintf('Run cleanupOrphanDirectories(false) to delete these.\n');
else
    fprintf('Total deleted: %d\n', totalDeleted);
end
end
