function handle = getAlgorithmHandle(algorithmSpec)
%GETALGORITHMHANDLE Extract function handle from algorithm specification
%
%   handle = getAlgorithmHandle(algorithmSpec)
%
%   Handles:
%     1. Function handle: @PyNSGAIIIwH -> @PyNSGAIIIwH
%     2. Cell array: {@ConfigurableNSGAIIIwH, config} -> @ConfigurableNSGAIIIwH
%
%   This is useful when you need the actual function handle for instantiation.

    if isa(algorithmSpec, 'function_handle')
        handle = algorithmSpec;
    elseif iscell(algorithmSpec)
        handle = algorithmSpec{1};
    else
        error('MATLAB:getAlgorithmHandle:InvalidInput', ...
            'algorithmSpec must be a function handle or cell array');
    end
end
