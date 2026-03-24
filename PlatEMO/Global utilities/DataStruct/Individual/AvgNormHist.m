classdef AvgNormHist < handle
    properties
        ideal_point
        nadir_point
        extreme_points
    end

    methods
        function obj = AvgNormHist(M)
            obj.ideal_point   = inf(1, M);
            obj.nadir_point   = [];
            obj.extreme_points = [];
        end

        function update(obj, F, nds)
            % F: N x M

            if nargin < 3 || isempty(nds)
                nds = 1:size(F,1);
            end

            % === update ideal ===
            obj.ideal_point = min([obj.ideal_point; F], [], 1);

            obj.nadir_point = get_nadir_point(F);

        end
    end
end

function nadir_point = get_nadir_point(F)
    nadir_point = mean(F);
end
