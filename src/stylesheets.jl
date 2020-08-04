#InspectDR: Defines stylesheets & presets
#-------------------------------------------------------------------------------

#==Important notes
***IEEE Plots***
  - Write out/export `Multiplot` object instead of `Plot` in order to control
    full plot dimensions instead of just dimensions of data area.
==#


#==Constants: Initial default values
===============================================================================#
#Default values for data area dimensions (used to save single plot):
const DEFAULT_DATA_WIDTH = 500.0
const DEFAULT_DATA_HEIGHT = DEFAULT_DATA_WIDTH / MathConstants.φ #Use golden ratio

#Default values for plot dimensions (used to save multi-plot):
const DEFAULT_PLOT_WIDTH = 600.0
const DEFAULT_PLOT_HEIGHT = DEFAULT_PLOT_WIDTH / MathConstants.φ #Use golden ratio

const PROPSET_PLOTFONTS = Set([:font_title, :font_axislabel, :font_ticklabel, :font_annotation, :font_legend, :font_time])
const PROPSET_MPLOTFONTS = Set([:font_title])

#Properties updated when autofitting to font:
const PROPSET_PLOTAUTOFIT = Set([
	:h_title, :h_axislabel, :h_ticklabel, :w_axislabel, :w_ticklabel,
	:valloc_top, :valloc_mid, :valloc_bottom, :halloc_left, :halloc_right,
	:halloc_colorscale, :halloc_colorscale_right, :halloc_legend, :voffset_title,
	:voffset_xticklabel, :hoffset_yticklabel, :voffset_xaxislabel, :hoffset_yaxislabel
])
const PROPSET_MPLOTAUTOFIT = Set([:valloc_title])

#==Types
===============================================================================#
mutable struct StyleID{T}; end
StyleID(T::Symbol) = StyleID{T}()

mutable struct PlotSylesheet
	plotlayout::PlotLayout
	mplotlayout::MultiplotLayout
end


#==Useful functions
===============================================================================#
#Round select layout values to avoid fractional pixel lines
function _round!(lyt::PlotLayout)
	_r!(font::Font) = (font._size = round(font._size, digits=1)) #Some fraction is ok
	_r(v::DReal) = round(v, digits=0) #No fractions.

	#Also round font values in case:
	_r!(lyt.font_title)
	_r!(lyt.font_striplabel)
	_r!(lyt.font_axislabel)
	_r!(lyt.font_ticklabel)
	_r!(lyt.font_annotation)
	_r!(lyt.font_time)
	_r!(lyt.font_legend)


	lyt.valloc_top = _r(lyt.valloc_top)
	lyt.valloc_mid = _r(lyt.valloc_mid)
	lyt.valloc_bottom = _r(lyt.valloc_bottom)

	lyt.halloc_data = _r(lyt.halloc_data)
	lyt.halloc_left = _r(lyt.halloc_left)
	lyt.halloc_right = _r(lyt.halloc_right)
	lyt.halloc_colorscale = _r(lyt.halloc_colorscale)
	lyt.halloc_colorscale_right = _r(lyt.halloc_colorscale_right)
	lyt.halloc_legend = _r(lyt.halloc_legend)
	return lyt
end
_round!(lyt::MultiplotLayout) = lyt #No need

"""
    autofit2font!(lyt::PlotLayout; legend_width::Float64=10.0)

Try to size allocations & offsets appropriately for font selections.

# Arguments
 - legend_width: In EM ("M" character widths)
"""
function autofit2font!(lyt::PlotLayout; legend_width::Float64=10.0)
#=IMPORTANT:
	-update PROPSET_PLOTAUTOFIT if more properties are modified!
	-We force pt2px=1 here because font sizes already scaled to get desired ppi effect.
	 This is BAD!!!!! Find a better way to capture effect of dpi @ drawing layer
	 instead of here.
=#

	pt2px = 1; #ppi/DTPPOINTS_PER_INCH Assumes 12pt height will translate to 12 pixel height.
	KHEIGHT = 1.4 #Factor to pad up label text "height" (irrespective of orientation)
	KOFFSET = 0.2 #Text "height"-to-offset factor

	#"M" width (=height) for different elements:
	em_title = lyt.font_title._size * pt2px
	em_striplabel = lyt.font_striplabel._size * pt2px
	em_axislabel = lyt.font_axislabel._size * pt2px
	em_ticklabel = lyt.font_ticklabel._size * pt2px
	em_font_legend = lyt.font_legend._size * pt2px

	#Compute label offsets wrt em-height/widths:
	lyt.voffset_title = em_title*KOFFSET
	lyt.voffset_xticklabel = em_ticklabel*KOFFSET
	lyt.hoffset_yticklabel = em_ticklabel*KOFFSET
	lyt.voffset_xaxislabel = lyt.hoffset_yticklabel + em_ticklabel + em_axislabel*KOFFSET
	lyt.hoffset_yaxislabel = em_axislabel*KOFFSET + 4*em_ticklabel + lyt.hoffset_yticklabel

	#Compute vertical allocations:
	lyt.valloc_top = max(em_title, em_striplabel) * KHEIGHT #Should not have both
	lyt.valloc_mid = max(em_striplabel, em_axislabel) * KHEIGHT #Room for x10^EXP
	lyt.valloc_bottom = lyt.voffset_xaxislabel + em_axislabel*KHEIGHT

	#Compute horizontal allocations:
	lyt.halloc_left = em_axislabel*KHEIGHT + 4*em_ticklabel + lyt.hoffset_yticklabel
	lyt.halloc_right = 3.75*em_ticklabel #Room for x10^EXP
	lyt.halloc_colorscale_right = 4.25*em_ticklabel #TODO: makes no sense

	lyt.halloc_legend = em_font_legend*legend_width
	return lyt
end

#Try to size allocations & offsets appropriately for font selections:
function autofit2font!(lyt::MultiplotLayout)
	lyt.valloc_title = lyt.font_title._size * 1.5
	return lyt
end

function _overwritefont!(lyt::T, propset, fontname, fontscale::DReal, autofit::Bool) where T<:Union{PlotLayout,MultiplotLayout}
	if fontname!=nothing
		for prop in propset
			ref = getfield(lyt, prop)
			ref.name = fontname
		end
	end

	for prop in propset
		ref = getfield(lyt, prop)
		ref._size *= fontscale
	end

	if autofit
		autofit2font!(lyt)
	end
	return _round!(lyt)
end

overwritefont!(lyt::PlotLayout; fontname=nothing, fontscale::Number=1.0, autofit::Bool=true) =
	_overwritefont!(lyt, PROPSET_PLOTFONTS, fontname, DReal(fontscale), autofit)

function overwritefont!(lyt::PlotStyle; fontname=nothing, fontscale::Number=1.0, autofit::Bool=true)
	_overwritefont!(lyt.values, PROPSET_PLOTFONTS, fontname, DReal(fontscale), autofit)
	markoverwritten!(lyt, PROPSET_PLOTFONTS)
	if autofit
		markoverwritten!(lyt, PROPSET_PLOTAUTOFIT)
	end
end

overwritefont!(lyt::MultiplotLayout; fontname=nothing, fontscale::Number=1.0, autofit::Bool=true) =
	_overwritefont!(lyt, PROPSET_MPLOTFONTS, fontname, DReal(fontscale), autofit)

function overwritefont!(lyt::MultiplotStyle; fontname=nothing, fontscale::Number=1.0, autofit::Bool=true)
	_overwritefont!(lyt.values, PROPSET_MPLOTFONTS, fontname, DReal(fontscale), autofit)
	markoverwritten!(lyt, PROPSET_MPLOTFONTS)
	if autofit
		markoverwritten!(lyt, PROPSET_MPLOTAUTOFIT)
	end
end


#==Preset Stylesheets
===============================================================================#

#Default ":screen" stylesheet:
#-------------------------------------------------------------------------------

#Default ":screen" PlotLayout stylesheet:
function getstyle(::Type{PlotLayout}, ::StyleID{:screen},
		fontscale::Float64, notation_x::Symbol, notation_y::Symbol, enable_legend::Bool)
	lyt = PlotLayout(PREDEFAULTS)
	#NOTE: Dimensions in Cairo backend are in pixels.

	lyt.enable_legend = enable_legend
	lyt.enable_timestamp = false

	lyt.font_title = Font(lyt.font_title.name, 14*fontscale, bold=true)
	lyt.font_striplabel._size = 12*fontscale
	lyt.font_axislabel._size = 14*fontscale
	lyt.font_ticklabel._size = 12*fontscale
	lyt.font_annotation._size = 12*fontscale
	lyt.font_time._size = 8*fontscale
	lyt.font_legend._size = 12*fontscale

	lyt.valloc_data = DEFAULT_DATA_HEIGHT
	lyt.halloc_data = DEFAULT_DATA_WIDTH

	lyt.halloc_colorscale = 20
	lyt.halloc_legendlineseg = 20
	lyt.hoffset_legendtext = 0.5 #EMs
	lyt.valloc_legenditemsp = -0.1 #Tighter than normal

	lyt.voffset_xticklabel = 7
	lyt.hoffset_yticklabel = 3

	function getticklabelstyle(notation::Symbol)
		if :ENG == notation
			TickLabelStyle()
		elseif :SI == notation
			TickLabelStyle(NumericIO.UEXPONENT_SI)
		else
			@warn("Unsupported tick label style: :$notation")
		end
	end
	lyt.format_xtick = getticklabelstyle(notation_x)
	lyt.format_ytick = getticklabelstyle(notation_y)

	lyt.frame_data = AreaAttributes(
		line=InspectDR.line(style=:solid, color=COLOR_BLACK, width=2)
	)
	lyt.frame_colorscale = AreaAttributes(
		line=InspectDR.line(style=:solid, color=COLOR_BLACK, width=2)
	)
	return _round!(autofit2font!(lyt)) #Compute offsets
end

#Default ":screen" MultiplotLayout stylesheet:
function getstyle(::Type{MultiplotLayout}, ::StyleID{:screen},
		fontscale::Float64, notation_x::Symbol, notation_y::Symbol, enable_legend::Bool
	)
	lyt = MultiplotLayout(PREDEFAULTS)

	lyt.ncolumns = 1
	lyt.font_title = Font(lyt.font_title.name, 20*fontscale, bold=true)

	lyt.valloc_plot = DEFAULT_PLOT_HEIGHT
	lyt.halloc_plot = DEFAULT_PLOT_WIDTH

	return autofit2font!(lyt) #Compute offsets
end

#":screen" stylesheet: High-level interface:
getstyle(::Type{T}, ID::StyleID{:screen}; fontscale::Real=1.0,
		notation_x::Symbol=:ENG, notation_y::Symbol=:ENG, enable_legend::Bool=true) where T =
	getstyle(T, ID, Float64(fontscale), notation_x, notation_y, enable_legend)


#":IEEE" stylesheet:
#-------------------------------------------------------------------------------
#":IEEE" PlotLayout stylesheet:
function getstyle(::Type{PlotLayout}, ::StyleID{:IEEE},
		ppi::Float64, fontscale::Float64, legend_width::Float64, #ppi: pixels per inch
		enable_legend::Bool
	)
	pt2px = ppi/DTPPOINTS_PER_INCH #WANTCONST
	lyt = PlotLayout(PREDEFAULTS)
	#=NOTE: Dimensions in Cairo backend are in pixels.
	  Must therefore convert desired dimensions in points, to pixels
	=#

	#IEEE Plot: Must ensure readable axis & tick labels
	#Yuk, mutables: Changing one font will change the other!
	fntaxis = Font(lyt.font_axislabel.name, fontscale*7*pt2px)
	fnttick = fntaxis
	fntannot = Font(lyt.font_annotation.name, fontscale*5*pt2px)
	lyt.font_title = fntaxis
	lyt.font_striplabel = fntaxis
	lyt.font_axislabel = fntaxis
	lyt.font_ticklabel = fnttick
	lyt.font_annotation = fntannot
	lyt.font_time = fntannot
	lyt.font_legend = fntannot

	lyt.halloc_legendlineseg = 10*pt2px
	lyt.valloc_legenditemsp = -0.1 #Tighter than normal
	lyt.hoffset_legendtext = 0.5 #EMs

	autofit2font!(lyt, legend_width=legend_width)

	#Re-tweak:
	em_ticklabel = lyt.font_ticklabel._size
	#No title, so only tick label:
	lyt.valloc_top = (em_ticklabel * .7) #A bit more than half
	Δyaxislabel = -2*em_ticklabel #Space for fewer digits on ticks
		lyt.halloc_left += Δyaxislabel
		lyt.hoffset_yaxislabel += Δyaxislabel

	function _scaleline(l::LineStyle, f::Float64)
		return LineStyle(l.style, l.width*f, l.color)
	end

	lyt.length_tickmajor *= pt2px
	lyt.length_tickminor *= pt2px
	lyt.line_gridmajor = _scaleline(lyt.line_gridmajor, .5*pt2px)
	lyt.line_gridminor = _scaleline(lyt.line_gridminor, .5*pt2px)
	lyt.line_smithmajor = _scaleline(lyt.line_smithmajor, .5*pt2px)
	lyt.line_smithminor = _scaleline(lyt.line_smithminor, .5*pt2px)
	lyt.frame_data.line = #Make sure we cover grid lines:
		line(style=:solid, color=COLOR_BLACK, width=lyt.line_gridmajor.width)
	lyt.frame_colorscale.line =
		line(style=:solid, color=COLOR_BLACK, width=lyt.line_gridmajor.width)
	lyt.enable_legend = enable_legend
	return _round!(lyt)
end

#":IEEE" MultiplotLayout stylesheet:
#(Write/export `Multiplot` instead of `Plot` to control full plot dimensions - not just data area)
function getstyle(::Type{MultiplotLayout}, ::StyleID{:IEEE},
		ppi::Float64, fontscale::Float64, legend_width::Float64, enable_legend::Bool
	)
	pt2px = ppi/DTPPOINTS_PER_INCH #WANTCONST
	wplot = 3.5*ppi #Inches => Pixels #WANTCONST

	lyt = MultiplotLayout(PREDEFAULTS)
	lyt.ncolumns = 1
	lyt.font_title = Font(lyt.font_title.name, 20*fontscale, bold=true)

	lyt.valloc_title = 0
	lyt.halloc_plot = wplot
	lyt.valloc_plot = wplot/MathConstants.φ #Golden ratio
	return lyt
end

#":IEEE" stylesheet: High-level interface:
getstyle(::Type{T}, ID::StyleID{:IEEE};
		ppi::Real=300, fontscale::Real=1, legend_width::Real=12, enable_legend::Bool=true) where T =
	getstyle(T, ID, Float64(ppi), Float64(fontscale), Float64(legend_width), enable_legend)


#==Preset Stylesheets: high-level interface
===============================================================================#

"""
    getstyle(::PlotLayout/::MultiplotLayout, styleid::Symbol; kwargs...)

See InspectDR/src/stylesheets.jl

TODO: Improve how this is done. Interface not clear.

# To list methods
```julia-repl
julia> methods(InspectDR.getstyle)
```
"""
getstyle(::Type{T}, styleid::Symbol; kwargs...) where T =
	getstyle(T, StyleID(styleid); kwargs...)

function setstyle!(p::Plot, styleid::Symbol; refresh::Bool=true, kwargs...)
	s = getstyle(PlotLayout, StyleID(styleid); kwargs...)
	setstyle!(p.layout, s, refresh=refresh)
end
function setstyle!(p::Multiplot, styleid::Symbol; refresh::Bool=true, kwargs...)
	s = getstyle(MultiplotLayout, StyleID(styleid); kwargs...)
	setstyle!(p.layout, s, refresh=refresh)
end

#Last line
