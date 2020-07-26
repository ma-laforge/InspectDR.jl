#InspectDR: Base functionnality and types for Cairo layer
#-------------------------------------------------------------------------------


#==Constants
===============================================================================#


#==Main types
===============================================================================#

# RPlot2D/RStrip2D
#-------------------------------------------------------------------------------
#=Comments
 - Cache for bounds, current extents, text formatting, transforms, etc.
 - "Evaluated" information about all plots/strips.
 - Structures are not meant to be user-editable.
 - Structures intended for ease of access for rendering functions, at expense
   of data duplication (Assumes data will not get corrupted while rendering).
=#
struct RStrip2D
	istrip::Int
	bb::BoundingBox #Location of graph (device units)
	ext::PExtents2D #Current extents of graph (aloc units)
	ixf::InputXfrm2D #Input transform for y-values (data->aloc)
	xf::Transform2D #Transform used to render data (aloc->dev)

	xscale::AxisScale
	yscale::AxisScale
	xfmt::TickLabelFormatting #x tick label formatting
	yfmt::TickLabelFormatting #y tick label formatting
	#x/yfmt: Want to define/use coord_grid when displaying coordinates???
	#        Or maybe we deprecate coord_grid???

	#Real, displayed ("_eval"-uated) grid - not "coordinate grid"
	grid::PlotGrid #will be concrete (ex: with Gridlines),
	               #not abstract (ex: with GridLinesAuto)
	cgrid::PlotGrid #also concrete.  Used to draw tick coordinates
	#(ex: A smith chart has a Smith-type "grid", and rectangular "cgrid"
	#for ticks and hover coordinates.)
end

struct RPlot2D
	bb::BoundingBox #Location of plot (device units)
	databb::BoundingBox #Location of data area (encompassing all graphs)
	strips::Vector{RStrip2D}
end


#Used to buffer portions of plot for better GUI response times
mutable struct CairoBufferedPlot
	surf::Cairo.CairoSurface #Main surface where plot is drawn
	data::Cairo.CairoSurface #Cache of data image layer
end

#==Constructor-like functions
===============================================================================#

function RStrip2D(plot::Plot2D, strip::GraphStrip, graphbb::BoundingBox,
		ext::PExtents2D, xfmt::TickLabelFormatting, istrip::Int)
	dfltfmt = TickLabelFormatting(NoRangeDisplayInfo()) #WANTCONST
	xf = Transform2D(ext, graphbb)

	yfmt = dfltfmt
	grid = _eval(strip.grid, plot.xscale, strip.yscale, ext)
	cgrid = coord_grid(strip.grid, plot.xscale, strip.yscale, ext)
	if !isa(cgrid.ylines, UndefinedGridLines)
		yfmt = TickLabelFormatting(plot.layout.values.format_ytick, cgrid.ylines.rnginfo)
	end

	ixf = InputXfrm2D(InputXfrm1DSpec(plot.xscale), InputXfrm1DSpec(strip.yscale))
	return RStrip2D(istrip, graphbb, ext, ixf, xf, plot.xscale, strip.yscale, xfmt, yfmt, grid, cgrid)
end

#bb: bounding box of entire plot
function RPlot2D(plot::Plot2D, bb::BoundingBox)
	dfltfmt = TickLabelFormatting(NoRangeDisplayInfo()) #WANTCONST
	nstrips = length(plot.strips)
	databb = databounds(bb, plot.layout.values, grid1(plot))
	graphbblist = graphbounds_list(databb, plot.layout.values, nstrips)

	xfmt = dfltfmt
	if nstrips > 0
		strip = plot.strips[1]
		ext = getextents_aloc(plot, 1)
		grid = _eval(strip.grid, plot.xscale, strip.yscale, ext)
		cgrid = coord_grid(grid, plot.xscale, strip.yscale, ext)
		if !isa(cgrid.xlines, UndefinedGridLines)
			xfmt = TickLabelFormatting(plot.layout.values.format_xtick, cgrid.xlines.rnginfo)
		end
	end
	striplist = RStrip2D[]

	for istrip in 1:nstrips #Compute x/y label formats:
		strip = plot.strips[istrip]
		graphbb = graphbblist[istrip]
		ext = getextents_aloc(plot, istrip)
		push!(striplist, RStrip2D(plot, strip, graphbb, ext, xfmt, istrip))
	end

	return RPlot2D(bb, databb, striplist)
end


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
	cairo_circle(ctx, pt.x, pt.y, g.radius*size)
	renderfill(ctx, fill)
	Cairo.stroke(ctx)
end

#Correctly displays a glyph, given wfrm properties.
function drawglyph_safe(ctx::CairoContext, wfrm::DWaveform, pt::Point2D)
	_glyph = Glyph(wfrm.glyph.shape)
	if nothing == _glyph; return; end

	linecolor = getglyphcolor(wfrm.glyph, wfrm.line)
	linestyle = LineStyle(:solid, Float64(wfrm.line.width), linecolor)
	setlinestyle(ctx, linestyle)
	fill = getglyphfill(wfrm.glyph)
	gsize = Float64(wfrm.glyph.size)

	drawglyph(ctx, _glyph, pt, gsize, fill)
	return
end


#==High-level rendering
===============================================================================#

#Render NaNs on plot:
#-------------------------------------------------------------------------------
function rendernans(ctx::CairoContext, rstrip::RStrip2D, wfrm::IWaveform)
	NAN_LINE = LineStyle(
		:solid, Float64(4), ARGB32(1, 0, 0, 0.5)
	) #WANTCONST
	graphbb = rstrip.bb #WANTCONST
	x = wfrm.ds.x #WANTCONST
	y = wfrm.ds.y #WANTCONST

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
			pt = apply(rstrip.xf, pt)
			Cairo.move_to(ctx, graphbb.xmin, pt.y)
			Cairo.line_to(ctx, graphbb.xmax, pt.y)
			Cairo.stroke(ctx)
		elseif ynan
			pt = apply(rstrip.xf, pt)
			Cairo.move_to(ctx, pt.x, graphbb.ymin)
			Cairo.line_to(ctx, pt.x, graphbb.ymax)
			Cairo.stroke(ctx)
		end
	end

	#TODO: warn hasNaNNaN?
	return hasNaNNaN
end
function rendernans(ctx::CairoContext, rstrip::RStrip2D, wfrmlist::Vector{IWaveform})
	for wfrm in wfrmlist
		if 0 == wfrm.strip || wfrm.strip == rstrip.istrip
			rendernans(ctx, rstrip, wfrm)
		end
	end
	return
end

#Render heatmap
#-------------------------------------------------------------------------------
function render(ctx::CairoContext, rstrip::RStrip2D, hm::DHeatmap)
	ds = hm.ds #alias
	(nx, ny) = size(ds.data)
	ensure((length(ds.x) == nx+1) && (length(ds.y) == ny+1),
		ArgumentError("Heatmap: z-data must have one less value in each dimension than x & y vectors.")
	)
	ctransp = ARGB32(0,0,0,0)

	Cairo.save(ctx)
	linestyle = LineStyle(:solid, Float64(1), ctransp) #Need 1px line to avoid gaps
	#TODO: Is there a better way to close gaps??
	setlinestyle(ctx, linestyle)

	for ix in 1:nx
		for iy in 1:ny
			pt1 = apply(rstrip.xf, Point2D(ds.x[ix], ds.y[iy]))
			pt2 = apply(rstrip.xf, Point2D(ds.x[ix+1], ds.y[iy+1]))
			Cairo.set_source(ctx, ds.data[ix,iy])
			Cairo.rectangle(ctx, BoundingBox(pt1.x, pt2.x, pt1.y, pt2.y))
			Cairo.fill_preserve(ctx)
			Cairo.stroke(ctx)
		end
	end

	Cairo.restore(ctx)
end
function render(ctx::CairoContext, rstrip::RStrip2D, hmlist::Vector{DHeatmap})
	for hm in hmlist
		if 0 == hm.strip || hm.strip == rstrip.istrip
			render(ctx, rstrip, hm)
		end
	end
	return
end

#Render an actual waveform
#-------------------------------------------------------------------------------
function render(ctx::CairoContext, rstrip::RStrip2D, wfrm::DWaveform)
	ds = wfrm.ds #WANTCONST

	if length(ds) < 1; return; end

if hasline(wfrm)
	setlinestyle(ctx, LineStyle(wfrm.line))
	newsegment = true
	for i in 1:length(ds)
		pt = apply(rstrip.xf, ds[i])
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
	Cairo.stroke(ctx)
end

	_glyph = Glyph(wfrm.glyph.shape)
	if nothing == _glyph; return; end

	#TODO: do not draw when outside graph extents.

	#Draw symbols:
	linecolor = getglyphcolor(wfrm.glyph, wfrm.line)
	linestyle = LineStyle(:solid, Float64(wfrm.line.width), linecolor)
	setlinestyle(ctx, linestyle)
	fill = getglyphfill(wfrm.glyph)
	gsize = Float64(wfrm.glyph.size)
	for i in 1:length(ds)
		pt = apply(rstrip.xf, ds[i])
		drawglyph(ctx, _glyph, pt, gsize, fill)
	end

	return
end
function render(ctx::CairoContext, rstrip::RStrip2D, wfrmlist::Vector{DWaveform})
	for wfrm in wfrmlist
		if 0 == wfrm.strip || wfrm.strip == rstrip.istrip
			render(ctx, rstrip, wfrm)
		end
	end
	return
end

#Last line
