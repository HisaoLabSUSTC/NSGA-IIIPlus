ph = @MOTSP;
M = 3; D = 30; ID = 1;
Problem = ph('M', M, 'D', D, 'parameter', {'ID', ID});

generateApproximatePF(ph, M, D, ID, 'algorithms', {@NSGAIIwH, {@MOEADwH, 1}}, 'N', 120, 'maxGenerations', 100, 'runs', 5, 'targetN', 3000);

refPF_file = sprintf('./Info/ReferencePF/RefPF-MOTSP_ID%d.mat', ID); data = load(refPF_file); PF = data.PF;
% refPF_file = sprintf('./Problems/Multi-objective optimization/Real-world MOPs/MOTSP_ID%d.mat', ID); data = load(refPF_file); PF = data.F;
heuristic_file = sprintf('./Info/InitialPopulation/HS-MOTSP_ID%d_M3_D30_1.mat', ID);


data = load(heuristic_file);
hs = data.heuristic_solutions;
hp = Problem.Evaluation(hs);
ho = hp.objs;



PreprocessProductionImage(0.4, 1, 8.8)
fig = gcf; ax = gca;
cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

plot3(ax,PF(:,1),PF(:,2),PF(:,3),'.k', 'MarkerSize', 25);
scatter3(ax,ho(:,1),ho(:,2),ho(:,3),'MarkerFaceColor', 'r', 'Marker', 'o', 'LineWidth', 1.5, 'SizeData', 25);

view(ax, 135, 30);