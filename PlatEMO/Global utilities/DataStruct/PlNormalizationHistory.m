classdef PlNormalizationHistory < handle
    properties
        ideal_point
        nadir_point
        extreme_points
        N
    end

    methods
        function obj = PlNormalizationHistory(M, N)
            obj.ideal_point   = inf(1, M);
            obj.nadir_point   = [];
            obj.extreme_points = [];
            obj.N = N;
        end

        function update(obj, F)
            % F: N x M

            % === update ideal (PlatEMO)===
            obj.ideal_point = min([obj.ideal_point; F], [], 1);

            % === get extreme points (PlatEMO) ===
            extreme_points = get_extreme_points_c( ...
                F, obj.ideal_point);

            obj.extreme_points = extreme_points;

            % === determine nadir ===
            %% Pymoo
            % worst_of_population = max(F, [], 1);
            % worst_of_front      = max(F(nds,:), [], 1);

            %% PlatEMO
            [FrontNo,MaxFNo] = NDSort(F,obj.N);
            Next = FrontNo < MaxFNo; Last = FrontNo==MaxFNo;
            worst_of_preserved = max([F(Next,:); F(Last,:)], [], 1);

            obj.nadir_point = get_nadir_point( ...
                extreme_points, obj.ideal_point, worst_of_preserved);
        end
    end
end

function extreme_points = get_extreme_points_c(F, ideal_point)
    [~, M] = size(F);

    % === ASF weight matrix (identity with off-diagonal = 1e6) ===
    weights = zeros(M)+eye(M)+1e-6;

    % if ~isempty(extreme_points)
    %     FF = [extreme_points; F];
    % else
    %     FF = F;
    % end
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

function nadir_point = get_nadir_point(extreme_points, ideal_point, worst_of_preserved)
    M = size(extreme_points,2);

    try
        % === Solve (extreme - ideal) * plane = 1 ===
        A = extreme_points - ideal_point;
        % pause(0.1)
        b = ones(M, 1);

        plane = A \ b;   % Gaussian elimination

        % intercepts = 1 ./ plane
        intercepts = 1 ./ plane';

        % === Check validity ===
        if any(isnan(intercepts)) || any(~isfinite(intercepts))
            % disp("Invalid triggered")
            % intercepts
            % pause(1);
            error('Invalid hyperplane');
        end

        % nadir = ideal + intercepts
        nadir_point = ideal_point + intercepts;


        % === Cap by historical worst === (Pymoo)
        % mask = nadir_point > worst_point;
        % nadir_point(mask) = worst_point(mask);

    catch
        % Fallback to worst of preserved (PlatEMO)
        nadir_point = worst_of_preserved;
    end
    
    % === If too small, fallback to worst of population === (Pymoo)
    % mask2 = (nadir_point - ideal_point) <= 1e-6;
    % nadir_point(mask2) = worst_of_population(mask2);

end


