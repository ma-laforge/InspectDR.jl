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


#==Rendering text annotation
===============================================================================#
function render(canvas::PCanvas2D, a::TextAnnotation, ixf::InputXfrm2D)
	const ctx = canvas.ctx
	const graphbb = canvas.graphbb
	align = get(ALIGN_MAP, a.align, ALIGN_BOTTOM | ALIGN_LEFT)
	angle = deg2rad(a.angle)

	pt = map2axis(a.pt, ixf)
	pt = map2dev(canvas.xf, pt)
	x = pt.x; y = pt.y
	if isnan(x); x = graphbb.xmin; end
	if isnan(y); y = graphbb.ymax; end
	x += a.xoffset * width(graphbb)
	y -= a.yoffset * height(graphbb)
	render(ctx, a.text, Point2D(x,y), a.font, angle=angle, align=align)
	return
end

function render(canvas::PCanvas2D, alist::Vector{TextAnnotation}, ixf::InputXfrm2D, strip::Int)
	for a in alist
		if 0 == a.strip || a.strip == strip
			render(canvas, a, ixf)
		end
	end
	return
end


#==Rendering markers
===============================================================================#

function render(canvas::PCanvas2D, mkr::HVMarker, ixf::InputXfrm2D)
	const ctx = canvas.ctx
	const graphbb = canvas.graphbb
	if :none == mkr.line.style
		return
	end

	setlinestyle(ctx, LineStyle(mkr.line))
	pt = map2axis(Point2D(mkr.pos, mkr.pos), ixf)
	pt = map2dev(canvas.xf, pt)

	if mkr.vmarker
		drawline(ctx, Point2D(pt.x, graphbb.ymin), Point2D(pt.x, graphbb.ymax))
	else #hmarker
		drawline(ctx, Point2D(graphbb.xmin, pt.y), Point2D(graphbb.xmax, pt.y))
	end

	return
end


function render(canvas::PCanvas2D, mkrlist::Vector{HVMarker}, ixf::InputXfrm2D, strip::Int)
	for mkr in mkrlist
		if 0 == mkr.strip || mkr.strip == strip
			render(canvas, mkr, ixf)
		end
	end
	return
end


#==Rendering polyline for annotation
===============================================================================#
function render(canvas::PCanvas2D, a::PolylineAnnotation, ixf::InputXfrm2D)
	const ctx = canvas.ctx

	x = a.x; y = a.y
	setlinestyle(ctx, LineStyle(a.line))
	pt = map2dev(canvas.xf, Point2D(x[1], y[1]))
	Cairo.move_to(ctx, pt.x, pt.y)
	for i in 2:length(x)
		pt = map2dev(canvas.xf, Point2D(x[i], y[i]))
		Cairo.line_to(ctx, pt.x, pt.y)
	end
	if a.closepath
		Cairo.close_path(ctx)
		renderfill(ctx, a.fillcolor)
	end
	Cairo.stroke(ctx)

#	function xf(x, y)
#		pt = map2dev(canvas.xf, map2axis(Point2D(x,y), ixf))
#		return (x, y)
#	end
	return
end

function render(canvas::PCanvas2D, alist::Vector{PolylineAnnotation}, ixf::InputXfrm2D, strip::Int)
	for a in alist
		if 0 == a.strip || a.strip == strip
			render(canvas, a, ixf)
		end
	end
	return
end

#Last line
