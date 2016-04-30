#InspectDR: Base functionnality and types for Gtk layer
#-------------------------------------------------------------------------------

import Gtk: getproperty, setproperty!, signal_connect


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

#type GtkPlot{CT<:PCanvas}

type GtkPlot
	canvas::_Gtk.Canvas
	src::Plot

	#Scrollbars to control x-scale & position:
	xscale::_Gtk.Adjustment
	xpos::_Gtk.Adjustment

	#Display image (Cached):
#	display_img::
#	plot::CT
end
#TODO: reactivate when more is needed:
#GtkPlot(canvas::_Gtk.Canvas, src::Plot, adj::_Gtk.Adjustment) =
#	GtkPlot(canvas, src, adj)


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

function Base.display(d::GtkDisplay, p::Plot)
	return GtkPlot(p)
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


#=="Constructors"
===============================================================================#
function GtkPlot(plot::Plot)
	vbox = _Gtk.@Box(true, 0)
	canvas = Gtk.@Canvas()
		setproperty!(canvas, :vexpand, true)
	w_xscale = _Gtk.@Scale(false, 1:XAXIS_SCALEMAX)
		xscale = _Gtk.@Adjustment(w_xscale)
		setproperty!(xscale, :value, 1)
	w_xpos = _Gtk.@Scale(false, -.5:XAXIS_POS_STEPRES:.5)
		xpos = _Gtk.@Adjustment(w_xpos)
		setproperty!(xpos, :value, 0)

	push!(vbox, canvas)
	push!(vbox, w_xpos)
	push!(vbox, w_xscale)

	gplot = GtkPlot(canvas, plot, xscale, xpos)

	#Register event: refresh canvas when zoom-level changes:
	conn = signal_connect(xscale, "value-changed") do widget
		#Has implicit reference to gplot... not a big fan of this technique...
		scale_update(gplot)
	end
	conn = signal_connect(xpos, "value-changed") do widget
		#Has implicit reference to gplot... not a big fan of this technique...
		scale_update(gplot)
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

	win = Gtk.@Window(vbox, "InspectDR", 640, 480, true)
	showall(win)

	return gplot
end

#Last line
