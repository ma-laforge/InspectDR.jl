#InspectDR: Secondary annotation (Cairo layer)
#-------------------------------------------------------------------------------


#==Constants
===============================================================================#
const ALIGN_MAP = Dict{Symbol, CAlignment}(
	:tl => ALIGN_TOP | ALIGN_LEFT,
	:tc => ALIGN_TOP | ALIGN_HCENTER,
	:tr => ALIGN_TOP | ALIGN_RIGHT,

	:cl => ALIGN_VCENTER | ALIGN_LEFT,
	:cc => ALIGN_VCENTER | ALIGN_HCENTER,
	:cr => ALIGN_VCENTER | ALIGN_RIGHT,

	:bl => ALIGN_BOTTOM | ALIGN_LEFT,
	:bc => ALIGN_BOTTOM | ALIGN_HCENTER,
	:br => ALIGN_BOTTOM | ALIGN_RIGHT,
)


#==Accessors
===============================================================================#
skipannot(a::PlotAnnotation, rstrip::RStrip2D) =  (a.strip != rstrip.istrip && a.strip != 0)


#==Rendering text annotation
===============================================================================#
function render(ctx::CairoContext, rstrip::RStrip2D, a::TextAnnotation)
	align = get(ALIGN_MAP, a.align, ALIGN_BOTTOM | ALIGN_LEFT)
	angle = deg2rad(a.angle)
	pt = axis2dev(a.pos, rstrip.xf, rstrip.ixf, rstrip.bb)
	render(ctx, a.text, pt, a.font, angle=angle, align=align)
	return
end


#==Rendering markers
===============================================================================#

function render(ctx::CairoContext, rstrip::RStrip2D, mkr::HVMarker)
	graphbb = rstrip.bb #WANTCONST
	if :none == mkr.line.style
		return
	end

	setlinestyle(ctx, LineStyle(mkr.line))
	pt = axis2aloc(mkr.pos, rstrip.ixf)
	pt = apply(rstrip.xf, pt)

	if mkr.vmarker
		drawline(ctx, Point2D(pt.x, graphbb.ymin), Point2D(pt.x, graphbb.ymax))
	end
	if mkr.hmarker
		drawline(ctx, Point2D(graphbb.xmin, pt.y), Point2D(graphbb.xmax, pt.y))
	end

	return
end


#==Rendering polyline for annotation
===============================================================================#
function render(ctx::CairoContext, rstrip::RStrip2D, a::PolylineAnnotation)
	x = a.x; y = a.y
	setlinestyle(ctx, LineStyle(a.line))
	pt = apply(rstrip.xf, Point2D(x[1], y[1]))
	Cairo.move_to(ctx, pt.x, pt.y)
	for i in 2:length(x)
		pt = apply(rstrip.xf, Point2D(x[i], y[i]))
		Cairo.line_to(ctx, pt.x, pt.y)
	end
	if a.closepath
		Cairo.close_path(ctx)
		renderfill(ctx, a.fillcolor)
	end
	Cairo.stroke(ctx)
	return
end


#==Generic rendering algorithm for annotations
===============================================================================#

function render(ctx::CairoContext, rstrip::RStrip2D, alist::Vector{T}) where T<:PlotAnnotation
	for a in alist
		if !skipannot(a, rstrip)
			render(ctx, rstrip, a)
		end
	end
	return
end

#Last line
