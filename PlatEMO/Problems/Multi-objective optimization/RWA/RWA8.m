classdef RWA8 < PROBLEM
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
                obj.M = 4;
            end
            if isempty(obj.D)
                obj.D = 4;
            end
            obj.lower    = zeros(1,4);
            obj.upper    = ones(1,4);
            obj.encoding = ones(1,obj.D);
        end
        %% Calculate objective values
        function PopObj = CalObj(obj,PopDec)
            M      = obj.M;
            PopObj = zeros(size(PopDec,1),M);
            a = PopDec(:,1);
            DHA = PopDec(:,2);
            DOA = PopDec(:,3);
            OPTT = PopDec(:,4);

            PopObj(:,1) = 0.692 + 0.477 * a - 0.687 * DHA - 0.080 * DOA - 0.0650 * OPTT ...
			- 0.167 * a .* a - 0.0129 * DHA .* a + 0.0796 * DHA .* DHA ...
			- 0.0634 * DOA .* a - 0.0257 * DOA .* DHA + 0.0877 * DOA .* DOA ...
			- 0.0521 * OPTT .* a + 0.00156 * OPTT .* DHA + 0.00198 * OPTT .* DOA ...
			+ 0.0184 * OPTT .* OPTT;
            PopObj(:,4) = 0.153 - 0.322 * a + 0.396 * DHA + 0.424 * DOA + 0.0226 * OPTT ...
			+ 0.175 * a .* a + 0.0185 * DHA .* a - 0.0701 * DHA .* DHA ...
			- 0.251 * DOA .* a + 0.179 * DOA .* DHA + 0.0150 * DOA .* DOA ...
			+ 0.0134 * OPTT .* a + 0.0296 * OPTT .* DHA + 0.0752 * OPTT .* DOA ...
			+ 0.0192 * OPTT .* OPTT;
            PopObj(:,2) = 0.758 + 0.358 * a - 0.807 * DHA + 0.0925 * DOA - 0.0468 * OPTT ...
			- 0.172 * a .* a + 0.0106 * DHA .* a + 0.0697 * DHA .* DHA ...
			- 0.146 * DOA .* a - 0.0416 * DOA .* DHA + 0.102 * DOA .* DOA ...
			- 0.0694 * OPTT .* a - 0.00503 * OPTT .* DHA + 0.0151 * OPTT .* DOA ...
			+ 0.0173 * OPTT .* OPTT;
            PopObj(:,3) = 0.370 - 0.205 * a + 0.0307 * DHA + 0.108 * DOA + 1.019 * OPTT ...
			- 0.135 * a .* a + 0.0141 * DHA .* a + 0.0998 * DHA .* DHA ...
			+ 0.208 * DOA .* a - 0.0301 * DOA .* DHA - 0.226 * DOA .* DOA ...
			+ 0.353 * OPTT .* a - 0.0497 * OPTT .* DOA - 0.423 * OPTT .* OPTT ...
			+ 0.202 * DHA .* a .* a - 0.281 * DOA .* a .* a - 0.342 * DHA .* DHA .* a ...
			- 0.245 * DHA .* DHA .* DOA + 0.281 * DOA .* DOA .* DHA ...
			- 0.184 * OPTT .* OPTT .* a - 0.281 * DHA .* a .* DOA;
        end
        %% Generate points on the Pareto front

        
        function R = GetOptimum(obj,N)
            R = load('RWA8.mat').PF;
        end
    end
end