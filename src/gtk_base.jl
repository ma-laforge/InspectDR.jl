#InspectDR: Base functionnality and types for Gtk layer
#------------------------------ -------------------------------------------------

import Gtk: get_gtk_property, set_gtk_property!, signal_connect, @guarded

#Create module aliasese to access constants:
#TODO: Figure out why constants are Int32 instead of Int???
import Gtk: GAccessor, GtkPositionType
import Gtk: GdkKeySyms, GdkEventType, GdkEventMask
import Gtk: GConstants.GdkModifierType
import Gtk: GConstants.GtkShadowType
import Gtk: GConstants.GtkAccelFlags


#==Constants
===============================================================================#
#Control axis control widget behaviour:
const AXISCTRL_STEPS_PER_WINDOW = 4

const MODIFIER_ALT = GdkModifierType.GDK_MOD1_MASK #Is this bad? How do I query?
const MODIFIER_CTRL = GdkModifierType.GDK_CONTROL_MASK
const MODIFIER_SHIFT = GdkModifierType.GDK_SHIFT_MASK

#Other modifiers are ignored... ex: numlock (Mod2)
const MODIFIERS_SUPPORTED = MODIFIER_ALT|MODIFIER_CTRL|MODIFIER_SHIFT

const GTK_ACCEL_VISIBLE = GtkAccelFlags.GTK_ACCEL_VISIBLE


#==Extensions
===============================================================================#
#TODO: Why can't I just access these functions directly from Gtk/gen/gbox3???

function draw_value(scale::Gtk.GtkScale, draw_value_::Bool)
	ccall((:gtk_scale_set_draw_value,Gtk.libgtk),Nothing,(Ptr{Gtk.GObject},Cint),scale,draw_value_)
	return scale
end
function value_pos(scale::Gtk.GtkScale,pos::Int)
	ccall((:gtk_scale_set_value_pos,Gtk.libgtk),Nothing,(Ptr{Gtk.GObject},Cint),scale,pos)
	return scale
end

function can_focus(widget::Gtk.GtkWidget,can_focus_::Bool)
	ccall((:gtk_widget_set_can_focus,Gtk.libgtk),Nothing,(Ptr{Gtk.GObject},Cint),widget,can_focus_)
	return widget
end

function window_close(window::Gtk.GtkWindow)
	ccall((:gtk_window_close,Gtk.libgtk),Nothing,(Ptr{Gtk.GObject},),window)
	return
end

function set_focus(window::Gtk.GtkWindow,widget::Gtk.GtkWidget)
	ccall((:gtk_window_set_focus,Gtk.libgtk),Nothing,(Ptr{Gtk.GObject},Ptr{Gtk.GObject}),window,widget)
	return window
end
function set_focus(widget::Gtk.GtkWidget)
	ccall((:gtk_widget_grab_focus,Gtk.libgtk),Nothing,(Ptr{Gtk.GObject},),widget)
	return widget
end
#=
function activate_key(wnd::Gtk.GtkWindow,event::GdkEventKey)
	ccall((:gtk_window_activate_key,Gtk.libgtk),Cint,(Ptr{Gtk.GObject},Ptr{Gtk.GObject}),wnd,event)
	return wnd
end
#gboolean gtk_window_activate_key (GtkWindow *window, GdkEventKey *event);
=#
function gdk_cursor_new(id::String)
	d = ccall((:gdk_display_get_default,Gtk.libgdk),Ptr{Nothing},(Cstring,),id)
	return ccall((:gdk_cursor_new_from_name,Gtk.libgdk),Ptr{Nothing},(Ptr{Nothing}, Cstring), d,id)
end

function gdk_window_set_cursor(wnd, cursor::Ptr{Nothing})
	wptr = GAccessor.window(wnd)
	ccall((:gdk_window_set_cursor,Gtk.libgdk),Nothing,(Ptr{Nothing},Ptr{Nothing}), wptr, cursor)
	return
end

function gtk_tree_path_new_from_string(pstr::Ptr{Cchar})
	tp = ccall((:gtk_tree_path_new_from_string, Gtk.libgtk), Ptr{_Gtk.TreePath}, (Ptr{Cchar},), pstr)
	return Gtk.GtkTreePath(tp, true)
end

function redraw(widget::Gtk.GtkWidget)
	return ccall((:gtk_widget_queue_draw, Gtk.libgtk), Nothing, (Ptr{Gtk.GObject},), widget)
end


#==Constants
===============================================================================#
function initialize_cursors()
	global CURSOR_DEFAULT = Gtk.C_NULL #WANTCONST
	global CURSOR_PAN = gdk_cursor_new("grabbing") #WANTCONST
	global CURSOR_MOVE = gdk_cursor_new("move") #WANTCONST
	global CURSOR_COLRESIZE = gdk_cursor_new("col-resize") #WANTCONST
	global CURSOR_ROWRESIZE = gdk_cursor_new("row-resize") #WANTCONST
	global CURSOR_BOXSELECT = gdk_cursor_new("crosshair") #WANTCONST
end


#==Display types
===============================================================================#
#Generic type used to spawn new InspectDR display windows:
struct GtkDisplay <: AbstractDisplay
end


#==Main types
===============================================================================#
abstract type InputState end #Identifies current user input state.

abstract type CtrlElement end #Controllable element
#=Implement:
TODO: explain interface
=#

"""`DisplayedRegion`

Tracks plot region currently being displayed.
"""
mutable struct DisplayedRegion
	#NOTE: Only need to track x-values at the moment for x-axis control widget.
	xcenter::DReal
	#Buffering span avoids accumulation of errors as user sweeps center value:
	xspan::DReal
end
DisplayedRegion() = DisplayedRegion(0,0)

mutable struct CtrlMarker <: CtrlElement
	prop::HVMarker #Properties
	Δinfo::Vector2D #Offset of Δ-information block
	Δbb::BoundingBox #Last postion of Δ-information block (optimize hit test)
	ref::NullOr{CtrlMarker} #Reference marker
end

#Grouping of controllable markers (used to get ::Plot object to render)
mutable struct CtrlMarkerGroup <: PlotAnnotation
	elem::Vector{CtrlMarker}
	fntcoord::Font
	fntdelta::Font
end
CtrlMarkerGroup(reffont::Font) = CtrlMarkerGroup([],
	Font(reffont, _size = 10), Font(reffont, _size = 12)
)

mutable struct GtkMouseOver
	istrip::Int
	pos::NullOr{Point2D}
end
GtkMouseOver() = GtkMouseOver(0, nothing)

mutable struct PlotWidget
	widget::_Gtk.Box #Base widget
	canvas::_Gtk.Canvas #Actual plot area
	src::Plot
	rplot::RPlot2D
	state::InputState

	#Scrollbars to control x-axis position control widget:
	w_xpos::_Gtk.Scale
	xpos::_Gtk.Adjustment

	#Display image (Cached):
	plotbuf::CairoBufferedPlot
#	bufbb::BoundingBox

	curstrip::Int #Currently active strip
	region::DisplayedRegion #Region f plot shown to user
	mouseover::GtkMouseOver #Where is mouse

	#Control elements:
	markers::CtrlMarkerGroup
	refmarker::NullOr{CtrlMarker} #Used as ref

	#External event handlers:
	eh_plothover::NullOr{HandlerInfo}
end

#Supports multiplot:
mutable struct GtkPlot
	destroyed::Bool #Way to know if window is actually desplayed
	wnd::_Gtk.Window
	grd::_Gtk.Grid #Holds subplot widgets
	subplots::Vector{PlotWidget}
	src::Multiplot #Akward for sync: subplots.src are references to src.subplots.
	status::_Gtk.Label
end


#==Accessors
===============================================================================#
skipannot(::CtrlMarkerGroup, rstrip::RStrip2D) =  false


#==Helper functions
===============================================================================#
function refresh_title(gplot::GtkPlot)
	if length(gplot.src.title)> 0
		title = "InspectDR - $(gplot.src.title)"
	else
		title = "InspectDR"
	end
	set_gtk_property!(gplot.wnd, :title, title)
	return
end

#Get numeric formatting/precision with mouse hover:
function hoverfmt(fmt::TickLabelFormatting)
	result = deepcopy(fmt.fmt)
	#Display a bit more precision than tick labels:
	result.ndigits += 2 #TODO: Better algorithm?
	return result
end


#==Constructor-like functions
===============================================================================#
function StripCoordMap(rplot::RPlot2D)
	result = StripCoordMap[]
	for strip in rplot.strips
		push!(result, StripCoordMap(strip.bb, strip.ext, strip.ixf, strip.xf, strip.xfmt, strip.yfmt))
	end
	return result
end


#==Accessors
===============================================================================#
function activestrip(w::PlotWidget)
	istrip = w.curstrip
	nstrips = length(w.src.strips)
	if istrip < 1 || istrip > nstrips
		istrip = 0
	end
	return istrip
end

#Tree views that model "ListStore"s can access indicies in a simpler fashion:
function listindex(treepath::_Gtk.TreePath)
	_indices = GAccessor.indices(treepath)
	#For arbitrary tres, see: Gtk.depth(treepath)
	return convert(Int, unsafe_load(_indices, 1))
end

#Find active subplot by polling which has focus:
#NOTE: Polling is a bit hacky... might be better to signal when set_focus is used??
function active_subplot(gplot::GtkPlot)
	for i in 1:length(gplot.subplots)
		isactive = Gtk.get_gtk_property(gplot.subplots[i].widget, "is-focus", Bool)
		if isactive return i; end
	end

	return 0 #No active subplot
end


#==Mutators
===============================================================================#
function settitle(gplot::GtkPlot, title::String)
	gplot.src.title = title
	refresh_title(gplot)
end

set_focus(pwidget::PlotWidget) = set_focus(pwidget.widget)


#==Main functions
===============================================================================#

function invalidbuffersize(pwidget::PlotWidget)
	return width(pwidget.canvas) != width(pwidget.plotbuf.surf) ||
		height(pwidget.canvas) != height(pwidget.plotbuf.surf)
end

dev2aloc(rstrip::RStrip2D, pt::Point2D) = apply_inv(rstrip.xf, pt)
function dev2axis(rstrip::RStrip2D, pt::Point2D)
	_pt = apply_inv(rstrip.xf, pt) #dev->aloc
	return aloc2axis(_pt, rstrip.ixf)
end

function drawoverlay(s::InputState, ctx::CairoContext, rplot::RPlot2D, lyt)
	#Default: do nothing
end

#Render PlotWidget widget to buffer:
#-------------------------------------------------------------------------------
function render(pwidget::PlotWidget; refreshdata::Bool=true)
	plot = pwidget.src #WANTCONST
	#Create new buffer large enough to match canvas:
	#TODO: Is crating surfaces expensive?  This solution might be bad.
	if invalidbuffersize(pwidget)
		Cairo.destroy(pwidget.plotbuf.surf)
		Cairo.destroy(pwidget.plotbuf.data)
		#TODO: use RGB surface? Gtk.cairo_surface_for() appears to generate ARGB surface (slower?)
		#pwidget.plotbuf.surf = Cairo.CairoRGBSurface(width(pwidget.canvas),height(pwidget.canvas))
		pwidget.plotbuf.surf = Gtk.cairo_surface_for(pwidget.canvas) #create similar
		pwidget.plotbuf.data = Gtk.cairo_surface_for(pwidget.canvas) #create similar - must be ARGB
	end

	w = width(pwidget.canvas); h = height(pwidget.canvas)
	bb = BoundingBox(0, w, 0, h)
	pwidget.rplot = render(pwidget.plotbuf, plot, bb, refreshdata)
	nstrips = length(pwidget.rplot.strips)
	pwidget.curstrip = max(pwidget.curstrip, 1) #Focus on 1st strip - if no strip has focus
	pwidget.curstrip = min(pwidget.curstrip, nstrips) #Make sure focus is not beyond nstrips
	return
end

"""
    refresh(gplot::PlotWidget; refreshdata::Bool=true)

Redraw `PlotWidget` canvas.

Will synchronize to its associated `Plot` object & re-render all data if `refreshdata=true`.
"""
function refresh(w::PlotWidget; refreshdata::Bool=true)
	render(w, refreshdata=refreshdata)
	Gtk.draw(w.canvas)
	return
end


#==IO functions
===============================================================================#
#_write() GtkPlot: Auto-coumpute w/h
function _write(path::String, mime::MIME, gplot::GtkPlot)
	_write(path, mime, gplot.src)
end

write_png(path::String, gplot::GtkPlot) = _write(path, MIMEpng(), gplot)
write_svg(path::String, gplot::GtkPlot) = _write(path, MIMEsvg(), gplot)
write_eps(path::String, gplot::GtkPlot) = _write(path, MIMEeps(), gplot)
write_pdf(path::String, gplot::GtkPlot) = _write(path, MIMEpdf(), gplot)

#Last line
