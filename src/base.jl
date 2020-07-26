#InspectDR: Base functionnality and types
#-------------------------------------------------------------------------------

#AnnotationArea
#TODO: Themes: Vector/Dict of PlotLayout/MultiplotLayout?


#==Abstracts
===============================================================================#
abstract type Plot end
abstract type PlotCanvas end #TODO: Does not appear useful
abstract type PlotAnnotation end


#==Plot-level structures
===============================================================================#
#=Input structures are high-level constructs describing the plot.  They will
be broken down to lower-level structures later on.
=#

struct PreDefaultsType; end #Used to construct structures BEFORE defaults are initialized
const PREDEFAULTS = PreDefaultsType()

#Specifies whether plot should apply F1 acceleration to drop points:
mutable struct PointDropMatrix
	m::Array{Bool,2} #Indices: (has_line, has_glyph)
end
droppoints(m::PointDropMatrix, has_line::Bool, has_glyph::Bool) =
	m.m[has_line+1, has_glyph+1]

#Don't want immutable like LineStyle (modified by user):
mutable struct LineAttributes <: AttributeList
	style
	width #[0, 10]
	color
end
line(;style=:solid, width=1, color=COLOR_BLACK) =
	LineAttributes(style, width, color)
LineStyle(a::LineAttributes) = LineStyle(a.style, Float64(a.width), a.color)

#"line" constructor:
#TODO: Inadequate
#eval(genexpr_attriblistbuilder(:line, LineAttributes, reqfieldcnt=0))

mutable struct AreaAttributes #<: AttributeList
	line::LineAttributes
	fillcolor::Colorant
end
AreaAttributes(;line=InspectDR.line(style=:none), fillcolor=COLOR_TRANSPARENT) =
	AreaAttributes(line, fillcolor)

mutable struct GlyphAttributes <: AttributeList #Don't use "Symbol" - name used by Julia
#==IMPORTANT:
Edge width & color taken from LineAttributes
==#
	shape #because "type" is reserved
	size #of glyph.  edge width taken from LineAttributes
	color #glyph linecolor. = nothing to match line.color
	fillcolor
end
glyph(;shape=:none, size=3, color=nothing, fillcolor=nothing) =
	GlyphAttributes(shape, size, color, fillcolor)

#"glyph" constructor:
#TODO: Inadequate
#eval(genexpr_attriblistbuilder(:glyph, GlyphAttributes, reqfieldcnt=0))

mutable struct Waveform{T}
	id::String
	ds::T
	line::LineAttributes
	glyph::GlyphAttributes
	ext::PExtents2D
	strip::UInt8 #Y-strip
	visible::Bool
end

#Input waveform:
const IWaveform = Waveform{IDataset}

#Display waveform (concrete (x, y) pair):
const DWaveform = Waveform{Vector{Point2D}}

#=TODO:
typealias DWaveformCplx Waveform{PointComplex}
to track x-values of complex data??
=#

#Input heat map data
mutable struct Heatmap{T}
	ext::PExtents2D #Extents of x/y coordinates
	zext::PExtents1D #extents of z-data
	strip::UInt8 #Y-strip
	visible::Bool
	ds::T
end

#Input heatmap:
const IHeatmap = Heatmap{IDatasetHeat}

#Display heatmap (Pick concrete colours):
#TODO: Find way to pick concrete type to optimize for speed wrt data??
const DHeatmap = Heatmap{IDatasetHeat{ARGB32}}

mutable struct Annotation
	title::String
	xlabel::String
	ylabels::Vector{String}
	timestamp::String
end
Annotation(;title="") = Annotation(title, "", [], Libc.strftime(time()))

mutable struct Font
	name::String
	_size::Float64
	bold::Bool
	color::Colorant
end
Font(name::String, _size::Real; bold::Bool=false, color=COLOR_BLACK) =
	Font(name, _size, bold, color)
Font(::PreDefaultsType) = Font(DEFAULT_FONTNAME, 10) #Construct some object
function overwrite!(f::Font; name=KEEP_PREV, _size=KEEP_PREV, bold=KEEP_PREV, color=KEEP_PREV)
	overwriteprop!(f, :name, name)
	overwriteprop!(f, :_size, _size)
	overwriteprop!(f, :bold, bold)
	overwriteprop!(f, :color, color)
	return f
end
Font(ref::Font; kwargs...) = overwrite!(deepcopy(ref); kwargs...)

mutable struct PlotLayout <: AbstractStyle #Layout/LegendLStyle
	enable_legend::Bool
	enable_colorscale::Bool
	enable_timestamp::Bool

	valloc_data::Float64 #Suggested height of data (graph) area when exporting.
	valloc_top::Float64 #Top of plot data area
	valloc_mid::Float64 #Space betwen strips
	valloc_bottom::Float64 #Bottom of plot data area
	valloc_legenditemsp::Float64 #Spacing between items (% of text height).

	halloc_data::Float64 #Suggested width of data (graph) area when exporting.
	halloc_left::Float64 #Left of data area
	halloc_right::Float64 #Right of data area - excluding legend area
	#NOTE: halloc_right needs room for axis scale (ex: ×10⁻²).
	halloc_colorscale::Float64
	halloc_colorscale_right::Float64 #Right of color scale (space for tick labels)
	halloc_legend::Float64
	halloc_legendlineseg::Float64 #length of line segment to display.

	#Offsets to center of text:
	voffset_title::Float64
	voffset_xaxislabel::Float64 #Centered
	voffset_xticklabel::Float64

	hoffset_yaxislabel::Float64 #Centered
	hoffset_yticklabel::Float64 #Used for colorscale as well
	hoffset_legendtext::Float64 #Spacing between line/symbol and label (% of M character).

	length_tickmajor::Float64
	length_tickminor::Float64

	line_gridmajor::LineStyle
	line_gridminor::LineStyle
	line_smithmajor::LineStyle
	line_smithminor::LineStyle

	font_title::Font
	font_axislabel::Font
	font_ticklabel::Font
	font_annotation::Font
	font_time::Font #Timestamp
	font_legend::Font

	format_xtick::TickLabelStyle
	format_ytick::TickLabelStyle
	format_ztick::TickLabelStyle #Color scale

	frame_canvas::AreaAttributes #Area under entire plot
	frame_data::AreaAttributes
	frame_colorscale::AreaAttributes
	frame_legend::AreaAttributes

#=TODO:
 - Legend position (left/right/...)
 - Legend autosize (auto-compute from text)
=#
end

PlotLayout(::PreDefaultsType) = PlotLayout(
	false, false, false, #enable
	0, 0, 0, 0, 0, #valloc
	0, 0, 0, 0, 0, 0, 0, #halloc
	0, 0, 0, #voffset
	0, 0, 0, #hoffset
	Float64(5), Float64(3), #length_tick*
	LineStyle(:dash, Float64(2), RGB24(.7, .7, .7)), #line_gridmajor
	LineStyle(:dash, Float64(1), RGB24(.7, .7, .7)), #line_gridminor
	LineStyle(:solid, Float64(2), COLOR_BLACK), #line_smithmajor
	LineStyle(:solid, Float64(1), RGB24(.7, .7, .7)), #line_smithminor
	Font(PREDEFAULTS),
	Font(PREDEFAULTS), Font(PREDEFAULTS),
	Font(PREDEFAULTS), Font(PREDEFAULTS),
	Font(PREDEFAULTS),
	TickLabelStyle(), TickLabelStyle(), TickLabelStyle(),
	AreaAttributes(), AreaAttributes(), AreaAttributes(), AreaAttributes()
)

const PlotStyle = StyleType{PlotLayout}

#AnnotationGroup: Allows for hierarchical groupings of PlotAnnotation:
mutable struct AnnotationGroup{T<:PlotAnnotation} <: PlotAnnotation
	elem::Vector{T}
end

mutable struct TextAnnotation <: PlotAnnotation
	text::String
	pos::Pos2DOffset
	font::Font
	angle::DReal #Degrees
	align::Symbol #tl, tc, tr, cl, cc, cr, bl, bc, br
	strip::UInt8
end
#Don't use "text"... high probability of collisions when exported...
atext(text::String; x=DNaN, y=DNaN,
	xoffset_rel=0, yoffset_rel=0, xoffset=0, yoffset=0,
	font=Font(10), angle=0, align=:bl, strip=1) =
	TextAnnotation(text,
		Pos2DOffset(Point2D(x,y), Vector2D(xoffset_rel, yoffset_rel), Vector2D(xoffset, yoffset)),
		font, angle, align, strip
	)

mutable struct HVMarker <: PlotAnnotation
	vmarker::Bool
	hmarker::Bool
	pos::Point2D
	line::LineAttributes
	strip::UInt8
end
vmarker(pos, line=InspectDR.line(); strip=0) = HVMarker(true, false, Point2D(pos, DNaN), line, strip)
hmarker(pos, line=InspectDR.line(); strip=1) = HVMarker(false, true, Point2D(DNaN, pos), line, strip)
hvmarker(pos, line=InspectDR.line(); strip=1) = HVMarker(true, true, pos, line, strip)

mutable struct PolylineAnnotation <: PlotAnnotation
	#TODO: preferable to use Point2D?
	x::Vector{DReal}
	y::Vector{DReal}
	line::LineAttributes
	fillcolor::Colorant
	closepath::Bool
	strip::UInt8
end
PolylineAnnotation(x, y; line=InspectDR.line(), fillcolor=COLOR_TRANSPARENT, closepath=true, strip=1) =
	PolylineAnnotation(x, y, line, fillcolor, closepath, strip)

#Single graph strip of a Plot2D (shared x-coord):
mutable struct GraphStrip
	yscale::AxisScale
	zscale::AxisScale #Might have log color scales in future.
	ext_data::PExtents2D #Maximum extents of data in strip (typically all finite)
	yext_full::PExtents1D #y-extents when zoomed out to "full" (NaN values: use ext_data)
	yext::PExtents1D #Current/active y-extents (typically all finite)
	zext_data::PExtents1D #Maximum z-extents of data in strip (typically all finite)
	zext_full::PExtents1D #z-extents when zoomed out to "full" (NaN values: use zext_data)
	zext::PExtents1D #Current/active z-extents (typically all finite)
	grid::PlotGrid
	colorscale::ColorScale
end
GraphStrip() = GraphStrip(AxisScale(:lin, tgtmajor=8, tgtminor=2),
	AxisScale(:lin, tgtmajor=8, tgtminor=2),
	PExtents2D(), PExtents1D(), PExtents1D(),
	PExtents1D(), PExtents1D(), PExtents1D(),
	GridRect(vmajor=true, vminor=false, hmajor=true, hminor=false),
	defaults.colorscale)

#2D plot.
mutable struct Plot2D <: Plot
	xscale::AxisScale #yscale specified in GraphStrip
	layout::PlotStyle
	annotation::Annotation

	#Plot extents (access using getextents):
	xext_data::PExtents1D #Maximum x-extents of data in strip (typically all finite)
	xext_full::PExtents1D #x-extents when zoomed out to "full" (NaN values: use xext_data)
	xext::PExtents1D #Current/active x-extents (typically all finite)

	plotbb::NullOr{BoundingBox} #User can specify where to draw on Multiplot

	strips::Vector{GraphStrip}
	data::Vector{IWaveform}
	data_heat::Vector{IHeatmap}

	#Annotation controlled directly by user (using _add interface):
	userannot::Vector{PlotAnnotation}

	#Annotation controlled by parent object (ex: GUI-controlled widgets)
	parentannot::Vector{PlotAnnotation}

	#Display data cache:
	invalid_ddata::Bool #Is cache of display data invalid?
	display_data::Vector{DWaveform} #Clipped to current extents
	display_data_heat::Vector{DHeatmap} #Clipped to current extents

	displayNaN::Bool #Costly (time) on large datasets
	pointdropmatrix::PointDropMatrix

	#Maximum # of x-pts in display:
	#TODO: move to layout?
	xres::Int
end

Plot2D(;title="") = Plot2D(AxisScale(:lin, tgtmajor=3.5, tgtminor=4),
	StyleType(defaults.plotlayout), Annotation(title=title),
	PExtents1D(), PExtents1D(), PExtents1D(),
	nothing, [GraphStrip()], [], [], [], [], true, [], [],
	false, defaults.pointdropmatrix, 1000
)

#Style info for multi-plot object:
mutable struct MultiplotLayout <: AbstractStyle
	ncolumns::Int

	valloc_title::Float64 #Title height allocation (title gets centered)
	valloc_plot::Float64 #Default height for single plot when saving multi-plot
	halloc_plot::Float64 #Default width for single plot when saving multi-plot

	font_title::Font
	frame::AreaAttributes
end
MultiplotLayout(::PreDefaultsType) = MultiplotLayout(
	1,
	0, 0, 0, #h/valloc
	Font(PREDEFAULTS),
	AreaAttributes()
)

const MultiplotStyle = StyleType{MultiplotLayout}

mutable struct Multiplot
	title::String
	subplots::Vector{Plot}
	layout::MultiplotStyle
end
#TODO: ok to deprecate titlefont=??
function Multiplot(;style::MultiplotLayout=defaults.mplotlayout, title="",
		ncolumns=USE_DFLT, valloc_plot=USE_DFLT, halloc_plot=USE_DFLT)
	layout = StyleType(style)
	layout[:ncolumns] = ncolumns
	layout[:valloc_plot] = valloc_plot
	layout[:halloc_plot] = halloc_plot
	return Multiplot(title, [], layout)
end


#==Constructor-like functions
===============================================================================#


#==Accessors
===============================================================================#
getextents(d::IWaveform) = getextents(d.ds)
getextents(d::IHeatmap) = getextents(d.ds)
getzextents(d::IHeatmap) = getextents(d.ds)
function getextents(dlist::Vector{T}, strip::Int=1) where T<:Union{IWaveform, IHeatmap}
	result = PExtents2D(xmin=-DInf, xmax=DInf, ymin=-DInf, ymax=DInf)
	for d in dlist
		if strip == d.strip
			result = union(result, d.ext)
		end
	end
	return result
end
#TODO: merge with getextents?
#TODO CODEDUP: Generate Vector and call union(::Vector) to mitigate code duplication.
function getzextents(dlist::Vector{T}, strip::Int=1) where T<:IHeatmap
	result = PExtents1D(min=-DInf, max=DInf)
	for d in dlist
		if strip == d.strip
			result = union(result, d.zext)
		end
	end
	return result
end

hasline(w::Waveform) = (w.line.style != :none)
hasglyph(w::Waveform) = isglyph(w.glyph.shape)


#==Mutators
===============================================================================#
settitle(mplot::Plot2D, title::String) =
	(mplot.annotation.title = String(title))

settitle(mplot::Multiplot, title::String) =
	(mplot.title = String(title))


#=="add" interface
===============================================================================#

function _add(mp::Multiplot, plot::Plot2D)
	push!(mp.subplots, plot)
	return plot
end
_add(mp::Multiplot, ::Type{T}) where T<:Plot = _add(mp, T())


#Set dataf1=false to overwrite optimizations for functions of 1 argument.
function _add(plot::Plot2D, x::Vector, y::Vector; id::String="", dataf1=true, strip=1, visible=true)
	if dataf1
		dataf1 = isincreasing(x) #Can we use optimizations?
	end
	ext = PExtents2D() #Don't care at the moment
	ds = IWaveform(id, IDataset{dataf1}(x, y), line(), glyph(), ext, strip, visible)
	push!(plot.data, ds)
	return ds
end

function addheatmap(plot::Plot2D, x::Vector, y::Vector, data::Array{T,2}; id::String="", strip=1, visible=true) where T<:Number
	ext = PExtents2D() #Don't care at the moment
	zext = PExtents1D() #Don't care at the moment
	ensure(isincreasing(x) && isincreasing(y),
		ArgumentError("Heatmap only supports increasing x/y coordinates"))
	ds = IHeatmap(ext, zext, strip, visible, IDatasetHeat(x, y, data))
	push!(plot.data_heat, ds)
	return ds
end

function _add(plot::Plot2D, annot::PlotAnnotation)
	push!(plot.userannot, annot)
	return annot
end

function clear_data(plot::Plot2D)
	plot.data = []
	return
end

function clear_data(mp::Multiplot)
	for plot in mp.subplots
		clear_data(plot)
	end
	return
end


#==Plot extents
===============================================================================#

function invalidate_extents(plot::Plot2D)
	#If extents are no longer valid, neither is display cache:
	plot.invalid_ddata = true
end

function invalidate_datalist(plot::Plot2D)
	plot.invalid_ddata = true
end

#Get/set functions for graph extents:
#-------------------------------------------------------------------------------
#Full extents are always merged (ext_full expected to be incomplete):
getxextents_full(plot::Plot2D) = merge(plot.xext_data, plot.xext_full)
getyextents_full(strip::GraphStrip) = merge(yvalues(strip.ext_data), strip.yext_full)
getzextents_full(strip::GraphStrip) = merge(strip.zext_data, strip.zext_full)

#Active extents:
#(Obtain values from full extents when supplied ext contains NaN fields):
#NOTE: no need for get functions.. simply access structures directly.
_setxextents(plot::Plot2D, ext::PExtents1D) =
	(plot.xext = merge(getxextents_full(plot), ext))
_setyextents(strip::GraphStrip, ext::PExtents1D) =
	(strip.yext = merge(getyextents_full(strip), ext))
_setzextents(strip::GraphStrip, ext::PExtents1D) =
	(strip.zext = merge(getzextents_full(strip), ext))

function setyextents(plot::Plot2D, ext::PExtents1D, strip::Int = 1)
	_setyextents(plot.strips[strip], ext)
	#No need to invalidate... data reduction depends on x extents
	#invalidate_extents(plot)
end
function setxextents(plot::Plot2D, ext::PExtents1D)
	_setxextents(plot, ext)
	invalidate_extents(plot)
end
function setzextents(plot::Plot2D, ext::PExtents1D, strip::Int = 1)
	_setzextents(plot.strips[strip], ext)
	#No need to invalidate... data reduction depends on x extents
	#invalidate_extents(plot)
end

#NOTE: set/get*extents_aloc functions: set/get extents in aloc coordinates
#      (stored in user-readable "axis" coordinates).
getxextents_aloc(plot::Plot2D) = axis2aloc(plot.xext, InputXfrm1D(plot.xscale))
getyextents_aloc(strip::GraphStrip) = axis2aloc(strip.yext, InputXfrm1D(strip.yscale))
getyextents_aloc(plot::Plot2D, strip::Int) = getyextents_aloc(plot.strips[strip])
getextents_aloc(plot::Plot2D, strip::Int) =
	PExtents2D(getxextents_aloc(plot), getyextents_aloc(plot.strips[strip]))

setxextents_aloc(plot::Plot2D, ext::PExtents1D) =
	setxextents(plot, aloc2axis(ext, InputXfrm1D(plot.xscale)))
setyextents_aloc(plot::Plot2D, ext::PExtents1D, strip::Int) =
	setyextents(plot, aloc2axis(ext, InputXfrm1D(plot.strips[strip].yscale)), strip)
function setextents_aloc(plot::Plot2D, ext::PExtents2D, strip::Int)
	setxextents_aloc(plot, xvalues(ext))
	setyextents_aloc(plot, yvalues(ext), strip)
end


#==Plot/graph bounding boxes
===============================================================================#

#TODO: Move aspect_square functionality to graph (not data area)
aspect_square(::PlotGrid) = false
aspect_square(::GridSmith) = true

#TODO: Deprecate this strange hack:
function grid1(plot::Plot2D)
	if length(plot.strips) > 0
		return plot.strips[1].grid
	else
		return GridRect()
	end
end


#Returns a centered bounding box with square aspect ratio.
#TODO: use in graphbounds - not databounds
function squarebounds(bb::BoundingBox)
	w = width(bb); h = height(bb)
	xmin = bb.xmin; xmax = bb.xmax
	ymin = bb.ymin; ymax = bb.ymax
	if w < h
		hdim = w / 2
		c = (ymin + ymax) / 2
		ymin = c - hdim; ymax = c + hdim
	else
		hdim = h / 2
		c = (xmin + xmax) / 2
		xmin = c - hdim; xmax = c + hdim
	end
	return BoundingBox(xmin, xmax, ymin, ymax)
end

#Get bounding box of plot data area:
#(Complement function to plotbounds)
function databounds(plotb::BoundingBox, lyt::PlotLayout)
	xmin = plotb.xmin + lyt.halloc_left
	xmax = plotb.xmax

	#TODO: always keep halloc_right?????
	if lyt.enable_colorscale
		xmax -= lyt.halloc_right + lyt.halloc_colorscale +
			lyt.halloc_colorscale_right
	end
	if lyt.enable_legend
		xmax -= lyt.halloc_legend #Don't add halloc_right
	end
	if !lyt.enable_legend && !lyt.enable_colorscale
		xmax -= lyt.halloc_right
	end
	ymin = plotb.ymin + lyt.valloc_top
	ymax = plotb.ymax - lyt.valloc_bottom

	#Avoid division by zero, inversions, ...
	if xmin >= xmax
		c = (xmin + xmax)/2
		xmin = c - 0.5
		xmax = c + 0.5
	end
	if ymin >= ymax
		c = (ymin + ymax)/2
		ymin = c - 0.5
		ymax = c + 0.5
	end

	return BoundingBox(xmin, xmax, ymin, ymax)
end

#TODO: Move aspect_square to graphbounds.
function databounds(plotb::BoundingBox, lyt::PlotLayout, grid::PlotGrid)
	graphbb = databounds(plotb, lyt)
	if aspect_square(grid)
		graphbb = squarebounds(graphbb)
	end
	return graphbb
end

#Compute graph height (given n strips)
#TODO: Causes graphs to start/end on fractional pixels... behaves poorly.
#TODO: Latch to integer pixel boundaries.
function graph_h(datab::BoundingBox, gap::Float64, nstrips::Int)
	h = height(datab)
	if nstrips > 1
		h = (h - gap*(nstrips-1)) / nstrips
	end
	return max(h, 0)
end

#Get bounding box of graph "istrip":
function _graphbounds(datab::BoundingBox, h::Float64, pitch::Float64, istrip::Int)
	ymin = datab.ymin + pitch*(istrip-1)
	ymax = ymin + h
	return BoundingBox(datab.xmin, datab.xmax, ymin, ymax)
end

function graphbounds(datab::BoundingBox, lyt::PlotLayout, nstrips::Int, istrip::Int)
	gap = lyt.valloc_mid
	h = graph_h(datab, gap, nstrips)
	return _graphbounds(datab, h, h+gap, istrip)
end

#Get vector of graphbounds:
function graphbounds_list(datab::BoundingBox, lyt::PlotLayout, nstrips::Int)
	result = Vector{BoundingBox}(undef, nstrips)
	gap = lyt.valloc_mid
	h = graph_h(datab, gap, nstrips)
	pitch = h+gap

	for i in 1:nstrips
		result[i] = _graphbounds(datab, h, pitch, i)
	end
	return result
end

#Get bounding box of entire plot:
#(Complement function to databounds)
function plotbounds(lyt::PlotLayout, graphbb::BoundingBox)
	xmin = graphbb.xmin - lyt.halloc_left
	xmax = graphbb.xmax
	if lyt.enable_colorscale
		xmax += lyt.halloc_right + lyt.halloc_colorscale +
			lyt.halloc_colorscale_right
	end
	if lyt.enable_legend
		xmax += lyt.halloc_legend #Don't add halloc_right
	end
	if !lyt.enable_legend && !lyt.enable_colorscale
		xmax += lyt.halloc_right
	end
	ymin = graphbb.ymin - lyt.valloc_top
	ymax = graphbb.ymax + lyt.valloc_bottom
	return BoundingBox(xmin, xmax, ymin, ymax)
end

function plotbounds(lyt::PlotLayout, graphw::Float64, graphh::Float64)
	bb = plotbounds(lyt, BoundingBox(0, graphw, 0, graphh))
	return BoundingBox(0, width(bb), 0, height(bb))
end

#Get suggested plot bounds:
function plotbounds(lyt::PlotLayout, grid::PlotGrid)
	graphw = lyt.halloc_data; graphh = lyt.valloc_data
	if aspect_square(grid)
		graphw = graphh = min(graphw, graphh)
	end
	return plotbounds(lyt, graphw, graphh)
end

#Grid dimensions using Multiplot auto layout
function griddims_auto(mplot::Multiplot)
	nplots = length(mplot.subplots)
	ncols = mplot.layout.values.ncolumns
	nrows = div(nplots-1, ncols) + 1
	return (nrows, ncols)
end

#Computes suggested canvas size for a Multiplot object
function size_auto(mplot::Multiplot)
	#TODO: Compute more accurate size from Plot2D.plotbb
	nrows, ncols = griddims_auto(mplot)
	yoffset = mplot.layout.values.valloc_title
	w = Float64(mplot.layout.values.halloc_plot*ncols)
	h = Float64(mplot.layout.values.valloc_plot*nrows+yoffset)
	return (w, h)
end


#==Pre-processing display data
===============================================================================#

function _reduce(input::IWaveform, xext::PExtents1D, pdm::PointDropMatrix, xres_max::Integer)
	ds = droppoints(pdm, hasline(input), hasglyph(input)) ?
		_reduce(input.ds, xext, xres_max) : _reduce_nodrop(input.ds, xext, xres_max)

	return DWaveform(input.id, ds, input.line, input.glyph, input.ext, input.strip, input.visible)
end

_reduce(inputlist::Vector{IWaveform}, xext::PExtents1D, pdm::PointDropMatrix, xres_max::Integer) =
	map((input)->_reduce(input, xext, pdm, xres_max), inputlist)

function update_displaydata(plot::Plot2D, inputlist::Vector{IWaveform})
	xext = getxextents_aloc(plot) #Read back extents, in transformed coordinates
	plot.display_data = _reduce(inputlist, xext, plot.pointdropmatrix, plot.xres)
end

#TODO: Find data reduction method??
function gen_displaydata(input::IHeatmap, xflist::Vector{Transform1DToARGB})
	colorxf = xflist[input.strip]
	ds = IDatasetHeat(input.ds.x, input.ds.y, apply(colorxf, input.ds.data))

	return DHeatmap(input.ext, input.zext, input.strip, input.visible, ds)
end

function update_displaydata(plot::Plot2D, inputlist::Vector{IHeatmap})
	nstrips = length(plot.strips) #WANTCONST
	xflist = Vector{Transform1DToARGB}(undef, nstrips)

	#Build color map transform for each strip:
	for i in 1:nstrips
		strip = plot.strips[i]
		ext = strip.zext
		xflist[i] = Transform1DToARGB(strip.colorscale, vmin=ext.min, vmax=ext.max)
	end
	plot.display_data_heat = map((input)->gen_displaydata(input, xflist), inputlist)
end


#Rescale input dataset:
#-------------------------------------------------------------------------------

data2aloc(input::T, x::InputXfrm1DSpec, y::InputXfrm1DSpec) where T<:IDataset =
	T(data2aloc(input.x, x), data2aloc(input.y, y))

data2aloc(input::T, x::InputXfrm1DSpec, y::InputXfrm1DSpec, z::InputXfrm1DSpec) where T<:IDatasetHeat =
	T(data2aloc(input.x, x), data2aloc(input.y, y), data2aloc(input.data, z))

function data2aloc(input::IWaveform, x::InputXfrm1DSpec, y::InputXfrm1DSpec)
	ds = data2aloc(input.ds, x, y)
	return IWaveform(input.id, ds, input.line, input.glyph, getextents(ds), input.strip, input.visible)
end

function data2aloc(input::IHeatmap, x::InputXfrm1DSpec, y::InputXfrm1DSpec, z::InputXfrm1DSpec)
	ds = data2aloc(input.ds, x, y, z)
	return IHeatmap(getextents(ds), getzextents(ds), input.strip, input.visible, ds)
end

function data2aloc(inputlist::Vector{IWaveform}, xflist::Vector{InputXfrm2D})
	n = length(inputlist) #WANTCONST
	nstrips = length(xflist) #WANTCONST
	emptyds = IDataset{true}([], []) #WANTCONST
	result = Vector{IWaveform}()

	for i in 1:n
		input = inputlist[i]
		if !input.visible; continue; end #Don't process non-visible waveforms
		strip = input.strip
		if strip > 0 && strip <= nstrips
			wfrm = data2aloc(input, xflist[strip].x, xflist[strip].y)
		else #No scale for this strip... return empty waveform (still want legend??)
			wfrm = IWaveform(input.id, emptyds, input.line, input.glyph, PExtents2D(), strip, input.visible)
		end
		push!(result, wfrm)
	end
	return result
end

function data2aloc(inputlist::Vector{IHeatmap}, xflist::Vector{InputXfrm2D}, zxflist::Vector{InputXfrm1D})
	n = length(inputlist) #WANTCONST
	nstrips = length(xflist) #WANTCONST
	emptyds = IDatasetHeat(DReal[], DReal[], Array{DReal}(undef, 0,0)) #WANTCONST
	result = Vector{IHeatmap}()

	for i in 1:n
		input = inputlist[i]
		if !input.visible; continue; end #Don't process non-visible waveforms
		strip = input.strip
		if strip > 0 && strip <= nstrips
			wfrm = data2aloc(input, xflist[strip].x, xflist[strip].y, zxflist[strip].spec)
		else #No scale for this strip... return empty waveform
			wfrm = IHeatmap(PExtents2D(), strip, input.visible, emptyds)
		end
		push!(result, wfrm)
	end
	return result
end

#Preprocess input dataset (rescale/reduce quantity of data/...):
#-------------------------------------------------------------------------------
#   (Updates display_data)
function preprocess_data(plot::Plot2D)
	#TODO: Find a way to preprocess x-vectors referencing same data only once?
	nstrips = length(plot.strips) #WANTCONST

	#Figure out required input data tranform for each strip:
	xflist = Vector{InputXfrm2D}(undef, nstrips)
	zxflist = Vector{InputXfrm1D}(undef, nstrips) #For heatmaps

	for i in 1:nstrips
		strip = plot.strips[i]

		#Need to take grid into account:
		xflist[i] = InputXfrm2D(plot.xscale, strip.yscale, strip.grid)
		#NOTE: With Smith Charts: Transform does (x,y) <= (re(y), im(y)) instead.
		zxflist[i] = InputXfrm1D(strip.zscale)
	end

	#Rescale data
	#NOTE: data extents are auto calculated here.
	#TODO: Auto-calculate when added, and add an explicit function to update??
	wfrmlist = data2aloc(plot.data, xflist)
	heatmaplist = data2aloc(plot.data_heat, xflist, zxflist)

	for i in 1:nstrips
		strip = plot.strips[i]
		xf = InputXfrm2D(plot.xscale, strip.yscale)

		#Update maximum x/y-extents of data (from all waveforms):
		ext_data = getextents(wfrmlist, i)
		ext_dataheat = getextents(heatmaplist, i)
		strip.ext_data = aloc2axis(union(ext_data, ext_dataheat), xf)
		#Update y-extents, resolving any NaN fields:
		_setyextents(strip, strip.yext)

		#Update maximum z-extents of data (from all heatmaps):
		zext_data = getzextents(heatmaplist, i)
		strip.zext = zext_data
		#Update z-extents, resolving any NaN fields:
		_setzextents(strip, strip.zext)
	end

	#Extract maximum xextents from all strips (calculated in above loop):
	plot.xext_data = union([xvalues(strip.ext_data) for strip in plot.strips])
	#Update x-extents, resolving any NaN fields:
	_setxextents(plot, plot.xext)

	#Update final display data:
	update_displaydata(plot, wfrmlist)
	update_displaydata(plot, heatmaplist)
	plot.invalid_ddata = false

	#NOTE: Rescaling before data reduction is somewhat inefficient, but makes
	#      it easier to interpolate data in _reduce step.
	#TODO: Find a way to efficiently reduce before re-scaling???
end


#==High-level display functions
===============================================================================#
function update_ddata(plot::Plot2D)
	invalidate_extents(plot) #Always refresh data
	#TODO: Conditionnaly compute (only when data changed/added)?

	refreshed = plot.invalid_ddata #Indicates if fn refreshed data
	if refreshed
		preprocess_data(plot)
	end
	return refreshed
end

#Last line
