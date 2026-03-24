function rerouteBenchmarkData(maxRuns, problemsToKeep, dryRun)
%REROUTEBENCHMARKDATA Move excess benchmark files to a tentative directory
%
%   rerouteBenchmarkData(maxRuns, problemsToKeep)
%   rerouteBenchmarkData(maxRuns, problemsToKeep, dryRun)
%
%   Parses all files in PlatEMO/Data/{algName}/ and moves files that:
%     1. Exceed the maximum run number (runNumber > maxRuns)
%     2. Are for problems not in the problemsToKeep list
%
%   Files are moved to PlatEMO/Tentative/31runs/Data/{algName}/
%
%   Input:
%     maxRuns        - Maximum run number to keep (e.g., 5 keeps runs 1-5)
%     problemsToKeep - Cell array of problem names to keep (e.g., {'DTLZ1', 'DTLZ2'})
%                      Use {} or 'all' to keep all problems (only filter by runs)
%     dryRun         - If true, only preview moves without executing (default: true)
%
%   Example:
%     % Preview what would be moved
%     rerouteBenchmarkData(5, {'DTLZ1', 'DTLZ2', 'DTLZ3'});
%
%     % Actually move the files
%     rerouteBenchmarkData(5, {'DTLZ1', 'DTLZ2', 'DTLZ3'}, false);
%
%     % Only filter by runs, keep all problems
%     rerouteBenchmarkData(5, 'all', false);

if nargin < 3
    dryRun = true;
end

if nargin < 2
    error('Usage: rerouteBenchmarkData(maxRuns, problemsToKeep, [dryRun])');
end

% Handle 'all' problems case
filterByProblem = true;
if ischar(problemsToKeep) && strcmpi(problemsToKeep, 'all')
    filterByProblem = false;
    problemsToKeep = {};
elseif isempty(problemsToKeep)
    filterByProblem = false;
end

% Define paths
sourceRoot = './Data';
destRoot = './Tentative/31runs/Data';

if dryRun
    fprintf('=== DRY RUN MODE (no files will be moved) ===\n');
    fprintf('Call rerouteBenchmarkData(%d, {...}, false) to actually move files.\n\n', maxRuns);
end

fprintf('Settings:\n');
fprintf('  Max runs to keep: %d\n', maxRuns);
if filterByProblem
    fprintf('  Problems to keep: %s\n', strjoin(problemsToKeep, ', '));
else
    fprintf('  Problems to keep: ALL\n');
end
fprintf('  Source: %s\n', sourceRoot);
fprintf('  Destination: %s\n\n', destRoot);

% Get all algorithm directories
algDirs = dir(sourceRoot);
algDirs = algDirs([algDirs.isdir]);
algDirs = algDirs(~ismember({algDirs.name}, {'.', '..'}));

totalFiles = 0;
movedFiles = 0;
keptFiles = 0;

% Pattern to parse filenames: {AlgName}_{Problem}_M{M}_D{D}_{Run}.mat
% Example: AgAdamDSSNSGAIIIwH_IDTLZ1_M3_D7_1.mat
filePattern = '^(.+?)_(.+)_M(\d+)_D(\d+)_(\d+)\.mat$';

for i = 1:numel(algDirs)
    algName = algDirs(i).name;
    algSourceDir = fullfile(sourceRoot, algName);
    algDestDir = fullfile(destRoot, algName);

    % Get all .mat files in this algorithm directory
    matFiles = dir(fullfile(algSourceDir, '*.mat'));

    if isempty(matFiles)
        continue;
    end

    algMoved = 0;
    algKept = 0;

    for j = 1:numel(matFiles)
        fileName = matFiles(j).name;
        totalFiles = totalFiles + 1;

        % Parse filename
        tokens = regexp(fileName, filePattern, 'tokens');

        if isempty(tokens)
            fprintf('  [WARNING] Could not parse: %s\n', fileName);
            continue;
        end

        % Extract components
        % fileAlgName = tokens{1}{1};  % Not needed
        problemName = tokens{1}{2};
        % M = str2double(tokens{1}{3});  % Not needed
        % D = str2double(tokens{1}{4});  % Not needed
        runNumber = str2double(tokens{1}{5});

        % Determine if file should be moved
        shouldMove = false;
        reason = '';

        % Check run number
        if runNumber > maxRuns
            shouldMove = true;
            reason = sprintf('run %d > %d', runNumber, maxRuns);
        end

        % Check problem name
        if filterByProblem && ~ismember(problemName, problemsToKeep)
            shouldMove = true;
            if isempty(reason)
                reason = sprintf('problem %s not in keep list', problemName);
            else
                reason = sprintf('%s; problem %s not in keep list', reason, problemName);
            end
        end

        if shouldMove
            movedFiles = movedFiles + 1;
            algMoved = algMoved + 1;

            sourcePath = fullfile(algSourceDir, fileName);
            destPath = fullfile(algDestDir, fileName);

            if dryRun
                % Just preview
                if algMoved <= 3 || mod(algMoved, 10) == 0
                    fprintf('  [WOULD MOVE] %s (%s)\n', fileName, reason);
                end
            else
                % Actually move the file
                if ~exist(algDestDir, 'dir')
                    mkdir(algDestDir);
                end

                try
                    movefile(sourcePath, destPath);
                    if algMoved <= 3 || mod(algMoved, 10) == 0
                        fprintf('  [MOVED] %s\n', fileName);
                    end
                catch ME
                    fprintf('  [ERROR] %s: %s\n', fileName, ME.message);
                end
            end
        else
            keptFiles = keptFiles + 1;
            algKept = algKept + 1;
        end
    end

    if algMoved > 0 || algKept > 0
        fprintf('%s: kept %d, moved %d\n', algName, algKept, algMoved);
    end
end

fprintf('\n=== Summary ===\n');
fprintf('Total files processed: %d\n', totalFiles);
fprintf('Files kept: %d\n', keptFiles);
fprintf('Files %s: %d\n', ternary(dryRun, 'to be moved', 'moved'), movedFiles);

if dryRun && movedFiles > 0
    fprintf('\nRun rerouteBenchmarkData(%d, {...}, false) to actually move these files.\n', maxRuns);
end
end

function result = ternary(condition, trueVal, falseVal)
    if condition
        result = trueVal;
    else
        result = falseVal;
    end
end
