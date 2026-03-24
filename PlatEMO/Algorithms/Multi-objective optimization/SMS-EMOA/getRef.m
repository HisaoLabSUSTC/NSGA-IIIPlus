function ref = getRef(Population, refConstant)
    invRefConstant = 2 - refConstant;
    ref = max(Population.objs,[],1);

    % Check if any values in maxPopObj are negative
    for i = 1:length(ref)
        if ref(i) < 0
            % For negative values, apply invRefConstant
            ref(i) = ref(i) * invRefConstant;
        else
            % For positive values, apply refConstant
            ref(i) = ref(i) * refConstant;
        end
    end
end