function [PF, ideal, nadir] = loadReferencePF(problemName, ID)
%LOADREFERENCEPF Load a stored reference Pareto front and compute ideal/nadir.
%
%   [PF, ideal, nadir] = loadReferencePF(problemName)
%
%   Loads the reference PF from ./Info/ReferencePF/RefPF-{problemName}.mat
%   and computes the true ideal point (min per objective) and true nadir
%   point (max per objective) from the PF.
%
%   Input:
%     problemName - String name of the problem (e.g., 'DTLZ1')
%
%   Output:
%     PF    - N x M matrix of Pareto front objective values
%     ideal - 1 x M vector of ideal point (min per objective)
%     nadir - 1 x M vector of nadir point (max per objective)
%
%   NOTE: You must run generateReferencePF() first to create the stored PFs.

    if nargin == 2
        refPath = fullfile('.', 'Info', 'ReferencePF', sprintf('RefPF-%s_ID%d.mat', problemName, ID));
    else
        refPath = fullfile('.', 'Info', 'ReferencePF', sprintf('RefPF-%s.mat', problemName));
    end

    if ~exist(refPath, 'file')
        error('loadReferencePF:FileNotFound', ...
            'Reference PF not found: %s\nRun generateReferencePF() first.', refPath);
    end

    data = load(refPath, 'PF');
    PF = data.PF;

    % Compute true ideal and nadir from the reference PF
    ideal = min(PF, [], 1);
    nadir = max(PF, [], 1);
end
