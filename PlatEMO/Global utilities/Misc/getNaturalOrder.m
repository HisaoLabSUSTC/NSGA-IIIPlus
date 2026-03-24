function sortedIndices = getNaturalOrder(strList)
    % 1. Use regex to split strings into alphabet part and number part
    % Pattern: (.*?) matches the prefix, (\d+) matches the trailing digits
    tokens = regexp(strList, '^(.*?)(-?\d+)$', 'tokens', 'once');
    
    % Handle cases where the string might not match (optional safety)
    if any(cellfun(@isempty, tokens))
        error('All strings must end with a number (e.g., "UF10").');
    end

    % 2. Extract into a table for multi-level sorting
    extracted = vertcat(tokens{:});
    prefixes = extracted(:, 1);
    numbers = str2double(extracted(:, 2));

    % 3. Perform a stable sort: 
    % Sort by number first, then by prefix to maintain hierarchy
    [~, sortedIndices] = sortrows(table(prefixes, numbers));
end