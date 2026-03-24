function [Population, DSSSelectedIdx] = PycDSSEnvironmentalSelection(Population,N,Z,NormStruct,visualize,iter)
% The environmental selection of NSGA-III with Distance-based Subset Selection
%
% INPUT:
%   Population : combined population (parents + offspring)
%   N          : target population size
%   Z          : reference points
%   NormStruct : normalization structure with ideal_point and nadir_point
%   visualize  : (optional) if true, visualize the DSS selection procedure
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

    %% Non-dominated sorting
    [FrontNo,MaxFNo] = NDSort(Population.objs,Population.cons,N);
    Next = FrontNo < MaxFNo;

    %% Select the solutions in the last front
    Last   = find(FrontNo==MaxFNo);
    PopObj1 = Population(Next).objs;
    PopObj2 = Population(Last).objs;

    [Choose, DSSSelectedIdx, NichedIdx] = LastSelection(PopObj1,PopObj2,N-sum(Next),Z,NormStruct);
    Next(Last(Choose)) = true;

    %% Visualization (for unit testing)
    if visualize
        VisualizeSubsetSelection(PopObj1, PopObj2, DSSSelectedIdx, NichedIdx, sprintf('%s.png', num2str(iter)));
    end

    % Population for next generation
    Population = Population(Next);
end

function [Choose, DSSSelectedIdx, NichedIdx] = LastSelection(PopObj1,PopObj2,K,Z,NormStruct)
% Select part of the solutions in the last front using DSS for non-niched

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

    % Track which solutions were selected via DSS (non-niched) vs niched selection
    DSSSelectedIdx = [];
    NichedIdx = [];

    if size(PopObj2, 1) == 1
        Choose(1) = true;
        return
    end
    corner_count = 0;
    [~, corner_i] = min(PopObj2);
    corner_i = unique(corner_i);
    
    % Select K solutions one by one
    while sum(Choose) < K
        %% Preserve M corner solutions
        if corner_count < numel(corner_i)
            Choose(corner_i(corner_count + 1)) = true;
            corner_count = corner_count + 1;
            continue
        end
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
                % DSS: Distance-based Subset Selection for non-niched
                % Select from ALL remaining unselected last-front solutions
                % Distance computed to ALL already-selected solutions (PopObj1 + chosen from last front)
                allRemainingIdx = find(Choose==0);
                if ~isempty(allRemainingIdx)
                    s_global = DSSSelect(allRemainingIdx, PopObj1Norm, PopObj2Norm, Choose);
                    Choose(allRemainingIdx(s_global)) = true;
                    DSSSelectedIdx = [DSSSelectedIdx, allRemainingIdx(s_global)];
                end
            end
            rho(j) = rho(j) + 1;
        else
            Zchoose(j) = false;
        end
    end
end

function s = DSSSelect(candidateIdx, PopObj1Norm, PopObj2Norm, Choose)
% Distance-based Subset Selection
% Select from ALL remaining candidates the one with maximum minimum distance
% to ALL already-selected solutions (PopObj1 + chosen from PopObj2)

    chosenFromLastFront = find(Choose);

    % Combine already-selected: all from PopObj1 + chosen from PopObj2
    if isempty(chosenFromLastFront)
        alreadySelectedObjs = PopObj1Norm;
    else
        alreadySelectedObjs = [PopObj1Norm; PopObj2Norm(chosenFromLastFront, :)];
    end

    if isempty(alreadySelectedObjs)
        % No solutions selected yet, pick randomly
        s = randi(length(candidateIdx));
        return;
    end

    % Get objectives of candidates (all remaining unselected from last front)
    candidateObjs = PopObj2Norm(candidateIdx, :);

    % Compute pairwise distances between candidates and all selected solutions
    Dist = pdist2(candidateObjs, alreadySelectedObjs, 'euclidean');

    % For each candidate, find minimum distance to any selected solution
    minDist = min(Dist, [], 2);

    % Select candidate with maximum minimum distance
    [~, s] = max(minDist);
end
