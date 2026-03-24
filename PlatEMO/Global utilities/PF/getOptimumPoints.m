function optimum = getOptimumPoints(Problem, ~, ~)
%GETOPTIMUMPOINTS Load stored reference Pareto front for visualization.
%
%   optimum = getOptimumPoints(Problem)
%
%   Loads the pre-computed reference PF from stored files. The reference PF
%   must be generated beforehand using generateReferencePF().
%
%   Input:
%     Problem - PROBLEM instance (class name used to look up PF)
%
%   Output:
%     optimum - N x M matrix of Pareto-optimal objective values

    pn = class(Problem);
    if isprop(Problem, 'ID')
        [PF, ~, ~] = loadReferencePF(pn, Problem.ID);
    else
        [PF, ~, ~] = loadReferencePF(pn);
    end
    optimum = PF;
end
