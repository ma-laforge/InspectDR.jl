#InspectDR: Base functionnality and types for Cairo layer
#-------------------------------------------------------------------------------

#Cairo.scale(destctx, 2, 1)


#==Main types
===============================================================================#

#2D plot canvas:
#TODO: is this too much? ext is not even needed...
type PCanvas2D <: PlotCanvas
	ctx::CairoContext
	ext::PExtents2D
	xf::Transform2D
end
PCanvas2D(ctx::CairoContext, ext::PExtents2D, graphbb::BoundingBox) =
	PCanvas2D(ctx, ext, Transform2D(ext, graphbb))


#==Helper functions
===============================================================================#

function _set_stylewidth(ctx::CairoContext, style::Symbol, linewidth::Float64)

	dashes = Float64[] #default (:solid)
	offset = 0

	if :none == style
		linewidth = 0 #In case
	elseif :dash == style
		dashes = Float64[4,2]
	elseif :dot == style
		dashes = Float64[1,2]
	elseif :dashdot == style
		dashes = Float64[4,2,1,2]
	elseif :solid != style
		warn("Unrecognized line style: $style")
	end

	Cairo.set_line_width(ctx, linewidth);
	Cairo.set_dash(ctx, dashes.*linewidth, offset)
end

function drawglyph_circle(ctx::CairoContext, pt::Point2D, radius::DReal)
	Cairo.arc(ctx, pt.x, pt.y, radius, 0, 2pi)
	Cairo.stroke(ctx)
end

#==Rendering
===============================================================================#

#Reset context to known state:
function _reset(ctx::CairoContext)
	Cairo.set_source(ctx, COLOR_BLACK)
	Cairo.set_line_width(ctx, 1);
	Cairo.set_dash(ctx, Float64[], 0)
end

function clear(ctx::CairoContext, bb::BoundingBox, color::Colorant=COLOR_WHITE)
	Cairo.set_source(ctx, color)
	Cairo.rectangle(ctx, bb)
	fill(ctx)
end

function _clip(ctx::CairoContext, bb::BoundingBox)
	Cairo.rectangle(ctx, bb)
	Cairo.clip(ctx)
end

function render(ctx::CairoContext, t::AbstractString, pt::Point2D,
	fontsize::Real, bold::Bool, centerv::Bool, centerh::Bool, angle::Real,
	color::Colorant)
	const fontname = "Serif" #Sans, Serif, Fantasy, Monospace
	const weight = bold? Cairo.FONT_WEIGHT_BOLD: Cairo.FONT_WEIGHT_NORMAL
	const noitalic = Cairo.FONT_SLANT_NORMAL
	Cairo.select_font_face(ctx, fontname, noitalic,	weight)
	Cairo.set_font_size(ctx, fontsize);
	t_ext = Cairo.text_extents(ctx, t);

#=
typedef struct {
	double x_bearing, y_bearing;
	double width, height;
	double x_advance, y_advance;
} cairo_text_extents_t;
=#
	if centerh
		xoff = -(t_ext[3]/2 + t_ext[1])
	end
	if centerv
		yoff = -(t_ext[4]/2 + t_ext[2])
	end

	Cairo.save(ctx) #-----

	Cairo.translate(ctx, pt.x, pt.y);
	if angle != 0 #In case is a bit faster...
		Cairo.rotate(ctx, angle*(pi/180));
	end

	Cairo.move_to(ctx, xoff, yoff);
	Cairo.set_source(ctx, color)
	Cairo.show_text(ctx, t);

	Cairo.restore(ctx) #-----
end
render(ctx::CairoContext, t::AbstractString, pt::Point2D;
	fontsize::Real=10, bold::Bool=false, centerv::Bool=false, centerh::Bool=false,
	angle::Real=0, color::Colorant=COLOR_BLACK) =
	render(ctx, t, pt, Float64(fontsize), bold, centerv, centerh, Float64(angle), color)

#bb: Main bounding box; graph: graph bounding box
function render(ctx::CairoContext, a::Annotation, bb::BoundingBox, graph::BoundingBox, lyt::Layout)
	const sztitle = Float64(16)

	xcenter = (bb.xmin+bb.xmax)/2

	#Title
	pt = Point2D(xcenter, bb.ymin+lyt.htitle/2)
	render(ctx, a.title, pt, fontsize=sztitle, bold=true, centerv=true, centerh=true)

	xcenter = (graph.xmin+graph.xmax)/2
	ycenter = (graph.ymin+graph.ymax)/2

	#X-axis
	pt = Point2D(xcenter, bb.ymax-lyt.haxlabel/2)
	render(ctx, a.xlabel, pt, fontsize=sztitle, centerv=true, centerh=true)

	#Y-axis
	pt = Point2D(bb.xmin+lyt.waxlabel/2, ycenter)
	render(ctx, a.ylabel, pt, fontsize=sztitle, centerv=true, centerh=true, angle=-90)
end

function render_graphframe(ctx::CairoContext, graph::BoundingBox)
	Cairo.set_source(ctx, COLOR_BLACK)
	Cairo.set_line_width(ctx, 2);
	Cairo.rectangle(ctx, graph)
	Cairo.stroke(ctx)
end

function render_axes(ctx::CairoContext, graph::BoundingBox, ext::PExtents2D, lyt::Layout)
	const sztick = 14
	canvas = PCanvas2D(ctx, ext, graph)
	render_graphframe(ctx, graph)

	xcenter = (graph.xmin+graph.xmax)/2
	ycenter = (graph.ymin+graph.ymax)/2

	xtick = graph.xmin - lyt.wticklabel / 2
	for vtick in [ext.ymin, ext.ymax]
		pt = ptmap(canvas.xf, Point2D(0, vtick))
		pt = Point2D(xtick, pt.y)
		tstr = @sprintf("%0.1e", vtick)
		render(ctx, tstr, pt, fontsize=sztick, centerv=true, centerh=true)
	end

	ytick = graph.ymax + lyt.hticklabel / 2
	for vtick in [ext.xmin, (ext.xmin+ext.xmax)/2, ext.xmax]
		pt = ptmap(canvas.xf, Point2D(vtick, 0))
		pt = Point2D(pt.x, ytick)
		tstr = @sprintf("%0.1e", vtick)
		render(ctx, tstr, pt, fontsize=sztick, centerv=true, centerh=true)
	end
end

function render(canvas::PCanvas2D, wfrm::DWaveformF1)
	ctx = canvas.ctx
	ds = wfrm.ds

	if length(ds) < 2
		return
	end

	Cairo.set_source(ctx, wfrm.line.color)
	_set_stylewidth(ctx, wfrm.line.style, Float64(wfrm.line.width))
	pt = ptmap(canvas.xf, ds[1])
	Cairo.move_to(ctx, pt.x, pt.y)
	for i in 2:length(ds)
		pt = ptmap(canvas.xf, ds[i])
		Cairo.line_to(ctx, pt.x, pt.y)
	end
#	set_line_join(ctx, Cairo.CAIRO_LINE_JOIN_MITER)
	Cairo.stroke(ctx)

	#Draw symbols:
	_set_stylewidth(ctx, :solid, Float64(wfrm.line.width))
	radius = Float64(3.0*wfrm.line.width)
	for i in 1:length(ds)
		pt = ptmap(canvas.xf, ds[i])
#		drawglyph_circle(ctx, pt, radius)
	end

	return
end
render(canvas::PCanvas2D, wfrmlist::Vector{DWaveformF1}) =
	map((w)->render(canvas, w), wfrmlist)


#Last line
