function config = loadOptimumConfig()
    persistent cachedConfig;
    
    if isempty(cachedConfig)
        configPath = './Info/Misc/optimum_config.json';
        
        if exist(configPath, 'file')
            jsonText = fileread(configPath);
            cachedConfig = jsondecode(jsonText);
        else
            % Fallback defaults if file doesn't exist
            warning('Config file not found: %s. Using defaults.', configPath);
            cachedConfig = struct(...
                'default_num_opt', 120, ...
                'target_points', 120, ...
                'overrides', struct());
        end
    end
    
    config = cachedConfig;
end