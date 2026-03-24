function [x_best, f_best] = greedy_mokp(P, W, weight_vector)
%GREEDY_MOKP Greedy solver for the weighted multi-objective knapsack problem.
%
%   [x_best, f_best] = greedy_mokp(P, W, weight_vector)
%
%   Selects items in descending order of scalarised profit-to-weight ratio
%   until the knapsack capacity is reached.
%
%   Input:
%     P              - M x D profit matrix
%     W              - M x D weight matrix
%     weight_vector  - 1 x M weight vector for scalarisation
%
%   Output:
%     x_best  - 1 x D binary vector (selected items)
%     f_best  - 1 x M row vector of objective values (minimisation form)

    [M, D] = size(P);
    capacity = sum(W, 2)' / 2;  % 1 x M (half total weight per knapsack)

    % Scalarise profits and weights
    scalarP = weight_vector * P;  % 1 x D
    scalarW = weight_vector * W;  % 1 x D

    % Sort items by profit-to-weight ratio (descending)
    ratio = scalarP ./ max(scalarW, 1e-12);
    [~, order] = sort(ratio, 'descend');

    x = zeros(1, D);
    currentWeight = zeros(1, M);

    for i = 1:D
        item = order(i);
        newWeight = currentWeight + W(:, item)';
        if all(newWeight <= capacity)
            x(item) = 1;
            currentWeight = newWeight;
        end
    end

    x_best = x;
    f_best = sum(P, 2)' - x * P';  % MOKP objectives: total_profit - packed_profit
end
