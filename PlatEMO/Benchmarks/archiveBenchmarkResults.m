function archiveBenchmarkResults(instructiveName, dryRun)
%ARCHIVEBENCHMARKRESULTS Move benchmark results to a named archive directory
%
%   archiveBenchmarkResults(instructiveName)
%   archiveBenchmarkResults(instructiveName, dryRun)
%
%   Moves contents from benchmark directories to './Tentative/{instructiveName}/'
%   while preserving the original directory structure. Source directories are
%   NOT deleted - only their contents are moved.
%
%   Input:
%     instructiveName - Name for the archive (e.g., 'nonparametric_5runs')
%     dryRun          - If true, only preview moves (default: false)
%
%   Directories archived:
%     ./Data                    -> ./Tentative/{name}/Data
%     ./TrimmedData             -> ./Tentative/{name}/TrimmedData
%     ./IntermediateHV          -> ./Tentative/{name}/IntermediateHV
%     ./IntermediateIGDp        -> ./Tentative/{name}/IntermediateIGDp
%     ./Info/FinalHV            -> ./Tentative/{name}/Info/FinalHV
%     ./Info/FinalIGD           -> ./Tentative/{name}/Info/FinalIGD
%     ./Info/MedianHVResults    -> ./Tentative/{name}/Info/MedianHVResults
%     ./Info/IdealNadirHistory  -> ./Tentative/{name}/Info/IdealNadirHistory
%     ./Info/InitialPopulation  -> ./Tentative/{name}/Info/InitialPopulation
%     ./Info/StableStatistics   -> ./Tentative/{name}/Info/StableStatistics
%     ./Info/Bounds             -> ./Tentative/{name}/Info/Bounds
%     ./Visualization/images    -> ./Tentative/{name}/Visualization/images
%     ./Info/fANOVA    -> ./Tentative/{name}/Info/fANOVA
%
%   Example:
%     % Archive current results
%     archiveBenchmarkResults('nonparametric_5runs');
%
%     % Preview what would be moved
%     archiveBenchmarkResults('test_archive', true);

    if nargin < 1 || isempty(instructiveName)
        error('Usage: archiveBenchmarkResults(instructiveName, [dryRun])');
    end
    if nargin < 2
        dryRun = false;
    end

    % Validate instructive name (no special characters that cause path issues)
    if ~isempty(regexp(instructiveName, '[<>:"/\\|?*]', 'once'))
        error('instructiveName cannot contain special characters: < > : " / \\ | ? *');
    end

    % Base target directory
    targetBase = fullfile('.', 'Tentative', instructiveName);

    % Define source directories to archive
    sourceDirs = {
        './Data';
        './TrimmedData';
        './IntermediateHV';
        './IntermediateIGDp';
        './Info/FinalHV';
        './Info/FinalIGD';
        './Info/MedianHVResults';
        './Info/IdealNadirHistory';
        './Info/StableStatistics';
        './Info/Bounds';
        './Info/Logs';
        './Visualization/images';
        './Info/fANOVA';
    };

    fprintf('=== Archiving Benchmark Results ===\n');
    fprintf('Archive name: %s\n', instructiveName);
    fprintf('Target base: %s\n', targetBase);
    if dryRun
        fprintf('MODE: Dry run (no files will be moved)\n');
    end
    fprintf('\n');

    totalMoved = 0;
    totalSkipped = 0;

    for i = 1:numel(sourceDirs)
        sourceDir = sourceDirs{i};

        % Skip if source doesn't exist
        if ~exist(sourceDir, 'dir')
            fprintf('[SKIP] %s (does not exist)\n', sourceDir);
            continue;
        end

        % Build target path preserving structure
        % e.g., './Info/FinalHV' -> './Tentative/{name}/Info/FinalHV'
        relativePath = strrep(sourceDir, './', '');
        targetDir = fullfile(targetBase, relativePath);

        % Get contents of source directory
        contents = dir(sourceDir);
        contents = contents(~ismember({contents.name}, {'.', '..'}));

        if isempty(contents)
            fprintf('[EMPTY] %s\n', sourceDir);
            continue;
        end

        fprintf('\n--- %s ---\n', sourceDir);
        fprintf('  Target: %s\n', targetDir);
        fprintf('  Items: %d\n', numel(contents));

        % Create target directory if needed
        if ~dryRun && ~exist(targetDir, 'dir')
            mkdir(targetDir);
        end

        % Move each item
        movedCount = 0;
        for j = 1:numel(contents)
            itemName = contents(j).name;
            sourcePath = fullfile(sourceDir, itemName);
            targetPath = fullfile(targetDir, itemName);

            % Check if target already exists
            if exist(targetPath, 'file') || exist(targetPath, 'dir')
                if j <= 3 || mod(j, 20) == 0
                    fprintf('  [EXISTS] %s\n', itemName);
                end
                totalSkipped = totalSkipped + 1;
                continue;
            end

            if dryRun
                if j <= 3 || mod(j, 20) == 0
                    fprintf('  [WOULD MOVE] %s\n', itemName);
                end
            else
                try
                    movefile(sourcePath, targetPath);
                    if j <= 3 || mod(j, 20) == 0
                        fprintf('  [MOVED] %s\n', itemName);
                    end
                    movedCount = movedCount + 1;
                catch ME
                    fprintf('  [ERROR] %s: %s\n', itemName, ME.message);
                end
            end
        end

        if dryRun
            fprintf('  Would move: %d items\n', numel(contents));
            totalMoved = totalMoved + numel(contents);
        else
            fprintf('  Moved: %d items\n', movedCount);
            totalMoved = totalMoved + movedCount;
        end
    end

    fprintf('\n=== Summary ===\n');
    fprintf('Total %s: %d\n', ternary(dryRun, 'to be moved', 'moved'), totalMoved);
    fprintf('Total skipped (already exist): %d\n', totalSkipped);
    fprintf('Archive location: %s\n', targetBase);

    if dryRun
        fprintf('\nRun archiveBenchmarkResults(''%s'', false) to actually move files.\n', instructiveName);
    else
        fprintf('\nArchive complete. Source directories preserved (now empty).\n');
    end
end

function result = ternary(condition, trueVal, falseVal)
    if condition
        result = trueVal;
    else
        result = falseVal;
    end
end
