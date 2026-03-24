function syncAlgorithmNames(algorithms, jsonPath)
%SYNCALGORITHMNAMES Update algorithm_display_names.json with current algorithms
%
%   syncAlgorithmNames(algorithms)
%   syncAlgorithmNames(algorithms, jsonPath)
%
%   Reads existing JSON file, adds any new algorithm names from the provided
%   algorithm specs, and writes back the updated file.
%
%   Input:
%     algorithms - Cell array of algorithm specs (handles or config cells)
%     jsonPath   - Path to JSON file (default: './Info/Misc/algorithm_display_names.json')

if nargin < 2
    jsonPath = './Info/Misc/algorithm_display_names.json';
end

% Ensure directory exists
[jsonDir, ~, ~] = fileparts(jsonPath);
if ~exist(jsonDir, 'dir')
    mkdir(jsonDir);
end

% Load existing names
existingNames = struct();
if exist(jsonPath, 'file')
    try
        jsonText = fileread(jsonPath);
        existingNames = jsondecode(jsonText);
    catch ME
        warning('Failed to parse existing JSON: %s', ME.message);
    end
end

% Process each algorithm
newCount = 0;
for i = 1:numel(algorithms)
    spec = algorithms{i};

    % Get internal and display names
    [displayName, internalName] = getAlgorithmName(spec);

    % Add if not exists
    fieldName = matlab.lang.makeValidName(internalName);
    if ~isfield(existingNames, fieldName)
        existingNames.(fieldName) = displayName;
        newCount = newCount + 1;
        fprintf('  Added: %s -> %s\n', internalName, displayName);
    end
end

% Write back to JSON
if newCount > 0
    % Convert struct to JSON with proper formatting
    jsonText = jsonencode(existingNames);

    % Pretty print (basic formatting)
    jsonText = strrep(jsonText, ',"', sprintf(',\n    "'));
    jsonText = strrep(jsonText, '{', sprintf('{\n    '));
    jsonText = strrep(jsonText, '}', sprintf('\n}'));

    fid = fopen(jsonPath, 'w');
    fprintf(fid, '%s', jsonText);
    fclose(fid);

    fprintf('Updated %s with %d new entries\n', jsonPath, newCount);
else
    fprintf('No new algorithm names to add\n');
end
end
