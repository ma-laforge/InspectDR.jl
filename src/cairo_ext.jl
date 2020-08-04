#InspectDR: Extensions to Cairo layer
#-------------------------------------------------------------------------------

#=
Also provides a higher-level inteface for some basic functions.

NOTE: might be useful to move to a separate module.
=#


#==Constants
===============================================================================#
struct CAlignment #Cairo alignment
	bitfield::Int
end
Base.:|(a::CAlignment, b::CAlignment) = CAlignment(a.bitfield|b.bitfield)

const ALIGN_LEFT = CAlignment(0)
const ALIGN_HCENTER = CAlignment(1)
const ALIGN_RIGHT = CAlignment(2)
const ALIGN_HSHIFT = 0
const ALIGN_HMASK = 0x3
ALIGN_HVALUE(a::CAlignment) = (a.bitfield & ALIGN_HMASK) >> ALIGN_HSHIFT

const ALIGN_BOTTOM = CAlignment(0)
const ALIGN_VCENTER = CAlignment(4)
const ALIGN_TOP = CAlignment(8)
const ALIGN_VSHIFT = 2
const ALIGN_VMASK = (0x3<<ALIGN_VSHIFT)
ALIGN_VVALUE(a::CAlignment) = (a.bitfield & ALIGN_VMASK) >> ALIGN_VSHIFT

#Symbols not currently supported by Cairo package:
#-------------------------------------------------------------------------------
const PANGO_ELLIPSIZE_END = 3


#==Main types
===============================================================================#


#==Basic rendering
===============================================================================#

#Low-level function to draw circles:
function cairo_circle(ctx::CairoContext, x::Float64, y::Float64, radius::Float64)
	Cairo.arc(ctx, x, y, radius, 0, 2pi)
end

#Reset context to known state:
function _reset(ctx::CairoContext)
	#TODO: reset transforms???
	Cairo.set_source(ctx, COLOR_BLACK)
	Cairo.set_line_width(ctx, 1);
	Cairo.set_dash(ctx, Float64[], 0)

	#Bevel is fastest.  Also not "spiky" like miter (default):
	Cairo.set_line_join(ctx, Cairo.CAIRO_LINE_JOIN_BEVEL)
end

#Set entire context to a single color:
function clear(ctx::CairoContext, color::Colorant=COLOR_TRANSPARENT)
	Cairo.save(ctx)
	Cairo.set_source(ctx, color)
	Cairo.set_operator(ctx, Cairo.OPERATOR_SOURCE)
	Cairo.paint(ctx) #_with_alpha?
	Cairo.restore(ctx)
end

#Draws a rectangle-shaped area with a solid color
wipe(ctx::CairoContext, bb::BoundingBox, color::Colorant) =
	drawrectangle(ctx, bb, color)

function setclip(ctx::CairoContext, bb::BoundingBox)
	Cairo.rectangle(ctx, bb)
	Cairo.clip(ctx)
end

#Set linestyle/linewidth.
function _setlinestyle(ctx::CairoContext, style::Symbol, linewidth::Float64)

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
		@warn("Unrecognized line style: $style")
	end

	Cairo.set_line_width(ctx, linewidth);
	Cairo.set_dash(ctx, dashes.*linewidth, offset)
end

function setlinestyle(ctx::CairoContext, s::LineStyle)
	Cairo.set_source(ctx, s.color)
	_setlinestyle(ctx, s.style, s.width)
end

#Conditionnaly render fill (preserve path for stroke)
#-------------------------------------------------------------------------------
renderfill(ctx::CairoContext, fill::Nothing) = nothing
function renderfill(ctx::CairoContext, fill::Colorant)
	Cairo.save(ctx) #-----
	Cairo.set_source(ctx, fill)
	Cairo.fill_preserve(ctx)
	Cairo.restore(ctx) #-----
end

#Draw a simple line on a CairoContext
#-------------------------------------------------------------------------------
function drawline(ctx::CairoContext, p1::Point2D, p2::Point2D)
	Cairo.move_to(ctx, p1.x, p1.y)
	Cairo.line_to(ctx, p2.x, p2.y)
	Cairo.stroke(ctx)
end

#Draw a rectangle, given AreaAttributes
#-------------------------------------------------------------------------------
function drawrectangle(ctx::CairoContext, bb::BoundingBox, aa::AreaAttributes)
	Cairo.set_source(ctx, aa.fillcolor)
	Cairo.rectangle(ctx, bb)
	Cairo.fill_preserve(ctx)
	setlinestyle(ctx, LineStyle(aa.line))
	Cairo.stroke(ctx)
end

#Draw a filled rectangle with no border
#-------------------------------------------------------------------------------
function drawrectangle(ctx::CairoContext, bb::BoundingBox, color::Colorant)
	Cairo.set_source(ctx, color)
	Cairo.rectangle(ctx, bb)
	Cairo.fill(ctx)
end

#==Rendering text
===============================================================================#
#= INFO:
typedef struct {
	double x_bearing, y_bearing;
	double width, height;
	double x_advance, y_advance;
} cairo_text_extents_t;
=#

#Extract text width/height from result of Cairo.set_text/Cairo.get_layout_size:
function textextents_wh(ctx::Cairo.CairoContext, str::AbstractString, markup::Bool=false)
	Cairo.set_text(ctx, str, markup)
	t_ext = Cairo.get_layout_size(ctx)
	return (t_ext[1], t_ext[2])
end

#Set active font on a CairoContext
#-------------------------------------------------------------------------------
function setfont(ctx::CairoContext, font::Font)
	FSCALE = DTPPOINTS_PER_INCH/96 #Pango appears to be preset to 96 PPI
	Cairo.set_source(ctx, font.color)
	weight = font.bold ? " bold" : ""
	facestr = @sprintf("%s%s %0.1f", font.name, weight, font._size*FSCALE)
	Cairo.set_font_face(ctx, facestr)
end

#Render text using "advanced" properties.
#-------------------------------------------------------------------------------
#angle: radians
function render(ctx::CairoContext, t::String, pt::Point2D,
	align::CAlignment, angle::Float64, markup::Bool=false)

	if !isfinite(pt.x) || !isfinite(pt.y)
		return #Seems to muck up context when accidentally drawing @ NaN.
	end

	#TODO: Create own function to avoid using strings???
	halignstr = ["left", "center", "right", "left"] #Last is default in case of error
	halign = halignstr[1+Int(ALIGN_HVALUE(align))]
  	valignstr = ["bottom", "center", "top", "bottom"] #Last is default in case of error
	valign = valignstr[1+Int(ALIGN_VVALUE(align))]

	Cairo.save(ctx) #-----
	angle *= -(180/π) #Cairo.text() wants angles in degrees and has opposite rotation
	bb=Cairo.text(ctx, pt.x, pt.y, t, halign=halign, valign=valign, angle=angle, markup=markup)
	Cairo.restore(ctx) #-----
	return
end
render(ctx::CairoContext, t::String, pt::Point2D;
	align::CAlignment=ALIGN_BOTTOM|ALIGN_LEFT, angle::Real=0) =
	render(ctx, t, pt, align, Float64(angle))

#Convenience: also set font.
function render(ctx::CairoContext, t::String, pt::Point2D, font::Font;
	align::CAlignment=ALIGN_BOTTOM|ALIGN_LEFT, angle::Real=0, markup::Bool=false)
	Cairo.save(ctx) #-----
	setfont(ctx, font)
	render(ctx, t, pt, align, Float64(angle), markup)
	Cairo.restore(ctx) #-----
end


#Draws number as base, raised to a power (ex: 10^9):
#-------------------------------------------------------------------------------
function render_power(ctx::CairoContext, tbase::String, val::DReal, pt::Point2D, font::Font, align::CAlignment)
	EXP_SCALE = 0.7 #WANTCONST
	EXP_SHIFT = 0.4 #WANTCONST
	fontexp = deepcopy(font)
	fontexp._size = font._size*EXP_SCALE

	Cairo.save(ctx) #-----
	setfont(ctx, font)
	(wbase, hbase) = textextents_wh(ctx, tbase)
	setfont(ctx, fontexp)
	texp = @sprintf("%0.0f", val)
	(wexp, hexp) = textextents_wh(ctx, texp)
	Cairo.restore(ctx) #-----

	#Compute bounding box:
	voffset_exp = EXP_SHIFT * hbase
	w = wbase+wexp
	h = max(hbase, voffset_exp+hexp)

	#Alignment factor (depending on CAlignment bitfield):
	KALIGN = DReal[0, 0.5, 1, 0] #Last is default in case of error

	xoff = -w * KALIGN[1+Int(ALIGN_HVALUE(align))]
	yoff = +h * KALIGN[1+Int(ALIGN_VVALUE(align))]

	pt = Point2D(pt.x + xoff, pt.y + yoff)
	render(ctx, tbase, pt, font, align=ALIGN_LEFT|ALIGN_BOTTOM)

	pt = Point2D(pt.x + wbase, pt.y - voffset_exp)
	render(ctx, texp, pt, fontexp, align=ALIGN_LEFT|ALIGN_BOTTOM)
end

#Last line
