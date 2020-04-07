#InspectDR: Rendering rectangular axes & ticks
#-------------------------------------------------------------------------------


#==Constants
===============================================================================#


#==Main types
===============================================================================#

#==Rendering base plot elements
===============================================================================#

#Render main plot annotation (titles, axis labels, ...)
#-------------------------------------------------------------------------------
function render_baseannotation(ctx::CairoContext, rplot::RPlot2D, lyt::PlotLayout, a::Annotation)
	TIMESTAMP_OFFSET = 3 #WANTCONST
	bb =  rplot.bb #WANTCONST
	databb =  rplot.databb #WANTCONST

	#Title
#	xcenter = (bb.xmin+bb.xmax)/2 #Entire plot BB.
	xcenter = (databb.xmin+databb.xmax)/2 #Data-area BB only.
	pt = Point2D(xcenter, bb.ymin+lyt.voffset_title)
	render(ctx, a.title, pt, lyt.font_title, align=ALIGN_HCENTER|ALIGN_VCENTER)

	#X-axis label
	xcenter = (databb.xmin+databb.xmax)/2
	pt = Point2D(xcenter, bb.ymax-lyt.voffset_xaxislabel)
	render(ctx, a.xlabel, pt, lyt.font_axislabel, align=ALIGN_HCENTER|ALIGN_VCENTER)

	#Y-axis labels
	nstrips = min(length(a.ylabels), length(rplot.strips))
	for i in 1:nstrips
		rstrip = rplot.strips[i]
		ycenter = (rstrip.bb.ymin+rstrip.bb.ymax)/2
		pt = Point2D(bb.xmin+lyt.hoffset_yaxislabel, ycenter)
		render(ctx, a.ylabels[i], pt, lyt.font_axislabel, align=ALIGN_HCENTER|ALIGN_VCENTER, angle=-π/2)
	end

	#Time stamp
	if lyt.enable_timestamp
		pt = Point2D(bb.xmax-TIMESTAMP_OFFSET, bb.ymax-TIMESTAMP_OFFSET)
		render(ctx, a.timestamp, pt, lyt.font_time, align=ALIGN_RIGHT|ALIGN_BOTTOM)
	end
end

#Render frame around graph
#-------------------------------------------------------------------------------
function render_graphframe(ctx::CairoContext, rstrip::RStrip2D, aa::AreaAttributes)
Cairo.save(ctx)
	setlinestyle(ctx, LineStyle(aa.line))
	Cairo.rectangle(ctx, rstrip.bb)
	Cairo.stroke(ctx)
Cairo.restore(ctx)
	return
end


#==Render grid
===============================================================================#
render_vlines(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::PlotLayout, xlines::AbstractGridLines) = nothing
function render_vlines(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::PlotLayout, xlines::GridLines)
	if xlines.displaymajor
		setlinestyle(ctx, lyt.line_gridmajor)
		for xline in xlines.major
			x = apply(xf, Point2D(xline, 0)).x
			drawline(ctx, Point2D(x, graphbb.ymin), Point2D(x, graphbb.ymax))
		end
	end
	if xlines.displayminor
		setlinestyle(ctx, lyt.line_gridminor)
		for xline in xlines.minor
			x = apply(xf, Point2D(xline, 0)).x
			drawline(ctx, Point2D(x, graphbb.ymin), Point2D(x, graphbb.ymax))
		end
	end
end
render_hlines(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::PlotLayout, ylines::AbstractGridLines) = nothing
function render_hlines(ctx::CairoContext, graphbb::BoundingBox, xf::Transform2D, lyt::PlotLayout, ylines::GridLines)
	if ylines.displaymajor
		setlinestyle(ctx, lyt.line_gridmajor)
		for yline in ylines.major
			y = apply(xf, Point2D(0, yline)).y
			drawline(ctx, Point2D(graphbb.xmin, y), Point2D(graphbb.xmax, y))
		end
	end
	if ylines.displayminor
		setlinestyle(ctx, lyt.line_gridminor)
		for yline in ylines.minor
			y = apply(xf, Point2D(0, yline)).y
			drawline(ctx, Point2D(graphbb.xmin, y), Point2D(graphbb.xmax, y))
		end
	end
end

function render_grid(ctx::CairoContext, rstrip::RStrip2D, lyt::PlotLayout, grid::GridRect)
	Cairo.save(ctx) #-----
	render_vlines(ctx, rstrip.bb, rstrip.xf, lyt, grid.xlines)
	render_hlines(ctx, rstrip.bb, rstrip.xf, lyt, grid.ylines)
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

render_ticklabel(ctx::CairoContext, val::DReal, pt::Point2D, font::Font, align::CAlignment, fmt::TickLabelFormatting, scale::LogScale{:e}) =
	render_power(ctx, "e", val, pt, font, align)
render_ticklabel(ctx::CairoContext, val::DReal, pt::Point2D, font::Font, align::CAlignment, fmt::TickLabelFormatting, scale::LogScale{2}) =
	render_power(ctx, "2", val, pt, font, align)
render_ticklabel(ctx::CairoContext, val::DReal, pt::Point2D, font::Font, align::CAlignment, fmt::TickLabelFormatting, scale::LogScale{10}) =
	render_power(ctx, "10", val, pt, font, align)

function render_axisscalelabel(ctx::CairoContext, pt::Point2D, font::Font, align::CAlignment, fmt::TickLabelFormatting, ::AxisScale)
	tstr = formatted_exp(fmt.fmt)
	render(ctx, tstr, pt, font, align=align)
end

#Render ticks: Well-defined GridLines
#-------------------------------------------------------------------------------
function render_xticks(ctx::CairoContext, rstrip::RStrip2D, lyt::PlotLayout, xlines::GridLines, ticklabels::Bool)
	graphbb = rstrip.bb
	xs = rstrip.xscale

	tframe = DReal(lyt.frame_data.line.width) #WANTCONST TODO: Fix LineAttributes to have concrete type
	fmt = TickLabelFormatting(lyt.format_xtick, xlines.rnginfo)
	yframe = graphbb.ymax
	ylabel = graphbb.ymax + lyt.voffset_xticklabel
	for xtick in xlines.major
		x = apply(rstrip.xf, Point2D(xtick, 0)).x
		if ticklabels
			render_ticklabel(ctx, xtick, Point2D(x, ylabel), lyt.font_ticklabel, ALIGN_TOP|ALIGN_HCENTER, fmt, xs)
		end
		drawline(ctx, Point2D(x, yframe), Point2D(x, yframe-lyt.length_tickmajor))
	end
	for xtick in xlines.minor
		x = apply(rstrip.xf, Point2D(xtick, 0)).x
		drawline(ctx, Point2D(x, yframe), Point2D(x, yframe-lyt.length_tickminor))
	end
	if fmt.splitexp && ticklabels
		xlabel = graphbb.xmax + tframe
		render_axisscalelabel(ctx, Point2D(xlabel, yframe), lyt.font_ticklabel, ALIGN_BOTTOM|ALIGN_LEFT, fmt, xs)
	end
end
function render_yticks(ctx::CairoContext, rstrip::RStrip2D, lyt::PlotLayout, ylines::GridLines)
	graphbb = rstrip.bb
	ys = rstrip.yscale
	tframe = DReal(lyt.frame_data.line.width) #WANTCONST TODO: Fix LineAttributes to have concrete type
	fmt = TickLabelFormatting(lyt.format_ytick, ylines.rnginfo)
	xframe = graphbb.xmin
	xlabel = graphbb.xmin - lyt.hoffset_yticklabel
	for ytick in ylines.major
		y = apply(rstrip.xf, Point2D(0, ytick)).y
		render_ticklabel(ctx, ytick, Point2D(xlabel, y), lyt.font_ticklabel, ALIGN_RIGHT|ALIGN_VCENTER, fmt, ys)
		drawline(ctx, Point2D(xframe, y), Point2D(xframe+lyt.length_tickmajor, y))
	end
	for ytick in ylines.minor
		y = apply(rstrip.xf, Point2D(0, ytick)).y
		drawline(ctx, Point2D(xframe, y), Point2D(xframe+lyt.length_tickminor, y))
	end
	if fmt.splitexp
		ylabel = graphbb.ymin - tframe
		render_axisscalelabel(ctx, Point2D(xframe, ylabel), lyt.font_ticklabel, ALIGN_BOTTOM|ALIGN_LEFT, fmt, ys)
	end
end
#Render ticks for colorscale (z-values)
function render_zticks(ctx::CairoContext, rstrip::RStrip2D, lyt::PlotLayout, csbb::BoundingBox,
		zext::PExtents1D, zlines::GridLines, zs::AxisScale)
	tframe = DReal(lyt.frame_colorscale.line.width) #WANTCONST TODO: Fix LineAttributes to have concrete type
	fmt = TickLabelFormatting(lyt.format_ztick, zlines.rnginfo)
	xf = LinearTransform(zext, csbb.ymax, csbb.ymin) #ymax corresponds to min z value
	xframe = csbb.xmax
	xlabel = xframe + lyt.hoffset_yticklabel
	for ztick in zlines.major
		y = apply(xf, ztick)
		render_ticklabel(ctx, ztick, Point2D(xlabel, y), lyt.font_ticklabel, ALIGN_LEFT|ALIGN_VCENTER, fmt, zs)
		drawline(ctx, Point2D(xframe, y), Point2D(xframe-lyt.length_tickmajor, y))
	end
	for ztick in zlines.minor
		y = apply(xf, ztick)
		drawline(ctx, Point2D(xframe, y), Point2D(xframe-lyt.length_tickminor, y))
	end
	if fmt.splitexp
		ylabel = csbb.ymin - tframe
		render_axisscalelabel(ctx, Point2D(xframe, ylabel), lyt.font_ticklabel, ALIGN_BOTTOM|ALIGN_RIGHT, fmt, zs)
	end
end

#Render ticks: UndefinedGridLines
#-------------------------------------------------------------------------------
function render_xticks(ctx::CairoContext, rstrip::RStrip2D, lyt::PlotLayout,
		xlines::UndefinedGridLines, ticklabels::Bool)
	graphbb = rstrip.bb
	fmt = TickLabelFormatting(NoRangeDisplayInfo())
	yframe = graphbb.ymax
	ylabel = graphbb.ymax + lyt.voffset_xticklabel
	for (x, xlabel) in [(graphbb.xmin, xlines.minline), (graphbb.xmax, xlines.maxline)]
		if ticklabels
			render_ticklabel(ctx, xlabel, Point2D(x, ylabel), lyt.font_ticklabel, ALIGN_TOP|ALIGN_HCENTER, fmt, LinScale())
		end
		drawline(ctx, Point2D(x, yframe), Point2D(x, yframe-lyt.length_tickmajor))
	end
end
function render_yticks(ctx::CairoContext, rstrip::RStrip2D, lyt::PlotLayout, ylines::UndefinedGridLines)
	fmt = TickLabelFormatting(NoRangeDisplayInfo())
	graphbb = rstrip.bb
	xframe = graphbb.xmin
	xlabel = graphbb.xmin - lyt.hoffset_yticklabel
	for (y, ylabel) in [(graphbb.ymax, ylines.minline), (graphbb.ymin, ylines.maxline)]
		render_ticklabel(ctx, ylabel, Point2D(xlabel, y), lyt.font_ticklabel, ALIGN_RIGHT|ALIGN_VCENTER, fmt, LinScale())
		drawline(ctx, Point2D(xframe, y), Point2D(xframe+lyt.length_tickmajor, y))
	end
end

function render_ticks(ctx::CairoContext, rstrip::RStrip2D, lyt::PlotLayout, xticklabels::Bool)
	#NOTE: Use coordinate grid (cgrid) to render ticks
	render_xticks(ctx, rstrip, lyt, rstrip.cgrid.xlines, xticklabels)
	render_yticks(ctx, rstrip, lyt, rstrip.cgrid.ylines)
end


#==High-level rendering
===============================================================================#

#Render axis labels, ticks, ...
#-------------------------------------------------------------------------------
function render_axes(ctx::CairoContext, rstrip::RStrip2D, lyt::PlotLayout, xticklabels::Bool)
	render_graphframe(ctx, rstrip, lyt.frame_data)
	render_ticks(ctx, rstrip, lyt, xticklabels)
end

#Last line
