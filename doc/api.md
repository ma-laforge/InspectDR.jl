# InspectDR: Programming interface

Note that many types & functions are not exported from InspectDR in order to avoid namespace pollution.  That being said, the module name will often be omitted below in an attempt to improve readability.

 1. [Main plot objects](#MainPlotObjects)
 1. [Secondary plot objects](#SecondaryPlotObjects)
 1. [Axis scale identifiers](#AxisScaleIdentifiers)
 1. [Function listing](#FunctionListing)
 1. [Creating plots](#CreatingPlots)
 1. [Plot generators](#PlotGenerators)
 1. [Displaying plots](#DisplayingPlots)
 1. [Layout & stylesheets](#Layout_Stylesheets)
 1. [Advanced usage](advanced.md)
    1. [Display/Render System](advanced.md#DisplaySystem)
    1. [Custom plot generators](advanced.md#CustomGenerators)
    1. [Custom stylesheets](advanced.md#CustomStylesheets)


<a name="MainPlotObjects"></a>
## Main plot objects

 - **`InspectDR.Plot`**: An abstract plot object.
 - **`InspectDR.Plot2D <: Plot`**:  A 2D plot object.
   - `InspectDR.Plot2D(title="Plot Title")`: Constructs empty 2D plot.
 - **`InspectDR.Multiplot`**:  A master plot structure that collects multiple `Plot`s together.
   - `InspectDR.Multiplot(title="Multiplot Title")`: Constructs empty multi-plot object.
 - **`InspectDR.GtkPlot`**: Gtk window that can display/manipulate a `Multiplot` object.

<a name="SecondaryPlotObjects"></a>
## Secondary plot objects

 - IDataset: {x, y} vectors representing 2D data.
 - `Waveform{IDataset}`: Stores input data and attributes specifying how do display.
 - `LineAttributes`: User-defined attributes for lines.
 - `GlyphAttributes`: User-defined attributes for glyphs (or "markers").

<a name="AxisScaleIdentifiers"></a>
## Axis scale identifiers
X/Y-axis scales are specified using one of the following `Symbols`:

 - `:lin`
 - `:log10`, `:log` (= `:log10`)
 - `:ln`, `:log2`: Grid lines might need improvement here.
 - `:dB20`, `:dB10`

<a name="FunctionListing"></a>
## Function listing
For more detailed information, use Julia's help system (`? [function name]`).

 - `Base.display(::Plot2D/Multiplot)`
 - `Base.close(::GtkPlot)`
 - `Base.show(::IO, ::MIME, ::Plot2D)`
 - `Base.show(::IO, ::MIME, ::Plot2D)`
 - `add(...)`: Add an element to a collection
   - `add(::Plot, ...)`: Add a dataset to a `Plot` object.
   - `add(::Multiplot, ...)`: Add a subplot to a `Multiplot` object.
 - `line(; style=, width=, color=)`: Create a `LineAttributes` object.
 - `glyph(; shape=, size=, color=, fillcolor=)`: Create a `GlyphAttributes` object.
 - `set(...)`: Modify attributes of an object.
   - `set(::Waveform, [attr]...)`: Set `LineAttributes` and/or `GlyphAttributes`.
 - TODO: addheatmap, vmarker, hmarker, atext, clear_data, refresh, write_png.

<a name="CreatingPlots"></a>
## Creating plots

### Plot creation example: A simple plot
The following shows how to create plots with InspectDR:

```julia
using InspectDR

#Generate some data:
x = collect(-2:.1:2)

#Create some plot:
plot1 = InspectDR.Plot2D(:lin, :lin, title="Some plot",
	xlabel="x-value", ylabels=["y-value"]
)
plot1.layout[:enable_legend] = true

#Add some data:
add(plot1, x, x.^2, id="x^2")
add(plot1, x, x.^3, id="x^3")

display(InspectDR.GtkDisplay(), plot1)
```

### Plot creation example: A stacked, multi-*strip* plot
`Plot2D` supports "multi-strip" plots with a common x-axis and multiple stacked y-axes.
"Multi-strip" plots are ideal for plotting data with wildly differing y-value ranges.

```julia
using InspectDR

#Generate data with differing y-value ranges:
T = 1/60; ΔT = T/20 #sec
C = 480e-6 #F
t = collect(0:ΔT:8T) #sec
v = (120*sqrt(2)) .* sin.(t.*(2π/T)) #V
	dv_dt = (2π/T) .* cos.(t.*(2π/T))
i = C .* dv_dt

#Create a multi-strip plot:
plot2 = InspectDR.Plot2D(:lin, [:lin, :lin], title="Multi-strip plot",
	xlabel="Time (V)", ylabels=["Voltage (V)", "Current (A)"]
)
plot2.layout[:enable_legend] = true
add(plot2, t, v, strip=1, id="cap")
add(plot2, t, i, strip=2, id="cap")

display(InspectDR.GtkDisplay(), plot2)
```

### Plot creation example: A multi-*plot* collection

```julia
mplot = InspectDR.Multiplot(title="A Multiplot Object", ncolumns=2)
add(mplot, plot1)
add(mplot, plot2)

display(InspectDR.GtkDisplay(), mplot)
```

<a name="PlotGenerators"></a>
## Plot generators
Specialized plot generator functions help to streamline control over plot axes/grids/labels/etc.
The following plot generators assist in creating `Plot2D` objects:

 1. `Plot2D(xscale, yscalelist; kwargs...)`: Generate a basic 2D plot.
     - `Plot2D(:lin, :log, title="title", xlabel="X", ylabels=["log(Y)"])`: Construct plot with a linear X-axis & log10 Y-axis.
     - `Plot2D(:log10, [:dB20, :lin, :lin], title="title", xlabel="X", ylabels=["Y1 (dB)", "Y2", "Y3"])`: Construct plot with a log10 X-axis, and 2 Y-strips: the top-most with a dB20 Y-scale, and the next two with linear Y-scale.
 2. `bodeplot(; kwargs...)`: Generate Bode plots.
     - `bodeplot()`: Default `kwargs` already set: `xlabel="Frequency (Hz)"`, ylabels=["Magnitude (dB)", "Phase (°)]"`.
 3. `transientplot(yscalelist; kwargs...)`: Generate time-domain plots.
     - `transientplot([:lin, :lin, :lin], title="title", ylabels=["Voltage", "Voltage", "Current"])`: `xlabel` already set to `"Time (s)"`, by default.
 4. `smithchart(TYPE; ref, kwargs...)`: Generate Smith Charts.
     - `smithchart(:Z, ref=50)`: Impedance (`Z`) Smith Chart with a 50&Omega; reference. Default `kwargs` already set: `xlabel="Real(Γ)"`, `ylabels=["Imaginary(Γ)"]"`.
     - `smithchart(:Y, ref=75)`: Admittance (`Y`) Smith Chart with a 75&Omega; reference.

<a name="DisplayingPlots"></a>
## Displaying plots

### Displaying plots: Gtk windows
To display a either a `Plot`, `Multiplot` object by creating a `GktPlot` GUI window, one simply calls:
```julia
gplot = display(InspectDR.GtkDisplay(), plot)
```

To programmatically close a `GktPlot` window, the `close()` function can be used:
```julia
close(gplot)
```

### Displaying plots: Inline plots in Jupyter
InspectDR already defines the `show(::IO, ::MIME, ::T)` functions for `Plot` and `Multiplot`.

Thus, you can display plots as inline images using `Base.display()`:
```julia
display(plot)
```

Also, since Jupyter automatically calls `Base.display()` on the last statement of a code block,
plots are automatically displayed if they are the the last statement:
```julia
#Start of Jupyter code block
# ... (Some code)
#Last statement:
plot #Implicit call to "optimal" show(::IO, ::MIME, ::T)
```

Note that there are rendering issues with Jupyter and MIME"image/svg+xml" (speed being one of them).
To inhibit InspectDR from `show`-ing with the SVG format, the following setting can be changed:
```julia
InspectDR.defaults.rendersvg = false
```

<a name="Layout_Stylesheets"></a>
## Layout & stylesheets
The appearance of InspectDR plots is configured through the `.layout` properties of `::Plot2D` & `::Multiplot` objects.  Until better documentation is available, one is encouraged to look at the fields of the `PlotLayout` & `MultiplotLayout` for more information:
```julia
#To control apperance of Plot2D elements:
?InspectDR.PlotLayout

#To control apperance of Multiplot elements:
?InspectDR.MultiplotLayout
```

The `.layout` properties should be accessed using the `[]` operators, using the field names names of `PlotLayout` / `MultiplotLayout` as arguments:

```julia
plot.layout[:valloc_top] = 20 #Modify space above data area
```

### Grids
Plot gridlines are configurable on a per-strip basis.  Assuming a `plot::Plot2D` object exists, the configuration can be altered with `GridRect()`:
```julia
plot.strips[i].grid = InspectDR.GridRect(vmajor=true, vminor=true, hmajor=false, hminor=false)
```

### Legends
At this point in time, legends have limited configurability.  When displayed, legends will consume fixed horizontal real-estate.  The idea is to display a large number of labels without hiding the data area.

In order to display the legend of a `plot::Plot2D` object, one would set:
```julia
plot.layout[:enable_legend] = true #Enables legend
plot.layout[:halloc_legend] = 150 #Control size of legend
```

### Pre-defined stylesheets
InspectDR uses "Stylesheets" to control the default values of plot elements.  To apply a different stylesheet to a given plot, use the `setstyle!` methods:

```julia
InspectDR.setstyle!(::Plot2D, stylesheet::Symbol; kwargs...)
InspectDR.setstyle!(::Multiplot, stylesheet::Symbol; kwargs...)
```

Currently supported values for `stylesheet` include:
 - `:screen`
 - `:IEEE`

