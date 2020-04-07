#InspectDR: Top-level interface for Cairo layer
#-------------------------------------------------------------------------------

#Render base annotation (titles, axis labels, ...)
function render_baseannotation(ctx::CairoContext, rplot::RPlot2D, plot::Plot2D)
	lyt = plot.layout.values #WANTCONST
Cairo.save(ctx)
	drawrectangle(ctx, rplot.bb, lyt.frame_canvas)
Cairo.restore(ctx)
	render_baseannotation(ctx, rplot, lyt, plot.annotation)
end

#Render axes & grid lines (graph area)
function render_axes(ctx::CairoContext, rplot::RPlot2D, plot::Plot2D)
	lyt = plot.layout.values #WANTCONST

	#Render titles, axis labels, ...
	render_baseannotation(ctx, rplot, plot.layout.values, plot.annotation)

	nstrips = length(rplot.strips)
	for rstrip in rplot.strips
		render_xticklabels = (rstrip.istrip == nstrips) #Only bottom-most graph
	Cairo.save(ctx)
		drawrectangle(ctx, rstrip.bb, lyt.frame_data)
	Cairo.restore(ctx)
		render_grid(ctx, rstrip, lyt, rstrip.grid)
		render_axes(ctx, rstrip, lyt, render_xticklabels)
	end
	return
end

#Render actual plot data
#-------------------------------------------------------------------------------
function render_data(ctx::CairoContext, rstrip::RStrip2D, plot::Plot2D)
Cairo.save(ctx)
	setclip(ctx, rstrip.bb)

	render(ctx, rstrip, plot.display_data_heat)
	render(ctx, rstrip, plot.display_data)
	if plot.displayNaN
		rendernans(ctx, rstrip, plot.data)
	end
Cairo.restore(ctx)
end
function render_data(ctx::CairoContext, rplot::RPlot2D, plot::Plot2D)
	for rstrip in rplot.strips
		render_data(ctx, rstrip, plot)
	end
end


#Render secondary plot annotation & redraw frame:
#-------------------------------------------------------------------------------
function render_userannotation(ctx::CairoContext, rstrip::RStrip2D, plot::Plot2D)
Cairo.save(ctx)
	setclip(ctx, rstrip.bb)
	render(ctx, rstrip, plot.userannot)
	render(ctx, rstrip, plot.parentannot)
Cairo.restore(ctx)

	render_graphframe(ctx, rstrip, plot.layout.values.frame_data) #Redraw frame
	#TODO: should we be more careful about setclip() - instead of redrawing frame?
end
function render_userannotation(ctx::CairoContext, rplot::RPlot2D, plot::Plot2D)
	for rstrip in rplot.strips
		render_userannotation(ctx, rstrip, plot)
	end
end

#Render entire plot using provided context (static images):
#-------------------------------------------------------------------------------
#TODO: Should base API be written such that user provides databb, and have
#      InspectDR calculate outwards instead?
function render(ctx::CairoContext, plot::Plot2D, bb::BoundingBox)
	refresh!(plot.layout) #Copy in values from defaults
	update_ddata(plot) #Also computes new extents
	rplot = RPlot2D(plot, bb)

	_reset(ctx) #Ensure known state.
	render_baseannotation(ctx, rplot, plot)
	render_axes(ctx, rplot, plot)
	render_legends(ctx, rplot, plot)
	render_data(ctx, rplot, plot)
	render_userannotation(ctx, rplot, plot)

	return rplot #So parent/caller can position objects/format data
end

#Render entire plot plot using CairoBufferedPlot (GUI optimization):
#-------------------------------------------------------------------------------
#TODO: split in parts so that GUI can be refreshed before refreshing data
#TODO: Or maybe send in final context so it can be done here.
function render(bplot::CairoBufferedPlot, plot::Plot2D, bb::BoundingBox, refreshdata::Bool)
	refresh!(plot.layout) #Copy in values from defaults
	refreshed = false
	if refreshdata
		update_ddata(plot) #Also computes new extents
		#TODO: don't refresh data if !refresh && bounding box did not change??
	end
	rplot = RPlot2D(plot, bb)

	ctx = CairoContext(bplot.surf)
	_reset(ctx); clear(ctx)
	render_baseannotation(ctx, rplot, plot)
	render_axes(ctx, rplot, plot)
	render_legends(ctx, rplot, plot)

	if refreshdata #Update data surface:
		ctxdata = CairoContext(bplot.data)
		_reset(ctxdata); clear(ctxdata)
		render_data(ctxdata, rplot, plot)
		Cairo.destroy(ctxdata)
	end

	#Now render data portion onto main context:
	Cairo.set_source_surface(ctx, bplot.data, 0, 0)
	Cairo.paint(ctx) #Applies contents of bplot.data

	render_userannotation(ctx, rplot, plot)
	Cairo.destroy(ctx)

	return rplot #So parent/caller can position objects/format data
end

#Last line
