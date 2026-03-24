% clear; clc; close all;

%% Task 2: Run algorithms
fprintf('Task 2: Collecting data...\n');

algorithms = {@MeNSGAIIIwH, @OrmeNSGAIIIwH};
problems = {@BT9, @DTLZ4, @DTLZ5, @DTLZ6, @DTLZ7, ...
    @IDTLZ1, @IDTLZ2, @IMOP4, @IMOP5, @IMOP6, @IMOP7, @IMOP8, ...
    @MaF1,@MaF2,@MaF4,@MaF5,@MaF13,@MaF14,@MaF15,...
    @MinusDTLZ1, @MinusWFG1, @RWA2, @RWA3, @RWA4, @RWA5, @RWA6, @RWA7,...
    @UF8, @UF9, @UF10, @VNT1, @VNT2, @VNT3, @WFG1, @WFG2, @WFG8};

FE = 200000;
N = 120;
M = 3;
save_interval = ceil(FE/N);
runs = 101;

%% Generate initial populations
generateInitialPopulations(problems, N, M, runs);

% Create all combinations
[P, A, R] = ndgrid(1:length(problems), 1:length(algorithms), 1:runs);
combinations = [P(:), A(:), R(:)];
total_tasks = size(combinations, 1);

% Start parallel pool if not already started
% delete(gcp('nocreate'))


fprintf('Starting %d parallel tasks...\n', total_tasks);

% Initialize error tracking
error_count = 0;
success_count = 0;
error_log = {};

tic;

% Run in parallel with error handling
parfor idx = 1:total_tasks
    prob_idx = combinations(idx, 1);
    algo_idx = combinations(idx, 2);
    run_num = combinations(idx, 3);

    % Get names for error reporting
    prob_name = func2str(problems{prob_idx});
    algo_name = func2str(algorithms{algo_idx});

    
        % Execute PlatEMO
        pro_inst = problems{prob_idx}('M', M);

        % --- New logic to construct heuristic file path ---
        initial_pop_path = fullfile('Info', 'InitialPopulation', ...
            sprintf('HS-%s_M%d_D%d_%d.mat', prob_name, pro_inst.M, pro_inst.D, run_num))
        % --------------------------------------------------
        prev_folder = fullfile('Data',algo_name);
        prev_file   = fullfile(prev_folder,sprintf( ...
            '%s_%s_M%d_D%d_%d.mat',algo_name,prob_name,pro_inst.M,pro_inst.D,run_num));

        if isfile(prev_file)
            continue
        else
            % We must pass the algorithm handle and the path as a cell array:
            % {@AlgorithmHandle, Parameter1, Parameter2, ...}

            % Check if the algorithm is your custom 'wH' variant
            if contains(algo_name, 'wH')
                % Pass the file path as a parameter
                algorithm_with_param = {algorithms{algo_idx}, initial_pop_path}
            else
                % Use the original algorithm handle without parameters
                algorithm_with_param = algorithms{algo_idx};
                warning('MATLAB:PlatEMO', 'Algorithm %s does not use heuristic initial population.', algo_name);
            end

            platemo('problem', problems{prob_idx}, 'N', N, 'M', M, ...
                'save', save_interval, 'maxFE', FE, ...
                'algorithm', algorithm_with_param, 'run', run_num);
        end


        fprintf('Completed: %s with %s (Run %d)\n', prob_name, algo_name, run_num);

    % catch ME
    %     % Handle errors gracefully
    %     error_msg = sprintf('ERROR: %s with %s (Run %d) - %s', ...
    %                        prob_name, algo_name, run_num, ME.message);
    % 
    %     % Display error but continue
    %     fprintf(2, '%s\n', error_msg);  % fprintf to stderr (shows in red in MATLAB)
    % 
    %     % Store error information for summary
    %     % Note: We can't directly modify shared variables in parfor
    %     % So we'll collect errors and process them after
    % end
end

elapsed = toc;

% Post-processing to count successes and errors
% Check which files were actually created
fprintf('\nTask 2 completed in %.2f seconds\n', elapsed);
fprintf('Checking results...\n');

% Count successful runs by checking created files
dataDir = fullfile('Data');
subdirs = dir(dataDir);
subdirs = subdirs([subdirs.isdir]);
subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));

total_files = 0;
for i = 1:length(subdirs)
    subdirPath = fullfile(dataDir, subdirs(i).name);
    matFiles = dir(fullfile(subdirPath, '*.mat'));
    total_files = total_files + length(matFiles);
end

expected_files = total_tasks;
failed_tasks = expected_files - total_files;

fprintf('\nSummary:\n');
fprintf('- Total tasks: %d\n', total_tasks);
fprintf('- Successful: %d\n', total_files);
fprintf('- Failed: %d (%.1f%%)\n', failed_tasks, 100*failed_tasks/total_tasks);
fprintf('Relevant data is stored.\n\n');


%% Task 3: Precompute hypervolume and CV
% dataDir = fullfile('./Info/NichedSolutions');
% hvDataDir = fullfile('./Info/NichedHV');
% dataDir = fullfile('./Data');
% igdDataDir = fullfile('./IGDData');
% hvDataDir = fullfile('./HVData');
% 
% phs = {@MinusWFG1,@MinusWFG2,@MinusWFG3,@MinusWFG4,@MinusWFG5,@MinusWFG6,@MinusWFG7,@MinusWFG8,@MinusWFG9,...
%     @VNT1, @VNT2, @VNT3,...
%     @WFG1,@WFG2,@WFG3,@WFG4,@WFG5,@WFG6,@WFG7,@WFG8,@WFG9,@ZDT1,@ZDT2,@ZDT3,@ZDT4,@ZDT6, ...
%     @BT1, @BT2, @BT3, @BT4, @BT5, @BT6, @BT7, @BT8, @BT9, ...
%     @DTLZ1, @DTLZ2, @DTLZ3, @DTLZ4, @DTLZ5, @DTLZ6, @DTLZ7, @IDTLZ1, @IDTLZ2, ...
%     @SDTLZ1, @SDTLZ2, @IMOP1, @IMOP2, @IMOP3, @IMOP4, @IMOP5, @IMOP6, @IMOP7, @IMOP8, ...
%     @MaF1,@MaF2,@MaF3,@MaF4,@MaF5,@MaF13,@MaF14,@MaF15,...
%     @RWA1,@RWA2,@RWA3,@RWA4,@RWA5,@RWA6,@RWA7,...
%     @UF1,@UF2,@UF3,@UF4,@UF5,@UF6,@UF7,@UF8,@UF9,@UF10,...
%     @MinusDTLZ1,@MinusDTLZ2,@MinusDTLZ3,@MinusDTLZ4,@MinusDTLZ5,@MinusDTLZ6};
% pns = string(cellfun(@func2str, phs, 'UniformOutput', false));
% 
% ComputeHVfromData(dataDir, igdDataDir, pns, 'igd');

%% Task 4: Visualize hypervolume using interactive tool with Export functionality
% HVCVGUI(hvDataDir)