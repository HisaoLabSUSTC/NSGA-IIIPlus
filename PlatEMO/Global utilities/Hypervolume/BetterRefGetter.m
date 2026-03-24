function ref = BetterRefGetter(PopObjs, refConstant)
    popmin = min(PopObjs,[],1);
    popmax = max(PopObjs,[],1);
    ref = popmin + refConstant * (popmax-popmin);
end