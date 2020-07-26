#InspectDR: Draw legends with Cairo layer.
#-------------------------------------------------------------------------------


#==
===============================================================================#

#NOTE: linelength & textoffset are absolute values
function legend_renderitem(ctx::CairoContext, wfrm::DWaveform, x::Float64, y::Float64,
	linelength::Float64, textoffset::Float64)
	linestart = x+textoffset
	lineend = linestart+linelength

Cairo.save(ctx)
	setlinestyle(ctx, LineStyle(wfrm.line))
	drawline(ctx, Point2D(linestart, y), Point2D(lineend, y))
	drawglyph_safe(ctx, wfrm, Point2D(linestart+linelength/2, y))
Cairo.restore(ctx)
	x = lineend+textoffset #Compute new x
	render(ctx, wfrm.id, Point2D(x, y), align=ALIGN_VCENTER|ALIGN_LEFT)
end

function render_legend(ctx::CairoContext, rstrip::RStrip2D, display_data::Vector,
		lyt::PlotLayout, bbleg::BoundingBox)
	Cairo.save(ctx)
	drawrectangle(ctx, bbleg, lyt.frame_legend)
	Cairo.restore(ctx)

	Cairo.save(ctx)
	setfont(ctx, lyt.font_legend)
	(w, h) = textextents_wh(ctx, "M")
	ypitch = h*(1+lyt.valloc_legenditemsp)

	#Compute absolute values:
	textoffset = lyt.hoffset_legendtext*w

	y = bbleg.ymin + h/2
	for d in display_data
		if d.strip != rstrip.istrip; continue; end
		if "" == d.id; continue; end
		legend_renderitem(ctx, d, bbleg.xmin, y, lyt.halloc_legendlineseg, textoffset)
		y += ypitch
	end
	Cairo.restore(ctx)
end

function render_colorscale(ctx::CairoContext, rstrip::RStrip2D, strip::GraphStrip, lyt::PlotLayout)
	colorscale = strip.colorscale

	#Compute bounding box of colorscale:
	xleft = rstrip.bb.xmax + lyt.halloc_right
	bb = BoundingBox(xleft, xleft+lyt.halloc_colorscale, rstrip.bb.ymin, rstrip.bb.ymax)

	#Draw color scale itself:
	N = length(colorscale.e)
	Δ = bb.ymin - bb.ymax
	ystart = bb.ymax #start at bottom (ymax)
	Cairo.save(ctx)
	for i in 1:N
		yend = bb.ymax + Δ * (i/N)
		cbb = BoundingBox(bb.xmin, bb.xmax, ystart, yend)
		drawrectangle(ctx, cbb, colorscale.e[i])
		ystart = yend
	end
	Cairo.restore(ctx)

	#Draw frame:
	Cairo.save(ctx)
	zscale = strip.zscale; zext = strip.zext
	zlines = gridlines(zscale, zext.min, zext.max, true, true, zscale.tgtmajor, zscale.tgtminor)
	render_zticks(ctx, rstrip, lyt, bb, zext, zlines, zscale)
	drawrectangle(ctx, bb, lyt.frame_colorscale)
	Cairo.restore(ctx)
	return
end

function render_legends(ctx::CairoContext, rplot::RPlot2D, plot::Plot2D)
	lyt = plot.layout.values #WANTCONST

	if lyt.enable_colorscale
		for rstrip in rplot.strips
			render_colorscale(ctx, rstrip, plot.strips[rstrip.istrip], lyt)
		end
	end
	if lyt.enable_legend
		legend_left = rplot.bb.xmax - lyt.halloc_legend
		for rstrip in rplot.strips
			bbleg = BoundingBox(legend_left, rplot.bb.xmax, rstrip.bb.ymin, rstrip.bb.ymax)
			render_legend(ctx, rstrip, plot.display_data, lyt, bbleg)
		end
	end
end

#Last line
