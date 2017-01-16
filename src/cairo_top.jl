#InspectDR: Top-level interface for Cairo layer
#-------------------------------------------------------------------------------

#Render entire plot
#-------------------------------------------------------------------------------
function render(canvas::PCanvas2D, plot::Plot2D)
	#Render annotation/axes
	render(canvas, plot.annotation, plot.layout)
	if plot.layout.legend.enabled
		legend_render(canvas, plot)
	end

	#Draw data area & grid lines
Cairo.save(canvas.ctx)
	drawrectangle(canvas.ctx, canvas.graphbb, plot.layout.framedata)
Cairo.restore(canvas.ctx)
	grid = gridlines(plot.axes, canvas.ext)
	render_grid(canvas, plot.layout, grid)
	#TODO: render axes first once drawing is multi-threaded.
#	render_axes

	#Plot actual data
Cairo.save(canvas.ctx)
	setclip(canvas.ctx, canvas.graphbb)

	render(canvas, plot.display_data)
	if plot.displayNaN
		rendernans(canvas, plot.data)
	end

	#Plot secondary annotation:
	render(canvas, plot.markers, plot.axes)
	render(canvas, plot.atext, plot.axes)
	render(canvas, plot.apline, plot.axes)
Cairo.restore(canvas.ctx)

	#Re-render axis over data:
	render_axes(canvas, plot.layout, grid)
end

#Render entire plot within provided bounding box:
function render(ctx::CairoContext, plot::Plot2D, bb::BoundingBox)
	_reset(ctx)
	graphbb = graphbounds(bb, plot.layout, plot.axes)
	update_ddata(plot) #Also computes new extents
Cairo.save(ctx)
	drawrectangle(ctx, bb, plot.layout.frame)
Cairo.restore(ctx)
	canvas = PCanvas2D(ctx, bb, graphbb, getextents_xfrm(plot))
	render(canvas, plot)
end

#Last line
