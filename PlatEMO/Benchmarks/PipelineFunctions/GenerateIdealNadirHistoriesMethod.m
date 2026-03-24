function GenerateIdealNadirHistoriesMethod(algorithmSpecs, problemHandles, Mvec, problemNames, Dvec, IDvec)
%GENERATEIDEALNADIRHISTORIESMETHOD Generate ideal/nadir point histories
%
%   GenerateIdealNadirHistoriesMethod(algorithmSpecs, problemHandles, Mvec)
%   GenerateIdealNadirHistoriesMethod(algorithmSpecs, problemHandles, Mvec, problemNames, Dvec, IDvec)
%
%   Input:
%     algorithmSpecs  - Cell array of algorithm specs (handles or config cells)
%     problemHandles  - Cell array of problem function handles
%     Mvec            - Numeric vector of M values (one per problem), or scalar
%     problemNames    - (optional) Cell array of pipeline names (e.g. 'MOTSP_ID1')
%     Dvec            - (optional) Decision variable counts (NaN for continuous)
%     IDvec           - (optional) Instance IDs (NaN for continuous)

    targetDir = fullfile('./Info/IdealNadirHistory');
    if ~exist(targetDir, 'dir')
        mkdir(targetDir);
    end
    sourceDirData = fullfile('./Data');

    numProblems = numel(problemHandles);

    % Default problemNames from handles
    if nargin < 4 || isempty(problemNames)
        problemNames = cellfun(@func2str, problemHandles, 'UniformOutput', false);
    end

    % Expand scalar M to vector
    if isscalar(Mvec)
        Mvec = repmat(Mvec, 1, numProblems);
    end

    if nargin < 5 || isempty(Dvec)
        Dvec = nan(1, numProblems);
    end

    if nargin < 6 || isempty(IDvec)
        IDvec = nan(1, numProblems);
    end

    % Raw class names for file matching
    rawClassNames = cellfun(@func2str, problemHandles, 'UniformOutput', false);

    % --- Build all Algorithm-Problem pairs ---
    AllPairs = {};
    for ph = 1:numProblems
        for ah = 1:numel(algorithmSpecs)
            AllPairs{end+1} = struct( ...
                'AlgSpec', {algorithmSpecs{ah}}, ...
                'ProbHandle', problemHandles{ph}, ...
                'RawName', rawClassNames{ph}, ...
                'PipeName', problemNames{ph}, ...
                'M', Mvec(ph), ...
                'D', Dvec(ph), ...
                'ID', IDvec(ph)); %#ok<AGROW>
        end
    end

    fprintf('Starting processing of %d tasks...\n', numel(AllPairs));

    for i = 1:numel(AllPairs)
        pair = AllPairs{i};
        algName = getAlgorithmName(pair.AlgSpec);

        % Build glob pattern for data files
        if ~isnan(pair.ID)
            % Combinatorial: match files with _ID{N} token
            globPattern = sprintf('%s_%s_M%d_D*_ID%d_*.mat', ...
                algName, pair.RawName, pair.M, pair.ID);
        else
            % Continuous: standard pattern
            globPattern = sprintf('%s_%s_M%d_*.mat', ...
                algName, pair.RawName, pair.M);
        end

        dataFilePath = fullfile(sourceDirData, algName, globPattern);
        dataFiles = dir(dataFilePath);

        if isempty(dataFiles)
            fprintf('  No data files found: %s\n', dataFilePath);
            continue;
        end

        % Process
        processStabilityData(dataFiles, algName, pair, targetDir);
    end

    disp('Processing complete.');
end

function processStabilityData(dataFiles, algName, pair, targetDir)
    % Instantiate problem to get M and normalization structure
    if ~isnan(pair.ID)
        paramCell = buildCombinatorialParam(pair.RawName, pair.ID);
        Problem = pair.ProbHandle('M', pair.M, 'D', pair.D, 'parameter', paramCell);
    else
        Problem = pair.ProbHandle('M', pair.M);
    end
    M = Problem.M;

    ideal_history = cell(1, numel(dataFiles));
    nadir_history = cell(1, numel(dataFiles));

    for fi = 1:numel(dataFiles)
        fprintf('Processing file %d/%d for %s on %s\n', fi, numel(dataFiles), algName, pair.PipeName);

        dataPath = fullfile(dataFiles(fi).folder, dataFiles(fi).name);

        % Load data
        data = load(dataPath);
        resultMatrix = data.result;
        n_gens = size(resultMatrix, 1);
        N = numel(resultMatrix{1, 2});

        % Create normalization structure using alg2norm (handles all algorithm types)
        NormStruct = alg2norm(algName, N, M);

        SS = initializeStabilityStruct(M, n_gens);

        % First generation
        Population = resultMatrix{1, 2};
        nds = nds_preprocess(Population);
        norm_update(algName, Problem, NormStruct, Population, nds);
        SS.ideal_point_history(1, :) = NormStruct.ideal_point;
        SS.nadir_point_history(1, :) = NormStruct.nadir_point;
        SS.FE_history(1) = resultMatrix{1, 1};

        % Subsequent generations
        for g = 2:n_gens
            Population = resultMatrix{g-1, 2};
            Offspring = resultMatrix{g, 3};
            Mixture = [Population, Offspring];
            nds = nds_preprocess(Mixture);
            norm_update(algName, Problem, NormStruct, Mixture, nds);

            SS.ideal_point_history(g, :) = NormStruct.ideal_point;
            SS.nadir_point_history(g, :) = NormStruct.nadir_point;
            SS.FE_history(g) = resultMatrix{g, 1};
        end

        ideal_history{fi} = SS.ideal_point_history;
        nadir_history{fi} = SS.nadir_point_history;
    end

    % Save results using pipeline name
    targetAlgDir = fullfile(targetDir, algName);
    if ~exist(targetAlgDir, 'dir')
        mkdir(targetAlgDir);
    end

    outputFileName = ['IN-', algName, '-', pair.PipeName, '.mat'];
    outputFilePath = fullfile(targetAlgDir, outputFileName);

    save(outputFilePath, 'ideal_history', 'nadir_history');
end

function SS = initializeStabilityStruct(M, n_gens)
    SS = struct();
    SS.ideal_point_history = nan(n_gens, M);
    SS.nadir_point_history = nan(n_gens, M);
    SS.FE_history = nan(n_gens, 1);
    SS.abs_stability_ideal_gen = NaN;
    SS.abs_stability_nadir_gen = NaN;
    SS.rel_stability_ideal_gen = NaN;
    SS.rel_stability_nadir_gen = NaN;
end

function problemHandles = preprocessProblemHandles(algorithmSpecs, sourceDirData)
    problemHandles = {};
    for ah = 1:numel(algorithmSpecs)
        algName = getAlgorithmName(algorithmSpecs{ah});
        dataFile = dir(fullfile(sourceDirData, algName, '*.mat'));
        FileNames = {dataFile.name};

        for fi = 1:numel(FileNames)
            FileName = FileNames{fi};
            [~, rawName, ~] = fileparts(FileName);
            tokens = strsplit(rawName, '_');

            if length(tokens) >= 3
                problemHandles{end+1} = [tokens{2}, '-', tokens{3}(2:end)]; %#ok<AGROW>
            end
        end
    end

    % Get unique problem names
    uniqueProblemNames = unique(problemHandles);
    problemHandles = cellfun(@(f) split(f, '-'), uniqueProblemNames, 'UniformOutput', false);
end
