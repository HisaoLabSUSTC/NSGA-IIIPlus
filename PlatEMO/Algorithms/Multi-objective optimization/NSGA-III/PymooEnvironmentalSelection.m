function Population = PymooEnvironmentalSelection(Population,N,Z,NormStruct,cornerIdx)
% The environmental selection of NSGA-III
%
% INPUT:
%   Population : combined population (parents + offspring)
%   N          : target population size
%   Z          : reference points
%   NormStruct : normalization structure with ideal_point and nadir_point
%   cornerIdx  : (optional) indices into Population of corner solutions
%                 to preserve. Only used when MaxFNo == 1.

%------------------------------- Copyright --------------------------------
% Copyright (c) 2024 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    if nargin < 5
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
    if K > 0 && ~isempty(Last)
        Choose = LastSelection(Population(Next).objs,Population(Last).objs,K,Z,NormStruct,cornerIdx);
        Next(Last(Choose)) = true;
    end
    % Population for next generation
    Population = Population(Next);
end

function Choose = LastSelection(PopObj1,PopObj2,K,Z,NormStruct,cornerIdx)
% Select part of the solutions in the last front

    Zmin = NormStruct.ideal_point;
    if isempty(cornerIdx)
        PopObj = [PopObj1;PopObj2];
        N1 = size(PopObj1,1);
    else
        % close all
        % PreprocessProductionImage(0.4, 1, 8.8)
        % fig = gcf; ax = gca;
        % cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        % 
        % plot3(ax,PopObj2(:,1),PopObj2(:,2),PopObj2(:,3),'.r', 'MarkerSize', 25);
        % plot3(ax,PopObj1(:,1),PopObj1(:,2),PopObj1(:,3),'.g', 'MarkerSize', 55);
        % 
        % view(ax, 135, 30);
        % xlabel('$f_1$', 'Interpreter', 'latex')
        % ylabel('$f_2$', 'Interpreter', 'latex')
        % zlabel('$f_3$', 'Interpreter', 'latex')
        % rng
        % pause(5)
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

    PopObj = (PopObj-Zuto)./(denom);

    %% Associate each solution with one reference point
    % Calculate the distance of each solution to each reference vector
    Cosine   = 1 - pdist2(PopObj,Z,'cosine');
    Distance = repmat(sqrt(sum(PopObj.^2,2)),1,NZ).*sqrt(1-Cosine.^2);
    % Associate each solution with its nearest reference point
    [d,pi] = min(Distance',[],1);

    %% Calculate the number of associated solutions except for the last front of each reference point
    rho = hist(pi(1:N1),1:NZ);

    %% Environmental selection
    Choose  = false(1,N2);
    Zchoose = true(1,NZ);
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
                [~,s] = min(d(N1+I));
            else
                s = randi(length(I));
            end
            Choose(I(s)) = true;
            rho(j) = rho(j) + 1;
        else
            Zchoose(j) = false;
        end
    end
end
