classdef PyMomentumNormHist < handle
    %PYENORMALIZATIONHISTORYMOMENTUM Normalization history with momentum-based nadir updates
    %
    %   Supports multiple momentum strategies for stabilizing nadir point estimation:
    %     'none'       - No momentum (original behavior)
    %     'ema'        - Exponential Moving Average
    %     'heavyball'  - Heavy-ball momentum
    %     'nag'        - Nesterov Accelerated Gradient (reformulated)
    %     'adam'       - Adam optimizer style
    %     'adamw'      - AdamW with decoupled weight decay
    %     'rmsprop'    - RMSprop style
    %
    %   Example:
    %     hist = PyeNormalizationHistoryMomentum(3, 'adam', 'Alpha', 0.1);
    %     hist.update(F, nds);

    properties
        ideal_point  
        worst_point
        nadir_point
        extreme_points
        
        % Momentum strategy
        strategy      % 'none', 'ema', 'heavyball', 'nag', 'adam', 'adamw', 'rmsprop'
        
        % Common parameters
        alpha         % Learning rate / step size
        
        % EMA parameters
        gamma         % Decay factor for EMA: z = gamma*z + (1-gamma)*z_new
        
        % Momentum parameters (heavy-ball, NAG)
        beta          % Momentum coefficient
        m             % First moment (velocity)
        
        % Adam/AdamW parameters
        beta1         % First moment decay
        beta2         % Second moment decay
        epsilon       % Numerical stability
        v             % Second moment (squared gradient)
        t             % Time step (for bias correction)
        weight_decay  % Weight decay for AdamW
        
        % NAG specific
        nadir_prev    % Previous nadir for NAG reformulation
        
        % Dimension
        M
    end

    methods
        function obj = PyMomentumNormHist(M, strategy, varargin)
            %PYENORMALIZATIONHISTORYMOMENTUM Constructor
            %   obj = PyeNormalizationHistoryMomentum(M) - No momentum
            %   obj = PyeNormalizationHistoryMomentum(M, strategy, Name, Value, ...)
            %
            %   Parameters:
            %     'Alpha'       - Learning rate (default: 0.3)
            %     'Gamma'       - EMA decay (default: 0.9)
            %     'Beta'        - Momentum coefficient (default: 0.9)
            %     'Beta1'       - Adam first moment decay (default: 0.9)
            %     'Beta2'       - Adam second moment decay (default: 0.999)
            %     'Epsilon'     - Numerical stability (default: 1e-8)
            %     'WeightDecay' - AdamW weight decay (default: 0.01)
            
            if nargin < 2
                strategy = 'none';
            end
            
            % Parse optional parameters
            p = inputParser;
            addParameter(p, 'Alpha', 0.3);
            addParameter(p, 'Gamma', 0.9);
            addParameter(p, 'Beta', 0.9);
            addParameter(p, 'Beta1', 0.9);
            addParameter(p, 'Beta2', 0.999);
            addParameter(p, 'Epsilon', 1e-8);
            addParameter(p, 'WeightDecay', 0.01);
            parse(p, varargin{:});
            
            % Initialize basic properties
            obj.M = M;
            obj.ideal_point   = inf(1, M);
            obj.worst_point   = -inf(1, M);
            obj.nadir_point   = [];
            obj.extreme_points = [];
            
            % Initialize momentum properties
            obj.strategy = lower(strategy);
            obj.alpha = p.Results.Alpha;
            obj.gamma = p.Results.Gamma;
            obj.beta = p.Results.Beta;
            obj.beta1 = p.Results.Beta1;
            obj.beta2 = p.Results.Beta2;
            obj.epsilon = p.Results.Epsilon;
            obj.weight_decay = p.Results.WeightDecay;
            
            % Initialize momentum buffers
            obj.m = zeros(1, M);           % First moment
            obj.v = zeros(1, M);           % Second moment
            obj.t = 0;                     % Time step
            obj.nadir_prev = [];           % For NAG
        end

        function update(obj, F, nds)
            % F: N x M
            if nargin < 3 || isempty(nds)
                nds = 1:size(F,1);
            end

            % === Update ideal and worst ===
            obj.ideal_point = min([obj.ideal_point; F], [], 1);
            obj.worst_point = max([obj.worst_point; F], [], 1);

            % === Get extreme points ===
            obj.extreme_points = get_extreme_points_c( ...
                F(nds,:), obj.ideal_point, obj.extreme_points);

            % === Determine raw nadir ===
            worst_of_population = max(F, [], 1);
            worst_of_front      = max(F(nds,:), [], 1);

            nadir_raw = get_nadir_point( ...
                obj.extreme_points, obj.ideal_point, obj.worst_point, ...
                worst_of_population, worst_of_front);
            
            % === Apply momentum strategy ===
            obj.nadir_point = obj.apply_momentum(nadir_raw);
        end
        
        function nadir_smoothed = apply_momentum(obj, nadir_raw)
            %APPLY_MOMENTUM Apply the selected momentum strategy
            
            obj.t = obj.t + 1;
            
            % Initialize nadir_point if empty
            if isempty(obj.nadir_point)
                obj.nadir_point = nadir_raw;
                obj.nadir_prev = nadir_raw;
                nadir_smoothed = nadir_raw;
                return;
            end
            
            switch obj.strategy
                case 'none'
                    nadir_smoothed = nadir_raw;
                    
                case 'ema'
                    nadir_smoothed = obj.momentum_ema(nadir_raw);
                    
                case 'heavyball'
                    nadir_smoothed = obj.momentum_heavyball(nadir_raw);
                    
                case 'nag'
                    nadir_smoothed = obj.momentum_nag(nadir_raw);
                    
                case 'adam'
                    nadir_smoothed = obj.momentum_adam(nadir_raw, false);
                    
                case 'adamw'
                    nadir_smoothed = obj.momentum_adam(nadir_raw, true);
                    
                case 'rmsprop'
                    nadir_smoothed = obj.momentum_rmsprop(nadir_raw);
                    
                otherwise
                    warning('Unknown strategy: %s. Using raw nadir.', obj.strategy);
                    nadir_smoothed = nadir_raw;
            end
            
            % Ensure nadir is always >= ideal (sanity check)
            nadir_smoothed = max(nadir_smoothed, obj.ideal_point + obj.epsilon);
        end
        
        function nadir_smoothed = momentum_ema(obj, nadir_raw)
            %MOMENTUM_EMA Exponential Moving Average
            %   z^{t+1} = gamma * z^{t} + (1 - gamma) * z_raw
            %
            %   High gamma (e.g., 0.95) = more smoothing, slower response
            %   Low gamma (e.g., 0.5) = less smoothing, faster response
            
            nadir_smoothed = obj.gamma * obj.nadir_point + (1 - obj.gamma) * nadir_raw;
        end
        
        function nadir_smoothed = momentum_heavyball(obj, nadir_raw)
            %MOMENTUM_HEAVYBALL Heavy-ball / Classical Momentum
            %   g = z_raw - z^{t}           (gradient toward target)
            %   m^{t+1} = beta * m^{t} + g  (accumulate momentum)
            %   z^{t+1} = z^{t} + alpha * m^{t+1}
            %
            %   This allows "overshooting" and faster convergence
            
            g = nadir_raw - obj.nadir_point;
            obj.m = obj.beta * obj.m + g;
            nadir_smoothed = obj.nadir_point + obj.alpha * obj.m;
        end
        
        function nadir_smoothed = momentum_nag(obj, nadir_raw)
            %MOMENTUM_NAG Nesterov Accelerated Gradient (Reformulated)
            %   Uses the equivalent formulation that doesn't require lookahead:
            %   
            %   y^{t} = z^{t} + beta * (z^{t} - z^{t-1})  (lookahead position)
            %   g = z_raw - y^{t}                          (gradient at lookahead)
            %   z^{t+1} = y^{t} + alpha * g
            %
            %   Alternatively, using Sutskever's reformulation:
            %   v^{t+1} = beta * v^{t} + alpha * g
            %   z^{t+1} = z^{t} + v^{t+1} + beta * (v^{t+1} - v^{t})
            
            if isempty(obj.nadir_prev)
                obj.nadir_prev = obj.nadir_point;
            end
            
            % Lookahead position
            y = obj.nadir_point + obj.beta * (obj.nadir_point - obj.nadir_prev);
            
            % Gradient at lookahead
            g = nadir_raw - y;
            
            % Update
            obj.nadir_prev = obj.nadir_point;
            nadir_smoothed = y + obj.alpha * g;
        end
        
        function nadir_smoothed = momentum_adam(obj, nadir_raw, use_weight_decay)
            %MOMENTUM_ADAM Adam / AdamW optimizer
            %   g = z_raw - z^{t}
            %   m^{t+1} = beta1 * m^{t} + (1 - beta1) * g
            %   v^{t+1} = beta2 * v^{t} + (1 - beta2) * g^2
            %   m_hat = m^{t+1} / (1 - beta1^t)
            %   v_hat = v^{t+1} / (1 - beta2^t)
            %   z^{t+1} = z^{t} + alpha * m_hat / (sqrt(v_hat) + eps)
            %
            %   AdamW adds decoupled weight decay toward the raw value
            
            if nargin < 3
                use_weight_decay = false;
            end
            
            g = nadir_raw - obj.nadir_point;
            
            % Update biased first and second moment estimates
            obj.m = obj.beta1 * obj.m + (1 - obj.beta1) * g;
            obj.v = obj.beta2 * obj.v + (1 - obj.beta2) * (g .^ 2);
            
            % Bias correction
            m_hat = obj.m / (1 - obj.beta1^obj.t);
            v_hat = obj.v / (1 - obj.beta2^obj.t);
            
            % Adaptive step
            step = obj.alpha * m_hat ./ (sqrt(v_hat) + obj.epsilon);
            
            if use_weight_decay
                % AdamW: decoupled weight decay pulls toward raw value
                % This acts as a regularizer toward the instantaneous estimate
                decay_term = obj.weight_decay * (obj.nadir_point - nadir_raw);
                nadir_smoothed = obj.nadir_point + step - decay_term;
            else
                nadir_smoothed = obj.nadir_point + step;
            end
        end
        
        function nadir_smoothed = momentum_rmsprop(obj, nadir_raw)
            %MOMENTUM_RMSPROP RMSprop-style adaptive learning rate
            %   g = z_raw - z^{t}
            %   v^{t+1} = beta * v^{t} + (1 - beta) * g^2
            %   z^{t+1} = z^{t} + alpha * g / (sqrt(v^{t+1}) + eps)
            %
            %   Adapts step size per dimension based on gradient magnitude
            
            g = nadir_raw - obj.nadir_point;
            
            % Update running average of squared gradients
            obj.v = obj.beta * obj.v + (1 - obj.beta) * (g .^ 2);
            
            % Adaptive step
            nadir_smoothed = obj.nadir_point + obj.alpha * g ./ (sqrt(obj.v) + obj.epsilon);
        end
        
        function reset_momentum(obj)
            %RESET_MOMENTUM Reset momentum buffers (useful when population changes drastically)
            obj.m = zeros(1, obj.M);
            obj.v = zeros(1, obj.M);
            obj.t = 0;
            obj.nadir_prev = [];
        end
    end
end

%% Helper functions (same as original)

function extreme_points = get_extreme_points_c(F, ideal_point, extreme_points)
    [~, M] = size(F);

    % ASF weight matrix (identity with off-diagonal = 1e6)
    weights = zeros(M) + eye(M) + 1e-6;

    % Preserve old extreme points (never lose them)
    if ~isempty(extreme_points)
        FF = [extreme_points; F];
    else
        FF = F;
    end
    [N, ~] = size(FF);

    % Shift by ideal
    FFF = FF - ideal_point;
    FFF(FFF < 1e-3) = 0;

    I = zeros(1, M);
    for i = 1 : M
        [~, I(i)] = min(max(FFF ./ repmat(weights(i,:), N, 1), [], 2));
    end

    extreme_points = FF(I, :);
end

function nadir_point = get_nadir_point(extreme_points, ideal_point, worst_point, worst_of_population, worst_of_front)
    M = size(extreme_points, 2);

    try
        % Solve (extreme - ideal) * plane = 1
        A = extreme_points - ideal_point;
        b = ones(M, 1);

        plane = A \ b;
        intercepts = 1 ./ plane';
        nadir_point = ideal_point + intercepts;

        % Check validity
        if any(isnan(plane)) || any(intercepts <= 1e-6) || norm(A * plane - b) > 1e-8
            error('Invalid hyperplane');
        end

        % Cap by historical worst
        mask = nadir_point > worst_point;
        nadir_point(mask) = worst_point(mask);

    catch
        % Fallback to worst of front
        nadir_point = worst_of_front;
    end

    % If too small, fallback to worst of population
    mask2 = (nadir_point - ideal_point) <= 1e-6;
    nadir_point(mask2) = worst_of_population(mask2);
end