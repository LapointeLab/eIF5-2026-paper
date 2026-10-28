# eIF5 N30 / codon–anticodon MD analysis — publication notebooks

Each notebook reads processed data from `../data/` generated from `generate_cpptraj_input.py`  and writes to `figures/` and `tables/`.
Analysis window: frames 13000–23000 (1300–2300 ns, 0.1 ns/frame). Clones are the unit of replication for statistics.
tRNAi U35 = residue U2054 in the topology (`:1912`); eIF5 N30 = `:846`.

| Panel | Notebook | Output |
|-------|----------|--------|
| Fig. 3C — N30·U35 H-bond survival, wt eIF5, varied start codons | `Fig3C_4D_hbond_survival.ipynb` | `figures/Fig3C_hbond_survival_wt_codons.png` |
| Fig. 4D — N30·U35 H-bond survival, eIF5 variants, AUG | `Fig3C_4D_hbond_survival.ipynb` | `figures/Fig4D_hbond_survival_eIF5_variants.png` |
| Ext. Fig. 5B — GNG RMSD time traces | `ExtFig5B-C_GNG_rmsd.ipynb` | `figures/ExtFig5B_GNG_rmsd_timetrace.png` |
| Ext. Fig. 5C — GNG RMSD bar charts (ANOVA, Dunnett vs wt/AUG) | `ExtFig5B-C_GNG_rmsd.ipynb` | `figures/ExtFig5C_GNG_rmsd_bar_{wt_codons,eIF5_variants}.png` |
| Ext. Fig. 5D — violins: codon–anticodon RMSD, N30–U35 distance | `ExtFig5D-E_rmsd_distance_distributions.ipynb` | `figures/ExtFig5D_*.png` |
| Ext. Fig. 5E — 2D landscape: codon–anticodon RMSD vs N30–U35 distance | `ExtFig5D-E_rmsd_distance_distributions.ipynb` | `figures/ExtFig5E_landscape_codon_anticodon_rmsd_vs_distance.png` |
| Ext. Fig. 5G — N30 H-bond partner circle plots | `ExtFig5G_N30_hbond_partners.ipynb` | `figures/ExtFig5G_N30_partners_{wt_codons,eIF5_variants}.png` |
| Table S3 — N30·U35 H-bond lifetimes | `TableS3_N30_U35_hbond_lifetime.ipynb` | `tables/TableS3_N30_U35_hbond_lifetime.csv` |

Run all: `jupyter nbconvert --to notebook --execute --inplace *.ipynb`
