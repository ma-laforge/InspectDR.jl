#InspectDR:
#-------------------------------------------------------------------------------

#__precompile__()
module InspectDR

const DEFAULT_DATA_ASPECT = 1.6 #Roughly golden ratio
const DEFAULT_DATA_WIDTH = 500.0
const DEFAULT_DATA_HEIGHT = DEFAULT_DATA_WIDTH / DEFAULT_DATA_ASPECT

using Colors
using Graphics
import Gtk
const _Gtk = Gtk.ShortNames
import Cairo
import Cairo: CairoContext

typealias DisplayString UTF8String

include("codegen.jl")
include("math.jl")
include("base.jl")
include("datasetop.jl")
include("ticks.jl")
#include("cairo_ext.jl")
include("cairo_base.jl")
include("cairo_io.jl")
include("gtk_base.jl")
include("gtk_zoom.jl")
include("gtk_top.jl")


#==Comments
================================================================================
-SVG output from writemime does not show up properly in Notebook.  There
 appears to be an issue with determining the extents of the image (bounding box).
-Data area referred to as "graph" area.  This might not be correct.
=#


#==Exported interface
===============================================================================#
add = _add #Danger: high risk of collision (common name)
export add, line, glyph, grid


#==Unexported interface
================================================================================
Supported plot types:
	InspectDR.Multiplot() #Figure supporting multiple plots
	InspectDR.Plot2D <: Plot #2D plot object

Convenience functions:
	write_png(path, ::Plot)
	write_svg(path, ::Plot)
	write_eps(path, ::Plot)
	write_pdf(path, ::Plot)
=#

#Create new plot window (Is this a good idea?):
#	figure(args...; kwargs...) = GtkPlotWindow(args...; kwargs...)

#Accessors:
	Plot(gplot::GtkPlot) = gplot.src
	Plot(wnd::GtkPlotWindow, i::Int) = wnd.subplots[i]


#==Already exported
================================================================================
#Displaying a plot object:
	Base.display(d::InspectDR.GtkDisplay, p::Plot) #Gtk mutltiplot window

#Writing plot to IO stream:
	Base.writemime(::IO, ::MIME, ::Plot2D)
for the following MIMEs:
		MIME"image/png"
		MIME"image/svg+xml"
		MIME"image/eps"
		MIME"application/pdf"
=#

end #module
