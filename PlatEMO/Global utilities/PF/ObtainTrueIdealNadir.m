% phs = {@BT1, @BT2, @BT3, @BT4, @BT5, @BT6, @BT7, @BT8, @BT9, ...
%     @DTLZ1, @DTLZ2, @DTLZ3, @DTLZ4, @DTLZ5, @DTLZ6, @DTLZ7, @IDTLZ1, @IDTLZ2, ...
%     @SDTLZ1, @SDTLZ2, @IMOP1, @IMOP2, @IMOP3, @IMOP4, @IMOP5, @IMOP6, @IMOP7, @IMOP8, ...
%     @MaF1,@MaF2,@MaF3,@MaF4,@MaF5,@MaF6,@MaF7,@MaF10,@MaF11,@MaF12,@MaF13,@MaF14,@MaF15,...
%     @MinusDTLZ1,@MinusDTLZ2,@MinusDTLZ3,@MinusDTLZ4,@MinusDTLZ5,@MinusDTLZ6,...
%     @MinusWFG1,@MinusWFG2,@MinusWFG3,@MinusWFG4,@MinusWFG5,@MinusWFG6,@MinusWFG7,@MinusWFG8,@MinusWFG9,...
%     @RWA1,@RWA2,@RWA3,@RWA4,@RWA5,@RWA6,@RWA7, @VNT1, @VNT2, @VNT3,...
%     @WFG1,@WFG2,@WFG3,@WFG4,@WFG5,@WFG6,@WFG7,@WFG8,@WFG9,@ZDT1,@ZDT2,@ZDT3,@ZDT4,@ZDT6};
phs = {@UF1, @UF2, @UF3, @UF4, @UF5, @UF6, @UF7, @UF8, @UF9, @UF10};

for i=1:numel(phs)
    ph = phs{i};
    Problem = ph();
    [ideal_pfs, nadir_pfs] = ObtainTrueIdealNadirMethod(Problem);
    fprintf("PFs %s Ideal: (", class(Problem))
    fprintf("%.16f, ", ideal_pfs); fprintf("\b\b).");
    fprintf(" Nadir: (")
    fprintf("%.16f, ", nadir_pfs); fprintf("\b\b).");
    fprintf("\n");

    [ideal_opt, nadir_opt] = ObtainFakeIdealNadirMethod(Problem);
    fprintf("Opt %s Ideal: (", class(Problem))
    fprintf("%.16f, ", ideal_opt); fprintf("\b\b).");
    fprintf(" Nadir: (")
    fprintf("%.16f, ", nadir_opt); fprintf("\b\b).");
    fprintf("\n");

    fprintf("Equal? Ideal: %d, Nadir: %d\n", ...
        isequaln(ideal_pfs, ideal_opt), ...
        isequaln(nadir_pfs, nadir_opt));
    fprintf("\n");
    % return
end


function [ideal, nadir] = ObtainTrueIdealNadirMethod(Problem)
    PF = [];
    if ~isempty(Problem.PF)
        if ~iscell(Problem.PF)
            if Problem.M == 2
                PF = [Problem.PF];
            elseif Problem.M == 3
                PF = [Problem.PF];
            end
        else
            PF = cell2mat( cellfun(@(A) A(:), Problem.PF, 'UniformOutput', false) );
            PF = PF(~any(isnan(PF), 2), :);
        end
    elseif size(Problem.optimum,1) > 1 && Problem.M < 4
        PF = Problem.optimum;
    end

    ideal = min(PF);
    nadir = max(PF);
end

function [ideal, nadir] = ObtainFakeIdealNadirMethod(Problem)
    PF = [];
    PF = Problem.optimum;

    ideal = min(PF);
    nadir = max(PF);
end