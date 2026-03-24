classdef RWA3 < PROBLEM
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
                obj.D = 3;
            end
            obj.lower    = [0.25,10000,600];
            obj.upper    = [0.55,20000,1100];
            obj.encoding = ones(1,obj.D);
        end
        %% Calculate objective values
        function PopObj = CalObj(obj,PopDec)
            M      = obj.M;
            PopObj = zeros(size(PopDec,1),M);
            O2CH4 = PopDec(:,1);
            GV = PopDec(:,2);
            T = PopDec(:,3);

            PopObj(:,1) = -1*((-8.87e-6) ...
			    * (86.74 + 14.6 * O2CH4 - 3.06 * GV + 18.82 * T + 3.14 * O2CH4 .* GV ...
					    - 6.91 * O2CH4 .* O2CH4 - 13.31 * T .* T));
            PopObj(:,2) = -1*((-2.152e-9) ...
			    * (39.46 + 5.98 * O2CH4 - 2.4 * GV + 13.06 * T + 2.5 * O2CH4 .* GV ...
					    + 1.64 * GV .* T - 3.9 * O2CH4 .* O2CH4 - 10.15 * T .* T ...
					    - 3.69 * GV .* GV .* O2CH4) + 45.7);
            PopObj(:,3) = (4.425e-10) ...
					* (1.29 - 0.45 * T - 0.112 * O2CH4 .* GV - 0.142 * T .* GV ...
							+ 0.109 * O2CH4 .* O2CH4 + 0.405 * T .* T ...
							+ 0.167 * T .* T .* GV) + 0.18;
        end
        %% Generate points on the Pareto front

        
        function R = GetOptimum(obj,N)
            R = load('RWA3.mat').PF;
        end
    end
end