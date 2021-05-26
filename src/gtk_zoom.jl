#InspectDR: Support for pan/zoom
#-------------------------------------------------------------------------------


#==Constants
===============================================================================#
const PAN_STEPRATIO = 0.25 #Percentage of current extents
const ZOOM_STEPRATIO = 2.0 #How much to zoom in/out with mousewheel + keybindings
const SELECTIONBOX_LINESTYLE = LineStyle(:dash, 1.0, COLOR_BLACK)


#==Types
===============================================================================#
#Restrict x/y changes for pan/zoom operations:
struct AxisLock
	x::Bool
	y::Bool
end
AxisLock() = AxisLock(false, false)

#User input states
mutable struct ISPanningData <: InputState #Typically with mouse
	p0::Point2D #Start
	pmouse::Point2D #move
	ext_start::PExtents2D #Extents @ start of operation
	#Store ext_start to avoid accumulation of numerical errors.
	lock::AxisLock
	istrip::Int
end
mutable struct ISSelectingArea <: InputState #Box-zoom
	bb::BoundingBox
	lock::AxisLock
	istrip::Int
end


#==Drawing functions
===============================================================================#
function selectionbox_draw(ctx::CairoContext, selbb::BoundingBox, graphbb::BoundingBox, lock::AxisLock)
	xmin = selbb.xmin; xmax = selbb.xmax
	ymin = selbb.ymin; ymax = selbb.ymax
	if lock.x
		xmin = graphbb.xmin
		xmax = graphbb.xmax
	end
	if lock.y
		ymin = graphbb.ymin
		ymax = graphbb.ymax
	end

	Cairo.save(ctx) #-----
	setlinestyle(ctx, SELECTIONBOX_LINESTYLE)
	Cairo.rectangle(ctx, BoundingBox(xmin, xmax, ymin, ymax))
	Cairo.stroke(ctx)
	Cairo.restore(ctx) #-----

	nothing
end

function drawoverlay(s::ISSelectingArea, ctx::CairoContext, rplot::RPlot2D, lyt)
	graphbb = rplot.strips[s.istrip].bb
	selectionbox_draw(ctx, s.bb, graphbb, s.lock)
end


#==X-axis scale/position control widget
===============================================================================#
function xaxisctrl_visible(pwidget::PlotWidget)
	return get_gtk_property(pwidget.w_xpos, :visible, Bool)
end
function xaxisctrl_visible(pwidget::PlotWidget, v::Bool)
	result = set_gtk_property!(pwidget.w_xpos, :visible, v)
	redraw(pwidget.w_xpos)
	return result
end
function xaxisctrl_enabled(pwidget::PlotWidget)
	return GAccessor.sensitive(pwidget.w_xpos)
end
function xaxisctrl_enabled(pwidget::PlotWidget, v::Bool)
	result = GAccessor.sensitive(pwidget.w_xpos, v)
	redraw(pwidget.w_xpos)
	return result
end
function xaxisctrl_update(pwidget::PlotWidget, xcenter::DReal, xspan::DReal)
	xspan = abs(xspan) #Don't yet support negative spans
	pwidget.region.xcenter = xcenter
	pwidget.region.xspan = xspan
	enabled = isfinite(xspan) && xspan > 0

	plot = pwidget.src
	ixf = InputXfrm1D(plot.xscale)
	xext_data = axis2aloc(getxextents_data(plot), ixf)
	#TODO: store xext_data in pwidget.region???
	xspan_data = xext_data.max - xext_data.min
	xnorm = (xcenter - xext_data.min) / xspan_data
	enabled = enabled && (xnorm >= 0 && xnorm <=1)

	step = 1/100; page = 1/10 #Defaults when using arrow keys; pgup/pgdn
	if enabled #Compute more appropriate step/page sizes
		nsteps = ceil((xspan_data/xspan)*AXISCTRL_STEPS_PER_WINDOW)
		step = 1/nsteps; page = 1/10
	end

	#Update values while disbled:
	xaxisctrl_enabled(pwidget, false)
	GAccessor.value(pwidget.w_xpos, xnorm) #set value
	GAccessor.increments(pwidget.w_xpos, step, page)

	xaxisctrl_enabled(pwidget, enabled)
	return enabled
end
function xaxisctrl_update(pwidget::PlotWidget) #Use current extents to update state
	plot = pwidget.src
	xext = getxextents_aloc(plot)
	xcenter = (xext.min+xext.max)/2
	xspan = xext.max-xext.min
	return xaxisctrl_update(pwidget, xcenter, xspan)
end
#Apply current scale/position scrollbar values to plot extents:
function xaxisctrl_apply(pwidget::PlotWidget)
	xpos = get_gtk_property(pwidget.xpos, :value, Float64)

	plot = pwidget.src #WANTCONST
	ixf = InputXfrm1D(plot.xscale) #WANTCONST

	#Use transformed coordinate system:
	xext_data = axis2aloc(getxextents_data(plot), ixf)
	xspan_data = xext_data.max - xext_data.min
	xcenter = xext_data.min + xpos*xspan_data
	pwidget.region.xcenter = xcenter
	xspan = pwidget.region.xspan
	xmin = xcenter - xspan/2
	xmax = xmin + xspan

	#Update extents & redraw
	xext_new = PExtents1D(xmin, xmax)
	xext = merge(getxextents_aloc(plot), xext_new)
	setxextents_aloc(plot, xext)

	refresh(pwidget, refreshdata=true)
	redraw(pwidget.w_xpos)
	return
end


#==State modifiers
===============================================================================#
#Change x/y lock (or releasing both)
function changelock(s::Union{ISPanningData,ISSelectingArea},
	pwidget::PlotWidget;	x = false, y = false)
	s.lock = AxisLock(x, y)
	refresh(pwidget, refreshdata=false)
end


#==Basic zoom control
===============================================================================#
#Zoom to bounding box (in device coordinates):
function _zoom_bb(pwidget::PlotWidget, bb::BoundingBox, lock::AxisLock, istrip::Int)
	p1 = Point2D(bb.xmin, bb.ymin)
	p2 = Point2D(bb.xmax, bb.ymax)

	rstrip = pwidget.rplot.strips[istrip]
	p1 = dev2aloc(rstrip, p1)
	p2 = dev2aloc(rstrip, p2)

	if !lock.x
		setxextents_aloc(pwidget.src, PExtents1D(min(p1.x, p2.x), max(p1.x, p2.x)))
	end

	if !lock.y
		setyextents_aloc(pwidget.src, PExtents1D(min(p1.y, p2.y), max(p1.y, p2.y)), istrip)
	end

	xaxisctrl_update(pwidget)
	refresh(pwidget, refreshdata=true)
end

#Zoom in/out @ point (pt in plot coordinates)
function zoom_byratio(pwidget::PlotWidget, ext::PExtents2D, pt::Point2D, ratio::Float64, istrip::Int)
	xspan = ext.xmax - ext.xmin
	yspan = ext.ymax - ext.ymin
	Δx = pt.x - ext.xmin
	Δy = pt.y - ext.ymin
	xmin = pt.x-ratio*Δx
	ymin = pt.y-ratio*Δy

	setxextents_aloc(pwidget.src, PExtents1D(xmin, xmin + ratio*xspan))
	setyextents_aloc(pwidget.src, PExtents1D(ymin, ymin + ratio*yspan), istrip)

	xaxisctrl_update(pwidget)
	refresh(pwidget, refreshdata=true)
end

#Zoom in/out, centered on current extents
function zoom_centered(pwidget::PlotWidget, ratio::Float64, istrip::Int)
	ext = pwidget.rplot.strips[istrip].ext
	pt = Point2D((ext.xmin+ext.xmax)/2, (ext.ymin+ext.ymax)/2)
	zoom_byratio(pwidget, ext, pt, ratio, istrip)
end
zoom_out(pwidget::PlotWidget, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom_centered(pwidget, stepratio, activestrip(pwidget))
zoom_in(pwidget::PlotWidget, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom_centered(pwidget, 1/stepratio, activestrip(pwidget))

#Zoom in/out around specified device coordinates:
function zoom_atpt(pwidget::PlotWidget, x::Float64, y::Float64, ratio::Float64, istrip::Int)
	rstrip = pwidget.rplot.strips[istrip]
	ext = rstrip.ext #(aloc coordinates)
	pt = dev2aloc(rstrip, Point2D(x, y))
	zoom_byratio(pwidget, ext, pt, ratio, istrip)
end
zoom_out(pwidget::PlotWidget, x::Float64, y::Float64, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom_atpt(pwidget, x, y, stepratio, activestrip(pwidget))
zoom_in(pwidget::PlotWidget, x::Float64, y::Float64, stepratio::Float64=ZOOM_STEPRATIO) =
	zoom_atpt(pwidget, x, y, 1/stepratio, activestrip(pwidget))

function zoom_xfull(pwidget::PlotWidget)
	#TODO
end
function _zoom_full(pwidget::PlotWidget, xlock::Bool, ylock::Bool, istrip::Int)
	#Reset desired extents:
	if !xlock
		setxextents(pwidget.src, PExtents1D())
	end
	if !ylock
		setyextents(pwidget.src, PExtents1D(), istrip)
	end

	xaxisctrl_update(pwidget)
	refresh(pwidget, refreshdata=true)
end
zoom_full(pwidget::PlotWidget, xlock::Bool=false, ylock::Bool=false) =
	_zoom_full(pwidget, xlock, ylock, activestrip(pwidget))
zoom_hfull(pwidget::PlotWidget) = zoom_full(pwidget, false, true)
zoom_vfull(pwidget::PlotWidget) = zoom_full(pwidget, true, false)


#==Box-zoom control
===============================================================================#
function boxzoom_setstart(pwidget::PlotWidget, x::Float64, y::Float64)
	bb = BoundingBox(x, x, y, y)
	istrip = activestrip(pwidget)
	gdk_window_set_cursor(pwidget.canvas, CURSOR_BOXSELECT)
	pwidget.state = ISSelectingArea(bb, AxisLock(), istrip)
	return
end
function boxzoom_cancel(s::ISSelectingArea, pwidget::PlotWidget)
	setstate_normal(pwidget)
	Gtk.draw(pwidget.canvas)
	return
end
function boxzoom_complete(s::ISSelectingArea, pwidget::PlotWidget, x::Float64, y::Float64)
	setstate_normal(pwidget)
	bb = BoundingBox(s.bb.xmin, x, s.bb.ymin, y)
	_zoom_bb(pwidget, bb, s.lock, s.istrip)
	return
end
#Change end point of boxzoom area:
function boxzoom_setend(s::ISSelectingArea, pwidget::PlotWidget, x::Float64, y::Float64)
	s.bb = BoundingBox(s.bb.xmin, x, s.bb.ymin, y)
	Gtk.draw(pwidget.canvas)
end


#==Basic pan control
===============================================================================#
function pan_xratio(pwidget::PlotWidget, panstepratio::Float64)
	xext = getxextents_aloc(pwidget.src)
	panstep = panstepratio*(xext.max-xext.min)
	setxextents_aloc(pwidget.src,
		PExtents1D(xext.min+panstep, xext.max+panstep))
	xaxisctrl_update(pwidget)
	refresh(pwidget, refreshdata=true)
end
function pan_yratio(pwidget::PlotWidget, panstepratio::Float64, istrip::Int)
	yext = getyextents_aloc(pwidget.src, istrip)
	panstep = panstepratio*(yext.max-yext.min)
	setyextents_aloc(pwidget.src,
		PExtents1D(yext.min+panstep, yext.max+panstep), istrip)
	refresh(pwidget, refreshdata=true)
end
pan_yratio(pwidget::PlotWidget, panstepratio::Float64) =
	pan_yratio(pwidget, panstepratio, activestrip(pwidget))

pan_left(pwidget::PlotWidget) = pan_xratio(pwidget, -PAN_STEPRATIO)
pan_right(pwidget::PlotWidget) = pan_xratio(pwidget, PAN_STEPRATIO)
pan_up(pwidget::PlotWidget) = pan_yratio(pwidget, PAN_STEPRATIO)
pan_down(pwidget::PlotWidget) = pan_yratio(pwidget, -PAN_STEPRATIO)


#==Mouse-pan control
===============================================================================#
#Apply changes from mouse-pan operation (Δy/Δy: in device coordinates):
function mousepan_delta(pwidget::PlotWidget, ext::PExtents2D, Δx::Float64, Δy::Float64,
   lock::AxisLock, istrip::Int
)
	#Convert to plot coordinates:
	rstrip = pwidget.rplot.strips[istrip]
	Δvec = apply_inv(rstrip.xf, Vector2D(-Δx, -Δy))

	setextents_aloc(pwidget.src, ext, istrip) #Restore original extents before overwriting

	if !lock.x
		setxextents_aloc(pwidget.src, PExtents1D(ext.xmin+Δvec.x, ext.xmax+Δvec.x))
	end
	if !lock.y
		setyextents_aloc(pwidget.src, PExtents1D(ext.ymin+Δvec.y, ext.ymax+Δvec.y), istrip)
	end

	xaxisctrl_update(pwidget)
	refresh(pwidget, refreshdata=true)
end
function mousepan_setstart(pwidget::PlotWidget, x::Float64, y::Float64)
	istrip = activestrip(pwidget)
	ext_start = pwidget.rplot.strips[istrip].ext
	p0 = Point2D(x, y)
	gdk_window_set_cursor(pwidget.canvas, CURSOR_PAN)
	pwidget.state = ISPanningData(p0, p0, ext_start, AxisLock(), istrip)
	return
end
function mousepan_cancel(s::ISPanningData, pwidget::PlotWidget)
	mousepan_delta(pwidget, s.ext_start, 0.0, 0.0, s.lock, s.istrip)
	setstate_normal(pwidget)
	return
end
function mousepan_complete(pwidget::PlotWidget, x::Float64, y::Float64)
	#Already panned.  Just revert to normal state:
	setstate_normal(pwidget)
	return
end
#Set new point of mousepan operation:
function mousepan_move(s::ISPanningData, pwidget::PlotWidget, x::Float64, y::Float64)
	s.pmouse = Point2D(x, y)
	Δx = s.pmouse.x-s.p0.x; Δy = s.pmouse.y-s.p0.y
	mousepan_delta(pwidget, s.ext_start, Δx, Δy, s.lock, s.istrip)
end


#==Event handlers for state: ISPanningData (Panning with mouse)
===============================================================================#
function handleevent_keypress(s::ISPanningData, pwidget::PlotWidget, event::Gtk.GdkEventKey)
	if GdkKeySyms.Escape == event.keyval
		mousepan_cancel(s, pwidget)
	elseif Int('h') == event.keyval || Int('H') == event.keyval
		changelock(s, pwidget, x=false, y=true)
	elseif Int('v') == event.keyval || Int('V') == event.keyval
		changelock(s, pwidget, x=true, y=false)
	elseif Int('b') == event.keyval || Int('B') == event.keyval
		changelock(s, pwidget, x=false, y=false)
	end
end
function handleevent_mouserelease(::ISPanningData, pwidget::PlotWidget, event::Gtk.GdkEventButton)
	if 1==event.button
		mousepan_complete(pwidget, event.x, event.y)
	end
end
function handleevent_mousemove(s::ISPanningData, pwidget::PlotWidget, event::Gtk.GdkEventMotion)
	handleevent_plothover(pwidget, event)
	mousepan_move(s, pwidget, event.x, event.y)
end


#==Event handlers for state: ISSelectingArea (for box-zoom)
===============================================================================#
function handleevent_keypress(s::ISSelectingArea, pwidget::PlotWidget, event::Gtk.GdkEventKey)
	if GdkKeySyms.Escape == event.keyval
		boxzoom_cancel(s, pwidget)
	elseif Int('h') == event.keyval
		changelock(s, pwidget, x=false, y=true)
	elseif Int('v') == event.keyval
		changelock(s, pwidget, x=true, y=false)
	elseif Int('b') == event.keyval
		changelock(s, pwidget, x=false, y=false)
	end
end
function handleevent_mouserelease(s::ISSelectingArea, pwidget::PlotWidget, event::Gtk.GdkEventButton)
	if 3==event.button
		boxzoom_complete(s, pwidget, event.x, event.y)
	end
end
function handleevent_mousemove(s::ISSelectingArea, pwidget::PlotWidget, event::Gtk.GdkEventMotion)
	handleevent_plothover(pwidget, event)
	boxzoom_setend(s, pwidget, event.x, event.y)
end


#Last line
