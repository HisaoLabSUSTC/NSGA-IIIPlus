classdef OrthoMedNormHist < handle
    properties
        ideal_point  
        nadir_point
        extreme_points
    end

    methods
        function obj = OrthoMedNormHist(M)
            obj.ideal_point   = inf(1, M);
            obj.nadir_point   = [];
            obj.extreme_points = [];
        end

        function update(obj, F, nds)
            % F: N x M
            % pause(1);

            if nargin < 3 || isempty(nds)
                nds = 1:size(F,1);
            end

            % === update ideal and worst ===
            obj.ideal_point = min([obj.ideal_point; F], [], 1);

            obj.nadir_point = get_nadir_point( ...
                F, obj.ideal_point);
            
        end
    end
end

function nadir_point = get_nadir_point(F, ideal_point)
    median_point = median(F);
    % FormatMatrix('%.6g ', median_point);
    normal = median_point - ideal_point;
    % FormatMatrix('%.6g ', normal);
    b = dot(normal, median_point);

    % FormatMatrix('%.6g ', b);
    nadir_point = b ./ normal;
    % FormatMatrix('%.6g ', nadir_point);

    % pause(5)
end


