# InspectDR: Configuration/Defaults

Default InspectDR.jl settings can be overwritten once the module is loaded by editing the `InspectDR.defaults` structure:

```julia
#Dissalow SVG MIME output for performance reasons:
InspectDR.defaults.rendersvg = false

#Change when plots drop points to enable "F1"-acceleration:
#(One of: {:always, :never, :noglyph, :hasline})
InspectDR.defaults.pointdropmatrix = InspectDR.PDM_DEFAULTS[:always]

#Enable time stamp & legend:
InspectDR.defaults.plotlayout[:enable_timestamp] = true
InspectDR.defaults.plotlayout[:enable_legend] = true

#Set data-area dimensions (saving single plot):
InspectDR.defaults.plotlayout[:halloc_data] = 500
InspectDR.defaults.plotlayout[:valloc_data] = 350

#Set plot dimensions (saving multi-plot):
InspectDR.defaults.mplotlayout[:halloc_plot] = 500
InspectDR.defaults.mplotlayout[:valloc_plot] = 350

#Configure # of columns in multi-plot outputs:
InspectDR.defaults.mplotlayout[:ncolumns] = 2
```

Until better documentation is available, one is encouraged to look at the fields of the `PlotLayout` for more information:
```julia
?InspectDR.PlotLayout
```

Defaults can also be specified *before* importing InspectDR.jl with the help of `Main.DEFAULTS_INSPECTDR::Dict`.  Simply create the variable in your `~/.julia/config/startup.jl` file, using the following pattern:
```julia
DEFAULTS_INSPECTDR = Dict(
	:rendersvg => false,

	#Special options available @ initialization:
	:droppoints => :always, #One of: {:always, :never, :noglyph, :hasline}
	:notation_x => :SI,   #Change x-axis notation
	:notation_y => :SI,   #Change y-axis notation
	:fontname => "Sans",  #Change default font family
	:fontscale => 1.2,    #Scale up/down font default sizes

	#Basic plot options:
	:enable_timestamp => true,
	:enable_legend => true,
	:halloc_legend => 150,

	#Supported multiplot options:
	:ncolumns => 2,
	:halloc_plot => 500,
	:valloc_plot => 350,
)
```

