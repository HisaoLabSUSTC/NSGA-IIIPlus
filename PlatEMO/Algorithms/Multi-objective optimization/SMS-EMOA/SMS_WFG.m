classdef SMS_WFG < ALGORITHM
% <multi> <real/integer/label/binary/permutation>
% S metric selection based evolutionary multiobjective optimization
% algorithm

%------------------------------- Reference --------------------------------
% M. Emmerich, N. Beume, and B. Naujoks, An EMO algorithm using the
% hypervolume measure as selection criterion, Proceedings of the
% International Conference on Evolutionary Multi-Criterion Optimization,
% 2005, 62-76.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2023 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    methods
        function main(Algorithm,Problem)
            %% Generate random population
            Population = Problem.Initialization();
            FrontNo    = NDSort(Population.objs,inf);

            %% Optimization
            while Algorithm.NotTerminated(Population)
                for i = 1 : Problem.N
                    drawnow('limitrate');
                    Offspring = OperatorGAhalf(Problem,Population(randperm(end,2)));
                    f = @() Reduce_wfg([Population, Offspring], FrontNo);
                    t = timeit(f);
                    n = Problem.N;
                    m = Problem.M;
                    results = [n, m, t];
                    
                    if isfile('timing_log.mat')
                        load('timing_log.mat', 'all_results');
                        all_results(end+1, :) = results;
                    else
                        all_results = results;
                    end

                    save('timing_log.mat', 'all_results');

                    return

                    [Population,FrontNo] = Reduce([Population,Offspring],FrontNo);
                end
            end
        end
    end
end