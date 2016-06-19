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

	grid = gridlines(plot.axes, canvas.ext)
	render_grid(canvas, plot.layout, grid)
	#TODO: render axes first once drawing is multi-threaded.
#	render_axes

	#Plot actual data
Cairo.save(canvas.ctx)
	setclip(canvas.ctx, canvas.graphbb)
	render(canvas, plot.display_data)

	#Plot secondary annotation:
	render(canvas, plot.markers, plot.axes)
	render(canvas, plot.atext, plot.axes)

Cairo.restore(canvas.ctx)

	#Re-render axis over data:
	render_axes(canvas, plot.layout, grid)
end

#Render entire plot within provided bounding box:
function render(ctx::CairoContext, plot::Plot2D, bb::BoundingBox)
	graphbb = graphbounds(bb, plot.layout)
	update_ddata(plot) #Also computes new extents
	canvas = PCanvas2D(ctx, bb, graphbb, getextents_xfrm(plot))
	render(canvas, plot)
end

#Last line
