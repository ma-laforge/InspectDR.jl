#InspectDR: Base functionnality and types for Gtk layer
#-------------------------------------------------------------------------------

import Gtk: getproperty, setproperty!, signal_connect, @guarded

#Create module aliasese to access constants:
#TODO: Figure out why constants are Int32 instead of Int???
import Gtk: GdkKeySyms
import Gtk: GtkPositionType, GdkEventType, GdkEventMask
import Gtk: GConstants.GtkShadowType


#==Extensions
===============================================================================#
#TODO: Why can't I just access these functions directly from Gtk/gen/gbox3???

function draw_value(scale::Gtk.GtkScale, draw_value_::Bool)
	ccall((:gtk_scale_set_draw_value,Gtk.libgtk),Void,(Ptr{Gtk.GObject},Cint),scale,draw_value_)
	return scale
end
function value_pos(scale::Gtk.GtkScale,pos::Int)
	ccall((:gtk_scale_set_value_pos,Gtk.libgtk),Void,(Ptr{Gtk.GObject},Cint),scale,pos)
	return scale
end

function can_focus(widget::Gtk.GtkWidget,can_focus_::Bool)
	ccall((:gtk_widget_set_can_focus,Gtk.libgtk),Void,(Ptr{Gtk.GObject},Cint),widget,can_focus_)
	return widget
end

function window_close(window::Gtk.GtkWindow)
	ccall((:gtk_window_close,Gtk.libgtk),Void,(Ptr{Gtk.GObject},),window)
	return
end

function focus(window::Gtk.GtkWindow,widget)
	ccall((:gtk_window_set_focus,Gtk.libgtk),Void,(Ptr{Gtk.GObject},Ptr{Gtk.GObject}),window,widget)
	return window
end
function focus(widget)
	ccall((:gtk_widget_grab_focus,Gtk.libgtk),Void,(Ptr{Gtk.GObject},),widget)
	return widget
end
#=
function activate_key(wnd::Gtk.GtkWindow,event::GdkEventKey)
	ccall((:gtk_window_activate_key,Gtk.libgtk),Cint,(Ptr{Gtk.GObject},Ptr{Gtk.GObject}),wnd,event)
	return wnd
end
#gboolean gtk_window_activate_key (GtkWindow *window, GdkEventKey *event);
=#


#==Constants
===============================================================================#
const XAXIS_SCALEMAX = 1000
const XAXIS_POS_STEPRES = 1/500


#==Display types
===============================================================================#
#Generic type used to spawn new InspectDR display windows:
immutable GtkDisplay <: Display
end


#==Main types
===============================================================================#
abstract InputState #Identifies current user input state.

abstract CtrlElement #Controllable element
#=Implement:
TODO: explain interface
=#

type CtrlMarker <: CtrlElement
	prop::HVMarker #Properties
	ref::NullOr{CtrlMarker} #Reference marker
end

#Grouping of controllable markers (used to get ::Plot object to render)
type CtrlMarkerGroup <: PlotAnnotation
	graphinfo::Graph2DInfo #Info needed to render markers
	elem::Vector{CtrlMarker}
	fntcoord::Font
	fntdelta::Font
end

#TODO: move to ISSelectingArea <: InputState??
type GtkSelection
	enabled::Bool
	istrip::Int
	bb::BoundingBox
	ext_start::PExtents2D #Exetents @ start of operation
	#Store ext_start to avoid accumulation of numerical errors.
end
GtkSelection() = GtkSelection(false, 0, BoundingBox(0,0,0,0), PExtents2D())

type GtkMouseOver
	istrip::Int
	pos::NullOr{Point2D}
end
GtkMouseOver() = GtkMouseOver(0, nothing)

type PlotWidget
	widget::_Gtk.Box #Base widget
	canvas::_Gtk.Canvas #Actual plot area
	src::Plot
	graphinfo::Graph2DInfo
	state::InputState

	#Scrollbars to control x-scale & position:
	w_xscale::_Gtk.Scale
	xscale::_Gtk.Adjustment
	w_xpos::_Gtk.Scale
	xpos::_Gtk.Adjustment

	#Display image (Cached):
	bufsurf::Cairo.CairoSurface
#	bufbb::BoundingBox

	curstrip::Int #Currently active strip
	mouseover::GtkMouseOver #Where is mouse
	sel::GtkSelection #Used to describe selection box

	#Control elements:
	markers::CtrlMarkerGroup
	refmarker::NullOr{CtrlMarker} #Used as ref

	#Restrict h/v motion:
	hallowed::Bool
	vallowed::Bool

	#External event handlers:
	eh_plothover::NullOr{HandlerInfo}
end

#Supports multiplot:
type GtkPlot
	destroyed::Bool #Way to know if window is actually desplayed
	wnd::_Gtk.Window
	grd::_Gtk.Grid #Holds subplot widgets
	subplots::Vector{PlotWidget}
	src::Multiplot #Akward for sync: subplots.src are references to src.subplots.
	status::_Gtk.Label
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


#==Mutators
===============================================================================#
function settitle(wnd::_Gtk.Window, title::String)
	if length(title)> 0
		title = "InspectDR - $(title)"
	else
		title = "InspectDR"
	end
	Gtk.setproperty!(wnd, :title, title)
end

function settitle(gplot::GtkPlot, title::String)
	gplot.src.title = title
	settitle(gplot.wnd, gplot.src.title)
end


#==Main functions
===============================================================================#

function invalidbuffersize(pwidget::PlotWidget)
	return width(pwidget.canvas) != width(pwidget.bufsurf) ||
		height(pwidget.canvas) != height(pwidget.bufsurf)
end

#Render PlotWidget widget to buffer:
#-------------------------------------------------------------------------------
function render(pwidget::PlotWidget)
	const plot = pwidget.src
	#Create new buffer large enough to match canvas:
	#TODO: Is crating surfaces expensive?  This solution might be bad.
	if invalidbuffersize(pwidget)
		Cairo.destroy(pwidget.bufsurf)
		#TODO: use RGB surface? Gtk.cairo_surface_for() appears to generate ARGB surface (slower?)
		#pwidget.bufsurf = Cairo.CairoRGBSurface(width(pwidget.canvas),height(pwidget.canvas))
		pwidget.bufsurf = Gtk.cairo_surface_for(pwidget.canvas) #create similar
	end

	w = width(pwidget.canvas); h = height(pwidget.canvas)
	bb = BoundingBox(0, w, 0, h)
	ctx = CairoContext(pwidget.bufsurf)

	_reset(ctx)
	clear(ctx, bb)
	pwidget.graphinfo = Graph2DInfo(plot, bb)
	pwidget.markers.graphinfo = pwidget.graphinfo
	nstrips = length(pwidget.graphinfo.strips)
	pwidget.curstrip = max(pwidget.curstrip, 1) #Focus on 1st strip - if no strip has focus
	pwidget.curstrip = min(pwidget.curstrip, nstrips) #Make sure focus is not beyond nstrips
	render(ctx, plot, bb)
	Cairo.destroy(ctx)
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
