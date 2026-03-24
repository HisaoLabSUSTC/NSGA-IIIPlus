import sys
import numpy as np
from pymoo.util.ref_dirs import get_reference_directions

if __name__ == "__main__":
    M = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    N = int(sys.argv[2]) if len(sys.argv) > 2 else 16
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 1

    ref_dirs = get_reference_directions("energy", M, N, seed=seed)
    # Output as CSV to stdout (easy to parse in MATLAB)
    np.savetxt(sys.stdout, ref_dirs, fmt='%.17g', delimiter=',')
