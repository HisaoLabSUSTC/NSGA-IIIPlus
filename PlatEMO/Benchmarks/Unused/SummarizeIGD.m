%% Generate HV Summary Table
%% Configuration
baseDir = './Info/FinalIGD';
algorithms = {'NSGAIIIwH', 'PyNSGAIIIwH'};

%% Load reference hypervolumes
refPath = fullfile(baseDir, algorithms{1}, 'prob2igdp.mat');
refData = load(refPath, 'prob2igd');
prob2igd = refData.prob2igd;

%% Get all problem names from reference map
problemNames = keys(prob2igd);

%% Initialize result struct
igdSummary = struct();
%% Process each problem
for i = 1:length(problemNames)
    probName = problemNames{i};

    % Create a struct for this problem's results
    probResult = struct();
    
    for j = 1:length(algorithms)
        alg = algorithms{j};
        
        % Load algorithm's prob2hv map
        algPath = fullfile(baseDir, alg, 'prob2igdp.mat');
        algData = load(algPath, 'prob2igd');
        prob2igd = algData.prob2igd;
        
        % Check if this problem exists for this algorithm
        if isKey(prob2igd, probName)
            igdList = prob2igd(probName);
            
            % Compute statistics
            meanIGD = mean(igdList);
            stdIGD = std(igdList);
            
            % Store as formatted string (mean ± std)
            probResult.(alg) = sprintf('%.3g ± %.3g', meanIGD, stdIGD);
            
            % Also store raw values if needed later
            probResult.([alg '_mean']) = meanIGD;
            probResult.([alg '_std']) = stdIGD;
            probResult.([alg '_raw']) = igdList;
        else
            probResult.(alg) = 'N/A';
            probResult.([alg '_mean']) = NaN;
            probResult.([alg '_std']) = NaN;
            probResult.([alg '_raw']) = [];
        end
    end
    
    % Use valid field name (replace invalid characters)
    validFieldName = matlab.lang.makeValidName(probName);
    igdSummary.(validFieldName) = probResult;
end

%% Display summary table
fprintf('\n========== Normalized IGD Summary (Mean ± Std) ==========\n\n');
fprintf('%-20s | %-20s | %-20s\n', 'Problem', algorithms{1}, algorithms{2});
fprintf('%s\n', repmat('-', 1, 65));

probFields = fieldnames(igdSummary);
for i = 1:length(probFields)
    prob = probFields{i};
    result = igdSummary.(prob);
    fprintf('%-20s | %-20s | %-20s\n', prob, result.(algorithms{1}), result.(algorithms{2}));
end

%% Save results
save(fullfile(baseDir, 'igdSummary.mat'), 'igdSummary');
fprintf('\nResults saved to %s\n', fullfile(baseDir, 'igdSummary.mat'));