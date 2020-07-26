#InspectDR: Edit plot layout within Gtk plot layer
#-------------------------------------------------------------------------------


#==Constants
===============================================================================#
const LAYOUTHANDLE_ALLOWANCE=3 #Distance (px): Allowance for marker hit test
const EDITINGLAYOUT_LINESTYLE = LineStyle(:dash, 3.0, COLOR_BLACK)
const EDITINGLAYOUT_TEXTBOX_AREAATTR = AreaAttributes(
	line=LineAttributes(:solid, 2, COLOR_BLACK),
	fillcolor=ARGB32(1, 1, 1, 0.8)
)
const LAYOUTELEM_LIST = [
	:valloc_top, :valloc_bottom, #:valloc_mid,
	:halloc_left, :halloc_right,
	:halloc_legend,
]


#==Types
===============================================================================#
#User input states
mutable struct ISWaitingToEditLayout <: InputState
end
mutable struct ISEditingLayout <: InputState #Mouse-move
	elem::Symbol
	v0::Float64 #Initial value (before editing)
	p0::Point2D #Start
	pmouse::Point2D #move
end
function ISEditingLayout(elem::Symbol, lyt, p0::Point2D)
	v0 = lyt[elem]
	ISEditingLayout(elem, v0, p0, p0)
end

#Info used to draw control elements for layout elements
struct LayoutControlInfo
	elem::Symbol
	ctrlline::Symbol #Where is the control line?: xmin, xmax, ymin or ymax
	bb::BoundingBox
	visible::Bool
end
LayoutControlInfo(elem, ctrlline, bb) = LayoutControlInfo(elem, ctrlline, bb, true)


#==Helper functions
===============================================================================#
isvert(lci::LayoutControlInfo) = lci.ctrlline == :ymin || lci.ctrlline == :ymax
isvert(elem::Symbol, lyt) =
	isvert(LayoutControlInfo(DS(elem), BoundingBox(0,0,0,0), lyt))

function _linepoints(lci::LayoutControlInfo)
	bb = lci.bb
	xmin, xmax = lci.bb.xmin, lci.bb.xmax
	ymin, ymax = lci.bb.ymin, lci.bb.ymax

	if :xmin == lci.ctrlline
		xmax = xmin
	elseif :xmax == lci.ctrlline
		xmin = xmax
	elseif :ymin == lci.ctrlline
		ymax = ymin
	elseif :ymax == lci.ctrlline
		ymin = ymax
	else
#		xmax = xmin
#		ymax = ymin
	end
	
	return (Point2D(xmin, ymin), Point2D(xmax, ymax))
end

function _computenewval(s::ISEditingLayout, lci::LayoutControlInfo)
	v = s.v0
	Δ = s.pmouse - s.p0
	if :xmin == lci.ctrlline
		v -= Δ.x
	elseif :xmax == lci.ctrlline
		v += Δ.x
	elseif :ymin == lci.ctrlline
		v -= Δ.y
	elseif :ymax == lci.ctrlline
		v += Δ.y
	end
	return round(v)
end


#==Layout control elements
===============================================================================#
function LayoutControlInfo(::DS{:valloc_top}, bb::BoundingBox, lyt)
	v = lyt[:valloc_top]
	return LayoutControlInfo(:valloc_top, :ymax,
		BoundingBox(bb.xmin, bb.xmax, bb.ymin, bb.ymin+v),
	)
end
function LayoutControlInfo(::DS{:valloc_bottom}, bb::BoundingBox, lyt)
	v = lyt[:valloc_bottom]
	return LayoutControlInfo(:valloc_bottom, :ymin,
		BoundingBox(bb.xmin, bb.xmax, bb.ymax-v, bb.ymax),
	)
end
function LayoutControlInfo(::DS{:halloc_left}, bb::BoundingBox, lyt)
	v = lyt[:halloc_left]
	return LayoutControlInfo(:halloc_left, :xmax,
		BoundingBox(bb.xmin, bb.xmin+v, bb.ymin, bb.ymax),
	)
end
function LayoutControlInfo(::DS{:halloc_right}, bb::BoundingBox, lyt)
	v = lyt[:halloc_right]
	xmax = bb.xmax# - lyt[:halloc_legend]
	return LayoutControlInfo(:halloc_right, :xmin,
		BoundingBox(xmax-v, xmax, bb.ymin, bb.ymax),
		!lyt[:enable_legend]
	)
end
function LayoutControlInfo(::DS{:halloc_legend}, bb::BoundingBox, lyt)
	v = lyt[:halloc_legend]
	return LayoutControlInfo(:halloc_legend, :xmin,
		BoundingBox(bb.xmax-v, bb.xmax, bb.ymin, bb.ymax),
		lyt[:enable_legend]
	)
end


#==Hit test
===============================================================================#
function hittest(lci::LayoutControlInfo, x::Float64, y::Float64)
	if !lci.visible; return false; end
	v = getfield(lci.bb, lci.ctrlline)
	if isvert(lci)
		return abs(y-v) <= LAYOUTHANDLE_ALLOWANCE
	else
		return abs(x-v) <= LAYOUTHANDLE_ALLOWANCE
	end
end


#==Draw functions
===============================================================================#
function editlyt_drawelem(ctx::CairoContext, bb::BoundingBox, elem::Symbol, lyt)
	lci = LayoutControlInfo(DS(elem), bb, lyt)
	if !lci.visible; return; end
	p1, p2 = _linepoints(lci)

	Cairo.save(ctx) #-----
	setlinestyle(ctx, EDITINGLAYOUT_LINESTYLE)
	drawline(ctx, p1, p2)
	Cairo.stroke(ctx)
	Cairo.restore(ctx) #-----
	return
end

function editlyt_drawall(ctx::CairoContext, bb::BoundingBox, lyt)
	for elem in LAYOUTELEM_LIST
		editlyt_drawelem(ctx, bb, elem, lyt)
	end
end

function editlyt_draweleminfo(ctx::CairoContext, bb::BoundingBox, elem::Symbol, lyt)
	v = lyt[elem]
	msg = ":$elem = $v"

	Cairo.save(ctx) #-----
	font = lyt[:font_annotation]
	setfont(ctx, font)
	w, h = textextents_wh(ctx, msg)
	Δ = h * 0.2
	bbann = BoundingBox(0, w+Δ, 0, h+Δ)
	ctr = Point2D(bbann.xmax/2, bbann.ymax/2)
	drawrectangle(ctx, bbann, EDITINGLAYOUT_TEXTBOX_AREAATTR)
	render(ctx, msg, ctr, font, align=ALIGN_HCENTER|ALIGN_VCENTER)
	Cairo.stroke(ctx)
	Cairo.restore(ctx) #-----
end

function drawoverlay(s::ISWaitingToEditLayout, w::PlotWidget, ctx::CairoContext, bb::BoundingBox)
	editlyt_drawall(ctx, bb, w.src.layout)
end
function drawoverlay(s::ISEditingLayout, w::PlotWidget, ctx::CairoContext, bb::BoundingBox)
	editlyt_drawelem(ctx, bb, s.elem, w.src.layout)
	editlyt_draweleminfo(ctx, bb, s.elem, w.src.layout)
end


#==State-dependent functions
===============================================================================#
function hittest(s::ISWaitingToEditLayout, pwidget::PlotWidget, x::Float64, y::Float64)
	lyt = pwidget.src.layout
	for elem in LAYOUTELEM_LIST
		lci = LayoutControlInfo(DS(elem), pwidget.rplot.bb, lyt)
		if hittest(lci, x, y)
			return lci
		end
	end
	return nothing
end

function editlyt_hover(s::ISWaitingToEditLayout, pwidget::PlotWidget, x::Float64, y::Float64)
	lci = hittest(s, pwidget, x, y)
	if nothing == lci
		gdk_window_set_cursor(pwidget.canvas, CURSOR_DEFAULT)
		return
	end

	csr = isvert(lci) ? CURSOR_ROWRESIZE : CURSOR_COLRESIZE
	gdk_window_set_cursor(pwidget.canvas, csr)
	return lci
end

function editlyt_mousedown(s::ISWaitingToEditLayout, pwidget::PlotWidget, x::Float64, y::Float64)
	lci = editlyt_hover(s, pwidget, x, y) #Get right cursor, etc
	if nothing == lci
		return
	end
	pwidget.state = ISEditingLayout(lci.elem, pwidget.src.layout, Point2D(x,y))
	Gtk.draw(pwidget.canvas)
end

#Exit ISWaitingToEditLayout editing state 
function editlyt_exit(s::ISWaitingToEditLayout, pwidget::PlotWidget)
	setstate_normal(pwidget)
	refresh(pwidget, refreshdata=true) #Proper refresh when exiting
end

#Complete a layout mouse-move operation:
function editlyt_mousemove(s::ISEditingLayout, pwidget::PlotWidget, x::Float64, y::Float64)
	s.pmouse = Point2D(x, y)
	lci = LayoutControlInfo(DS(s.elem), pwidget.rplot.bb, pwidget.src.layout)
	pwidget.src.layout[s.elem] = _computenewval(s, lci)
	Gtk.draw(pwidget.canvas)
	return
end

function editlyt_mouseup(s::ISEditingLayout, pwidget::PlotWidget, x::Float64, y::Float64)
	#Already modified value.  Just revert to wait state:
	pwidget.state = ISWaitingToEditLayout()
	refresh(pwidget, refreshdata=true)
end

function editlyt_cancel(s::ISEditingLayout, pwidget::PlotWidget)
	pwidget.state = ISWaitingToEditLayout() #before resetting layout value
	pwidget.src.layout[s.elem] = s.v0
	Gtk.draw(pwidget.canvas)
end


#==Event handlers for state: ISWaitingToEditLayout
===============================================================================#
function handleevent_keypress(s::ISWaitingToEditLayout, pwidget::PlotWidget, event::Gtk.GdkEventKey)
	if GdkKeySyms.Escape == event.keyval
		editlyt_exit(s, pwidget)
	end
end
function handleevent_mousemove(s::ISWaitingToEditLayout, pwidget::PlotWidget, event::Gtk.GdkEventMotion)
	editlyt_hover(s, pwidget, event.x, event.y)
end
function handleevent_mousepress(s::ISWaitingToEditLayout, pwidget::PlotWidget, event::Gtk.GdkEventButton)
	set_focus(pwidget) #In case not in focus

	if 1==event.button
		editlyt_mousedown(s, pwidget, event.x, event.y)
	end
end


#==Event handlers for state: ISEditingLayout (change properties)
===============================================================================#
function handleevent_keypress(s::ISEditingLayout, pwidget::PlotWidget, event::Gtk.GdkEventKey)
	if GdkKeySyms.Escape == event.keyval
		editlyt_cancel(s, pwidget)
	end
end

function handleevent_mouserelease(s::ISEditingLayout, pwidget::PlotWidget, event::Gtk.GdkEventButton)
	if 1==event.button
		editlyt_mouseup(s, pwidget, event.x, event.y)
	end
end
function handleevent_mousemove(s::ISEditingLayout, pwidget::PlotWidget, event::Gtk.GdkEventMotion)
	#handleevent_plothover(pwidget, event)
	editlyt_mousemove(s, pwidget, event.x, event.y)
end
function handleevent_mousepress(s::ISEditingLayout, pwidget::PlotWidget, event::Gtk.GdkEventButton)
	set_focus(pwidget) #In case not in focus
end


#==Switch to layout-editing state
===============================================================================#
function setstate_editlayout(pwidget::PlotWidget)
	pwidget.state = ISWaitingToEditLayout()
end


#Last line
