ph = @MOTSP;
M = 3; D = 100; ID = 1; N = 120;
Problem = ph('M', M, 'D', D, 'parameter', {'ID', ID});
% 

refPF_file = sprintf('./Info/ReferencePF/RefPF-MOTSP_ID%d.mat', ID); data = load(refPF_file); PF = data.PF;
% refPF_file = sprintf('./Problems/Multi-objective optimization/Real-world MOPs/MOTSP_ID%d.mat', ID); data = load(refPF_file); PF = data.F;
heuristic_file = sprintf('./Info/InitialPopulation/HS-MOTSP_ID%d_M3_D%d_1.mat', ID, D);

data = load(heuristic_file);
hs = data.heuristic_solutions;
hp = Problem.Evaluation(hs);
ho = hp.objs;

% ah = @SPEA2wH;
ah = generateAlgorithm('area1', 'ZYX');
% algorithm_with_param = {ah, heuristic_file}
algorithm_with_param = ah; algorithm_with_param{end+1} = heuristic_file;

FE = 500 * 120;
platemo('problem', ph, 'N', N, 'M', M, 'D', D, ...
        'parameter', {'ID', ID}, ...
        'save', ceil(FE/N), 'maxFE', FE, ...
        'algorithm', algorithm_with_param, 'run', 1);


[fig, ax, hP] = initializePlot(PF, ho);


% algorithm_file = sprintf('./Data/%s/%s_MOTSP_M3_D30_ID2_1.mat', func2str(ah), func2str(ah));
an='ZYXNSGAIIIwH';algorithm_file = sprintf('./Data/%s/%s_MOTSP_M%d_D%d_ID%d_1.mat', an, an, M, D, ID);

result = load(algorithm_file).result;
n_gens = size(result, 1);

pause(1)
for gen = 1:10:n_gens
        pobjs = result{gen, 2}.objs;
        [fig, ax] = stepGen(fig, ax, pobjs, hP);
        pause(0.05);
end


function [fig, ax, hP] = initializePlot(PF, ho)
    PreprocessProductionImage(0.4, 1, 8.8)
    fig = gcf; ax = gca;
    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    hHS = ho(1:4, :);
    hIP = ho(5:end, :);
    % hPF = plot3(ax,PF(:,1),PF(:,2),PF(:,3),'.k', 'MarkerSize', 25);
    hIP = scatter3(ax,hIP(:,1),hIP(:,2),hIP(:,3),'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k', 'Marker', 'o', 'LineWidth', 1.5, 'SizeData', 55);
    hHS = scatter3(ax,hHS(:,1),hHS(:,2),hHS(:,3),'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'r', 'Marker', '*', 'LineWidth', 4.5, 'SizeData', 255);
    
    hP = scatter3(ax, [], [], [], 'SizeData', 200, 'Marker', 'o', 'MarkerFaceColor', 'green', 'LineWidth', 1.5);

    view(ax, 245, 20);
end

function [fig, ax] = stepGen(fig, ax, pobjs, hP)
    set(hP, 'XData', pobjs(:,1), 'YData', pobjs(:,2), 'ZData', pobjs(:, 3));
    drawnow;
end