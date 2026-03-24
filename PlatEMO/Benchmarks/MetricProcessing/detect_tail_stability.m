function result = detect_tail_stability(trajectory, varargin)
%DETECT_TAIL_STABILITY Detect tail stability in a trajectory
%
%   result = detect_tail_stability(trajectory, 'Name', Value, ...)
%
%   Input:
%     trajectory - T x M matrix of trajectory points
%
%   Optional Parameters:
%     'max_abs'      - Maximum absolute change threshold (default: 1e-3)
%     'rel_max'      - Relative maximum change threshold (default: 1e-6)
%     'min_tail_len' - Minimum tail length for stability (default: 30)
%
%   Output:
%     result - Struct with stability detection results:
%       .is_stable_max_rel  - 1 if stable by relative max criterion
%       .stable_gen_max_rel - Generation where stability began
%       .tail_length        - Length of stable tail

    p = inputParser;
    p.addParameter('max_abs', 1e-3, @(x) isempty(x) || isscalar(x));
    p.addParameter('rel_max', 1e-6, @(x) isempty(x) || (isscalar(x) && x > 0));
    p.addParameter('min_tail_len', 30, @(x) isscalar(x) && x >= 1);
    p.parse(varargin{:});

    max_abs = p.Results.max_abs;
    rel_max = p.Results.rel_max;
    min_tail_len = p.Results.min_tail_len;

    [T, M] = size(trajectory);

    % Initialize result
    result = struct();
    result.is_stable_max_rel = 0;
    result.stable_gen_max_rel = NaN;
    result.tail_length = 0;

    if min_tail_len > T
        warning('min_tail_len (%d) exceeds trajectory length T=%d.', min_tail_len, T);
        return;
    end

    X = trajectory;

    % Compute cumulative sums from the end (backward)
    cs1 = zeros(T, M);  % Sum of values
    cs2 = zeros(T, M);  % Sum of squared values

    cs1(T, :) = X(T, :);
    cs2(T, :) = X(T, :).^2;
    for t = T-1:-1:1
        cs1(t, :) = cs1(t+1, :) + X(t, :);
        cs2(t, :) = cs2(t+1, :) + X(t, :).^2;
    end

    % Find stable tail using relative max criterion
    for t = T - min_tail_len + 1:-1:1
        tail_len = T - t + 1;
        tail_mean = cs1(t, :) / tail_len;
        tail_var = cs2(t, :) / tail_len - tail_mean.^2;
        tail_std = sqrt(max(tail_var, 0));

        % Relative max: max deviation relative to mean
        tail_data = X(t:T, :);
        max_dev = max(abs(tail_data - tail_mean), [], 1);

        % Use relative criterion: max_dev / (|mean| + eps) < rel_max
        rel_criterion = max(max_dev ./ (abs(tail_mean) + eps));

        if rel_criterion < rel_max
            result.is_stable_max_rel = 1;
            result.stable_gen_max_rel = t;
            result.tail_length = tail_len;
        else
            break;
        end
    end
end
