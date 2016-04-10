#InspectDR:
#-------------------------------------------------------------------------------
module InspectDR

using Colors
using Graphics
import Gtk
const _Gtk = Gtk.ShortNames
import Cairo
import Cairo: CairoContext

include("codegen.jl")
include("base.jl")
include("datasetop.jl")
include("cairo_base.jl")
include("gtk_base.jl")

#==Interface
===============================================================================#
add = _add #Danger: high risk of collision (common name)
export add, line, glyph

#==Unexported tools
================================================================================
	_display: Displays the pot
=#


#==Already exported
================================================================================
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
