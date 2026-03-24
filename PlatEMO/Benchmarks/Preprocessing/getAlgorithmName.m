function [algName, displayName] = getAlgorithmName(algorithmSpec)
%GETALGORITHMNAME Extract algorithm name from various specification formats
%
%   [algName, displayName] = getAlgorithmName(algorithmSpec)
%
%   Handles three types of algorithm specifications:
%     1. Function handle (legacy): @PyNSGAIIIwH -> "PyNSGAIIIwH"
%     2. Cell array with config: {@ConfigurableNSGAIIIwH, config} -> name from config
%     3. Cell array with config and HID: {@ConfigurableNSGAIIIwH, config, 'file.mat'}
%
%   Returns:
%     algName     - Internal name for file paths (e.g., "OrmePyAAdamNSGAIIIwH")
%     displayName - Human-readable name (e.g., "Orme-PyA-Adam-NSGA-III")
%
%   Examples:
%     % Legacy function handle
%     [name, disp] = getAlgorithmName(@PyNSGAIIIwH)
%     % name = "PyNSGAIIIwH", disp = "PyNSGAIIIwH"
%
%     % Config-based algorithm
%     config = struct('nadirType', 'median', 'ortho', true);
%     [name, disp] = getAlgorithmName({@ConfigurableNSGAIIIwH, config})
%     % name = "OrmeNSGAIIIwH", disp = "Orme-NSGA-III"

    if isa(algorithmSpec, 'function_handle')
        % Legacy: simple function handle
        algName = func2str(algorithmSpec);
        displayName = algName;

    elseif iscell(algorithmSpec)
        % Cell array: {handle, config} or {handle, config, HID}
        handle = algorithmSpec{1};
        className = func2str(handle);

        if strcmp(className, 'ConfigurableNSGAIIIwH')
            % Extract config from cell array
            if length(algorithmSpec) >= 2 && isstruct(algorithmSpec{2})
                config = algorithmSpec{2};
            else
                config = struct();
            end

            % Parse and merge with defaults
            config = parseAlgConfig(config);

            % Generate names from config
            [displayName, algName] = config2name(config);
        else
            % Non-configurable algorithm in cell array (has params but fixed name)
            algName = className;
            displayName = className;
        end

    elseif ischar(algorithmSpec) || isstring(algorithmSpec)
        % String algorithm name (for backward compatibility)
        algName = char(algorithmSpec);
        displayName = algName;

    else
        error('MATLAB:getAlgorithmName:InvalidInput', ...
            'algorithmSpec must be a function handle, cell array, or string');
    end
end
