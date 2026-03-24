classdef ModularNormHist < handle
    %MODULARNORMHIST Unified modular normalization history for NSGA-III variants
    %
    %   This class consolidates normalization strategies into a single
    %   configurable component, supporting:
    %
    %   Area 1 - Implementation Modifications:
    %     removeThreshold  (Z)  - Remove 1e-3 threshold in ASF
    %     preserveCorners  (Y)  - Preserve corner solutions across generations
    %     useArchive       (X)  - Unbounded archive for extreme points
    %     Default (no flags) = baseline
    %
    %   Nadir Estimation Strategy:
    %     'extreme_pt' - Hyperplane through extreme points (only supported type)
    %
    %   Area 2 - Normalization Modifications:
    %     'tikhonov' (Tk)   - Tikhonov-regularized hyperplane solve via
    %                         standard least squares (C\d).
    %
    %   Area 3 - Selection Modifications:
    %     useDSS (Dss) - Distance-based subset selection
    %                    (handled by ConfigurableNSGAIIIwH)
    %
    %   Example:
    %     config = struct('removeThreshold', true, 'preserveCorners', true, ...
    %                     'momentum', 'tikhonov', 'useDSS', true);
    %     hist = ModularNormHist(3, config);
    %     hist.update(F, nds, 120);

    properties
        % Core state
        ideal_point
        worst_point
        nadir_point
        extreme_points
        extreme_archive  % For X (useArchive)

        % Configuration
        config
        M      % Number of objectives
        N_pop  % Population size (for fallback)

        % Normalization modification state
        t             % Time step
        last_plane    % Previous generation's plane coefficients (for 'previous' prior)
    end

    methods
        function obj = ModularNormHist(M, config)
            %MODULARNORMHIST Constructor
            %   obj = ModularNormHist(M) - Default Py-style configuration
            %   obj = ModularNormHist(M, config) - Custom configuration

            obj.M = M;

            % Default configuration
            defaultConfig = struct(...
                'removeThreshold', false, ...   % Z (was PyA)
                'useArchive', false, ...        % X (was PyB)
                'preserveCorners', false, ...   % Y (was PyC)
                'momentum', 'none', ...         % Normalization modification: 'none', 'tikhonov'
                'epsilon', 1e-8, ...            % Numerical stability / nadir floor
                'regLambda', 1e-3, ...          % Tikhonov regularization strength
                'regAdaptive', false, ...        % Scale lambda by trace(A'A)/m
                'regPrior', 'worst_of_front', ...% Prior type: 'worst_of_front', 'previous', 'uniform'
                'useDSS', false ...             % DSS (Area 3, passthrough)
            );

            if nargin < 2
                config = struct();
            end

            % Merge with defaults
            obj.config = defaultConfig;
            fields = fieldnames(config);
            for i = 1:length(fields)
                obj.config.(fields{i}) = config.(fields{i});
            end

            % Initialize state
            obj.ideal_point = inf(1, M);
            obj.worst_point = -inf(1, M);
            obj.nadir_point = [];
            obj.extreme_points = [];
            obj.extreme_archive = [];

            % Initialize normalization modification state
            obj.t = 0;
            obj.last_plane = [];
        end

        function update(obj, F, nds, N_pop)
            %UPDATE Update normalization based on population F
            %   update(obj, F, nds, N_pop)
            %     F     - objective matrix (N x M)
            %     nds   - indices of non-dominated solutions (optional)
            %     N_pop - population size (optional)

            if nargin < 3 || isempty(nds)
                nds = 1:size(F, 1);
            end

            if nargin >= 4 && ~isempty(N_pop)
                obj.N_pop = N_pop;
            end

            % Update ideal and worst
            obj.ideal_point = min([obj.ideal_point; F], [], 1);
            obj.worst_point = max([obj.worst_point; F], [], 1);

            % Compute raw nadir and plane coefficients from extreme points
            [nadir_raw, ~] = obj.computeExtremePtNadir(F, nds);

            % Apply normalization modification (if any)
            obj.nadir_point = obj.applyNormMod(nadir_raw);
        end

        function [nadir_raw, plane_raw] = computeExtremePtNadir(obj, F, nds)
            %COMPUTEEXTREMEPTNADIR Compute nadir using extreme points (Py-style)
            %   Returns:
            %     nadir_raw  - raw nadir estimate (1×M)
            %     plane_raw  - reciprocal intercepts p (1×M), or []

            % Get extreme points with optional archive
            if obj.config.useArchive
                archiveInput = obj.extreme_archive;
            else
                archiveInput = obj.extreme_points;
            end

            obj.extreme_points = obj.getExtremePoints(F(nds,:), archiveInput);

            if obj.config.useArchive
                obj.extreme_archive = [obj.extreme_archive; obj.extreme_points];
            end

            % Compute nadir from extreme points
            worst_of_population = max(F, [], 1);
            worst_of_front = max(F(nds,:), [], 1);

            [nadir_raw, plane_raw] = obj.getNadirFromExtremePoints(...
                obj.extreme_points, worst_of_population, worst_of_front);
        end

        function extreme_points = getExtremePoints(obj, F, existing_extreme)
            %GETEXTREMEPOINTS Find extreme points using ASF

            [~, M] = size(F);

            % Standard ASF weight matrix: [1,0,0] style
            weights = zeros(M) + eye(M) + 1e-6;

            % Preserve old extreme points
            if ~isempty(existing_extreme)
                FF = [existing_extreme; F];
            else
                FF = F;
            end
            [N, ~] = size(FF);

            % Shift by ideal
            FFF = FF - obj.ideal_point;

            % Apply threshold unless removeThreshold (Z)
            if ~obj.config.removeThreshold
                FFF(FFF < 1e-3) = 0;
            end

            % Find extreme points via ASF
            I = zeros(1, M);
            for i = 1:M
                [~, I(i)] = min(max(FFF ./ repmat(weights(i,:), N, 1), [], 2));
            end

            extreme_points = FF(I, :);
        end

        function [nadir_point, plane] = getNadirFromExtremePoints(obj, extreme_points, worst_of_population, worst_of_front)
            %GETNADIRFROMEXTREMEPOINTS Compute nadir from extreme points via hyperplane
            %   When momentum='tikhonov', uses Tikhonov-regularized
            %   hyperplane solve via standard least squares.
            %
            %   Returns:
            %     nadir_point - estimated nadir (1×M)
            %     plane       - hyperplane coefficients p = 1/intercepts (1×M),
            %                   empty if hyperplane computation fails

            M = size(extreme_points, 2);
            plane = [];

            try
                % A: m×m, rows = shifted extreme points
                A = extreme_points - obj.ideal_point;
                b = ones(M, 1);

                momType = lower(obj.config.momentum);
                if strcmp(momType, 'tikhonov')
                    % --- Tikhonov-regularized solve ---
                    % min ||Ap - 1||^2 + lam * ||p - p_prior||^2
                    % Unconstrained via standard least squares

                    % Build prior
                    switch lower(obj.config.regPrior)
                        case 'worst_of_front'
                            range = worst_of_front - obj.ideal_point;
                            range = max(range, obj.config.epsilon);
                            p_prior = (1 ./ range)';   % M×1 column
                        case 'previous'
                            if ~isempty(obj.last_plane)
                                p_prior = obj.last_plane(:);
                            else
                                % Fallback to worst_of_front on first call
                                range = worst_of_front - obj.ideal_point;
                                range = max(range, obj.config.epsilon);
                                p_prior = (1 ./ range)';
                            end
                        case 'uniform'
                            p_prior = ones(M, 1) / M;
                        otherwise
                            p_prior = ones(M, 1) / M;
                    end

                    % Compute lambda (optionally adaptive)
                    lam = obj.config.regLambda;
                    if obj.config.regAdaptive
                        lam = lam * trace(A' * A) / M;
                    end

                    % Augmented system
                    C = [A; sqrt(lam) * eye(M)];
                    d = [b; sqrt(lam) * p_prior];

                    % Unconstrained: min ||Cx - d||^2
                    p = C \ d;
                else
                    % --- Original exact solve ---
                    p = A \ b;
                end

                intercepts = 1 ./ p';
                nadir_point = obj.ideal_point + intercepts;

                % Check validity
                if any(isnan(p)) || any(intercepts <= 1e-6)
                    error('Invalid hyperplane');
                end

                % For exact solve only: check residual
                if ~strcmp(momType, 'tikhonov')
                    if norm(A * p - b) > 1e-8
                        error('Invalid hyperplane');
                    end
                end

                % Store valid plane coefficients (1×M row vector)
                plane = p';

                % Store for 'previous' prior
                obj.last_plane = plane;

                % Cap by historical worst
                mask = nadir_point > obj.worst_point;
                nadir_point(mask) = obj.worst_point(mask);

            catch
                % Fallback to worst of front
                nadir_point = worst_of_front;
            end

            % If too small, fallback to worst of population
            mask2 = (nadir_point - obj.ideal_point) <= 1e-6;
            nadir_point(mask2) = worst_of_population(mask2);
        end

        function nadir_out = applyNormMod(obj, nadir_raw)
            %APPLYNORMMOD Apply normalization modification
            %   nadir_out = applyNormMod(obj, nadir_raw)
            %     nadir_raw - raw nadir estimate (1×M)
            %
            %   For 'tikhonov', the regularization is already applied in
            %   getNadirFromExtremePoints; this method is a passthrough.
            %   For 'none', this is also a passthrough.

            obj.t = obj.t + 1;

            switch lower(obj.config.momentum)
                case {'none', 'tikhonov'}
                    % Tikhonov regularization is applied in
                    % getNadirFromExtremePoints. No post-processing needed.
                    nadir_out = nadir_raw;

                otherwise
                    warning('ModularNormHist:unknownMomentum', ...
                        'Unknown momentum: %s. Using raw nadir.', obj.config.momentum);
                    nadir_out = nadir_raw;
            end

            % Ensure nadir >= ideal
            nadir_out = max(nadir_out, obj.ideal_point + obj.config.epsilon);
        end

        function resetState(obj)
            %RESETSTATE Reset normalization modification state
            obj.t = 0;
            obj.last_plane = [];
        end
    end
end