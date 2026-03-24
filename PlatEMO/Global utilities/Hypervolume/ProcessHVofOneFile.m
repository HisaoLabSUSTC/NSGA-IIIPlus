%%%
% fileInfo contains:
% 'filepath': str -- Example: './Data/Alg/a.mat'
% 'algorithm': str -- Example: NSGA-III
% 'filename': str -- Example: 'a.mat'
% 'hvFilepath': str -- Example: './HVData/Alg/a.mat'
% 'shouldProcess': bool -- Example: false
%%% 

function result = ProcessHVofOneFile(fileInfo)
    result = struct('success', false, 'hvData', [], 'error', '');

    try
        % Load original data
        data = load(fileInfo.filepath);

        % Parse filename to get problem information
        parts = strsplit(fileInfo.filename, '_');
        if length(parts) < 5
            result.error = 'Invalid filename format';
            return;
        end

        problemName = parts{2};
        M = str2double(parts{3}(2:end));
        D = str2double(parts{4}(2:end));

        % Get problem instance and reference point
        problemHandle = str2func(problemName);
        problem = problemHandle('M', M, 'D', D);
        [~, ref] = GetPFnRef(problem);

        % Compute hypervolume and CV for each generation
        resultData = data.result;
        numGenerations = size(resultData, 1);
        FE = zeros(numGenerations, 1);
        HV = zeros(numGenerations, 1);
        avgCV = zeros(numGenerations, 1);
        feasibleCount = zeros(numGenerations, 1);

        for g = 1:numGenerations
            FE(g) = resultData{g, 1};
            Population = resultData{g, 2};

            cons = Population.cons;
            cons(cons < 0) = 0;
            CV = sum(cons, 2);
            avgCV(g) = sum(CV) / numel(CV);

            
            % Get feasible population for HV computation
            feas_pop = GetFeasible(Population);


            objs = feas_pop.objs;

            HV(g) = stk_dominatedhv(objs, ref);
            feasibleCount(g) = size(objs, 1);
        end

        % Create structure to return
        hvData = struct();
        hvData.FE = FE;
        hvData.HV = HV;
        hvData.avgCV = avgCV;
        hvData.feasibleCount = feasibleCount;
        hvData.referencePoint = ref;
        hvData.problemInfo = struct(...
            'algorithm', fileInfo.algorithm, ...
            'problemName', problemName, ...
            'M', M, ...
            'D', D, ...
            'originalFile', fileInfo.filename);

        fprintf("%s on %s\n", fileInfo.algorithm, problemName);
        fprintf("Original file: %s\n", fileInfo.filename);
        hvData.computationDate = datetime('now');

        result.hvData = hvData;
        result.success = true;

    catch ME
        result.error = ME.message;
        result.success = false;
    end
end