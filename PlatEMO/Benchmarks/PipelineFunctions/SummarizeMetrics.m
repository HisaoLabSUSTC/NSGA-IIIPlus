function SummarizeMetrics(algorithmSpecs, problemHandles, M, N, problemNames)
%SUMMARIZEMETRICS Compute reference HV, HV summary, IGD+, Generalized Spread, and Time summaries
%
%   SummarizeMetrics(algorithmSpecs, problemHandles, M, N)
%   SummarizeMetrics(algorithmSpecs, problemHandles, M, N, problemNames)
%
%   Input:
%     algorithmSpecs   - Cell array of algorithm specs (handles or config cells)
%     problemHandles   - Cell array of problem function handles
%     M                - Number of objectives. Scalar (applied to all) or
%                        vector with one value per problem.
%     N                - Population size
%     problemNames     - (optional) Cell array of pipeline names.
%                        Defaults to func2str of each handle.
%
%   Output:
%     Saves:
%       - ./Info/FinalHV/ReferenceHV/prob2rhv.mat (reference hypervolumes)
%       - ./Info/FinalHV/hvSummary.mat (normalized HV summary)
%       - ./Info/FinalIGD/igdSummary.mat (IGD+ summary)
%       - ./Info/FinalGenSpread/genSpreadSummary.mat (Generalized Spread summary)
%       - ./Info/FinalTime/timeSummary.mat (Time summary)

    %% Extract names - supports both legacy handles and config-based specs
    algorithmNames = cell(1, numel(algorithmSpecs));
    for i = 1:numel(algorithmSpecs)
        algorithmNames{i} = getAlgorithmName(algorithmSpecs{i});
    end
    if nargin < 5 || isempty(problemNames)
        problemNames = cellfun(@func2str, problemHandles, 'UniformOutput', false);
    end

    numAlgorithms = numel(algorithmNames);
    numProblems = numel(problemNames);

    % Expand scalar M to vector
    if isscalar(M)
        M = repmat(M, 1, numProblems);
    end

    %% Directory setup
    hvBaseDir = './Info/FinalHV';
    igdBaseDir = './Info/FinalIGD';
    refDir = fullfile(hvBaseDir, 'ReferenceHV');

    if ~exist(refDir, 'dir')
        mkdir(refDir);
    end

    %% ================================================================
    %  PHASE 1: Compute Reference Hypervolumes (in normalized [0,1] space)
    %% ================================================================
    fprintf('\n========== Phase 1: Computing Reference Hypervolumes ==========\n');
    fprintf('  (Maximum obtainable HV in normalized [0,1] space with ref=[1,...,1])\n');

    prob2rhv = containers.Map();

    for i = 1:numProblems
        pn = problemNames{i};
        M_i = M(i);

        fprintf('  Computing reference HV for %s (M=%d, %d/%d)...\n', pn, M_i, i, numProblems);

        % Load stored reference PF and normalize to [0,1]
        [PF, ideal, nadir] = loadReferencePF(pn);
        range = nadir - ideal;
        range(range < 1e-12) = 1e-12;
        PF_norm = (PF - ideal) ./ range;

        % HV reference point: 1 + 1/H (cite ishibuchi et al.)
        H = getRefH(M_i, N);
        ref = ones(1, M_i) + ones(1, M_i)./H;

        % Compute maximum obtainable HV in normalized space
        hv = stk_dominatedhv(PF_norm, ref);
        prob2rhv(pn) = hv;

        fprintf('    Reference HV (normalized): %.6f\n', hv);
    end

    % Save reference hypervolumes
    refPath = fullfile(refDir, 'prob2rhv.mat');
    save(refPath, 'prob2rhv');
    fprintf('  Saved reference HVs to: %s\n', refPath);

    %% ================================================================
    %  PHASE 2: Generate HV Summary (already normalized from computeAllMetrics)
    %% ================================================================
    fprintf('\n========== Phase 2: Generating HV Summary ==========\n');
    fprintf('  HV values are already in normalized [0,1] space (no refHV division needed).\n');

    hvSummary = struct();

    for i = 1:numProblems
        probName = problemNames{i};

        % Create a struct for this problem's results
        probResult = struct();

        for j = 1:numAlgorithms
            alg = algorithmNames{j};

            % Load algorithm's prob2hv map
            algPath = fullfile(hvBaseDir, alg, 'prob2hv.mat');

            if ~exist(algPath, 'file')
                warning('HV file not found: %s', algPath);
                probResult.(matlab.lang.makeValidName(alg)) = 'N/A';
                probResult.([matlab.lang.makeValidName(alg) '_mean']) = NaN;
                probResult.([matlab.lang.makeValidName(alg) '_std']) = NaN;
                probResult.([matlab.lang.makeValidName(alg) '_raw']) = [];
                continue;
            end

            algData = load(algPath, 'prob2hv_map');
            prob2hv = algData.prob2hv_map;

            % Check if this problem exists for this algorithm
            if isKey(prob2hv, probName)
                hvList = prob2hv(probName);

                % HV values are already normalized - no division needed
                meanHV = mean(hvList);
                stdHV = std(hvList);

                % Store as formatted string (mean +/- std)
                algField = matlab.lang.makeValidName(alg);
                probResult.(algField) = sprintf('%.4f +/- %.4f', meanHV, stdHV);
                probResult.([algField '_mean']) = meanHV;
                probResult.([algField '_std']) = stdHV;
                probResult.([algField '_raw']) = hvList;
            else
                algField = matlab.lang.makeValidName(alg);
                probResult.(algField) = 'N/A';
                probResult.([algField '_mean']) = NaN;
                probResult.([algField '_std']) = NaN;
                probResult.([algField '_raw']) = [];
            end
        end

        % Use valid field name
        validFieldName = matlab.lang.makeValidName(probName);
        hvSummary.(validFieldName) = probResult;
    end

    % Display HV summary table
    fprintf('\n---------- Normalized HV Summary (Mean +/- Std) ----------\n\n');

    % Build header
    headerFormat = '%-20s';
    headerArgs = {'Problem'};
    for j = 1:numAlgorithms
        headerFormat = [headerFormat ' | %-20s']; %#ok<AGROW>
        headerArgs{end+1} = algorithmNames{j}; %#ok<AGROW>
    end
    fprintf([headerFormat '\n'], headerArgs{:});
    fprintf('%s\n', repmat('-', 1, 22 + 23*numAlgorithms));

    % Print rows
    probFields = fieldnames(hvSummary);
    for i = 1:length(probFields)
        prob = probFields{i};
        result = hvSummary.(prob);

        rowFormat = '%-20s';
        rowArgs = {prob};
        for j = 1:numAlgorithms
            rowFormat = [rowFormat ' | %-20s']; %#ok<AGROW>
            algField = matlab.lang.makeValidName(algorithmNames{j});
            rowArgs{end+1} = result.(algField); %#ok<AGROW>
        end
        fprintf([rowFormat '\n'], rowArgs{:});
    end

    % Save HV summary
    hvSummaryPath = fullfile(hvBaseDir, 'hvSummary.mat');
    save(hvSummaryPath, 'hvSummary');
    fprintf('\n  Saved HV summary to: %s\n', hvSummaryPath);

    %% ================================================================
    %  PHASE 3: Generate IGD+ Summary
    %% ================================================================
    fprintf('\n========== Phase 3: Generating IGD+ Summary ==========\n');

    igdSummary = struct();

    for i = 1:numProblems
        probName = problemNames{i};
        probResult = struct();

        for j = 1:numAlgorithms
            alg = algorithmNames{j};

            % Load algorithm's IGD map
            algPath = fullfile(igdBaseDir, alg, 'prob2igdp.mat');

            if ~exist(algPath, 'file')
                warning('IGD file not found: %s', algPath);
                algField = matlab.lang.makeValidName(alg);
                probResult.(algField) = 'N/A';
                probResult.([algField '_mean']) = NaN;
                probResult.([algField '_std']) = NaN;
                probResult.([algField '_raw']) = [];
                continue;
            end

            algData = load(algPath, 'prob2igd');
            prob2igd = algData.prob2igd;

            if isKey(prob2igd, probName)
                igdList = prob2igd(probName);

                % Compute statistics
                meanIGD = mean(igdList);
                stdIGD = std(igdList);

                algField = matlab.lang.makeValidName(alg);
                probResult.(algField) = sprintf('%.4e +/- %.4e', meanIGD, stdIGD);
                probResult.([algField '_mean']) = meanIGD;
                probResult.([algField '_std']) = stdIGD;
                probResult.([algField '_raw']) = igdList;
            else
                algField = matlab.lang.makeValidName(alg);
                probResult.(algField) = 'N/A';
                probResult.([algField '_mean']) = NaN;
                probResult.([algField '_std']) = NaN;
                probResult.([algField '_raw']) = [];
            end
        end

        validFieldName = matlab.lang.makeValidName(probName);
        igdSummary.(validFieldName) = probResult;
    end

    % Display IGD summary table
    fprintf('\n---------- IGD+ Summary (Mean +/- Std) ----------\n\n');

    headerFormat = '%-20s';
    headerArgs = {'Problem'};
    for j = 1:numAlgorithms
        headerFormat = [headerFormat ' | %-24s']; %#ok<AGROW>
        headerArgs{end+1} = algorithmNames{j}; %#ok<AGROW>
    end
    fprintf([headerFormat '\n'], headerArgs{:});
    fprintf('%s\n', repmat('-', 1, 22 + 27*numAlgorithms));

    probFields = fieldnames(igdSummary);
    for i = 1:length(probFields)
        prob = probFields{i};
        result = igdSummary.(prob);

        rowFormat = '%-20s';
        rowArgs = {prob};
        for j = 1:numAlgorithms
            rowFormat = [rowFormat ' | %-24s']; %#ok<AGROW>
            algField = matlab.lang.makeValidName(algorithmNames{j});
            rowArgs{end+1} = result.(algField); %#ok<AGROW>
        end
        fprintf([rowFormat '\n'], rowArgs{:});
    end

    % Save IGD summary
    igdSummaryPath = fullfile(igdBaseDir, 'igdSummary.mat');
    save(igdSummaryPath, 'igdSummary');
    fprintf('\n  Saved IGD+ summary to: %s\n', igdSummaryPath);

    %% ================================================================
    %  PHASE 4: Generate Generalized Spread Summary
    %% ================================================================
    fprintf('\n========== Phase 4: Generating Generalized Spread Summary ==========\n');

    genSpreadBaseDir = './Info/FinalGenSpread';
    genSpreadSummary = struct();

    for i = 1:numProblems
        probName = problemNames{i};
        probResult = struct();

        for j = 1:numAlgorithms
            alg = algorithmNames{j};

            % Load algorithm's Generalized Spread map
            algPath = fullfile(genSpreadBaseDir, alg, 'prob2genspread.mat');

            if ~exist(algPath, 'file')
                warning('GenSpread file not found: %s', algPath);
                algField = matlab.lang.makeValidName(alg);
                probResult.(algField) = 'N/A';
                probResult.([algField '_mean']) = NaN;
                probResult.([algField '_std']) = NaN;
                probResult.([algField '_raw']) = [];
                continue;
            end

            algData = load(algPath, 'prob2genspread');
            prob2genspread = algData.prob2genspread;

            if isKey(prob2genspread, probName)
                genSpreadList = prob2genspread(probName);

                % Compute statistics
                meanGenSpread = mean(genSpreadList);
                stdGenSpread = std(genSpreadList);

                algField = matlab.lang.makeValidName(alg);
                probResult.(algField) = sprintf('%.4f +/- %.4f', meanGenSpread, stdGenSpread);
                probResult.([algField '_mean']) = meanGenSpread;
                probResult.([algField '_std']) = stdGenSpread;
                probResult.([algField '_raw']) = genSpreadList;
            else
                algField = matlab.lang.makeValidName(alg);
                probResult.(algField) = 'N/A';
                probResult.([algField '_mean']) = NaN;
                probResult.([algField '_std']) = NaN;
                probResult.([algField '_raw']) = [];
            end
        end

        validFieldName = matlab.lang.makeValidName(probName);
        genSpreadSummary.(validFieldName) = probResult;
    end

    % Display Generalized Spread summary table
    fprintf('\n---------- Generalized Spread Summary (Mean +/- Std) ----------\n\n');

    headerFormat = '%-20s';
    headerArgs = {'Problem'};
    for j = 1:numAlgorithms
        headerFormat = [headerFormat ' | %-20s']; %#ok<AGROW>
        headerArgs{end+1} = algorithmNames{j}; %#ok<AGROW>
    end
    fprintf([headerFormat '\n'], headerArgs{:});
    fprintf('%s\n', repmat('-', 1, 22 + 23*numAlgorithms));

    probFields = fieldnames(genSpreadSummary);
    for i = 1:length(probFields)
        prob = probFields{i};
        result = genSpreadSummary.(prob);

        rowFormat = '%-20s';
        rowArgs = {prob};
        for j = 1:numAlgorithms
            rowFormat = [rowFormat ' | %-20s']; %#ok<AGROW>
            algField = matlab.lang.makeValidName(algorithmNames{j});
            rowArgs{end+1} = result.(algField); %#ok<AGROW>
        end
        fprintf([rowFormat '\n'], rowArgs{:});
    end

    % Save Generalized Spread summary
    genSpreadSummaryPath = fullfile(genSpreadBaseDir, 'genSpreadSummary.mat');
    if ~exist(genSpreadBaseDir, 'dir')
        mkdir(genSpreadBaseDir);
    end
    save(genSpreadSummaryPath, 'genSpreadSummary');
    fprintf('\n  Saved Generalized Spread summary to: %s\n', genSpreadSummaryPath);

    %% ================================================================
    %  PHASE 5: Generate Time Summary
    %% ================================================================
    fprintf('\n========== Phase 5: Generating Time Summary ==========\n');

    timeBaseDir = './Info/FinalTime';
    timeSummary = struct();

    for i = 1:numProblems
        probName = problemNames{i};
        probResult = struct();

        for j = 1:numAlgorithms
            alg = algorithmNames{j};

            % Load algorithm's Time map
            algPath = fullfile(timeBaseDir, alg, 'prob2time.mat');

            if ~exist(algPath, 'file')
                warning('Time file not found: %s', algPath);
                algField = matlab.lang.makeValidName(alg);
                probResult.(algField) = 'N/A';
                probResult.([algField '_mean']) = NaN;
                probResult.([algField '_std']) = NaN;
                probResult.([algField '_raw']) = [];
                continue;
            end

            algData = load(algPath, 'prob2time');
            prob2time = algData.prob2time;

            if isKey(prob2time, probName)
                timeList = prob2time(probName);

                % Compute statistics
                meanTime = mean(timeList);
                stdTime = std(timeList);

                algField = matlab.lang.makeValidName(alg);
                probResult.(algField) = sprintf('%.2f +/- %.2f', meanTime, stdTime);
                probResult.([algField '_mean']) = meanTime;
                probResult.([algField '_std']) = stdTime;
                probResult.([algField '_raw']) = timeList;
            else
                algField = matlab.lang.makeValidName(alg);
                probResult.(algField) = 'N/A';
                probResult.([algField '_mean']) = NaN;
                probResult.([algField '_std']) = NaN;
                probResult.([algField '_raw']) = [];
            end
        end

        validFieldName = matlab.lang.makeValidName(probName);
        timeSummary.(validFieldName) = probResult;
    end

    % Display Time summary table
    fprintf('\n---------- Time Summary (Mean +/- Std, seconds) ----------\n\n');

    headerFormat = '%-20s';
    headerArgs = {'Problem'};
    for j = 1:numAlgorithms
        headerFormat = [headerFormat ' | %-20s']; %#ok<AGROW>
        headerArgs{end+1} = algorithmNames{j}; %#ok<AGROW>
    end
    fprintf([headerFormat '\n'], headerArgs{:});
    fprintf('%s\n', repmat('-', 1, 22 + 23*numAlgorithms));

    probFields = fieldnames(timeSummary);
    for i = 1:length(probFields)
        prob = probFields{i};
        result = timeSummary.(prob);

        rowFormat = '%-20s';
        rowArgs = {prob};
        for j = 1:numAlgorithms
            rowFormat = [rowFormat ' | %-20s']; %#ok<AGROW>
            algField = matlab.lang.makeValidName(algorithmNames{j});
            rowArgs{end+1} = result.(algField); %#ok<AGROW>
        end
        fprintf([rowFormat '\n'], rowArgs{:});
    end

    % Save Time summary
    timeSummaryPath = fullfile(timeBaseDir, 'timeSummary.mat');
    if ~exist(timeBaseDir, 'dir')
        mkdir(timeBaseDir);
    end
    save(timeSummaryPath, 'timeSummary');
    fprintf('\n  Saved Time summary to: %s\n', timeSummaryPath);

    fprintf('\n========== Summary Complete ==========\n');
end
