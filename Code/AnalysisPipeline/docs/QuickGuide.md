# Analysis Pipeline — Quick Guide

A MATLAB app for analyzing single-molecule binding/FRET data: detects binding
events from a state-assignment file, then offers twelve modules covering
kinetics, FRET distributions, and conformational statistics.

## Running the app

Requires MATLAB with the **Curve Fitting** and **Statistics and Machine
Learning** Toolboxes. The folder with `AnalysisPipelineApp.m` and the
`+modules`/`+pipeline` folders must be on the MATLAB path — either `cd`
there for the session, or (recommended) add it permanently via
**Home → Set Path...**. If this app lives inside your lab's shared
`MatlabScripts` directory, make sure `MatlabScripts` has been added via
**Set Path...** so the app is callable from any Current Folder. Then in the
Command Window run: `AnalysisPipelineApp` — this opens the GUI (no arguments
needed). Use `app = AnalysisPipelineApp();` instead if you want a handle to
the running app for scripting.

## Getting started

1. **Load data.** Click **Load State-Assignment File...** and pick a
   `*_assigned_corrected.mat` file (must contain `states`, `ttotal`,
   `channelNames`, `nChPerMol`; older files with only `ttotal` and `states`
   open as 2-color data). The app detects binding events per channel
   automatically.
2. **(Optional) Set Min event frames** to drop events shorter than a chosen
   number of frames — useful for filtering out one-frame noise spikes.
3. **Click a module button** in the left sidebar (**Analysis** or
   **Plotting**) to open its tab.
4. **Adjust the controls** at the top of the tab (Channel, Events, etc.) —
   most modules recompute live as you change them.
5. **Fit, export a plot, and/or export a CSV** as needed (see below).

## Fit vs. Save Fit vs. Export CSV

Modules with curve fitting (exponential or Gaussian-mixture) share one
pattern: **Fit** is a *trial* — it draws the curve and shows the fitted
parameters but logs nothing. **Save Fit** re-runs the same fit and *also*
runs a bootstrap confidence interval, then appends one row to that module's
own results table. **Export CSV...** saves that table. Every module's table
is independent: no module's fits ever mix into another module's export.

## Confidence intervals

Most parameters carry two possible CIs: a **Fit CI** (from the curve fit's
own covariance estimate) and a **Bootstrap CI** (from resampling molecules
with replacement many times and refitting — see the User Guide for why
resampling is done by *molecule*, not by event). Both are 95% intervals,
reported in CSVs as a single `[lower, upper]` column.

## Modules

| Module | Category | What it does |
|---|---|---|
| Binding Lifetime Kinetics | Analysis | Single/double-exponential fit to the eCDF of event lifetimes |
| Association Kinetics | Analysis | Same fit, applied to first-association / reassociation wait times |
| FRET Efficiency Distribution | Analysis | 1–4 component Gaussian-mixture fit to a pooled FRET histogram |
| FRET State Lifetime | Analysis | Same exponential-fit machinery as Binding Lifetime, split by Low/High FRET state |
| Association/Dissociation Conformations | Analysis | Does FRET state predict dissociation risk or onset composition? (mixed-effects logistic regression + bootstrap) |
| Event Sorting by Mean FRET | Analysis | Splits events into Low/High groups by mean FRET; compares group lifetimes (points + bootstrap CI + rank-sum test) |
| Event Sorting by Lifetime | Analysis | Splits events into Short/Long groups by lifetime; compares group FRET distributions (Gaussian-mixture fits) |
| Donor-Acceptor Correlation | Analysis | Within-event donor/acceptor intensity Pearson r as a FRET sanity check (histogram, points + bootstrap CI, pooled D-vs-A scatter) |
| Post-Sync FRET Heatmap | Plotting | Time × FRET-efficiency density heatmap, traces aligned to binding onset |
| FRET Evolution | Plotting | Individual per-event FRET trajectories right after binding onset |
| Combined Dataset Overlay | Plotting | Overlays previously-exported `.fig` plots from different sessions/samples into one figure |
| Summary Figure | Plotting | Auto-detects every module's previously-exported `.png` plots in a chosen folder and composites them into one multi-panel page for a fast overview |

## Exporting plots

Every analysis module has an **Export Plot...** button producing a
publication-style `.eps` + `.png` + `.fig` set (square or landscape panel,
transparent background, consistent fonts/line weights) via a shared house
style — `.fig` files exported this way can later be combined in **Combined
Dataset Overlay**, and the `.png` files can be pulled together automatically
by **Summary Figure**.

*For details on the statistics, exact CSV columns, and how to interpret each
module's output, see the full User Guide.*
