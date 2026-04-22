# Molecular dynamics simulations of eIF5-bound initiation complex

## Contents
- `analysis/` - analysis scripts and notebook
- `production/` 
    - `prmtop/` - topology file in `prmtop` file format
    - `init_rst/` - initial coordinates for simulation in AMBER rst file format
    - `restraint_atoms/` - list of atoms to be harmonically restrained during production simulation. `txt` file formate.
    - `prod-restraint.py` - initalize an OpenMM production simulation with restraints applied.
    - `prod-restraint.py` - restart an OpenMM simulation. 

## Systems simulated

| System | eIF5_variant | start_site | 
| --- | --- | --- | 
20251112_48S_eIF5_G29A_G31A_AUG | G29A/G31A | AUG| 
20251112_48S_eIF5_N30K_AUG | N30K | AUG | 
20251112_48S_eIF5_N30Q_AUG | N30A | AUG | 
20251112_48S_eIF5wt_ACG | WT | ACG | 
20251112_48S_eIF5wt_AUC | WT | AUC | 
20251112_48S_eIF5wt_AUG | WT | AUG | 
20251112_48S_eIF5wt_CUG | WT | CUG | 
20251112_48S_eIF5wt_GUG | WT | GUG | 
20251112_48S_eIF5wt_UUG | WT | UUG | 

## Usage

Initialize production simulations
```
prod-restraint.py --prmtop 20251112_48S_eIF5wt_AUG.prmtop \
    --rst 20251112_48S_eIF5wt_AUG-restraint-equl.rst \
    --output_name 20251112_48S_eIF5wt_AUG-prod0 \ 
    --restrain_list  20251112_48S_eIF5wt_AUG-restraint_atoms.txt
```

