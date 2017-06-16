#InspectDR: Defines stylesheets & presets
#-------------------------------------------------------------------------------


#==Constants: Initial default values
===============================================================================#
#Default values for data area dimensions (used to save single plot):
const DEFAULT_DATA_WIDTH = 500.0
const DEFAULT_DATA_HEIGHT = DEFAULT_DATA_WIDTH / φ #Use golden ratio

#Default values for plot dimensions (used to save multi-plot):
const DEFAULT_PLOT_WIDTH = 600.0
const DEFAULT_PLOT_HEIGHT = DEFAULT_PLOT_WIDTH / φ #Use golden ratio


#==Types
===============================================================================#
type PlotSylesheet
	plotlayout::PlotLayout
	mplotlayout::MultiplotLayout
end


#==Useful functions
===============================================================================#
#Try to size allocations & offsets appropriately for font selections:
function autofit2font!(lyt::PlotLayout)
	#Allocations for different elements:
	h_title = lyt.font_title._size * (20/14)
	h_xaxislabel = lyt.font_axislabel._size * (20/14)
	h_xticklabel = lyt.font_ticklabel._size * (15/12)
	w_yaxislabel = lyt.font_axislabel._size * (20/14)
	w_yticklabel = lyt.font_ticklabel._size * (60/12)


	lyt.valloc_top = h_title
	lyt.valloc_mid = lyt.font_ticklabel._size * (20/12)
	lyt.valloc_bottom = h_xaxislabel + h_xticklabel

	lyt.halloc_left = w_yaxislabel + w_yticklabel
	lyt.halloc_right = lyt.font_ticklabel._size * (45/12) #Room for x10^EXP
	lyt.halloc_legend = lyt.font_legend._size * (100/12)

	lyt.voffset_title = h_title/2
	lyt.voffset_xaxislabel = h_xaxislabel/2
	lyt.hoffset_yaxislabel = w_yaxislabel/2

	return lyt
end

#Try to size allocations & offsets appropriately for font selections:
function autofit2font!(lyt::MultiplotLayout)
	lyt.valloc_title = lyt.font_title._size * (30/20)
	return lyt
end

function overwritefont!(lyt::PlotStyle; fontname=nothing, fontscale=1.0, autofit=true)
	proplist = [:font_title, :font_axislabel, :font_ticklabel, :font_annotation, :font_legend, :font_time]

	if fontname!=nothing
		for prop in proplist
			lyt[prop].name = fontname
		end
	end

	for prop in proplist
		ref = lyt[prop]
		ref._size *= fontscale
		lyt[prop] = ref #Updates layout.overwrite
	end

	if autofit
		autofit2font!(lyt.values)
	end
end


#==Default layouts
===============================================================================#
function build_default_plot_layout(fontname::String, fontscale::Float64,
		notation_x::Symbol, notation_y::Symbol)
	font = Font(fontname, 10) #default
	lyt = PlotLayout()

	lyt.enable_legend = false
	lyt.enable_timestamp = false

	lyt.font_title = Font(font, _size = 14*fontscale, bold=true)
	lyt.font_axislabel = Font(font, _size = 14*fontscale)
	lyt.font_ticklabel = Font(font, _size = 12*fontscale)
	lyt.font_annotation = Font(font, _size = 12*fontscale)
	lyt.font_time = Font(font, _size = 8*fontscale)
	lyt.font_legend = Font(font, _size = 12*fontscale)

	lyt.halloc_legendlineseg = 20
	lyt.hoffset_legendtext = 0.5
	lyt.valloc_legenditemsp = 0.25

	lyt.voffset_xticklabel = 7
	lyt.hoffset_yticklabel = 3

	function getticklabelstyle(notation::Symbol)
		if :ENG == notation
			TickLabelStyle()
		elseif :SI == notation
			TickLabelStyle(NumericIO.UEXPONENT_SI)
		else
			warn("Unsupported tick label style: :$notation")
		end
	end
	lyt.format_xtick = getticklabelstyle(notation_x)
	lyt.format_ytick = getticklabelstyle(notation_y)

	lyt.frame_data = AreaAttributes(
		line=InspectDR.line(style=:solid, color=COLOR_BLACK, width=2)
	)

	return autofit2font!(lyt) #Compute offsets
end

function build_default_multiplot_layout(fontname::String, fontscale::Float64)
	font = Font(fontname, 10) #default
	lyt = MultiplotLayout()

	lyt.ncolumns = 1
	lyt.font_title = Font(font, _size = 20*fontscale, bold=true)

	lyt.valloc_plot = DEFAULT_PLOT_HEIGHT
	lyt.halloc_plot = DEFAULT_PLOT_WIDTH

	return autofit2font!(lyt) #Compute offsets
end


#==Preset style sheets
===============================================================================#
#=
#Includes default fontname
function add_preset_stylesheets(plotsheets::Dict, multiplotsheets::Dict,
	ref_plotlayout::PlotLayout, ref_mplotlayout::MultiplotLayout)
end
=#

#Last line
