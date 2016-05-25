#InspectDR: Base functionnality and types for Cairo layer
#-------------------------------------------------------------------------------

#=TODO
-Fix glyph size for "constant area" (appearance).  Currently, algorithms use
 "constant bounding box" to avoid repeating complex math (ex: h=sqrt(a^2+b^2)).
 Solution: Create glyph object that takes Vector{Point2D} - or something
 similar.  That way, complex math is done only once per curve.
=#


#==Constants
===============================================================================#


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

immutable CGlyph{GTYPE}; end #Dispatchable glyph object
CGlyph(gtype::Symbol) = CGlyph{gtype}()


#==Basic rendering
===============================================================================#

#Reset context to known state:
function _reset(ctx::CairoContext)
	Cairo.set_source(ctx, COLOR_BLACK)
	Cairo.set_line_width(ctx, 1);
	Cairo.set_dash(ctx, Float64[], 0)
end

#Clears a rectangle-shaped area with a solid color
function clear(ctx::CairoContext, bb::BoundingBox, color::Colorant=COLOR_WHITE)
	Cairo.set_source(ctx, color)
	Cairo.rectangle(ctx, bb)
	fill(ctx)
end


#==Rendering Glyphs
===============================================================================#

function drawglyph{T}(ctx::CairoContext, ::CGlyph{T}, pt::Point2D, size::DReal)
	warn("Glyph shape not supported: $T")
end

#= Supported:
	:square, :diamond,
	:uarrow, :darrow, :larrow, :rarrow, #usually triangles
	:cross, :+, :diagcross, :x,
	:circle, :o, :star, :*,
=#

function drawglyph(ctx::CairoContext, ::CGlyph{:circle}, pt::Point2D, size::DReal)
	radius = size/2
	Cairo.arc(ctx, pt.x, pt.y, radius, 0, 2pi)
	Cairo.stroke(ctx)
end
drawglyph(ctx::CairoContext, ::CGlyph{:o}, pt::Point2D, size::DReal) =
	drawglyph(ctx, CGlyph{:circle}(), pt, size)

function drawglyph(ctx::CairoContext, ::CGlyph{:square}, pt::Point2D, size::DReal)
	elen = size #full edge length
	hlen = elen/2 #halflength
	Cairo.rectangle(ctx, pt.x-hlen, pt.y-hlen, elen, elen)
	Cairo.stroke(ctx)
end

function drawglyph(ctx::CairoContext, ::CGlyph{:cross}, pt::Point2D, size::DReal)
	elen = size*sqrt(2) #full edge length
	hlen = elen/2 #halflength
	Cairo.move_to(ctx, pt.x, pt.y-hlen)
	Cairo.rel_line_to(ctx, 0, elen)
	Cairo.stroke(ctx)
	Cairo.move_to(ctx, pt.x-hlen, pt.y)
	Cairo.rel_line_to(ctx, elen, 0)
	Cairo.stroke(ctx)
end
drawglyph(ctx::CairoContext, ::CGlyph{:+}, pt::Point2D, size::DReal) =
	drawglyph(ctx, CGlyph{:cross}(), pt, size)

function drawglyph(ctx::CairoContext, ::CGlyph{:diagcross}, pt::Point2D, size::DReal)
	elen = size #full edge length
	hlen = elen/2 #halflength
	Cairo.move_to(ctx, pt.x-hlen, pt.y-hlen)
	Cairo.rel_line_to(ctx, elen, elen)
	Cairo.stroke(ctx)
	Cairo.move_to(ctx, pt.x-hlen, pt.y+hlen)
	Cairo.rel_line_to(ctx, elen, -elen)
	Cairo.stroke(ctx)
end
drawglyph(ctx::CairoContext, ::CGlyph{:x}, pt::Point2D, size::DReal) =
	drawglyph(ctx, CGlyph{:diagcross}(), pt, size)

function drawglyph(ctx::CairoContext, ::CGlyph{:star}, pt::Point2D, size::DReal)
	elen = size*sqrt(2) #full edge length
	hlen = elen/2 #halflength

	Cairo.move_to(ctx, pt.x, pt.y-hlen)
	Cairo.rel_line_to(ctx, 0, elen)
	Cairo.stroke(ctx)
	Cairo.move_to(ctx, pt.x-hlen, pt.y)
	Cairo.rel_line_to(ctx, elen, 0)
	Cairo.stroke(ctx)

	elen = size #full edge length
	hlen = elen/2 #halflength

	Cairo.move_to(ctx, pt.x-hlen, pt.y-hlen)
	Cairo.rel_line_to(ctx, elen, elen)
	Cairo.stroke(ctx)
	Cairo.move_to(ctx, pt.x-hlen, pt.y+hlen)
	Cairo.rel_line_to(ctx, elen, -elen)
	Cairo.stroke(ctx)
end
drawglyph(ctx::CairoContext, ::CGlyph{:*}, pt::Point2D, size::DReal) =
	drawglyph(ctx, CGlyph{:star}(), pt, size)

function drawglyph(ctx::CairoContext, ::CGlyph{:diamond}, pt::Point2D, size::DReal)
	elen = size #full edge length
	hlen = elen/2 #halflength
	Cairo.move_to(ctx, pt.x, pt.y-hlen)
	Cairo.rel_line_to(ctx, hlen, hlen)
	Cairo.rel_line_to(ctx, -hlen, hlen)
	Cairo.rel_line_to(ctx, -hlen, -hlen)
	Cairo.close_path(ctx)
	Cairo.stroke(ctx)
end


#dir=1: up, -1: down
function drawglyph_varrow(ctx::CairoContext, pt::Point2D, size::DReal, dir::Int)
	elen = size #full edge length
	hlen = elen/2 #halflength
	dlen = dir*elen #directional edge
	Cairo.move_to(ctx, pt.x, pt.y-dir*hlen)
	Cairo.rel_line_to(ctx, hlen, dlen)
	Cairo.rel_line_to(ctx, -elen, 0)
	Cairo.close_path(ctx)
	Cairo.stroke(ctx)
end

drawglyph(ctx::CairoContext, ::CGlyph{:uarrow}, pt::Point2D, size::DReal) =
	drawglyph_varrow(ctx, pt, size, 1)
drawglyph(ctx::CairoContext, ::CGlyph{:darrow}, pt::Point2D, size::DReal) =
	drawglyph_varrow(ctx, pt, size, -1)

#dir=1: right, -1: left
function drawglyph_harrow(ctx::CairoContext, pt::Point2D, size::DReal, dir::Int)
	elen = size #full edge length
	hlen = elen/2 #halflength
	dlen = dir*elen #directional edge
	Cairo.move_to(ctx, pt.x+dir*hlen, pt.y)
	Cairo.rel_line_to(ctx, -dlen, hlen)
	Cairo.rel_line_to(ctx, 0, -elen)
	Cairo.close_path(ctx)
	Cairo.stroke(ctx)
end

drawglyph(ctx::CairoContext, ::CGlyph{:larrow}, pt::Point2D, size::DReal) =
	drawglyph_harrow(ctx, pt, size, -1)
drawglyph(ctx::CairoContext, ::CGlyph{:rarrow}, pt::Point2D, size::DReal) =
	drawglyph_harrow(ctx, pt, size, 1)

function drawglyph_safe(ctx::CairoContext, wfrm::DWaveform, pt::Point2D)
	if wfrm.glyph.shape != :none
		_glyph = CGlyph(wfrm.glyph.shape)
		gsize = Float64(wfrm.line.width*wfrm.glyph.size)
		drawglyph(ctx, _glyph, pt, gsize)
	end
end


#==Rendering base plot elements
===============================================================================#

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
	render(ctx, a.title, pt, lyt.fnttitle, align=ALIGN_HCENTER|ALIGN_VCENTER)

	#X-axis
	pt = Point2D(xcenter, bb.ymax-lyt.haxlabel/2)
	render(ctx, a.xlabel, pt, lyt.fntaxlabel, align=ALIGN_HCENTER|ALIGN_VCENTER)

	#Y-axis
	pt = Point2D(bb.xmin+lyt.waxlabel/2, ycenter)
	render(ctx, a.ylabel, pt, lyt.fntaxlabel, align=ALIGN_HCENTER|ALIGN_VCENTER, angle=-90)
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

#==Render grid
===============================================================================#
render_vlines(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, xlines::AbstractGridLines) = nothing
function render_vlines(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, xlines::GridLines)
	if lyt.grid.vmajor
		setlinestyle(ctx, :dash, GRID_MAJOR_WIDTH)
		Cairo.set_source(ctx, GRID_MAJOR_COLOR)
		for xline in xlines.major
			x = ptmap(xf, Point2D(xline, 0)).x
			drawline(ctx, Point2D(x, graphbb.ymin), Point2D(x, graphbb.ymax))
		end
	end
	if lyt.grid.vminor
		setlinestyle(ctx, :dash, GRID_MINOR_WIDTH)
		Cairo.set_source(ctx, GRID_MINOR_COLOR)
		for xline in xlines.minor
			x = ptmap(xf, Point2D(xline, 0)).x
			drawline(ctx, Point2D(x, graphbb.ymin), Point2D(x, graphbb.ymax))
		end
	end
end
render_hlines(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, ylines::AbstractGridLines) = nothing
function render_hlines(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, ylines::GridLines)
	if lyt.grid.hmajor
		setlinestyle(ctx, :dash, GRID_MAJOR_WIDTH)
		Cairo.set_source(ctx, GRID_MAJOR_COLOR)
		for yline in ylines.major
			y = ptmap(xf, Point2D(0, yline)).y
			drawline(ctx, Point2D(graphbb.xmin, y), Point2D(graphbb.xmax, y))
		end
	end
	if lyt.grid.hminor
		setlinestyle(ctx, :dash, GRID_MINOR_WIDTH)
		Cairo.set_source(ctx, GRID_MINOR_COLOR)
		for yline in ylines.minor
			y = ptmap(xf, Point2D(0, yline)).y
			drawline(ctx, Point2D(graphbb.xmin, y), Point2D(graphbb.xmax, y))
		end
	end
end

function render_grid(canvas::PCanvas2D, lyt::Layout, grid::GridRect)
	const ctx = canvas.ctx
	Cairo.save(ctx) #-----
	render_vlines(ctx, canvas.graphbb, canvas.xf, lyt, grid.xlines)
	render_hlines(ctx, canvas.graphbb, canvas.xf, lyt, grid.ylines)
	Cairo.restore(ctx) #-----
end


#==Render ticks
===============================================================================#

#Default label:
function render_ticklabel(ctx::CairoContext, val::DReal, pt::Point2D, font::Font, align::CAlignment, ::AxisScale)
	#TODO: Improve how numbers are displayed
	tstr = "$val"
	if length(tstr) > 7 #HACK!
		tstr = @sprintf("%0.1e", val)
	end
	render(ctx, tstr, pt, font, align=align)
end

render_ticklabel(ctx::CairoContext, val::DReal, pt::Point2D, font::Font, align::CAlignment, scale::AxisScale{:log10}) =
	render_power(ctx, 10, val, pt, font, align)

#Render ticks: Well-defined GridLines
#-------------------------------------------------------------------------------
function render_xticks(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, xlines::GridLines)
	yframe = graphbb.ymax
	ylabel = graphbb.ymax + lyt.hticklabel / 2
	for xtick in xlines.major
		x = ptmap(xf, Point2D(xtick, 0)).x
		render_ticklabel(ctx, xtick, Point2D(x, ylabel), lyt.fntaxlabel, ALIGN_HCENTER|ALIGN_VCENTER, xlines.scale)
		drawline(ctx, Point2D(x, yframe), Point2D(x, yframe-TICK_MAJOR_LEN))
	end
	for xtick in xlines.minor
		x = ptmap(xf, Point2D(xtick, 0)).x
		drawline(ctx, Point2D(x, yframe), Point2D(x, yframe-TICK_MINOR_LEN))
	end
end
function render_yticks(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, ylines::GridLines)
	xframe = graphbb.xmin
	xlabel = graphbb.xmin - 2 #TODO: offset by with of graphframe?
	for ytick in ylines.major
		y = ptmap(xf, Point2D(0, ytick)).y
		render_ticklabel(ctx, ytick, Point2D(xlabel, y), lyt.fntaxlabel, ALIGN_RIGHT|ALIGN_VCENTER, ylines.scale)
		drawline(ctx, Point2D(xframe, y), Point2D(xframe+TICK_MAJOR_LEN, y))
	end
	for ytick in ylines.minor
		y = ptmap(xf, Point2D(0, ytick)).y
		drawline(ctx, Point2D(xframe, y), Point2D(xframe+TICK_MINOR_LEN, y))
	end
end

#Render ticks: UndefinedGridLines
#-------------------------------------------------------------------------------
function render_xticks(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, xlines::UndefinedGridLines)
	yframe = graphbb.ymax
	ylabel = graphbb.ymax + lyt.hticklabel / 2
	for (x, xlabel) in [(graphbb.xmin, xlines.minline), (graphbb.xmax, xlines.maxline)]
		render_ticklabel(ctx, xlabel, Point2D(x, ylabel), lyt.fntaxlabel, ALIGN_HCENTER|ALIGN_VCENTER, AxisScale{:lin}())
		drawline(ctx, Point2D(x, yframe), Point2D(x, yframe-TICK_MAJOR_LEN))
	end
end
function render_yticks(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, ylines::UndefinedGridLines)
	xframe = graphbb.xmin
	xlabel = graphbb.xmin - 2 #TODO: offset by with of graphframe?
	for (y, ylabel) in [(graphbb.ymax, ylines.minline), (graphbb.ymin, ylines.maxline)]
		render_ticklabel(ctx, ylabel, Point2D(xlabel, y), lyt.fntaxlabel, ALIGN_RIGHT|ALIGN_VCENTER, AxisScale{:lin}())
		drawline(ctx, Point2D(xframe, y), Point2D(xframe+TICK_MAJOR_LEN, y))
	end
end

function render_ticks(canvas::PCanvas2D, lyt::Layout, grid::GridRect)
	render_xticks(canvas.ctx, canvas.graphbb, canvas.xf, lyt, grid.xlines)
	render_yticks(canvas.ctx, canvas.graphbb, canvas.xf, lyt, grid.ylines)
end


#==High-level rendering
===============================================================================#

#Render axis labels, ticks, ...
#-------------------------------------------------------------------------------
function render_axes(canvas::PCanvas2D, lyt::Layout, grid::GridRect)
	render_graphframe(canvas)
	render_ticks(canvas, lyt, grid)
end

#Render an actual waveform
#-------------------------------------------------------------------------------
function render(canvas::PCanvas2D, wfrm::DWaveform)
	ctx = canvas.ctx
	ds = wfrm.ds

	if length(ds) < 2
		return
	end

	Cairo.set_source(ctx, wfrm.line.color)
	setlinestyle(ctx, wfrm.line.style, Float64(wfrm.line.width))
	pt = ptmap(canvas.xf, ds[1])
	Cairo.move_to(ctx, pt.x, pt.y)
	for i in 2:length(ds)
		pt = ptmap(canvas.xf, ds[i])
		Cairo.line_to(ctx, pt.x, pt.y)
	end
#	set_line_join(ctx, Cairo.CAIRO_LINE_JOIN_MITER)
	Cairo.stroke(ctx)

	if :none == wfrm.glyph.shape; return; end
	_glyph = CGlyph(wfrm.glyph.shape)

	#TODO: do not draw when outside graph extents.

	#Draw symbols:
	setlinestyle(ctx, :solid, Float64(wfrm.line.width))
	gsize = Float64(wfrm.glyph.size*wfrm.line.width)
	for i in 1:length(ds)
		pt = ptmap(canvas.xf, ds[i])
		drawglyph(ctx, _glyph, pt, gsize)
	end

	return
end
render(canvas::PCanvas2D, wfrmlist::Vector{DWaveform}) =
	map((w)->render(canvas, w), wfrmlist)

#Last line
