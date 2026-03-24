function GenerateRefHVfromPF(problemHandles, M, N, problemNames)
%GENERATEREFHVFROMPF Compute reference hypervolume in normalized [0,1] space.
%
%   GenerateRefHVfromPF(problemHandles, M, N)
%   GenerateRefHVfromPF(problemHandles, M, N, problemNames)
%
%   For each problem, loads the stored reference PF, normalizes to [0,1]
%   using the true ideal/nadir, and computes the maximum obtainable HV
%   with reference point [1+1/H, ..., 1+1/H].
%
%   Input:
%     problemHandles - Cell array of problem function handles
%     M              - Number of objectives. Scalar (applied to all) or
%                      vector with one value per problem. (default: 3)
%     N              - Population size (for HV reference point scaling)
%     problemNames   - (optional) Cell array of pipeline names.
%                      Defaults to func2str of each handle.
%                      For combinatorial: 'MOTSP_ID1', etc.
%
%   Output:
%     Saves prob2rhv map to ./Info/FinalHV/ReferenceHV/prob2rhv.mat

    if nargin < 2
        M = 3;
    end

    % Expand scalar M to vector
    if isscalar(M)
        M = repmat(M, 1, numel(problemHandles));
    end

    if nargin < 4 || isempty(problemNames)
        pns = cellfun(@func2str, problemHandles, 'UniformOutput', false);
    else
        pns = problemNames;
    end

    fprintf('=== Computing Reference Hypervolumes (normalized [0,1] space) ===\n');

    prob2rhv = containers.Map();

    for i = 1:numel(pns)
        pn = pns{i};
        M_i = M(i);
        fprintf('  [%d/%d] %s (M=%d): ', i, numel(pns), pn, M_i);

        % Load stored reference PF
        [PF, ideal, nadir] = loadReferencePF(pn);
        range = nadir - ideal;
        range(range < 1e-12) = 1e-12;

        % Normalize PF to [0,1]
        PF_norm = (PF - ideal) ./ range;

        % HV reference point: 1 + 1/H (cite ishibuchi et al.)
        H = getRefH(M_i, N);
        ref = ones(1, M_i) + ones(1, M_i)./H;

        % Compute maximum obtainable HV
        hv = stk_dominatedhv(PF_norm, ref);
        prob2rhv(pn) = hv;

        fprintf('refHV = %.6f\n', hv);
    end

    % Save
    outDir = './Info/FinalHV/ReferenceHV';
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    save(fullfile(outDir, 'prob2rhv.mat'), 'prob2rhv');
    fprintf('Saved to %s\n', outDir);
end
