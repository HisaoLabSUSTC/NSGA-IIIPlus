classdef DSSPyNSGAIIIwH < ALGORITHM
% <multi/many> <real/integer/label/binary/permutation> <constrained/none>
% Nondominated sorting genetic algorithm III with Distance-based Subset Selection

%------------------------------- Reference --------------------------------
% K. Deb and H. Jain, An evolutionary many-objective optimization algorithm
% using reference-point based non-dominated sorting approach, part I:
% Solving problems with box constraints, IEEE Transactions on Evolutionary
% Computation, 2014, 18(4): 577-601.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2024 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------
%% With Heuristic Solutions + Distance-based Subset Selection

    methods
        function main(Algorithm,Problem)
            %% Generate the reference points and random population
            [HID] = Algorithm.ParameterSet("");

            [Z,Problem.N] = UniformPoint(Problem.N,Problem.M);

            if HID==""
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

            NormStruct = PyNormalizationHistory(Problem.M);
            [FrontNo, ~] = NDSort(Population.objs, Population.cons, 1);
            nds = find(FrontNo==1);
            NormStruct.update(Population(all(Population.cons<=0,2)).objs, nds);

            Offspring = Population; % modded store sequence
            %% Optimization
            while Algorithm.NotTerminatedMod(Population,Offspring)
                MatingPool = TournamentSelection(2,Problem.N,sum(max(0,Population.cons),2));
                Offspring  = OperatorGA(Problem,Population(MatingPool));

                Mixture = [Population,Offspring];
                [FrontNo, ~] = NDSort(Mixture.objs, Mixture.cons, 1);
                nds = find(FrontNo==1);
                NormStruct.update(Mixture(all(Mixture.cons<=0,2)).objs, nds);
                Population = DSSEnvironmentalSelection(Mixture,Problem.N,Z,NormStruct,false);

                % if Problem.FE >= Problem.maxFE
                %     VisualizeMindistPopulation(str2func(class(Algorithm)), Population, Z, Problem, Problem.FE, NormStruct);
                %     return
                % end
            end
        end
    end
end
