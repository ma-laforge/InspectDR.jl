#math_coordinates.jl: 
#-------------------------------------------------------------------------------

#=
map2axis
map2data
map2dev
=#

#==Types
===============================================================================#

#Tag data as being part of a given coordinate system:
immutable CoordSystem{ID}; end
typealias DeviceCoord CoordSystem{:dev}
typealias AxisCoord CoordSystem{:axis}
typealias NormCoord CoordSystem{:norm} #Normalized (ex: relative to axis-delimited viewport)
typealias DataCoord CoordSystem{:data}

#Never actually used:
#... but could simplify names of mapping functions/mitigate incorrect use.
immutable TypedCoord{CT<:CoordSystem}
	v::DReal
end
coord(s::Symbol, v::DReal) = TypedCoord{CoordSystem{s}}(v)

#Annotation coordinates can match data or be normalized to plot bounds (0 -> 1):
#NOTE: not used
typealias AnnotationCoord Union{TypedCoord{NormCoord}, TypedCoord{DataCoord}}

#Dispatchable scale:
abstract AxisScale #Note: "Scale" too generic a name

immutable LinScale{T} <: AxisScale
	tgtmajor::DReal #Targeted number of major grid lines
	tgtminor::Int   #Targeted number of minor grid lines
	(t::Type{LinScale{T}}){T}(a1, a2) = error("$t not supported")
	(::Type{LinScale{1}})(a1, a2) = new{1}(a1, a2) #Default linear
	(::Type{LinScale{:dB10}})(a1, a2) = new{:dB10}(a1, a2)
	(::Type{LinScale{:dB20}})(a1, a2) = new{:dB20}(a1, a2)
end
LinScale(t=1; tgtmajor=3.5, tgtminor=4) = LinScale{t}(tgtmajor, tgtminor)

immutable LogScale{T} <: AxisScale
	#TODO: Configure how many major/minor lines are desired?
	(t::Type{LogScale{T}}){T}() = error("$t not supported")
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
abstract NLTransform{NDIMS} #Nonlinear transform

#InputXfrm: Maps raw input data to axis coordinates:

#InputXfrm1DSpec: Generates specialized (efficient) code:
immutable InputXfrm1DSpec{T} <: NLTransform{1}
end
InputXfrm1DSpec(::LinScale{1}) = InputXfrm1DSpec{:lin}()
InputXfrm1DSpec(::LinScale{:dB10}) = InputXfrm1DSpec{:dB10}()
InputXfrm1DSpec(::LinScale{:dB20}) = InputXfrm1DSpec{:dB20}()
InputXfrm1DSpec(::LogScale{:e}) = InputXfrm1DSpec{:ln}()
InputXfrm1DSpec(::LogScale{2}) = InputXfrm1DSpec{:log2}()
InputXfrm1DSpec(::LogScale{10}) = InputXfrm1DSpec{:log10}()

immutable InputXfrm1D <: NLTransform{1} #Generates non-specialized code
	spec::InputXfrm1DSpec
end
InputXfrm1D(s::AxisScale) = InputXfrm1D(InputXfrm1DSpec(s))
immutable InputXfrm2D <: NLTransform{2} #Generates non-specialized code
	x::InputXfrm1DSpec #x-transform
	y::InputXfrm1DSpec #y-transform
end
InputXfrm2D(x::InputXfrm1D, y::InputXfrm1D) = InputXfrm2D(x.spec, y.spec)
InputXfrm2D(xs::AxisScale, ys::AxisScale) = InputXfrm2D(InputXfrm1DSpec(xs), InputXfrm1DSpec(ys))


#==Mapping/interpolation functions
===============================================================================#
#Map input data to axis coordinates:
map2axis{T<:Number}(::Type{T}, ::InputXfrm1DSpec{:lin}) = (x::T)->DReal(x)
map2axis{T<:Number}(::Type{T}, ::InputXfrm1DSpec{:dB10}) = (x::T)->(5*log10(DReal(abs2(x))))
map2axis{T<:Number}(::Type{T}, ::InputXfrm1DSpec{:dB20}) = (x::T)->(10*log10(DReal(abs2(x))))
map2axis{T<:Number}(::Type{T}, ::InputXfrm1DSpec{:ln}) =
	(x::T)->(x<0? DNaN: log(DReal(x)))
map2axis{T<:Number}(::Type{T}, ::InputXfrm1DSpec{:log2}) =
	(x::T)->(x<0? DNaN: log2(DReal(x)))
map2axis{T<:Number}(::Type{T}, ::InputXfrm1DSpec{:log10}) =
	(x::T)->(x<0? DNaN: log10(DReal(x)))
#TODO: find a way to show negative values for log10?

#Map axis coordinates to user-readable version:
axis2read{T<:Number}(::Type{T}, ::InputXfrm1DSpec) = (x::T)->DReal(x) #NOTE: lin/dB values remain as-is - for readability
axis2read{T<:Number}(::Type{T}, ::InputXfrm1DSpec{:ln}) = (x::T)->(exp(x))
axis2read{T<:Number}(::Type{T}, ::InputXfrm1DSpec{:log2}) = (x::T)->(2.0^x)
axis2read{T<:Number}(::Type{T}, ::InputXfrm1DSpec{:log10}) = (x::T)->(10.0^x)

axis2read{T<:Number}(v::T, s::InputXfrm1DSpec) = axis2read(T,s)(v) #One-off conversion


#Map Point2D:
#-------------------------------------------------------------------------------
map2axis(pt::Point2D, x::InputXfrm1DSpec, y::InputXfrm1DSpec) =
	Point2D(map2axis(DReal, x)(pt.x), map2axis(DReal, y)(pt.y))
map2axis(pt::Point2D, xf::InputXfrm2D) = map2axis(pt, xf.x, xf.y)

#Map entire data vector:
#-------------------------------------------------------------------------------
function map2axis{T<:Number}(d::Vector{T}, xf::InputXfrm1DSpec)
	#Apparently, passing functions as arguments is not efficient in Julia.
	#-->Specializing on InputXfrm1DSpec, hoping to improve efficiency on dmap:
	dmap = map2axis(T, xf)

	result = Array(DReal, length(d))
	for i in 1:length(d)
		result[i] = dmap(d[i])
	end
	return result
end
map2axis{T<:Number}(d::Vector{T}, ::InputXfrm1DSpec{:lin}) = d #Optimization: Linear scale does not need re-scaling


#Extents mapping functions, depending on axis type:
#-------------------------------------------------------------------------------
_extread2axis(t::InputXfrm1DSpec) = map2axis(DReal, t)
#User specifies desired extents in dBs (already axis coordinates):
_extread2axis(t::InputXfrm1DSpec{:dB10}) = (x::DReal)->x
_extread2axis(t::InputXfrm1DSpec{:dB20}) = (x::DReal)->x

_extaxis2read(t::InputXfrm1DSpec) = axis2read(DReal, t)
#Extents in dB remain in dBs - for readability:
_extaxis2read(t::InputXfrm1DSpec{:dB10}) = (x::DReal)->x
_extaxis2read(t::InputXfrm1DSpec{:dB20}) = (x::DReal)->x

function read2axis(ext::PExtents1D, xf::InputXfrm1D)
	emap = _extread2axis(xf.spec)
	return PExtents1D(emap(ext.min), emap(ext.max))
end
function read2axis(ext::PExtents2D, xf::InputXfrm2D)
	xmap = _extread2axis(xf.x)
	ymap = _extread2axis(xf.y)
	return PExtents2D(
		xmap(ext.xmin), xmap(ext.xmax),
		ymap(ext.ymin), ymap(ext.ymax)
	)
end

function axis2read(ext::PExtents1D, xf::InputXfrm1D)
	emap = _extaxis2read(xf.spec)
	return PExtents1D(emap(ext.min), emap(ext.max))
end
function axis2read(ext::PExtents2D, xf::InputXfrm2D)
	xmap = _extaxis2read(xf.x)
	ymap = _extaxis2read(xf.y)
	return PExtents2D(
		xmap(ext.xmin), xmap(ext.xmax),
		ymap(ext.ymin), ymap(ext.ymax)
	)
end

#Last line
