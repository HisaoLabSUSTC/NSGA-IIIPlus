classdef RWA10 < PROBLEM
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
                obj.M = 7;
            end
            if isempty(obj.D)
                obj.D = 3;
            end
            obj.lower    = [10,10,150];
            obj.upper    = [50,50,170];
            obj.encoding = ones(1,obj.D);
        end
        %% Calculate objective values
        function PopObj = CalObj(obj,PopDec)
            M      = obj.M;
            PopObj = zeros(size(PopDec,1),M);
            X1 = PopDec(:,1);
            X2 = PopDec(:,2);
            X3 = PopDec(:,3);

            PopObj(:,1) = -1*(-1331.04 + 1.99 * X1 + 0.33 * X2 + 17.12 * X3 - 0.02 * X1 .* X1 ...
			    - 0.05 * X3 .* X3 - 15.33);
            PopObj(:,2) = -1*(-4231.14 + 4.27 * X1 + 1.50 * X2 + 52.30 * X3 - 0.04 * X1 .* X2 ...
			    - 0.04 * X1 .* X1 - 0.16 * X3 .* X3 - 29.33);
            PopObj(:,3) = -1*(1766.80 - 32.32 * X1 - 24.56 * X2 - 10.48 * X3 + 0.24 * X1 .* X3 ...
			    + 0.19 * X2 .* X3 - 0.06 * X1 .* X1 - 0.10 * X2 .* X2 - 413.33);
            PopObj(:,4) = -1*(-2342.13 - 1.556 * X1 + 0.77 * X2 + 31.14 * X3 + 0.03 * X1 .* X1 ...
			    - 0.10 * X3 .* X3 - 73.33);
            PopObj(:,5) = 9.34 + 0.02 * X1 - 0.03 * X2 - 0.03 * X3 - 0.001 * X1 .* X2 ...
			    + 0.0009 * X2 .* X2 + 0.22;
            PopObj(:,6) = -1*(1954.71 + 14.246 * X1 + 5.00 * X2 - 4.30 * X3 - 0.22 * X1 .* X1 ...
			    - 0.33 * X2 .* X2 - 8413.33);
            PopObj(:,7) = -1*(828.16 + 3.55 * X1 + 73.65 * X2 + 10.80 * X3 - 0.56 * X2 .* X3 ...
			    + 0.20 * X2 .* X2 - 2814.83);
        end
        %% Generate points on the Pareto front

        
        function R = GetOptimum(obj,N)
            R = load('RWA10.mat').PF;
        end
    end
end