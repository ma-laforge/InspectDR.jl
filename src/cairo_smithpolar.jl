#InspectDR: Drawing Smith/polar grids with Cairo layer
#-------------------------------------------------------------------------------

#TODO: Try to collect Smith plot code in this module, if it makes sense.


#==Constants
===============================================================================#
const SMITHLABEL_OFFSET = Float64(2) #Device units from intercept


#==Types
===============================================================================#


#==Base functions
===============================================================================#
function render_rcircle(ctx::CairoContext, c::DReal)
	pctr = Point2D(c / (1+c), 0)
	radius = 1 / (1+c)
	Cairo.arc(ctx, pctr.x, pctr.y, radius, 0, 2pi)
	Cairo.stroke(ctx)
end
render_rcircles(ctx::CairoContext, clist::Vector{DReal}) =
	(for c in clist; render_rcircle(ctx, c); end)

function render_xcircle(ctx::CairoContext, c::DReal)
	radius = 1/c
	Cairo.arc(ctx, 1, radius, radius, 0, 2pi)
	Cairo.stroke(ctx)
	Cairo.arc(ctx, 1, -radius, radius, 0, 2pi)
	Cairo.stroke(ctx)
end
render_xcircles(ctx::CairoContext, clist::Vector{DReal}) =
	(for c in clist; render_xcircle(ctx, c); end)

function render_rcirclelabel(ctx::CairoContext, xf::Transform2D, pt::Point2D, lbl::DisplayString)
	pt = ptmap(xf, pt)
	#render(ctx, lbl, Point2D(pt.x, pt.y+SMITHLABEL_OFFSET), align=ALIGN_TOP|ALIGN_HCENTER)
	render(ctx, lbl, Point2D(pt.x-SMITHLABEL_OFFSET, pt.y+SMITHLABEL_OFFSET),
		align=ALIGN_TOP|ALIGN_RIGHT
	)
	#render(ctx, lbl, pt, align=ALIGN_VCENTER|ALIGN_HCENTER)
end
function render_rcirclelabel(ctx::CairoContext, xf::Transform2D, c::DReal)
	xintercept = (c-1)/(c+1)
	pt = Point2D(xintercept, 0)
	tstr = DisplayString("$c")
	render_rcirclelabel(ctx, xf, pt, tstr)
end
render_rcirclelabels(ctx::CairoContext, xf::Transform2D, clist::Vector{DReal}) =
	(for c in clist; render_rcirclelabel(ctx, xf, c); end)


function render_xcirclelabel(ctx::CairoContext, xf::Transform2D, pt::Point2D, lbl::DisplayString)
	vlbl = pt #Directional vector of label position
	#Compute text angle:
	corr = -xf.xs/xf.ys #Correct for aspect ratio
	Θ = atan2(vlbl.x, vlbl.y*corr)

	#Compute text position, including offset:
	vpos = vecmap(xf, pt)
	voffset = (SMITHLABEL_OFFSET/vecnorm(vpos))*vpos
	pt = ptmap(xf, pt)+voffset
	render(ctx, lbl, pt, angle=Θ, align=ALIGN_BOTTOM|ALIGN_HCENTER)
end
function render_xcirclelabel(ctx::CairoContext, xf::Transform2D, c::DReal)
	radius = 1/c
	#Compute intercept with 0dB circle (r=1):
	y = 2*radius/(1+radius*radius)
	x = 1-y*radius

	pt = Point2D(x, y)
	tstr = DisplayString("$c")
	render_xcirclelabel(ctx, xf, pt, tstr)
end
render_xcirclelabels(ctx::CairoContext, xf::Transform2D, clist::Vector{DReal}) =
	(for c in clist; render_xcirclelabel(ctx, xf, c); end)


#==Extensions to base functionnality
===============================================================================#

#Split complex input data into real/imag components:
function getrealimag{T<:Number}(d::Vector{T})
	x = Array(DReal, length(d))
	y = Array(DReal, length(d))
	for i in 1:length(d)
		x[i] = convert(DReal, imag(d[i]))
		y[i] = convert(DReal, real(d[i]))
	end
	return (x, y)
end

function getrealimag(input::IDataset)
	(x, y) = getrealimag(input.y)
	return IDataset{false}(x, y) #Assume new re/im data is not sorted.
end

function getrealimag(input::IWaveform)
	ds = getrealimag(input.ds)
	return IWaveform(input.id, ds, input.line, input.glyph, getextents(ds))
end

_rescale(inputlist::Vector{IWaveform}, axes::AxesSmith) =
	map((input)->getrealimag(input), inputlist)


#==High-level rendering functions
===============================================================================#
function render_grid(canvas::PCanvas2D, lyt::Layout, grid::GridSmith)
	const ctx = canvas.ctx
	const graphbb = canvas.graphbb
	const MINOR_COLOR = GRID_MINOR_COLOR
	const MAJOR_COLOR = COLOR_BLACK #GRID_MAJOR_COLOR

Cairo.save(ctx) #-----
	setclip(ctx, graphbb)

	#Set transform through Cairo to so it can deal with circles:
	setxfrm(ctx, canvas.xf)

	setlinestyle(ctx, :solid, GRID_MINOR_WIDTH)
	Cairo.set_source(ctx, MINOR_COLOR)
		render_rcircles(ctx, grid.minorR)
		render_xcircles(ctx, grid.minorX)
	setlinestyle(ctx, :solid, GRID_MAJOR_WIDTH)
	Cairo.set_source(ctx, MAJOR_COLOR)
		render_rcircles(ctx, grid.majorR)
Cairo.restore(ctx) #-----

Cairo.save(ctx) #-----
	setclip(ctx, graphbb)

	#Draw X=0 line:
	setlinestyle(ctx, :solid, GRID_MINOR_WIDTH)
	Cairo.set_source(ctx, MINOR_COLOR)
	y = ptmap(canvas.xf, Point2D(0, 0)).y
	drawline(ctx::CairoContext, Point2D(graphbb.xmin, y), Point2D(graphbb.xmax, y))

	#Draw labels:
	setfont(ctx, lyt.fntticklabel)
	render_rcirclelabels(ctx, canvas.xf, grid.majorR)
	render_rcirclelabels(ctx, canvas.xf, grid.minorR)
#	render_rcirclelabel(ctx, canvas.xf, Point2D(1,0), "∞")
	pt = ptmap(canvas.xf, Point2D(1, 0))
	#render(ctx, "∞", Point2D(pt.x+SMITHLABEL_OFFSET, pt.y), align=ALIGN_VCENTER|ALIGN_LEFT)
	render(ctx, "∞", Point2D(pt.x-SMITHLABEL_OFFSET, pt.y+SMITHLABEL_OFFSET),
		align=ALIGN_TOP|ALIGN_RIGHT
	)
	render_xcirclelabels(ctx, canvas.xf, grid.minorX)

Cairo.restore(ctx) #-----
	nothing
end

function render_axes(canvas::PCanvas2D, lyt::Layout, grid::GridSmith)
	render_graphframe(canvas)

	#Display linear grid:
	#TODO: make it possible to disable?
	grid = gridlines(axes(:lin, :lin), canvas.ext)
	render_ticks(canvas, lyt, grid)
end

#Last line
