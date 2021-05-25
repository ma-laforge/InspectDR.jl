#InspectDR:
#-------------------------------------------------------------------------------
#=
TAGS:
	#WANTCONST, HIDEWARN_0.7
=#

const _devmode = false
if _devmode
@warn("Development mode - precompile deactivated.")
end
__precompile__(!_devmode)

module InspectDR

using Colors
using Graphics
using NumericIO
using Pkg
import Base.MathConstants: π #Just in case
import Printf: @sprintf
import Cairo
import Cairo: CairoContext

const GtkAvailable = true
import Gtk
const _Gtk = Gtk.ShortNames
#=
REMINDER:
Conditional inclusion causes issues with __precompile__() (source: tkelman).
Not worth risking precompile issues just for current troubles with JuliaBox/Gtk.

try
	import Gtk
	eval(:(const _Gtk = Gtk.ShortNames))
	GtkAvailable = true
catch
	@warn("InspectDR: Error loading Gtk.  GUI-based features are unavailable.")
end
=#


#==Constants: Initial default values
===============================================================================#
const DTPPOINTS_PER_INCH = 72 #Typography (desktop publishing) "points per inch"

#Default font:
const DEFAULT_FONTNAME = (@static Sys.iswindows() ? "Cambria" : "Serif")
#Cairo "built-in": Serif, Sans, Serif, Fantasy, Monospace
#NOTE: "Serif" does not work well in Windows.


#==Aliases
===============================================================================#
NullOr{T} = Union{Nothing, T}


#==Type definitions
===============================================================================#
#Type used to dispatch on a symbol & minimize namespace pollution:
#-------------------------------------------------------------------------------
struct DS{Symbol}; end; #Dispatchable symbol
DS(v::Symbol) = DS{v}()


#==Ensure interface (similar to assert)
===============================================================================#
#=Similar to assert.  However, unlike assert, "ensure" is not meant for
debugging.  Thus, ensure is never meant to be compiled out.
=#
function ensure(cond::Bool, err)
	if !cond; throw(err); end
end

include("codegen.jl")
include("styles.jl")
include("math.jl")
include("math_graphics.jl")
include("math_coordinates.jl")
include("heatmap_tools.jl")
include("numericfmt.jl")
include("events.jl")
include("datasets.jl")
include("grids.jl")
include("base.jl")
include("stylesheets.jl")
include("defaults.jl")
include("glyphs.jl")
include("cairo_ext.jl")
include("cairo_base.jl")
include("cairo_axes.jl")
include("cairo_annotation.jl")
include("cairo_smithpolar.jl")
include("cairo_legends.jl")
include("cairo_top.jl")
include("cairo_io.jl")
include("templates.jl")
include("compat.jl")

if GtkAvailable
include("gtk_base.jl")
include("gtk_events.jl")
include("gtk_zoom.jl")
include("gtk_layout.jl")
include("gtk_markers.jl")
include("gtk_traces.jl")
include("gtk_input.jl")
include("gtk_top.jl")
end

include("docstrings.jl")
include("show.jl")


#==Exported interface
===============================================================================#
add = _add #Danger: high risk of collision (common name)
export add, line, glyph, addheatmap
export vmarker, hmarker, atext
export clear_data


#==Accessors
===============================================================================#
if GtkAvailable
	Plot(pwidget::PlotWidget) = pwidget.src
	Plot(gplot::GtkPlot, i::Int) = gplot.subplots[i]
end


#==Initialization
===============================================================================#
function __init__()
	global defaults
	_initialize(defaults)

	if GtkAvailable
		initialize_cursors()
		_setdefaults(keybindings)
	end

	#De-activate compatibility check with Plots.jl
	#It does not seep to work very well.
	#checkcompat_plots()
end

#include("precompile.jl")

end #module
