#InspectDR: Base functionnality and types
#-------------------------------------------------------------------------------

#AnnotationArea
#TODO: Themes: Define StyleInfo/style?
#TODO: Themes: Vector/Dict of StyleInfo/Layout?


#==Abstracts
===============================================================================#
abstract Plot
abstract PlotCanvas #TODO: Does not appear useful
abstract PlotAnnotation


#==Plot-level structures
===============================================================================#
#=Input structures are high-level constructs describing the plot.  They will
be broken down to lower-level structures later on.
=#

#Don't want immutable like LineStyle (modified by user):
type LineAttributes <: AttributeList
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

type AreaAttributes #<: AttributeList
	line::LineAttributes
	fillcolor::Colorant
end
AreaAttributes(;line=InspectDR.line(style=:none), fillcolor=COLOR_TRANSPARENT) =
	AreaAttributes(line, fillcolor)

type GlyphAttributes <: AttributeList #Don't use "Symbol" - name used by Julia
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

type Waveform{T}
	id::String
	ds::T
	line::LineAttributes
	glyph::GlyphAttributes
	ext::PExtents2D
	strip::UInt8 #Y-strip
end

#Input waveform:
typealias IWaveform Waveform{IDataset}

#Display waveform (concrete (x, y) pair):
typealias DWaveform Waveform{Vector{Point2D}}

#=TODO:
typealias DWaveformCplx Waveform{PointComplex}
to track x-values of complex data??
=#

type Annotation
	title::String
	xlabel::String
	ylabels::Vector{String}
	timestamp::String
end
Annotation(;title="") = Annotation(title, "", [], Libc.strftime(time()))

type Font
	name::String
	_size::Float64
	bold::Bool
	color::Colorant
end
Font(name::String, _size::Real; bold::Bool=false, color=COLOR_BLACK) =
	Font(name, _size, bold, color)
Font(_size::Real; bold::Bool=false, color=COLOR_BLACK) =
	Font(defaults.fontname, _size, bold, color)

#Legend layout/style
type LegendLStyle
	enabled::Bool
	#autosize::Bool Auto-compute width from text.
	font::Font
	#position: left/right/...
	width::Float64
	#border::Bool
	#wborder
	vgap::Float64 #Vertical spacing between (% of text height).
	linegap::Float64 #Spacing between line and label (% of M character).
	linelength::Float64 #length of line segment to display.
	frame::AreaAttributes
end
LegendLStyle(;enabled=false, font=Font(12)) =
	LegendLStyle(enabled, font, 100.0, .25, 0.5, 20, AreaAttributes())

#Plot layout
#TODO: Split Layout into "StyleInfo" - which includes Layout??
#TODO: Sort out this w/h vs h/v confusion.
type Layout
	htitle::Float64 #Title allocation
	waxlabel::Float64 #Vertical axis label allocation (width)
	haxlabel::Float64 #Horizontal axis label allocation (height)
	wnolabels::Float64 #Width to use where no labels are displayed
	#NOTE: wnolabels needs room for axis scale (ex: ×10⁻²).
	hstripgap::Float64 #Between graph strips

	wticklabel::Float64 #y-axis values allocation (width)
	hticklabel::Float64 #x-axis values allocation (height)
	hlabeloffset::Float64
	vlabeloffset::Float64

	wdata::Float64 #Suggested width of data (graph) area
	hdata::Float64 #Suggested height of data (graph) area

	fnttitle::Font
	fntaxlabel::Font
	fntticklabel::Font
	fnttime::Font #Timestamp

	legend::LegendLStyle
	xlabelformat::TickLabelStyle
	ylabelformat::TickLabelStyle
	frame::AreaAttributes #Area under entire plot
	framedata::AreaAttributes #Data area
	showtimestamp::Bool
end
Layout(;fontname::String=defaults.fontname, fontscale=defaults.fontscale) =
	Layout(
	20*fontscale, 20*fontscale, 20*fontscale, 45*fontscale, #Title/main labels
	20*fontscale,
	60*fontscale, 15*fontscale, 3, 7, #Ticks/frame
	defaults.wdata, defaults.hdata,
	Font(fontname, fontscale*14, bold=true), #Title
	Font(fontname, fontscale*14), Font(fontname, fontscale*12), #Axis/Tick labels
	Font(fontname, fontscale*8), #Time stamp
	LegendLStyle(font=Font(fontname, fontscale*12)),
	TickLabelStyle(), TickLabelStyle(),
	AreaAttributes(),
	AreaAttributes(line=InspectDR.line(style=:solid, color=COLOR_BLACK, width=2)),
	defaults.showtimestamp
)

#AnnotationGroup: Allows for hierarchical groupings of PlotAnnotation:
type AnnotationGroup{T<:PlotAnnotation} <: PlotAnnotation
	elem::Vector{T}
end

type TextAnnotation <: PlotAnnotation
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

type HVMarker <: PlotAnnotation
	vmarker::Bool
	hmarker::Bool
	pos::Point2D
	line::LineAttributes
	strip::UInt8
end
vmarker(pos, line=InspectDR.line(); strip=0) = HVMarker(true, false, Point2D(pos, DNaN), line, strip)
hmarker(pos, line=InspectDR.line(); strip=1) = HVMarker(false, true, Point2D(DNaN, pos), line, strip)
hvmarker(pos, line=InspectDR.line(); strip=1) = HVMarker(true, true, pos, line, strip)

type PolylineAnnotation <: PlotAnnotation
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
type GraphStrip
	yscale::AxisScale
	ext_data::PExtents2D #Maximum extents of data in strip (typically all finite)
	yext_full::PExtents1D #y-extents when zoomed out to "full" (NaN values: use ext_data)
	yext::PExtents1D #Current/active y-extents (typically all finite)
	grid::PlotGrid
end
GraphStrip() = GraphStrip(AxisScale(:lin, tgtmajor=8, tgtminor=2),
	PExtents2D(), PExtents1D(), PExtents1D(),
	GridRect(vmajor=true, vminor=false, hmajor=true, hminor=false))

#2D plot.
type Plot2D <: Plot
	xscale::AxisScale
	layout::Layout
	annotation::Annotation

	#Plot extents (access using getextents):
	xext_data::PExtents1D #Maximum x-extents of data in strip (typically all finite)
	xext_full::PExtents1D #x-extents when zoomed out to "full" (NaN values: use xext_data)
	xext::PExtents1D #Current/active x-extents (typically all finite)

	plotbb::NullOr{BoundingBox} #User can specify where to draw on Multiplot

	strips::Vector{GraphStrip}
	data::Vector{IWaveform}

	#Annotation controlled directly by user (using _add interface):
	userannot::Vector{PlotAnnotation}

	#Annotation controlled by parent object
	parentannot::Vector{PlotAnnotation}

	#Display data cache:
	invalid_ddata::Bool #Is cache of display data invalid?
	display_data::Vector{DWaveform} #Clipped to current extents

	displayNaN::Bool #Costly (time) on large datasets

	#Maximum # of x-pts in display:
	#TODO: move to layout?
	xres::Int
end

Plot2D(;title="") = Plot2D(AxisScale(:lin, tgtmajor=3.5, tgtminor=4),
	Layout(), Annotation(title=title),
	PExtents1D(), PExtents1D(), PExtents1D(),
	nothing, [GraphStrip()], [], [], [], true, [], false, 1000
)

type Multiplot
	title::String

	subplots::Vector{Plot}
	ncolumns::Int

	#Default width/height of plots
	wplot::Float64
	hplot::Float64

	htitle::Float64 #Title height allocation
	fnttitle::Font

	frame::AreaAttributes
end
Multiplot(;title="", ncolumns=1, titlefont=Font(defaults.fontname, 20),
		wplot=defaults.wplot, hplot=defaults.hplot) =
	Multiplot(title, [], ncolumns, wplot, hplot, 30, titlefont, AreaAttributes())


#==Constructor-like functions
===============================================================================#

#axes function:
#TODO: deprecate axes()... left for reference
#Interface is a bit irregular, but should be easy to use...
#-------------------------------------------------------------------------------
function axes(a1::Symbol)
	if :smith == a1
		return :smith_Z
	elseif :polar == a1
		return :polar
	else
		throw(MethodError(axes, (a1,)))
	end
end

function axes(a1::Symbol, a2::Symbol; ref = nothing)
	if :smith == a1
		return Symbol("smith_$(a2)_$(ref)")
	elseif ref != nothing
		error("cannot set ref for axes(:$a1, :$a2)")
	end

	if :polar == a1
		return Symbol("polar_$(a2)")
	else
		return Symbol("rect_$(a1)_$(a2)")
	end
end

function axes(a1::Symbol, a2::Symbol, a3::Symbol)
	if :polar == a1
		return Symbol("polar_$(a2)_$(a3)")
	else
		throw(MethodError(axes, (a1,a2,a3)))
	end
end


#==Accessors
===============================================================================#
_width(style::LegendLStyle) = style.width

getextents(d::IWaveform) = getextents(d.ds)
function getextents(dlist::Vector{IWaveform}, strip::Int=1)
	result = PExtents2D(DNaN, DNaN, DNaN, DNaN)
	for d in dlist
		if strip == d.strip
			result = union(result, d.ext)
		end
	end
	return result
end


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
_add{T<:Plot}(mp::Multiplot, ::Type{T}) = _add(mp, T())


#Set dataf1=false to overwrite optimizations for functions of 1 argument.
function _add(plot::Plot2D, x::Vector, y::Vector; id::String="", dataf1=true, strip=1)
	if dataf1
		dataf1 = isincreasing(x) #Can we use optimizations?
	end
	ext = PExtents2D() #Don't care at the moment
	ds = IWaveform(id, IDataset{dataf1}(x, y), line(), glyph(), ext, strip)
	push!(plot.data, ds)
	return ds
end

function _add(plot::Plot2D, annot::PlotAnnotation)
	push!(plot.userannot, annot)
	return annot
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

#Active extents:
#(Obtain values from full extents when supplied ext contains NaN fields):
#NOTE: no need for get functions.. simply access structures directly.
_setxextents(plot::Plot2D, ext::PExtents1D) =
	(plot.xext = merge(getxextents_full(plot), ext))
_setyextents(strip::GraphStrip, ext::PExtents1D) =
	(strip.yext = merge(getyextents_full(strip), ext))

function setyextents(plot::Plot2D, ext::PExtents1D, strip::Int = 1)
	_setyextents(plot.strips[strip], ext)
	#No need to invalidate... data reduction depends on x extents
	#invalidate_extents(plot)
end
function setxextents(plot::Plot2D, ext::PExtents1D)
	_setxextents(plot, ext)
	invalidate_extents(plot)
end

#NOTE: set/get*extents_axis functions: set/get extents in axis coordinates
#      (stored in user-"read"-able coordinates).
getxextents_axis(plot::Plot2D) = read2axis(plot.xext, InputXfrm1D(plot.xscale))
getyextents_axis(strip::GraphStrip) = read2axis(strip.yext, InputXfrm1D(strip.yscale))
getyextents_axis(plot::Plot2D, strip::Int) = getyextents_axis(plot.strips[strip])
getextents_axis(plot::Plot2D, strip::Int) =
	PExtents2D(getxextents_axis(plot), getyextents_axis(plot.strips[strip]))

setxextents_axis(plot::Plot2D, ext::PExtents1D) =
	setxextents(plot, axis2read(ext, InputXfrm1D(plot.xscale)))
setyextents_axis(plot::Plot2D, ext::PExtents1D, strip::Int) =
	setyextents(plot, axis2read(ext, InputXfrm1D(plot.strips[strip].yscale)), strip)
function setextents_axis(plot::Plot2D, ext::PExtents2D, strip::Int)
	setxextents_axis(plot, xvalues(ext))
	setyextents_axis(plot, yvalues(ext), strip)
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
function databounds(plotb::BoundingBox, lyt::Layout)
	xmin = plotb.xmin + lyt.waxlabel + lyt.wticklabel
	xmax = plotb.xmax
	xmax -= lyt.legend.enabled? _width(lyt.legend): lyt.wnolabels
	ymin = plotb.ymin + lyt.htitle
	ymax = plotb.ymax - lyt.haxlabel - lyt.hticklabel

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
function databounds(plotb::BoundingBox, lyt::Layout, grid::PlotGrid)
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

#TODO: Layout->hstripgap??
function graphbounds(datab::BoundingBox, lyt::Layout, nstrips::Int, istrip::Int)
	gap = lyt.hstripgap
	h = graph_h(datab, gap, nstrips)
	return _graphbounds(datab, h, h+gap, istrip)
end

#Get vector of graphbounds:
function graphbounds_list(datab::BoundingBox, lyt::Layout, nstrips::Int)
	result = Vector{BoundingBox}(nstrips)
	gap = lyt.hstripgap
	h = graph_h(datab, gap, nstrips)
	pitch = h+gap

	for i in 1:nstrips
		result[i] = _graphbounds(datab, h, pitch, i)
	end
	return result
end

#Get bounding box of entire plot:
function plotbounds(lyt::Layout, graphbb::BoundingBox)
	xmin = graphbb.xmin - lyt.waxlabel - lyt.wticklabel
	xmax = graphbb.xmax
	xmax += lyt.legend.enabled? _width(lyt.legend): lyt.wnolabels
	ymin = graphbb.ymin - lyt.htitle
	ymax = graphbb.ymax + lyt.haxlabel + lyt.hticklabel
	return BoundingBox(xmin, xmax, ymin, ymax)
end

function plotbounds(lyt::Layout, graphw::Float64, graphh::Float64)
	bb = plotbounds(lyt, BoundingBox(0, graphw, 0, graphh))
	return BoundingBox(0, width(bb), 0, height(bb))
end

#Get suggested plot bounds:
function plotbounds(lyt::Layout, grid::PlotGrid)
	wdata = lyt.wdata; hdata = lyt.hdata
	if aspect_square(grid)
		wdata = hdata = min(wdata, hdata)
	end
	return plotbounds(lyt, wdata, hdata)
end

#Grid dimensions using Multiplot auto layout
function griddims_auto(mplot::Multiplot)
	nplots = length(mplot.subplots)
	ncols = mplot.ncolumns
	nrows = div(nplots-1, ncols) + 1
	return (nrows, ncols)
end

#Computes suggested canvas size for a Multiplot object
function size_auto(mplot::Multiplot)
	#TODO: Compute more accurate size from Plot2D.plotbb
	nrows, ncols = griddims_auto(mplot)
	yoffset = mplot.htitle
	w = Float64(mplot.wplot*ncols); h = Float64(mplot.hplot*nrows+yoffset)
	return (w, h)
end


#==Pre-processing display data
===============================================================================#

function _reduce(input::IWaveform, xext::PExtents1D, xres_max::Integer)
	return DWaveform(input.id, _reduce(input.ds, xext, xres_max), input.line, input.glyph, input.ext, input.strip)
end

_reduce(inputlist::Vector{IWaveform}, xext::PExtents1D, xres_max::Integer) =
	map((input)->_reduce(input, xext, xres_max::Integer), inputlist)

#Rescale input dataset:
#-------------------------------------------------------------------------------

map2axis{T<:IDataset}(input::T, x::InputXfrm1DSpec, y::InputXfrm1DSpec) =
	T(map2axis(input.x, x), map2axis(input.y, y))

function map2axis(input::IWaveform, x::InputXfrm1DSpec, y::InputXfrm1DSpec)
	ds = map2axis(input.ds, x, y)
	return IWaveform(input.id, ds, input.line, input.glyph, getextents(ds), input.strip)
end

function map2axis(inputlist::Vector{IWaveform}, xflist::Vector{InputXfrm2D})
	const n = length(inputlist)
	const nstrips = length(xflist)
	const emptyds = IDataset{true}([], [])
	result = Vector{IWaveform}(n)

	for i in 1:n
		input = inputlist[i]
		strip = input.strip
		if strip > 0 && strip <= nstrips
			result[i] = map2axis(input, xflist[strip].x, xflist[strip].y)
		else #No scale for this strip... return empty waveform
			result = IWaveform(input.id, emptyds, input.line, input.glyph, PExtents2D(), strip)
		end
	end
	return result
end

#Preprocess input dataset (rescale/reduce quantity of data/...):
#-------------------------------------------------------------------------------
#   (Updates display_data)
function preprocess_data(plot::Plot2D)
	#TODO: Find a way to preprocess x-vectors referencing same data only once?
	const nstrips = length(plot.strips)

	#Figure out required input data tranform for each strip:
	xflist = Vector{InputXfrm2D}(nstrips)
	for i in 1:nstrips
		strip = plot.strips[i]

		#Need to take grid into account:
		xflist[i] = InputXfrm2D(plot.xscale, strip.yscale, strip.grid)
	end

	#Rescale data
	wfrmlist = map2axis(plot.data, xflist)

	for i in 1:nstrips
		strip = plot.strips[i]
		xf = InputXfrm2D(plot.xscale, strip.yscale)

		#Update extents:
		strip.ext_data = axis2read(getextents(wfrmlist, i), xf)
		_setyextents(strip, strip.yext) #Update extents, resolving any NaN fields.
	end

	#Extract maximum xextents from all strips:
	plot.xext_data = union([xvalues(strip.ext_data) for strip in plot.strips])
	_setxextents(plot, plot.xext) #Update extents, resolving any NaN fields.

	#Reduce data:
	xext = getxextents_axis(plot) #Read back extents, in transformed coordinates
	plot.display_data = _reduce(wfrmlist, xext, plot.xres)
	plot.invalid_ddata = false

	#NOTE: Rescaling before data reduction is somewhat inefficient, but makes
	#      it easier to interpolate data in _reduce step.
	#TODO: Find a way to efficiently reduce before re-scaling???
end


#==High-level display functions
===============================================================================#
function update_ddata(plot::Plot2D)
	invalidate_extents(plot) #Always compute below:
	#TODO: Conditionnaly compute (only when data changed/added)?

	if plot.invalid_ddata
		preprocess_data(plot)
	end
end

#Last line
