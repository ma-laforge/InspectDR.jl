#InspectDR: Base functionnality and types for Gtk layer
#-------------------------------------------------------------------------------

import Gtk: getproperty, setproperty!, signal_connect

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
#=
function activate_key(wnd::Gtk.GtkWindow,event::GdkEventKey)
	ccall((:gtk_window_activate_key,Gtk.libgtk),Cint,(Ptr{Gtk.GObject},Ptr{Gtk.GObject}),wnd,event)
	return wnd
end
#gboolean gtk_window_activate_key (GtkWindow *window, GdkEventKey *event);
=#


#Gtk constants
#-------------------------------------------------------------------------------
const GTK_POS_LEFT = 0
const GTK_POS_RIGHT = 1
const GTK_POS_TOP = 2
const GTK_POS_BOTTOM = 3

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

type GtkPlot
	widget::_Gtk.Box #Base widget
	canvas::_Gtk.Canvas #Actual plot area
	src::Plot

	#Scrollbars to control x-scale & position:
	xscale::_Gtk.Adjustment
	xpos::_Gtk.Adjustment

	#Display image (Cached):
#	display_img::
#	plot::CT
end

#Supports multiplot:
type GtkPlotWindow
	wnd::_Gtk.Window
	grd::_Gtk.Grid #Holds subplot widgets
	subplots::Vector{GtkPlot}
	ncolumns::Int
end


#==Main functions
===============================================================================#

function render(gplot::GtkPlot)
	ctx = getgc(gplot.canvas)
	w = width(ctx); h = height(ctx)
	bb = BoundingBox(0, w, 0, h)

	_reset(ctx)
	clear(ctx, bb)
	render(ctx, gplot.src, bb)

	#TODO: Can/should we explicitly Cairo.destroy(ctx)???
#	gplot.display_img = render(ctx, gplot)
end

function scale_update(gplot::GtkPlot)
	xscale = getproperty(gplot.xscale, :value, Int)
	xpos = getproperty(gplot.xpos, :value, Float64)
	emax = gplot.src.ext_max
	span = emax.xmax - emax.xmin
	center = (emax.xmax + emax.xmin) / 2
	vspan = span/xscale #Visible span
	xmin = center + span*xpos - vspan/2
	xmax = xmin + vspan
	setextents(gplot.src, PExtents2D(xmin, xmax, DNaN, DNaN))
	Gtk.draw(gplot.canvas)
end

function handle_key(gplot::GtkPlot, event::Gtk.GdkEventKey)
#event_type: GDK_KEY_PRESS/GDK_KEY_RELEASE
#state: GDK_SHIFT_MASK, GDK_LOCK_MASK, GDK_RELEASE_MASK, ...
#@show event.event_type, event.state, event.keyval, event.length, event.string, event.hardware_keycode, event.group, event.flags
	if event.keyval == 'f'
		#TODO: find a way to suppress signalling & explicitly call update:
		setproperty!(gplot.xscale, :value, Int(1))
		setproperty!(gplot.xpos, :value, Float64(0))
#		scale_update(gplot)
	end
	false #Do not keep processing?
end


#=="Constructors"
===============================================================================#
function GtkPlot(plot::Plot)
	vbox = _Gtk.@Box(true, 0)
		can_focus(vbox, true)
	canvas = Gtk.@Canvas()
		setproperty!(canvas, :vexpand, true)
	w_xscale = _Gtk.@Scale(false, 1:XAXIS_SCALEMAX)
		xscale = _Gtk.@Adjustment(w_xscale)
		setproperty!(xscale, :value, 1)
#		draw_value(w_xscale, false)
		value_pos(w_xscale, GTK_POS_RIGHT)
	w_xpos = _Gtk.@Scale(false, -.5:XAXIS_POS_STEPRES:.5)
		xpos = _Gtk.@Adjustment(w_xpos)
		setproperty!(xpos, :value, 0)
#		draw_value(w_xpos, false)
		value_pos(w_xpos, GTK_POS_RIGHT)

	push!(vbox, canvas)
	push!(vbox, w_xpos)
	push!(vbox, w_xscale)

	gplot = GtkPlot(vbox, canvas, plot, xscale, xpos)

	#Register event: refresh canvas when zoom-level changes:
	conn = signal_connect(xscale, "value-changed") do widget
		#Has implicit reference to gplot... not a big fan of this technique...
		scale_update(gplot)
	end
	conn = signal_connect(xpos, "value-changed") do widget
		#Has implicit reference to gplot... not a big fan of this technique...
		scale_update(gplot)
	end
	conn = signal_connect(vbox, "key_press_event") do widget, event
		#Has implicit reference to gplot... not a big fan of this technique...
		handle_key(gplot, event)
	end


	#Register event: draw function
	Gtk.@guarded Gtk.draw(gplot.canvas) do canvas
		#=NOTE:
		GtkPlot should probably be subclassed from GtkCanvas (the draw event
		would then have a reference to the GtkPlot...), but Julia does not
		make this easy.  Instead, this function generates an annonymous function
		that implicitly has a reference to the appropriate GtkPlot instance.
		=#
		render(gplot)
	end

	return gplot
end


function GtkPlotWindow(mp::Multiplot)
	subplots = GtkPlot[]
	grd = Gtk.@Grid()
	ncols = mp.ncolumns
	_focus = nothing

	for (i, sp) in enumerate(mp.subplots)
		row = div(i-1, ncols)+1
		col = i - ((row-1)*ncols)
		gplot = GtkPlot(sp)
		_focus = gplot.widget
		push!(subplots, gplot)
		grd[col, row] = gplot.widget
	end

	setproperty!(grd, :column_homogeneous, true)
	#setproperty!(grd, :column_spacing, 15) #Gap between

	wnd = Gtk.@Window(grd, "InspectDR", 640, 480, true)
	if _focus != nothing
		focus(wnd, _focus)
	end
	showall(wnd)
	return GtkPlotWindow(wnd, grd, subplots, ncols)
end

function GtkPlotWindow(plot::Plot)
	mp = Multiplot()
	add(mp, plot)
	return GtkPlotWindow(mp)
end
GtkPlotWindow() = GtkPlotWindow(Plot2D())


#==High-level interface
===============================================================================#
function Base.display(d::GtkDisplay, mp::Multiplot)
	return GtkPlotWindow(mp)
end
function Base.display(d::GtkDisplay, p::Plot)
	return GtkPlotWindow(p)
end

#Last line
