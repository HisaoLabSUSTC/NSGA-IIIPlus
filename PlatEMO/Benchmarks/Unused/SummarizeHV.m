%% Generate HV Summary Table
%% Configuration
baseDir = './Info/FinalHV';
algorithms = {'NSGAIIIwH', 'PyNSGAIIIwH'};
refDir = 'ReferenceHV';

%% Load reference hypervolumes
refPath = fullfile(baseDir, refDir, 'prob2rhv.mat');
refData = load(refPath, 'prob2rhv');
prob2rhv = refData.prob2rhv;

%% Get all problem names from reference map
problemNames = keys(prob2rhv);

%% Initialize result struct
hvSummary = struct();

%% Process each problem
for i = 1:length(problemNames)
    probName = problemNames{i};
    
    % Get reference HV for this problem
    rhv = prob2rhv(probName);
    
    % Create a struct for this problem's results
    probResult = struct();
    
    for j = 1:length(algorithms)
        alg = algorithms{j};
        
        % Load algorithm's prob2hv map
        algPath = fullfile(baseDir, alg, 'prob2hv.mat');
        algData = load(algPath, 'prob2hv');
        prob2hv = algData.prob2hv;
        
        % Check if this problem exists for this algorithm
        if isKey(prob2hv, probName)
            hvList = prob2hv(probName);
            
            % Normalize by reference HV
            normalizedHV = hvList / rhv;
            
            % Compute statistics
            meanHV = mean(normalizedHV);
            stdHV = std(normalizedHV);
            
            % Store as formatted string (mean ± std)
            probResult.(alg) = sprintf('%.4f ± %.4f', meanHV, stdHV);
            
            % Also store raw values if needed later
            probResult.([alg '_mean']) = meanHV;
            probResult.([alg '_std']) = stdHV;
            probResult.([alg '_raw']) = normalizedHV;
        else
            probResult.(alg) = 'N/A';
            probResult.([alg '_mean']) = NaN;
            probResult.([alg '_std']) = NaN;
            probResult.([alg '_raw']) = [];
        end
    end
    
    % Use valid field name (replace invalid characters)
    validFieldName = matlab.lang.makeValidName(probName);
    hvSummary.(validFieldName) = probResult;
end

%% Display summary table
fprintf('\n========== Normalized HV Summary (Mean ± Std) ==========\n\n');
fprintf('%-20s | %-20s | %-20s\n', 'Problem', algorithms{1}, algorithms{2});
fprintf('%s\n', repmat('-', 1, 65));

probFields = fieldnames(hvSummary);
for i = 1:length(probFields)
    prob = probFields{i};
    result = hvSummary.(prob);
    fprintf('%-20s | %-20s | %-20s\n', prob, result.(algorithms{1}), result.(algorithms{2}));
end

%% Save results
save(fullfile(baseDir, 'hvSummary.mat'), 'hvSummary');
fprintf('\nResults saved to %s\n', fullfile(baseDir, 'hvSummary.mat'));