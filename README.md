# InspectDR.jl: Fast, Interactive Plots

[Sample Plots](https://github.com/ma-laforge/FileRepo/tree/master/InspectDR/sampleplots/README.md) (might be out of date).<br>

[![Build Status](https://travis-ci.org/ma-laforge/InspectDR.jl.svg?branch=master)](https://travis-ci.org/ma-laforge/InspectDR.jl)

**WARNING:** [NOT ALL FEATURES ARE YET IMPLEMENTED](#KnownLimitations)

## Description

InspectDR is a fast plotting tool.  The main goal is to allow the user to quickly navigate simulation results (interactive) before moving to the next design iteration.

Despite their great quality, most current Julia plotting options are still either too slow, or provide inadequate interactivity for the author's needs.

### Features/Highlights

#### Responsive

Quick to first plot, and easy to navigate data using supported [mouse/keybindings](#Bindings)

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
 - Smith/polar (S-Parameter) charts

#### Smith Charts

InpsectDR can generate Smith charts by specifying axes as `:smith`:

```
plot.axes = InspectDR.axes(:smith)
```

<a name="Bindings"></a>
#### Mouse/Keybindings

InspectDR.jl supports keybindings to improve/accelerate user control.  The following table lists supported bindings:

| Function | Key |
| -------: | :---: |
| Zoom out to full extents | `f` |
| Box zoom (in) | `right-click` + `mousemove`|
| Zoom in / zoom out | `+` / `-` |
| Zoom in / zoom out | `CTRL` + `mousewheel`|
| Pan up / pan down | &uArr; / &dArr; |
| Pan up / pan down | `mousewheel` |
| Pan left / pan right | &lArr; / &rArr; |
| Pan left / pan right | `SHIFT` + `mousewheel`|
| Pan anywhere | (`SHIFT` + `left-click`) + `mousemove` |

## Select Documentation

Note that many types & functions are not exported from InspectDR in order to avoid namespace pollution.  That being said, the module name will often be omitted below in an attempt to improve readability.

### Plot Objects

Principal objects:

 - **`InspectDR.Plot`**: An abstract plot object.
 - **`InspectDR.Plot2D <: Plot`**:  A 2D plot object.  Construct empty 2D plot using `InspectDR.Plot2D()`.
 - **`InspectDR.Multiplot`**:  A multi-plot object.  Construct empty multi-plot using: `InspectDR.Multiplot()`.

Subplots (`T<:Plot`) are added to a multi-plot object using the `add()` method:
```
mplot = InspectDR.Multiplot()
plot1 = InspectDR.Plot2D()
plot2 = InspectDR.Plot2D()

add(mplot, plot1)
add(mplot, plot2)
```

Similarly, the `add()` method adds waveforms to plots/subplots:
```
wfrm = add(plot1, x, y, id="Waveform label")
```

**WARNING:** Only `Vector` data can be added (`AbstractVector`/`Range` not currently supported).

#### Displaying plots

InspectDR provides the `GtkDisplay` object derived from `Base.Multimedia.Display`.  `GtkDisplay` is used in combination with `Base.display()`, to spawn a new instance of a GTK-based GUI.

To display a single `plot::Plot` object, one simply calls:
```
display(InspectDR.GtkDisplay(), plot)
```

Similarly, to display `mplot::Multiplot` object, one calls:
```
display(InspectDR.GtkDisplay(), mplot)
```

### Axis Scales

The X/Y scales of a `Plot2D` object can independently be selected to be one of the following:

 - `:lin`
 - `:log10`, `:log` (= `:log10`)
 - `:dB20`, `:dB10`

In order to display `plot::Plot2D` using semilog-x scales, one would set:
```
plot.axes = InspectDR.axes(:log10, :lin).
```

### Layout/Plot Style

Until a proper API is defined, one is encouraged to look at the `Layout` object to alter how plots are displayed:
```
?InspectDR.Layout
```

#### Legends

At this point in time, legends have limited configurability.  When displayed, legends will consume fixed horizontal real-estate.  The idea is to display a large number of labels without hiding the data area.

In order to display the legend of a `plot::Plot2D` object, one would set:
```
plot.layout.legend.enabled = true
```


Until a proper API is defined, one is encouraged to look at the `LegendLStyle` object to alter how legends are displayed:
```
?InspectDR.LegendLStyle
```


<a name="SampleUsage"></a>
## Sample Usage

Sample code to construct InspectDR objects can be found [here](sample/).

<a name="KnownLimitations"></a>
## Known Limitations

 - Documentation is a bit limited at the moment.  See [Sample Usage](#SampleUsage) to learn from examples.
 - API is still a bit rough.  User often has to manipulate data structures directly.
 - Tick labels need to be improved (# of decimal places, ...).
 - Legends not very configurable (currently optimized to display many labels @ cost of horizontal real-estate).
 - Does not yet support many axis scales.
 - Does not yet render plot data in separate thread (will improve interactive experience with large datasets).
 - Mouse events currently function even outside data area (a bit odd).
 - Mouse cursor does not change as user switches mousemodes (ex: drag icon, cross-hairs, ...).
 - Smith charts are not yet constrained to square aspect ratios.
 - Not discarding data outside displayed extents causes massive slowdowns (ex: when zoomed in).


### Compatibility

Extensive compatibility testing of InspectDR.jl has not been performed.  The module has been tested using the following environment(s):

 - Linux / Julia-0.4.2 / Gtk 0.9.3 (Gtk+ 3) / Cairo 0.2.31

## Disclaimer

The InspectDR.jl module is not yet mature.  Expect significant changes.
