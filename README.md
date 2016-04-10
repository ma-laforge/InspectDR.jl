# InspectDR.jl

\*Sigh\*... Yet *another* plotting tool.

## Description

**ONLY BASIC PLOTTING AVAILABLE**

InspectDR is a fast plotting tool.  The main goal is to allow the user to quickly navigate simulation results (interactive) before moving to the next design iteration.

Despite their great quality, most current Julia plotting options are still either too slow, or provide inadequate interactivity for the author's needs.

### Features/Highlights

#### "F1" Plot Support

InspectDR.jl can generate (x,y) graphs for functions of 1 argument ("F1"), which meet the following requirement:

	y = f(x), where x: sorted, real vector

Examples of "F1" datasets include **time domain** (`y(x=time)`) and **frequncy domain** (`X(w)`) data.

InspectDR.jl includes specialized algorithms to accellerate plotting of large "F1" datasets in order to maintain a good "real-time" (interactive) user experience.

#### 2D Plot Support

InspectDR.jl also provides generic 2D plotting.  More specifically, the tool is capable of plotting arbitrary 2D datasets that satisfy:

	(x,y) = (u[i], v[i]), for i in [1...N]

Examples of of such plots (where x-values are not guaranteed to be sorted) include:

 - Nyquist plots
 - Lissajous plots
 - S-Parameter Plots

## Sample Usage

Sample code to construct InspectDR objects can be found [here](test/).

## Known Limitations

 - The module is not yet very interactive... you cannot even zoom properly at the moment.
 - InspectDR.jl currently only supports F1 datasets (x-values must be in sorted, increasing order).
 - Only generates basic annotations. Needs legends, ...
 - Does not yet render plot data in separate thread (will improve interactive experience with large datasets).
 - Does not yet support glyphs (symbols).
 - Does not yet save images to files.
 - Interface, algorithms, and object hierarchies are a big mess at the moment... I mean: the architecture is not yet finalized.

### Compatibility

Extensive compatibility testing of InspectDR.jl has not been performed.  The module has been tested using the following environment(s):

 - Linux / Julia-0.4.2 / Gtk 0.9.3 / Cairo 0.2.31

## Disclaimer

The InspectDR.jl module is not yet mature.  Expect significant changes.

This software is provided "as is", with no guarantee of correctness.  Use at own risk.
