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
	Cairo.fill(ctx)
end

#Apply transform to Cairo (when easier to do so):
function setxfrm(ctx::CairoContext, xf::Transform2D)
	xorig = xf.x0*xf.xs
	yorig = xf.y0*xf.ys
	Cairo.translate(ctx, xorig, yorig)
	Cairo.scale(ctx, xf.xs, xf.ys)
end


#==Rendering Glyphs
===============================================================================#

function getglyphcolor(glyph::GlyphAttributes, line::LineAttributes)
	c = glyph.color
	if nothing == c
		c = line.color
	end
	return c
end

function getglyphfill(glyph::GlyphAttributes)
	fill = glyph.fillcolor
	if COLOR_TRANSPARENT == fill #Small optimization
		fill = nothing
	end
	return fill
end

#Conditionnaly render fill (preserve path for stroke)
renderfill(ctx::CairoContext, fill::Void) = nothing
function renderfill(ctx::CairoContext, fill::Colorant)
	Cairo.save(ctx) #-----
	Cairo.set_source(ctx, fill)
	Cairo.fill_preserve(ctx)
	Cairo.restore(ctx) #-----
end

function drawglyph{T}(ctx::CairoContext, ::CGlyph{T}, pt::Point2D, size::DReal, fill)
	warn("Glyph shape not supported: $T")
end

#= Supported:
	:square, :diamond,
	:uarrow, :darrow, :larrow, :rarrow, #usually triangles
	:cross, :+, :diagcross, :x,
	:circle, :o, :star, :*,
=#

function drawglyph(ctx::CairoContext, ::CGlyph{:circle}, pt::Point2D, size::DReal, fill)
	radius = size/2
	Cairo.arc(ctx, pt.x, pt.y, radius, 0, 2pi)
	renderfill(ctx, fill)
	Cairo.stroke(ctx)
end
drawglyph(ctx::CairoContext, ::CGlyph{:o}, pt::Point2D, size::DReal, fill) =
	drawglyph(ctx, CGlyph{:circle}(), pt, size, fill)

function drawglyph(ctx::CairoContext, ::CGlyph{:square}, pt::Point2D, size::DReal, fill)
	elen = size #full edge length
	hlen = elen/2 #halflength
	Cairo.rectangle(ctx, pt.x-hlen, pt.y-hlen, elen, elen)
	renderfill(ctx, fill)
	Cairo.stroke(ctx)
end

function drawglyph(ctx::CairoContext, ::CGlyph{:cross}, pt::Point2D, size::DReal, fill)
	elen = size*sqrt(2) #full edge length
	hlen = elen/2 #halflength
	Cairo.move_to(ctx, pt.x, pt.y-hlen)
	Cairo.rel_line_to(ctx, 0, elen)
	Cairo.stroke(ctx)
	Cairo.move_to(ctx, pt.x-hlen, pt.y)
	Cairo.rel_line_to(ctx, elen, 0)
	Cairo.stroke(ctx)
end
drawglyph(ctx::CairoContext, ::CGlyph{:+}, pt::Point2D, size::DReal, fill) =
	drawglyph(ctx, CGlyph{:cross}(), pt, size, fill)

function drawglyph(ctx::CairoContext, ::CGlyph{:diagcross}, pt::Point2D, size::DReal, fill)
	elen = size #full edge length
	hlen = elen/2 #halflength
	Cairo.move_to(ctx, pt.x-hlen, pt.y-hlen)
	Cairo.rel_line_to(ctx, elen, elen)
	Cairo.stroke(ctx)
	Cairo.move_to(ctx, pt.x-hlen, pt.y+hlen)
	Cairo.rel_line_to(ctx, elen, -elen)
	Cairo.stroke(ctx)
end
drawglyph(ctx::CairoContext, ::CGlyph{:x}, pt::Point2D, size::DReal, fill) =
	drawglyph(ctx, CGlyph{:diagcross}(), pt, size, fill)

function drawglyph(ctx::CairoContext, ::CGlyph{:star}, pt::Point2D, size::DReal, fill)
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
drawglyph(ctx::CairoContext, ::CGlyph{:*}, pt::Point2D, size::DReal, fill) =
	drawglyph(ctx, CGlyph{:star}(), pt, size, fill)

function drawglyph(ctx::CairoContext, ::CGlyph{:diamond}, pt::Point2D, size::DReal, fill)
	elen = size #full edge length
	hlen = elen/2 #halflength
	Cairo.move_to(ctx, pt.x, pt.y-hlen)
	Cairo.rel_line_to(ctx, hlen, hlen)
	Cairo.rel_line_to(ctx, -hlen, hlen)
	Cairo.rel_line_to(ctx, -hlen, -hlen)
	Cairo.close_path(ctx)
	renderfill(ctx, fill)
	Cairo.stroke(ctx)
end


#dir=1: up, -1: down
function drawglyph_varrow(ctx::CairoContext, pt::Point2D, size::DReal, dir::Int, fill)
	elen = size #full edge length
	hlen = elen/2 #halflength
	dlen = dir*elen #directional edge
	Cairo.move_to(ctx, pt.x, pt.y-dir*hlen)
	Cairo.rel_line_to(ctx, hlen, dlen)
	Cairo.rel_line_to(ctx, -elen, 0)
	Cairo.close_path(ctx)
	renderfill(ctx, fill)
	Cairo.stroke(ctx)
end

drawglyph(ctx::CairoContext, ::CGlyph{:uarrow}, pt::Point2D, size::DReal, fill) =
	drawglyph_varrow(ctx, pt, size, 1, fill)
drawglyph(ctx::CairoContext, ::CGlyph{:darrow}, pt::Point2D, size::DReal, fill) =
	drawglyph_varrow(ctx, pt, size, -1, fill)

#dir=1: right, -1: left
function drawglyph_harrow(ctx::CairoContext, pt::Point2D, size::DReal, dir::Int, fill)
	elen = size #full edge length
	hlen = elen/2 #halflength
	dlen = dir*elen #directional edge
	Cairo.move_to(ctx, pt.x+dir*hlen, pt.y)
	Cairo.rel_line_to(ctx, -dlen, hlen)
	Cairo.rel_line_to(ctx, 0, -elen)
	Cairo.close_path(ctx)
	renderfill(ctx, fill)
	Cairo.stroke(ctx)
end

drawglyph(ctx::CairoContext, ::CGlyph{:larrow}, pt::Point2D, size::DReal, fill) =
	drawglyph_harrow(ctx, pt, size, -1, fill)
drawglyph(ctx::CairoContext, ::CGlyph{:rarrow}, pt::Point2D, size::DReal, fill) =
	drawglyph_harrow(ctx, pt, size, 1, fill)

#Correctly displays a glyph, given wfrm properties.
function drawglyph_safe(ctx::CairoContext, wfrm::DWaveform, pt::Point2D)
	if wfrm.glyph.shape != :none
		_glyph = CGlyph(wfrm.glyph.shape)
		setlinestyle(ctx, :solid, Float64(wfrm.line.width))
		linecolor = getglyphcolor(wfrm.glyph, wfrm.line)
		Cairo.set_source(ctx, linecolor)
		fill = getglyphfill(wfrm.glyph)
		gsize = Float64(wfrm.glyph.size)

		drawglyph(ctx, _glyph, pt, gsize, fill)
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
	const TIMESTAMP_OFFSET = 3

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
	render(ctx, a.ylabel, pt, lyt.fntaxlabel, align=ALIGN_HCENTER|ALIGN_VCENTER, angle=-π/2)

	#Time stamp
	if lyt.showtimestamp
		pt = Point2D(bb.xmax-TIMESTAMP_OFFSET, bb.ymax-TIMESTAMP_OFFSET)
		render(ctx, a.timestamp, pt, lyt.fnttime, align=ALIGN_RIGHT|ALIGN_BOTTOM)
	end
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
function render_ticklabel(ctx::CairoContext, val::DReal, pt::Point2D, font::Font, align::CAlignment, fmt::TickLabelFormatting, ::AxisScale)
	tstr = ""
	if false #Old display system.
		#TODO: deprecate
		tstr = "$val"
		if length(tstr) > 7 #HACK!
			tstr = @sprintf("%0.1e", val)
		end
	else
		tstr = formatted(val, fmt.fmt, showexp=!fmt.splitexp)
	end
	render(ctx, tstr, pt, font, align=align)
end

render_ticklabel(ctx::CairoContext, val::DReal, pt::Point2D, font::Font, align::CAlignment, fmt::TickLabelFormatting, scale::AxisScale{:log10}) =
	render_power(ctx, 10, val, pt, font, align)

function render_axisscalelabel(ctx::CairoContext, pt::Point2D, font::Font, align::CAlignment, fmt::TickLabelFormatting, ::AxisScale)
	tstr = formatted_exp(fmt.fmt)
	render(ctx, tstr, pt, font, align=align)
end

#Render ticks: Well-defined GridLines
#-------------------------------------------------------------------------------
function render_xticks(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, xlines::GridLines)
	fmt = TickLabelFormatting(lyt.xlabelformat, xlines.rnginfo)
	yframe = graphbb.ymax
	ylabel = graphbb.ymax + lyt.vlabeloffset
	for xtick in xlines.major
		x = ptmap(xf, Point2D(xtick, 0)).x
		render_ticklabel(ctx, xtick, Point2D(x, ylabel), lyt.fntticklabel, ALIGN_TOP|ALIGN_HCENTER, fmt, xlines.scale)
		drawline(ctx, Point2D(x, yframe), Point2D(x, yframe-TICK_MAJOR_LEN))
	end
	for xtick in xlines.minor
		x = ptmap(xf, Point2D(xtick, 0)).x
		drawline(ctx, Point2D(x, yframe), Point2D(x, yframe-TICK_MINOR_LEN))
	end
	if fmt.splitexp
		xlabel = graphbb.xmax + lyt.tframe
		render_axisscalelabel(ctx, Point2D(xlabel, yframe), lyt.fntticklabel, ALIGN_BOTTOM|ALIGN_LEFT, fmt, xlines.scale)
	end
end
function render_yticks(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, ylines::GridLines)
	fmt = TickLabelFormatting(lyt.ylabelformat, ylines.rnginfo)
	xframe = graphbb.xmin
	xlabel = graphbb.xmin - lyt.hlabeloffset
	for ytick in ylines.major
		y = ptmap(xf, Point2D(0, ytick)).y
		render_ticklabel(ctx, ytick, Point2D(xlabel, y), lyt.fntticklabel, ALIGN_RIGHT|ALIGN_VCENTER, fmt, ylines.scale)
		drawline(ctx, Point2D(xframe, y), Point2D(xframe+TICK_MAJOR_LEN, y))
	end
	for ytick in ylines.minor
		y = ptmap(xf, Point2D(0, ytick)).y
		drawline(ctx, Point2D(xframe, y), Point2D(xframe+TICK_MINOR_LEN, y))
	end
	if fmt.splitexp
		ylabel = graphbb.ymin - lyt.tframe
		render_axisscalelabel(ctx, Point2D(xframe, ylabel), lyt.fntticklabel, ALIGN_BOTTOM|ALIGN_LEFT, fmt, ylines.scale)
	end
end

#Render ticks: UndefinedGridLines
#-------------------------------------------------------------------------------
function render_xticks(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, xlines::UndefinedGridLines)
	fmt = TickLabelFormatting(NoRangeDisplayInfo())
	yframe = graphbb.ymax
	ylabel = graphbb.ymax + lyt.vlabeloffset
	for (x, xlabel) in [(graphbb.xmin, xlines.minline), (graphbb.xmax, xlines.maxline)]
		render_ticklabel(ctx, xlabel, Point2D(x, ylabel), lyt.fntticklabel, ALIGN_TOP|ALIGN_HCENTER, fmt, AxisScale{:lin}())
		drawline(ctx, Point2D(x, yframe), Point2D(x, yframe-TICK_MAJOR_LEN))
	end
end
function render_yticks(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, ylines::UndefinedGridLines)
	fmt = TickLabelFormatting(NoRangeDisplayInfo())
	xframe = graphbb.xmin
	xlabel = graphbb.xmin - lyt.hlabeloffset
	for (y, ylabel) in [(graphbb.ymax, ylines.minline), (graphbb.ymin, ylines.maxline)]
		render_ticklabel(ctx, ylabel, Point2D(xlabel, y), lyt.fntticklabel, ALIGN_RIGHT|ALIGN_VCENTER, fmt, AxisScale{:lin}())
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

if wfrm.line.style != :none
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
end

	if :none == wfrm.glyph.shape; return; end
	_glyph = CGlyph(wfrm.glyph.shape)

	#TODO: do not draw when outside graph extents.

	#Draw symbols:
	setlinestyle(ctx, :solid, Float64(wfrm.line.width))
	linecolor = getglyphcolor(wfrm.glyph, wfrm.line)
	Cairo.set_source(ctx, linecolor)
	fill = getglyphfill(wfrm.glyph)
	gsize = Float64(wfrm.glyph.size)
	for i in 1:length(ds)
		pt = ptmap(canvas.xf, ds[i])
		drawglyph(ctx, _glyph, pt, gsize, fill)
	end

	return
end
render(canvas::PCanvas2D, wfrmlist::Vector{DWaveform}) =
	map((w)->render(canvas, w), wfrmlist)

#Last line
