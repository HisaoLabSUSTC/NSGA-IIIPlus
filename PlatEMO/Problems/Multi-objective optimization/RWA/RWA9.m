classdef RWA9 < PROBLEM
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
                obj.M = 5;
            end
            if isempty(obj.D)
                obj.D = 6;
            end
            obj.lower    = [17.5,17.5,2,2,5,5];
            obj.upper    = [22.5,22.5,3,3,7,6];
            obj.encoding = ones(1,obj.D);
        end
        %% Calculate objective values
        function PopObj = CalObj(obj,PopDec)
            M      = obj.M;
            PopObj = zeros(size(PopDec,1),M);
            l1 = PopDec(:,1);
            w1 = PopDec(:,2);
            l2 = PopDec(:,3);
            w2 = PopDec(:,4);
            a1 = PopDec(:,5);
            b1 = PopDec(:,6);
            a2 = l1 .* w1 .* l2 .* w2;
            b2 = l1 .* w1 .* l2 .* a1;
            d2 = w1 .* w2 .* a1 .* b1;

            PopObj(:,1) = 502.94 - 27.18 * ((w1 - 20.0) / 0.5) + 43.08 * ((l1 - 20.0) / 2.5) ...
			    + 47.75 * (a1 - 6.0) + 32.25 * ((b1 - 5.5) / 0.5) ...
			    + 31.67 * (a2 - 11.0) ...
			    - 36.19 * ((w1 - 20.0) / 0.5) .* ((w2 - 2.5) / 0.5) ...
			    - 39.44 * ((w1 - 20.0) / 0.5) .* (a1 - 6.0) ...
			    + 57.45 * (a1 - 6.0) .* ((b1 - 5.5) / 0.5);
            PopObj(:,2) = -1*(130.53 + 45.97 * ((l1 - 20.0) / 2.5) - 52.93 * ((w1 - 20.0) / 0.5) ...
			    - 78.93 * (a1 - 6.0) + 79.22 * (a2 - 11.0) ...
			    + 47.23 * ((w1 - 20.0) / 0.5) .* (a1 - 6.0) ...
			    - 40.61 * ((w1 - 20.0) / 0.5) .* (a2 - 11.0) ...
			    - 50.62 * (a1 - 6.0) .* (a2 - 11.0));
            PopObj(:,3) = -1*(203.16 - 42.75 * ((w1 - 20.0) / 0.5) + 56.67 * (a1 - 6.0) ...
			    + 19.88 * ((b1 - 5.5) / 0.5) - 12.89 * (a2 - 11.0) ...
			    - 35.09 * (a1 - 6.0) .* ((b1 - 5.5) / 0.5) ...
			    - 22.91 * ((b1 - 5.5) / 0.5) .* (a2 - 11.0));
            PopObj(:,4) = -1*(0.76 - 0.06 * ((l1 - 20.0) / 2.5) + 0.03 * ((l2 - 2.5) / 0.5) ...
			    + 0.02 * (a2 - 11.0) - 0.02 * ((b2 - 6.5) / 0.5) ...
			    - 0.03 * ((d2 - 12.0) / 0.5) ...
			    + 0.03 * ((l1 - 20.0) / 2.5) .* ((w1 - 20.0) / 0.5) ...
			    - 0.02 * ((l1 - 20.0) / 2.5) .* ((l2 - 2.5) / 0.5) ...
			    + 0.02 * ((l1 - 20.0) / 2.5) .* ((b2 - 6.5) / 0.5));
            PopObj(:,5) = 1.08 - 0.12 * ((l1 - 20.0) / 2.5) - 0.26 * ((w1 - 20.0) / 0.5) ...
			    - 0.05 * (a2 - 11.0) - 0.12 * ((b2 - 6.5) / 0.5) ...
			    + 0.08 * (a1 - 6.0) .* ((b2 - 6.5) / 0.5) ...
			    + 0.07 * (a2 - 6.0) .* ((b2 - 5.5) / 0.5);

        end
        %% Generate points on the Pareto front

        
        function R = GetOptimum(obj,N)
            R = load('RWA9.mat').PF;
        end
    end
end