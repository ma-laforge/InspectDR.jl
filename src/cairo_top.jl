#InspectDR: Top-level interface for Cairo layer
#-------------------------------------------------------------------------------

#Render entire plot
#-------------------------------------------------------------------------------
function render(canvas::PCanvas2D, plot::Plot2D, xticklabels::Bool, istrip::Int)
	const strip = plot.strips[istrip]
	if plot.layout.legend.enabled
		legend_render(canvas, plot)
	end

	#Draw data area & grid lines
Cairo.save(canvas.ctx)
	drawrectangle(canvas.ctx, canvas.graphbb, plot.layout.framedata)
Cairo.restore(canvas.ctx)
	grid = _eval(strip.grid, plot.xscale, strip.yscale, canvas.ext)
	render_grid(canvas, plot.layout, grid)

	#Plot actual data
Cairo.save(canvas.ctx)
	setclip(canvas.ctx, canvas.graphbb)

	render(canvas, plot.display_data, istrip)
	if plot.displayNaN
		rendernans(canvas, plot.data, istrip)
	end

	#Plot secondary annotation:
	ixf = InputXfrm2D(plot.xscale, strip.yscale)
	render(canvas, plot.markers, ixf, istrip)
	render(canvas, plot.atext, ixf, istrip)
	render(canvas, plot.apline, ixf, istrip)
Cairo.restore(canvas.ctx)

	#Re-render axis over data:
	render_axes(canvas, plot.layout, grid, plot.xscale, strip.yscale, xticklabels)
	return
end

#Render entire plot within provided bounding box:
#TODO: Should base API be written such that user provides databb, and have
#      InspectDR calculate outwards instead?
function render(ctx::CairoContext, plot::Plot2D, bb::BoundingBox)
	const lyt = plot.layout
	const databb = databounds(bb, lyt, grid1(plot))

	_reset(ctx)
Cairo.save(ctx)
	drawrectangle(ctx, bb, lyt.frame)
Cairo.restore(ctx)

	#Render annotation
	graphbblist = graphbounds_list(databb, lyt, length(plot.strips))
	render(ctx, plot.annotation, bb, databb, graphbblist, lyt)

	update_ddata(plot) #Also computes new extents

	nstrips = length(plot.strips)
	for i in 1:nstrips
		graphbb = graphbounds(databb, lyt, nstrips, i)
		canvas = PCanvas2D(ctx, bb, graphbb, getextents_axis(plot, i))
		#TODO: Render all non-data elements *before* plotting once drawing is multi-threaded.

		render_xticklabels = (i == nstrips) #Only bottom-most graph
		render(canvas, plot, render_xticklabels, i)
	end

	return
end

#Last line
