# A codon-sensitive conformational switch gates commitment to translation start sites

Data and analysis code for:

> McGuire SF\*, Chan MC\*, Chan TC, Cueny RR, Pachikara N, Alleman EM, Sikora VM, Subramaniam AR, Campbell MG, Lapointe CP. **A codon-sensitive conformational switch gates commitment to translation start sites.** *(in revision; the full citation and DOI will be added on publication)*
> \* equal contribution

Human ribosomes must start translation at the right codon, usually AUG, yet regulated starts at near-cognate codons (CUG, UUG, GUG, ACG ...) also matter. Using single-molecule FRET, structural work and molecular dynamics, we show that the initiation factor eIF5 switches between at least two conformations on the ribosome. A strictly conserved loop in eIF5 senses the start codon. AUG codons favor the conformation that is stabilized by GTP hydrolysis and commits the complex to the start site; non-AUG codons favor a "standby" conformation. This repository holds every single-molecule dataset behind the paper's figures, the apps we used to analyze them, and the inputs for the molecular dynamics simulations.

## What's here

| Folder | Contents |
|---|---|
| [`Figure 1`](Figure%201) … [`Figure 6`](Figure%206) | Single-molecule data for each main figure **and its supplementary figures**. One subfolder per experiment. |
| [`Code`](Code) | MATLAB apps to view and analyze the single-molecule data, with step-by-step instructions. |
| [`molecular_dynamics`](molecular_dynamics) | Topologies, starting and final coordinates, and run and analysis scripts for the MD simulations. |
| [`LICENSE`](LICENSE) | Terms of reuse (non-commercial, with attribution). |

**Where to start:**
- *To browse the data,* read on. Each `.mat` file opens in MATLAB or Python.
- *To view traces or re-run analyses with our apps,* go to **[Code/README.md](Code/README.md)**. It takes about five minutes to set up.
- *To rerun or extend the simulations,* see **[molecular_dynamics/README.md](molecular_dynamics/README.md)**.

## The single-molecule experiments in brief

Initiation complexes were assembled on 40S ribosomal subunits with either the HCV IRES or a model mRNA. They were tethered to a microscope slide and imaged by TIRF microscopy. The initiator tRNA carries the FRET donor (Cy3, "green"), and eIF5 carries the acceptor (Cy5 or LD655, "red"). Each time eIF5 binds, FRET appears; the FRET efficiency then reports which conformation eIF5 adopts. "Real-time" (`RT`) experiments deliver components while recording, so complexes can proceed through initiation with GTP (or non-hydrolyzable GDPNP). The Methods section of the paper has the full details.

## How the data are organized

Each experiment folder is named `date_description`, and the description gives the conditions:

| In the name | Meaning |
|---|---|
| `IRES-AUG`, `IRES-CUG`, ... | HCV IRES with the indicated start codon (`IRES-WT`: wild-type IRES; `IRES-delta-dII`: domain II deleted) |
| `modelAUG`, `modelCUG` | Model mRNA with the indicated start codon |
| `eIF5-N30R`, `G31R`, `K114A-K115A`, ... | eIF5 variant (`WT` = wild type) |
| `eIF1A-eIF5`, `eIF5-eIF1A` | Experiments that also included eIF1A |
| `RT_` / `RealTime_` | Real-time experiment, with `GTP` or `GDPNP` |
| `(5nM)`, `(7p5nM)` | eIF5 concentration (`7p5` = 7.5) |

Supplementary-figure data are stored in the folder of the main figure they support. Each experiment matches a row of **Supplementary Table 2** of the paper.

### File types

| File | What it holds |
|---|---|
| `*_analyzed.mat` | Every molecule's traces and state assignments (`ttotal`, `states`), plus the intermediate and final results of the analysis (lifetimes, arrival times, histograms, ...). |
| `*_analyzed.sfit` | The exponential and Gaussian fits shown in the figures, as MATLAB Curve Fitter sessions. Open one with `cftool('file.sfit')` (Curve Fitting Toolbox). |
| `*_assigned_corrected.mat` | Traces and state assignments only, in the format our apps write. |
| `*_D-A.mat`, `*_green-normalized.mat`, `*_red-normalized.mat`, `*_TransitionAnalysis.mat` (+ `.sfit`) | Added in revision: donor-acceptor correlation, donor and acceptor intensity distributions, and FRET-state transition lifetimes for the indicated experiment. |

### What's inside a `.mat` file

Every `.mat` file here contains the same two core variables. Each one covers all the molecules ("traces") from one experiment:

- **`ttotal`**, a matrix of *frames × (1 + 3 × molecules)*. Column 1 is time in seconds. Each molecule then has three columns: **donor** intensity, **acceptor** intensity and **FRET** efficiency. So molecule *m* is in columns `3m-1`, `3m` and `3m+1`.
- **`states`**, the same size as `ttotal`. Our idealized assignment of each frame, stored in each molecule's FRET column: **0** = eIF5 not bound, **1** = bound. The donor and acceptor columns of `states` are 0.

Newer files also store `channelNames` (`{'donor','acceptor','fret'}`) and `nChPerMol` (3). Most `*_analyzed.mat` files also have `Exposure` (seconds per frame). The other variables are outputs of the analysis scripts.

**MATLAB:**

```matlab
% from the repository folder
d = load('Figure 3/20241209_IRES-AUG_eIF5-WT/IRES-AUG_eIF5-WT_analyzed.mat', 'ttotal', 'states');
time  = d.ttotal(:, 1);
m     = 5;                                  % molecule number
fret  = d.ttotal(:, 3*m + 1);
bound = d.states(:, 3*m + 1) > 0;
plot(time, fret); hold on; plot(time, bound, 'k--')
```

**Python** (`pip install scipy numpy`):

```python
from scipy.io import loadmat
# from the repository folder
d = loadmat("Figure 3/20241209_IRES-AUG_eIF5-WT/IRES-AUG_eIF5-WT_analyzed.mat",
            variable_names=["ttotal", "states"])
ttotal, states = d["ttotal"], d["states"]
time = ttotal[:, 0]
donor, acceptor, fret = ttotal[:, 1::3], ttotal[:, 2::3], ttotal[:, 3::3]   # frames x molecules
bound = states[:, 3::3] > 0
```

## Dataset inventory

"Traces" is the number of molecules in the file. The counts reported in the paper can be smaller, because they include only molecules and events that pass the filters described in the Methods. "Frames × exposure" gives the movie length.

| Figure | Experiment folder | Traces | Movie | Files |
|---|---|---:|---|---|
| 1 | [20240815_ModelAUG_eIF5-Cy5 (5nM)](Figure%201/20240815_ModelAUG_eIF5-Cy5%20%285nM%29) | 381 | 1800 × 100 ms | analyzed (+ fits) |
|  | [20241003_IRES-AUG_eIF5-eIF1A](Figure%201/20241003_IRES-AUG_eIF5-eIF1A) | 392 | 1200 × 100 ms | analyzed (+ fits) |
|  | [20241217_IRES-AUG_eIF1A-eIF5 (10nM)](Figure%201/20241217_IRES-AUG_eIF1A-eIF5%20%2810nM%29) | 250 | 1200 × 100 ms | analyzed (+ fits) |
|  | [20241217_IRES-AUG_eIF1A-eIF5 (15nM)](Figure%201/20241217_IRES-AUG_eIF1A-eIF5%20%2815nM%29) | 123 | 1200 × 100 ms | analyzed (+ fits) |
|  | [20241217_IRES-AUG_eIF1A-eIF5 (20nM)](Figure%201/20241217_IRES-AUG_eIF1A-eIF5%20%2820nM%29) | 151 | 1200 × 100 ms | analyzed (+ fits) |
|  | [20241217_IRES-AUG_eIF1A-eIF5 (5nM)](Figure%201/20241217_IRES-AUG_eIF1A-eIF5%20%285nM%29) | 304 | 1200 × 100 ms | analyzed (+ fits) |
| 2 | [20241107_IRES-AUG_eIF5-eIF1A](Figure%202/20241107_IRES-AUG_eIF5-eIF1A) | 319 | 1500 × 20 ms | analyzed (+ fits) |
|  | [20241121_IRES-WT_eIF5](Figure%202/20241121_IRES-WT_eIF5) | 334 | 1500 × 20 ms | analyzed (+ fits) |
|  | [20241121_IRES-delta-dII_eIF5](Figure%202/20241121_IRES-delta-dII_eIF5) | 128 | 1500 × 20 ms | analyzed (+ fits) |
|  | [20250128_modelAUG_eIF5WT-LD655](Figure%202/20250128_modelAUG_eIF5WT-LD655) | 450 | 1500 × 20 ms | analyzed (+ fits) |
|  | [20260805_IRES-AUG_eIF5(30nM)](Figure%202/20260805_IRES-AUG_eIF5%2830nM%29) | 350 | 2250 × 20 ms | analyzed, FRET transitions, donor-acceptor, green intensity, red intensity (+ fits) |
|  | [20260805_IRES-AUG_eIF5(7p5nM)](Figure%202/20260805_IRES-AUG_eIF5%287p5nM%29) | 146 | 2250 × 20 ms | analyzed, FRET transitions (+ fits) |
|  | [20260805_IRES-AUG_eIF5-Cy5](Figure%202/20260805_IRES-AUG_eIF5-Cy5) | 267 | 2250 × 20 ms | analyzed, donor-acceptor, green intensity, red intensity (+ fits) |
| 3 | [20241209_IRES-AUG_eIF5-WT](Figure%203/20241209_IRES-AUG_eIF5-WT) | 419 | 1500 × 20 ms | analyzed (+ fits) |
|  | [20250124_IRES-CUG_eIF5-WT](Figure%203/20250124_IRES-CUG_eIF5-WT) | 400 | 1500 × 20 ms | analyzed (+ fits) |
|  | [20250411_IRES-ACG_eIF5-WT](Figure%203/20250411_IRES-ACG_eIF5-WT) | 169 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250501_IRES-GUG_eIF5-WT](Figure%203/20250501_IRES-GUG_eIF5-WT) | 189 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250501_IRES-UUG_eIF5-WT](Figure%203/20250501_IRES-UUG_eIF5-WT) | 149 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250808_modelCUG_eIF5WT](Figure%203/20250808_modelCUG_eIF5WT) | 128 | 2250 × 20 ms | analyzed (+ fits) |
| 4 | [20241209_IRES-AUG_eIF5-K143E](Figure%204/20241209_IRES-AUG_eIF5-K143E) | 286 | 1500 × 20 ms | analyzed (+ fits) |
|  | [20241209_IRES-AUG_eIF5-N30E](Figure%204/20241209_IRES-AUG_eIF5-N30E) | 265 | 1500 × 20 ms | analyzed (+ fits) |
|  | [20241209_IRES-AUG_eIF5-N30R](Figure%204/20241209_IRES-AUG_eIF5-N30R) | 507 | 1500 × 20 ms | analyzed (+ fits) |
|  | [20241209_IRES-AUG_eIF5-R15M](Figure%204/20241209_IRES-AUG_eIF5-R15M) | 315 | 1500 × 20 ms | analyzed (+ fits) |
|  | [20250124_IRES-CUG_eIF5-N30R](Figure%204/20250124_IRES-CUG_eIF5-N30R) | 400 | 1500 × 20 ms | analyzed (+ fits) |
|  | [20250124_IRES-CUG_eIF5-R15M](Figure%204/20250124_IRES-CUG_eIF5-R15M) | 400 | 1500 × 20 ms | analyzed (+ fits) |
|  | [20250515_IRES-AUG_eIF5-G29AG31A](Figure%204/20250515_IRES-AUG_eIF5-G29AG31A) | 305 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250515_IRES-AUG_eIF5-N30A](Figure%204/20250515_IRES-AUG_eIF5-N30A) | 329 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250515_IRES-AUG_eIF5-N30K](Figure%204/20250515_IRES-AUG_eIF5-N30K) | 325 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250515_IRES-AUG_eIF5-N30Q](Figure%204/20250515_IRES-AUG_eIF5-N30Q) | 331 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250520_IRES-CUG_eIF5-G29AG31A](Figure%204/20250520_IRES-CUG_eIF5-G29AG31A) | 306 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250520_IRES-CUG_eIF5-N30A](Figure%204/20250520_IRES-CUG_eIF5-N30A) | 262 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250520_IRES-CUG_eIF5-N30K](Figure%204/20250520_IRES-CUG_eIF5-N30K) | 311 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250520_IRES-CUG_eIF5-N30Q](Figure%204/20250520_IRES-CUG_eIF5-N30Q) | 297 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250915_IRES-AUG_G31R](Figure%204/20250915_IRES-AUG_G31R) | 266 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250922_IRES-CUG_G31R](Figure%204/20250922_IRES-CUG_G31R) | 306 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20261001_RealTime_eIF5-G31R_GDPNP-TC_modelAUG_full-initiation](Figure%204/20261001_RealTime_eIF5-G31R_GDPNP-TC_modelAUG_full-initiation) | 482 | 3000 × 20 ms | states only |
|  | [20261001_RealTime_eIF5-WT_GDPNP-TC_modelAUG_full-initiation](Figure%204/20261001_RealTime_eIF5-WT_GDPNP-TC_modelAUG_full-initiation) | 926 | 3000 × 20 ms | states only |
| 5 | [20250228_RT_IRES-AUG_GDPNP_WT](Figure%205/20250228_RT_IRES-AUG_GDPNP_WT) | 433 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250228_RT_IRES-AUG_GTP_WT](Figure%205/20250228_RT_IRES-AUG_GTP_WT) | 268 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250310-12_RT_IRES-AUG_GTP_N30R](Figure%205/20250310-12_RT_IRES-AUG_GTP_N30R) | 166 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250310-12_RT_IRES-AUG_GTP_R15M](Figure%205/20250310-12_RT_IRES-AUG_GTP_R15M) | 116 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250416_RT_IRES-CUG_GTP_N30R](Figure%205/20250416_RT_IRES-CUG_GTP_N30R) | 169 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250416_RT_IRES-CUG_GTP_WT](Figure%205/20250416_RT_IRES-CUG_GTP_WT) | 144 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250820_RT_IRES-UUG_GTP_WT](Figure%205/20250820_RT_IRES-UUG_GTP_WT) | 141 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20250923_RT_IRES-AUG_GTP_G31R](Figure%205/20250923_RT_IRES-AUG_GTP_G31R) | 174 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20251204_RT_IRES-UUG_GTP_G31R](Figure%205/20251204_RT_IRES-UUG_GTP_G31R) | 441 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20251206_RT_IRES-CUG_GTP_G31R](Figure%205/20251206_RT_IRES-CUG_GTP_G31R) | 220 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20251219_RT_modelAUG_GTP_WT](Figure%205/20251219_RT_modelAUG_GTP_WT) | 253 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20260507_RT_modelAUG_GTP_WT](Figure%205/20260507_RT_modelAUG_GTP_WT) | 302 | 2250 × 20 ms | analyzed (+ fits) |
| 6 | [20251211_IRES-AUG_eIF5-K114A-K115A](Figure%206/20251211_IRES-AUG_eIF5-K114A-K115A) | 350 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20251211_IRES-UUG_eIF5-K114A-K115A](Figure%206/20251211_IRES-UUG_eIF5-K114A-K115A) | 304 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20260130_IRES-RT_AUG_GTP_K114A-K115A](Figure%206/20260130_IRES-RT_AUG_GTP_K114A-K115A) | 139 | 2250 × 20 ms | analyzed (+ fits) |
|  | [20260130_IRES-RT_CUG_GTP_K114A-K115A](Figure%206/20260130_IRES-RT_CUG_GTP_K114A-K115A) | 131 | 2250 × 20 ms | analyzed (+ fits) |

## Analysis code

[`Code/`](Code) contains our two MATLAB apps, **Assign States** (view and correct traces) and the **Analysis Pipeline** (kinetics, FRET distributions and conformations). It also holds two intensity-analysis scripts and a copy of vbFRET. [Code/README.md](Code/README.md) walks through setup and common tasks, and each app has a full user guide in its `docs/` folder.

The scripts used for the first submission remain available at the git tag [`original-analysis-scripts`](https://github.com/LapointeLab/eIF5-2026-paper/tree/original-analysis-scripts/Code).

## License

The data, code and documentation are released under [CC BY-NC 4.0](LICENSE): free to use, share and adapt for non-commercial purposes, with attribution to the paper above. The bundled vbFRET (`Code/vbFRET_June10`) is third-party software and keeps its authors' terms.

## Questions

Please [open an issue](https://github.com/LapointeLab/eIF5-2026-paper/issues) and we'll respond as soon as we can.
