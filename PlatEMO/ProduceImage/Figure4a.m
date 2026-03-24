%% Figure 4: Nadir point estimation trajectory smoothness test

% close all; clc;

%% ---- Colours ----
cPop     = [0.85  0.15  0.15];   % population (all red)
cEst     = [0.85  0.55  0.15];   % estimated points (orange)
cTrue    = [0.13  0.55  0.20];   % true points (green)
cPF      = [0.00  0.00  0.00];   % Pareto front

%% ---- Sizing constants ----
S  = 8.8;                   % scale factor (matches PreprocessProductionImage)
fs = 6.5 * S;               % annotation font size
ms_pop     = 300;            % population marker area (scatter)
ms_special = 1500;            % special point marker area (scatter)
lms = 26;                    % legend marker size (plot-based, controls icon size)
lw_pf     = 8;               % Pareto front line width
lw_conn   = 5;               % connection lines (dotted)
lw_edge   = 1.5;             % marker edge width

%% ---- Data ----
ah = {generateAlgorithm('area1', '')};
% ah = {generateAlgorithm('momentum', 'tikhonov')};
ph = @RWA2;
params = struct(...
    'FE',   1000 * 120, ...   % Max function evaluations
    'N',    120, ...      % Population size
    'M',    3, ...        % Number of objectives
    'runs', 1 ...         % Independent runs
);

FE = getFieldDefault(params, 'FE', 10000);
N = getFieldDefault(params, 'N', 120);
M = getFieldDefault(params, 'M', 3);
% runs = getFieldDefault(params, 'runs', 1); 
run_num = 1; runs = run_num;
save_interval = ceil(FE / N);
% save_interval = 0;
generateInitialPopulations({ph}, N, M, runs);
pro_inst = ph('M', M); prob_name = func2str(ph);
initial_pop_path = fullfile('Info', 'InitialPopulation', ...
    sprintf('HS-%s_M%d_D%d_%d.mat', prob_name, pro_inst.M, pro_inst.D, run_num));
algorithmSpec = ah{1};
algorithm_with_param = prepareAlgorithmForPlatemo(algorithmSpec, initial_pop_path);
% platemo('problem', ph, 'N', N, 'M', M, ...
%                 'save', save_interval, 'maxFE', FE, ...
%                 'algorithm', algorithm_with_param, 'run', run_num);
% 
% phs = {ph};
% 
% GenerateIdealNadirHistoriesMethod(ah, phs, M);
idx = 1;

variant_name = '';
% variant_name = 'Tk';
variant_dataDir = sprintf('./Info/IdealNadirHistory/%sNSGAIIIwH', variant_name);
variant_fileName = sprintf('IN-%sNSGAIIIwH-%s.mat', variant_name, func2str(ph));
variant_fileData = load(fullfile(variant_dataDir,variant_fileName));
    
pl_nadirHistories = variant_fileData.nadir_history;

[PF, gt_ideal, gt_nadir] = loadReferencePF(func2str(ph));

norm_variant_nadirHistories = cellfun(@(c) ...
    (c-gt_ideal+eps)./(gt_nadir-gt_ideal+eps), ...
    pl_nadirHistories, 'UniformOutput', false);

test_history = norm_variant_nadirHistories{idx};
result = detect_tail_stability(test_history, ...
        'max_abs', 1e-3, ...
        'rel_max', 1e-6, ...
        'min_tail_len', 30);
savePath = sprintf('./Info/TemporalDispersionPlot/TD-%s-%s-%d.png', ...
                    variant_name, func2str(ph), idx);
PreprocessProductionImage(1, 2, 8.8);
plotColumns(test_history, result.stable_gen_max_rel, savePath);

%% ---- Post-process subplots ----
fig = gcf;
axs = findobj(fig, 'Type', 'axes');
axs = flip(axs);  % order top-to-bottom: axs(1)=subplot1, axs(2)=subplot2, axs(3)=subplot3

S_fig = 8.8;
fs = 7 * S_fig;  % match PreprocessProductionImage font size

% Objective labels for y-axes
objLabels = {"$\hat{f}_1$", "$\hat{f}_2$", "$\hat{f}_3$"};

for k = 1:numel(axs)
    % 1. Remove subplot titles
    title(axs(k), '');

    % 3. Set y-label to f_k
    ylabel(axs(k), objLabels{k}, 'Interpreter', 'latex', ...
        'FontSize', fs, 'Rotation', 0, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');

    % 2. Remove x-label and tick labels from all but the bottom subplot
    if k < numel(axs)
        xlabel(axs(k), '');
        set(axs(k), 'XTickLabel', {});
    else
        xlabel(axs(k), '$t$', 'Interpreter', 'latex', 'FontSize', fs, 'VerticalAlignment', 'middle');
    end


    if k == 1
        set(axs(k), 'YTick', ...
            [0.8, 1.0], 'YTickLabel', ...
            {'0.8', '1.0'});
    end
    if k == 2
        set(axs(k), 'YTick', ...
            [0.5, 1.0], 'YTickLabel', ...
            {'0.5', '1.0'});
    end
    if k == 3
        set(axs(k), 'YTick', ...
            [0.8, 1.0], 'YTickLabel', ...
            {'0.8', '1.0'});
    end

    % Ensure t=0 is visible and ticked
    xl = get(axs(k), 'XLim');
    set(axs(k), 'XLim', [0, xl(2)]);
    xt = get(axs(k), 'XTick');
    if isempty(xt) || xt(1) ~= 0
        set(axs(k), 'XTick', [0, xt]);
    end
end

% Remove sgtitle
sgtitle('');

% Equalize subplot sizes and stack closely
nAx = numel(axs);
gap = 0.06;          % vertical gap between subplots
margin_bot = 0.16;   % bottom margin (room for x-label)
margin_top = 0.03;   % top margin
margin_left = 0.16;  % left margin
margin_right = 0.04; % right margin
total_h = 1 - margin_bot - margin_top - gap * (nAx - 1);
ax_h = total_h / nAx;
ax_w = 1 - margin_left - margin_right;

for k = 1:nAx
    y_pos = margin_bot + (nAx - k) * (ax_h + gap);
    set(axs(k), 'Position', [margin_left, y_pos, ax_w, ax_h]);
end

%% ---- Export ----
exportgraphics(fig, './ProduceImage/Images/Figure4a.png', 'Resolution', 300);
close(fig);














function val = getFieldDefault(s, field, default)
    if isfield(s, field)
        val = s.(field);
    else
        val = default;
    end
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
    fig = gcf;

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
        plot(x_axis, test_history(:,1), 'b-', 'LineWidth', 3.5);
        xline(stable_gen, 'k--', 'LineWidth', 2.5)
        hold off
        title('Objective 1');
        xlabel('$t$', 'Interpreter','latex'); xlim([1, N]);
        ylabel('Value');
        grid on;
    
        subplot(3,1,2);
        hold on
        plot(x_axis, test_history(:,2), 'r-', 'LineWidth', 3.5);
        xline(stable_gen, 'k--', 'LineWidth', 2.5)
        hold off
        title('Objective 2');
        xlabel('$t$', 'Interpreter','latex'); xlim([1, N]);
        ylabel('Value');
        grid on;
    
        subplot(3,1,3);
        hold on
        plot(x_axis, test_history(:,3), 'g-', 'LineWidth', 3.5);
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