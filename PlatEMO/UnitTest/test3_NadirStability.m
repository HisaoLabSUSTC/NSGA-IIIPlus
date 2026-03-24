ph = @MOTSP;
M = 3; D = 30; ID = 2; N = 120;
Problem = ph('M', M, 'D', D, 'parameter', {'ID', ID});

heuristic_file = sprintf('./Info/InitialPopulation/HS-MOTSP_ID%d_M3_D30_1.mat', ID);
% ah = @SPEA2wH; algorithm_with_param = {ah, heuristic_file}
ah = generateAlgorithm('area1', 'ZYX', 'momentum', 'tikhonov', 'useDSS', true); 
algorithm_with_param = ah;
algorithm_with_param{end+1} = heuristic_file;

FE = 500 * 120;
platemo('problem', ph, 'N', N, 'M', M, 'D', D, ...
        'parameter', {'ID', ID}, ...
        'save', ceil(FE/N), 'maxFE', FE, ...
        'algorithm', algorithm_with_param, 'run', 1);

% algorithm_file = sprintf('./Data/%s/%s_MOTSP_M3_D30_ID2_1.mat', func2str(ah), func2str(ah));
an='ZYXTkDssNSGAIIIwH';algorithm_file = sprintf('./Data/%s/%s_MOTSP_M3_D30_ID%d_1.mat', an, an, ID);

result = load(algorithm_file).result;
n_gens = size(result, 1);
NormStruct = alg2norm(an, N, M);
SS = initializeStabilityStruct(M, n_gens);

Population = result{1, 2};
nds = nds_preprocess(Population);
norm_update(an, Problem, NormStruct, Population, nds);
SS.ideal_point_history(1, :) = NormStruct.ideal_point;
SS.nadir_point_history(1, :) = NormStruct.nadir_point;
SS.FE_history(1) = result{1, 1};

% Subsequent generations
for g = 2:n_gens
    Population = result{g-1, 2};
    Offspring = result{g, 3};
    Mixture = [Population, Offspring];
    nds = nds_preprocess(Mixture);
    norm_update(an, Problem, NormStruct, Mixture, nds);

    SS.ideal_point_history(g, :) = NormStruct.ideal_point;
    SS.nadir_point_history(g, :) = NormStruct.nadir_point;
    SS.FE_history(g) = result{g, 1};
end

ideal_history = {SS.ideal_point_history};
nadir_history = {SS.nadir_point_history};

refPF_file = sprintf('./Info/ReferencePF/RefPF-MOTSP_ID%d.mat', ID); data = load(refPF_file); PF = data.PF;
gt_ideal = min(PF);
gt_nadir = max(PF);
norm_nadirHistory = cellfun(@(c) (c-gt_ideal+eps)./(gt_nadir-gt_ideal+eps), ...
        nadir_history, 'UniformOutput', false);
norm_idealHistory = cellfun(@(c) (c-gt_ideal+eps)./(gt_nadir-gt_ideal+eps), ...
        ideal_history, 'UniformOutput', false);

savePath = sprintf('./Info/TemporalDispersionPlot/TD-%s-%s-%d.png', ...
                        an, func2str(ph), 1);

plotColumns(norm_nadirHistory{1}, NaN, savePath);




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

    % saveas(fig, savePath);
    % close(fig); 
end