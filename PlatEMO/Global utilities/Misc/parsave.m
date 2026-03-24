function parsave(filepath, finalPop)
%PARSAVE Save function for use inside parfor
%   parfor doesn't allow save() with dynamic filenames directly,
%   so we wrap it in a function.
    save(filepath, 'finalPop', '-v6');
end