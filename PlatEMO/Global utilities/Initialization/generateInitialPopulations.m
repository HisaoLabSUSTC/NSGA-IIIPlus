function generateInitialPopulations(problems, N, M, runs, saveto, Dvec, IDvec)
%GENERATEINITIALPOPULATIONS Generate initial populations for benchmark runs
%
%   M can be a scalar (applied to all problems) or a vector with one value
%   per problem.
%
%   For combinatorial problems (non-NaN IDvec entries), greedy heuristic
%   solutions are generated and padded with random solutions to fill N.

    if nargin < 5 || isempty(saveto)
        saveto = './Info/InitialPopulation';
    end

    if nargin < 6 || isempty(Dvec)
        Dvec = nan(1, numel(problems));
    end

    if nargin < 7 || isempty(IDvec)
        IDvec = nan(1, numel(problems));
    end

    % Expand scalar M to vector
    if isscalar(M)
        M = repmat(M, 1, numel(problems));
    end

    sourceDirData = saveto;
    if ~exist(sourceDirData, 'dir')
        mkdir(sourceDirData);
    end

    % --- 1. Determine all required tasks and filter out existing files ---
    [P_indices, R_indices] = ndgrid(1:length(problems), 1:runs);
    all_tasks = [P_indices(:), R_indices(:)];
    total_tasks = size(all_tasks, 1);

    fprintf('Task 1: Checking %d potential initial population tasks...\n', total_tasks);

    % Pre-check which files already exist
    tasks_to_run = [];
    skipped_count = 0;

    for idx = 1:total_tasks
        prob_idx = all_tasks(idx, 1);
        run_num = all_tasks(idx, 2);

        prob_handle = problems{prob_idx};
        prob_name = func2str(prob_handle);
        M_i = M(prob_idx);
        D_i = Dvec(prob_idx);
        ID_i = IDvec(prob_idx);

        % Build pattern: include ID for combinatorial problems
        if ~isnan(ID_i)
            pattern = sprintf('HS-%s_ID%d_M%d_D%d_%d.mat', prob_name, ID_i, M_i, D_i, run_num);
        else
            pattern = sprintf('HS-%s_M%d_D%d_%d.mat', prob_name, M_i, D_i, run_num);
        end
        matches = dir(fullfile(sourceDirData, pattern));

        if ~isempty(matches)
            fprintf('SKIPPED (exists): %s\n', matches(1).name);
            skipped_count = skipped_count + 1;
        else
            tasks_to_run = [tasks_to_run; prob_idx, run_num]; %#ok<AGROW>
        end
    end

    num_tasks_to_run = size(tasks_to_run, 1);
    fprintf('Task 1: %d files already exist, %d to generate.\n', skipped_count, num_tasks_to_run);

    if num_tasks_to_run == 0
        fprintf('Task 1: All files already exist. Nothing to do.\n');
        return;
    end

    % --- 2. Generate populations ---
    fprintf('Task 1: Generating %d populations...\n', num_tasks_to_run);

    % Extract columns into separate arrays for parfor compatibility
    task_prob_indices = tasks_to_run(:, 1);
    task_run_nums = tasks_to_run(:, 2);

    saved_data = cell(num_tasks_to_run, 1);

    if runs > 1
        parfor idx = 1:num_tasks_to_run
            saved_data{idx} = generateOnePopulation(idx, ...
                task_prob_indices, task_run_nums, problems, M, N, ...
                Dvec, IDvec, sourceDirData);
        end
    else
        for idx = 1:num_tasks_to_run
            saved_data{idx} = generateOnePopulation(idx, ...
                task_prob_indices, task_run_nums, problems, M, N, ...
                Dvec, IDvec, sourceDirData);
        end
    end

    % --- 3. Save populations SEQUENTIALLY (I/O) ---
    fprintf('Task 1: Saving populations sequentially...\n');

    for idx = 1:num_tasks_to_run
        current_data = saved_data{idx};
        heuristic_solutions = current_data.Data;
        save(current_data.FilePath, 'heuristic_solutions');
        fprintf('SAVED: %s\n', current_data.FileName);
    end

    fprintf('Task 1: Complete. Skipped %d existing, saved %d new files.\n', skipped_count, num_tasks_to_run);
end

%% ==================== Local Functions ====================

function result = generateOnePopulation(idx, task_prob_indices, task_run_nums, ...
        problems, M, N, Dvec, IDvec, sourceDirData)

    prob_idx = task_prob_indices(idx);
    run_num = task_run_nums(idx);

    prob_handle = problems{prob_idx};
    prob_name = func2str(prob_handle);
    M_i = M(prob_idx);
    D_i = Dvec(prob_idx);
    ID_i = IDvec(prob_idx);
    isCombinatorial = ~isnan(ID_i);

    % Create problem instance
    if isCombinatorial
        paramCell = buildCombinatorialParam(prob_name, ID_i);
        pro_inst = prob_handle('M', M_i, 'D', D_i, 'parameter', paramCell);
    else
        pro_inst = prob_handle('M', M_i);
    end
    D = pro_inst.D;

    % Define target file name (include ID for combinatorial)
    if isCombinatorial
        fileName = sprintf('HS-%s_ID%d_M%d_D%d_%d.mat', prob_name, ID_i, M_i, D, run_num);
    else
        fileName = sprintf('HS-%s_M%d_D%d_%d.mat', prob_name, M_i, D, run_num);
    end
    filePath = fullfile(sourceDirData, fileName);

    % Set a deterministic seed
    seed_string = sprintf('%s_%d_%d', prob_name, ID_i, run_num);
    seed_value = sum(double(seed_string));
    rng(seed_value, 'twister');

    % Generate the initial population
    if isCombinatorial
        heuristic_solutions = generateCombinatorialInit(prob_name, pro_inst, N);
    else
        temp_pro_inst = prob_handle('M', M_i);
        Population = temp_pro_inst.Initialization(N);
        heuristic_solutions = Population.decs;
    end

    result = struct(...
        'FileName', fileName, ...
        'FilePath', filePath, ...
        'Data', heuristic_solutions);

    fprintf('GENERATED: %s (Run %d)\n', prob_name, run_num);
end

function heuristic_solutions = generateCombinatorialInit(prob_name, pro_inst, N)
%GENERATECOMBINATORIALINIT Generate heuristic + random initial solutions.
%
%   Produces M+1 greedy solutions (one per axis + uniform weight) and pads
%   the remainder with random feasible solutions to fill N rows.

    M = pro_inst.M;
    D = pro_inst.D;

    % Weight vectors: axis-aligned + uniform
    weight_vectors = [eye(M); ones(1, M) / M];
    nGreedy = size(weight_vectors, 1);

    heuristic_solutions = zeros(max(N, nGreedy), D);

    switch prob_name
        case 'MOTSP'
            C = pro_inst.C;
            for i = 1:nGreedy
                [p, ~] = greedy_motsp(C, weight_vectors(i, :));
                heuristic_solutions(i, :) = p;
            end
            % Fill remaining with random permutations
            for i = (nGreedy + 1):N
                heuristic_solutions(i, :) = randperm(D);
            end

        case 'MOKP'
            P = pro_inst.P;
            W = pro_inst.W;
            for i = 1:nGreedy
                [x, ~] = greedy_mokp(P, W, weight_vectors(i, :));
                heuristic_solutions(i, :) = x;
            end
            % Fill remaining with random binary vectors (feasibility not guaranteed)
            for i = (nGreedy + 1):N
                heuristic_solutions(i, :) = randi([0, 1], 1, D);
            end

        otherwise
            warning('generateCombinatorialInit:unknownProblem', ...
                'No greedy solver for "%s"; using random initialization.', prob_name);
            Population = pro_inst.Initialization(N);
            heuristic_solutions = Population.decs;
            return;
    end

    heuristic_solutions = heuristic_solutions(1:N, :);
end
