function config = parseAlgConfig(input)
%PARSEALGCONFIG Parse algorithm configuration from name string or struct
%
%   config = parseAlgConfig('ZYNSGAIIIwH')
%   config = parseAlgConfig('ZY-Tk-Dss-NSGA-III')
%   config = parseAlgConfig(struct('removeThreshold', true, 'momentum', 'tikhonov'))
%
%   Current naming convention (all tokens title-case):
%     Area 1 (Implementation): Z, Y, X flags in reversed-alphabetical
%       order. Examples: (none), Z, ZY, ZYX.
%       Legacy names with Py suffix (e.g., ZYPy) are also accepted.
%     Area 2 (Normalization): Tk (tikhonov)
%     Area 3 (Selection): Dss
%
%   Returns a config struct suitable for ModularNormHist and ConfigurableNSGAIIIwH

    % Default configuration
    config = struct(...
        'removeThreshold', false, ...
        'useArchive', false, ...
        'preserveCorners', false, ...
        'momentum', 'none', ...
        'useDSS', false ...
    );

    if isstruct(input)
        % Merge provided struct with defaults
        fields = fieldnames(input);
        for i = 1:length(fields)
            config.(fields{i}) = input.(fields{i});
        end
        return;
    end

    if ~ischar(input) && ~isstring(input)
        error('Input must be a string (algorithm name) or struct (config)');
    end

    name = char(input);

    % === Strip suffix to get prefix ===
    if endsWith(name, 'NSGAIIIwH')
        prefix = name(1:end-9);
        isInternal = true;
    elseif endsWith(name, 'NSGA-III')
        prefix = name(1:end-8);
        if endsWith(prefix, '-')
            prefix = prefix(1:end-1);
        end
        isInternal = false;
    else
        prefix = name;
        isInternal = true;
    end

    % === Check for pure baseline names ===
    if isempty(prefix) || strcmp(prefix, 'Py')
        return;  % Baseline: no modifications (Py is legacy, empty is current)
    end

    % === Parse remaining prefix (Areas 1-3) ===
    if isInternal
        remaining = prefix;

        % --- Area 1: Z/Y/X flags (optional Py suffix for legacy) ---
        [g1flags, remaining] = parseInternalGroup1(remaining);
        if g1flags.Z, config.removeThreshold = true; end
        if g1flags.Y, config.preserveCorners = true; end
        if g1flags.X, config.useArchive      = true; end

        % --- Area 2: Normalization ---
        if startsWith(remaining, 'Tk')
            config.momentum = 'tikhonov'; remaining = remaining(3:end);
        end

        % --- Area 3: Selection ---
        if startsWith(remaining, 'Dss')
            config.useDSS = true; remaining = remaining(4:end);
        elseif startsWith(remaining, 'DSS')
            config.useDSS = true; remaining = remaining(4:end);
        end

    else
        % === Display name: dash-separated tokens ===
        tokens = strsplit(prefix, '-');
        tokenIdx = 1;

        % --- Area 1 ---
        if tokenIdx <= numel(tokens)
            g1token = tokens{tokenIdx};
            parsed = parseDisplayGroup1(g1token);
            if parsed.any
                if parsed.Z, config.removeThreshold = true; end
                if parsed.Y, config.preserveCorners = true; end
                if parsed.X, config.useArchive      = true; end
                tokenIdx = tokenIdx + 1;
            elseif strcmp(g1token, 'Py')
                tokenIdx = tokenIdx + 1;
            end
        end

        % --- Area 2: Normalization ---
        if tokenIdx <= numel(tokens)
            if strcmp(tokens{tokenIdx}, 'Tk') || strcmp(tokens{tokenIdx}, 'TK')
                config.momentum = 'tikhonov';
                tokenIdx = tokenIdx + 1;
            end
        end

        % --- Area 3: Selection ---
        if tokenIdx <= numel(tokens)
            tok = tokens{tokenIdx};
            if strcmpi(tok, 'Dss') || strcmp(tok, 'DSS')
                config.useDSS = true; tokenIdx = tokenIdx + 1; %#ok<NASGU>
            end
        end
    end
end

%% ========================================================================
%  INTERNAL HELPER FUNCTIONS
%  ========================================================================

function [flags, remaining] = parseInternalGroup1(str)
%PARSEINTERNALGROUP1 Parse Group 1 token from internal name
%   Consumes Z/Y/X flags (in any order) then optional Py suffix.
    flags = struct('Z', false, 'Y', false, 'X', false, 'any', false);
    remaining = str;

    % Greedily consume Z/Y/X flags
    changed = true;
    while changed
        changed = false;
        if startsWith(remaining, 'Z')
            flags.Z = true; flags.any = true;
            remaining = remaining(2:end); changed = true;
        elseif startsWith(remaining, 'Y')
            flags.Y = true; flags.any = true;
            remaining = remaining(2:end); changed = true;
        elseif startsWith(remaining, 'X')
            flags.X = true; flags.any = true;
            remaining = remaining(2:end); changed = true;
        end
    end

    % Consume Py terminal marker
    if startsWith(remaining, 'Py')
        flags.any = true;
        remaining = remaining(3:end);
    end
end

function parsed = parseDisplayGroup1(token)
%PARSEDISPLAYGROUP1 Parse Group 1 display token (e.g., 'ZYPy', 'ZYXPy')
%   Returns struct with flags; parsed.any=false if token is not Group 1.
    parsed = struct('Z', false, 'Y', false, 'X', false, 'any', false);
    remaining = token;

    changed = true;
    while changed
        changed = false;
        if ~isempty(remaining) && remaining(1) == 'Z'
            parsed.Z = true; parsed.any = true;
            remaining = remaining(2:end); changed = true;
        elseif ~isempty(remaining) && remaining(1) == 'Y'
            parsed.Y = true; parsed.any = true;
            remaining = remaining(2:end); changed = true;
        elseif ~isempty(remaining) && remaining(1) == 'X'
            parsed.X = true; parsed.any = true;
            remaining = remaining(2:end); changed = true;
        end
    end

    % Consume Py terminal marker
    if startsWith(remaining, 'Py')
        parsed.any = true;
        remaining = remaining(3:end);
    end

    % If unconsumed content remains, this was not a valid Group 1 token
    if ~isempty(remaining)
        parsed = struct('Z', false, 'Y', false, 'X', false, 'any', false);
    end
end
