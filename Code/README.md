# Analysis code

This folder holds the MATLAB apps we use to analyze single-molecule TIRF/FRET data. They need no programming: you point and click. With them you can:

- **look at any molecule** in our datasets, with its traces and the ON/OFF (bound/unbound) assignments we made;
- **re-run the analyses**: binding lifetimes, association rates, FRET distributions, FRET-state lifetimes and conformational changes;
- **analyze your own data** in the same way.

| Folder | What it is |
|---|---|
| `startHere.m` | Run this first. It sets MATLAB up for the session. |
| [`AssignStatesTool/`](AssignStatesTool) | **Assign States** app. Shows each molecule's donor, acceptor and FRET traces with its assigned states, and lets you review or correct them. [User Guide](AssignStatesTool/docs/UserGuide.pdf) |
| [`AnalysisPipeline/`](AnalysisPipeline) | **Analysis Pipeline** app. Finds binding events and runs twelve analysis and plotting modules. [Quick Guide (1 page)](AnalysisPipeline/docs/QuickGuide.pdf) · [User Guide](AnalysisPipeline/docs/UserGuide.pdf) |
| [`IntensityAnalysis/`](IntensityAnalysis) | Two scripts that measure donor (green) intensity while eIF5 is unbound and acceptor (red) intensity during binding events, in camera units and photon equivalents. |
| [`vbFRET_June10/`](vbFRET_June10) | vbFRET (Bronson *et al.*, *Biophys. J.* 2009), the hidden Markov model tool that Assign States launches to idealize new 2-color FRET traces. Third-party; included for convenience. |

## What you need

- **MATLAB R2023b** or newer. Older releases may work but were not tested.
- For the Analysis Pipeline: the **Curve Fitting Toolbox** and the **Statistics and Machine Learning Toolbox**. Assign States needs no toolboxes.
- The repository on your computer: **Code → Download ZIP** on GitHub, or `git clone`. Keep the folder structure as it is.

## Set up (once per MATLAB session)

1. Open MATLAB.
2. In the Command Window, run `startHere.m` from this folder. You can drag the file into the Command Window, or type:

   ```matlab
   run('/path/to/eIF5-2026-paper/Code/startHere.m')
   ```

   It adds the apps to MATLAB's path for this session only. It also warns you if a toolbox is missing.

## Recipe 1: look at the molecules in a dataset

1. Type `AssignStatesApp` and press Enter.
2. Click **Assign States** (either panel has one), then choose a `.mat` file from one of the `Figure` folders. For example, choose `Figure 3/20241209_IRES-AUG_eIF5-WT/IRES-AUG_eIF5-WT_analyzed.mat`, which is eIF5 on the HCV IRES with an AUG start codon. (The Status panel will say the file is "old-format, assuming 2-color data". That is expected.)
3. The top plot shows the raw donor and acceptor intensities. The bottom plot shows FRET efficiency (blue), with our state assignment as a dashed line: 0 means eIF5 is not bound, and a step up marks a binding event.
4. Move between molecules with the **→** and **←** arrow keys, or type a number in the **Molecule** box. To zoom, drag a box on a plot; press **u** to reset.

Assign States is also an editor, so the mouse and number keys change assignments. Nothing is written to disk unless you click **Save**, so feel free to explore. The [User Guide](AssignStatesTool/docs/UserGuide.pdf) explains every control.

## Recipe 2: re-run an analysis

1. Type `AnalysisPipelineApp` and press Enter.
2. Click **Load State-Assignment File...** and choose a dataset `.mat` file, as in Recipe 1. The Status panel reports how many molecules and binding events it found.
3. Click a module in the left sidebar. Each one opens in its own tab, with controls along the top.

| To look at... | Use the module |
|---|---|
| How long eIF5 stays bound (lifetimes, exponential fits) | Binding Lifetime Kinetics |
| How quickly eIF5 binds (arrival times, association rates) | Association Kinetics |
| FRET efficiency histograms and Gaussian fits | FRET Efficiency Distribution |
| How long each FRET state lasts (high vs. low FRET) | FRET State Lifetime |
| FRET over time, aligned to the start of binding events | Post-Sync FRET Heatmap, FRET Evolution |
| Which FRET state eIF5 binds in and leaves from | Association/Dissociation Conformations |
| Whether donor and acceptor intensities anti-correlate | Donor-Acceptor Correlation |
| Events grouped by mean FRET or by lifetime | Event Sorting by Mean FRET, Event Sorting by Lifetime |
| Several datasets on one plot, or a one-page summary | Combined Dataset Overlay, Summary Figure |

Confidence intervals are bootstrapped by **molecule**, not by event, because events on the same molecule are not independent. The [User Guide](AnalysisPipeline/docs/UserGuide.pdf) explains each module's method and statistics. Fits can be exported as CSV, and plots as `.png`, `.eps` and `.fig`.

**About reproducing the published numbers.** Most datasets in this repository were first analyzed with our earlier, script-based code. Those scripts are kept in the repository's history at the tag [`original-analysis-scripts`](https://github.com/LapointeLab/eIF5-2026-paper/tree/original-analysis-scripts/Code). The apps perform the same analyses, but fitting options and bootstrap resampling can make values differ slightly from the reported ones. If you find a difference that matters, please open an issue.

## Recipe 3: analyze your own data

The full workflow is **movie → traces → states → analysis**:

1. **Extract traces from your movies.** We used SPARTAN ([Juette *et al.*, *Nat. Methods* 2016](https://www.scottcblanchardlab.com/software)), which writes a `.traces` file. SPARTAN is not included here because of its license.
2. **Assign states** in Assign States:
   - **2-color FRET:** click **Analyze with vbFRET**. Fit your traces in vbFRET, save its *Analysis Summary*, and click **Merge vbFRET Summary...**. Then review each molecule and correct any errors.
   - **3- or 4-color data:** click **Assign States** and assign each channel by hand.
3. **Save** with **Save As _assigned_corrected.mat...**.
4. **Analyze** that file in the Analysis Pipeline (Recipe 2).

Importing `.traces` files directly needs SPARTAN's `loadTraces` function on your MATLAB path. Alternatively, you can build the `.mat` file yourself in the format described in the [main README](../README.md#whats-inside-a-mat-file). The Assign States guide explains each step in detail. Where it says vbFRET must be added to the path yourself, ignore that: `startHere.m` already does it.

## The intensity scripts

These are plain MATLAB scripts. They work on the `ttotal` and `states` variables in your workspace and write their results to Excel files in the current folder:

```matlab
repo = '/path/to/eIF5-2026-paper';
load(fullfile(repo, 'Figure 2', '20260805_IRES-AUG_eIF5(30nM)', 'IRES-AUG_eIF5(30nM)_analyzed.mat'), 'ttotal', 'states')
cd(tempdir)   % the .xlsx output goes to the current folder
Chan_GreenIntensityCalculator_normalized_v2   % donor intensity while eIF5 is unbound
Chan_RedIntensityCalculator_normalized_v2     % acceptor intensity during binding events
```

Both scripts assume 2-color data with three columns per molecule, as in all datasets here. The conversion from camera units to photon equivalents is set near the top of each script.

## Troubleshooting

- **"Unrecognized function or variable 'AssignStatesApp'"** (or `AnalysisPipelineApp`): run `startHere.m` again. MATLAB forgets the path when it restarts.
- **A module says a toolbox is missing:** install the Curve Fitting and Statistics and Machine Learning toolboxes (MATLAB **Home → Add-Ons**).
- **The app looks out of date after you downloaded a newer version:** type `clear classes`, then reopen the app.
- **Anything else:** please [open an issue](https://github.com/LapointeLab/eIF5-2026-paper/issues) with the exact error message and the file you were using.
