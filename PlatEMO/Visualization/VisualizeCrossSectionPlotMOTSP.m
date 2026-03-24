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

    % algorithm = {{@NSGAIIIwH, fullfile(H_dir, Hfilename)}};
    algorithm = {{@PyNSGAIIIwH, fullfile(H_dir, Hfilename)}};
    % algorithm = {{@SMSEMOAwH, fullfile(H_dir, Hfilename)}};

    % platemo('problem', problem_handle, 'M', M, 'D', D, 'parameter', {0, ID, ''}, 'N', 120, ...
    %     'maxFE', FE, 'algorithm', algorithm{1}, 'save', save_interval, 'run', ID)


    P_dir = sprintf('./Data/%s', func2str(algorithm{1}{1}));
    P_file = sprintf('%s_%s_M%d_D%d_%d.mat', ...
        func2str(algorithm{1}{1}), class(pro), M,D,ID);
    P_data = load(fullfile(P_dir, P_file));
    n_gens = size(P_data.result, 1);

    fig = figure('Position', [50, 20, 1200, 960], ...
                 'Name', 'Mindist Visualization', 'Visible', 'on');
    ax = axes; hold(ax, 'on'); 
    gray_color = [0    0.4471    0.7412];
    drawnow;
    vid_name = sprintf('XY_%s_M%d_D%d_%d.mp4', func2str(algorithm{1}{1}), M, D, ID);
    % v = VideoWriter(vid_name, 'MPEG-4');
    % v.FrameRate = 120;
    % open(v);
    hP = [];
    ideal = [inf, inf, inf]; 
    
    figure(fig); 
    hP = scatter(ax, [], [], 160, 'Marker', 'o', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'red', 'LineWidth', 0.5);
    hI = scatter(ax, ideal(1), ideal(2), 200, 'Marker', 'square', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'blue', 'LineWidth', 0.5);
    hY = yline(ax, ideal(2), 'blue', 'LineStyle', '--', 'LineWidth', 4.0);
    hX = xline(ax, ideal(1), 'blue', 'LineStyle', '--', 'LineWidth', 4.0);

    title(ax, sprintf('XY-plane of MOTSP with M=%d, D=%d, N=%%d', M, D, 0));
    xlabel(ax, '$x$', 'Interpreter', 'latex');
    ylabel(ax, '$y$', 'Interpreter', 'latex');
    xlim(ax, [0 60]);
    ylim(ax, [0 60]);
    xticks(ax, 0:10:60);
    yticks(ax, 0:10:60);
    EnlargeFont(fig);
    drawnow;
    
    % --- Loop for Animation ---
    for gen = 1:2000:n_gens
        % disp(gen);
        P_pop = P_data.result{gen, 2};
        P_objs = P_pop.objs; % N x 3 matrix
        current_pop_size = size(P_objs, 1);

        
        % HISTPOP= P_data.result{1,2};
        % HISTOBJS = HISTPOP.objs;
        current_min_f1f2f3 = min(P_objs, [], 1); % Find min across all population rows
        ideal = min(ideal, current_min_f1f2f3); % Update the historical minimum
        
        set(hP, 'XData', P_objs(:,1), 'YData', P_objs(:,2), 'DisplayName', sprintf('Pop Gen %d', gen));
        set(hI, 'XData', ideal(1), 'YData', ideal(2));
        set(hY, 'Value', ideal(2));
        set(hX, 'Value', ideal(1));
        
        % 5. Update Title
        title(ax, sprintf('XY-plane of a %d-objective %d-city MOTSP (N=%d)', M, D, N));
        subtitle(sprintf('Gen: %d / %d', gen, n_gens))

        
        fc = struct();
        fc.axesSize = 28;
        fc.fontSize = 36;
        
        EnlargeFont(fig, fc)

        drawnow;
        pause(1);

        filename = sprintf('Py-NSGA-III-MOTSP-G%d.png', gen);
        exportgraphics(ancestor(ax, 'figure'), filename, 'Resolution', 600);
        % Write frame to video
        % frame = getframe(gcf);
        % writeVideo(v, frame);
    end
    return
    close(v); fprintf('Animation saved to: %s\n', vid_name);
    close(fig);

end


