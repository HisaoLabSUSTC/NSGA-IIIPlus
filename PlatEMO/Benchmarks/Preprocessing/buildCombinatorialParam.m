function paramCell = buildCombinatorialParam(problemName, ID)
%BUILDCOMBINATORIALPARAM Build the 'parameter' cell for a combinatorial problem.
%
%   paramCell = buildCombinatorialParam(problemName, ID)
%
%   Each combinatorial problem class has its own positional parameter
%   layout (set via ParameterSet in Setting).  This function returns the
%   correctly ordered cell array for a given problem class and instance ID.
%
%   Input:
%     problemName - String name of the problem class ('MOTSP', 'MOKP', ...)
%     ID          - Instance identifier (positive integer)
%
%   Output:
%     paramCell   - Cell array suitable for 'parameter' in platemo() calls
%
%   Example:
%     platemo('problem', @MOTSP, 'M', 3, 'D', 12, ...
%             'parameter', buildCombinatorialParam('MOTSP', 1), ...);

    switch problemName
        case 'MOTSP'
            % MOTSP.ParameterSet(c, ID, FID): c=0 (uncorrelated), FID='' (auto)
            paramCell = {0, ID, ''};
        case 'MOKP'
            % MOKP.ParameterSet(ID)
            paramCell = {ID};
        otherwise
            warning('buildCombinatorialParam:unknownProblem', ...
                'Unknown combinatorial problem "%s"; passing ID as sole parameter.', ...
                problemName);
            paramCell = {ID};
    end
end
