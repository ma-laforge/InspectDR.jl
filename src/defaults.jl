#InspectDR: Defaults
#-------------------------------------------------------------------------------


#==Types
===============================================================================#
mutable struct Defaults
	rendersvg::Bool #Might want to dissalow SVG renderings for performance reasons

	plotlayout::PlotLayout
	mplotlayout::MultiplotLayout
end


#==Set style of Defaults
===============================================================================#
function setstyle!(d::Defaults, styleid::Symbol; refresh::Bool=true, kwargs...)
	s.plotlayout = getstyle(PlotLayout, StyleID(styleid); kwargs...)
	s.mplotlayout = getstyle(MultiplotLayout, StyleID(styleid); kwargs...)
end


#==Data Initialization
===============================================================================#
#Initialize InspectDR.defaults (To be called in __init__()):
function initialize_defaults()
	local userdefaults = Dict{Symbol, Any}()
	try
		userdefaults = copy(Main.DEFAULTS_INSPECTDR)
	end

	function condget(dict, key::Symbol, T::Type, default)
		if haskey(dict, key)
			return T(pop!(dict, key))
		else
			return T(default)
		end
	end

	rendersvg = condget(userdefaults, :rendersvg, Bool, true)
	notation_x = condget(userdefaults, :notation_x, Symbol, :ENG)
	notation_y = condget(userdefaults, :notation_y, Symbol, :ENG)

	fontname = condget(userdefaults, :fontname, String, DEFAULT_FONTNAME)
	fontscale = condget(userdefaults, :fontscale, Float64, 1.0)

	#Manually get SUPPORTED defaults for Multiplot layout (seed from :screen):
	mplotlayout = getstyle(MultiplotLayout, :screen,
		fontname=fontname, fontscale=fontscale
	)
	condoverwrite(key::Symbol, T::Type) =
		mplotlayout[key] = condget(userdefaults, key, T, mplotlayout[key])
	condoverwrite(:ncolumns, Int)
	condoverwrite(:valloc_plot, Float64)
	condoverwrite(:halloc_plot, Float64)

	#Automatically get defaults for Plot layout (seed from :screen):
	plotlayout = getstyle(PlotLayout, :screen,
		fontname=fontname, fontscale=fontscale,
		notation_x=notation_x, notation_y=notation_x, enable_legend=false
	)
	for (k, v) in userdefaults
		try
			plotlayout[k] = v
		catch
			warn("Cannot set default PlotLayout.$k = $v.")
		end
	end

	global const defaults = Defaults(rendersvg, plotlayout, mplotlayout)
	return
end

#Last line
