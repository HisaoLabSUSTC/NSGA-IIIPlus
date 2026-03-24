function tf = usesHeuristicInit(algorithmSpec)
%USESHEURISTICINIT Check if algorithm uses heuristic initialization
%
%   tf = usesHeuristicInit(algorithmSpec)
%
%   Returns true if the algorithm name contains 'wH' (with Heuristics),
%   indicating it should use a heuristic initial population file.
%
%   Works with both legacy function handles and config-based specs.

    algName = getAlgorithmName(algorithmSpec);
    tf = contains(algName, 'wH');
end
