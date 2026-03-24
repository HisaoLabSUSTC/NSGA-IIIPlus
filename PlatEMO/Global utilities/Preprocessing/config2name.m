function [displayName, internalName] = config2name(config)
%CONFIG2NAME Generate algorithm names from configuration
%
%   [displayName, internalName] = config2name(config)
%
%   Name format: [Area1]-[Area2]-[Area3]-NSGA-III
%
%   All tokens use title case (first letter capitalized, rest lowercase).
%   Display names join tokens with '-'; internal names concatenate tokens.
%
%   Area 1 (Implementation):
%     Z  = removeThreshold
%     Y  = preserveCorners
%     X  = useArchive (EPA)
%     Order within Area 1: reversed alphabetical Z > Y > X
%     No flags = baseline (no Area 1 token)
%
%   Area 2 (Normalization):
%     Tk  = tikhonov
%
%   Area 3 (Selection): Dss
%
%   Returns:
%     displayName  - Human-readable name (e.g., "ZY-Tk-Dss-NSGA-III")
%     internalName - Internal class name (e.g., "ZYTkDssNSGAIIIwH")

    tokens = {};

    % === Area 1: Implementation modifications ===
    g1 = '';
    if config.removeThreshold
        g1 = [g1 'Z'];
    end
    if config.preserveCorners
        g1 = [g1 'Y'];
    end
    if config.useArchive
        g1 = [g1 'X'];
    end
    if ~isempty(g1)
        tokens{end+1} = g1;
    end

    % === Area 2: Normalization modifications ===
    switch lower(config.momentum)
        case 'tikhonov'
            tokens{end+1} = 'Tk';
        case 'none'
            % No normalization modification suffix
    end

    % === Area 3: Selection modifications ===
    if config.useDSS
        tokens{end+1} = 'Dss';
    end

    % === Assemble names ===
    % Display: tokens joined by '-', suffix 'NSGA-III'
    % Internal: tokens concatenated, suffix 'NSGAIIIwH'
    displayName  = strjoin([tokens, {'NSGA-III'}],   '-');
    internalName = strjoin([tokens, {'NSGAIIIwH'}],  '');
end
