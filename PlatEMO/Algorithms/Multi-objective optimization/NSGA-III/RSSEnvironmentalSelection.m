function [Population, HSSSelectedIdx] = RSSEnvironmentalSelection(Population,N,Z,NormStruct,visualize,iter)
% The environmental selection of NSGA-III with Hypervolume-based Subset Selection
%
% INPUT:
%   Population : combined population (parents + offspring)
%   N          : target population size
%   Z          : reference points
%   NormStruct : normalization structure with ideal_point and nadir_point
%   visualize  : (optional) if true, visualize the HSS selection procedure
%
% OUTPUT:
%   Population     : selected population
%   HSSSelectedIdx : indices of solutions selected via HSS (in the last front)

%------------------------------- Copyright --------------------------------
% Copyright (c) 2024 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    if nargin < 5
        visualize = false;
    end

    %% Non-dominated sorting
    [FrontNo,MaxFNo] = NDSort(Population.objs,Population.cons,N);
    Next = FrontNo < MaxFNo;

    %% Select the solutions in the last front
    Last   = find(FrontNo==MaxFNo);
    PopObj1 = Population(Next).objs;
    PopObj2 = Population(Last).objs;

    [Choose, HSSSelectedIdx, NichedIdx] = LastSelection(PopObj1,PopObj2,N-sum(Next),Z,NormStruct,iter);
    Next(Last(Choose)) = true;

    %% Visualization (for unit testing)
    if visualize
        % HSSSelectedIdx
        VisualizeSubsetSelection(PopObj1, PopObj2, HSSSelectedIdx, NichedIdx, sprintf('%s.png', num2str(iter)));
    end

    % Population for next generation
    Population = Population(Next);
end

function [Choose, HSSSelectedIdx, NichedIdx] = LastSelection(PopObj1,PopObj2,K,Z,NormStruct,iter)
% Select part of the solutions in the last front using HSS for non-niched

    Zmin = NormStruct.ideal_point;
    PopObj = [PopObj1;PopObj2];
    [N,M]  = size(PopObj);
    N1     = size(PopObj1,1);
    N2     = size(PopObj2,1);
    NZ     = size(Z,1);

    %% Normalization
    Zmax = NormStruct.nadir_point;
    Zuto = Zmin-1e-6;
    denom = Zmax-Zmin;
    denom(denom==0) = 1e-12;

    PopObjNorm = (PopObj-Zuto)./(denom);

    %% Associate each solution with one reference point
    % Calculate the distance of each solution to each reference vector
    Cosine   = 1 - pdist2(PopObjNorm,Z,'cosine');
    Distance = repmat(sqrt(sum(PopObjNorm.^2,2)),1,NZ).*sqrt(1-Cosine.^2);
    % Associate each solution with its nearest reference point
    [d,pi] = min(Distance',[],1);

    %% Calculate the number of associated solutions except for the last front of each reference point
    rho = hist(pi(1:N1),1:NZ);

    %% Environmental selection
    Choose  = false(1,N2);
    Zchoose = true(1,NZ);

    % Store normalized objectives for distance calculation
    % PopObj1Norm: solutions from higher fronts (already selected)
    % PopObj2Norm: solutions from last front (candidates)
    PopObj1Norm = PopObjNorm(1:N1,:);
    PopObj2Norm = PopObjNorm(N1+1:end,:);

    %% HSS setup
    pideal = min(PopObj2Norm);
    pnadir = max(PopObj2Norm);
    H = getRefH(size(PopObj2Norm, 2), size(PopObj2Norm,1));
    ref = pideal + (1+1/H) * (pnadir-pideal);

    % Track which solutions were selected via HSS (non-niched) vs niched selection
    HSSSelectedIdx = [];
    NichedIdx = [];

    % Select K solutions one by one
    while sum(Choose) < K
        % Select the least crowded reference point
        Temp = find(Zchoose);
        Jmin = find(rho(Temp)==min(rho(Temp)));
        j    = Temp(Jmin(randi(length(Jmin))));
        I    = find(Choose==0 & pi(N1+1:end)==j);
        % Then select one solution associated with this reference point
        if ~isempty(I)
            if rho(j) == 0
                % Niched selection: pick closest to reference vector
                [~,s] = min(d(N1+I));
                Choose(I(s)) = true;
                NichedIdx = [NichedIdx, I(s)];
            else
                % HSS: Hypervolume-based Subset Selection for non-niched
                % Select from ALL remaining unselected last-front solutions
                s_global = HSSSelect(PopObj2Norm, Choose, ref);
                Choose(s_global) = true;
                HSSSelectedIdx(end+1) = s_global;
            end
            rho(j) = rho(j) + 1;
        else
            Zchoose(j) = false;
        end
    end
end

function s = HSSSelect(PopObj2Norm, Choose, ref)
% Hypervolume-based Subset Selection
% Select from ALL remaining candidates the one with maximum hypervolume
% contribution relative to the already-chosen subset

    left = find(~Choose);
    if numel(left) == 1
        s = left;
        return;
    end

    chosenFromLastFront = find(Choose);
    if isempty(chosenFromLastFront)
        selectedObjs = zeros(0, size(PopObj2Norm, 2));
    else
        selectedObjs = PopObj2Norm(chosenFromLastFront, :);
    end

    bestHVC = -inf;
    bestIdx = left(1);
    for i = left
        hvc = CalHVC(selectedObjs, ref, PopObj2Norm(i, :));
        if hvc > bestHVC
            bestHVC = hvc;
            bestIdx = i;
        end
    end
    s = bestIdx;
end

function HVC = CalHVC(selectedObjs, RefPoint, o)
% Exclusive hypervolume contribution of o relative to selectedObjs
%   HVC = HV(S U {o}) - HV(S)
%   Using the clamping trick: data = max(o, S), then
%   HVC = prod(RefPoint - o) - stk_dominatedhv(data, RefPoint)
    if isempty(selectedObjs)
        HVC = prod(RefPoint - o);
    else
        data = max(o, selectedObjs);
        HVC = prod(RefPoint - o) - stk_dominatedhv(data, RefPoint);
    end
end
