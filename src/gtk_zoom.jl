#InspectDR: Support for pan/zoom
#-------------------------------------------------------------------------------


#==Constants
===============================================================================#
const PAN_STEPRATIO = 0.25 #Percentage of current extents
const ZOOM_STEPRATIO = 2.0 #How much to zoom in/out with mousewheel + keybindings


#==Drawing functions
===============================================================================#
function selectionbox_draw(ctx::CairoContext, selbb::BoundingBox, graphbb::BoundingBox, hallowed::Bool, vallowed::Bool)
	xmin = selbb.xmin; xmax = selbb.xmax
	ymin = selbb.ymin; ymax = selbb.ymax
	if !hallowed
		xmin = graphbb.xmin
		xmax = graphbb.xmax
	end
	if !vallowed
		ymin = graphbb.ymin
		ymax = graphbb.ymax
	end

	Cairo.save(ctx) #-----
	Cairo.set_source(ctx, COLOR_BLACK)
	setlinestyle(ctx, :dash, 1.0)
	Cairo.rectangle(ctx, BoundingBox(xmin, xmax, ymin, ymax))
	Cairo.stroke(ctx)
	Cairo.restore(ctx) #-----

	nothing
end

function selectionbox_draw(ctx::CairoContext, w::PlotWidget)
	if !w.sel.enabled; return; end
	selectionbox_draw(ctx, w.sel.bb, w.graphbb, w.hallowed, w.vallowed)
end


#==Switching to h/v lock (or releasing both)
===============================================================================#
function locdir_h(pwidget::PlotWidget)
	pwidget.hallowed = true
	pwidget.vallowed = false
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end
function locdir_v(pwidget::PlotWidget)
	pwidget.hallowed = false
	pwidget.vallowed = true
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end
function locdir_any(pwidget::PlotWidget)
	pwidget.hallowed = true
	pwidget.vallowed = true
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end


#==Scale/position widget control
===============================================================================#
function scalectrl_enabled(pwidget::PlotWidget)
	return Gtk.GAccessor.sensitive(pwidget.w_xscale)
end
function scalectrl_enabled(pwidget::PlotWidget, v::Bool)
	Gtk.GAccessor.sensitive(pwidget.w_xscale, v)
	Gtk.GAccessor.sensitive(pwidget.w_xpos, v)
end
#Apply current scale/position scrollbar values to plot extents:
function scalectrl_apply(pwidget::PlotWidget)
	xscale = getproperty(pwidget.xscale, :value, Int)
	xpos = getproperty(pwidget.xpos, :value, Float64)

	#Use transformed coordinate system:
	ext_full = rescale(getextents_full(pwidget.src), pwidget.src.axes)
	span = ext_full.xmax - ext_full.xmin
	center = (ext_full.xmax + ext_full.xmin) / 2
	vspan = span/xscale #Visible span
	xmin = center + span*xpos - vspan/2
	xmax = xmin + vspan

	#Update extents & redraw
	ext_new = PExtents2D(xmin, xmax, DNaN, DNaN)
	ext = merge(getextents_xfrm(pwidget.src), ext_new)
	setextents_xfrm(pwidget.src, ext)
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end


#==Basic zoom control
===============================================================================#
#Zoom to bounding box (in device coordinates):
function zoom(pwidget::PlotWidget, bb::BoundingBox)
	p1 = Point2D(bb.xmin, bb.ymin)
	p2 = Point2D(bb.xmax, bb.ymax)

	ext = getextents_xfrm(pwidget.src)
	xf = Transform2D(ext, pwidget.graphbb)
	p1 = ptmap_rev(xf, p1)
	p2 = ptmap_rev(xf, p2)

	setextents_xfrm(pwidget.src, PExtents2D(
		min(p1.x, p2.x), max(p1.x, p2.x),
		min(p1.y, p2.y), max(p1.y, p2.y)),
		pwidget.hallowed, pwidget.vallowed
	)
	scalectrl_enabled(pwidget, false) #Scroll bar control no longer valid
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end

#Zoom in/out @ point (pt in plot coordinates)
function zoom(pwidget::PlotWidget, ext::PExtents2D, pt::Point2D, ratio::Float64)
	xspan = ext.xmax - ext.xmin
	yspan = ext.ymax - ext.ymin
	Δx = pt.x - ext.xmin
	Δy = pt.y - ext.ymin
	xmin = pt.x-ratio*Δx
	ymin = pt.y-ratio*Δy

	setextents_xfrm(pwidget.src, PExtents2D(
		xmin, xmin + ratio*xspan,
		ymin, ymin + ratio*yspan
	))
	scalectrl_enabled(pwidget, false) #Scroll bar control no longer valid
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end

#Zoom in/out, centered on current extents
function zoom(pwidget::PlotWidget, ratio::Float64)
	ext = getextents_xfrm(pwidget.src)
	pt = Point2D((ext.xmin+ext.xmax)/2, (ext.ymin+ext.ymax)/2)
	zoom(pwidget, ext, pt, ratio)
end
zoom_out(pwidget::PlotWidget, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom(pwidget, stepratio)
zoom_in(pwidget::PlotWidget, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom(pwidget, 1/stepratio)

#Zoom in/out around specified device coordinates:
function zoom(pwidget::PlotWidget, x::Float64, y::Float64, ratio::Float64)
	pt = Point2D(x, y)
	ext = getextents_xfrm(pwidget.src)
	xf = Transform2D(ext, pwidget.graphbb)
	pt = ptmap_rev(xf, pt)
	zoom(pwidget, ext, pt, ratio)
end
zoom_out(pwidget::PlotWidget, x::Float64, y::Float64, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom(pwidget, x, y, stepratio)
zoom_in(pwidget::PlotWidget, x::Float64, y::Float64, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom(pwidget, x, y, 1/stepratio)

function zoom_xfull(pwidget::PlotWidget)
	#TODO
end
function zoom_full(pwidget::PlotWidget, hallowed::Bool=true, vallowed::Bool=true)
	setextents(pwidget.src, PExtents2D(), hallowed, vallowed) #Reset desired extents
	if hallowed
		scalectrl_enabled(pwidget, false) #Suppress updates from setproperty!
		setproperty!(pwidget.xscale, :value, Int(1))
		setproperty!(pwidget.xpos, :value, Float64(0))
		scalectrl_enabled(pwidget, true)
		scalectrl_apply(pwidget)
	else
		render(pwidget)
		Gtk.draw(pwidget.canvas)
	end
end
zoom_hfull(pwidget::PlotWidget) = zoom_full(pwidget, true, false)
zoom_vfull(pwidget::PlotWidget) = zoom_full(pwidget, false, true)


#==Box-zoom control
===============================================================================#
function boxzoom_setstart(pwidget::PlotWidget, x::Float64, y::Float64)
	locdir_any(pwidget)
	pwidget.sel.enabled = true
	pwidget.sel.bb = BoundingBox(x, x, y, y)
end
function boxzoom_cancel(pwidget::PlotWidget)
	pwidget.sel.enabled = false
	Gtk.draw(pwidget.canvas)
end
function boxzoom_complete(pwidget::PlotWidget, x::Float64, y::Float64)
	pwidget.sel.enabled = false
	bb = pwidget.sel.bb
	pwidget.sel.bb = BoundingBox(bb.xmin, x, bb.ymin, y)
	zoom(pwidget, pwidget.sel.bb)
end
#Set end point of boxzoom area:
function boxzoom_setend(pwidget::PlotWidget, x::Float64, y::Float64)
	bb = pwidget.sel.bb
	pwidget.sel.bb = BoundingBox(bb.xmin, x, bb.ymin, y)	
	Gtk.draw(pwidget.canvas)
end


#==Basic pan control
===============================================================================#
function pan_xratio(pwidget::PlotWidget, panstepratio::Float64)
	ext = getextents_xfrm(pwidget.src)
	panstep = panstepratio*(ext.xmax-ext.xmin)
	setextents_xfrm(pwidget.src, PExtents2D(
		ext.xmin+panstep, ext.xmax+panstep,
		ext.ymin, ext.ymax
	))
	scalectrl_enabled(pwidget, false) #Scroll bar control no longer valid
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end
function pan_yratio(pwidget::PlotWidget, panstepratio::Float64)
	ext = getextents_xfrm(pwidget.src)
	panstep = panstepratio*(ext.ymax-ext.ymin)
	setextents_xfrm(pwidget.src, PExtents2D(
		ext.xmin, ext.xmax,
		ext.ymin+panstep, ext.ymax+panstep
	))
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end

pan_left(pwidget::PlotWidget) = pan_xratio(pwidget, -PAN_STEPRATIO)
pan_right(pwidget::PlotWidget) = pan_xratio(pwidget, PAN_STEPRATIO)
pan_up(pwidget::PlotWidget) = pan_yratio(pwidget, PAN_STEPRATIO)
pan_down(pwidget::PlotWidget) = pan_yratio(pwidget, -PAN_STEPRATIO)


#==Mouse-pan control
===============================================================================#
#Δy/Δy: in device coordinates
function mousepan_delta(pwidget::PlotWidget, ext::PExtents2D, Δx::Float64, Δy::Float64)
	#Convert to plot coordinates:
	xf = Transform2D(ext, pwidget.graphbb)
	Δvec = vecmap_rev(xf, Point2D(-Δx, -Δy))

	setextents_xfrm(pwidget.src, ext) #Restore original extents before overwriting
	setextents_xfrm(pwidget.src, PExtents2D(
		ext.xmin+Δvec.x, ext.xmax+Δvec.x,
		ext.ymin+Δvec.y, ext.ymax+Δvec.y),
		pwidget.hallowed, pwidget.vallowed
	)
	scalectrl_enabled(pwidget, false) #Scroll bar control no longer valid
	render(pwidget)
	Gtk.draw(pwidget.canvas)
end
function mousepan_setstart(pwidget::PlotWidget, x::Float64, y::Float64)
	locdir_any(pwidget)
	pwidget.sel.bb = BoundingBox(x, x, y, y) #Tracks start/end pos
	pwidget.sel.ext_start = getextents_xfrm(pwidget.src)
end
function mousepan_cancel(pwidget::PlotWidget)
	mousepan_delta(pwidget, pwidget.sel.ext_start, 0.0, 0.0)
end
function mousepan_complete(pwidget::PlotWidget, x::Float64, y::Float64)
	#Already panned.
end
#Set new point of mousepan operation:
function mousepan_move(pwidget::PlotWidget, x::Float64, y::Float64)
	bb = pwidget.sel.bb
	bb = BoundingBox(bb.xmin, x, bb.ymin, y)
	pwidget.sel.bb = bb
	Δx = bb.xmax-bb.xmin; Δy = bb.ymax-bb.ymin
	mousepan_delta(pwidget, pwidget.sel.ext_start, Δx, Δy)
end


#Last line
