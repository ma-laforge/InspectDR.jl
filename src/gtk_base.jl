#InspectDR: Base functionnality and types for Gtk layer
#-------------------------------------------------------------------------------

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

	#Display image (Cached):
#	display_img::
#	plot::CT
end
GtkPlot(canvas::_Gtk.Canvas, src::Plot) =
	GtkPlot(canvas, src, true, [])


#==Constructors
===============================================================================#
function GtkPlot()
	canvas = Gtk.@Canvas()
	win = Gtk.@Window(canvas, "InspectDR")
	showall(win)

	w = width(canvas)
	h = height(canvas)
	plot = Plot2D(w, h)

	return GtkPlot(canvas, plot)
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
	ext = getextents(gplot.src)
	setextents(gplot, ext)

	if gplot.invalid_ddata
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
	bb = BoundingBox(0, w, 0, h)
	canvas = PCanvas2D(ctx, gplot.src.ext, bb) #xresolution
#	gplot.display_img = render(ctx, gplot)

	render(canvas, gplot.display_data)
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
