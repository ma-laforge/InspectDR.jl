#InspectDR: Support for zoom
#-------------------------------------------------------------------------------


#==Drawing functions
===============================================================================#
function selectionbox_draw(ctx::CairoContext, sel::GtkSelection)
	if !sel.enabled; return; end

	Cairo.save(ctx) #-----
	Cairo.set_source(ctx, COLOR_BLACK)
	_set_stylewidth(ctx, :dash, 1.0)
	Cairo.rectangle(ctx, sel.bb)
	Cairo.stroke(ctx)
	Cairo.restore(ctx) #-----

	nothing
end


#==Main functions
===============================================================================#

#Enable/disable scale control widgets
function scalectrl_enabled(gplot::GtkPlot)
	return Gtk.GAccessor.sensitive(gplot.w_xscale)
end
function scalectrl_enabled(gplot::GtkPlot, v::Bool)
	Gtk.GAccessor.sensitive(gplot.w_xscale, v)
	Gtk.GAccessor.sensitive(gplot.w_xpos, v)
	focus(gplot.widget)
end

function zoom(gplot::GtkPlot, bb::BoundingBox)
	p1 = Point2D(bb.xmin, bb.ymin)
	p2 = Point2D(bb.xmax, bb.ymax)

	ext = getextents(gplot.src)
	xf = Transform2D(ext, gplot.graphbb)
	p1 = ptmap_rev(xf, p1)
	p2 = ptmap_rev(xf, p2)

	setextents(gplot.src, PExtents2D(
		min(p1.x, p2.x), max(p1.x, p2.x),
		min(p1.y, p2.y), max(p1.y, p2.y)
	))
	render(gplot)
	Gtk.draw(gplot.canvas)
end

function zoom_full(gplot::GtkPlot)
	gplot.src.ext = PExtents2D() #Reset active extents
	scalectrl_enabled(gplot, false) #Suppress updates from setproperty!
	setproperty!(gplot.xscale, :value, Int(1))
	setproperty!(gplot.xpos, :value, Float64(0))
	scalectrl_enabled(gplot, true)
	handleevent_scalechanged(gplot)
end


#==Event handlers
===============================================================================#

#Event handler for changes to the plot scale/position scrollbars:
#-------------------------------------------------------------------------------
function handleevent_scalechanged(gplot::GtkPlot)
	xscale = getproperty(gplot.xscale, :value, Int)
	xpos = getproperty(gplot.xpos, :value, Float64)
	emax = gplot.src.ext_max
	span = emax.xmax - emax.xmin
	center = (emax.xmax + emax.xmin) / 2
	vspan = span/xscale #Visible span
	xmin = center + span*xpos - vspan/2
	xmax = xmin + vspan
	setextents(gplot.src, PExtents2D(xmin, xmax, DNaN, DNaN))
	render(gplot)
	Gtk.draw(gplot.canvas)
end

#-------------------------------------------------------------------------------
function handleevent_mousepress(gplot::GtkPlot, event::Gtk.GdkEventButton)
#	@show event.state, event.button, event.event_type
	if 3==event.button
		gplot.sel.enabled = true
		x = event.x; y = event.y
		gplot.sel.bb = BoundingBox(x, x, y, y)
	end
end
function handleevent_mouserelease(gplot::GtkPlot, event::Gtk.GdkEventButton)
	if 3==event.button
		gplot.sel.enabled = false
		scalectrl_enabled(gplot, false)
		bb = gplot.sel.bb
		gplot.sel.bb = BoundingBox(bb.xmin, event.x, bb.ymin, event.y)
		zoom(gplot, gplot.sel.bb)
	end
end
function handleevent_mousemove(gplot::GtkPlot, event::Gtk.GdkEventMotion)
	if gplot.sel.enabled
		bb = gplot.sel.bb
		gplot.sel.bb = BoundingBox(bb.xmin, event.x, bb.ymin, event.y)	
		Gtk.draw(gplot.canvas)
	end
end


#Last line
