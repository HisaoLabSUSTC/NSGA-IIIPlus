function [PF, out2, out3] = GetPFnRef(problemOrName, ~)
%GETPFNREF Load stored reference PF and return ideal/nadir points.
%
%   [PF, ideal, nadir] = GetPFnRef(Problem)    % New 3-output form
%   [PF, ref] = GetPFnRef(Problem)             % Legacy 2-output form
%
%   Loads the stored reference PF for the given problem.
%
%   With 3 outputs: returns PF, ideal (min per obj), nadir (max per obj).
%   With 2 outputs (legacy): returns PF and ref point [1,1,...,1] in
%     normalized space (for backward compatibility with old HV callers).
%
%   NOTE: Reference PFs must be pre-generated using generateReferencePF().

    if ischar(problemOrName) || isstring(problemOrName)
        problemName = char(problemOrName);
    else
        problemName = class(problemOrName);
    end

    [PF, ideal, nadir] = loadReferencePF(problemName);

    if nargout <= 2
        % Legacy mode: return [PF, ref] where ref = ones(1,M) for normalized HV
        M = size(PF, 2);
        out2 = ones(1, M);
    else
        % New mode: return [PF, ideal, nadir]
        out2 = ideal;
        out3 = nadir;
    end
end
