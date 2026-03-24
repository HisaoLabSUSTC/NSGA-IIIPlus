%% Problems that DO NOT affect: linear, Problems that DO affect: convex/concave
ph = @IDTLZ2; Problem = ph(); M = Problem.M; D = Problem.D;
N = 120; [Z, ~] = UniformPoint(N, M);
[PF, ~] = GetPFnRef(Problem, 120);



fig = figure('Position', [100, 50, 1000, 800], 'Name', 'Coplanar Extreme Points', 'Visible', 'on');
ax = axes('Position', [0.13, 0.1, 0.8, 0.8]); cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); 
view(ax, 66, 30);
xlabel(ax, '$f_1$', 'Interpreter', 'Latex'); ylabel(ax, '$f_2$', 'Interpreter', 'Latex'); zlabel(ax, '$f_3$', 'Interpreter', 'Latex');



%% Determine extreme point manually
% first = [0.5, 0, 0]; second = [0, 0.5, 0]; third = [0, 0, 0.5];
first = [0.107, 0.035, 0.357]; second = [0.285, 0.07, 0.142]; third = [0.142, 0.357, 0];
% first = [0.2, 0.4, 0.99]; second = [0.99, 0.2, 0.4]; third = [0.2, 0.99, 0.4];

[~, I] = min(pdist2(PF, [first; second; third]));
EP = PF(I, :);
PF(I, :) = [];

Hyperplane = EP\ones(M,1);
c = 1./Hyperplane';
if any(isnan(c))
    warning("hyperplane is invalid.")
end

scatter3(ax, PF(:,1), PF(:,2), PF(:, 3), 60, ...
                'r', 'filled', 'MarkerEdgeColor','k', ...
                'MarkerFaceAlpha',1, 'MarkerEdgeAlpha',1);

scatter3(ax, EP(:,1), EP(:,2), EP(:, 3), 444, ...
                'yellow', 'filled', 'pentagram', 'MarkerEdgeColor','k', ...
                'MarkerFaceAlpha',1, 'MarkerEdgeAlpha',1);

scatter3(ax, c(:,1), c(:,2), c(:, 3), 200, ...
                'green', 'filled', 'square', 'MarkerEdgeColor','k', ...
                'MarkerFaceAlpha',1, 'MarkerEdgeAlpha',1);

% draw_bounding_box_to_origin(ax, c);

legend_marker_size = 16;
h_extreme = plot3(ax, NaN, NaN, NaN, 'p', ...
                'MarkerSize', legend_marker_size+2, ...
                'MarkerFaceColor', 'yellow', 'MarkerEdgeColor', 'k');

h_norm = plot3(ax, NaN, NaN, NaN, 'o', ...
                'MarkerSize', legend_marker_size-8, ...
                'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');

h_nadir = plot3(ax, NaN, NaN, NaN, 's', ...
                'MarkerSize', legend_marker_size-4, ...
                'MarkerFaceColor', 'green', 'MarkerEdgeColor', 'k');

h_handles = [h_extreme, h_norm, h_nadir];
h_labels = {'Extreme Solutions', 'Other Solutions', 'Nadir Point'};
lgd = legend(ax, h_handles, h_labels, 'Location', 'best');

xlim([0 c(1)])
ylim([0 c(2)])
zlim([0 c(3)])

fontConfig = struct();
fontConfig.legendSize = 30;
EnlargeFont(fig, fontConfig);


current_xticks = xticks(ax);
current_yticks = yticks(ax);
current_zticks = zticks(ax);
xticks(ax, sort(unique([current_xticks, c(1)])));
yticks(ax, sort(unique([current_yticks, c(2)])));
zticks(ax, sort(unique([current_zticks, c(3)])));

% exportgraphics(fig, './IDTLZ2_EP2.png', 'Resolution', 600);
% close(fig);





function draw_bounding_box_to_origin(ax, c)
% DRAW_BOUNDING_BOX_TO_ORIGIN Draws a 3D rectangular bounding box from the
% point 'c' to the origin (0, 0, 0) on the specified axes 'ax'.
%
% Input:
%   ax (handle): The handle of the target axes object.
%   c (vector): The 1x3 coordinate vector of the point [x, y, z].
%
% Filtering Conditions:
%   X (Column 1): 1650 < X < 1680
%   Y (Column 2): 6.5 < Y < 9
%   Z (Column 3): 0.05 < Z < 0.15
%
% Author: Gemini

    % Ensure input 'c' is a 1x3 vector (or 3x1)
    if numel(c) ~= 3
        error('Input point vector c must contain exactly 3 coordinates [x, y, z].');
    end
    
    x = c(1);
    y = c(2);
    z = c(3);
    
    % --- 1. Define the 8 Vertices (Corners) of the Cuboid ---
    % Vertices are defined by all combinations of 0 or the point's coordinate
    % for each axis. The order matters for defining the faces.
    
    V = [
        0, 0, 0;    % V1: Origin
        x, 0, 0;    % V2: Along X-axis
        0, y, 0;    % V3: Along Y-axis
        0, 0, z;    % V4: Along Z-axis
        x, y, 0;    % V5: In X-Y plane
        x, 0, z;    % V6: In X-Z plane
        0, y, z;    % V7: In Y-Z plane
        x, y, z     % V8: The point c itself
    ];

    % --- 2. Define the 6 Faces using the Vertex Indices ---
    % Each row defines one face using 4 vertex indices.
    F = [
        1, 2, 5, 3; % Bottom (Z=0)
        4, 6, 8, 7; % Top (Z=z)
        1, 2, 6, 4; % Front (Y=0)
        3, 5, 8, 7; % Back (Y=y)
        1, 3, 7, 4; % Left (X=0)
        2, 5, 8, 6  % Right (X=x)
    ];

    % --- 3. Draw the Bounding Box using the PATCH function ---
    
    % The patch command draws the cuboid defined by the vertices (V) and faces (F)
    h_box = patch(ax, 'Vertices', V, 'Faces', F, ...
        'FaceColor', [0.8 0.8 0.8], ... % Light gray color
        'FaceAlpha', 0.2, ...          % Make it semi-transparent
        'EdgeColor', 'k', ...           % Black edges
        'LineWidth', 1.5);              % Thicker edges for visibility
    
    % Ensure the box is drawn on top of the scatter point by setting the axes
    % rendering order (optional, but sometimes helpful).
    set(ax, 'SortMethod', 'childorder');
   
end
