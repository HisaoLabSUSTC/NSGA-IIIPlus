% problems = {@MinusWFG1,@MinusWFG2,@MinusWFG3,@MinusWFG4,@MinusWFG5,@MinusWFG6,@MinusWFG7,@MinusWFG8,@MinusWFG9,...
%     @RWA1,@RWA2,@RWA3,@RWA4,@RWA5,@RWA6,@RWA7, @VNT1, @VNT2, @VNT3,...
%     @WFG1,@WFG2,@WFG3,@WFG4,@WFG5,@WFG6,@WFG7,@WFG8,@WFG9,@ZDT1,@ZDT2,@ZDT3,@ZDT4,@ZDT6, ...
%     @BT1, @BT2, @BT3, @BT4, @BT5, @BT6, @BT7, @BT8, @BT9, ...
%     @DTLZ1, @DTLZ2, @DTLZ3, @DTLZ4, @DTLZ5, @DTLZ6, @DTLZ7, @IDTLZ1, @IDTLZ2, ...
%     @SDTLZ1, @SDTLZ2, @IMOP1, @IMOP2, @IMOP3, @IMOP4, @IMOP5, @IMOP6, @IMOP7, @IMOP8, ...
%     @MaF1,@MaF2,@MaF3,@MaF4,@MaF5,@MaF6,@MaF7,@MaF10,@MaF11,@MaF12,@MaF13,@MaF14,@MaF15,...
%     @MinusDTLZ1,@MinusDTLZ2,@MinusDTLZ3,@MinusDTLZ4,@MinusDTLZ5,@MinusDTLZ6};
problems = {@IDTLZ2}; 

idx = 1;
for pi = 1:numel(problems)
    % if ~strcmp(func2str(problems{pi}), 'RWA3')
    %     continue
    % end
    ph = problems{pi};
    py_dataDir = './Info/IdealNadirHistory/PyNSGAIIIwH';
    pl_name = '';
    pl_dataDir = sprintf('./Info/IdealNadirHistory/Py%sNSGAIIIwH', pl_name);
    py_fileName = sprintf('IN-PyNSGAIIIwH-%s.mat', func2str(ph));
    pl_fileName = sprintf('IN-Py%sNSGAIIIwH-%s.mat', pl_name, func2str(ph));
    py_fileData = load(fullfile(py_dataDir,py_fileName));
    pl_fileData = load(fullfile(pl_dataDir,pl_fileName));
    
    py_idealHistories = py_fileData.ideal_history;
    pl_idealHistories = pl_fileData.ideal_history;
    py_nadirHistories = py_fileData.nadir_history;
    pl_nadirHistories = pl_fileData.nadir_history;
    
    Problem = ph();
    PF = Problem.GetOptimum(3000);
    gt_ideal = min(PF);
    gt_nadir = max(PF);
    
    norm_py_idealHistories = cellfun(@(c) (c-gt_ideal+eps)./(gt_nadir-gt_ideal+eps), ...
        py_idealHistories, 'UniformOutput', false);
    norm_pl_idealHistories = cellfun(@(c) (c-gt_ideal+eps)./(gt_nadir-gt_ideal+eps), ...
        pl_idealHistories, 'UniformOutput', false);
    norm_py_nadirHistories = cellfun(@(c) (c-gt_ideal+eps)./(gt_nadir-gt_ideal+eps), ...
        py_nadirHistories, 'UniformOutput', false);
    norm_pl_nadirHistories = cellfun(@(c) (c-gt_ideal+eps)./(gt_nadir-gt_ideal+eps), ...
        pl_nadirHistories, 'UniformOutput', false);

    %% PlatEMO
    test_history = norm_pl_nadirHistories{idx};
    result = detect_tail_stability(test_history, ...
            'max_abs', 1e-3, ...
            'rel_max', 1e-6, ...
            'min_tail_len', 30);
    savePath = sprintf('./Info/TemporalDispersionPlot/TD-%s-%s-%d.png', ...
                        pl_name, func2str(ph), idx);
    plotColumns(test_history, result.stable_gen_max_rel, savePath);

    %% pymoo
    % test_history = norm_py_nadirHistories{idx};
    % result = detect_tail_stability(test_history, ...
    %         'max_abs', 1e-3, ...
    %         'rel_max', 1e-6, ...
    %         'min_tail_len', 30);
    % savePath = sprintf('./Info/TemporalDispersionPlot/TD-%s-%s-%d.png', ...
    %                     'PyNSGAIIIwH', func2str(ph), idx);
    % plotColumns(test_history, result.stable_gen_max_rel, savePath);
    % return
end

function plotColumns(test_history, stable_gen, savePath)
    [N, M] = size(test_history); % Get matrix size

    [dirName, fileName, ext] = fileparts(savePath); mkdir(dirName);
    nameParts = split(fileName, '-');
    algName = nameParts{2};
    proName = nameParts{3};
    idx = nameParts{4};

    % --- Validate input ---
    if M < 2
        error('The input matrix must have at least 2 columns.');
    end
    
    x_axis = 1:N; % X-axis for rows
    
    % --- Create figure ---
    fig = figure('Name', fileName, 'Position', [100, 50, 1200, 950]);

    % --- CASE 1: If M == 2: Use 2 subplots ---
    if M == 2
        % Subplot 1
        subplot(2,1,1);
        hold on 
        plot(x_axis, test_history(:,1), 'b-', 'LineWidth', 1.5);
        xline(stable_gen, 'k--', 'LineWidth', 2.5)
        hold off
        title('Objective 1');
        xlabel('$t$', 'Interpreter','latex'); xlim([1, N]);
        ylabel('Value');
        grid on;

        % Subplot 2
        subplot(2,1,2);
        hold on
        plot(x_axis, test_history(:,2), 'r-', 'LineWidth', 1.5);
        xline(stable_gen, 'k--', 'LineWidth', 2.5)
        hold off
        title('Objective 2');
        xlabel('$t$', 'Interpreter','latex'); xlim([1, N]);
        ylabel('Value');
        grid on;

    else

        % --- CASE 2: M >= 3: Use 3 subplots (first three columns only) ---
        subplot(3,1,1);
        hold on
        plot(x_axis, test_history(:,1), 'b-', 'LineWidth', 1.5);
        xline(stable_gen, 'k--', 'LineWidth', 2.5)
        hold off
        title('Objective 1');
        xlabel('$t$', 'Interpreter','latex'); xlim([1, N]);
        ylabel('Value');
        grid on;
    
        subplot(3,1,2);
        hold on
        plot(x_axis, test_history(:,2), 'r-', 'LineWidth', 1.5);
        xline(stable_gen, 'k--', 'LineWidth', 2.5)
        hold off
        title('Objective 2');
        xlabel('$t$', 'Interpreter','latex'); xlim([1, N]);
        ylabel('Value');
        grid on;
    
        subplot(3,1,3);
        hold on
        plot(x_axis, test_history(:,3), 'g-', 'LineWidth', 1.5);
        xline(stable_gen, 'k--', 'LineWidth', 2.5)
        hold off
        title('Objective 3');
        xlabel('$t$', 'Interpreter','latex'); xlim([1, N]);
        ylabel('Value');
        grid on;
    
    end

    if strcmp(algName, 'PyNSGAIIIwH')
        algName = 'Py-NSGA-III';
    elseif strcmp(algName, 'NSGAIIIwH')
        algName = 'Pl-NSGA-III';
    end

    if strcmp(proName, 'MinusDTLZ1')
        proName = 'Minus-DTLZ1';
    end

    disp(stable_gen)
    
    sgtitle(sprintf('Normalized nadir point estimation of %s on %s\n(Run %d of 101)', ...
            algName, proName, str2num(idx)));
        
    % EnlargeFont(fig);

    saveas(fig, savePath);
    close(fig); 
end


function result = detect_tail_stability(trajectory, varargin)
% detect_tail_stability - Detect temporal stability using tail RMS deviation
%                         and tail Max-Deviation (outlier-sensitive).
%
% INPUT:
%   trajectory : [T x M] matrix, each row is point at generation t
%
% PARAMS (name-value pairs, all optional):
%   'max_abs'      : absolute threshold on max_tail                  (default: [])
%   'rel_max'      : relative threshold as fraction of max_tail(1)   (default: [])
%   'min_tail_len' : minimum tail length to consider stable          (default: 50)
%
% OUTPUT (struct):
%   result.max_tail          : [T x 1] tail Max-Deviation for each start t
%
%   Max-dev-based stability:
%       result.stable_gen_max_abs: earliest stable gen (absolute max-dev) or NaN
%       result.is_stable_max_abs : logical
%       result.stable_gen_max_rel: earliest stable gen (relative max-dev) or NaN
%       result.is_stable_max_rel : logical

    % ---- Parse inputs ----
    p = inputParser;
    p.addParameter('max_abs',      [], @(x) isempty(x) || isscalar(x));
    p.addParameter('rel_max',      [], @(x) isempty(x) || (isscalar(x) && x > 0));
    p.addParameter('min_tail_len', 50, @(x) isscalar(x) && x >= 1);
    p.parse(varargin{:});

    max_abs      = p.Results.max_abs;
    rel_max      = p.Results.rel_max;
    min_tail_len = p.Results.min_tail_len;

    [T, M] = size(trajectory);

    if min_tail_len > T
        error('min_tail_len (%d) cannot exceed trajectory length T=%d.', ...
              min_tail_len, T);
    end

    X = trajectory;

    % ---- Precompute cumulative sums from the end (for O(T*M) RMS computation) ----
    cs1 = zeros(T, M);  % cumulative sum of x from t..T
    cs2 = zeros(T, M);  % cumulative sum of x.^2 from t..T

    cs1(T, :) = X(T, :);
    cs2(T, :) = X(T, :).^2;
    for t = T-1:-1:1
        cs1(t, :) = cs1(t+1, :) + X(t, :);
        cs2(t, :) = cs2(t+1, :) + X(t, :).^2;
    end

    % ---- Compute sigma_tail(t) and max_tail(t) for all t ----
    max_tail   = zeros(T, 1);

    for t = 1:T
        n = T - t + 1;

        % Tail Max-Deviation (outlier-sensitive)
        mu   = cs1(t, :) / n;     % [1 x M]
        vals = X(t:T, :);                % [n x M]
        diffs = vals - mu;               % [n x M]
        d = vecnorm(diffs, 2, 2);        % [n x 1], Euclidean distance to mu
        %% Maybe use Chebyshev distance?
        max_tail(t) = max(d);            % max distance in this tail
    end

    % Common mask: only tails with at least min_tail_len samples
    max_start = T - min_tail_len + 1;
    tail_mask = (1:T)' <= max_start;

    % ---- Max-Deviation: Absolute threshold detection ----
    % stable_gen_max_abs = NaN;
    % is_stable_max_abs  = false;
    % 
    % if ~isempty(max_abs)
    %     idx_max = find(max_tail <= max_abs & tail_mask, 1, 'first');
    %     if ~isempty(idx_max)
    %         stable_gen_max_abs = idx_max;
    %         is_stable_max_abs  = true;
    %     end
    % end

    % ---- Max-Deviation: Relative threshold detection ----
    stable_gen_max_rel = NaN;
    is_stable_max_rel  = false;

    if ~isempty(rel_max)
        max0 = max_tail(1); % max deviation over full trajectory

        if max0 <= max_abs
            stable_gen_max_rel = 1;
            is_stable_max_rel  = true;
        else
            thresh_max_rel = max(rel_max * max0, max_abs);
            idx_max_rel = find(max_tail <= thresh_max_rel & tail_mask, 1, 'first');
            if ~isempty(idx_max_rel)
                stable_gen_max_rel = idx_max_rel;
                is_stable_max_rel  = true;
            end
        end
    end

    % ---- Pack results ----
    result.max_tail            = max_tail;

    % result.stable_gen_max_abs  = stable_gen_max_abs;
    % result.is_stable_max_abs   = is_stable_max_abs;
    result.stable_gen_max_rel  = stable_gen_max_rel;
    result.is_stable_max_rel   = is_stable_max_rel;
end
