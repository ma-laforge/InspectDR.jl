# InspectDR: Programming Interface

Note that many types & functions are not exported from InspectDR in order to avoid namespace pollution.  That being said, the module name will often be omitted below in an attempt to improve readability.

<a name="MainPlotObjects"></a>
## Main Plot Objects

- **`InspectDR.Plot`**: An abstract plot object.
- **`InspectDR.Plot2D <: Plot`**:  A 2D plot object.  Construct empty 2D plot using `InspectDR.Plot2D(title="Plot Title")`.
- **`InspectDR.Multiplot`**:  A multi-plot object.  Construct empty multi-plot using: `InspectDR.Multiplot(title="Multiplot Title")`.

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

<a name="DisplaySystem"></a>
## Display/Render System

InspectDR provides the `GtkDisplay` object derived from `Base.Multimedia.Display`.  `GtkDisplay` is used in combination with `Base.display()`, to spawn a new instance of a GTK-based GUI.

To display a single `plot::Plot` object, one simply calls:
```
gplot = display(InspectDR.GtkDisplay(), plot)
```

Similarly, to display `mplot::Multiplot` object, one calls:
```
gplot = display(InspectDR.GtkDisplay(), mplot)
```

To programmatically close a Gtk plot window, the `close()` function can be used:
```
close(gplot)
```

<a name="Templates_Scales"></a>
## Plot Templates/Axis Scales

In order to support stacked graphs with independent y-axes (tied to the same x-axis), specifying axis scales is a bit involved:

- `InspectDR.Plot2D.xscale` controls the x-axis scale.
- `InspectDR.Plot2D.strips[STRIP_INDEX].yscale` controls the y-axis scale.

To streamline control over plot axes/grids/labels/..., it is highly recommended to use the following **plot templates**:

1. `Plot2D(xscale, yscalelist; kwargs...)`: Generic 2D plot template.

    - `Plot2D(:lin, :log, title="title", xlabel="X", ylabels=["log(Y)"])`: Construct plot with a linear X-axis & log10 Y-axis.
    - `Plot2D(:log10, [:dB20, :lin, :lin], title="title", xlabel="X", ylabels=["Y1 (dB)", "Y2", "Y3"])`: Construct plot with a log10 X-axis, and 2 Y-strips: the top-most with a dB20 Y-scale, and the next two with linear Y-scale.

2. `bodeplot(; kwargs...)`: Template for generating Bode plots.
    - `bodeplot()`: Default `kwargs` already set: `xlabel="Frequency (Hz)"`, ylabels=["Magnitude (dB)", "Phase (°)]"`.

3. `transientplot(yscalelist; kwargs...)`: Template for plotting transient data.
    - `transientplot([:lin, :lin, :lin], title="title", ylabels=["Voltage", "Voltage", "Current"])`: `xlabel` already set to `"Time (s)"`, by default.

4. `smithchart(TYPE; ref, kwargs...)`: Template for plotting onto a Smith Chart.
    - `smithchart(:Z, ref=50)`: Impedance (`Z`) Smith Chart with a 50&Omega; reference. Default `kwargs` already set: `xlabel="Real(Γ)"`, `ylabels=["Imaginary(Γ)"]"`.
    - `smithchart(:Y, ref=75)`: Admittance (`Y`) Smith Chart with a 75&Omega; reference.

NOTE: X/Y-axis scales are specified using one of the following `::Symbols`:

- `:lin`
- `:log10`, `:log` (= `:log10`)
- `:ln`, `:log2`: Grid lines might need improvement here.
- `:dB20`, `:dB10`

<a name="Layout_Stylesheets"></a>
## Layout & Stylesheets

The appearance of InspectDR plots is configured through the `.layout` properties of `::Plot2D` & `::Multiplot` objects.  Until better documentation is available, one is encouraged to look at the fields of the `PlotLayout` & `MultiplotLayout` for more information:
```
#To control apperance of Plot2D elements:
?InspectDR.PlotLayout

#To control apperance of Multiplot elements:
?InspectDR.MultiplotLayout
```

The `.layout` properties should be accessed using the `[]` operators, using the field names names of `PlotLayout` / `MultiplotLayout` as arguments:

```
plot.layout[:valloc_top] = 20 #Modify space above data area
```

### Legends

At this point in time, legends have limited configurability.  When displayed, legends will consume fixed horizontal real-estate.  The idea is to display a large number of labels without hiding the data area.

In order to display the legend of a `plot::Plot2D` object, one would set:
```
plot.layout[:enable_legend] = true #Enables legend
plot.layout[:halloc_legend] = 150 #Control size of legend
```

### Pre-defined Stylesheets

InspectDR uses "Stylesheets" to control the default values of plot elements.  To apply a different stylesheet to a given plot, use the `setstyle!` methods:

```
InspectDR.setstyle!(::Plot2D, stylesheet::Symbol; kwargs...)
InspectDR.setstyle!(::Multiplot, stylesheet::Symbol; kwargs...)
```

Currently supported values for `stylesheet` include:
- `:screen`
- `:IEEE`

Custom stylesheets are added by extending `InspectDR.getstyle()`, as done in [stylesheets.jl](../src/stylesheets.jl) (Search for: `StyleID{:screen}` & `StyleID{:IEEE}`).

<a name="CodeDoc_Arch"></a>
# Code Documentation & Architecture

To help clarify software design choices, nomenclature, etc, software documentation is provided in the [src/doc](../src/doc) directory.
