function processAlgorithmProblemPair(algorithmName, problemName, problemHandle, statsDir, M)
%PROCESSALGORITHMPROBLEMPAIR Compute stability statistics for one pair.
%
%   problemName is the pipeline name (e.g. 'MOTSP_ID1' or 'DTLZ1').
%   File lookups use this name: IN-{alg}-{problemName}.mat
%   Reference PF lookups use this name: RefPF-{problemName}.mat

    % Load data
    dataDir = sprintf('./Info/IdealNadirHistory/%s', algorithmName);
    fileName = sprintf('IN-%s-%s.mat', algorithmName, problemName);
    filePath = fullfile(dataDir, fileName);

    if ~exist(filePath, 'file')
        fprintf('  Warning: File not found: %s\n', filePath);
        return;
    end

    fileData = load(filePath);
    idealHistories = fileData.ideal_history;
    nadirHistories = fileData.nadir_history;

    % Get ground truth
    [PF, gt_ideal, gt_nadir] = loadReferencePF(problemName);

    % Normalize histories
    norm_idealHistories = cellfun(@(c) (c-gt_ideal+eps)./(gt_nadir-gt_ideal+eps), ...
        idealHistories, 'UniformOutput', false);
    norm_nadirHistories = cellfun(@(c) (c-gt_ideal+eps)./(gt_nadir-gt_ideal+eps), ...
        nadirHistories, 'UniformOutput', false);

    % Detect stability and compute statistics
    ideal_stats = computeStabilityStatistics(norm_idealHistories, 'ideal', M);
    nadir_stats = computeStabilityStatistics(norm_nadirHistories, 'nadir', M);

    % Save statistics using pipeline name
    saveStatistics(ideal_stats, statsDir, algorithmName, problemName, 'Ideal');
    saveStatistics(nadir_stats, statsDir, algorithmName, problemName, 'Nadir');

    % Print summary
    printSummary(ideal_stats, nadir_stats, algorithmName, problemName);
end
