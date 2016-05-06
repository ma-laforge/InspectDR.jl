#InspectDR: Top/high-level functionnality of Gtk layer
#-------------------------------------------------------------------------------


#==Event handlers
===============================================================================#

#Event handler for plot widget keypress
#-------------------------------------------------------------------------------
function handleevent_keypress(gplot::GtkPlot, event::Gtk.GdkEventKey)
#event_type: GDK_KEY_PRESS/GDK_KEY_RELEASE
#state: GDK_SHIFT_MASK, GDK_LOCK_MASK, GDK_RELEASE_MASK, ...
#@show event.event_type, event.state, event.keyval, event.length, event.string, event.hardware_keycode, event.group, event.flags
	if event.keyval == 'f'
		zoom_full(gplot)
	end
end


#==Callback wrapper functions
===============================================================================#
#=COMMENTS
 -Define callback wrapper functions with concrete types to assist with precompile.
 -Remove unecessary arguments/convert to proper types
=#
@guarded function cb_keypress(w::Ptr{Gtk.GObject}, event::Gtk.GdkEventKey, gplot::GtkPlot)
	handleevent_keypress(gplot, event)
	nothing #Void signature
end
@guarded function cb_scalechanged(w::Ptr{Gtk.GObject}, gplot::GtkPlot)
	if !scalectrl_enabled(gplot); return; end
	handleevent_scalechanged(gplot)
	nothing #Void signature
end
@guarded function cb_mousepress(w::Ptr{Gtk.GObject}, event::Gtk.GdkEventButton, gplot::GtkPlot)
	handleevent_mousepress(gplot, event)
	nothing #Void signature
end
@guarded function cb_mouserelease(w::Ptr{Gtk.GObject}, event::Gtk.GdkEventButton, gplot::GtkPlot)
	handleevent_mouserelease(gplot, event)
	nothing #Void signature
end
@guarded function cb_mousemove(w::Ptr{Gtk.GObject}, event::Gtk.GdkEventMotion, gplot::GtkPlot)
	handleevent_mousemove(gplot, event)
	nothing #Void signature
end


#=="Constructors"
===============================================================================#

#-------------------------------------------------------------------------------
function GtkPlot(plot::Plot)
	vbox = _Gtk.@Box(true, 0)
		can_focus(vbox, true)
#		setproperty!(vbox, "focus-on-click", true)
#		setproperty!(vbox, :focus_on_click, true)
	canvas = Gtk.@Canvas()
		setproperty!(canvas, :vexpand, true)
	w_xscale = _Gtk.@Scale(false, 1:XAXIS_SCALEMAX)
		xscale = _Gtk.@Adjustment(w_xscale)
		setproperty!(xscale, :value, 1)
#		draw_value(w_xscale, false)
		value_pos(w_xscale, Int(GtkPositionType.GTK_POS_RIGHT))
	w_xpos = _Gtk.@Scale(false, -.5:XAXIS_POS_STEPRES:.5)
		xpos = _Gtk.@Adjustment(w_xpos)
		setproperty!(xpos, :value, 0)
#		draw_value(w_xpos, false)
		value_pos(w_xpos, Int(GtkPositionType.GTK_POS_RIGHT))

	push!(vbox, canvas)
	push!(vbox, w_xpos)
	push!(vbox, w_xscale)

	bufsurf = Cairo.CairoRGBSurface(width(canvas), height(canvas))
	#TODO: how do we get a maximum surface for all monitors?
	#TODO: or can we resize in some intelligent way??
	#bufsurf = Cairo.CairoRGBSurface(1920,1200) #Appears slow for average monitor size???
#	bufsurf = Gtk.cairo_surface_for(canvas) #create similar - does not work here
	gplot = GtkPlot(vbox, canvas, plot, BoundingBox(0,1,0,1), w_xscale, xscale, w_xpos, xpos, bufsurf, GtkSelection())

	#Register callback functions:
	signal_connect(cb_scalechanged, xscale, "value-changed", Void, (), false, gplot)
	signal_connect(cb_scalechanged, xpos, "value-changed", Void, (), false, gplot)
	signal_connect(cb_keypress, vbox, "key-press-event", Void, (Ref{Gtk.GdkEventKey},), false, gplot)
	signal_connect(cb_mousepress, vbox, "button-press-event", Void, (Ref{Gtk.GdkEventButton},), false, gplot)
	signal_connect(cb_mouserelease, vbox, "button-release-event", Void, (Ref{Gtk.GdkEventButton},), false, gplot)
	signal_connect(cb_mousemove, vbox, "motion-notify-event", Void, (Ref{Gtk.GdkEventMotion},), false, gplot)

	#Register event: draw function
	Gtk.@guarded Gtk.draw(gplot.canvas) do canvas
		#=NOTE:
		GtkPlot should probably be subclassed from GtkCanvas (the draw event
		would then have a reference to the GtkPlot...), but Julia does not
		make this easy.  Instead, this function generates an annonymous function
		that implicitly has a reference to the appropriate GtkPlot instance.
		=#
		if invalidbuffersize(gplot)
			render(gplot)
		end
		ctx = getgc(gplot.canvas)
		Cairo.set_source_surface(ctx, gplot.bufsurf, 0, 0)
		Cairo.paint(ctx) #Applies contents of bufsurf
		selectionbox_draw(ctx, gplot.sel)
		#TODO: Can/should we explicitly Cairo.destroy(ctx)???
	end

	return gplot
end

#-------------------------------------------------------------------------------
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

#-------------------------------------------------------------------------------
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
