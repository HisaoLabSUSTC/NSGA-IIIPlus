classdef MOKP < PROBLEM
% <multi/many> <binary> <large/none> <constrained>
% The multi-objective knapsack problem
% ID --- 1 --- ID parameter

%------------------------------- Reference --------------------------------
% E. Zitzler and L. Thiele, Multiobjective evolutionary algorithms: A
% comparative case study and the strength Pareto approach, IEEE
% Transactions on Evolutionary Computation, 1999, 3(4): 257-271.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2024 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    properties(Access = public)
        P;	% Profit of each item according to each knapsack
        W;  % Weight of each item according to each knapsack
        ID;
    end
    methods
        %% Default settings of the problem
        function Setting(obj)
            % Parameter setting
            [ID] = obj.ParameterSet(1);

            obj.ID = ID;
            if isempty(obj.M); obj.M = 2; end
            if isempty(obj.D); obj.D = 250; end
            obj.encoding = 4 + zeros(1,obj.D);
            % Randomly generate profits and weights
            file = sprintf('MOKP-M%d-D%d-%d.mat',obj.M,obj.D,obj.ID);
            file = fullfile(fileparts(mfilename('fullpath')),file);
            if exist(file,'file') == 2
                load(file,'P','W');
            else
                P = randi([10,100],obj.M,obj.D);
                W = randi([10,100],obj.M,obj.D);
                save(file,'P','W');
            end
            obj.P = P;
            obj.W = W;
        end
        %% Calculate objective values
        function PopObj = CalObj(obj,PopDec)
            PopObj = repmat(sum(obj.P,2)',size(PopDec,1),1) - PopDec*obj.P';
        end
        %% Calculate constraint violations
        function PopCon = CalCon(obj,PopDec)
            PopCon = PopDec*obj.W' - repmat(sum(obj.W,2)'/2,size(PopDec,1),1);
        end
        %% Generate a point for hypervolume calculation
        function R = GetOptimum(obj,~)
            R = sum(obj.P,2)';
        end
        %% Display a population in the objective space
        function DrawObj(obj,Population)
            Draw(Population.decs*obj.P',{'\it f\rm_1','\it f\rm_2','\it f\rm_3'});
        end
    end
end
