#InspectDR: Base functionnality and types for Gtk layer
#-------------------------------------------------------------------------------

import Gtk: getproperty, setproperty!, signal_connect

#==Main types
===============================================================================#

#type GtkPlot{CT<:PCanvas}

type GtkPlot
	canvas::_Gtk.Canvas
	src::Plot

	#Is cache of display data invalid?
	invalid_ddata::Bool

	#Display data cache (Clipped to current extents):
	display_data::Vector{DWaveformF1}

	adj::_Gtk.Adjustment

	#Display image (Cached):
#	display_img::
#	plot::CT
end
GtkPlot(canvas::_Gtk.Canvas, src::Plot, adj::_Gtk.Adjustment) =
	GtkPlot(canvas, src, true, [], adj)


#==Constructors
===============================================================================#
function GtkPlot()
	const SCALEMAX = 1000
	vbox = _Gtk.@Box(true, 0)
	canvas = Gtk.@Canvas()
	scale = _Gtk.@Scale(false, 1:SCALEMAX)
	adj = _Gtk.@Adjustment(scale)
		setproperty!(adj, :value, 1)

	push!(vbox, canvas)
	push!(vbox, scale)
#	setproperty!(scale, :vexpand, true)
	setproperty!(canvas, :vexpand, true)

	win = Gtk.@Window(vbox, "InspectDR")
	showall(win)

	w = width(canvas)
	h = height(canvas)
	plot = Plot2D(w, h)

	gplot = GtkPlot(canvas, plot, adj)

	conn = signal_connect(adj, "value-changed") do widget
		v = getproperty(widget, :value, Int)
		emax = gplot.src.ext_max
		xmax = emax.xmax/v
		setextents(gplot, PExtents2D(0, xmax, DNaN, DNaN))
		Gtk.draw(gplot.canvas)
	end

	return gplot
end


#==Main functions
===============================================================================#
function invalidate_extents(gplot::GtkPlot)
	gplot.invalid_ddata = true
end

function invalidate_datalist(gplot::GtkPlot)
	gplot.ext_max = nothing
	gplot.invalid_ddata = true
end

function setextents(gplot::GtkPlot, ext::PExtents2D)
	setextents(gplot.src, ext)
	invalidate_extents(gplot)
end

function update_ddata(gplot::GtkPlot)
	#TODO: Conditionnaly compute:
	setextents_detectmax(gplot.src)

	invalidate_extents(gplot) #Always compute below:
	if gplot.invalid_ddata
		ext = getextents(gplot.src)
#		npts = max(1000, width(gplot.canvas))
		npts = gplot.src.xres
#@show npts
		gplot.display_data = _reduce(gplot.src.data, ext, npts) #Hardcode resolution
		gplot.invalid_ddata = false
	end
end

#=
function render(canvas::_Gtk.Canvas, plot::Plot2D)
	ctx = getgc(canvas)
	#TODO: Can/should we explicitly Cairo.destroy(ctx)???
	w = width(ctx); h = height(ctx)
	#...

	#TODO: should we support canvas, or only GtkPlot???
end
=#

function render(gplot::GtkPlot)
	ctx = getgc(gplot.canvas)
	#TODO: Can/should we explicitly Cairo.destroy(ctx)???
	w = width(ctx); h = height(ctx)

	update_ddata(gplot)
	ext = getextents(gplot.src)
	bb = BoundingBox(0, w, 0, h)
	graphbb = databounds(bb, gplot.src.layout)

	#Render annotation/axes
	_reset(ctx)
	clear(ctx, bb)
	render(ctx, gplot.src.annotation, bb, graphbb, gplot.src.layout)
	render_axes(ctx, graphbb, ext, gplot.src.layout)

	#Plot actual data
	Cairo.save(ctx)
	_clip(ctx, graphbb)
	canvas = PCanvas2D(ctx, ext, graphbb)
	render(canvas, gplot.display_data)
	Cairo.restore(ctx)

	#Re-render graph frame over data:
	render_graphframe(ctx, graphbb)
#	gplot.display_img = render(ctx, gplot)
end

#TODO: make this a constructor???
function _display(gplot::GtkPlot)
	#=NOTE:
	GtkPlot should probably be subclassed from GtkCanvas, but Julia does not
	make this easy.  Instead, this function generates an annonymous function
	that implicitly has a reference to this GtkPlot instance.
	=#

	#Register drawing function:
	Gtk.@guarded Gtk.draw(gplot.canvas) do canvas
		render(gplot)
	end
end

#Last line
