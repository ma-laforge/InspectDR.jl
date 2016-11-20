#InspectDR: Defaults
#-------------------------------------------------------------------------------


#==Constants: Initial default values
===============================================================================#
#Default values for data area dimensions (used to save single plot):
const DEFAULT_DATA_WIDTH = 500.0
const DEFAULT_DATA_HEIGHT = DEFAULT_DATA_WIDTH / φ #Use golden ratio

#Default values for plot dimensions (used to save multi-plot):
const DEFAULT_PLOT_WIDTH = 600.0
const DEFAULT_PLOT_HEIGHT = DEFAULT_PLOT_WIDTH / φ #Use golden ratio

#Default font:
const DEFAULT_FONTNAME = (@static is_windows()? "Cambria": "Serif")
#Cairo "built-in": Serif, Sans, Serif, Fantasy, Monospace


#==Types
===============================================================================#
type Defaults
	rendersvg::Bool #Might want to dissalow SVG renderings for performance reasons
	showtimestamp::Bool
	fontname::String
	fontscale::Float64

	#Default values for data-area dimensions (saving single plot):
	wdata::Float64
	hdata::Float64

	#Default values for plot dimensions (saving multi-plot):
	wplot::Float64
	hplot::Float64
end
Defaults() =
	Defaults(true, false, DEFAULT_FONTNAME, 1,
		DEFAULT_DATA_WIDTH, DEFAULT_DATA_HEIGHT,
		DEFAULT_PLOT_WIDTH, DEFAULT_PLOT_HEIGHT,
	)


#==Data
===============================================================================#
function __init__()
	global const defaults = Defaults()
	local userdefaults

	try; userdefaults = Main.DEFAULTS_INSPECTDR
	catch; return;	end

	for (k, v) in userdefaults
		try
			setfield!(defaults, k, v)
		catch
			warn("Cannot set InspectDR.defaults.$k = $v.")
		end
	end
end


#==Functions
===============================================================================#
#Forces a function call to read *current* settings during parameter initialization:
#=Not needed:
function getdefaults(field::Symbol)
	global defaults
	return getfield(defaults, field)
end
=#


#Last line
