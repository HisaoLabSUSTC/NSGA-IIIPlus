classdef NSGAIIIwH < ALGORITHM
% <multi/many> <real/integer/label/binary/permutation> <constrained/none>
% Nondominated sorting genetic algorithm III

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
%% With Heuristic Solutions

    methods
        function main(Algorithm,Problem)
            %% Generate the reference points and random population
            % rng(2042);

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
            
            % NormStruct = PlNormalizationHistory(Problem.M, Problem.N);
            % %% We are currently dealing with unconstrained MOPs, so this is fine
            % NormStruct.update(Population(all(Population.cons<=0,2)).objs);

            Zmin          = min(Population(all(Population.cons<=0,2)).objs,[],1);

            Offspring = Population; % modded store sequence
            %% Optimization
            while Algorithm.NotTerminatedMod(Population,Offspring)
                MatingPool = TournamentSelection(2,Problem.N,sum(max(0,Population.cons),2));
                Offspring  = OperatorGA(Problem,Population(MatingPool));

                % disp(NormStruct);pause(1);
                % Mixture = [Population,Offspring];
                % NormStruct.update(Mixture(all(Mixture.cons<=0,2)).objs);

                Zmin       = min([Zmin;Offspring(all(Offspring.cons<=0,2)).objs],[],1);
                Population = PlEnvironmentalSelection([Population,Offspring],Problem.N,Z,Zmin);
                % if Problem.FE >= Problem.maxFE
                %     VisualizeMindistPopulation(str2func(class(Algorithm)), Population, Z, Problem);
                %     return
                % end
            end
        end
    end
end