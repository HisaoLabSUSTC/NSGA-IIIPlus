
idx = 1;

ph = @RWA3;
py_dataDir = './Info/IdealNadirHistory/PyNSGAIIIwH';
pl_dataDir = './Info/IdealNadirHistory/NSGAIIIwH';
py_fileName = sprintf('IN-PyNSGAIIIwH-%s.mat', func2str(ph));
pl_fileName = sprintf('IN-NSGAIIIwH-%s.mat', func2str(ph));
py_fileData = load(fullfile(py_dataDir,py_fileName));
pl_fileData = load(fullfile(pl_dataDir,pl_fileName));

py_idealHistories = py_fileData.ideal_history;
pl_idealHistories = pl_fileData.ideal_history;
py_nadirHistories = py_fileData.nadir_history;
pl_nadirHistories = pl_fileData.nadir_history;

Problem = ph();
PF = Problem.GetOptimum(1000);
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
                    'NSGAIIIwH', func2str(ph), idx);


PublishColumns(test_history, result.stable_gen_max_rel, savePath, 'pl');

%% pymoo
test_history = norm_py_nadirHistories{idx};
result = detect_tail_stability(test_history, ...
        'max_abs', 1e-3, ...
        'rel_max', 1e-6, ...
        'min_tail_len', 30);
savePath = sprintf('./Info/TemporalDispersionPlot/TD-%s-%s-%d.png', ...
                    'PyNSGAIIIwH', func2str(ph), idx);
PublishColumns(test_history, result.stable_gen_max_rel, savePath, 'py');
return


function PublishColumns(test_history, stable_gen, savePath, mode)
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
    % fig = figure('Name', fileName, 'Position', [100, 50, 1200, 950]);

    lineConfig = ['b-', 'r-', 'g-'];
    for i = 1:M
        PreprocessProductionImage(1/2, 0.4, 8.8);
        fig = gcf; ax = gca;
        hold on 
        plot(x_axis, test_history(:,i), lineConfig(i), 'LineWidth', 4.5);
        xline(stable_gen, 'k--', 'LineWidth', 6)
        hold off
        if i == M
            xlabel('Generations', 'Interpreter', 'latex'); xlim([1, N]);
        end
        ylabel(sprintf('$\\tilde{z}_%d$', i), 'Interpreter', 'latex');
        grid on;

        %% Customize plot
        set(ax.Title, 'String', '');
        set(ax, 'XLim', [1, 1667]); set(ax, 'XTick', [1, 501, 1001, 1501])
        
        if strcmp(mode, 'pl')
            if i == 1
                set(ax, 'YLim', [0.8 2.0])
                set(ax, 'YTick', [0.8 1.4 2.0])
            elseif i == 2
                set(ax, 'YLim', [0.8 2.0])
                set(ax, 'YTick', [0.8 1.4 2.0])
            elseif i == 3
                set(ax, 'YLim', [0.8 2.0])
                set(ax, 'YTick', [0.8 1.4 2.0])
            end
        elseif strcmp(mode, 'py')
            if i == 1
                set(ax, 'YLim', [0.8 2.0])
                set(ax, 'YTick', [0.8 1.4 2.0])
            elseif i == 2
                set(ax, 'YLim', [0.8 2.0])
                set(ax, 'YTick', [0.8 1.4 2.0])
            elseif i == 3
                set(ax, 'YLim', [0.8 2.0])
                set(ax, 'YTick', [0.8 1.4 2.0])
            end
        end
        
        set(ax, 'Position', [0.18 0.39 0.8 0.55])
        set(ax.Legend, 'Position', [0.02 0.05 0.9570 0.1093])
        % set(ax.Title, 'FontWeight','normal')
        set(ax, 'XTickLabelRotation', 0);
        set(ax, 'YTickLabelRotation', 0);

        set(ax.XLabel, 'Rotation', 0, 'Position', [833, ax.YLim(1)-0.37*(ax.YLim(2)-ax.YLim(1)), 0.0])
        set(ax.YLabel, 'Rotation', 0, 'Position', [-280, ax.YLim(1)+0.28*(ax.YLim(2)-ax.YLim(1)), 0.0])
        savePath(end-4) = int2str(i);
        
        exportgraphics(ancestor(ax, 'figure'), savePath, 'Resolution', 300);
        close(fig)
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
    
    % sgtitle(sprintf('Normalized nadir point estimation of %s on %s\n(Run %d of 101)', ...
    %         algName, proName, str2num(idx)));
        
    % EnlargeFont(fig);

    % saveas(fig, savePath);
    % close(fig); 
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
