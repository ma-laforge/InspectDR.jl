#InspectDR: Defaults
#-------------------------------------------------------------------------------


#==Constants
===============================================================================#
#Identifies whether a plot should apply f1 acceleration to drop points:
const PDM_NEVER = PointDropMatrix([false false; false false])
const PDM_ALWAYS = PointDropMatrix([true true; true true])
const PDM_NOGLYPH = PointDropMatrix([false false; true false])
const PDM_HASLINE = PointDropMatrix([false false; true true])
const PDM_DEFAULTS = Dict(
	:never => PDM_NEVER,
	:always => PDM_ALWAYS,
	:noglyph => PDM_NOGLYPH,
	:hasline => PDM_HASLINE,
)


#==Types
===============================================================================#
mutable struct Defaults
	rendersvg::Bool #Might want to dissalow SVG renderings for performance reasons
	xaxiscontrol_visible::Bool
	pointdropmatrix::PointDropMatrix
	colorscale::ColorScale

	plotlayout::PlotLayout
	mplotlayout::MultiplotLayout
end
Defaults() = Defaults(
	false, false, PDM_NEVER, ColorScale(),
	PlotLayout(PREDEFAULTS), MultiplotLayout(PREDEFAULTS)
)


#==Data
===============================================================================#
const global defaults = Defaults()

#==Constructors
===============================================================================#

PlotLayout() = PlotLayout(defaults.plotlayout)
MultiplotLayout() = MultiplotLayout(defaults.mplotlayout)


#==Set style of Defaults
===============================================================================#
function setstyle!(d::Defaults, styleid::Symbol; refresh::Bool=true, kwargs...)
	s.plotlayout = getstyle(PlotLayout, StyleID(styleid); kwargs...)
	s.mplotlayout = getstyle(MultiplotLayout, StyleID(styleid); kwargs...)
end


#==Data Initialization
===============================================================================#
#Initialize InspectDR.defaults (To be called in __init__()):
function _initialize(dflt::Defaults)
	local userdefaults = Dict{Symbol, Any}()
	try
		userdefaults = copy(Main.DEFAULTS_INSPECTDR)
	catch
	end

	#Get dict value, or default if not exist.
	#Note: Pop key from dict to avoid double processing
	function condget(dict, key::Symbol, T::Type, default)
		if haskey(dict, key)
			return T(pop!(dict, key))
		else
			return T(default)
		end
	end
	function condget(dict, key::Symbol, T::Type, default::KeepPrevType)
		if haskey(dict, key)
			return T(pop!(dict, key))
		else
			return default
		end
	end

	dflt.rendersvg = condget(userdefaults, :rendersvg, Bool, true)
	dflt.xaxiscontrol_visible = condget(userdefaults, :xaxiscontrol_visible, Bool, true)
	notation_x = condget(userdefaults, :notation_x, Symbol, :ENG)
	notation_y = condget(userdefaults, :notation_y, Symbol, :ENG)
	notation_z = condget(userdefaults, :notation_z, Symbol, :ENG)
	droppoints = condget(userdefaults, :droppoints, Symbol, :noglyph)
	dflt.pointdropmatrix = PDM_DEFAULTS[droppoints]
	cmapid = condget(userdefaults, :colorscale, String, "Oranges")
	dflt.colorscale = ColorScale(Colors.colormap(cmapid))

	fontname = condget(userdefaults, :fontname, String, DEFAULT_FONTNAME)
	fontscale = condget(userdefaults, :fontscale, Float64, 1.0)

	dflt.mplotlayout = getstyle(MultiplotLayout, :screen)
	overwritefont!(dflt.mplotlayout, fontname=fontname, fontscale=fontscale)

	#Manually get SUPPORTED defaults for Multiplot layout (seed from :screen):
	condoverwrite(key::Symbol, T::Type) =
		(overwriteprop!(dflt.mplotlayout, key, condget(userdefaults, key, T, KEEP_PREV)))
	condoverwrite(:ncolumns, Int)
	condoverwrite(:valloc_plot, Float64)
	condoverwrite(:halloc_plot, Float64)

	#Automatically get defaults for Plot layout (seed from :screen):
	dflt.plotlayout = getstyle(PlotLayout, :screen,
		notation_x=notation_x, notation_y=notation_x, enable_legend=false
	)
	overwritefont!(dflt.plotlayout, fontname=fontname, fontscale=fontscale)
	for (k, v) in userdefaults
		try
			dflt.plotlayout[k] = v
		catch
			@warn("Cannot set default PlotLayout.$k = $v.")
		end
	end

	return
end

#Last line
