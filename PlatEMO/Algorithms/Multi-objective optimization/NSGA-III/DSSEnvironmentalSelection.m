function [Population, DSSSelectedIdx] = DSSEnvironmentalSelection(Population,N,Z,NormStruct,visualize,iter,cornerIdx)
% The environmental selection of NSGA-III with Distance-based Subset Selection
%
% INPUT:
%   Population : combined population (parents + offspring)
%   N          : target population size
%   Z          : reference points
%   NormStruct : normalization structure with ideal_point and nadir_point
%   visualize  : (optional) if true, visualize the DSS selection procedure
%   iter       : (optional) iteration number for visualization filename
%   cornerIdx  : (optional) indices into Population of corner solutions
%                 to preserve. Only used when MaxFNo == 1.
%
% OUTPUT:
%   Population     : selected population
%   DSSSelectedIdx : indices of solutions selected via DSS (in the last front)

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
    if nargin < 7
        cornerIdx = [];
    end

    %% Non-dominated sorting
    [FrontNo,MaxFNo] = NDSort(Population.objs,Population.cons,N);
    Next = FrontNo < MaxFNo;

    %% Preserve corner solutions (Y variant)
    % Corner solutions can only be lost when the critical front is the
    % first nondominated front (MaxFNo == 1), since they are nondominated
    % by definition. Indices were computed during ideal point update at
    % O(1) additional cost per objective.
    if MaxFNo == 1
        Next(cornerIdx) = true;
    else
        cornerIdx = [];
    end

    %% Select the solutions in the last front
    Last   = find(FrontNo==MaxFNo & ~Next);
    K      = N - sum(Next);
    PopObj1 = Population(Next).objs;
    PopObj2 = Population(Last).objs;

    DSSSelectedIdx = [];
    NichedIdx = [];
    if K > 0 && ~isempty(Last)
        [Choose, DSSSelectedIdx, NichedIdx] = LastSelection(PopObj1,PopObj2,K,Z,NormStruct,cornerIdx);
        Next(Last(Choose)) = true;
    end

    %% Visualization (for unit testing)
    if visualize
        VisualizeSubsetSelection(PopObj1, PopObj2, DSSSelectedIdx, NichedIdx, sprintf('%s.png', num2str(iter)));
    end

    % Population for next generation
    Population = Population(Next);
end

function [Choose, DSSSelectedIdx, NichedIdx] = LastSelection(PopObj1,PopObj2,K,Z,NormStruct,cornerIdx)
% Select part of the solutions in the last front using DSS for non-niched

    Zmin = NormStruct.ideal_point;
    if isempty(cornerIdx)
        PopObj = [PopObj1;PopObj2];
        N1 = size(PopObj1,1);
    else
        PopObj = PopObj2;
        N1 = 0;
    end
    [N,M]  = size(PopObj);
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

    % Precompute distance matrices for DSS (computed once per generation)
    PopObj1Norm = PopObjNorm(1:N1,:);
    PopObj2Norm = PopObjNorm(N1+1:end,:);

    % D_within(i,j) = Euclidean distance between last-front candidates i and j
    D_within = pdist2(PopObj2Norm, PopObj2Norm, 'euclidean');

    % Initialize minDist: for each candidate, minimum distance to any
    % already-selected solution (from higher fronts)
    if N1 > 0
        D_to_fixed = pdist2(PopObj2Norm, PopObj1Norm, 'euclidean');
        minDist = min(D_to_fixed, [], 2);
    else
        minDist = Inf(N2, 1);
    end

    % Track which solutions were selected via DSS (non-niched) vs niched selection
    DSSSelectedIdx = [];
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
                chosen = I(s);
                Choose(chosen) = true;
                NichedIdx = [NichedIdx, chosen];
            else
                % DSS: select from ALL remaining the one with max min-distance
                allRemainingIdx = find(Choose==0);
                if ~isempty(allRemainingIdx)
                    [~, s_global] = max(minDist(allRemainingIdx));
                    chosen = allRemainingIdx(s_global);
                    Choose(chosen) = true;
                    DSSSelectedIdx = [DSSSelectedIdx, chosen];
                end
            end
            % Update minDist with the newly selected solution
            minDist = min(minDist, D_within(:, chosen));
            rho(j) = rho(j) + 1;
        else
            Zchoose(j) = false;
        end
    end
end
