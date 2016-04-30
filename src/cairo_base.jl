#InspectDR: Base functionnality and types for Cairo layer
#-------------------------------------------------------------------------------

#Cairo.scale(destctx, 2, 1)


#==Main types
===============================================================================#

#2D plot canvas; basic info:
type PCanvas2D <: PlotCanvas
	ctx::CairoContext
	bb::BoundingBox #Entire canvas
	graphbb::BoundingBox #Graph portion
	ext::PExtents2D #Extents of graph portion
	xf::Transform2D #Transform used to render data
end
PCanvas2D(ctx, bb, graphbb, ext) =
	PCanvas2D(ctx, bb, graphbb, ext, Transform2D(ext, graphbb))


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

#Draw a simple line on a CairoContext
#-------------------------------------------------------------------------------
function drawline(ctx::CairoContext, p1::Point2D, p2::Point2D)
	Cairo.move_to(ctx, p1.x, p1.y)
	Cairo.line_to(ctx, p2.x, p2.y)
	Cairo.stroke(ctx)
end

#Render text on a CairoContext
#-------------------------------------------------------------------------------
function render(ctx::CairoContext, t::AbstractString, pt::Point2D,
	fontsize::Real, bold::Bool, centerv::Bool, centerh::Bool, angle::Float64,
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
render(ctx::CairoContext, t::AbstractString, pt::Point2D, font::Font;
	centerv::Bool=false, centerh::Bool=false,	angle::Real=0, color::Colorant=COLOR_BLACK) =
	render(ctx, t, pt, font._size, font.bold, centerv, centerh, Float64(angle), color)

#Render main plot annotation (titles, axis labels, ...)
#-------------------------------------------------------------------------------
function render(canvas::PCanvas2D, a::Annotation, lyt::Layout)
	const ctx = canvas.ctx
	const bb = canvas.bb
	const graph = canvas.graphbb

	xcenter = (graph.xmin+graph.xmax)/2
	ycenter = (graph.ymin+graph.ymax)/2

	#Title
	pt = Point2D(xcenter, bb.ymin+lyt.htitle/2)
	render(ctx, a.title, pt, lyt.fnttitle, centerv=true, centerh=true)

	#X-axis
	pt = Point2D(xcenter, bb.ymax-lyt.haxlabel/2)
	render(ctx, a.xlabel, pt, lyt.fntaxlabel, centerv=true, centerh=true)

	#Y-axis
	pt = Point2D(bb.xmin+lyt.waxlabel/2, ycenter)
	render(ctx, a.ylabel, pt, lyt.fntaxlabel, centerv=true, centerh=true, angle=-90)
end

#Render frame around graph
#-------------------------------------------------------------------------------
function render_graphframe(canvas::PCanvas2D)
	const ctx = canvas.ctx
	Cairo.set_source(ctx, COLOR_BLACK)
	Cairo.set_line_width(ctx, 2);
	Cairo.rectangle(ctx, canvas.graphbb)
	Cairo.stroke(ctx)
end


#Render ticks
#-------------------------------------------------------------------------------
function render_ticks(canvas::PCanvas2D, lyt::Layout)
	const TICK_MAJOR_LEN = 5
	const TICK_MINOR_LEN = 3
	const graph = canvas.graphbb
	const ctx = canvas.ctx

	#TODO: right align tick labels

	xframe = graph.xmin
	xlabel = graph.xmin - lyt.wticklabel / 2
	yticks = ticks_linear(canvas.ext.ymin, canvas.ext.ymax, tgtmajor=8.0)
	for ytick in yticks.major
		y = ptmap(canvas.xf, Point2D(0, ytick)).y
		tstr = @sprintf("%0.1e", ytick)
		render(ctx, tstr, Point2D(xlabel, y), lyt.fntaxlabel, centerv=true, centerh=true)
		drawline(ctx, Point2D(xframe, y), Point2D(xframe+TICK_MAJOR_LEN, y))
	end
	for ytick in yticks.minor
		y = ptmap(canvas.xf, Point2D(0, ytick)).y
		drawline(ctx, Point2D(xframe, y), Point2D(xframe+TICK_MINOR_LEN, y))
	end

	yframe = graph.ymax
	ylabel = graph.ymax + lyt.hticklabel / 2
	xticks = ticks_linear(canvas.ext.xmin, canvas.ext.xmax, tgtmajor=3.5)
	for xtick in xticks.major
		x = ptmap(canvas.xf, Point2D(xtick, 0)).x
		tstr = @sprintf("%0.1e", xtick)
		render(ctx, tstr, Point2D(x, ylabel), lyt.fntaxlabel, centerv=true, centerh=true)
		drawline(ctx, Point2D(x, yframe), Point2D(x, yframe-TICK_MAJOR_LEN))
	end
	for xtick in xticks.minor
		x = ptmap(canvas.xf, Point2D(xtick, 0)).x
		drawline(ctx, Point2D(x, yframe), Point2D(x, yframe-TICK_MINOR_LEN))
	end

end

#Render axes labels, ticks, ...
#-------------------------------------------------------------------------------
function render_axes(canvas::PCanvas2D, lyt::Layout)
	render_graphframe(canvas)
	render_ticks(canvas, lyt)
end

#Render an actual waveform
#-------------------------------------------------------------------------------
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


#Render entire plot
#-------------------------------------------------------------------------------
function render(canvas::PCanvas2D, plot::Plot2D)
	#Render annotation/axes
	render(canvas, plot.annotation, plot.layout)

	#TODO: render axes first once drawing is multi-threaded.
#	render_axes(canvas, plot.layout)

	#Plot actual data
	Cairo.save(canvas.ctx)
	_clip(canvas.ctx, canvas.graphbb)
	render(canvas, plot.display_data)
	Cairo.restore(canvas.ctx)

	#Re-render axis over data:
	render_axes(canvas, plot.layout)
end

#Render entire plot within provided bounding box:
function render(ctx::CairoContext, plot::Plot2D, bb::BoundingBox)
	graphbb = graphbounds(bb, plot.layout)
	update_ddata(plot) #Also computes new extents
	canvas = PCanvas2D(ctx, bb, graphbb, getextents(plot))
	render(canvas, plot)
end

#Last line
