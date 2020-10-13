<!-- Reference-style links to make tables & lists more readable -->
[Gallery]: <https://github.com/ma-laforge/FileRepo/tree/master/InspectDR/sampleplots/README.md>
[GallerySProc]: <https://github.com/ma-laforge/FileRepo/tree/master/SignalProcessing/sampleplots/README.md>
[GalleryPlotsJL]: <https://github.com/ma-laforge/FileRepo/blob/master/InspectDR/sampleplots_Plots/README.md>
[MDDatasetsJL]: <https://github.com/ma-laforge/MDDatasets.jl>
[CMDimDataJL]: <https://github.com/ma-laforge/CMDimData.jl>
[CMDimCircuitsJL]: <https://github.com/ma-laforge/CMDimCircuits.jl>
[PlotsJL]: <https://github.com/JuliaPlots/Plots.jl>
[BlinkJL]: <https://github.com/JunoLab/Blink.jl>
[Electron]: <https://github.com/electron/electron>
[Cairo]: <https://cairographics.org>
[GTK]: <https://www.gtk.org>

# InspectDR.jl: Fast, interactive plots
**Galleries:** [:art: Output from ./sample/][Gallery] / [:art: SignalProcessing module][GallerySProc] / [:art: Plots.jl package][GalleryPlotsJL]

[![Build Status](https://travis-ci.org/ma-laforge/InspectDR.jl.svg?branch=master)](https://travis-ci.org/ma-laforge/InspectDR.jl)

| <img src="https://github.com/ma-laforge/FileRepo/blob/master/InspectDR/sampleplots/demo11.png" width="425"> | <img src="https://github.com/ma-laforge/FileRepo/blob/master/InspectDR/sampleplots/demo2.png" width="425"> |
| :---: | :---: |

| <img src="https://github.com/ma-laforge/FileRepo/blob/master/SignalProcessing/sampleplots/demo15.png" width="850"> |
| :---: |

# :warning: Alternative APIs

The InspectDR programming interface in not particularly refined. Code used to generate more complex plots can therefore be a bit difficult to read/maintain.

It will most likely be easier to generate `InspectDR` plots by leveraging higher-level APIs (unless you have stringent requirements on time-to-first-plot or number of dependencies).  Alternative APIs supporting `InspectDR` include:
 - [Plots.jl][PlotsJL]: Succinct plotting interface ideal for interactive exploration (supports multiple backends).
 - [CMDimData.jl][CMDimDataJL]: Facilitates parametric analysis with continous <var>f(x)</var> interpolation & multi-dimensional plots. Built using [MDDatasets.jl][MDDatasetsJL] module.
 - [CMDimCircuits.jl][CMDimCircuitsJL]: Extends [CMDimData.jl][CMDimDataJL] with circuit-specific functionnality (ex: signal processing, network analysis, ...).

Note: In instances where higher-level APIs have limited control over the plot, it is typically possible to tweak the final apearance of the "rendered" `::InspectDR.Plot` object using the `InspectDR` API.

## Table of contents

 1. [Description](#Description)
    1. [Features/Highlights](#Highlights)
 1. [Mouse/Keybindings](doc/input_bindings.md)
 1. [Usage examples](#UsageExamples)
 1. [Programming interface](doc/api.md)
 1. [Code documentation & architecture](src/doc/README.md)
 1. [Configuration/Defaults](doc/config.md)
 1. [Known limitations](#KnownLimitations)
    1. [TODO](TODO.md)

<a name="Description"></a>
## Description

InspectDR is a fast plotting tool with a responsive GUI, targeting quick navigation of simulation results.  In design applications, InspectDR allows for efficient, interactive data exploration, thus shortening each iteration of the design cycle.

**Motivation:** Despite their great quality, most of Julia's current plotting options were found to be either too slow, and/or provide inadequate interactivity for the author's needs.

The InspectDR library is implemented using **3 distinct plot layers**:

 - **Plot image layer:** Implemented with the [Cairo library][Cairo], the plot image layer allows the user to render (multi-) plots as simple images.
 - **Plot widget layer:** Library users can also integrate plots to their own [GTK+][GTK] application by instantiating a single InspectDR widget.
 - **Plot application layer:** Most end users will likely display/interact with plots/data using the built-in Julia/[GTK+][GTK] multi-plot application.

Users are encouraged to open an issue if it is unclear how to utilize a particular layer.  Documentation is a bit limited at the moment.

<a name="Highlights"></a>
## Features/Highlights

The following highlights a few interesting features of InspectDR:

 - Publication-quality output.
 - Included as a "backend" of [Plots.jl][PlotsJL].
 - Relatively short load times / time to first plot.
 - Designed with larger datasets in mind:
   - Responsive even with moderate (>200k points) datasets.
   - Confirmed to handle 2GB datsets with reasonable speed on older desktop running Windows 7 (drag+pan of data area highly discouraged).
 - Support for stacked, multi-***strip*** plots with common x-axis values.
 - Support for Smith charts (admittance & impedance - see [Plot generators](doc/api.md#PlotGenerators)).
 - Support for various types of annotation:
   - User-programmable text, polyline, vertical & horizontal bars.
   - Drag & drop &Delta;-markers (Measures/displays &Delta;x, &Delta;y & slope).
 - Interactive [mouse/keybindings](doc/input_bindings.md).
   - Fast & simple way to pan/zoom into data.
   - In line with other similar tools.
   - Create drag & drop &Delta;-markers.
 - [Layout & stylesheets](doc/api.md#Layout_Stylesheets).
   - See [demo targeting IEEE publications @300 dpi](sample/demo12.jl)
   - Add custom stylesheets.

See following subsections for more information.

### Responsive

Quick to first plot, and easy to navigate data using supported [mouse/keybindings](doc/input_bindings.md)

<a name="F1Accel"></a>
### "F1" acceleration

InspectDR.jl includes specialized algorithms to accellerate plotting of large "F1" datasets (functions of 1 argument) in order to maintain a good "real-time" (interactive) user experience.

A dataset is defined as a function of 1 argument ("F1") if it satisfies:

	y = f(x), where x: sorted, real vector

Examples of "F1" datasets include **time domain** (`y(x=time)`) and **frequncy domain** (`X(w)`) data.

"F1" acceleration is obtained by dropping points in order to speed up the rendering process.

***IMPORTANT:*** "F1" acceleration tends to generate erroneous-looking plots whenever glyphs are displayed.  This is because the dropped points may become very noticeable.  Consequently, InspectDR will, by default, only apply "F1" acceleration on datasets drawn without glyphs (lines only).

To change when InspectDR applies "F1" acceleration to drop points, look for the `:droppoints` entry in the [Configuration/Defaults](doc/config.md) section.

### 2D plot support

InspectDR.jl also supports generic 2D plotting.  More specifically, the tool is capable of plotting arbitrary 2D datasets that satisfy:

	(x,y) = (u[i], v[i]), for i in [1...N]

Examples of of such plots (where x-values are not guaranteed to be sorted) include:

- Nyquist plots
- Lissajous plots
- Smith/polar (S-Parameter) charts

<a name="UsageExamples"></a>
## Usage examples

 - Sample code to construct InspectDR objects can be found [here](sample/).
 - **(DEPRECATED)** Sample IJulia (Jupyter) notebooks can be found [here](notebook/).
 - Sample [Blink.jl][BlinkJL]/[Electron] projects can be found [here](Blink/).

<a name="KnownLimitations"></a>
## Known limitations

### [TODO](TODO.md)

- API is too verbose for interactive plotting applications (designed for scripting).
  - Workaround: Use [Plots.jl][PlotsJL] as a "frontend" (increases plot times).
- Only `Vector` data can be added (`AbstractVector`/`Range` not currently supported).
- [Sample Jupyter notebooks](notebook/) are not very good at the moment.  Also: many examples are not yet ported to Julia 1.0.
- SVG `MIME` output (using `show`) does not show up properly in Jupyter notebooks.  There appears to be an issue in determining image extents (bounding box).
- Font control is not ideal.  The default font might not be available on all platforms - and the fallback font might not have Unicode characters to display exponent values (ex: `10⁻¹⁵`).  Some Greek characters might also be missing.
  - Workaround: Overwrite default font, as described in [Configuration/Defaults](doc/config.md).
- Legends not very configurable (currently optimized to display many labels @ cost of horizontal real-estate).
- Does not yet render plot data in separate thread (will improve interactive experience with large datasets).
- Mouse events currently function even outside data area (a bit odd).
- Significant slowdowns observed when zooming **deep** into non-F1 data... Can likely be solved by discarding data outside plot extents.
  - Workaround: make sure x-values are sorted (F1-acceleration discards data & is less prone to slowdowns).
- By default, "F1"-acceleration is only applied to datasets drawn without glyphs (lines only).
  - Look for the `:droppoints` entry in the [Configuration/Defaults](doc/config.md) section to change this behaviour.

### Compatibility

Extensive compatibility testing of InspectDR.jl has not been performed.  The module has been tested using the following environment(s):

- Windows / Linux / Julia-1.3.1 / Gtk 1.1.4 (GTK+ 3) / Cairo 1.0.4

## Disclaimer

The InspectDR.jl module is not yet mature.  Expect significant changes.
