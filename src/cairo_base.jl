#InspectDR: Base functionnality and types for Cairo layer
#-------------------------------------------------------------------------------


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


#==Basic rendering
===============================================================================#

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

function drawglyph(ctx::CairoContext, g::GlyphPolyline, pt::Point2D, size::DReal, fill)
	#TODO: could scale GlyphPolyline only once for efficiency (instead of every time we draw).
	x = g.x*size; y = g.y*(-1*size) #Compensate for y-reversal
	Cairo.move_to(ctx, pt.x, pt.y)
	Cairo.rel_move_to(ctx, x[1], y[1]) #rel: Probably less prone to rounding errors

	dxv = diff(x); dyv = diff(y)
	for (dx, dy) in zip(dxv, dyv)
		Cairo.rel_line_to(ctx, dx, dy)
	end
	if g.closepath
		Cairo.close_path(ctx)
		renderfill(ctx, fill)
	end
	Cairo.stroke(ctx)
	return
end
function drawglyph(ctx::CairoContext, g::GlyphLineSegments, pt::Point2D, size::DReal, fill)
	dxv = size * (g.x2 - g.x1)
	dyv = -size * (g.y2 - g.y1)
	x1v = size * g.x1
	y1v = -size * g.y1
	for (x1, y1, dx, dy) in zip(x1v, y1v, dxv, dyv)
		Cairo.move_to(ctx, pt.x, pt.y)
		Cairo.rel_move_to(ctx, x1, y1) #rel: Probably less prone to rounding errors
		Cairo.rel_line_to(ctx, dx, dy)
		Cairo.stroke(ctx)
	end
	return
end
function drawglyph(ctx::CairoContext, g::GlyphCircle, pt::Point2D, size::DReal, fill)
	Cairo.arc(ctx, pt.x, pt.y, g.radius*size, 0, 2pi)
	renderfill(ctx, fill)
	Cairo.stroke(ctx)
end

#Correctly displays a glyph, given wfrm properties.
function drawglyph_safe(ctx::CairoContext, wfrm::DWaveform, pt::Point2D)
	_glyph = Glyph(wfrm.glyph.shape)
	if nothing == _glyph; return; end

	setlinestyle(ctx, :solid, Float64(wfrm.line.width))
	linecolor = getglyphcolor(wfrm.glyph, wfrm.line)
	Cairo.set_source(ctx, linecolor)
	fill = getglyphfill(wfrm.glyph)
	gsize = Float64(wfrm.glyph.size)

	drawglyph(ctx, _glyph, pt, gsize, fill)
	return
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
function render_graphframe(canvas::PCanvas2D, aa::AreaAttributes)
	const ctx = canvas.ctx
Cairo.save(ctx)
	setlinestyle(ctx, aa.line)
	Cairo.rectangle(ctx, canvas.graphbb)
	Cairo.stroke(ctx)
Cairo.restore(ctx)
	return
end

#==Render grid
===============================================================================#
render_vlines(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, xlines::AbstractGridLines) = nothing
function render_vlines(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, xlines::GridLines)
	if lyt.grid.vmajor
		setlinestyle(ctx, GRID_MAJOR_LINE)
		for xline in xlines.major
			x = ptmap(xf, Point2D(xline, 0)).x
			drawline(ctx, Point2D(x, graphbb.ymin), Point2D(x, graphbb.ymax))
		end
	end
	if lyt.grid.vminor
		setlinestyle(ctx, GRID_MINOR_LINE)
		for xline in xlines.minor
			x = ptmap(xf, Point2D(xline, 0)).x
			drawline(ctx, Point2D(x, graphbb.ymin), Point2D(x, graphbb.ymax))
		end
	end
end
render_hlines(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, ylines::AbstractGridLines) = nothing
function render_hlines(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, ylines::GridLines)
	if lyt.grid.hmajor
		setlinestyle(ctx, GRID_MAJOR_LINE)
		for yline in ylines.major
			y = ptmap(xf, Point2D(0, yline)).y
			drawline(ctx, Point2D(graphbb.xmin, y), Point2D(graphbb.xmax, y))
		end
	end
	if lyt.grid.hminor
		setlinestyle(ctx, GRID_MINOR_LINE)
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

render_ticklabel(ctx::CairoContext, val::DReal, pt::Point2D, font::Font, align::CAlignment, fmt::TickLabelFormatting, scale::AxisScale{:ln}) =
	render_power(ctx, "e", val, pt, font, align)
render_ticklabel(ctx::CairoContext, val::DReal, pt::Point2D, font::Font, align::CAlignment, fmt::TickLabelFormatting, scale::AxisScale{:log2}) =
	render_power(ctx, "2", val, pt, font, align)
render_ticklabel(ctx::CairoContext, val::DReal, pt::Point2D, font::Font, align::CAlignment, fmt::TickLabelFormatting, scale::AxisScale{:log10}) =
	render_power(ctx, "10", val, pt, font, align)

function render_axisscalelabel(ctx::CairoContext, pt::Point2D, font::Font, align::CAlignment, fmt::TickLabelFormatting, ::AxisScale)
	tstr = formatted_exp(fmt.fmt)
	render(ctx, tstr, pt, font, align=align)
end

#Render ticks: Well-defined GridLines
#-------------------------------------------------------------------------------
function render_xticks(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, xlines::GridLines)
	const tframe = DReal(lyt.framedata.line.width) #TODO: Fix LineAttributes to have concrete type
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
		xlabel = graphbb.xmax + tframe
		render_axisscalelabel(ctx, Point2D(xlabel, yframe), lyt.fntticklabel, ALIGN_BOTTOM|ALIGN_LEFT, fmt, xlines.scale)
	end
end
function render_yticks(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::Layout, ylines::GridLines)
	const tframe = DReal(lyt.framedata.line.width) #TODO: Fix LineAttributes to have concrete type
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
		ylabel = graphbb.ymin - tframe
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
	render_graphframe(canvas, lyt.framedata)
	render_ticks(canvas, lyt, grid)
end

#Render NaNs on plot:
#-------------------------------------------------------------------------------
function rendernans(canvas::PCanvas2D, wfrm::IWaveform)
	const NAN_LINE = LineAttributes(
		:solid, Float64(4), ARGB32(1, 0, 0, 0.5)
	)
	const ctx = canvas.ctx
	const graphbb = canvas.graphbb
	const x = wfrm.ds.x
	const y = wfrm.ds.y

	if length(x) != length(y)
		error("x & y - vector length mismatch.")
	end

	setlinestyle(ctx, NAN_LINE)
	hasNaNNaN = false

	for i in 1:length(x)
		pt = Point2D(x[i], y[i])
		xnan = isnan(pt.x); ynan = isnan(pt.y)

		if xnan && ynan
			hasNaNNaN = true #nothing practical to display
		elseif xnan
			pt = ptmap(canvas.xf, pt)
			Cairo.move_to(ctx, graphbb.xmin, pt.y)
			Cairo.line_to(ctx, graphbb.xmax, pt.y)
			Cairo.stroke(ctx)
		elseif ynan
			pt = ptmap(canvas.xf, pt)
			Cairo.move_to(ctx, pt.x, graphbb.ymin)
			Cairo.line_to(ctx, pt.x, graphbb.ymax)
			Cairo.stroke(ctx)
		end
	end

	#TODO: warn hasNaNNaN?
	return hasNaNNaN
end
rendernans(canvas::PCanvas2D, wfrmlist::Vector{IWaveform}) =
	map((w)->rendernans(canvas, w), wfrmlist)

#Render an actual waveform
#-------------------------------------------------------------------------------
function render(canvas::PCanvas2D, wfrm::DWaveform)
	const ctx = canvas.ctx
	const ds = wfrm.ds

	if length(ds) < 1; return; end

if wfrm.line.style != :none
	setlinestyle(ctx, wfrm.line)
	newsegment = true
	for i in 1:length(ds)
		pt = ptmap(canvas.xf, ds[i])
		xnan = isnan(pt.x); ynan = isnan(pt.y)

		#TODO: log NaNs?  Display NaNs?
		if xnan && ynan
			Cairo.stroke(ctx) #Close last line
			newsegment = true
		elseif xnan || ynan
			#Simply skip this point
		elseif newsegment
			Cairo.move_to(ctx, pt.x, pt.y)
			newsegment = false
		else
			Cairo.line_to(ctx, pt.x, pt.y)
		end
	end
#	set_line_join(ctx, Cairo.CAIRO_LINE_JOIN_MITER)
	Cairo.stroke(ctx)
end

	_glyph = Glyph(wfrm.glyph.shape)
	if nothing == _glyph; return; end

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
