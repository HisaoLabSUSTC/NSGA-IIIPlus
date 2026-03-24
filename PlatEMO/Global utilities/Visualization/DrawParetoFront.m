% phs = {@BT1, @BT2, @BT3, @BT4, @BT5, @BT6, @BT7, @BT8, @BT9, ...
%     @DTLZ1, @DTLZ2, @DTLZ3, @DTLZ4, @DTLZ5, @DTLZ6, @DTLZ7, @IDTLZ1, @IDTLZ2, ...
%     @SDTLZ1, @SDTLZ2, @IMOP1, @IMOP2, @IMOP3, @IMOP4, @IMOP5, @IMOP6, @IMOP7, @IMOP8, ...
%     @MaF1,@MaF2,@MaF3,@MaF4,@MaF5, @MaF13,@MaF14,@MaF15}
% phs ={    @MinusDTLZ1,@MinusDTLZ2,@MinusDTLZ3,@MinusDTLZ4,@MinusDTLZ5,@MinusDTLZ6,...
%     @MinusWFG1,@MinusWFG2,@MinusWFG3,@MinusWFG4,@MinusWFG5,@MinusWFG6,@MinusWFG7,@MinusWFG8,@MinusWFG9,...
%     @RWA1,@RWA2,@RWA3,@RWA4,@RWA5,@RWA6,@RWA7, @VNT1, @VNT2, @VNT3,...
%     @WFG1,@WFG2,@WFG3,@WFG4,@WFG5,@WFG6,@WFG7,@WFG8,@WFG9,@ZDT1,@ZDT2,@ZDT3,@ZDT4,@ZDT6,...
%     @UF1, @UF2, @UF3,@UF4,@UF5,@UF6,@UF7,@UF8,@UF9,@UF10};

% generateReferencePF({@MinusDTLZ2}, [3], 3000);

% generateReferencePF({@IDTLZ2}, 3, 50);
phs = {@IDTLZ2}; 
Ms = [3, 3, 3, 3, 3];
for i=1:numel(phs)
    ph = phs{i};
    M = Ms(i);
    if M <= 3
        ScatterPFandRef(ph, M);
        return
    end
end

function extreme_points = getExtremePoints(F)
    ideal_point = min(F, [], 1);
    [~, M] = size(F);
    weights = zeros(M)+eye(M)+1e-6;
    FF = F;
    [N, ~] = size(FF);

    % === Shift by ideal ===
    FFF = FF - ideal_point;
    % FFF(FFF < 1e-3) = 0;

    I = zeros(1, M);
    for i = 1 : M
        [~, I(i)] = min(max(FFF./repmat(weights(i,:),N,1),[],2));
    end

    extreme_points = FF(I, :);
end

function ScatterPFandRef(ph, M)
    [PF, ideal, nadir] = loadReferencePF(func2str(ph));
    
    PreprocessProductionImage(0.2, 1, 8.8);
    fig = gcf; ax = gca;
    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    
    optimum = PF;

    if size(optimum,1) > 1
        if M == 2
            plot(ax,optimum(:,1),optimum(:,2),'.k', 'MarkerSize', 20);
            plot(ax,nadir(:,1),nadir(:,2),'.g', 'MarkerSize', 40);
            plot(ax,ideal(:,1),ideal(:,2),'.b', 'MarkerSize', 40);
        elseif M == 3
            plot3(ax,optimum(:,1),optimum(:,2),optimum(:,3),'.k', 'MarkerSize', 25);
            plot3(ax,nadir(:,1),nadir(:,2),nadir(:,3),'.g', 'MarkerSize', 50);
            plot3(ax,ideal(:,1),ideal(:,2),ideal(:,3),'.b', 'MarkerSize', 50);
        end
    end

    extreme_points = getExtremePoints(optimum);
    plot3(ax, extreme_points(:,1), extreme_points(:,2), extreme_points(:,3), '.r', 'MarkerSize', 40)

    % ideal = [0 0 0]
    % eigvec1 = [0.3691 0.6550 0.6593];
    % eigvec2 = [-0.3806 0.6574 0.6504];
    % eigvec3 = [0.0041 0.0105 0.9999];
    % quiver3(ax, ideal(:,1),ideal(:,2),ideal(:,3),eigvec1(1), eigvec1(2), eigvec1(3))
    % quiver3(ax, ideal(:,1),ideal(:,2),ideal(:,3),eigvec2(1), eigvec2(2), eigvec2(3))
    % quiver3(ax, ideal(:,1),ideal(:,2),ideal(:,3),eigvec3(1), eigvec3(2), eigvec3(3))

    xlabel(ax, '$f_1$', 'Interpreter', 'Latex');
    ylabel(ax, '$f_2$', 'Interpreter', 'Latex');

    % hold on
    % h1 = plot(NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');
    % h2 = plot(NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');
    % legend([h1, h2], ...
    %     sprintf('Problem: %s', class(Problem)), ...
    %     sprintf('$m$ = %d, $n$ = %d', Problem.M, Problem.D), ...
    %     'Location', 'best');
    % hold off

    if M == 3
        view(ax, 135, 30);
        box(ax, 'on');
        zlabel(ax, '$f_3$', 'Interpreter', 'Latex');

        lighting(ax, 'gouraud');
        light('Position', [1 1 1], 'Style', 'infinite');
        light('Position', [-1 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);
    else
        view(ax, 2); % top-down 2D view
    end

    set(ax.Title, 'String', '');
end

function DrawParetoFrontMethod(Problem, PF)
    %% Create figure for visualization
    % fig = figure('Position', [100, 50, 1000, 800], ...
    %              'Name', 'PF Visualization', 'Visible', 'on');
    % ax = axes('Position', [0.13, 0.1, 0.8, 0.8]);

    PreprocessProductionImage(1, 0.3, 8.8);
    fig = gcf; ax = gca;
    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    % axis(ax, 'square'); 
    boundDir = fullfile('./Info/Bounds'); mkdir(boundDir)

    % if ~isempty(Problem.PF)
    %     if ~iscell(Problem.PF)
    %         if Problem.M == 2
    %             plot(ax,Problem.PF(:,1),Problem.PF(:,2),'-k','LineWidth',1);
    %         elseif Problem.M == 3
    %             plot3(ax,Problem.PF(:,1),Problem.PF(:,2),Problem.PF(:,3),'-k','LineWidth',1);
    %         end
    %     else
    %         if Problem.M == 2
    %             surf(ax,Problem.PF{1},Problem.PF{2},Problem.PF{3},'EdgeColor','none','FaceColor',[.85 .85 .85]);
    %         elseif Problem.M == 3
    %             surf(ax,Problem.PF{1},Problem.PF{2},Problem.PF{3},'EdgeColor',[.0 .0 .0],'FaceColor','black');
    %         end
    %         % set(ax,'Children',ax.Children(flip(1:end)));
    %     end
    % end
    %% Remember to do NDSort and plot again

    if nargin < 2
        optimum = Problem.GetOptimum(120);
        optimum = optimum(NDSort(optimum, 1)==1,:);

        disp(size(optimum))
        % optimumI = getLeastCrowdedPoints(optimum, 120);
        % optimum = optimum(optimumI,:);
        disp(size(optimum))
        PF = optimum;
    end
    save(sprintf('./Info/ReferencePF/%s.mat', class(Problem)), "PF");
    
    optimum = PF;

    if size(optimum,1) > 1 && Problem.M < 4
        if Problem.M == 2
            plot(ax,optimum(:,1),optimum(:,2),'.k', 'MarkerSize', 20);
        elseif Problem.M == 3
            plot3(ax,optimum(:,1),optimum(:,2),optimum(:,3),'.k', 'MarkerSize', 25);
        end
    end

    xlabel(ax, '$f_1$', 'Interpreter', 'Latex');
    ylabel(ax, '$f_2$', 'Interpreter', 'Latex');
    % title(ax, sprintf('Pareto Front of %s', class(Problem)));

    hold on
    h1 = plot(NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');
    h2 = plot(NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');

    % Create legend with these handles
    legend([h1, h2], ...
        sprintf('Problem: %s', class(Problem)), ...
        sprintf('m = %d, n = %d', Problem.M, Problem.D), ...
        'Location', 'best');
    hold off

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


    set(ax.Title, 'String', '');

    % lastObjs = optimum;
    lastObjs = [0, 0, 0; 2.1, 4.1, 6.1];
    low_lims = min(lastObjs);
    high_lims = max(lastObjs);

    %% LIMLIM
    boundFile = sprintf('bound-%s.mat', class(Problem));
    boundData = fullfile(boundDir, boundFile);

    if Problem.M == 2
        XBounds = roundc([low_lims(1), high_lims(1)]);
        YBounds = roundc([low_lims(2), high_lims(2)]);
        if ~isfile(boundData)
            % save(boundData, 'XBounds', 'YBounds')
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
            % save(boundData, 'XBounds', 'YBounds', 'ZBounds')
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

    if Problem.M == 2
        set(ax, 'XTick', XBounds);
        set(ax, 'YTick', YBounds);
    else 
        set(ax, 'XTick', XBounds);
        set(ax, 'YTick', YBounds);
        set(ax, 'ZTick', ZBounds);
    end

    shift = high_lims - low_lims;
    if Problem.M==2
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

    filename = sprintf("./Visualization/images/PF-%s-M%d-D%d.png", ...
        class(Problem), Problem.M, Problem.D);
    % exportgraphics(gcf, filename, 'Resolution', 300);
    % close(fig);

end


%% helper function
% function new_interval = roundc(interval)
%     % 1. Calculate the 'Scale'
%     % We take the range, divide by 10, and find the nearest lower power of 10.
%     range = diff(interval);
%     scale = 10^floor(log10(range / 10));
% 
%     % 2. Round the limits
%     % Floor the lower limit and Ceil the upper limit to expand the interval
%     new_lower = floor(interval(1) / scale) * scale;
%     new_upper = ceil(interval(2) / scale) * scale;
% 
%     new_interval = [new_lower, new_upper];
% end

function new_interval = roundc(interval)
    new_interval = interval;
end