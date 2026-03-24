classdef PopulationHistory < handle
    %POPULATIONHISTORY Store population and offspring data across generations.
    %   Accumulates the decision, objective, and constraint matrices for
    %   each generation during a PlatEMO run.
    %
    %   Example:
    %       pophist = PopulationHistory(200); % preallocate 200 generations
    %       pophist.add(Population, Offspring);
    %       save('history.mat', 'pophist', '-v7.3');

    properties
        history  % struct array of generation data
        gen = 1  % current generation counter
    end

    methods
        function obj = PopulationHistory(prealloc)
            % Constructor optionally preallocates history array
            if nargin < 1, prealloc = 0; end

            if prealloc > 0
                % Preallocate as empty struct array for efficiency
                emptyGen = struct('pop', [], 'off', []);
                obj.history(1:prealloc) = emptyGen;
            else
                obj.history = struct('pop', {}, 'off', {});
            end
        end

        function add(obj, Population, Offspring)
            %ADD Add a generation's population and offspring to history
            if nargin < 2 || isempty(Population)
                popStruct = struct('decs', [], 'objs', [], 'cons', []);
            else
                popStruct = struct( ...
                    'decs', Population.decs, ...
                    'objs', Population.objs, ...
                    'cons', Population.cons);
            end

            if nargin < 3 || isempty(Offspring)
                offStruct = struct('decs', [], 'objs', [], 'cons', []);
            else
                offStruct = struct( ...
                    'decs', Offspring.decs, ...
                    'objs', Offspring.objs, ...
                    'cons', Offspring.cons);
            end

            % Expand history if needed
            if obj.gen > numel(obj.history)
                obj.history(obj.gen).pop = [];
                obj.history(obj.gen).off = [];
            end

            obj.history(obj.gen).pop = popStruct;
            obj.history(obj.gen).off = offStruct;
            obj.gen = obj.gen + 1;
        end

        function n = numGenerations(obj)
            %NUMGENERATIONS Return how many generations have been recorded
            n = obj.gen - 1;
        end

        function clear(obj)
            %CLEAR Reset all stored data
            obj.history = struct('pop', {}, 'off', {});
            obj.gen = 1;
        end
    end
end
