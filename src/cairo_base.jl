#InspectDR: Base functionnality and types for Cairo layer
#-------------------------------------------------------------------------------

#Cairo.scale(destctx, 2, 1)


#==Main types
===============================================================================#

#2D plot canvas:
type PCanvas2D <: PlotCanvas
	ctx::CairoContext
	ext::PExtents2D

	xf::Transform2D
	#Is this needed?
#	w::DReal
#	h::DReal

	#Max resolution along x-axis to reduce data:
	#TODO: use in PCanvasF1
#	xresolution::DReal
end
PCanvas2D(ctx::CairoContext, ext::PExtents2D, inputb::BoundingBox) =
	PCanvas2D(ctx, ext, Transform2D(ext, inputb))


#==Helper functions
===============================================================================#

function _set_stylewidth(ctx::CairoContext, style::Symbol, linewidth::Float64)

	dashes = Float64[] #default (:solid)
	offset = 0

	if :none == style
		linewidth = 0 #In case
	elseif :dash == style
		dashes = Float64[4,2]
	elseif :dot == style
		dashes = Float64[1,2]
	elseif :dashdot == style
		dashes = Float64[4,2,1,2]
	elseif :solid != style
		warn("Unrecognized line style: $style")
	end

	Cairo.set_line_width(ctx, linewidth);
	Cairo.set_dash(ctx, dashes.*linewidth, offset)
end

function drawglyph_circle(ctx::CairoContext, pt::Point2D, radius::DReal)
	Cairo.arc(ctx, pt.x, pt.y, radius, 0, 2pi)
	Cairo.stroke(ctx)
end

#==Rendering
===============================================================================#

function render(canvas::PCanvas2D, wfrm::DWaveformF1)
	ctx = canvas.ctx
	ds = wfrm.ds

	if length(ds) < 2
		return
	end

	Cairo.set_source(ctx, wfrm.line.color)
	_set_stylewidth(ctx, wfrm.line.style, Float64(wfrm.line.width))
	pt = ptmap(canvas.xf, ds[1])
	Cairo.move_to(ctx, pt.x, pt.y)
	for i in 2:length(ds)
		pt = ptmap(canvas.xf, ds[i])
		Cairo.line_to(ctx, pt.x, pt.y)
	end
#	set_line_join(ctx, Cairo.CAIRO_LINE_JOIN_MITER)
	Cairo.stroke(ctx)

	#Draw symbols:
	_set_stylewidth(ctx, :solid, Float64(wfrm.line.width))
	radius = Float64(3.0*wfrm.line.width)
	for i in 1:length(ds)
		pt = ptmap(canvas.xf, ds[i])
#		drawglyph_circle(ctx, pt, radius)
	end

	return
end
render(canvas::PCanvas2D, wfrmlist::Vector{DWaveformF1}) =
	map((w)->render(canvas, w), wfrmlist)


#Last line
