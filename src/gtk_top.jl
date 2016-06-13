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
plothover_coordformatting(lstyle::TickLabelStyle, lines::AbstractGridLines) =
	NumericFormatting() #Just use default
function plothover_coordformatting(lstyle::TickLabelStyle, lines::GridLines)
	fmt = TickLabelFormatting(lstyle, lines.rnginfo).fmt
	fmt.ndigits += 2 #TODO: Better algorithm?
	return fmt
end

function plothover_coordstr(axes::AxesRect, ext::PExtents2D, xlstyle::TickLabelStyle, ylstyle::TickLabelStyle, x::DReal, y::DReal)
	x = datamap_rev(x, axes.xscale)
	y = datamap_rev(y, axes.yscale)
	grid = gridlines(axes, ext)
	fmt = plothover_coordformatting(xlstyle, grid.xlines)
	xstr = string(fmt, x)
	fmt = plothover_coordformatting(ylstyle, grid.ylines)
	ystr = string(fmt, y)
	return "(x, y) = ($xstr, $ystr)"
end

#Show rectangular coordinates for Smith (not transformed, for the moment):
plothover_coordstr(axes::AxesSmith, ext::PExtents2D, xlstyle::TickLabelStyle, ylstyle::TickLabelStyle, x::DReal, y::DReal) =
	plothover_coordstr(AxesRect(:lin, :lin), ext, xlstyle, ylstyle, x, y)

function handleevent_plothover(gplot::GtkPlot, pwidget::PlotWidget, x::DReal, y::DReal)
	plot = pwidget.src
	lyt = plot.layout
	ext = getextents_xfrm(plot)
	statstr = plothover_coordstr(plot.axes, ext, lyt.xlabelformat, lyt.ylabelformat, x, y)
	setproperty!(gplot.status, :label, statstr)
end


#==Menu builders:
===============================================================================#
function Gtk_addmenu(parent::Union{_Gtk.Menu, _Gtk.MenuBar}, name::AbstractString)
	item = _Gtk.@MenuItem(name)
	mnu = _Gtk.@Menu(item)
	push!(parent, item)
	return mnu
end
function Gtk_addmenuitem(mnu::_Gtk.Menu, name::AbstractString)
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
	pwidget = PlotWidget(vbox, canvas, plot,
		BoundingBox(0,1,0,1), ISNormal(),
		w_xscale, xscale, w_xpos, xpos,
		bufsurf, GtkSelection(),
		#Event handlers:
		nothing
	)

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
		selectionbox_draw(ctx, pwidget.sel)
		#TODO: Can/should we explicitly Cairo.destroy(ctx)???
	end

	return pwidget
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
	settitle(GtkPlot, wnd, mp.title)

	properties = copy_properties(mp)
	gplot = GtkPlot(wnd, grd, [], properties, status)

	_focus = nothing
	ncols = properties.ncolumns

	#Add subplots:
	for (i, sp) in enumerate(mp.subplots)
		row = div(i-1, ncols)+1
		col = i - ((row-1)*ncols)
		pwidget = PlotWidget(sp)
		pwidget.eh_plothover = HandlerInfo(gplot, handleevent_plothover)
		_focus = pwidget.widget
		push!(gplot.subplots, pwidget)
		grd[col, row] = pwidget.widget
	end

	if _focus != nothing
		focus(wnd, _focus)
	end

	showall(wnd)
	signal_connect(cb_mnufileexport, mnuexport, "activate", Void, (), false, gplot)
	signal_connect(cb_mnufileclose, mnuquit, "activate", Void, (), false, gplot)

	return gplot
end

#-------------------------------------------------------------------------------
function GtkPlot(plot::Plot, args...; kwargs...)
	mp = Multiplot(args...; kwargs...)
	add(mp, plot)
	return GtkPlot(mp)
end
GtkPlot(args...; kwargs...) = GtkPlot(Plot2D(), args...; kwargs...)


#==High-level interface
===============================================================================#
function Base.display(d::GtkDisplay, mp::Multiplot)
	return GtkPlot(mp)
end
function Base.display(d::GtkDisplay, p::Plot)
	return GtkPlot(p)
end

#Last line
