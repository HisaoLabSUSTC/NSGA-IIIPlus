function nds = nds_preprocess(Population)
    [FrontNo, ~] = NDSort(Population.objs, Population.cons, inf);
    nds = find(FrontNo==1);
end