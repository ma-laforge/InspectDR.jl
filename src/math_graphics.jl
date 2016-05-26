#math_graphics.jl: 
#-------------------------------------------------------------------------------


#==Aliases
===============================================================================#
#Real data type used for display functionnality (low-level):
typealias DReal Float64


#==Data structures.
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


#==Constructor-like functions
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


#==Basic operations
===============================================================================#
#Compute vector norm (assumes point refers to a vector):
function vecnorm(pt::Point2D)
	return sqrt(pt.x*pt.x+pt.y*pt.y)
end

#Simple scaling - no commutativity:
Base.(:*)(s::DReal, pt::Point2D) = Point2D(s*pt.x, s*pt.y)
Base.(:*)(s::Real, pt::Point2D) = DReal(s)*pt
Base.(:+)(p1::Point2D, p2::Point2D) = Point2D(p1.x+p2.x, p1.y+p2.y)

function union(e1::PExtents2D, e2::PExtents2D)
	return PExtents2D(
		min(e1.xmin, e2.xmin),
		max(e1.xmax, e2.xmax),
		min(e1.ymin, e2.ymin),
		max(e1.ymax, e2.ymax),
	)
end

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

Base.isfinite(ext::PExtents2D) =
	isfinite(ext.xmin) && isfinite(ext.xmax) &&
	isfinite(ext.ymin) && isfinite(ext.ymax)


#==Mapping/interpolation functions
===============================================================================#

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

#Apply transform that maps a vector to the canvas (device) coordinates
#-------------------------------------------------------------------------------
function vecmap(xf::Transform2D, pt::Point2D)
	x = pt.x*xf.xs
	y = pt.y*xf.ys
	return Point2D(x, y)
end
function vecmap_rev(xf::Transform2D, pt::Point2D)
	x = pt.x/xf.xs
	y = pt.y/xf.ys
	return Point2D(x, y)
end

#Interpolate between two points.
#-------------------------------------------------------------------------------
function interpolate(p1::Point2D, p2::Point2D, x::DReal)
	m = (p2.y-p1.y) / (p2.x-p1.x)
	return m*(x-p1.x)+p1.y
end

















#Last line
