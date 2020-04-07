#math_coordinates.jl: 
#-------------------------------------------------------------------------------


#==Types
===============================================================================#

#Tag data as being part of a given coordinate system:
struct CoordSystem{ID}; end
const DeviceCoord = CoordSystem{:dev}
const AxisCoord = CoordSystem{:axis}
const NormCoord = CoordSystem{:norm} #Normalized (ex: relative to axis-delimited viewport)
const DataCoord = CoordSystem{:data}

#Never actually used:
#... but could simplify names of mapping functions/mitigate incorrect use.
struct TypedCoord{CT<:CoordSystem}
	v::DReal
end
coord(s::Symbol, v::DReal) = TypedCoord{CoordSystem{s}}(v)

#Annotation coordinates can match data or be normalized to plot bounds (0 -> 1):
#NOTE: not used
const AnnotationCoord = Union{TypedCoord{NormCoord}, TypedCoord{DataCoord}}

#Dispatchable scale:
abstract type AxisScale end #Note: "Scale" too generic a name

struct LinScale{T} <: AxisScale
	tgtmajor::DReal #Targeted number of major grid lines
	tgtminor::Int   #Targeted number of minor grid lines
	(t::Type{LinScale{_T}})(a1, a2) where _T = error("$t not supported")
	(::Type{LinScale{1}})(a1, a2) = new{1}(a1, a2) #Default linear
	(::Type{LinScale{:dB10}})(a1, a2) = new{:dB10}(a1, a2)
	(::Type{LinScale{:dB20}})(a1, a2) = new{:dB20}(a1, a2)
end
LinScale(t=1; tgtmajor=3.5, tgtminor=4) = LinScale{t}(tgtmajor, tgtminor)

struct LogScale{T} <: AxisScale
	#TODO: Configure how many major/minor lines are desired?
	(t::Type{LogScale{_T}})() where _T = error("$t not supported")
	(::Type{LogScale{:e}})() = new{:e}()
	(::Type{LogScale{2}})() = new{2}()
	(::Type{LogScale{10}})() = new{10}()
end
LogScale(t) = LogScale{t}()

function AxisScale(t::Symbol; kwargs...)
	if :ln == t; return LogScale(:e); end
	if :log2 == t; return LogScale(2); end
	if :log10 == t; return LogScale(10); end
	if :log == t; return LogScale(10); end #Alias
	if :lin == t; return LinScale(1; kwargs...); end
	return LinScale(t; kwargs...)
end
AxisScale() = AxisScale(:lin)


#Nonlinear transform type definitions
#-------------------------------------------------------------------------------
abstract type NLTransform{NDIMS} end #Nonlinear transform

#InputXfrm: Maps raw input data to axis coordinates:

#InputXfrm1DSpec: Generates specialized (efficient) code:
#(Identifies xf from input data -> {aloc or axis})
struct InputXfrm1DSpec{T} <: NLTransform{1}
end
InputXfrm1DSpec(::LinScale{1}) = InputXfrm1DSpec{:lin}()
InputXfrm1DSpec(::LinScale{:dB10}) = InputXfrm1DSpec{:dB10}()
InputXfrm1DSpec(::LinScale{:dB20}) = InputXfrm1DSpec{:dB20}()
InputXfrm1DSpec(::LogScale{:e}) = InputXfrm1DSpec{:ln}()
InputXfrm1DSpec(::LogScale{2}) = InputXfrm1DSpec{:log2}()
InputXfrm1DSpec(::LogScale{10}) = InputXfrm1DSpec{:log10}()

struct InputXfrm1D <: NLTransform{1} #Generates non-specialized code
	spec::InputXfrm1DSpec
end
InputXfrm1D(s::AxisScale) = InputXfrm1D(InputXfrm1DSpec(s))
struct InputXfrm2D <: NLTransform{2} #Generates non-specialized code
	x::InputXfrm1DSpec #x-transform
	y::InputXfrm1DSpec #y-transform
end
InputXfrm2D(x::InputXfrm1D, y::InputXfrm1D) = InputXfrm2D(x.spec, y.spec)
InputXfrm2D(xs::AxisScale, ys::AxisScale) = InputXfrm2D(InputXfrm1DSpec(xs), InputXfrm1DSpec(ys))

#Offsettable 2D position:
#TODO: Should reloffset exist as is?
#      Alt: v.x/y is *either* "read" or "relative" (use relx::Bool, rely::Bool)
mutable struct Pos2DOffset
	v::Point2D #Position ("Read"able coordinates) - set NaN to use offsets only
	reloffset::Vector2D #Relative offset (Normalized to [0,1] graph bounds)
	offset::Vector2D #Absolute offset (device units)
end

#==Accessors
===============================================================================#
xvalues(xf::InputXfrm2D) = InputXfrm1D(xf.x)
yvalues(xf::InputXfrm2D) = InputXfrm1D(xf.y)


#==Mapping/interpolation functions
===============================================================================#
#Map input data --> aloc coordinates:
data2aloc(::Type{T}, ::InputXfrm1DSpec{:lin}) where T<:Number = (x::T)->DReal(x)
data2aloc(::Type{T}, ::InputXfrm1DSpec{:dB10}) where T<:Number = (x::T)->(5*log10(DReal(abs2(x))))
data2aloc(::Type{T}, ::InputXfrm1DSpec{:dB20}) where T<:Number = (x::T)->(10*log10(DReal(abs2(x))))
data2aloc(::Type{T}, ::InputXfrm1DSpec{:ln}) where T<:Number =
	(x::T)->(x<0 ? DNaN : log(DReal(x)))
data2aloc(::Type{T}, ::InputXfrm1DSpec{:log2}) where T<:Number =
	(x::T)->(x<0 ? DNaN : log2(DReal(x)))
data2aloc(::Type{T}, ::InputXfrm1DSpec{:log10}) where T<:Number =
	(x::T)->(x<0 ? DNaN : log10(DReal(x)))
#TODO: find a way to show negative values for log10?

#Map aloc coord --> axis (user-readable) coord (Typically reverse of data2aloc):
aloc2axis(::Type{T}, ::InputXfrm1DSpec) where T<:Number = (x::T)->DReal(x) #NOTE: lin/dB values remain as-is - for readability
aloc2axis(::Type{T}, ::InputXfrm1DSpec{:ln}) where T<:Number = (x::T)->(exp(x))
aloc2axis(::Type{T}, ::InputXfrm1DSpec{:log2}) where T<:Number = (x::T)->(2.0^x)
aloc2axis(::Type{T}, ::InputXfrm1DSpec{:log10}) where T<:Number = (x::T)->(10.0^x)

aloc2axis(v::T, s::InputXfrm1DSpec) where T<:Number = aloc2axis(T,s)(v) #One-off conversion

#Map user-readable coord, axis --> aloc coord (Typically same as data2aloc):
axis2aloc(::Type{T}, ixf::InputXfrm1DSpec) where T<:Number = data2aloc(T, ixf)
#Exception: "Readable" coordinates match axis coordinates when in dB:
axis2aloc(::Type{T}, ::InputXfrm1DSpec{:dB10}) where T<:Number = (x::DReal)->x
axis2aloc(::Type{T}, ::InputXfrm1DSpec{:dB20}) where T<:Number = (x::DReal)->x

axis2aloc(v::T, s::InputXfrm1DSpec) where T<:Number = axis2aloc(T,s)(v) #One-off conversion


#Map Point2D:
#-------------------------------------------------------------------------------
#TODO: define one-off conversion for data2aloc to simplify following?:
data2aloc(pt::Point2D, xixf::InputXfrm1DSpec, yixf::InputXfrm1DSpec) =
	Point2D(data2aloc(DReal, xixf)(pt.x), data2aloc(DReal, yixf)(pt.y))
data2aloc(pt::Point2D, ixf::InputXfrm2D) = data2aloc(pt, ixf.x, ixf.y)
aloc2axis(pt::Point2D, xixf::InputXfrm1DSpec, yixf::InputXfrm1DSpec) =
	Point2D(aloc2axis(pt.x, xixf), aloc2axis(pt.y, yixf))
aloc2axis(pt::Point2D, ixf::InputXfrm2D) = aloc2axis(pt, ixf.x, ixf.y)
axis2aloc(pt::Point2D, xixf::InputXfrm1DSpec, yixf::InputXfrm1DSpec) =
	Point2D(axis2aloc(pt.x, xixf), axis2aloc(pt.y, yixf))
axis2aloc(pt::Point2D, ixf::InputXfrm2D) = axis2aloc(pt, ixf.x, ixf.y)


#Map entire data vector:
#-------------------------------------------------------------------------------
function data2aloc(d::Array{T}, xf::InputXfrm1DSpec) where T<:Number
	#Apparently, passing functions as arguments is not efficient in Julia.
	#-->Specializing on InputXfrm1DSpec, hoping to improve efficiency on dmap:
	dmap = data2aloc(T, xf)

	result = Array{DReal}(undef, size(d))
	for i in 1:length(d)
		result[i] = dmap(d[i])
	end
	return result
end
data2aloc(d::Array{T}, ::InputXfrm1DSpec{:lin}) where T<:Number = d #Optimization: Linear scale does not need re-scaling


#Extents mapping functions, depending on axis type:
#-------------------------------------------------------------------------------
#Shortcut - hardwire type used in extents:
_extaxis2aloc(t::InputXfrm1DSpec) = axis2aloc(DReal, t)
_extaloc2axis(t::InputXfrm1DSpec) = aloc2axis(DReal, t)

function axis2aloc(ext::PExtents1D, xf::InputXfrm1D)
	emap = _extaxis2aloc(xf.spec)
	return PExtents1D(emap(ext.min), emap(ext.max))
end
function axis2aloc(ext::PExtents2D, xf::InputXfrm2D)
	xmap = _extaxis2aloc(xf.x)
	ymap = _extaxis2aloc(xf.y)
	return PExtents2D(
		xmap(ext.xmin), xmap(ext.xmax),
		ymap(ext.ymin), ymap(ext.ymax)
	)
end

function aloc2axis(ext::PExtents1D, xf::InputXfrm1D)
	emap = _extaloc2axis(xf.spec)
	return PExtents1D(emap(ext.min), emap(ext.max))
end
function aloc2axis(ext::PExtents2D, xf::InputXfrm2D)
	xmap = _extaloc2axis(xf.x)
	ymap = _extaloc2axis(xf.y)
	return PExtents2D(
		xmap(ext.xmin), xmap(ext.xmax),
		ymap(ext.ymin), ymap(ext.ymax)
	)
end

#Pos2DOffset mapping functions:
#-------------------------------------------------------------------------------
function axis2dev(pos::Pos2DOffset, xf::Transform2D, ixf::InputXfrm2D, graphbb::BoundingBox)
	pt = axis2aloc(pos.v, ixf)
	pt = apply(xf, pt) #aloc->dev
	x = pt.x; y = pt.y
	if isnan(x); x = graphbb.xmin; end
	if isnan(y); y = graphbb.ymax; end
	x += pos.reloffset.x * width(graphbb) + pos.offset.x
	y -= pos.reloffset.y * height(graphbb) + pos.offset.y
	return Point2D(x, y)
end

#Last line
