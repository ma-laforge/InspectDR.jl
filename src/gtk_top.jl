#InspectDR: Top/high-level functionnality of Gtk layer
#-------------------------------------------------------------------------------


#==Callback wrapper functions (PlotWidget-level)
===============================================================================#
#=COMMENTS
 -Define callback wrapper functions with concrete types to assist with precompile.
 -Remove unecessary arguments/convert to proper types
=#
@guarded function cb_keypress(w::Ptr{Gtk.GObject}, event::Gtk.GdkEventKey, pwidget::PlotWidget)
	handleevent_keypress(pwidget.state, pwidget, event)
	nothing #Void signature
end
@guarded function cb_scalechanged(w::Ptr{Gtk.GObject}, pwidget::PlotWidget)
	handleevent_scalechanged(pwidget.state, pwidget)
	nothing #Void signature
end
@guarded function cb_mousepress(w::Ptr{Gtk.GObject}, event::Gtk.GdkEventButton, pwidget::PlotWidget)
	handleevent_mousepress(pwidget.state, pwidget, event)
	nothing #Void signature
end
@guarded function cb_mouserelease(w::Ptr{Gtk.GObject}, event::Gtk.GdkEventButton, pwidget::PlotWidget)
	handleevent_mouserelease(pwidget.state, pwidget, event)
	nothing #Void signature
end
@guarded function cb_mousemove(w::Ptr{Gtk.GObject}, event::Gtk.GdkEventMotion, pwidget::PlotWidget)
	handleevent_mousemove(pwidget.state, pwidget, event)
	nothing #Void signature
end
@guarded function cb_mousescroll(w::Ptr{Gtk.GObject}, event::Gtk.GdkEventScroll, pwidget::PlotWidget)
	handleevent_mousescroll(pwidget.state, pwidget, event)
	nothing #Void signature
end


#==Callback wrapper functions (GtkPlot-level)
===============================================================================#
@guarded function cb_wnddestroyed(w::Ptr{Gtk.GObject}, gplot::GtkPlot)
	gplot.destroyed = true
	nothing #Void signature
end
@guarded function cb_mnufileexport(w::Ptr{Gtk.GObject}, gplot::GtkPlot)
	filepath = Gtk.save_dialog("Export plot...", _Gtk.Null(),
		(_Gtk.@FileFilter("*.png,*.svg,*.eps", name="All supported formats"), "*.png", "*.svg", "*.eps")
	)
	if isempty(filepath); return nothing; end

	ext = splitext(filepath)[end]
	mime = get(MAPEXT2MIME, ext, nothing)
	if nothing == mime
		Gtk.warn_dialog("Unrecognized file type: '$ext'")
		return nothing
	end

	try
		_write(filepath, mime, gplot)
	catch
		Gtk.warn_dialog("Write failed: '$filepath'")
	end
	nothing #Void signature
end
@guarded function cb_mnufileclose(w::Ptr{Gtk.GObject}, gplot::GtkPlot)
	window_close(gplot.wnd)
	nothing #Void signature
end


#==Higher-level event handlers
===============================================================================#
#plothover event: show plot coordinates under mouse.
#-------------------------------------------------------------------------------
function handleevent_plothover(gplot::GtkPlot, pwidget::PlotWidget, x::Float64, y::Float64)
	const plotinfo = pwidget.plotinfo

	istrip = pwidget.mouseover.istrip
	pos = pwidget.mouseover.pos
	if istrip > 0 && pos != nothing
		xfmt = hoverfmt(plotinfo.xfmt)
		yfmt = hoverfmt(plotinfo.strips[istrip].yfmt)
		xstr = formatted(pos.x, xfmt)
		ystr = formatted(pos.y, yfmt)
		statstr = "(x, y) = ($xstr, $ystr)"
	else
		statstr = "(x, y) = ( , )"
	end

	setproperty!(gplot.status, :label, statstr)
	nothing
end


#==Menu builders:
===============================================================================#
function Gtk_addmenu(parent::Union{_Gtk.Menu, _Gtk.MenuBar}, name::String)
	item = _Gtk.@MenuItem(name)
	mnu = _Gtk.@Menu(item)
	push!(parent, item)
	return mnu
end
function Gtk_addmenuitem(mnu::_Gtk.Menu, name::String)
	item = _Gtk.@MenuItem(name)
	push!(mnu, item)
	return item
end


#=="Constructors"
===============================================================================#

#-------------------------------------------------------------------------------
function PlotWidget(plot::Plot)
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
	curstrip = 1 #TODO: Is this what is desired?

	plotinfo = Plot2DInfo(plot)
	pwidget = PlotWidget(vbox, canvas, plot, plotinfo, ISNormal(),
		w_xscale, xscale, w_xpos, xpos,
		bufsurf, curstrip, GtkMouseOver(),
		CtrlMarkerGroup(), nothing, true, true,
		#Event handlers:
		nothing
	)

	#Take control of parentannot:
	plot.parentannot = [pwidget.markers]

	#Register callback functions:
	signal_connect(cb_scalechanged, xscale, "value-changed", Void, (), false, pwidget)
	signal_connect(cb_scalechanged, xpos, "value-changed", Void, (), false, pwidget)
	signal_connect(cb_keypress, vbox, "key-press-event", Void, (Ref{Gtk.GdkEventKey},), false, pwidget)
	signal_connect(cb_mousepress, vbox, "button-press-event", Void, (Ref{Gtk.GdkEventButton},), false, pwidget)
	signal_connect(cb_mouserelease, vbox, "button-release-event", Void, (Ref{Gtk.GdkEventButton},), false, pwidget)
	signal_connect(cb_mousemove, vbox, "motion-notify-event", Void, (Ref{Gtk.GdkEventMotion},), false, pwidget)
	signal_connect(cb_mousescroll, vbox, "scroll-event", Void, (Ref{Gtk.GdkEventScroll},), false, pwidget)

	#Register event: draw function
	Gtk.@guarded Gtk.draw(pwidget.canvas) do canvas
		#=NOTE:
		PlotWidget should probably be subclassed from GtkCanvas (the draw event
		would then have a reference to the PlotWidget...), but Julia does not
		make this easy.  Instead, this function generates an annonymous function
		that implicitly has a reference to the appropriate PlotWidget instance.
		=#
		if invalidbuffersize(pwidget)
			render(pwidget)
		end
		ctx = getgc(pwidget.canvas)
		Cairo.set_source_surface(ctx, pwidget.bufsurf, 0, 0)
		Cairo.paint(ctx) #Applies contents of bufsurf
		selectionbox_draw(ctx, pwidget)
		#TODO: Can/should we explicitly Cairo.destroy(ctx)???
	end

	return pwidget
end
#Build a PlotWidget & register event handlers for GtkPlot object
function PlotWidget(gplot::GtkPlot, plot::Plot)
	pwidget = PlotWidget(plot)
	pwidget.eh_plothover = HandlerInfo(gplot, handleevent_plothover)
	return pwidget
end

#Synchronize with gplot.src.subplots
function sync_subplots(gplot::GtkPlot)
	wlist = gplot.subplots #widget list
	plist = gplot.src.subplots #(sub)plot list
	resize!(wlist, length(plist))

	for (i, s) in enumerate(plist)
		if !isassigned(wlist, i)
			wlist[i] = PlotWidget(gplot, s)
		else
			if wlist[i].src != s
				Gtk.destroy(wlist[i].widget)
				wlist[i] = PlotWidget(gplot, s)
			end
		end
	end

	#Blindly re-construct grid:
	for i in length(gplot.grd):-1:1
		Gtk.delete!(gplot.grd, gplot.grd[i]) #Does not destroy existing child widgets
	end
	const ncols = gplot.src.ncolumns
	for (i, w) in enumerate(wlist)
		row = div(i-1, ncols)+1
		col = i - ((row-1)*ncols)
		gplot.grd[col,row] = w.widget

		#FIXME/HACK: rebuilding grd appears to inhibit the redraw mechanism.
		#Toggling w.canvas -> visible unclogs refresh algorithm somehow.
		Gtk.setproperty!(w.canvas, :visible, false)
		Gtk.setproperty!(w.canvas, :visible, true)
	end
	return
end


#-------------------------------------------------------------------------------
function GtkPlot(mp::Multiplot)
	#Generate graphical elements:
	mb = _Gtk.@MenuBar()
	mnufile = Gtk_addmenu(mb, "_File")
		mnuexport = Gtk_addmenuitem(mnufile, "_Export")
		push!(mnufile, _Gtk.@SeparatorMenuItem())
		mnuquit = Gtk_addmenuitem(mnufile, "_Quit")
	grd = Gtk.@Grid() #Main grid with different subplots.
		setproperty!(grd, :column_homogeneous, true)
		#setproperty!(grd, :column_spacing, 15) #Gap between
	status = _Gtk.@Label("")#"(x,y) =")
		setproperty!(status, :hexpand, true)
		setproperty!(status, :ellipsize, PANGO_ELLIPSIZE_END)
		setproperty!(status, :xalign, 0.0)
		sbar_frame = _Gtk.@Frame(status)
			setproperty!(sbar_frame, "shadow-type", GtkShadowType.GTK_SHADOW_ETCHED_IN)

	vbox = _Gtk.@Box(true, 0)
		push!(vbox, mb) #Menu bar
		push!(vbox, grd) #Subplots
		push!(vbox, sbar_frame) #status bar
	wnd = Gtk.@Window(vbox, "", 640, 480, true)
	settitle(wnd, mp.title)

	gplot = GtkPlot(false, wnd, grd, [], mp, status)
	sync_subplots(gplot)

	if length(gplot.subplots) > 0
		focus(wnd, gplot.subplots[end].widget)
	end

	showall(wnd)
	signal_connect(cb_wnddestroyed, wnd, "destroy", Void, (), false, gplot)
	signal_connect(cb_mnufileexport, mnuexport, "activate", Void, (), false, gplot)
	signal_connect(cb_mnufileclose, mnuquit, "activate", Void, (), false, gplot)

	return gplot
end

#-------------------------------------------------------------------------------
function GtkPlot(plot::Plot, args...; kwargs...)
	mp = Multiplot(args...; kwargs...)
	_add(mp, plot)
	return GtkPlot(mp)
end
GtkPlot(args...; kwargs...) = GtkPlot(Plot2D(), args...; kwargs...)


#==High-level interface
===============================================================================#
function clearsubplots(gplot::GtkPlot)
	for s in gplot.subplots
		Gtk.destroy(s.widget)
	end
	gplot.subplots = []
	gplot.src.subplots = []
	return gplot
end

refresh(w::PlotWidget) = (render(w); Gtk.draw(w.canvas); return w)
function refresh(gplot::GtkPlot)
	if !gplot.destroyed
		settitle(gplot.wnd, gplot.src.title)
		setproperty!(gplot.grd, :visible, false) #Suppress gliching
			sync_subplots(gplot)
			map(refresh, gplot.subplots) #Is this necessary?
		setproperty!(gplot.grd, :visible, true)
		showall(gplot.grd)
		#TODO: find a way to force GUI to updates here... Animations don't refresh...
		sleep(eps(0.0)) #Ugly Hack: No guarantee this works... There must be a better way.
	end
	return gplot
end

function Base.display(d::GtkDisplay, mp::Multiplot)
	return GtkPlot(mp)
end
function Base.display(d::GtkDisplay, p::Plot)
	return GtkPlot(p)
end

#Last line
