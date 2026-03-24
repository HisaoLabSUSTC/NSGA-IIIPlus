function norm_update(algName, Problem, NormStruct, Population, nds)
%NORM_UPDATE Unified normalization update dispatcher
%
%   norm_update(algName, Problem, NormStruct, Population, nds)
%
%   Handles both legacy algorithm-specific update logic and the new
%   ModularNormHist which uses a unified update interface.

    % Check if using ModularNormHist (new system)
    if isa(NormStruct, 'ModularNormHist')
        NormStruct.update(Population.objs, nds);
        return;
    end

    % Legacy algorithm-specific handling
    try
        if strcmp(algName, "NSGAIIIwH")
            NormStruct.update(Population.objs);
        elseif strcmp(algName, "GtNSGAIIIwH") || strcmp(algName, "Gt-NSGA-III")
            if any(isinf(NormStruct.ideal_point)) || isempty(NormStruct.nadir_point)
                PF = Problem.GetOptimum(1000);
                true_ideal_point = min(PF, [], 1);
                true_nadir_point = max(PF, [], 1);
                NormStruct.ideal_point = true_ideal_point;
                NormStruct.nadir_point = true_nadir_point;
            end
        else
            % Default: most algorithms use (Population.objs, nds)
            NormStruct.update(Population.objs, nds);
        end
    catch ME
        % Try fallback with just objs
        try
            NormStruct.update(Population.objs);
        catch
            warning('NormStruct.update failed: %s', ME.message);
        end
    end
end
