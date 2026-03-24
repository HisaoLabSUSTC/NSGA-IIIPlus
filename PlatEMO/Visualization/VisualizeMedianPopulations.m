Algorithms = {@NSGAIIIwH, @PyNSGAIIIwH};

% pause(14000);
VisualizeMedianPopulationsMethod(Algorithms)

function VisualizeMedianPopulationsMethod(algorithmHandles)

    rootDirHV   = fullfile('./Info/MedianHVResults');
    rootDirData = fullfile('./Tentative/2025-12-20-Correct');
    boundDir = fullfile('./Info/Bounds'); mkdir(boundDir)

    % -------------------------------------------------------------
    % 1. Load HV results for all algorithms first
    % -------------------------------------------------------------
    allResults = struct();   % allResults.(algName) = results struct
    allProblems = {};        % union of all problems across algorithms

    for ah = 1:numel(algorithmHandles)
        algName = func2str(algorithmHandles{ah});
        hvFile  = fullfile(rootDirHV, sprintf('MedianHV_%s.mat', algName));

        if ~exist(hvFile, 'file')
            warning('Median HV file missing: %s', hvFile);
            continue;
        end

        hvData = load(hvFile);   % loads "results"
        results = hvData.results;
        allResults.(algName) = results;

        % Union of problems
        problems = fieldnames(results);
        allProblems = union(allProblems, problems);
    end

    % -------------------------------------------------------------
    % 2. MAIN LOOP: For each problem across ALL algorithms
    % -------------------------------------------------------------
    for pi = 1:numel(allProblems)

        problem = allProblems{pi};

        fprintf('\n=============================================\n');
        fprintf('Processing Problem: %s (%d/%d)\n', problem, pi, numel(allProblems));
        fprintf('=============================================\n');

        % close all;   % one figure per problem if desired

        % Prepare Problem object (dimensions detected from first algorithm)
        Problem = [];
        Z_cache = struct();   % per algorithm uniform points

        % ---------------------------------------------------------
        % 2a. For each algorithm, load its median-run data for this problem
        % ---------------------------------------------------------
        ax_hv = gobjects(0); ax_nad = gobjects(0);
        colorIndex = 0; % Initialize color index
        for ah = 1:numel(algorithmHandles)

            algName = func2str(algorithmHandles{ah});
            %% LIMLIM
            hps = {@WFG8};
            pns = cellfun(@func2str, hps, 'UniformOutput', false);
            if ~ismember(problem, pns)
                continue
            end
            fprintf('  Algorithm: %s\n', algName);


            results = allResults.(algName);

            medianFilenameHV = results.(problem).medianFile;
            dataFilename = erase(medianFilenameHV, 'HV_');
            dataPath = fullfile(rootDirData, algName, dataFilename);

            if ~exist(dataPath, 'file')
                warning('Data missing: %s', dataPath);
                continue;
            end

            data = load(dataPath);

            if ~isfield(data, 'result')
                warning('%s missing variable "result"', dataPath);
                continue;
            end

            resultMatrix = data.result;
            lastPopulation = resultMatrix{end, 2};
            FE = resultMatrix{end, 1};

            % -------------------------------------
            % Initialize Problem (M, D) only once
            % -------------------------------------
            if isempty(Problem)
                M = size(lastPopulation.objs, 2);
                D = size(lastPopulation.decs, 2);
                Problem_handle = str2func(problem);
                Problem = Problem_handle('M', M, 'D', D);
            end


            % -------------------------------------
            % Uniform reference vectors (per alg)
            % -------------------------------------
            N = size(lastPopulation, 2);
            [Z, ~] = UniformPoint(N, Problem.M);
            Z_cache.(algName) = Z;


            NormStruct = alg2norm(algName, N, M);
       
            n_gens = size(resultMatrix,1);
            %% First iteration requires special processing
            Population = resultMatrix{1, 2};
            nds = nds_preprocess(Population);
            norm_update(algName, Problem, NormStruct, Population, nds);
            for g = 2:n_gens
                Population = resultMatrix{g-1, 2};
                Offspring = resultMatrix{g, 3};
                Mixture = [Population, Offspring];
                nds = nds_preprocess(Mixture);
                norm_update(algName, Problem, NormStruct, Mixture, nds);
            end
        

            % -------------------------------------
            % 2b. Call your visualization per algorithm
            % -------------------------------------
            % if Problem.M <= 3

            Algorithm = str2func(algName);
            colorIndex = colorIndex + 1;
            colorIndex2 = colorIndex + 1;
            PreprocessProductionImage(2/3, 1, 8.8);
            VisualizeMindistPopulation(Algorithm, lastPopulation, Z, Problem, FE, NormStruct);
            % ax_hv = VisualizeHypervolumeEvolution(Algorithm, Problem, allResults.(algName).(problem).medianFile, ax_hv);
            % ax_nad = VisualizeNadirStability(Algorithm, Problem, resultMatrix, ax_nad, colorIndex, colorIndex2);
            % colorIndex = colorIndex + 1; % Prepare for the next algorithm's first line
            %% Customize
            ax = gca; fig = gcf;
            set(ax.Title, 'String', '');

            axis(ax, 'square'); 
            %% LIMLIM
            lastObjs = lastPopulation.objs;
            % lastObjs = [-6320, -2400, -690; -3229, -300, -360];

            low_lims = min(lastObjs);
            high_lims = max(lastObjs);

            

            boundFile = sprintf('bound-%s.mat', class(Problem));
            boundData = fullfile(boundDir, boundFile);
            if M == 2
                XBounds = roundc([low_lims(1), high_lims(1)]);
                YBounds = roundc([low_lims(2), high_lims(2)]);
                if ~isfile(boundData)
                    save(boundData, 'XBounds', 'YBounds')
                else
                    data = load(boundData, 'XBounds', 'YBounds');
                    combined = [XBounds; data.XBounds];
                    XBounds = [min(combined(:,1)), max(combined(:,2))];
                    combined = [YBounds; data.YBounds];
                    YBounds = [min(combined(:,1)), max(combined(:,2))];
                    save(boundData, 'XBounds', 'YBounds')
                end
                set(ax, 'XLim', XBounds); low_lims(1) = XBounds(1); high_lims(1) = XBounds(2);
                set(ax, 'YLim', YBounds); low_lims(2) = YBounds(1); high_lims(2) = YBounds(2);
            else 
                XBounds = roundc([low_lims(1), high_lims(1)]);
                YBounds = roundc([low_lims(2), high_lims(2)]);
                ZBounds = roundc([low_lims(3), high_lims(3)]);
                if ~isfile(boundData)
                    save(boundData, 'XBounds', 'YBounds', 'ZBounds')
                else
                    data = load(boundData, 'XBounds', 'YBounds', 'ZBounds');
                    combined = [XBounds; data.XBounds];
                    XBounds = [min(combined(:,1)), max(combined(:,2))];
                    combined = [YBounds; data.YBounds];
                    YBounds = [min(combined(:,1)), max(combined(:,2))];
                    combined = [ZBounds; data.ZBounds];
                    ZBounds = [min(combined(:,1)), max(combined(:,2))];
                    save(boundData, 'XBounds', 'YBounds', 'ZBounds')
                end
                set(ax, 'XLim', XBounds); low_lims(1) = XBounds(1); high_lims(1) = XBounds(2);
                set(ax, 'YLim', YBounds); low_lims(2) = YBounds(1); high_lims(2) = YBounds(2);
                set(ax, 'ZLim', ZBounds); low_lims(3) = ZBounds(1); high_lims(3) = ZBounds(2);
            end

            if M == 2
                set(ax, 'XTick', XBounds);
                set(ax, 'YTick', YBounds);
            else 
                set(ax, 'XTick', XBounds);
                set(ax, 'YTick', YBounds);
                set(ax, 'ZTick', ZBounds);
            end

            
            shift = high_lims - low_lims;
            if M==2
                set(ax, 'Position', [0.32 0.35 0.36 0.57])
                set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1])
                set(ax, 'XTickLabelRotation', 0);
                set(ax, 'YTickLabelRotation', 0);
                set(ax.XLabel, 'Rotation', 0, 'Position', ...
                    [low_lims(1) + 1/2 * shift(1), low_lims(2) - 0.05 * shift(2)]);
                set(ax.YLabel, 'Rotation', 0, 'Position', ...
                    [low_lims(1) - 0.1 * shift(1), low_lims(2) + 0.4 * shift(2)]);
            else
                set(ax, 'Position', [0.2 0.35 0.6 0.6])
                set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1])
                set(ax, 'XTickLabelRotation', 0);
                set(ax, 'YTickLabelRotation', 0);
                set(ax.XLabel, 'Rotation', 0, 'Position', ...
                    [low_lims(1) + 1/2 * shift(1), ...
                    low_lims(2) + 1.1 * shift(2), ...
                    low_lims(3)])
                set(ax.YLabel, 'Rotation', 0, 'Position', ...
                    [low_lims(1) + 1.1 * shift(1), ...
                    low_lims(2) + 1/2 * shift(2), ...
                    low_lims(3)])
                set(ax, 'ZTickLabelRotation', 0);
                set(ax.ZLabel, 'Rotation', 0, 'Position', ...
                    [low_lims(1) + 0.62 * shift(1), ...
                    low_lims(2) - 0.62 * shift(2), ...
                    low_lims(3)])
                FormatMatrix('%.8g\n' ,[low_lims(1) + 0.62 * shift(1), ...
                    low_lims(2) - 0.62 * shift(2), ...
                    low_lims(3)])
            end

            DrawParetoFrontMethod(Problem)

            drawnow;
            filename = sprintf("./Visualization/images/MP-%s-%s-M%d-D%d.png", ...
                func2str(Algorithm), class(Problem), Problem.M, Problem.D);

            exportgraphics(ancestor(ax, 'figure'), filename, 'Resolution', 300);
            close(fig);
            % end
        end

        % drawnow;
    end
end

%% helper function
function new_interval = roundc(interval)
    % 1. Calculate the 'Scale'
    % We take the range, divide by 10, and find the nearest lower power of 10.
    range = diff(interval);
    scale = 10^floor(log10(range / 10));

    % 2. Round the limits
    % Floor the lower limit and Ceil the upper limit to expand the interval
    new_lower = floor(interval(1) / scale) * scale;
    new_upper = ceil(interval(2) / scale) * scale;

    new_interval = [new_lower, new_upper];
end


% function new_interval = roundc(interval)
%     new_interval = interval;
% end


function DrawParetoFrontMethod(Problem, PF)
    %% Create figure for visualization
    fig = gcf; ax = gca;
    % cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); axis(ax, 'square'); 
    boundDir = fullfile('./Info/Bounds'); mkdir(boundDir)

    if nargin < 2
        %% LIMLIM
        optimum = Problem.GetOptimum(120);
        optimum = optimum(NDSort(optimum, 1)==1,:);
    
        disp(size(optimum))
        % optimumI = getLeastCrowdedPoints(optimum, 120);
        % optimum = optimum(optimumI,:);
        disp(size(optimum))
        PF = optimum;
    end
    
    optimum = PF;

    hold on
    if size(optimum,1) > 1 && Problem.M < 4
        if Problem.M == 2
            plot(ax,optimum(:,1),optimum(:,2),'.k', 'MarkerSize', 10, ...
                'HandleVisibility', 'off');
        elseif Problem.M == 3
            plot3(ax,optimum(:,1),optimum(:,2),optimum(:,3),'.k', 'MarkerSize', 15, ...
                'HandleVisibility', 'off');
        end
    end
    hold off

    xlabel(ax, '$f_1$', 'Interpreter', 'Latex');
    ylabel(ax, '$f_2$', 'Interpreter', 'Latex');

    if Problem.M == 3
        view(ax, 135, 30);
    else
        view(ax, 2); % top-down 2D view
    end


    if Problem.M == 3
        box(ax, 'on');
        zlabel(ax, '$f_3$', 'Interpreter', 'Latex');

        lighting(ax, 'gouraud');
        light('Position', [1 1 1], 'Style', 'infinite');
        light('Position', [-1 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);
    end

end