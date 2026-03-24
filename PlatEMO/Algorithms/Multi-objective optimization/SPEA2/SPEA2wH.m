classdef SPEA2wH < ALGORITHM
% <multi> <real/integer/label/binary/permutation>
% Strength Pareto evolutionary algorithm 2 (with heuristic initialization)

%------------------------------- Reference --------------------------------
% E. Zitzler, M. Laumanns, and L. Thiele, SPEA2: Improving the strength
% Pareto evolutionary algorithm, Proceedings of the Conference on
% Evolutionary Methods for Design, Optimization and Control with
% Applications to Industrial Problems, 2001, 95-100.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2024 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    methods
        function main(Algorithm,Problem)
            %% Generate population (with optional heuristic initialization)
            [HID] = Algorithm.ParameterSet("");
            if HID == ""
                Population = Problem.Initialization();
            else
                data = load(HID, 'heuristic_solutions').heuristic_solutions;
                initial_n = size(data, 1);
                if Problem.N - initial_n > 0
                    other_pop = Problem.Initialization(Problem.N - initial_n);
                else
                    other_pop = [];
                end
                heur_pop = Problem.Evaluation(data);
                Population = [heur_pop, other_pop];
            end
            Fitness = CalFitness(Population.objs);

            %% Optimization
            while Algorithm.NotTerminated(Population)
                MatingPool = TournamentSelection(2,Problem.N,Fitness);
                Offspring  = OperatorGA(Problem,Population(MatingPool));
                [Population,Fitness] = EnvironmentalSelection([Population,Offspring],Problem.N);
            end
        end
    end
end
