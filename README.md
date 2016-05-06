# InspectDR.jl

\*Sigh\*... Yet *another* plotting tool.

[Sample Plots](https://github.com/ma-laforge/FileRepo/tree/master/InspectDR/sampleplots/README.md) (might be out of date).<br>
**WARNING:** MANY FEATURES ARE [NOT YET IMPLEMENTED](#KnownLimitations)

## Description

InspectDR is a fast plotting tool.  The main goal is to allow the user to quickly navigate simulation results (interactive) before moving to the next design iteration.

Despite their great quality, most current Julia plotting options are still either too slow, or provide inadequate interactivity for the author's needs.

### Features/Highlights

#### Box Zoom

Use right mouse button to select new extents for plot.

#### "F1" Acceleration

InspectDR.jl includes specialized algorithms to accellerate plotting of large "F1" datasets (functions of 1 argument) in order to maintain a good "real-time" (interactive) user experience.

A dataset is defined as a function of 1 argument ("F1") if it satisfies:

	y = f(x), where x: sorted, real vector

Examples of "F1" datasets include **time domain** (`y(x=time)`) and **frequncy domain** (`X(w)`) data.

#### 2D Plot Support

InspectDR.jl also supports generic 2D plotting.  More specifically, the tool is capable of plotting arbitrary 2D datasets that satisfy:

	(x,y) = (u[i], v[i]), for i in [1...N]

Examples of of such plots (where x-values are not guaranteed to be sorted) include:

 - Nyquist plots
 - Lissajous plots
 - S-Parameter Plots

#### Keybindings

InspectDR.jl supports keybindings to improve/accelerate user control.  The following table lists supported bindings:

| Function | Key |
| -------- | :---: |
| Zoom out to full extents | `f` |

## Sample Usage

Sample code to construct InspectDR objects can be found [here](sample/).

<a name="KnownLimitations"></a>
## Known Limitations

 - The module is not yet very interactive... you cannot even zoom properly at the moment.
 - Tick labels need to be improved (# of decimal places, ...).
 - Only generates basic annotations. Needs legends, ...
 - Does not yet support different axis scales (log-log, dB, ...).
 - Does not yet render plot data in separate thread (will improve interactive experience with large datasets).

### Compatibility

Extensive compatibility testing of InspectDR.jl has not been performed.  The module has been tested using the following environment(s):

 - Linux / Julia-0.4.2 / Gtk 0.9.3 (Gtk+ 3) / Cairo 0.2.31

## Disclaimer

The InspectDR.jl module is not yet mature.  Expect significant changes.

This software is provided "as is", with no guarantee of correctness.  Use at own risk.
