classdef PybNormalizationHistory < handle
    properties
        ideal_point  
        worst_point
        nadir_point
        extreme_points
        extreme_archive
    end

    methods
        function obj = PybNormalizationHistory(M)
            obj.ideal_point   = inf(1, M);
            obj.worst_point   = -inf(1, M);
            obj.nadir_point   = [];
            obj.extreme_points = [];
            obj.extreme_archive = [];
        end

        function update(obj, F, nds)
            % F: N x M
            % pause(1);

            if nargin < 3 || isempty(nds)
                nds = 1:size(F,1);
            end

            % === update ideal and worst ===
            obj.ideal_point = min([obj.ideal_point; F], [], 1);
            obj.worst_point = max([obj.worst_point; F], [], 1);

            % === get extreme points ===
            obj.extreme_points = get_extreme_points_c( ...
                F(nds,:), obj.ideal_point, obj.extreme_archive);
            obj.extreme_archive = [obj.extreme_archive; obj.extreme_points];

            % === determine nadir ===
            worst_of_population = max(F, [], 1);
            worst_of_front      = max(F(nds,:), [], 1);

            obj.nadir_point = get_nadir_point( ...
                obj.extreme_points, obj.ideal_point, obj.worst_point, ...
                worst_of_population, worst_of_front);
            
        end
    end
end

function extreme_points = get_extreme_points_c(F, ideal_point, extreme_points)
    [~, M] = size(F);

    % === ASF weight matrix (identity with off-diagonal = 1e6) ===
    weights = zeros(M)+eye(M)+1e-6;

    % === Preserve old extreme points (never lose them) ===
    if ~isempty(extreme_points)
        FF = [extreme_points; F];
    else
        FF = F;
    end
    [N, ~] = size(FF);

    % === Shift by ideal ===
    FFF = FF - ideal_point;
    FFF(FFF < 1e-3) = 0;
    % pause(0.5);

    I = zeros(1, M);
    for i = 1 : M
        [~, I(i)] = min(max(FFF./repmat(weights(i,:),N,1),[],2));
    end

    extreme_points = FF(I, :);
end

function nadir_point = get_nadir_point(extreme_points, ideal_point, worst_point, worst_of_population, worst_of_front)
    M = size(extreme_points,2);

    try
        % === Solve (extreme - ideal) * plane = 1 ===
        A = extreme_points - ideal_point;
        % pause(0.1);
        b = ones(M, 1);

        plane = A \ b;

        % intercepts = 1 ./ plane
        intercepts = 1 ./ plane';

        % nadir = ideal + intercepts
        nadir_point = ideal_point + intercepts;

        % === Check validity ===
        if any(isnan(plane)) || any(intercepts <= 1e-6) || norm(A * plane - b) > 1e-8
            % disp("Invalid triggered")
            % plane
            % intercepts
            % norm(A * plane - b) > 1e-8
            % pause(1);
            error('Invalid hyperplane');
        end

        % === Cap by historical worst ===
        mask = nadir_point > worst_point;
        % if any(mask)
        %     nadir_point > worst_point
        %     disp("^Mask: historical worst");
        %     pause(1)
        % end
        nadir_point(mask) = worst_point(mask);

    catch
        % Fallback to worst of front
        nadir_point = worst_of_front;
    end

    % === If too small, fallback to worst of population ===
    mask2 = (nadir_point - ideal_point) <= 1e-6;
    % if any(mask2)
    %     (nadir_point - ideal_point) <= 1e-6
    %     disp("^Mask: too small");
    %     pause(1)
    % end
    nadir_point(mask2) = worst_of_population(mask2);

end


