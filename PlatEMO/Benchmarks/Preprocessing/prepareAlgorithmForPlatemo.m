function algSpec = prepareAlgorithmForPlatemo(algorithmSpec, heuristicPath)
%PREPAREALGORITHMFORPLATEMO Prepare algorithm specification for platemo call
%
%   algSpec = prepareAlgorithmForPlatemo(algorithmSpec, heuristicPath)
%
%   Converts an algorithm specification into the format expected by platemo,
%   adding the heuristic file path if the algorithm uses heuristic initialization.
%
%   Input:
%     algorithmSpec  - Function handle, cell array with config, or string
%     heuristicPath  - Path to heuristic initial population file
%
%   Output:
%     algSpec        - Format suitable for platemo('algorithm', algSpec, ...)
%
%   Examples:
%     % Legacy algorithm with heuristics
%     spec = prepareAlgorithmForPlatemo(@PyNSGAIIIwH, 'init.mat')
%     % Returns: {@PyNSGAIIIwH, 'init.mat'}
%
%     % Config-based algorithm
%     config = struct('nadirType', 'median');
%     spec = prepareAlgorithmForPlatemo({@ConfigurableNSGAIIIwH, config}, 'init.mat')
%     % Returns: {@ConfigurableNSGAIIIwH, config, 'init.mat'}
%
%     % Algorithm without heuristics (no wH suffix)
%     spec = prepareAlgorithmForPlatemo(@NSGAII, 'init.mat')
%     % Returns: @NSGAII (unchanged, warning issued)

    % Check if algorithm uses heuristic initialization
    if ~usesHeuristicInit(algorithmSpec)
        algName = getAlgorithmName(algorithmSpec);
        warning('MATLAB:PlatEMO', ...
            'Algorithm %s does not use heuristic initial population.', algName);
        algSpec = algorithmSpec;
        return;
    end

    if isa(algorithmSpec, 'function_handle')
        % Legacy: wrap in cell array with heuristic path
        algSpec = {algorithmSpec, heuristicPath};

    elseif iscell(algorithmSpec)
        handle = algorithmSpec{1};
        className = func2str(handle);

        if strcmp(className, 'ConfigurableNSGAIIIwH')
            % Config-based: {handle, config} -> {handle, config, heuristicPath}
            if length(algorithmSpec) >= 2 && isstruct(algorithmSpec{2})
                algSpec = {handle, algorithmSpec{2}, heuristicPath};
            else
                algSpec = {handle, struct(), heuristicPath};
            end
        else
            % Other cell array format: append heuristic path
            algSpec = [algorithmSpec, {heuristicPath}];
        end
    else
        error('MATLAB:prepareAlgorithmForPlatemo:InvalidInput', ...
            'algorithmSpec must be a function handle or cell array');
    end
end
