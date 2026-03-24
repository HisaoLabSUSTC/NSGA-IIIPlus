function [P_others, P_mindist] = ComputeMindist(Population, Problem, Z, NormStruct)
    if nargin < 4
        NormStruct = PyNormalizationHistory(Problem.M);
        F = Population.objs;
        [FrontNo, ~] = NDSort(F, 1);
        nds = find(FrontNo == 1);
        NormStruct.update(F, nds);
    end
    F = Population.objs;

    Zmin = NormStruct.ideal_point;
    Zmax = NormStruct.nadir_point;
    denom = Zmax-Zmin;
    denom(denom == 0) = 1e-12;
    FF = (F-Zmin)./denom;
    
    N=numel(Population); NZ = size(Z,1);
    Cosine   = 1 - pdist2(FF,Z,'cosine');
    Distance = repmat(sqrt(sum(FF.^2,2)),1,NZ).*sqrt(1-Cosine.^2);
    %% Distance: (i, j) means ith solution to jth reference vector
    [d,pi] = min(Distance',[],1);
    %% Distance': (i, j) means ith reference vector to jth solution
    %% d: dist of solution i to the assigned reference vector pi(i)
    rho = hist(pi(1:N),1:NZ);
    %% rho: count of solutions at niche i
    l_mindist = zeros(1, N);
    for i=1:NZ
        if rho(i) == 0
            continue
        elseif rho(i) == 1
            l_mindist(pi==i) = 1;
        else
            l_mindist(d==min(d(pi==i))) = 1;
        end
    end

    l = l_mindist==1;
    P_mindist = Population(l);
    P_others = Population(~l);
end