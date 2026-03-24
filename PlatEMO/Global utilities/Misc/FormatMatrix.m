function FormatMatrix(str_format, matrix)
    for i=1:size(matrix,1)
        for j=1:size(matrix,2)
            fprintf(str_format, matrix(i,j));
        end
        fprintf("\n");
    end
    fprintf("\n");
end

