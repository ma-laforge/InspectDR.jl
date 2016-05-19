#InspectDR: Base functionnality and types
#-------------------------------------------------------------------------------

#AnnotationArea
#TODO: Themes: Define StyleInfo/style?
#TODO: Themes: Vector/Dict of StyleInfo/Layout?

#==Abstracts
===============================================================================#
abstract Plot
abstract PlotCanvas


#==Aliases
===============================================================================#
typealias NullOr{T} Union{Void, T}

#Real data type used for display functionnality (low-level):
typealias DReal Float64


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


#==Low-level data structures.
===============================================================================#

#TODO: Use library version?
abstract Point #So we can use as a function
immutable Point2D <: Point
	x::DReal
	y::DReal
end

#Could use BoundingBox, but cannot control type (and is technically not a BB).
immutable PExtents2D
	xmin::DReal
	xmax::DReal
	ymin::DReal
	ymax::DReal
end
PExtents2D(;xmin::Real=DNaN, xmax::Real=DNaN, ymin::Real=DNaN, ymax::Real=DNaN) =
	PExtents2D(xmin, xmax, ymin, ymax)

#Transform used for Canvas2D/CanvasF1 (only scale/offset - no rotation).
#xd = (xs + x0) * xu
#yd = (ys + y0) * yu
#where: xu/yu: user coordinates & xd/yd: device coordinates
#NOTE: Format used instead of xs*xu + x0 for improved numeric stability?
#TODO: Does immutable cause copy on function calls instead of using pointers??
immutable Transform2D
	xs::DReal
	x0::DReal
	ys::DReal
	y0::DReal
end


#==Plot-level structures
===============================================================================#
#=Input structures are high-level constructs describing the plot.  They will
be broken down to lower-level structures later on.
=#

#Input dataset data:
#TODO: make x an immutable (read-only) type so data cannot be changed once identified.
type IDataset{DATAF1} #DATAF1::Bool: Data is function of 1 argument (optimization possible)
	x::Vector
	y::Vector
end

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

type GlyphAttributes <: AttributeList #Don't use "Symbol" - name used by Julia
#==IMPORTANT:
Edge width & color taken from LineAttributes
==#
	shape #because "type" is reserved
	size #of glyph.  edge width taken from LineAttributes
	color #Fill color.  Do not set to leave unfilled.
end
glyph(;shape=:none, size=3, color=COLOR_TRANSPARENT) =
	GlyphAttributes(shape, size, color)

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
	call{T}(t::Type{AxisScale{T}}) = error("$t not supported")
	call(::Type{AxisScale{:lin}}) = new{:lin}()
	call(::Type{AxisScale{:log2}}) = new{:log2}()
	call(::Type{AxisScale{:log10}}) = new{:log10}()
	call(::Type{AxisScale{:dB10}}) = new{:dB10}()
	call(::Type{AxisScale{:dB20}}) = new{:dB20}()

	#Aliases:
	call(::Type{AxisScale{:log}}) = new{:log10}()
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
	call{T}(t::Type{AxesSmith{T}}, ref::Real) = error("$t not supported")
	call(::Type{AxesSmith{:Z}}, ref::Real) = new{:Z}(ref)
	call(::Type{AxesSmith{:Y}}, ref::Real) = new{:Y}(ref)
end
AxesSmith(t::Symbol; ref::Real=50) = AxesSmith{t}(ref)
AxesSmith(t::Symbol, ref::Void) = AxesSmith(t)

type Waveform{T}
	ds::T
	line::LineAttributes
	glyph::GlyphAttributes
	ext::PExtents2D
end

#Input waveform:
typealias IWaveform Waveform{IDataset}

#Display waveform (concrete (x, y) pair):
typealias DWaveform Waveform{Vector{Point2D}}

type Annotation
	title::DisplayString
	xlabel::DisplayString
	ylabel::DisplayString
	#legend
end
Annotation() = Annotation("", "", "")

type Font
	_size::Float64
	bold::Bool
end
Font(_size::Real; bold::Bool=false) = Font(_size, bold)

#Plot layout
#TODO: Split Layout into "StyleInfo" - which includes Layout??
type Layout
	htitle::Float64 #Title allocation
	waxlabel::Float64 #Vertical axis label allocation (width)
	haxlabel::Float64 #Horizontal axis label allocation (height)
	wnolabels::Float64 #Width to use where no labels are displayed

	wticklabel::Float64 #y-axis values allocation (width)
	hticklabel::Float64 #x-axis values allocation (height)

	tframe::Float64 #Frame thickness

	wdata::Float64 #Suggested width of data (graph) area
	hdata::Float64 #Suggested height of data (graph) area

	fnttitle::Font
	fntaxlabel::Font
	fntticklabel::Font

	grid::GridAttributes
end
Layout() = Layout(20, 20, 20, 30, 60, 20, 2,
	DEFAULT_DATA_WIDTH, DEFAULT_DATA_HEIGHT,
	Font(14, bold=true), Font(14), Font(12),
	GridAttributes(true, false, true, false)
)

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

	#Display data cache:
	invalid_ddata::Bool #Is cache of display data invalid?
	display_data::Vector{DWaveform} #Clipped to current extents

	#Maximum # of x-pts in display:
	#TODO: move to layout?
	xres::Int
end

Plot2D() = Plot2D(Layout(), AxesRect(), Annotation(),
	PExtents2D(), PExtents2D(), PExtents2D(), [], true, [], 1000
)

type Multiplot
	ncolumns::Int
	subplots::Vector{Plot}
end
Multiplot(;ncolumns::Int = 1) = Multiplot(ncolumns, [])


#==More constructors
===============================================================================#
#=Inputs
 -ext: Visible plot extents
 -inputb: Bounding box of display area.
NOTE:
 -Assumes device y-coordinate increases as we descend on the screen.
=#
function Transform2D(ext::PExtents2D, inputb::BoundingBox)
	xs = (inputb.xmax-inputb.xmin) / (ext.xmax-ext.xmin)
	ys = -(inputb.ymax-inputb.ymin) / (ext.ymax-ext.ymin)
	x0 = + inputb.xmin/xs - ext.xmin
	y0 = + inputb.ymax/ys - ext.ymin

	return Transform2D(xs, x0, ys, y0)
end

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

function axes(a1::Symbol, a2::Symbol; zref = nothing)
	if :smith == a1
		return AxesSmith(a2, zref)
	elseif zref != nothing
		error("cannot set zref for axes(:$a1, :$a2)")
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

Point(ds::IDataset, i::Int) = Point2D(ds.x[i], ds.y[i])
Point(ds::Vector{Point2D}, i::Int) = ds[i]


#=="add" interface
===============================================================================#

function _add(mp::Multiplot, plot::Plot2D)
	push!(mp.subplots, plot)
	return plot
end
_add{T<:Plot}(mp::Multiplot, ::Type{T}) = _add(mp, T())


function _add(plot::Plot2D, x::Vector, y::Vector)
	dataf1 = isincreasing(x) #Can we use optimizations?
	ext = PExtents2D() #Don't care at the moment
	ds = IWaveform(IDataset{dataf1}(x, y), line(), glyph(), ext)
	push!(plot.data, ds)
	return ds
end


#==Mapping/interpolation functions
===============================================================================#

#Mapping functions, depending on axis type:
#-------------------------------------------------------------------------------
datamap{T<:Number}(::Type{T}, ::AxisScale) = (x::T)->DReal(x)
datamap{T<:Number}(::Type{T}, ::AxisScale{:dB10}) = (x::T)->(5*log10(DReal(abs2(x))))
datamap{T<:Number}(::Type{T}, ::AxisScale{:dB20}) = (x::T)->(10*log10(DReal(abs2(x))))
datamap{T<:Number}(::Type{T}, ::AxisScale{:log2}) =
	(x::T)->(x<0? DNaN: log2(DReal(x)))
datamap{T<:Number}(::Type{T}, ::AxisScale{:log10}) =
	(x::T)->(x<0? DNaN: log10(DReal(x)))
#TODO: find a way to show negative values for log10?

#Extents mapping functions, depending on axis type:
#-------------------------------------------------------------------------------
extentsmap(::AxisScale) = (x::DReal)->x #Most axis types don't need to re-map extents.
extentsmap(t::AxisScale{:log2}) = datamap(DReal, t)
extentsmap(t::AxisScale{:log10}) = datamap(DReal, t)

extentsmap_rev(::AxisScale) = (x::DReal)->x #Most axis types don't need to re-map extents.
extentsmap_rev(t::AxisScale{:log2}) = (x::DReal)->(2^x)
extentsmap_rev(t::AxisScale{:log10}) = (x::DReal)->(10^x)


#Apply transform that maps a data point to the canvas
#-------------------------------------------------------------------------------
function ptmap(xf::Transform2D, pt::Point2D)
	x = (pt.x + xf.x0)*xf.xs
	y = (pt.y + xf.y0)*xf.ys
	return Point2D(x, y)
end
function ptmap_rev(xf::Transform2D, pt::Point2D)
	x = pt.x/xf.xs - xf.x0
	y = pt.y/xf.ys - xf.y0
	return Point2D(x, y)
end

#Interpolate between two points.
#-------------------------------------------------------------------------------
function interpolate(p1::Point2D, p2::Point2D, x::DReal)
	m = (p2.y-p1.y) / (p2.x-p1.x)
	return m*(x-p1.x)+p1.y
end


#==Plot extents
===============================================================================#

#Overwrite with new extents, if defined
#-------------------------------------------------------------------------------
function Base.merge(base::PExtents2D, new::PExtents2D)
	#Pick maximum extents 
	baseifnan(bv, nv) = isnan(nv)? bv: nv
	xmin = baseifnan(base.xmin, new.xmin)
	xmax = baseifnan(base.xmax, new.xmax)
	ymin = baseifnan(base.ymin, new.ymin)
	ymax = baseifnan(base.ymax, new.ymax)
	return PExtents2D(xmin, xmax, ymin, ymax)
end

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
function setextents(plot::Plot2D, ext::PExtents2D)
	#Automatically fill-in any NaN fields, if possible:
	plot.ext = merge(getextents_full(plot), ext)
	invalidate_extents(plot)
end

#Set active plot extents using xfrm display coordinates:
setextents_xfrm(plot::Plot2D, ext::PExtents2D) =
	setextents(plot, rescale_rev(ext, plot.axes))

function setextents_full(plot::Plot2D, ext::PExtents2D)
	plot.ext_full = ext
end

Base.isfinite(ext::PExtents2D) =
	isfinite(ext.xmin) && isfinite(ext.xmax) &&
	isfinite(ext.ymin) && isfinite(ext.ymax)


#==Plot/graph bounding boxes
===============================================================================#

#Get bounding box of graph (plot data area):
function graphbounds(plotb::BoundingBox, lyt::Layout)
	xmin = plotb.xmin + lyt.waxlabel + lyt.wticklabel
	xmax = plotb.xmax - lyt.wnolabels
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

#Get bounding box of entire plot:
function plotbounds(lyt::Layout, graphw::Float64, graphh::Float64)
	xmax = graphw + lyt.waxlabel + lyt.wticklabel + lyt.wnolabels
	ymax = graphh + lyt.htitle + lyt.haxlabel + lyt.hticklabel
	return BoundingBox(0, xmax, 0, ymax)
end

#Get suggested plot bounds:
plotbounds(lyt::Layout) = plotbounds(lyt, lyt.wdata, lyt.hdata)


#==Pre-processing display data
===============================================================================#

#_reduce: Obtain reduced dataset by limiting to the extents & max resolution:
#-------------------------------------------------------------------------------
#Generic algorithm... Just transfer all data for now
#    xres_max: Max number of x-points in data window.
#TODO: clip data beyond extents.
#WARNING: not clipping might cause display issues when applying the transform
function _reduce(input::IDataset, ext::PExtents2D, xres_max::Integer)
	x = input.x; y = input.y
	n_ds = length(x) #numer of points of input dataset
	result = Array(Point2D, n_ds)
	for i in 1:n_ds
		result[i] = Point2D(x[i], y[i])
	end
	return result
end

#Optimized for functions of 1 argument:
#    xres_max: Max number of x-points in data window.
function _reduce(input::IDataset{true}, ext::PExtents2D, xres_max::Integer)
	xres = (ext.xmax - ext.xmin)/ xres_max
	const min_lookahead = 2
	const thresh_xres = (min_lookahead+1)*xres
	x = input.x; y = input.y
	n_ds = length(x) #numer of points of input dataset
	sz = min(n_ds, xres_max)+4 #Add 4 pts, just in case (TODO: fix)
	result = Array(Point2D, sz)
	n = 0 #Number of points in reduced dataset
	i = 1 #Index into input dataset

	if length(x) != length(y)
		error("x & y - vector length mismatch.")
	end

	#Discard data before visible extents:
	while i < n_ds
		if x[i] > ext.xmin; break; end
		i+=1
	end

	i = max(i-1, 1)
	lastx = x[i]
	lasty = y[i]
	n+=1
	result[n] = Point2D(lastx, lasty)
	i+=1

	while i <= n_ds
		if lastx >= ext.xmax; break; end
		xthresh = min(lastx+thresh_xres, ext.xmax)
		ilahead_start = i+min_lookahead
		ilahead = min(ilahead_start, n_ds)
		while ilahead < n_ds
			if x[ilahead] >= xthresh; break; end
			ilahead += 1
		end

		#@assert(ilahead<=nds)

		if ilahead > ilahead_start #More data than xres allows
			#TODO: make this a function??
			#"Internal limits":
			(ymin_i, ymax_i) = extrema(y[i:(ilahead-1)])
			p1 = Point2D(x[ilahead-1], y[ilahead-1])
			p2 = Point2D(x[ilahead], y[ilahead])
			nexty = interpolate(p1, p2, xthresh)

			#"External limits:
			(ymin, ymax) = minmax(lasty, nexty)

			#Add points representing "internal limits"
			#(if they exceed external):
			yint = [ymin_i, ymax_i]
			ysel = Bool[false, false]
			ysel[1] = ymin_i < ymin
			ysel[2] = ymax_i > ymax
#ysel = Bool[true, true] #Debug: add points no matter what
			curx = lastx + 1.5*xres #TODO: resize to have steps of 1xres?
#@show ilahead-i
			offset = lasty < nexty ?0 :1 #Add min or max first??
			for j in (offset+(1:2))
				idx = 1+(j&0x1)
				if !ysel[idx]; continue; end #Only add points if desired
				n+=1;
				result[n] = Point2D(curx,yint[idx])
			end
			#Done adding points

			n+=1;
			lastx = xthresh
			lasty = nexty
			result[n] = Point2D(lastx, lasty)
			i = ilahead
		else #Plot actual data points
			while i <= ilahead
				n += 1
				lastx = x[i]
				lasty = y[i]
				result[n] = Point2D(lastx, lasty)
				i += 1
			end
		end
	end

	resize!(result, n)
	return result
end

function _reduce(input::IWaveform, ext::PExtents2D, xres_max::Integer)
	return DWaveform(_reduce(input.ds, ext, xres_max), input.line, input.glyph, input.ext)
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
	return IWaveform(ds, input.line, input.glyph, getextents(ds))
end

#Specialized on xscale/yscale for efficiency:
_rescale(inputlist::Vector{IWaveform}, xscale::AxisScale, yscale::AxisScale) =
	map((input)->_rescale(input, xscale, yscale), inputlist)

_rescale(inputlist::Vector{IWaveform}, axes::AxesRect) = _rescale(inputlist, axes.xscale, axes.yscale)

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
