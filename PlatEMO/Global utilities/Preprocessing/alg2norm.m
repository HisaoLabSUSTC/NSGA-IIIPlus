function NormStruct = alg2norm(algName, N, M)
%ALG2NORM Create normalization structure for a given algorithm
%
%   NormStruct = alg2norm(algName, N, M)
%
%   Supports both legacy algorithm names and the new modular system.
%   For unrecognized names, attempts to parse using parseAlgConfig
%   and create a ModularNormHist.

    % === Legacy support for existing algorithm files ===
    % These use the original implementation files for exact compatibility

    if strcmp(algName, "NSGAIIIwH")
        NormStruct = PyNormalizationHistory(M);
        return;
    elseif strcmp(algName, "PyNSGAIIIwH")
        NormStruct = PyNormalizationHistory(M);
        return;
    elseif strcmp(algName, "GtNSGAIIIwH")
        NormStruct = PyNormalizationHistory(M);
        return;
    end

    % === Try modular system for all other names ===
    try
        config = parseAlgConfig(algName);
        NormStruct = ModularNormHist(M, config);
        return;
    catch
        % Fall through to legacy handling
    end

    % === Legacy fallback for specific algorithm names ===
    if strcmp(algName, "MeNSGAIIIwH")
        NormStruct = MedNormHist(M);
    elseif strcmp(algName, "OrmeNSGAIIIwH")
        NormStruct = OrthoMedNormHist(M);
    elseif strcmp(algName, "PyaNSGAIIIwH")
        NormStruct = PyaNormalizationHistory(M);
    elseif strcmp(algName, "PybNSGAIIIwH")
        NormStruct = PybNormalizationHistory(M);
    elseif strcmp(algName, "PycNSGAIIIwH")
        NormStruct = PyNormalizationHistory(M);
    elseif strcmp(algName, "PydNSGAIIIwH")
        NormStruct = PydNormalizationHistory(M);
    elseif strcmp(algName, "AdamPyNSGAIIIwH")
        NormStruct = PyMomentumNormHist(M, 'adam', 'Alpha', 0.3, 'Beta1', 0.9, 'Beta2', 0.999);
    elseif strcmp(algName, "AdamwPyNSGAIIIwH")
        NormStruct = PyMomentumNormHist(M, 'adamw', 'Alpha', 0.3, 'WeightDecay', 0.1);
    elseif strcmp(algName, "EmaPyNSGAIIIwH")
        NormStruct = PyMomentumNormHist(M, 'ema', 'Gamma', 0.9);
    elseif strcmp(algName, "HbPyNSGAIIIwH")
        NormStruct = PyMomentumNormHist(M, 'heavyball', 'Alpha', 0.3, 'Beta', 0.8);
    elseif strcmp(algName, "NagPyNSGAIIIwH")
        NormStruct = PyMomentumNormHist(M, 'nag', 'Alpha', 0.3, 'Beta', 0.8);
    elseif strcmp(algName, "RmsPyNSGAIIIwH")
        NormStruct = PyMomentumNormHist(M, 'rmsprop', 'Alpha', 0.3, 'Beta', 0.9);
    elseif strcmp(algName, "DSSPyNSGAIIIwH")
        NormStruct = PyNormalizationHistory(M);
    elseif strcmp(algName, "AgNSGAIIIwH")
        NormStruct = AvgNormHist(M);
    elseif strcmp(algName, "OragNSGAIIIwH")
        NormStruct = OrthoAvgNormHist(M);
    elseif strcmp(algName, "MaNSGAIIIwH")
        NormStruct = MaxNormHist(M);
    elseif strcmp(algName, "OrmaNSGAIIIwH")
        NormStruct = OrthoMaxNormHist(M);
    else
        % Final fallback: try to create ModularNormHist from parsed config
        try
            config = parseAlgConfig(algName);
            NormStruct = ModularNormHist(M, config);
        catch
            warning('MATLAB:AlgorithmName', "Algorithm name %s not recognized. Using default Py config.", algName);
            NormStruct = ModularNormHist(M, struct());
        end
    end
end
