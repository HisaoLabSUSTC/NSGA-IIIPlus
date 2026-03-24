classdef ConfigurableNSGAIIIwH < ALGORITHM
% <multi/many> <real/integer/label/binary/permutation> <constrained/none>
% Configurable NSGA-III with modular components
%
%   A unified algorithm class that supports NSGA-III variants through
%   configuration rather than separate class files.
%
%   Configuration groups:
%     Area 1 - Implementation:
%       removeThreshold (Z): remove 1e-3 ASF threshold
%       preserveCorners (Y): preserve corner solutions
%       useArchive (X): unbounded extreme point archive
%       Default (none) = baseline
%
%     Area 2 - Normalization:
%       momentum: 'none', 'tikhonov' (Tk)
%
%     Area 3 - Selection:
%       useDSS: true/false (Distance-based Subset Selection)
%
%   Usage:
%     config = struct('removeThreshold', true, 'preserveCorners', true, ...
%                     'momentum', 'tikhonov', 'useDSS', true);
%     platemo('algorithm', {@ConfigurableNSGAIIIwH, config}, ...)
%
%     % Or with heuristic file:
%     platemo('algorithm', {@ConfigurableNSGAIIIwH, config, 'heuristic.mat'}, ...)

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

    methods
        function main(Algorithm, Problem)
            %% Parse parameters
            % First param can be config struct or HID string
            % If config struct, second param can be HID
            [param1, param2] = Algorithm.ParameterSet(struct(), "");

            if isstruct(param1)
                config = param1;
                HID = param2;
            else
                % Legacy: first param is HID
                config = struct();
                HID = param1;
            end

            % Merge with defaults via parseAlgConfig
            config = parseAlgConfig(config);

            %% Set save name based on config
            [~, internalName] = config2name(config);
            Algorithm.SetSaveName(internalName);

            %% Generate reference points
            [Z, Problem.N] = UniformPoint(Problem.N, Problem.M);
            Z = sortrows(Z);

            %% Inject T_max (total generations estimate)
            % Must happen after UniformPoint (which may adjust Problem.N).
            config.T_max = round(Problem.maxFE / Problem.N);

            %% Initialize population
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

            %% Initialize normalization structure
            NormStruct = ModularNormHist(Problem.M, config);

            [FrontNo, ~] = NDSort(Population.objs, Population.cons, 1);
            nds = find(FrontNo == 1);
            NormStruct.update(Population(all(Population.cons <= 0, 2)).objs, nds, Problem.N);

            %% Select environmental selection function
            if config.useDSS
                envSelectFunc = @DSSEnvironmentalSelection;
            else
                envSelectFunc = @PymooEnvironmentalSelection;
            end

            Offspring = Population;

            %% Main optimization loop
            while Algorithm.NotTerminatedMod(Population, Offspring)
                selectFn = @() TournamentSelection(2, Problem.N, sum(max(0, Population.cons), 2));
                Offspring = OperatorGA(Problem, Population(selectFn()));

                Mixture = [Population, Offspring];
                [FrontNo, ~] = NDSort(Mixture.objs, Mixture.cons, 1);
                nds = find(FrontNo == 1);
                NormStruct.update(Mixture(all(Mixture.cons <= 0, 2)).objs, nds, Problem.N);

                % Identify corner solutions via PBI (Y variant)
                % Per-axis PBI: g = d1 + theta*d2 where d1 is the
                % projection along the axis and d2 is the perpendicular
                % distance. theta=5 (Zhang & Li, 2007). This penalises
                % dominance-resistant solutions that have tiny f_i but
                % huge f_j on the other objectives.
                cornerIdx = [];
                if config.preserveCorners
                    % nObj = size(Mixture.objs, 2);
                    % shifted = Mixture.objs - NormStruct.ideal_point;
                    % normSq = sum(shifted.^2, 2);
                    % allCorners = zeros(1, nObj);
                    % theta = 1;
                    % for ci = 1:nObj
                    %     d1 = shifted(:, ci);
                    %     d2 = sqrt(max(normSq - d1.^2, 0));
                    %     pbi = d1 + theta * d2;
                    %     [~, allCorners(ci)] = min(pbi);
                    % end
                    [~, allCorners] = min(Mixture.objs);
                    cornerIdx = unique(allCorners);
                end

                if config.useDSS
                    [Population, ~] = envSelectFunc(Mixture, Problem.N, Z, NormStruct, false, [], cornerIdx);
                else
                    Population = envSelectFunc(Mixture, Problem.N, Z, NormStruct, cornerIdx);
                end

                % if Problem.FE >= Problem.maxFE
                %     VisualizeMindistPopulation(str2func(class(Algorithm)), Population, Z, Problem);
                %     return
                % end
            end
        end
    end
end
