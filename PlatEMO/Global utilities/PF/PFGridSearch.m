
[x, y, fmin, hist] = refineMinimum(3, 1000, 1e-16);
FormatMatrix('%.16f ', x);
FormatMatrix('%.16f ', y);
FormatMatrix('%.16f ', fmin);


% x  = cos(a1)*cos(a2);
% y  = cos(a1)*sin(a2);
% z  = sin(a1);
% x=-1;y=4;
g1 = @(a1, a2) a1.^2 + a2.^2;
f1 = @(a1, a2) 0.5.*g1(a1,a2)+sin(g1(a1,a2));
f2 = @(a1, a2) (3*a1-2*a2+4).^2/8 + (a1-a2+1).^2/27 + 15;
f3 = @(a1, a2) 1./(g1(a1,a2)+1) - 1.1*exp(-g1(a1,a2));

opt = [f1(x,y), f2(x,y), f3(x,y)];
% 
FormatMatrix('%.16f, ', opt);

function [a1_opt, a2_opt, f_opt, history] = refineMinimum(objIdx, nSamples, tol)
% REFINEMINIMUM  Iteratively refine to find global minimum of objective
%
%   objIdx   - which objective to minimize (1=x, 2=y, 3=z)
%   nSamples - samples per iteration (default: 200)
%   tol      - tolerance for convergence (default: 1e-15)

    if nargin < 1, objIdx = 1; end
    if nargin < 2, nSamples = 200; end
    if nargin < 3, tol = 1e-15; end
    
    g1 = @(a1, a2) a1.^2 + a2.^2;
    f1 = @(a1, a2) 0.5.*g1(a1,a2)+sin(g1(a1,a2));
    f2 = @(a1, a2) (3*a1-2*a2+4).^2/8 + (a1-a2+1).^2/27 + 15;
    f3 = @(a1, a2) 1./(g1(a1,a2)+1) - 1.1*exp(-g1(a1,a2));


    % Define objective function based on index
    switch objIdx
        case 1
            % objFun = @(a1, a2) cos(a1) .* cos(a2);      % x
            objFun = @(a1, a2) 0.5.*g1(a1,a2)+sin(g1(a1,a2));      % x
        case 2
            objFun = @(a1, a2) (3*a1-2*a2+4).^2/8 + (a1-a2+1).^2/27 + 15;       % y
        case 3
            % objFun = @(a1, a2) sin(a1) .* ones(size(a2)); % z
            objFun = @(a1, a2) 1./(g1(a1,a2)+1) - 1.1*exp(-g1(a1,a2));
        otherwise
            error('objIdx must be 1, 2, or 3');
    end

    % Constraint function: returns true if point is VALID
    % constraintFun = @(a1, a2) ...
    %     cos(a1) >= cos(3*pi/8) & cos(a1) <= cos(pi/8) & ...
    %     cos(a2) >= cos(3*pi/8) & cos(a2) <= cos(pi/8);
    constraintFun = @(a1, a2) ...
        NDSort([Flatten(f1(a1, a2))',Flatten(f2(a1, a2))',Flatten(f3(a1, a2))'], 1)==1;
    
    % Initial bounds: full range [0, pi/2], but we know feasible region
    % From constraints: pi/8 <= a1,a2 <= 3*pi/8
    GLOBAL_MIN = -3; GLOBAL_MAX = 3;
    % a1_min = pi/8;  a1_max = 3*pi/8;
    % a2_min = pi/8;  a2_max = 3*pi/8;
    a1_min = GLOBAL_MIN;  a1_max = GLOBAL_MAX;
    a2_min = GLOBAL_MIN;  a2_max = GLOBAL_MAX;
    
    % Grid size per dimension
    nGrid = ceil(sqrt(nSamples));
    
    % Iteration tracking
    history = [];
    iter = 0;
    maxIter = 100;
    
    f_opt_prev = inf;
    
    while iter < maxIter
        iter = iter + 1;
        
        % Create grid
        a1_vec = linspace(a1_min, a1_max, nGrid)';
        a2_vec = linspace(a2_min, a2_max, nGrid)';
        
        [A1, A2] = meshgrid(a1_vec, a2_vec);
        
        % Evaluate objective
        F = objFun(A1, A2);
        
        % Apply constraints (set invalid to NaN)
        % valid = constraintFun(A1, A2);
        % F(~valid) = NaN;
        
        % Find minimum
        [f_opt, linearIdx] = min(F(:));
        [row, col] = ind2sub(size(F), linearIdx);
        
        a1_opt = a1_vec(col);
        a2_opt = a2_vec(row);
        
        % Store history
        history(iter).iter = iter;
        history(iter).a1_opt = a1_opt;
        history(iter).a2_opt = a2_opt;
        history(iter).f_opt = f_opt;
        history(iter).range_a1 = a1_max - a1_min;
        history(iter).range_a2 = a2_max - a2_min;
        
        % Check convergence
        if abs(f_opt - f_opt_prev) < tol && ...
           (a1_max - a1_min) < tol && (a2_max - a2_min) < tol
            fprintf('Converged at iteration %d\n', iter);
            break;
        end
        
        f_opt_prev = f_opt;
        
        % Shrink bounds around minimum (zoom factor ~0.5)
        shrink = 0.5;
        range_a1 = (a1_max - a1_min) * shrink;
        range_a2 = (a2_max - a2_min) * shrink;
        
        % New bounds centered on current optimum
        a1_min_new = a1_opt - range_a1/2;
        a1_max_new = a1_opt + range_a1/2;
        a2_min_new = a2_opt - range_a2/2;
        a2_max_new = a2_opt + range_a2/2;
        
        % Clamp to feasible region
        % a1_min = max(a1_min_new, pi/8);
        % a1_max = min(a1_max_new, 3*pi/8);
        % a2_min = max(a2_min_new, pi/8);
        % a2_max = min(a2_max_new, 3*pi/8);
        a1_min = max(a1_min_new, GLOBAL_MIN);
        a1_max = min(a1_max_new, GLOBAL_MAX);
        a2_min = max(a2_min_new, GLOBAL_MIN);
        a2_max = min(a2_max_new, GLOBAL_MAX);
    end
    
    % Display result with full precision
    fprintf('\n=== Optimization Result (Objective %d) ===\n', objIdx);
    fprintf('a1_opt = %.15f\n', a1_opt);
    fprintf('a2_opt = %.15f\n', a2_opt);
    fprintf('f_opt  = %.15f\n', f_opt);
    fprintf('Iterations: %d\n', iter);
end