
P = [1 3; 2 2; 3 1];
A1 = [4 7; 5 6; 7 5; 8 4; 9 2];
A2 = [4 7; 5 6; 7 5; 8 4];
A3 = [6 8; 7 7; 8 6; 9 5; 10 4];

disp(I_Epsilon(A1, A1));
disp(I_Epsilon(A1, A2));
disp(I_Epsilon(A1, A3));
disp(I_Epsilon(A1, P));
disp('\n');
disp(I_Epsilon(A2, A1));
disp(I_Epsilon(A2, A2));
disp(I_Epsilon(A2, A3));
disp(I_Epsilon(A2, P));
disp('\n');
disp(I_Epsilon(A3, A1));
disp(I_Epsilon(A3, A2));
disp(I_Epsilon(A3, A3));
disp(I_Epsilon(A3, P));
disp('\n');
disp(I_Epsilon(P, A1));
disp(I_Epsilon(P, A2));
disp(I_Epsilon(P, A3));
disp(I_Epsilon(P, P));

function score = I_Epsilon(A, B)
    % Function to compute I_epsilon(A, B)
    % A: a x n matrix (set of vectors z^1)
    % B: b x n matrix (set of vectors z^2)
    
    % Number of vectors in A and B
    a = size(A, 1);
    b = size(B, 1);
    
    % Initialize an array to hold S(z2) for each z2 in B
    S_z2 = zeros(b, 1);
    
    % Loop over each vector z2 in B
    for idxB = 1:b
        z2 = B(idxB, :);  % Current z2 vector (1 x n)
        
        % Compute the ratios z1_i / z2_i for all z1 in A
        % Using element-wise division and implicit expansion
        ratios = A ./ z2;  % Result is an (a x n) matrix
        % ratios = A - z2; % Additive epsilon
        
        % Compute the maximum ratio over dimensions for each z1 (max over i)
        max_ratios = max(ratios, [], 2);  % Result is an (a x 1) vector
        
        % Compute the minimum of these max_ratios over all z1 in A (min over z1)
        S_z2(idxB) = min(max_ratios);
    end
    
    % Compute the maximum S(z2) over all z2 in B (max over z2)
    score = max(S_z2);
end
