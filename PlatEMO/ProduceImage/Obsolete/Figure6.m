data_dir = './Problems/Multi-objective optimization/Real-world MOPs';
H_dir = './Info/HeuristicSolutions';

IDs = 2;
M=3;D=100;N=120;FE = N*2001;
save_interval = ceil(FE/N);


for ID=IDs
    filename = sprintf('MOTSP-M%d-D%d-%d.mat',M,D,ID);
    attributes = split(filename, '-'); problem_name = attributes{1};
    problem_handle = str2func(problem_name);
    pro = problem_handle('M', M, 'D', D, 'parameter', {0, ID, ''}); C = pro.C;
    Hfilename = sprintf('H-MOTSP-M%d-D%d-%d.mat',M,D,ID);
    % bruteforce_MOTSP(C, fullfile(E_dir,Efilename));

    algorithm = {{@PyNSGAIIIwH, fullfile(H_dir, Hfilename)}};

    % platemo('problem', problem_handle, 'M', M, 'D', D, 'parameter', {0, ID, ''}, 'N', 120, ...
    %     'maxFE', FE, 'algorithm', algorithm{1}, 'save', save_interval, 'run', ID)

    P_dir = sprintf('./Tentative', func2str(algorithm{1}{1}));
    P_file = sprintf('%s_%s_M%d_D%d_%d.mat', ...
        func2str(algorithm{1}{1}), class(pro), M,D,ID);
    P_data = load(fullfile(P_dir, P_file));
    n_gens = size(P_data.result, 1);

    PreprocessProductionImage(1/2, 1.2, 8.8);
    fig = gcf; ax = gca;

    gray_color = [0    0.4471    0.7412];
    drawnow;

    hP = [];
    ideal = [inf, inf, inf]; 
    
    figure(fig); 
    hP = scatter(ax, [], [], 1240/2, 'Marker', 'o', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'red', 'LineWidth', 1.5);
    hI = scatter(ax, ideal(1), ideal(2), 2480/2, 'Marker', 'diamond', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'green', 'LineWidth', 1.5);
    hY = line(ax, [0 60], [ideal(2) ideal(2)], 'Color', 'blue', 'LineStyle', '--', 'LineWidth', 4.0);
    hX = line(ax, [ideal(1) ideal(1)], [0 60], 'Color', 'blue', 'LineStyle', '--', 'LineWidth', 4.0);
    uistack(hX, 'bottom')
    uistack(hY, 'bottom')

    xlabel(ax, '$f_1$', 'Interpreter', 'latex');
    ylabel(ax, '$f_2$', 'Interpreter', 'latex');
   
    drawnow;

    set(ax.Title, 'String', '');
    % set(ax.)
    lims = [0 60];
    set(ax, 'XLim', lims);set(ax, 'YLim', lims);set(ax, 'ZLim', lims);
    ticks = 0:10:60;
    set(ax, 'XTick', ticks);set(ax, 'YTick', ticks);set(ax, 'ZTick', ticks);
    set(ax, 'Position', [0.16 0.18 0.77 0.79])
    % set(ax.Legend, 'Position', [0.02 0.073 0.9570 0.1093])
    set(ax, 'XTickLabelRotation', 0);
    set(ax, 'YTickLabelRotation', 0);
    set(ax.XLabel, 'Rotation', 0)
    set(ax.YLabel, 'Rotation', 0, 'Position', ax.YLabel.Position + [-3, -2.5, 0])
    
    % --- Loop for Animation ---
    for gen = 1:2000:n_gens
        P_pop = P_data.result{gen, 2};
        P_objs = P_pop.objs; % N x 3 matrix
        current_pop_size = size(P_objs, 1);

        current_min_f1f2f3 = min(P_objs, [], 1); % Find min across all population rows
        ideal = min(ideal, current_min_f1f2f3); % Update the historical minimum
        
        set(hP, 'XData', P_objs(:,1), 'YData', P_objs(:,2));
        set(hI, 'XData', ideal(1), 'YData', ideal(2));
        hY = line(ax, [0 60], [ideal(2) ideal(2)], 'Color', 'blue', 'LineStyle', '--', 'LineWidth', 4.0);
        hX = line(ax, [ideal(1) ideal(1)], [0 60], 'Color', 'blue', 'LineStyle', '--', 'LineWidth', 4.0);
        uistack(hX, 'bottom')
        uistack(hY, 'bottom')

        drawnow;
        pause(1);

        filename = sprintf('Py-NSGA-III-MOTSP-G%d.png', gen);
        exportgraphics(ancestor(ax, 'figure'), filename, 'Resolution', 300);
    end
    close(fig);
end


