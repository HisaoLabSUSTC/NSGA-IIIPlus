function [p_best, f_best] = greedy_motsp(C, weight_vector)
%GREEDY_MOTSP Greedy nearest-neighbour solver for the weighted MOTSP.
%
%   [p_best, f_best] = greedy_motsp(C, weight_vector)
%
%   For each starting city, constructs a tour by always visiting the
%   nearest unvisited city under the scalarised distance matrix
%   sum_i w_i * C{i}.  Returns the best tour found.
%
%   Input:
%     C              - 1 x M cell array of D x D symmetric distance matrices
%     weight_vector  - 1 x M weight vector for scalarisation
%
%   Output:
%     p_best  - 1 x D row vector (permutation of 1:D), the best tour
%     f_best  - 1 x M row vector of per-objective tour costs
%
%   Based on the greedy TSP algorithm by John Burkardt (2018).

    M = numel(C);
    D = size(C{1}, 1);

    % Scalarise distance matrices
    distance = zeros(D);
    for i = 1:M
        distance = distance + C{i} * weight_vector(i);
    end

    % Try every starting city, keep the cheapest tour
    cost_best = Inf;
    p_best = 1:D;  % fallback
    for start = 1:D
        p = path_greedy(D, distance, start);
        cost = path_cost(D, distance, p);
        if cost < cost_best
            p_best = p;
            cost_best = cost;
        end
    end

    % Compute per-objective tour costs
    f_best = zeros(1, M);
    for i = 1:M
        f_best(i) = path_cost(D, C{i}, p_best);
    end
end

%% ==================== Local Functions ====================

function cost = path_cost(n, distance, p)
%PATH_COST Round-trip cost of tour p under distance matrix.
    cost = 0;
    i1 = n;
    for i2 = 1:n
        cost = cost + distance(p(i1), p(i2));
        i1 = i2;
    end
end

function p = path_greedy(n, distance, start)
%PATH_GREEDY Greedy nearest-neighbour tour from a given start city.
    p = zeros(1, n);   % row vector (fixed: original returned column)
    p(1) = start;
    d = distance;
    d(:, start) = Inf;
    for i = 1:n
        d(i, i) = Inf;
    end
    from = start;
    for j = 2:n
        [~, to] = min(d(from, :));
        p(j) = to;
        d(:, to) = Inf;
        from = to;
    end
end
