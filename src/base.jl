#InspectDR: Base functionnality and types
#-------------------------------------------------------------------------------

#AnnotationArea
#TODO: Themes: Define StyleInfo/style?
#TODO: Themes: Vector/Dict of StyleInfo/Layout?


#==Abstracts
===============================================================================#
abstract Plot
abstract PlotCanvas


#==Constants
===============================================================================#
const DInf = convert(DReal, Inf)
const DNaN = convert(DReal, NaN)

const COLOR_TRANSPARENT = ARGB32(0, 0, 0, 0)

const COLOR_BLACK = RGB24(0, 0, 0)
const COLOR_WHITE = RGB24(1, 1, 1)

const COLOR_RED = RGB24(1, 0, 0)
const COLOR_GREEN = RGB24(0, 1, 0)
const COLOR_BLUE = RGB24(0, 0, 1)


#==Plot-level structures
===============================================================================#
#=Input structures are high-level constructs describing the plot.  They will
be broken down to lower-level structures later on.
=#

type LineAttributes <: AttributeList
	style
	width #[0, 10]
	color
end
line(;style=:solid, width=1, color=COLOR_BLACK) =
	LineAttributes(style, width, color)

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

type GridAttributes <: AttributeList
	#Bool values
	vmajor
	vminor
	hmajor
	hminor
end
grid(;vmajor=false, vminor=false, hmajor=false, hminor=false) =
	GridAttributes(vmajor, vminor, hmajor, hminor)

#Dispatchable scale:
immutable AxisScale{T}
	(t::Type{AxisScale{T}}){T}() = error("$t not supported")
	(::Type{AxisScale{:lin}})() = new{:lin}()
	(::Type{AxisScale{:ln}})() = new{:ln}()
	(::Type{AxisScale{:log2}})() = new{:log2}()
	(::Type{AxisScale{:log10}})() = new{:log10}()
	(::Type{AxisScale{:dB10}})() = new{:dB10}()
	(::Type{AxisScale{:dB20}})() = new{:dB20}()

	#Aliases:
	(::Type{AxisScale{:log}})() = new{:log10}()
end
AxisScale(t::Symbol) = AxisScale{t}()

#Specifies configuration of axes:
abstract Axes

#Rectilinear axis (ex: normal cartesian +logarithmic, ...):
immutable AxesRect <: Axes
	xscale::AxisScale
	yscale::AxisScale
end
AxesRect(xscale::Symbol, yscale::Symbol) = AxesRect(AxisScale{xscale}(), AxisScale{yscale}())
AxesRect() = AxesRect(:lin, :lin)

#Curvilinear axes (ex: polar plots):
immutable AxesCurv <: Axes
	rscale::AxisScale #Radial scale could be 
end
AxesCurv(rscale::Symbol=:lin) = AxesCurv(AxisScale{rscale}())

immutable AxesSmith{T} <: Axes
	ref::Float64 #Y/Zref
	(t::Type{AxesSmith{T}}){T}(ref::Real) = error("$t not supported")
	(::Type{AxesSmith{:Z}})(ref::Real) = new{:Z}(ref)
	(::Type{AxesSmith{:Y}})(ref::Real) = new{:Y}(ref)
end
AxesSmith(t::Symbol, ref::Real=1) = AxesSmith{t}(ref)
AxesSmith(t::Symbol, ref::Void) = AxesSmith(t)

type Waveform{T}
	id::String
	ds::T
	line::LineAttributes
	glyph::GlyphAttributes
	ext::PExtents2D
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
	ylabel::String
	timestamp::String
end
Annotation(;title="") = Annotation(title, "", "", Libc.strftime(time()))

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
type Layout
	htitle::Float64 #Title allocation
	waxlabel::Float64 #Vertical axis label allocation (width)
	haxlabel::Float64 #Horizontal axis label allocation (height)
	wnolabels::Float64 #Width to use where no labels are displayed

	wticklabel::Float64 #y-axis values allocation (width)
	hticklabel::Float64 #x-axis values allocation (height)
	hlabeloffset::Float64
	vlabeloffset::Float64

	wdata::Float64 #Suggested width of data (graph) area
	hdata::Float64 #Suggested height of data (graph) area

	fnttitle::Font
	fntaxlabel::Font
	fntticklabel::Font
	fnttime::Font

	grid::GridAttributes
	legend::LegendLStyle
	xlabelformat::TickLabelStyle
	ylabelformat::TickLabelStyle
	frame::AreaAttributes #Area under entire plot
	framedata::AreaAttributes #Data area
	showtimestamp::Bool
end
Layout(;fontname::String=defaults.fontname, fontscale=defaults.fontscale) =
	Layout(
	20*fontscale, 20*fontscale, 20*fontscale, 45, #Title/main labels
	60*fontscale, 15*fontscale, 3, 7, #Ticks/frame
	defaults.wdata, defaults.hdata,
	Font(fontname, fontscale*14, bold=true), #Title
	Font(fontname, fontscale*14), Font(fontname, fontscale*12), #Axis/Tick labels
	Font(fontname, fontscale*8), #Time stamp
	GridAttributes(true, false, true, false),
	LegendLStyle(font=Font(fontname, fontscale*12)),
	TickLabelStyle(), TickLabelStyle(),
	AreaAttributes(),
	AreaAttributes(line=InspectDR.line(style=:solid, color=COLOR_BLACK, width=2)),
	defaults.showtimestamp
)

#Tag data as being part of a given coordinate system:
immutable CoordSystem{ID}; end
typealias DeviceCoord CoordSystem{:dev}
typealias NormCoord CoordSystem{:norm}
typealias DataCoord CoordSystem{:data}

immutable TypedCoord{CT<:CoordSystem}
	v::DReal
end
#Annotation coordinates can match data or be normalized to plot bounds (0 -> 1):
typealias AnnotationCoord Union{TypedCoord{NormCoord}, TypedCoord{DataCoord}}
coord(s::Symbol, v::DReal) = TypedCoord{CoordSystem{s}}(v)

type TextAnnotation
	text::String
	pt::Point2D #Data coordinates - set NaN to use offsets only
	xoffset::DReal #Normalized to [0,1] plot bounds
	yoffset::DReal #Normalized to [0,1] plot bounds
	font::Font
	angle::DReal #Degrees
	align::Symbol #tl, tc, tr, cl, cc, cr, bl, bc, br
end
#Don't use "text"... high probability of collisions when exported...
atext(text::String; x::Real=DNaN, y::Real=DNaN, xoffset=0, yoffset=0,
	font=Font(10), angle=0, align=:bl) =
	TextAnnotation(text, Point2D(x,y), xoffset, yoffset, font, angle, align)

type HVMarker
	vmarker::Bool #false: hmarker
	pos::DReal
	line::LineAttributes
end
vmarker(pos, line=InspectDR.line()) = HVMarker(true, pos, line)
hmarker(pos, line=InspectDR.line()) = HVMarker(false, pos, line)

type PolylineAnnotation
	#TODO: preferable to use Point2D?
	x::Vector{DReal}
	y::Vector{DReal}
	line::LineAttributes
	fillcolor::Colorant
	closepath::Bool
end
PolylineAnnotation(x, y; line=InspectDR.line(), fillcolor=COLOR_TRANSPARENT, closepath=true) =
	PolylineAnnotation(x, y, line, fillcolor, closepath)

#2D plot.
type Plot2D <: Plot
	layout::Layout
	axes::Axes
	annotation::Annotation

	#Plot extents (access using getextents):
	ext_data::PExtents2D #Maximum extents of data
	ext_full::PExtents2D #Defines "full" zoom when combined with ext_data
	ext::PExtents2D #Current/active extents

	data::Vector{IWaveform}
	markers::Vector{HVMarker}
	atext::Vector{TextAnnotation}
	apline::Vector{PolylineAnnotation}

	#Display data cache:
	invalid_ddata::Bool #Is cache of display data invalid?
	display_data::Vector{DWaveform} #Clipped to current extents

	displayNaN::Bool #Costly (time) on large datasets

	#Maximum # of x-pts in display:
	#TODO: move to layout?
	xres::Int
end

Plot2D(;title="") = Plot2D(Layout(), AxesRect(), Annotation(title=title),
	PExtents2D(), PExtents2D(), PExtents2D(), [], [], [], [], true, [], false, 1000
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
#Interface is a bit irregular, but should be easy to use...
#-------------------------------------------------------------------------------
function axes(a1::Symbol)
	if :smith == a1
		return AxesSmith(:Z)
	elseif :polar == a1
		return AxesCurv()
	else
		throw(MethodError(axes, (a1,)))
	end
end

function axes(a1::Symbol, a2::Symbol; ref = nothing)
	if :smith == a1
		return AxesSmith(a2, ref)
	elseif ref != nothing
		error("cannot set ref for axes(:$a1, :$a2)")
	end

	if :polar == a1
		return AxesCurv(a2)
	else
		return AxesRect(a1, a2)
	end
end

function axes(a1::Symbol, a2::Symbol, a3::Symbol)
	if :polar == a1
		return AxesCurv(a2, a3)
	else
		throw(MethodError(axes, (a1,a2,a3)))
	end
end


#==Accessors
===============================================================================#
_width(style::LegendLStyle) = style.width

getextents(d::IWaveform) = getextents(d.ds)
function getextents(dlist::Vector{IWaveform})
	result = PExtents2D(DNaN, DNaN, DNaN, DNaN)
	for d in dlist
		result = union(result, d.ext)
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
function _add(plot::Plot2D, x::Vector, y::Vector; id::String="", dataf1=true)
	if dataf1
		dataf1 = isincreasing(x) #Can we use optimizations?
	end
	ext = PExtents2D() #Don't care at the moment
	ds = IWaveform(id, IDataset{dataf1}(x, y), line(), glyph(), ext)
	push!(plot.data, ds)
	return ds
end

function _add(plot::Plot2D, marker::HVMarker)
	push!(plot.markers, marker)
	return marker
end

function _add(plot::Plot2D, a::TextAnnotation)
	push!(plot.atext, a)
	return a
end


#==Mapping/interpolation functions
===============================================================================#

#Mapping functions, depending on axis type:
#-------------------------------------------------------------------------------
datamap{T<:Number}(::Type{T}, ::AxisScale) = (x::T)->DReal(x)
datamap{T<:Number}(::Type{T}, ::AxisScale{:dB10}) = (x::T)->(5*log10(DReal(abs2(x))))
datamap{T<:Number}(::Type{T}, ::AxisScale{:dB20}) = (x::T)->(10*log10(DReal(abs2(x))))
datamap{T<:Number}(::Type{T}, ::AxisScale{:ln}) =
	(x::T)->(x<0? DNaN: log(DReal(x)))
datamap{T<:Number}(::Type{T}, ::AxisScale{:log2}) =
	(x::T)->(x<0? DNaN: log2(DReal(x)))
datamap{T<:Number}(::Type{T}, ::AxisScale{:log10}) =
	(x::T)->(x<0? DNaN: log10(DReal(x)))
#TODO: find a way to show negative values for log10?

datamap_rev{T<:Number}(::Type{T}, ::AxisScale) = (x::T)->DReal(x)
#NOTE: Values dBs remain in dBs for readability
datamap_rev{T<:Number}(::Type{T}, ::AxisScale{:ln}) = (x::T)->(exp(x))
datamap_rev{T<:Number}(::Type{T}, ::AxisScale{:log2}) = (x::T)->(2.0^x)
datamap_rev{T<:Number}(::Type{T}, ::AxisScale{:log10}) = (x::T)->(10.0^x)

datamap_rev{T<:Number}(v::T, s::AxisScale) = datamap_rev(T,s)(v) #One-off conversion


#Extents mapping functions, depending on axis type:
#-------------------------------------------------------------------------------
extentsmap(::AxisScale) = (x::DReal)->x #Most axis types don't need to re-map extents.
#NOTE: Extents in dBs remain extents in dBs
extentsmap(t::AxisScale{:ln}) = datamap(DReal, t)
extentsmap(t::AxisScale{:log2}) = datamap(DReal, t)
extentsmap(t::AxisScale{:log10}) = datamap(DReal, t)

extentsmap_rev(::AxisScale) = (x::DReal)->x #Most axis types don't need to re-map extents.
#NOTE: Extents in dBs remain extents in dBs
extentsmap_rev(t::AxisScale{:ln}) = datamap_rev(DReal, t)
extentsmap_rev(t::AxisScale{:log2}) = datamap_rev(DReal, t)
extentsmap_rev(t::AxisScale{:log10}) = datamap_rev(DReal, t)


#==Plot extents
===============================================================================#

function invalidate_extents(plot::Plot2D)
	#If extents are no longer valid, neither is display cache:
	plot.invalid_ddata = true
end

function invalidate_datalist(plot::Plot2D)
	plot.invalid_ddata = true
end

rescale(ext::PExtents2D, axes::Axes) = ext #Default
function rescale(ext::PExtents2D, axes::AxesRect)
	xmap = extentsmap(axes.xscale)
	ymap = extentsmap(axes.yscale)
	return PExtents2D(
		xmap(ext.xmin), xmap(ext.xmax),
		ymap(ext.ymin), ymap(ext.ymax)
	)
end
rescale_rev(ext::PExtents2D, axes::Axes) = ext #Default
function rescale_rev(ext::PExtents2D, axes::AxesRect)
	xmap = extentsmap_rev(axes.xscale)
	ymap = extentsmap_rev(axes.yscale)
	return PExtents2D(
		xmap(ext.xmin), xmap(ext.xmax),
		ymap(ext.ymin), ymap(ext.ymax)
	)
end

#Accessor:
getextents(plot::Plot2D) = plot.ext
getextents_xfrm(plot::Plot2D) = rescale(plot.ext, plot.axes)

#Full extents are always merged (ext_full expected to be incomplete):
getextents_full(plot::Plot2D) = merge(plot.ext_data, plot.ext_full)

#Set active plot extents using data coordinates:
function setextents(plot::Plot2D, ext::PExtents2D, hallowed::Bool=true, vallowed::Bool=true)
	xmin = ext.xmin; xmax = ext.xmax; ymin = ext.ymin; ymax = ext.ymax
	if !hallowed
		xmin = plot.ext.xmin
		xmax = plot.ext.xmax
	end
	if !vallowed
		ymin = plot.ext.ymin
		ymax = plot.ext.ymax
	end
	#Automatically fill-in any NaN fields, if possible:
	plot.ext = merge(getextents_full(plot), PExtents2D(xmin, xmax, ymin, ymax))
	invalidate_extents(plot)
end

#Set active plot extents using xfrm display coordinates:
setextents_xfrm(plot::Plot2D, ext::PExtents2D, hallowed::Bool=true, vallowed::Bool=true) =
	setextents(plot, rescale_rev(ext, plot.axes), hallowed, vallowed)

function setextents_full(plot::Plot2D, ext::PExtents2D)
	plot.ext_full = ext
end


#==Plot/graph bounding boxes
===============================================================================#

aspect_square(::Axes) = false
aspect_square(::AxesSmith) = true

#Returns a centered bounding box with square aspect ratio.
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

#Get bounding box of graph (plot data area):
function graphbounds(plotb::BoundingBox, lyt::Layout)
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

function graphbounds(plotb::BoundingBox, lyt::Layout, axes::Axes)
	graphbb = graphbounds(plotb, lyt)
	if aspect_square(axes)
		graphbb = squarebounds(graphbb)
	end
	return graphbb
end

#Get bounding box of entire plot:
function plotbounds(lyt::Layout, graphw::Float64, graphh::Float64)
	xmax = graphw + lyt.waxlabel + lyt.wticklabel
	xmax += lyt.legend.enabled? _width(lyt.legend): lyt.wnolabels
	ymax = graphh + lyt.htitle + lyt.haxlabel + lyt.hticklabel
	return BoundingBox(0, xmax, 0, ymax)
end

#Get suggested plot bounds:
function plotbounds(lyt::Layout, axes::Axes)
	wdata = lyt.wdata; hdata = lyt.hdata
	if aspect_square(axes)
		wdata = hdata = min(wdata, hdata)
	end
	return plotbounds(lyt, wdata, hdata)
end


#==Pre-processing display data
===============================================================================#

function _reduce(input::IWaveform, ext::PExtents2D, xres_max::Integer)
	return DWaveform(input.id, _reduce(input.ds, ext, xres_max), input.line, input.glyph, input.ext)
end

_reduce(inputlist::Vector{IWaveform}, ext::PExtents2D, xres_max::Integer) =
	map((input)->_reduce(input, ext, xres_max::Integer), inputlist)

#Rescale input dataset:
#-------------------------------------------------------------------------------
function _rescale{T<:Number}(d::Vector{T}, scale::AxisScale)
	#Apparently, passing functions as arguments is not efficient in Julia.
	#-->Specializing on AxisScale, hoping to improve efficiency on dmap:
	dmap = datamap(T, scale)

	result = Array(DReal, length(d))
	for i in 1:length(d)
		result[i] = dmap(d[i])
	end
	return result
end
_rescale{T<:Number}(d::Vector{T}, scale::AxisScale{:lin}) = d #Optimization: Linear scale does not need re-scaling
_rescale{T<:IDataset}(input::T, xscale::AxisScale, yscale::AxisScale) =
	T(_rescale(input.x, xscale), _rescale(input.y, yscale))

function _rescale(input::IWaveform, xscale::AxisScale, yscale::AxisScale)
	ds = _rescale(input.ds, xscale, yscale)
	return IWaveform(input.id, ds, input.line, input.glyph, getextents(ds))
end

#Specialized on xscale/yscale for efficiency:
_rescale(inputlist::Vector{IWaveform}, xscale::AxisScale, yscale::AxisScale) =
	map((input)->_rescale(input, xscale, yscale), inputlist)

_rescale(inputlist::Vector{IWaveform}, axes::AxesRect) = _rescale(inputlist, axes.xscale, axes.yscale)

_rescale(pt::Point2D, xscale::AxisScale, yscale::AxisScale) =
	Point2D(datamap(DReal, xscale)(pt.x), datamap(DReal, yscale)(pt.y))
_rescale(pt::Point2D, axes::AxesRect) = _rescale(pt, axes.xscale, axes.yscale)


#Preprocess input dataset (rescale/reduce quantity of data/...):
#-------------------------------------------------------------------------------
#   (Updates display_data)
function preprocess_data(plot::Plot2D)
	#TODO: Find a way to preprocess x-vectors referencing same data only once?

	#Rescale data
	wfrmlist = _rescale(plot.data, plot.axes)

	#Update extents:
	plot.ext_data = rescale_rev(getextents(wfrmlist), plot.axes) #Update max extents
	setextents(plot, plot.ext) #Update extents, resolving any NaN fields.
	ext = getextents_xfrm(plot) #Read back extents, in transformed coordinates

	#Reduce data:
	plot.display_data = _reduce(wfrmlist, ext, plot.xres)
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
