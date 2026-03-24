classdef RWA6 < PROBLEM
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
                obj.D = 4;
            end
            obj.lower    = [12.56,0.02,1,0.5];
            obj.upper    = [25.12,0.06,5,2];
            obj.encoding = ones(1,obj.D);
        end
        %% Calculate objective values
        function PopObj = CalObj(obj,PopDec)
            M      = obj.M;
            PopObj = zeros(size(PopDec,1),M);
            vc = PopDec(:,1);
            fz = PopDec(:,2);
            ap = PopDec(:,3);
            ae = PopDec(:,4);
            d = 2.5;
            z = 1;

            PopObj(:,1) = -54.3 - 1.18 * vc - 2429 * fz + 104.2 * ap + 129.0 * ae ...
			    - 18.9 * vc .* fz - 0.209 * vc .* ap - 0.673 * vc .* ae + 265 * fz .* ap ...
			    + 1209 * fz .* ae + 22.76 * ap .* ae + 0.066 * vc .* vc ...
			    + 32117 * fz .* fz - 16.98 * ap .* ap - 47.6 * ae .* ae;
            PopObj(:,2) = 0.227 - 0.0072 * vc + 1.89 * fz - 0.0203 * ap + 0.3075 * ae ...
			    - 0.198 * vc .* fz - 0.000955 * vc .* ap - 0.00656 * vc .* ae ...
			    + 0.209 * fz .* ap + 0.783 * fz .* ae + 0.02275 * ap .* ae ...
			    + 0.000355 * vc .* vc + 35 * fz .* fz + 0.00037 * ap .* ap ...
			    - 0.0791 * ae .* ae;
            PopObj(:,3) = -1*((1000.0 * vc .* fz .* z .* ap .* ae) ./ (pi .* d));
        end
        %% Generate points on the Pareto front

        
        function R = GetOptimum(obj,N)
            R = load('RWA6.mat').PF;
        end
    end
end