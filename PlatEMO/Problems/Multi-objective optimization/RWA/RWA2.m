classdef RWA2 < PROBLEM
% <multi/many> <real> <large/none> <expensive/none>
% Engineering applications of multi-objective evolutionary algorithms: A test suite of box-constrained real-world problems

%------------------------------- Reference --------------------------------
% This is a two-objective version of the reinforced concrete beam design problem.
% 
% Reference:
% H. M. Amir and T. Hasegawa, "Nonlinear Mixed-Discrete Structural Optimization," J. Struct. Eng., vol. 115, no. 3, pp. 626-646, 1989.
%
%  Copyright (c) 2018 Ryoji Tanabe
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.

% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.

% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
%--------------------------------------------------------------------------

    methods
        %% Default settings of the problem
        function Setting(obj)
            if isempty(obj.M)
                obj.M = 3;
            end
            if isempty(obj.D)
                obj.D = 5;
            end
            obj.lower    = [1,1,1,1,1];
            obj.upper    = [3,3,3,3,3];
            obj.encoding = ones(1,obj.D);
        end
        %% Calculate objective values
        function PopObj = CalObj(obj,PopDec)
            M      = obj.M;
            PopObj = zeros(size(PopDec,1),M);
            t1 = PopDec(:,1);
            t2 = PopDec(:,2);
            t3 = PopDec(:,3);
            t4 = PopDec(:,4);
            t5 = PopDec(:,5);

            PopObj(:,1) = 1640.2823 + 2.3573285 * t1 + 2.3220035 * t2 + 4.5688768 * t3 ...
			    + 7.7213633 * t4 + 4.4559504 * t5;
            PopObj(:,2) = 6.5856 + 1.15 * t1 - 1.0427 * t2 + 0.9738 * t3 + 0.8364 * t4 ...
			    - 0.3695 * t1 .* t4 + 0.0861 * t1 .* t5 + 0.3628 * t2 .* t4 ...
			    - 0.1106 * t1 .* t1 - 0.3437 * t3 .* t3 + 0.1764 * t4 .* t4;
            PopObj(:,3) = -0.0551 + 0.0181 * t1 + 0.1024 * t2 + 0.0421 * t3 ...
			    - 0.0073 * t1 .* t2 + 0.024 * t2 .* t3 - 0.0118 * t2 .* t4 ...
			    - 0.0204 * t3 .* t4 - 0.008 * t3 .* t5 - 0.0241 * t2 .* t2 ...
			    + 0.0109 * t4 .* t4;
        end
        %% Generate points on the Pareto front
        function R = GetOptimum(obj,N)
            R = load('RWA2.mat').PF;
        end
    end
end