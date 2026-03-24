function algSpec = generateAlgorithm(varargin)
%GENERATEALGORITHM Create a single algorithm spec from name-value arguments
%
%   algSpec = generateAlgorithm()
%   algSpec = generateAlgorithm('area1', 'ZY')
%   algSpec = generateAlgorithm('area1', 'ZY', 'momentum', 'tikhonov', 'dss', true)
%
%   Naming convention: [Area1]-[Area2]-[Area3]-NSGA-III
%   All tokens use title case (e.g., ZY, Tk, Dss).
%   The base algorithm is implicitly Py-NSGA-III; the Py prefix is omitted.
%
%   Name-Value Arguments:
%     'area1'    - Area 1 (implementation) flags: any combo of Z/Y/X (default: '' = baseline)
%                  Examples: 'ZY' -> ZY, 'ZYX' -> ZYX, 'Y' -> Y
%     'momentum' - Area 2 (normalization) method (default: 'none')
%                  Options: 'none', 'tikhonov' (Tk)
%     'dss'      - Area 3 (selection): enable DSS true/false (default: false)
%
%   Any additional name-value pairs are forwarded directly into the config
%   struct, allowing Tikhonov tuning parameters to be set inline:
%     generateAlgorithm('momentum', 'tikhonov', 'regLambda', 1e-2)
%     generateAlgorithm('momentum', 'tikhonov', 'regAdaptive', false, 'regPrior', 'previous')
%
%   Returns: cell array {@ConfigurableNSGAIIIwH, config} suitable for pipeline functions
%
%   Examples (ablation study rows A-D):
%     % Row A: NSGA-III (baseline)
%     algA = generateAlgorithm();
%
%     % Row B: ZY-NSGA-III (implementation fixes)
%     algB = generateAlgorithm('area1', 'ZY');
%
%     % Row C: ZY-Tk-NSGA-III (+ Tikhonov regularization)
%     algC = generateAlgorithm('area1', 'ZY', 'momentum', 'tikhonov');
%
%     % Row D: ZY-Tk-Dss-NSGA-III (+ DSS selection)
%     algD = generateAlgorithm('area1', 'ZY', 'momentum', 'tikhonov', 'dss', true);

    p = inputParser;
    p.KeepUnmatched = true;
    addParameter(p, 'area1', '', @ischar);
    addParameter(p, 'momentum', 'none', @ischar);
    addParameter(p, 'dss', false, @islogical);
    parse(p, varargin{:});

    area1 = p.Results.area1;

    config = struct(...
        'removeThreshold', contains(area1, 'Z'), ...
        'preserveCorners', contains(area1, 'Y'), ...
        'useArchive', contains(area1, 'X'), ...
        'momentum', p.Results.momentum, ...
        'useDSS', p.Results.dss);

    % Forward any unrecognised name-value pairs straight into the config
    extra = fieldnames(p.Unmatched);
    for i = 1:numel(extra)
        config.(extra{i}) = p.Unmatched.(extra{i});
    end

    algSpec = {@ConfigurableNSGAIIIwH, config};
end
