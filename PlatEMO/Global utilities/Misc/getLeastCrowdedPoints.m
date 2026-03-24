function [idx, filteredPF] = getLeastCrowdedPoints(PF, K)
    % PF: N x M matrix
    % K: Desired number of points (e.g., 120)
    
    [N, M] = size(PF);
    
    if N <= K
        idx = (1:N)';
        filteredPF = PF;
        return;
    end

    % 1. Normalize the data to ensure all objectives carry equal weight
    normPF = (PF - min(PF)) ./ (max(PF) - min(PF) + 1e-12);

    % 2. Perform K-means clustering
    % 'MaxIter' and 'Replicates' can be adjusted for speed vs accuracy
    [clusterIdx, centroids] = kmeans(normPF, K, ...
        'MaxIter', 1000, ...
        'Replicates', 3, ...
        'Display', 'off');

    % 3. Find the point in each cluster closest to its centroid
    idx = zeros(K, 1);
    for i = 1:K
        % Get points belonging to current cluster
        thisClusterMask = (clusterIdx == i);
        pointsInCluster = normPF(thisClusterMask, :);
        originalIndices = find(thisClusterMask);
        
        % Calculate distance from each point in cluster to its centroid
        distToCentroid = sum((pointsInCluster - centroids(i, :)).^2, 2);
        
        % Pick the point with the minimum distance
        [~, bestLocalIdx] = min(distToCentroid);
        idx(i) = originalIndices(bestLocalIdx);
    end
    
    filteredPF = PF(idx, :);
end