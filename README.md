# NSGA-III+: Improved NSGA-III for Many-Objective Optimization

An enhanced NSGA-III implementation built on [PlatEMO](https://github.com/BIMK/PlatEMO), addressing three known deficiencies in standard NSGA-III: implementation vulnerabilities in nadir point estimation, ill-conditioned hyperplane fitting, and random non-niched survivor selection.

## Modifications

NSGA-III+ introduces three layers of improvements, each targeting a specific deficiency:

| Layer | Deficiency | Modification | Effect |
|-------|-----------|--------------|--------|
| **Area 1** - Implementation | Unstable extreme point detection | `Z` (remove $10^{-3}$ threshold), `Y` (preserve corner solutions), `X` (extreme point archive) | Improved convergence (HV, IGD+) |
| **Area 2** - Normalization | Ill-conditioned hyperplane system | Tikhonov regularization (`Tk`) with adaptive scaling | Stable nadir estimation, bounded condition number |
| **Area 3** - Selection | Random non-niched selection | Distance-based Subset Selection (`DSS`) | Deterministic, improved diversity |

These modifications are composable: any combination can be enabled independently.

## Quick Start

### Requirements

- MATLAB R2018a or later (GUI features require R2020b+)
- No additional toolboxes required

### Running a Single Experiment

```matlab
cd PlatEMO
platemo('algorithm', {@ConfigurableNSGAIIIwH, struct( ...
    'removeThreshold', true, ...
    'preserveCorners', true, ...
    'momentum', 'tikhonov', ...
    'useDSS', true)}, ...
    'problem', @DTLZ1, 'N', 120, 'M', 3, 'maxFE', 100000);
```

### Using `generateAlgorithm` (Recommended)

The `generateAlgorithm` helper creates algorithm specs from concise name-value arguments:

```matlab
cd PlatEMO

% Baseline NSGA-III
alg = generateAlgorithm();

% Full NSGA-III+ (all three layers)
alg = generateAlgorithm('area1', 'ZY', 'momentum', 'tikhonov', 'dss', true);

% Run with platemo
platemo('algorithm', alg, 'problem', @DTLZ1, 'N', 120, 'M', 3, 'maxFE', 100000);
```

### Ablation Study Configurations

```matlab
% Row A: NSGA-III baseline
algA = generateAlgorithm();

% Row B: ZY-NSGA-III (implementation fixes only)
algB = generateAlgorithm('area1', 'ZY');

% Row C: ZY-Tk-NSGA-III (+ Tikhonov regularization)
algC = generateAlgorithm('area1', 'ZY', 'momentum', 'tikhonov');

% Row D: ZY-Tk-Dss-NSGA-III (+ DSS) -- full NSGA-III+
algD = generateAlgorithm('area1', 'ZY', 'momentum', 'tikhonov', 'dss', true);
```

## Configuration Reference

### Area 1: Implementation Flags

| Flag | Config Field | Description |
|------|-------------|-------------|
| `Z` | `removeThreshold` | Removes the `1e-3` threshold in ASF computation that can cause extreme point detection failures |
| `Y` | `preserveCorners` | Preserves corner solutions (per-objective minima) during environmental selection |
| `X` | `useArchive` | Maintains an unbounded archive for extreme point tracking across generations |

Pass any combination via the `'area1'` argument: `'Z'`, `'ZY'`, `'ZYX'`, etc.

### Area 2: Normalization

| Method | Config Value | Description |
|--------|-------------|-------------|
| None | `'none'` (default) | Standard hyperplane fitting via ASF-based extreme points |
| Tikhonov | `'tikhonov'` | Ridge-regularized hyperplane solve; guarantees invertibility |

Tikhonov parameters (pass as additional name-value pairs to `generateAlgorithm`):

| Parameter | Default | Description |
|-----------|---------|-------------|
| `regLambda` | `1e-3` | Base regularization strength |
| `regAdaptive` | `true` | Scale lambda relative to data energy (recommended) |
| `regPrior` | `'worst_of_front'` | Prior for penalty term. Options: `'worst_of_front'`, `'previous'`, `'uniform'` |

Example with custom Tikhonov parameters:
```matlab
alg = generateAlgorithm('momentum', 'tikhonov', 'regLambda', 1e-2, 'regAdaptive', true);
```

### Area 3: Selection

| Method | Config Value | Description |
|--------|-------------|-------------|
| Standard | `false` (default) | NSGA-III niche-count based random selection for non-niched slots |
| DSS | `true` | Distance-based Subset Selection -- deterministic, maximizes minimum pairwise distance |

## Benchmark Pipeline

A full benchmarking pipeline is included for systematic evaluation:

```matlab
cd PlatEMO

% Define algorithms
algorithms = {
    generateAlgorithm(), ...                                                     % Baseline
    generateAlgorithm('area1', 'ZY'), ...                                        % +Implementation
    generateAlgorithm('area1', 'ZY', 'momentum', 'tikhonov'), ...               % +Normalization
    generateAlgorithm('area1', 'ZY', 'momentum', 'tikhonov', 'dss', true), ...  % +Selection
};

% Define problems (plain handle uses default M; {handle, M} overrides)
problems = {@DTLZ1, @DTLZ2, {@MaF1, 5}, @WFG1, @MinusDTLZ1};

% Parameters
params = struct('FE', 100000, 'N', 120, 'M', 3, 'runs', 30);

% Run the pipeline (see BenchmarkPipeline.m for the full task list)
```

The pipeline computes four metrics:

| Metric | Direction | Validates |
|--------|-----------|-----------|
| HV (Hypervolume) | Higher is better | Convergence |
| IGD+ (Inverted Generational Distance+) | Lower is better | Convergence |
| Generalized Spread (Delta*) | Lower is better | Diversity |
| Time | Lower is better | Efficiency |

All quality metrics are computed in normalized `[0, 1]` objective space.

## Project Structure

```
PlatEMO/
  Algorithms/Multi-objective optimization/NSGA-III/
    ConfigurableNSGAIIIwH.m    # Unified configurable algorithm
    PymooEnvironmentalSelection.m  # Standard environmental selection
    DSSEnvironmentalSelection.m    # DSS environmental selection
  Benchmarks/
    BenchmarkPipeline.m        # Main benchmark orchestrator
    ComparisonPipeline.m       # Statistical comparison tables
    generateAlgorithm.m        # Algorithm spec generator
  Global utilities/
    DataStruct/ModularNormHist.m   # Modular normalization with Tikhonov
    Visualization/                 # Plotting and figure generation
    PF/                            # Reference Pareto front generation/loading
    Metrics/                       # Anytime metric computation
  platemo.m                    # PlatEMO entry point
```

## Naming Convention

Algorithm variants follow the pattern `[Area1]-[Area2]-[Area3]-NSGA-III`:

| Example | Area 1 | Area 2 | Area 3 |
|---------|--------|--------|--------|
| NSGA-III | -- | -- | -- |
| ZY-NSGA-III | Z + Y | -- | -- |
| ZY-Tk-NSGA-III | Z + Y | Tikhonov | -- |
| ZY-Tk-Dss-NSGA-III | Z + Y | Tikhonov | DSS |

## Citation

This project builds on PlatEMO. If you use this code, please cite:

```bibtex
@article{tian2017platemo,
  title={PlatEMO: A MATLAB platform for evolutionary multi-objective optimization},
  author={Tian, Ye and Cheng, Ran and Zhang, Xingyi and Jin, Yaochu},
  journal={IEEE Computational Intelligence Magazine},
  volume={12},
  number={4},
  pages={73--87},
  year={2017}
}
```

## License

PlatEMO is free to use for research purposes. See PlatEMO's license terms for details.
