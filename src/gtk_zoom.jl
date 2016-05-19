#InspectDR: Support for pan/zoom
#-------------------------------------------------------------------------------


#==Constants
===============================================================================#
const PAN_STEPRATIO = 0.25 #Percentage of current extents
const ZOOM_STEPRATIO = 2.0 #How much to zoom in/out with mousewheel + keybindings


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


#==Scale/position widget control
===============================================================================#
function scalectrl_enabled(gplot::GtkPlot)
	return Gtk.GAccessor.sensitive(gplot.w_xscale)
end
function scalectrl_enabled(gplot::GtkPlot, v::Bool)
	Gtk.GAccessor.sensitive(gplot.w_xscale, v)
	Gtk.GAccessor.sensitive(gplot.w_xpos, v)
end
#Apply current scale/position scrollbar values to plot extents:
function scalectrl_apply(gplot::GtkPlot)
	xscale = getproperty(gplot.xscale, :value, Int)
	xpos = getproperty(gplot.xpos, :value, Float64)

	#Use transformed coordinate system:
	ext_full = rescale(getextents_full(gplot.src), gplot.src.axes)
	span = ext_full.xmax - ext_full.xmin
	center = (ext_full.xmax + ext_full.xmin) / 2
	vspan = span/xscale #Visible span
	xmin = center + span*xpos - vspan/2
	xmax = xmin + vspan

	#Update extents & redraw
	ext_new = PExtents2D(xmin, xmax, DNaN, DNaN)
	ext = merge(getextents_xfrm(gplot.src), ext_new)
	setextents_xfrm(gplot.src, ext)
	render(gplot)
	Gtk.draw(gplot.canvas)
end


#==Basic zoom control
===============================================================================#
#Zoom to bounding box (in device coordinates):
function zoom(gplot::GtkPlot, bb::BoundingBox)
	p1 = Point2D(bb.xmin, bb.ymin)
	p2 = Point2D(bb.xmax, bb.ymax)

	ext = getextents_xfrm(gplot.src)
	xf = Transform2D(ext, gplot.graphbb)
	p1 = ptmap_rev(xf, p1)
	p2 = ptmap_rev(xf, p2)

	setextents_xfrm(gplot.src, PExtents2D(
		min(p1.x, p2.x), max(p1.x, p2.x),
		min(p1.y, p2.y), max(p1.y, p2.y)
	))
	scalectrl_enabled(gplot, false) #Scroll bar control no longer valid
	render(gplot)
	Gtk.draw(gplot.canvas)
end

#Zoom in/out @ point (pt in plot coordinates)
function zoom(gplot::GtkPlot, ext::PExtents2D, pt::Point2D, ratio::Float64)
	xspan = ext.xmax - ext.xmin
	yspan = ext.ymax - ext.ymin
	Δx = pt.x - ext.xmin
	Δy = pt.y - ext.ymin
	xmin = pt.x-ratio*Δx
	ymin = pt.y-ratio*Δy

	setextents_xfrm(gplot.src, PExtents2D(
		xmin, xmin + ratio*xspan,
		ymin, ymin + ratio*yspan
	))
	scalectrl_enabled(gplot, false) #Scroll bar control no longer valid
	render(gplot)
	Gtk.draw(gplot.canvas)
end

#Zoom in/out, centered on current extents
function zoom(gplot::GtkPlot, ratio::Float64)
	ext = getextents_xfrm(gplot.src)
	pt = Point2D((ext.xmin+ext.xmax)/2, (ext.ymin+ext.ymax)/2)
	zoom(gplot, ext, pt, ratio)
end
zoom_out(gplot::GtkPlot, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom(gplot, stepratio)
zoom_in(gplot::GtkPlot, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom(gplot, 1/stepratio)

#Zoom in/out around specified device coordinates:
function zoom(gplot::GtkPlot, x::Float64, y::Float64, ratio::Float64)
	pt = Point2D(x, y)
	ext = getextents_xfrm(gplot.src)
	xf = Transform2D(ext, gplot.graphbb)
	pt = ptmap_rev(xf, pt)
	zoom(gplot, ext, pt, ratio)
end
zoom_out(gplot::GtkPlot, x::Float64, y::Float64, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom(gplot, x, y, stepratio)
zoom_in(gplot::GtkPlot, x::Float64, y::Float64, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom(gplot, x, y, 1/stepratio)

function zoom_xfull(gplot::GtkPlot)
	#TODO
end
function zoom_full(gplot::GtkPlot)
	setextents(gplot.src, PExtents2D()) #Reset active extents
	scalectrl_enabled(gplot, false) #Suppress updates from setproperty!
	setproperty!(gplot.xscale, :value, Int(1))
	setproperty!(gplot.xpos, :value, Float64(0))
	scalectrl_enabled(gplot, true)
	scalectrl_apply(gplot)
end


#==Box-zoom control
===============================================================================#
function boxzoom_setstart(gplot::GtkPlot, x::Float64, y::Float64)
	gplot.sel.enabled = true
	gplot.sel.bb = BoundingBox(x, x, y, y)
end
function boxzoom_cancel(gplot::GtkPlot)
	gplot.sel.enabled = false
	Gtk.draw(gplot.canvas)
end
function boxzoom_complete(gplot::GtkPlot, x::Float64, y::Float64)
	gplot.sel.enabled = false
	bb = gplot.sel.bb
	gplot.sel.bb = BoundingBox(bb.xmin, x, bb.ymin, y)
	zoom(gplot, gplot.sel.bb)
end
#Set end point of boxzoom area:
function boxzoom_setend(gplot::GtkPlot, x::Float64, y::Float64)
	bb = gplot.sel.bb
	gplot.sel.bb = BoundingBox(bb.xmin, x, bb.ymin, y)	
	Gtk.draw(gplot.canvas)
end


#==Pan control
===============================================================================#
function pan_xratio(gplot::GtkPlot, panstepratio::Float64)
	ext = getextents_xfrm(gplot.src)
	panstep = panstepratio*(ext.xmax-ext.xmin)
	setextents_xfrm(gplot.src, PExtents2D(
		ext.xmin+panstep, ext.xmax+panstep,
		ext.ymin, ext.ymax
	))
	scalectrl_enabled(gplot, false) #Scroll bar control no longer valid
	render(gplot)
	Gtk.draw(gplot.canvas)
end
function pan_yratio(gplot::GtkPlot, panstepratio::Float64)
	ext = getextents_xfrm(gplot.src)
	panstep = panstepratio*(ext.ymax-ext.ymin)
	setextents_xfrm(gplot.src, PExtents2D(
		ext.xmin, ext.xmax,
		ext.ymin+panstep, ext.ymax+panstep
	))
	render(gplot)
	Gtk.draw(gplot.canvas)
end

pan_left(gplot::GtkPlot) = pan_xratio(gplot, -PAN_STEPRATIO)
pan_right(gplot::GtkPlot) = pan_xratio(gplot, PAN_STEPRATIO)
pan_up(gplot::GtkPlot) = pan_yratio(gplot, PAN_STEPRATIO)
pan_down(gplot::GtkPlot) = pan_yratio(gplot, -PAN_STEPRATIO)


#Last line
