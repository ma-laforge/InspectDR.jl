#InspectDR: Base functionnality and types for Gtk layer
#-------------------------------------------------------------------------------

import Gtk: getproperty, setproperty!, signal_connect, @guarded

#Create module aliasese to access constants:
#TODO: Figure out why constants are Int32 instead of Int???
import Gtk: GdkKeySyms
import Gtk: GtkPositionType, GdkEventType, GdkEventMask


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

type GtkSelection
	enabled::Bool
	bb::BoundingBox
	ext_start::PExtents2D #Exetents @ start of operation
	#Store ext_start to avoid accumulation of numerical errors.
end
GtkSelection() = GtkSelection(false, BoundingBox(0,0,0,0), PExtents2D())

type GtkPlot
	widget::_Gtk.Box #Base widget
	canvas::_Gtk.Canvas #Actual plot area
	src::Plot
	graphbb::BoundingBox
	state::InputState

	#Scrollbars to control x-scale & position:
	w_xscale::_Gtk.Scale
	xscale::_Gtk.Adjustment
	w_xpos::_Gtk.Scale
	xpos::_Gtk.Adjustment

	#Display image (Cached):
	bufsurf::Cairo.CairoSurface
#	bufbb::BoundingBox

	sel::GtkSelection
end

#Supports multiplot:
type GtkPlotWindow
	title::DisplayString
	wnd::_Gtk.Window
	grd::_Gtk.Grid #Holds subplot widgets
	subplots::Vector{GtkPlot}
	ncolumns::Int
end


#==Mutators
===============================================================================#
function settitle(::Type{GtkPlotWindow}, wnd::_Gtk.Window, title::DisplayStringArg)
	if length(title)> 0
		title = "InspectDR - $(title)"
	else
		title = "InspectDR"
	end
	Gtk.setproperty!(wnd, :title, title)
end

function settitle(gplot::GtkPlotWindow, title::DisplayStringArg)
	gplot.title = DisplayString(title)
	settitle(GtkPlotWindow, gplot.wnd, gplot.title)
end


#==Main functions
===============================================================================#

function invalidbuffersize(gplot::GtkPlot)
	return width(gplot.canvas) != width(gplot.bufsurf) ||
		height(gplot.canvas) != height(gplot.bufsurf)
end

#Render GtkPlot widget to buffer:
#-------------------------------------------------------------------------------
function render(gplot::GtkPlot)
	#Create new buffer large enough to match canvas:
	#TODO: Is crating surfaces expensive?  This solution might be bad.
	if invalidbuffersize(gplot)
		Cairo.destroy(gplot.bufsurf)
		#TODO: use RGB surface? Gtk.cairo_surface_for() appears to generate ARGB surface (slower?)
		#gplot.bufsurf = Cairo.CairoRGBSurface(width(gplot.canvas),height(gplot.canvas))
		gplot.bufsurf = Gtk.cairo_surface_for(gplot.canvas) #create similar
	end

	w = width(gplot.canvas); h = height(gplot.canvas)
	bb = BoundingBox(0, w, 0, h)
	ctx = CairoContext(gplot.bufsurf)

	_reset(ctx)
	clear(ctx, bb)
	render(ctx, gplot.src, bb)
	gplot.graphbb = graphbounds(bb, gplot.src.layout)
	Cairo.destroy(ctx)
end

#Last line
