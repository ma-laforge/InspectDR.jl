#InspectDR: Base functionnality and types
#-------------------------------------------------------------------------------

#AnnotationArea
#TODO: Themes: Vector/Dict of StyleInfo?


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
PExtents2D() = PExtents2D(DNaN, DNaN, DNaN, DNaN)

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
type IDataset
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

#"glyph" constructor:
eval(genexpr_attriblistbuilder(:glyph, GlyphAttributes, reqfieldcnt=0))

type Waveform{T}
	ds::T
	line::LineAttributes
	#Line/glyph attributes
#Include line/glyph attributes...
end

#Input waveform:
typealias IWaveform Waveform{IDataset}

#Display waveform for function of 1 argument:
#Concrete (x, y) pair.
typealias DWaveformF1 Waveform{Vector{Point2D}}

type Annotation
	title::AbstractString
	xlabel::AbstractString
	ylabel::AbstractString
	#legend
end
Annotation() = Annotation("", "", "")

type StyleInfo
	#Identifies width of plot margins where labels are written
	#TODO: find better names
	borderwidth::Float64

#Fontname, fontsize, ...
end
StyleInfo() = StyleInfo(20)

#2D plot.
type Plot2D <: Plot
	optimize_f1::Bool #Optimize for data: function of 1 argument

	#w/h of entire surface (labels & all)
	w::Float64
	h::Float64
	annotation::Annotation

	#Plot extents:
	ext::PExtents2D
	ext_max::PExtents2D

	style::StyleInfo

	data::Vector{IWaveform}

	xres::Int
end

Plot2D(w::Real, h::Real; optimize_f1=true) = Plot2D(optimize_f1,
	w, h, Annotation(),
	PExtents2D(), PExtents2D(),
	StyleInfo(), [], 1000
)


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
	x0 = - inputb.xmin/xs - ext.xmin
	y0 = + inputb.ymax/ys - ext.ymin

	return Transform2D(xs, x0, ys, y0)
end


#==Accessors
===============================================================================#

Point(ds::IDataset, i::Int) = Point2D(ds.x[i], ds.y[i])
Point(ds::Vector{Point2D}, i::Int) = ds[i]


#==Base functions
===============================================================================#
#=
function apply!(s::StyleInfo, l::LineAttributes)
	#ignore style for now..
	#TODO: make global:
	const COLOR_DEFAULT = RGB(0,0,0)

	if nothing == l.width; l.width = 1; end
	if nothing == l.color; l.color = COLOR_DEFAULT; end
end
function apply(s::StyleInfo, l::LineAttributes)
	result = deepcopy(l)
	return apply!(s, l)
end
=#

function _add(plot::Plot2D, x::Vector, y::Vector)
	ds = IWaveform(IDataset(x, y), line())
	push!(plot.data, ds)
	return ds
end

function ptmap(xf::Transform2D, pt::Point2D)
	x = (pt.x + xf.x0)*xf.xs
	y = (pt.y + xf.y0)*xf.ys
	return Point2D(x, y)
end

#Auto-detect extents from plot data:
#TODO: compute_maxextents? setextents_computemax
function setextents_detectmax(plot::Plot2D)
	plot.ext_max = PExtents2D(plot.data)
end

function setextents(plot::Plot2D, ext::PExtents2D)
	plot.ext = ext
end

function getextents(plot::Plot2D)
	maxifnan(v, maxv) = isnan(v)? maxv: v
	xmin = maxifnan(plot.ext.xmin, plot.ext_max.xmin)
	xmax = maxifnan(plot.ext.xmax, plot.ext_max.xmax)
	ymin = maxifnan(plot.ext.ymin, plot.ext_max.ymin)
	ymax = maxifnan(plot.ext.ymax, plot.ext_max.ymax)
	return PExtents2D(xmin, xmax, ymin, ymax)
end

#Interpolate between two points.
function interpolate(p1::Point2D, p2::Point2D, x::DReal)
	m = (p2.y-p1.y) / (p2.x-p1.x)
	return m*(x-p1.x)+p1.y
end

#Obtain reduced waveform datasets by limiting to the extents & max resolution:
#-------------------------------------------------------------------------------
function _reduce(input::IWaveform, ext::PExtents2D, xres_max::Integer)
	xres = (ext.xmax - ext.xmin)/ xres_max
	const min_lookahead = 2
	const thresh_xres = (min_lookahead+1)*xres
	x = input.ds.x; y = input.ds.y
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
	return Waveform(result, input.line)
end

_reduce(inputlist::Vector{IWaveform}, ext::PExtents2D, xres_max::Integer) =
	map((input)->_reduce(input, ext, xres_max::Integer), inputlist)


#Last line
