#InspectDR:
#-------------------------------------------------------------------------------
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

include("codegen.jl")
include("base.jl")
include("datasetop.jl")
include("ticks.jl")
#include("cairo_ext.jl")
include("cairo_base.jl")
include("cairo_io.jl")
include("gtk_base.jl")


#==Comments
================================================================================
-SVG output from writemime does not show up properly in Notebook.  There
 appears to be an issue with determining the extents of the image (bounding box).
-Data area referred to as "graph" area.  This might not be correct.
=#


#==Interface
===============================================================================#
add = _add #Danger: high risk of collision (common name)
export add, line, glyph


#==Unexported tools
================================================================================
Displays the plot:
	_display(::GtkPlot)

Convenience functions:
	write_png(path, ::Plot2D)
	write_svg(path, ::Plot2D)
	write_eps(path, ::Plot2D)
	write_pdf(path, ::Plot2D)
=#


#==Already exported
================================================================================
	Base.writemime(::IO, ::MIME, ::Plot2D)
for the following MIMEs:
		MIME"image/png"
		MIME"image/svg+xml"
		MIME"image/eps"
		MIME"application/pdf"
=#


#==
===============================================================================#
#=Plot types:
Plot2D: Generic 2D plot tool
Capable of plotting arbitrary traces: (x,y) = (u[i], v[i]), for i ∈ [1...N]
Good for:
	Nyquist plots
	Lissajous plots
	S-Parameter Plots

PlotF1: Plot functions of 1 argument.
Specialized for functions of 1 argument: y = f(x), with sorted x values.
Optimized plotting speed with sorted datasets (x[i] < x[i+1]) when compared to
Plot2D.
=#

end #module
