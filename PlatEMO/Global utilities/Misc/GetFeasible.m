function feasible_pop = GetFeasible(Population)
    Popcons = Population.cons;
    feasible_pop = Population(all(Popcons <= 0, 2));
end

