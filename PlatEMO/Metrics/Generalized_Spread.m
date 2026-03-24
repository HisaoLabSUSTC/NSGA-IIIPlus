function score = Generalized_Spread(Population, optimum)
% Spread metric customized to align with Zhou et al. (2006)
% "Combining Model-based and Genetics-based Offspring Generation..."
% 
% This calculates the distance from the true Pareto optimal set (S*) 
% to the achieved solutions (S).

    PopObj = Population.best.objs;
    
    if size(PopObj,2) ~= size(optimum,2)
        score = nan;
    else
        % Find the m extreme solutions in S* (optimum)
        [~, E] = max(optimum, [], 1);
        extreme_S_star = optimum(E, :);

        % Calculate squared Euclidean distance between S* and S
        % d(X, S) = min ||F(X) - F(Y)||^2
        Dis = pdist2(optimum, PopObj, 'squaredeuclidean');
        d_X_S = min(Dis, [], 2);
        
        % Calculate the distances for the extreme solutions e_i in S* to S
        Dis_e = pdist2(extreme_S_star, PopObj, 'squaredeuclidean');
        d_e_S = min(Dis_e, [], 2);
        sum_d_e_S = sum(d_e_S);
        
        % Calculate the mean distance \bar{d}
        d_bar = mean(d_X_S);
        
        % Calculate the Delta metric
        numerator = sum_d_e_S + sum(abs(d_X_S - d_bar));
        denominator = sum_d_e_S + size(optimum, 1) * d_bar;
        
        score = numerator / denominator;
    end
end