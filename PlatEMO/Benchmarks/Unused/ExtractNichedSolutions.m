Algorithms = {@PyNSGAIIIwH, @NSGAIIIwH};
% phs = {@UF1, @UF2, @UF3, @UF4, @UF5, @UF6, @UF7, @UF8, @UF9, @UF10};
% phs = {@MaF10,@MaF11,@MaF12,@MaF13,@MaF14,@MaF15};
ExtractNichedSolutionsMethod(Algorithms)

function ExtractNichedSolutionsMethod(algorithmHandles, problemHandles)
    targetDir = fullfile('./Info/NichedSolutions'); mkdir(targetDir);
    sourceDirData = fullfile('Data');
    if nargin < 2 || isempty(problemHandles)
        problemHandles = preprocessProblemHandles(algorithmHandles, sourceDirData);
    end
    AllPairs = {};
    for ph = 1:numel(problemHandles)
        for ah = 1:numel(algorithmHandles)
            % Store the handles directly in the pair
            AllPairs{end+1} = struct('AlgHandle', algorithmHandles{ah}, ...
                                     'ProbHandle', problemHandles{ph});
        end
    end
    
    %% Construct tasks to parallelize this process
    % if isempty(gcp('nocreate'))
    %     disp('Starting parallel pool...');
    %     parpool; % Start the default parallel pool if not already running
    % end
    %% For each problem, associate with Data, and turn them into 
    % Use parfor to distribute the work of processing each file pair
    parfor i = 1:numel(AllPairs)
        currentPair = AllPairs{i};
        algHandle = currentPair.AlgHandle;
        problemHandle = currentPair.ProbHandle;
        
        algName = func2str(algHandle);
        problem = func2str(problemHandle);
        
        % 1. Find the specific data file for this Alg/Problem combination
        dataFilePath = fullfile(sourceDirData, algName, [algName, '_', problem, '_', '*.mat']);
        dataFiles = dir(dataFilePath);
        
        % Handle multiple files matching the pattern (e.g., multiple runs)
        for fi = 1:numel(dataFiles)
            dataPath = fullfile(dataFiles(fi).folder, dataFiles(fi).name);
            
            % Processing logic moved to a helper function for cleaner parallel loop
            % try
                processDataFile(dataPath, algName, problem, targetDir);
            % catch ME
            %     fprintf(2, '\n   -> FAILED (Corrupted/Error): %s. Error Type: %s\n', dataPath, ME.identifier);
            % end
        end
    end
    
    disp('Parallel processing complete.');
end
function processDataFile(dataPath, algName, problem, targetDir)
    % Create target subdirectory and output path first for existence check
    targetAlgDir = fullfile(targetDir, algName);
    % Generate the output filename (NS- prefix)
    [~, rawName] = fileparts(dataPath);
    outputFileName = ['NS-', rawName, '.mat'];
    outputFilePath = fullfile(targetAlgDir, outputFileName);
    
    % --- Step 0: Check if output file already exists. If so, skip processing. ---
    if exist(outputFilePath, 'file') == 2
        fprintf('    [SKIP] NS file already exists: %s\n', outputFilePath);
        return;
    end

    % 1. Load Data
    data = load(dataPath);
    
    if ~isfield(data, 'result')
        warning('MATLAB:MissingField', '%s missing variable "result"', dataPath);
        return;
    end
    resultMatrix = data.result;
    
    % 2. Initialize Problem and Uniform Points
    Problem = []; % Initialize Problem structure
    M = []; D = []; Z = []; NormStruct = []; % Initialize other variables
    lastPopulation = resultMatrix{end, 2};
    FE = resultMatrix{end, 1}; % FE from the last generation
    % -------------------------------------
    % Initialize Problem (M, D) only once
    % -------------------------------------
    M = size(lastPopulation(1).objs, 2); % Assuming structure array in resultMatrix
    D = size(lastPopulation(1).decs, 2);

    Problem_handle = str2func(problem);
    Problem = Problem_handle('M', M, 'D', D);
    % -------------------------------------
    % Uniform reference vectors (per alg)
    % -------------------------------------
    N = numel(lastPopulation);
    [Z, ~] = UniformPoint(N, Problem.M);
    
    NormStruct = alg2norm(algName, N, M);
   
    % 3. Iterate and Process Generations
    n_gens = size(resultMatrix, 1);
    
    % Initialize the matrix to store the mindist results
    MindistResultMatrix = cell(n_gens, 2);
    
    % %% First iteration requires special processing
    Population = resultMatrix{1, 2};
    nds = nds_preprocess(Population);
    norm_update(algName, Problem, NormStruct, Population, nds);
    
    % Compute and store mindist for the first generation
    [~, P_mindist] = ComputeMindist(Population, Problem, Z, NormStruct);
    MindistResultMatrix{1, 1} = resultMatrix{1, 1}; % FE
    MindistResultMatrix{1, 2} = P_mindist;
    % %% Loop through remaining generations
    for g = 2:n_gens
        Population = resultMatrix{g-1, 2};
        Offspring = resultMatrix{g, 3};
        Mixture = [Population, Offspring];
        nds = nds_preprocess(Mixture);
        norm_update(algName, Problem, NormStruct, Mixture, nds);
        
        % Compute and store mindist for the current generation (after norm_update)
        % Assuming Population here refers to the parent population from g-1
        [~, P_mindist] = ComputeMindist(Population, Problem, Z, NormStruct); 
        MindistResultMatrix{g, 1} = resultMatrix{g, 1}; % FE
        MindistResultMatrix{g, 2} = P_mindist;
    end
    
    % 4. Save the Result
    
    % Create target subdirectory
    mkdir(targetAlgDir); 
    
    % Save the result matrix (MindistResultMatrix)
    result = MindistResultMatrix; % Variable name 'result' for consistency in file loading
    save(outputFilePath, 'result');
end
function problemHandles = preprocessProblemHandles(algorithmHandles, sourceDirData)
    problemHandles = {};
    for ah = 1:numel(algorithmHandles)
        algName = func2str(algorithmHandles{ah});
        dataFile = dir(fullfile(sourceDirData, algName, '*.mat'));
        FileNames = {dataFile.name};
        
        for fi = 1:numel(FileNames)
            FileName = FileNames{fi};
            [~,rawName,~] = fileparts(FileName);
            tokens = strsplit(rawName,'_');
            
            % Ensure there's a token at index 2
            if length(tokens) >= 2
                problemHandles{end+1} = tokens{2};
            end
        end
    end
    % Apply str2func to unique names to get a cell array of function handles
    problemHandles = cellfun(@str2func, unique(problemHandles), 'UniformOutput', false);
end