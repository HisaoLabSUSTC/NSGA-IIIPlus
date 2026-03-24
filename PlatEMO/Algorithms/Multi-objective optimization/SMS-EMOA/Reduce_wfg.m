function [Population,FrontNo] = Reduce_wfg(Population,FrontNo)
% Delete one solution from the population

%------------------------------- Copyright --------------------------------
% Copyright (c) 2023 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% Identify the solutions in the last front
    FrontNo   = UpdateFront(Population.objs,FrontNo);
    LastFront = find(FrontNo==max(FrontNo));
    PopObj    = Population(LastFront).objs;
    [N,~]     = size(PopObj);
    
    %% Calculate the contribution of hypervolume of each solution
    deltaS = inf(1,N);
    ref = RefGetter(Population(LastFront), 1.1);

    for i=1:N
        deltaS(i) = CalHVC(PopObj, ref, i);
    end

    
    %% Delete the worst solution from the last front
    [~,worst] = min(deltaS);
    FrontNo   = UpdateFront(Population.objs,FrontNo,LastFront(worst));
    Population(LastFront(worst)) = [];
end

function HVC = CalHVC(PopObj, RefPoint, i)
    data = PopObj;
    s = data(i, :);
    data(i, :) = [];
    data = max(s, data);
    HVC = prod(RefPoint-s)-stk_dominatedhv(data, RefPoint);
end