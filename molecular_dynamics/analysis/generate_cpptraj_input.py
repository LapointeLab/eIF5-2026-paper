#!/usr/bin/env python3
"""
Generate cpptraj input files for MD trajectory analysis.

This script generates a single cpptraj input file per trajectory that performs
all requested analyses (rmsd_nofit, rmsf, rmsd, distance) in one pass, loading
the trajectory only once for efficiency.

Features:
- Loads domains from domains.csv with analysis type filtering
- Loads distance pairs from distance_pairs.csv
- Uses prmtop topology files
- Supports frame range specification
- Generates cpptraj scripts with proper syntax
"""

import argparse
import csv
import os
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# Hardcoded residue mask for global trajectory alignment
# These residues define the alignment reference frame for all analyses
ALIGNMENT_MASK = ":1995-2024,2032-2108,2130-2247,2258-2313,2329-2351,2356-2455"


def load_domains_csv(csv_file: str) -> Dict[str, Dict[str, any]]:
    """
    Load domain definitions from CSV file.

    Args:
        csv_file: Path to domains.csv

    Returns:
        Dictionary mapping domain names to their properties:
        {domain_name: {'mask': str, 'analyses': List[str]}}
    """
    domains = {}
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            domain_name = row['domain']
            mask = row['mask']
            # Parse semicolon-separated analyses
            analyses = [a.strip() for a in row['analyses'].split(';')]
            domains[domain_name] = {
                'mask': mask,
                'analyses': analyses
            }
    return domains


def load_distance_pairs_csv(csv_file: str) -> List[Dict[str, str]]:
    """
    Load distance pair definitions from CSV file.

    Args:
        csv_file: Path to distance_pairs.csv

    Returns:
        List of dictionaries with distance pair information:
        [{'label': str, 'mask1': str, 'mask2': str}, ...]
    """
    distance_pairs = []
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            distance_pairs.append({
                'label': row['label'],
                'mask1': row['mask1'],
                'mask2': row['mask2']
            })
    return distance_pairs


def load_hbond_pairs_csv(csv_file: str) -> List[Dict[str, str]]:
    """
    Load hydrogen bond pair definitions from CSV file.

    Args:
        csv_file: Path to hbond_pair.csv

    Returns:
        List of dictionaries with hbond pair information:
        [{'label': str, 'donormask': str, 'acceptormask': str}, ...]
    """
    hbond_pairs = []
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            hbond_pairs.append({
                'label': row['label'],
                'donormask': row['donormask'],
                'acceptormask': row['acceptormask']
            })
    return hbond_pairs


def get_backbone_atoms(domain_name: str) -> str:
    """
    Determine appropriate backbone atom selection based on domain type.

    Args:
        domain_name: Name of the domain

    Returns:
        Backbone atom selector (@CA for protein, @C4' for RNA)
    """
    # RNA domains use C4' ribose carbon
    if "tRNA" in domain_name or "mRNA" in domain_name or "codon" in domain_name or "anticodon" in domain_name:
        return "@C4'"
    # Protein domains use alpha carbon
    else:
        return "@CA"


def extract_variant(system_name: str) -> str:
    """
    Extract eIF5 variant from system name.

    Args:
        system_name: System name (e.g., 20250917_48S_eIF5wt_AUG)

    Returns:
        Variant name (e.g., eIF5wt, eIF5_N30Q, eIF5_N30K, eIF5_G29A_G31A)
    """
    parts = system_name.split('_')
    # Find the part that starts with 'eIF5'
    for part in parts:
        if part.startswith('eIF5'):
            # Check if next part is also part of variant name (e.g., G29A)
            idx = parts.index(part)
            if idx + 1 < len(parts) and parts[idx + 1] in ['G29A', 'N30Q', 'N30K', 'N30R']:
                # Handle multi-part variant names
                if idx + 2 < len(parts) and parts[idx + 2] in ['G31A']:
                    return f"{part}_{parts[idx + 1]}_{parts[idx + 2]}"
                return f"{part}_{parts[idx + 1]}"
            return part
    return "eIF5wt"  # Default fallback


def get_variant_specific_atom(residue: str, atom: str, variant: str, dataset: str) -> str:
    """
    Get variant-specific atom name for eIF5 position 30.

    In the 20251112 dataset, eIF5 position 30 corresponds to residue 846.

    In eIF5 wt systems, position 30 is asparagine with ND2 atom.
    In mutant systems:
    - N30Q: glutamine with NE2 atom
    - N30K: lysine with NZ atom

    Args:
        residue: Residue number as string
        atom: Original atom name
        variant: eIF5 variant (e.g., eIF5wt, eIF5_N30Q, eIF5_N30K)
        dataset: Dataset identifier (20251112)

    Returns:
        Corrected atom name based on variant
    """
    # Only modify eIF5 position 30 (residue 846) with ND2 atom
    is_eif5_pos30 = (residue == "846")

    if not is_eif5_pos30 or atom != "ND2":
        return atom

    # Map variant to correct atom name
    if "N30Q" in variant:
        return "NE2"
    elif "N30K" in variant or "N30R" in variant:
        return "NZ"
    else:
        # WT and G29A_G31A keep ND2
        return "ND2"


def apply_variant_correction_to_mask(mask: str, variant: str, dataset: str) -> str:
    """
    Apply variant-specific atom corrections to any atom mask.

    For eIF5 N30 variants, replaces ND2 atom with appropriate atom:
    - N30Q: NE2 (glutamine)
    - N30K/N30R: NZ (lysine/arginine)
    - WT/G29A_G31A: ND2 (asparagine)

    Args:
        mask: Atom mask (e.g., ':988@ND2', ':959-1108@CA', ':2020@C4\'')
        variant: eIF5 variant name
        dataset: Dataset identifier (20250917 or 20251112)

    Returns:
        Corrected mask with variant-specific atom
    """
    # Parse mask to extract residue and atom
    # Format: :residue@atom (supports atoms like CA, ND2, C4', etc.)
    # Note: Only handles simple :residue@atom format, not ranges like :start-end@atom
    import re
    match = re.match(r':(\d+)@([\w\']+)', mask)
    if not match:
        return mask

    residue = match.group(1)
    atom = match.group(2)

    # Apply variant-specific correction
    corrected_atom = get_variant_specific_atom(residue, atom, variant, dataset)

    # If no correction needed, return original mask to preserve exact formatting
    if corrected_atom == atom:
        return mask

    # Return corrected mask
    return f':{residue}@{corrected_atom}'


def get_topology_file(dataset: str, system: str, dataset_path: Path) -> Tuple[Path, str]:
    """
    Get topology file path and determine command type.

    Uses prmtop files for topology.

    Args:
        dataset: Dataset identifier (20251112)
        system: System name (e.g., 20251112_48S_eIF5wt_AUG)
        dataset_path: Path to dataset directory

    Returns:
        Tuple of (file_path, command_type) where command_type is 'parm' or 'pdb'
    """
    prmtop = dataset_path / f"{system}-strip.prmtop"
    return prmtop


def generate_consolidated_cpptraj(
    dataset: str,
    base_dir: str,
    domains: Dict[str, Dict],
    distance_pairs: List[Dict],
    hbond_pairs: List[Dict],
    first_frame: Optional[int] = None,
    last_frame: Optional[int] = None,
    interval: Optional[int] = None,
    skip_existing: bool = True
) -> None:
    """
    Generate cpptraj input files for a specific dataset.

    Creates one cpptraj script per trajectory with all analyses.

    Args:
        dataset: Dataset identifier (20250917 or 20251112)
        base_dir: Base directory containing datasets
        domains: Dictionary of domain definitions from domains.csv
        distance_pairs: List of distance pair definitions from distance_pairs.csv
        hbond_pairs: List of hydrogen bond pair definitions from hbond_pair.csv
        first_frame: First frame to analyze (optional)
        last_frame: Last frame to analyze (optional)
        interval: Frame interval/stride (optional)
        skip_existing: Skip analyses for output files that already exist (default: True)
    """
    dataset_path = Path(base_dir) / f"{dataset}_eif5"

    # Find all topology files
    topology_files = sorted(dataset_path.glob("*-strip.prmtop"))

    for prmtop in topology_files:
        # Extract system name
        system = prmtop.stem.replace("-strip", "")

        # Get topology file (prmtop)
        topology_file = get_topology_file(dataset, system, dataset_path)

        if not topology_file.exists():
            print(f"Warning: Topology file not found for {system}")
            print(f"  Expected: {topology_file}")
            continue

        # Get reference trajectory
        ref_file = dataset_path / "ref" / f"{system}-ref.xtc"

        if not ref_file.exists():
            print(f"Warning: Reference file not found for {system}")
            continue

        # Find all trajectory files for this system
        traj_pattern = f"{system}_clone*.xtc"
        traj_files = sorted((dataset_path / "strip-traj").glob(traj_pattern))

        if not traj_files:
            print(f"Warning: No trajectory files found for {system}")
            continue

        # Generate cpptraj input for each trajectory
        for traj in traj_files:
            traj_name = traj.name
            out_prefix = traj_name.replace("-strip.xtc", "")

            cpptraj_script = f"cpp_{traj_name}.in"

            # Track what analyses need to be run
            analyses_to_run = {
                'rmsd_nofit': [],
                'rmsf': [],
                'rmsd': [],
                'distance': [],
                'hbond': []
            }
            skipped_count = 0

            # Check which analyses need to be run
            # NO-FIT RMSD
            nofit_domains = {name: info for name, info in domains.items()
                            if 'rmsd_nofit' in info['analyses']}
            for domain_name, domain_info in nofit_domains.items():
                out_file = Path(f"data/rmsd-nofit/{out_prefix}-{domain_name}-nofit-rmsd.dat")
                if not skip_existing or not out_file.exists():
                    analyses_to_run['rmsd_nofit'].append((domain_name, domain_info))
                else:
                    skipped_count += 1

            # RMSF
            rmsf_domains = {name: info for name, info in domains.items()
                           if 'rmsf' in info['analyses']}
            for domain_name, domain_info in rmsf_domains.items():
                rmsf_file = Path(f"data/rmsf/{out_prefix}-{domain_name}-rmsf.dat")
                if not skip_existing or not rmsf_file.exists():
                    analyses_to_run['rmsf'].append((domain_name, domain_info))
                else:
                    skipped_count += 1

            # FITTED RMSD
            rmsd_domains = {name: info for name, info in domains.items()
                           if 'rmsd' in info['analyses']}
            for domain_name, domain_info in rmsd_domains.items():
                rmsd_file = Path(f"data/rmsd/{out_prefix}-{domain_name}-rmsd.dat")
                if not skip_existing or not rmsd_file.exists():
                    analyses_to_run['rmsd'].append((domain_name, domain_info))
                else:
                    skipped_count += 1

            # DISTANCE
            variant = extract_variant(system)
            for pair in distance_pairs:
                label = pair['label']
                dist_file = Path(f"data/distance/{out_prefix}-{label}-distance.dat")
                if not skip_existing or not dist_file.exists():
                    analyses_to_run['distance'].append(pair)
                else:
                    skipped_count += 1

            # HBOND
            for pair in hbond_pairs:
                label = pair['label']
                hbond_file = Path(f"data/hbond/{out_prefix}-HB_{label}-hbond.dat")
                hbond_avg_file = Path(f"data/hbond/{out_prefix}-HB_{label}-hbond_avg.dat")
                if not skip_existing or not (hbond_file.exists() and hbond_avg_file.exists()):
                    analyses_to_run['hbond'].append(pair)
                else:
                    skipped_count += 1

            # Check if any analyses need to be run
            total_analyses = sum(len(v) for v in analyses_to_run.values())
            if total_analyses == 0:
                if skipped_count > 0:
                    print(f"Skipping {traj_name}: all {skipped_count} output files exist")
                continue

            if skipped_count > 0:
                print(f"Processing {traj_name}: {total_analyses} analyses to run, {skipped_count} skipped")

            with open(cpptraj_script, 'w') as f:
                # ============================================================
                # HEADER
                # ============================================================
                f.write(f"# cpptraj input for {system} - {traj.stem}\n")
                f.write(f"# Auto-generated by generate_cpptraj_input.py\n")
                f.write(f"# Consolidated analysis: rmsd_nofit, rmsf, rmsd, distance, hbond\n\n")

                # ============================================================
                # SETUP: Load topology, trajectory, and reference
                # ============================================================
                f.write(f"parm {topology_file}\n")
                f.write(f"trajin {dataset_path / 'strip-traj' / traj_name}\n")
                f.write(f"reference {ref_file} [ref]\n\n")

                # ============================================================
                # GLOBAL ALIGNMENT
                # ============================================================
                f.write(f"# GLOBAL ALIGNMENT: Align trajectory to alignment residues\n")
                f.write(f"rms {ALIGNMENT_MASK} reference [ref]\n\n")

                # ============================================================
                # NO-FIT RMSD
                # ============================================================
                if analyses_to_run['rmsd_nofit']:
                    f.write(f"# NO-FIT RMSD: Calculate RMSD without fitting (after global alignment)\n")

                    for domain_name, domain_info in analyses_to_run['rmsd_nofit']:
                        mask = domain_info['mask']
                        out_file = f"data/rmsd-nofit/{out_prefix}-{domain_name}-nofit-rmsd.dat"
                        f.write(f"rmsd {mask} ref [ref] out {out_file} nofit\n")

                    f.write("\n")

                # ============================================================
                # RMSF
                # ============================================================
                if analyses_to_run['rmsf']:
                    f.write(f"# RMSF: Calculate atomic fluctuations (requires per-domain alignment)\n")

                    for domain_name, domain_info in analyses_to_run['rmsf']:
                        mask = domain_info['mask']
                        rmsf_file = f"data/rmsf/{out_prefix}-{domain_name}-rmsf.dat"

                        f.write(f"# {domain_name}\n")
                        f.write(f"rms {domain_name}_fit {mask} ref [ref]\n")

                        if first_frame is not None or last_frame is not None or interval is not None:
                             first = first_frame if first_frame is not None else 1
                             last = last_frame if last_frame is not None else "last"
                             step = interval if interval is not None else 1
                             atomicfluct_cmd = f"atomicfluct {mask} out {rmsf_file} byres start {first} stop {last} offset {step} \n"
                        else:
                            atomicfluct_cmd = f"atomicfluct {mask} out {rmsf_file} byres\n\n"

                        f.write(f"{atomicfluct_cmd}")
                
                # ============================================================
                # FITTED RMSD
                # ============================================================
                if analyses_to_run['rmsd']:
                    f.write(f"# FITTED RMSD: Calculate RMSD with domain-specific fitting\n")

                    for domain_name, domain_info in analyses_to_run['rmsd']:
                        mask = domain_info['mask']
                        rmsd_file = f"data/rmsd/{out_prefix}-{domain_name}-rmsd.dat"
                        f.write(f"rms {domain_name}_rmsd {mask} ref [ref] out {rmsd_file}\n")

                    f.write("\n")

                # ============================================================
                # DISTANCE CALCULATIONS
                # ============================================================
                if analyses_to_run['distance']:
                    f.write(f"# DISTANCE CALCULATIONS: Atom-atom distances\n")

                    for pair in analyses_to_run['distance']:
                        label = pair['label']
                        mask1 = pair['mask1']
                        mask2 = pair['mask2']

                        # Apply variant-specific atom name corrections
                        mask1_corrected = apply_variant_correction_to_mask(mask1, variant, dataset)
                        mask2_corrected = apply_variant_correction_to_mask(mask2, variant, dataset)

                        dist_file = f"data/distance/{out_prefix}-{label}-distance.dat"
                        f.write(f"distance {mask1_corrected} {mask2_corrected} out {dist_file}\n")

                    f.write("\n")

                # ============================================================
                # HYDROGEN BOND ANALYSIS
                # ============================================================
                if analyses_to_run['hbond']:
                    f.write(f"# HYDROGEN BOND ANALYSIS: Donor-acceptor hydrogen bonds\n")

                    for pair in analyses_to_run['hbond']:
                        label = pair['label']
                        donormask = pair['donormask']
                        acceptormask = pair['acceptormask']

                        # Apply variant-specific atom corrections to donor mask
                        donormask_corrected = apply_variant_correction_to_mask(donormask, variant, dataset)

                        hbond_file = f"data/hbond/{out_prefix}-HB_{label}-hbond.dat"
                        hbond_avg_file = f"data/hbond/{out_prefix}-HB_{label}-hbond_avg.dat"

                        # Generate hbond command
                        f.write(f"hbond HB_{label} donormask {donormask_corrected} acceptormask {acceptormask} ")
                        f.write(f"dist 3.2 angle 120.0 out {hbond_file} avgout {hbond_avg_file} ")
                        f.write(f"series uuseries data/hbond/{out_prefix}-HB_{label}-matrix.dat\n")

                    f.write("\n")

                f.write(f"go\n")

            #print(f"Generated: {cpptraj_script}")


def parse_arguments() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Generate consolidated cpptraj input files for MD trajectory analysis (20251112 dataset).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate scripts for all frames (skips existing output files by default)
  python generate_cpptraj_input.py

  # Force regenerate all files, even if they exist
  python generate_cpptraj_input.py --no-skip-existing

  # Generate scripts for frames 1-20000
  python generate_cpptraj_input.py --first-frame 1 --last-frame 20000

  # Generate scripts for every 10th frame
  python generate_cpptraj_input.py --interval 10

  # Generate scripts for frames 1000-5000, every 5th frame
  python generate_cpptraj_input.py --first-frame 1000 --last-frame 5000 --interval 5

Output:
  - cpptraj scripts: cpp_{trajectory}.in (only for trajectories with pending analyses)
  - Run with: cpptraj -i cpp_*.in
        """
    )

    parser.add_argument(
        '--first-frame',
        type=int,
        default=None,
        help='First frame to analyze for RMSF (default: 1, start from beginning)'
    )

    parser.add_argument(
        '--last-frame',
        type=int,
        default=None,
        help='Last frame to analyze for RMSF (default: last frame in trajectory)'
    )

    parser.add_argument(
        '--interval',
        type=int,
        default=None,
        help='Frame interval/stride for RMSF (default: 1, every frame)'
    )

    parser.add_argument(
        '--skip-existing',
        action='store_true',
        default=True,
        help='Skip analyses for output files that already exist (default: True)'
    )

    parser.add_argument(
        '--no-skip-existing',
        dest='skip_existing',
        action='store_false',
        help='Regenerate all analyses, even if output files exist'
    )

    return parser.parse_args()


def main():
    """Main function to generate all consolidated cpptraj input files."""
    # Parse command-line arguments
    args = parse_arguments()

    # Determine script location and set paths relative to project root
    script_dir = Path(__file__).parent
    project_root = script_dir.parent if script_dir.name == 'scripts' else script_dir

    # Base directory
    base_dir = "/mnt/campbell-data/mchan3/md/eif5"

    # Create output directories
    for dirname in ['rmsd-nofit', 'rmsf', 'rmsd', 'distance', 'hbond']:
        os.makedirs(f"data/{dirname}", exist_ok=True)
    print("Created output directories: data/rmsd-nofit/, data/rmsf/, data/rmsd/, data/distance/, data/hbond/\n")

    # Print analysis parameters
    print(f"{'='*60}")
    print("cpptraj Script Generation")
    print(f"{'='*60}")
    if args.first_frame is not None or args.last_frame is not None or args.interval is not None:
        first = args.first_frame if args.first_frame is not None else 1
        last = args.last_frame if args.last_frame is not None else "last"
        step = args.interval if args.interval is not None else 1
        print(f"Frame range: {first} to {last}, interval {step}")
    else:
        print("Frame range: All frames (default)")
    print(f"Dataset: 20251112")
    print(f"Skip existing: {args.skip_existing}")
    print(f"{'='*60}\n")

    # Process 20251112 dataset only
    dataset = '20251112'
    print(f"Processing dataset: {dataset}")

    # Load dataset-specific configuration files
    domains_csv = project_root / f"{dataset}_domains.csv"
    distance_pairs_csv = project_root / f"{dataset}_distance_pairs.csv"
    hbond_pairs_csv = project_root / f"{dataset}_hbond_pair.csv"

    # Load domains
    if not domains_csv.exists():
        print(f"Error: {dataset}_domains.csv not found at {domains_csv}")
        return

    domains = load_domains_csv(str(domains_csv))
    print(f"Loaded domains from: {domains_csv.name}")

    # Load distance pairs (optional)
    distance_pairs = []
    if distance_pairs_csv.exists():
        distance_pairs = load_distance_pairs_csv(str(distance_pairs_csv))
        print(f"Loaded distance pairs from: {distance_pairs_csv.name}")
    else:
        print(f"Warning: {dataset}_distance_pairs.csv not found at {distance_pairs_csv}")
        print("Skipping distance calculations for this dataset.")

    # Load hbond pairs (optional)
    hbond_pairs = []
    if hbond_pairs_csv.exists():
        hbond_pairs = load_hbond_pairs_csv(str(hbond_pairs_csv))
        print(f"Loaded hbond pairs from: {hbond_pairs_csv.name}")
    else:
        print(f"Warning: {dataset}_hbond_pair.csv not found at {hbond_pairs_csv}")
        print("Skipping hydrogen bond calculations for this dataset.")

    print()

    generate_consolidated_cpptraj(
        dataset,
        base_dir,
        domains,
        distance_pairs,
        hbond_pairs,
        first_frame=args.first_frame,
        last_frame=args.last_frame,
        interval=args.interval,
        skip_existing=args.skip_existing
    )



if __name__ == "__main__":
    main()
