#!/usr/bin/env python3
"""
Generate LaTeX figure code for GECCO supplementary material.

This script scans the current directory for image triplets and generates
LaTeX code to display them in ACM two-column format.

Each set consists of:
  - PF-{problemName}-M{M}-D{D}.png           (Pareto Front)
  - MP-{AlgName}-{problemName}-M{M}-D{D}.png (Algorithm results)

The script automatically detects all algorithm names present in the directory
and generates figures with the appropriate number of subplots.

For large numbers of algorithms (300+), the script:
  - Organizes figures into multiple rows per problem
  - Uses reduced image sizes to prevent LaTeX memory issues
  - Supports loading algorithm names from JSON configuration

Usage:
    python batch_insert.py [--output OUTPUT_FILE] [--dir IMAGE_DIR]

    # With custom algorithm display names from JSON:
    python batch_insert.py --alg-json "./Info/Misc/algorithm_display_names.json"
"""

import os
import re
import json
import argparse
from pathlib import Path
from collections import defaultdict
import itertools
import string

# Default algorithm display name mappings (fallback)
DEFAULT_ALG_DISPLAY_NAMES = {
    'NSGAIIIwH': 'NSGA-III',
    'PyNSGAIIIwH': 'Py-NSGA-III',
}


def generate_subcaption_labels(num_items):
    labels = []
    # We start with length 1 ('a'), then length 2 ('aa'), etc.
    for length in itertools.count(1):
        # itertools.product generates ('a', 'a'), ('a', 'b'), etc.
        for p in itertools.product(string.ascii_lowercase, repeat=length):
            labels.append("".join(p))
            if len(labels) == num_items:
                return labels


def load_alg_display_names_from_json(json_path: str) -> dict:
    """
    Load algorithm display names from a JSON file.

    Expected JSON format:
    {
        "MeNSGAIIIwH": "Me-NSGA-III",
        "OrmeNSGAIIIwH": "Orme-NSGA-III",
        ...
    }
    """
    if not os.path.exists(json_path):
        print(f"  Warning: JSON file not found: {json_path}")
        return {}

    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        print(f"  Loaded {len(data)} algorithm display names from {json_path}")
        return data
    except json.JSONDecodeError as e:
        print(f"  Error parsing JSON file {json_path}: {e}")
        return {}


def parse_filename(filename: str) -> dict | None:
    """
    Parse an image filename to extract its components.

    Returns a dict with keys: type, problem, M, D, filename
    or None if the filename doesn't match expected patterns.
    """
    # Pattern 1: Pareto Front (PF)
    pf_pattern = r'^PF-(.+)-M(\d+)-D(\d+)\.png$'

    # Pattern 2: Generic Algorithm (MP)
    # Non-greedy match for algorithm name, greedy for problem (handles hyphens)
    mp_pattern = r'^MP-(.+?)-(.+)-M(\d+)-D(\d+)\.png$'

    match = re.match(pf_pattern, filename)
    if match:
        return {
            'type': 'PF',
            'problem': match.group(1),
            'M': int(match.group(2)),
            'D': int(match.group(3)),
            'filename': filename
        }

    match = re.match(mp_pattern, filename)
    if match:
        return {
            'type': match.group(1),
            'problem': match.group(2),
            'M': int(match.group(3)),
            'D': int(match.group(4)),
            'filename': filename
        }

    return None


def scan_directory(directory: str) -> tuple[dict, set]:
    """
    Scan directory for image files and group them by problem name.

    Returns:
        problems: dict {problem_name: {alg_type: parsed_info, ...}}
        algorithm_types: set of all algorithm types found (excluding 'PF')
    """
    problems = defaultdict(dict)
    algorithm_types = set()

    for filename in os.listdir(directory):
        if not filename.endswith('.png'):
            continue

        parsed = parse_filename(filename)
        if parsed:
            problem = parsed['problem']
            img_type = parsed['type']
            problems[problem][img_type] = parsed

            if img_type != 'PF':
                algorithm_types.add(img_type)

    return problems, algorithm_types


def get_display_name(alg_name: str, display_names: dict) -> str:
    """Get the display name for an algorithm, with fallback."""
    return display_names.get(alg_name, alg_name)


def generate_figure_latex_multirow(problem_data: dict, problem_name: str,
                                   algorithm_order: list, display_names: dict,
                                   image_prefix: str = "",
                                   max_per_row: int = 4,
                                   image_scale: float = 1.0) -> str:
    """
    Generate LaTeX code for a single figure with multiple rows.

    Handles arbitrary number of algorithms by organizing into rows.

    Args:
        problem_data: Dict with algorithm type keys mapping to parsed info
        problem_name: Name of the problem for the caption
        algorithm_order: List of algorithm types in display order
        display_names: Dict mapping algorithm names to display names
        image_prefix: Prefix path for images
        max_per_row: Maximum images per row
        image_scale: Scale factor for images (1.0 = full, 0.5 = half)
    """
    first_available = next(iter(problem_data.values()))
    m_val = first_available['M']
    d_val = first_available['D']

    # Build the order: PF first, then algorithms
    all_items = [('PF', 'True Pareto Front')]
    for alg in algorithm_order:
        if alg in problem_data:
            display_name = get_display_name(alg, display_names)
            all_items.append((alg, display_name))

    num_items = len(all_items)

    # Calculate rows needed
    num_rows = (num_items + max_per_row - 1) // max_per_row

    # Calculate width based on items per row
    items_in_first_row = min(num_items, max_per_row)
    base_width = 0.9 / items_in_first_row
    width = base_width * image_scale

    # Generate subcaption labels
    # subcaption_labels = [chr(ord('a') + i) for i in range(num_items)]
    subcaption_labels = generate_subcaption_labels(num_items)

    rows_latex = []
    item_idx = 0

    for row in range(num_rows):
        row_items = []
        items_this_row = min(max_per_row, num_items - item_idx)

        for i in range(items_this_row):
            key, label = all_items[item_idx]

            if key in problem_data:
                img_path = f"Visualization/images/{image_prefix}{problem_data[key]['filename']}"
                minipage = f"""\\begin{{minipage}}{{{width:.3f}\\linewidth}}
    \\centering
    \\includegraphics[width=\\linewidth]{{{img_path}}}
    \\caption*{{({subcaption_labels[item_idx]}) {label}}}
\\end{{minipage}}"""
            else:
                minipage = f"""\\begin{{minipage}}{{{width:.3f}\\linewidth}}
    \\centering
    % Missing: {key}
    \\caption*{{({subcaption_labels[item_idx]}) {label} -- N/A}}
\\end{{minipage}}"""

            row_items.append(minipage)
            item_idx += 1

        rows_latex.append("\\hfill\n".join(row_items))

    safe_label = re.sub(r'[^a-zA-Z0-9]', '', problem_name)
    latex_problem_name = problem_name.replace('_', r'\_')

    # Join rows with line breaks
    all_rows = "\n\n\\vspace{2mm}\n\n".join(rows_latex)

    figure = f"""\\begin{{figure*}}[htbp]
\\centering
{all_rows}
\\caption{{{latex_problem_name} (M={m_val}, D={d_val})}}
\\label{{fig:{safe_label}}}
\\end{{figure*}}
"""
    return figure


def natural_sort_key(s: str):
    """Generate a sort key for natural sorting."""
    parts = []
    for part in re.split(r'(\d+)', s):
        if part.isdigit():
            parts.append(int(part))
        else:
            parts.append(part.lower())
    return parts


def generate_all_latex(problems: dict, algorithm_order: list,
                       display_names: dict, image_prefix: str = "",
                       figures_per_page: int = 2,
                       max_per_row: int = 4,
                       image_scale: float = 1.0) -> str:
    """
    Generate LaTeX code for all problem figures.

    Args:
        problems: Dict of problem data from scan_directory()
        algorithm_order: List of algorithm types in display order
        display_names: Dict mapping algorithm names to display names
        image_prefix: Prefix path for images
        figures_per_page: Number of figures before clearpage
        max_per_row: Maximum images per row
        image_scale: Scale factor for images
    """
    latex_parts = []

    sorted_problems = sorted(problems.keys(), key=natural_sort_key)

    for i, problem_name in enumerate(sorted_problems):
        problem_data = problems[problem_name]

        # Filter to only algorithms that have images
        available_algs = [a for a in algorithm_order if a in problem_data]

        if not available_algs and 'PF' not in problem_data:
            latex_parts.append(f"% Skipping {problem_name}: no images found\n")
            continue

        figure_latex = generate_figure_latex_multirow(
            problem_data, problem_name,
            available_algs, display_names,
            image_prefix, max_per_row, image_scale
        )
        latex_parts.append(figure_latex)

        # Add clearpage periodically
        if (i + 1) % figures_per_page == 0 and i < len(sorted_problems) - 1:
            latex_parts.append("\\clearpage\n")

    return "\n".join(latex_parts)


def parse_alg_names_arg(arg_string: str) -> dict:
    """Parse the --alg-names argument string into a dictionary."""
    if not arg_string:
        return {}

    result = {}
    pairs = arg_string.split(',')
    for pair in pairs:
        pair = pair.strip()
        if ':' in pair:
            internal, display = pair.split(':', 1)
            result[internal.strip()] = display.strip()
        else:
            result[pair] = pair
    return result


def parse_alg_order_arg(arg_string: str) -> list:
    """Parse the --alg-order argument string into a list."""
    if not arg_string:
        return []
    return [name.strip() for name in arg_string.split(',') if name.strip()]


def main():
    parser = argparse.ArgumentParser(
        description='Generate LaTeX figure code for supplementary material'
    )
    parser.add_argument(
        '--dir', '-d',
        default='./Visualization/images',
        help='Directory containing the images (default: ./Visualization/images)'
    )
    parser.add_argument(
        '--output', '-o',
        default='figures.tex',
        help='Output LaTeX file (default: figures.tex)'
    )
    parser.add_argument(
        '--prefix', '-p',
        default='',
        help='Prefix path for images in LaTeX'
    )
    parser.add_argument(
        '--per-page', '-n',
        type=int,
        default=2,
        help='Number of figures per page before clearpage (default: 2)'
    )
    parser.add_argument(
        '--max-per-row',
        type=int,
        default=4,
        help='Maximum images per row (default: 4)'
    )
    parser.add_argument(
        '--image-scale',
        type=float,
        default=1.0,
        help='Scale factor for images (default: 1.0, use 0.7 for smaller)'
    )
    parser.add_argument(
        '--full-document',
        action='store_true',
        help='Generate a complete LaTeX document instead of just figures'
    )
    parser.add_argument(
        '--alg-names',
        default='',
        help='Algorithm display name mappings (format: "Internal1:Display1,Internal2:Display2")'
    )
    parser.add_argument(
        '--alg-json',
        default='./Info/Misc/algorithm_display_names.json',
        help='Path to JSON file with algorithm display names'
    )
    parser.add_argument(
        '--alg-order',
        default='',
        help='Specify algorithm order as comma-separated list (default: alphabetical)'
    )
    parser.add_argument(
        '--draft',
        action='store_true',
        help='Enable draft mode (adds [draft] to graphicx for faster rendering)'
    )

    args = parser.parse_args()

    # Scan the directory
    print(f"Scanning directory: {args.dir}")
    problems, detected_algorithms = scan_directory(args.dir)

    # Build display names: defaults -> JSON -> command line args
    display_names = DEFAULT_ALG_DISPLAY_NAMES.copy()

    # Load from JSON if available
    if args.alg_json:
        json_names = load_alg_display_names_from_json(args.alg_json)
        display_names.update(json_names)

    # Override with command line args
    user_display_names = parse_alg_names_arg(args.alg_names)
    display_names.update(user_display_names)

    # Determine algorithm order
    if args.alg_order:
        algorithm_order = parse_alg_order_arg(args.alg_order)
        for alg in algorithm_order:
            if alg not in detected_algorithms:
                print(f"  WARNING: Algorithm '{alg}' in order but not found")
    else:
        algorithm_order = sorted(detected_algorithms, key=natural_sort_key)

    print(f"\nDetected {len(detected_algorithms)} algorithm(s)")
    print(f"Found {len(problems)} problem(s)")
    print(
        f"Settings: max_per_row={args.max_per_row}, image_scale={args.image_scale}")

    # Show first 10 algorithms
    if len(algorithm_order) > 10:
        print(f"Algorithm order (first 10 of {len(algorithm_order)}):")
        for alg in algorithm_order[:10]:
            print(f"  - {alg} -> {get_display_name(alg, display_names)}")
        print(f"  ... and {len(algorithm_order) - 10} more")
    else:
        print("Algorithm order:")
        for alg in algorithm_order:
            print(f"  - {alg} -> {get_display_name(alg, display_names)}")

    # Generate LaTeX
    figures_latex = generate_all_latex(
        problems, algorithm_order, display_names,
        args.prefix, args.per_page, args.max_per_row, args.image_scale
    )

    if args.full_document:
        draft_opt = ",draft" if args.draft else ""
        document = f"""\\documentclass[sigconf,nonacm]{{acmart}}

\\settopmatter{{printacmref=false}}
\\renewcommand\\footnotetextcopyrightpermission[1]{{}}
\\pagestyle{{plain}}

\\usepackage{{booktabs}}
\\usepackage{{multirow}}
\\usepackage[{draft_opt}]{{graphicx}}
\\usepackage{{float}}

\\begin{{document}}

\\title{{Supplementary Material: Algorithm Comparison Figures}}
\\maketitle

{figures_latex}

\\end{{document}}
"""
        output_content = document
    else:
        output_content = figures_latex

    with open(args.output, 'w', encoding='utf-8') as f:
        f.write(output_content)

    print(f"\nGenerated LaTeX written to: {args.output}")
    print(f"Total figures: {len(problems)}")


if __name__ == '__main__':
    main()
