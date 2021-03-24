# TODO: Scales

The following lists various desired ways to display axis scales & labels.

## Lin scales

### Config: Display compact (maxdigits = M)
 - Only use scientific notation when # digits exceeds M.

### Config: Display scientific/engineering/SI
 - Ticks scientific: (1x10^6, 1x10^7, 1x10^8, 1x10^9)
 - Ticks engineering: (1x10^6, 10x10^6, 100x10^6, 1x10^9)
 - Ticks SI: (1M, 10M, 100M, 1G)

### Config: Display common axis factor, F
 - Ticks F native (F=1): (1x10^6, 5x10^7, 1x10^8, 1.5x10^8)
 - Ticks F user defined (F=10^9): (.001, .05, .1, .15) x10^9
 - Ticks F aligned low: (1, 50, 100, 150) x10^6
 - Ticks F aligned middle: (0.1, 5, 10, 15) x10^7
 - Ticks F aligned high: (0.01, 0.5, 1.0, 1.5) x10^8

## Log scales

### Config: Display C * N^EXP for user-selected C, N:
 - Ticks native (5, 10): (50, 500, 5000, 50000)
 - Ticks compact (5, 10): (5x10^1, 5x10^2, 5x10^3, 5x10^4)
 - Ticks native (1, 2): (2, 4, 8, 16)
 - Ticks compact (1.5, 2): (1.5x2^1, 1.5x2^2, 1.5x2^3, 1.5x2^4)
 - Ticks compact (2.5, e): (2.5xe^1, 2.5xe^2, 2.5xe^3, 2.5xe^4)

## Other scales

 - 1/x Scale

## Scale transformations

 - Provide a means to reverse axis direction.

# Event handlers

## Raise event: UpdateStatusMsg instead of using pwidget.eh_plothover.
Possibly better for encapsulation. That way, you wouldn't necessarily need to store pwidget.mouseover.
Instead, you could keep mouseover info in input state.

You could use status message to inform about new layout sizes as well, instead of overlaying on plot itself.

## Raise event: pwidget.eh_plothover.
Could be used by user for other things (instead of being used by GtkPlot for coordinate status message).

# Defaults system
 - Improve defaults system so that it works better (overwriting system is a bit buggy/clunky).
 - Start using `getproperty` instead of `getindex`/`setindex!`. (`layout.halloc_legend` instead of `layout[:halloc_legend]`.
 - Centralize in separate package.

# Function/Datatype overlap/confusion

 - Mutable vs immutable structs: convenience vs side effects vs performance, etc.
 - LineAttributes vs LineStyle: Very confusing.
 - Defaults vs stylesheets: Confusing!!!! => Consolidate a bit more / make more coherent.

# Re-org base.jl/math_graphics.jl/math_coordinates.jl
 - math_coordinates -> coord_tranforms.jl?
   - AxisScale stuff, InputXfrm*, data2aloc, ...
 - math_graphics -> cartesian.jl
   - Move some stuff to coord_transforms.jl
 - Many things in base.jl pertain to layouts.
   - Split base layout functions to a file called layout.jl?
   - Split Plot/Multiplot-based layout functions to a file caled plot_layout.jl?
 - Move plot update/refresh functions in base.jl -> plot_update.jl?
 - layout.jl could house:
   - PlotLayout, grid1, databounds, plotbounds, graphbounds
   - griddims_auto, size_auto, plotbblist_auto

# Improve Layout system
 - Migrate LayoutControlInfo to base/Cairo layers.
 - Start using bounding boxes in Cairo layers.

Maybe find a way to do something like rename `PlotLayout -> PlotConfig`, then:
```julia
struct PlotLayout
	legend::BoundingBox
	data::BoundingBox
	... #More bounding boxes
end

function ComputeBoundingBoxes(plotconfig::PlotConfig, bb::BoundingBox)
	#Where bb is the entire canvas' bounding box
	return PlotLayout(bblegend, bbdata, ...)
end
```

# Documentation

 - Document callback/event handler hierarchy and how they are ued.
 - Document defaults system and how it is used.
 - Document plot generator and stylesheets systems.
 - Document Plot object hierarchy and how to use it.
 - Document plot invalidation and how it is applied.
 - Document scales, transformations and function hierarchy (ex: aloc2axis).

# Other

 - Improve differentiation of private vs externally available variables in structures like Plot2D, GraphStrip, etc.
 - GUI: cancel triggered operation if activestrip(w) < 1
 - Fix aspect_square functionality (currently very hacky).
 - Fix issues with fractional pixel graph bounds.
 - Fix how we store/manipulate extents
 - REMOVE DUPLICATED CODE WHENEVER POSSIBLE!
 - There is HUGE room for improvement in function/type names, and how solution is broken down. There has been some very confusing patchwork.

# Deprecation
rename `refresh()` -> `refresh!()`?? or vice-versa?? Strange to have both.
...
