#InspectDR: IO functionnality for writing plots with Cairo
#-------------------------------------------------------------------------------

#==Constants
===============================================================================#
typealias MIMEpng MIME"image/png"
typealias MIMEsvg MIME"image/svg+xml"
typealias MIMEeps MIME"image/eps"
typealias MIMEpdf MIME"application/pdf"

#If an easy way to read Cairo scripts back to a surface is found:
#typealias MIMEcairo MIME"image/cairo"

#All supported MIMEs:
#EXCLUDE SVG so it can be turnd on/off??
typealias MIMEall Union{MIMEpng, MIMEeps, MIMEpdf, MIMEsvg}


#==Defaults
===============================================================================#
type Defaults
	rendersvg::Bool #Might want to dissalow SVG renderings for performance reasons
end
Defaults() = Defaults(true)

const defaults = Defaults()

#=="Constructors"
===============================================================================#
_CairoSurface(io::IO, ::MIMEsvg, w::Float64, h::Float64) =
	Cairo.CairoSVGSurface(io, w, h)
_CairoSurface(io::IO, ::MIMEeps, w::Float64, h::Float64) =
	Cairo.CairoEPSSurface(io, w, h)
_CairoSurface(io::IO, ::MIMEpdf, w::Float64, h::Float64) =
	Cairo.CairoPDFSurface(io, w, h)


#=="write" interface
===============================================================================#
function _write(stream::IO, mime::MIME, plot::Plot2D, w::Float64, h::Float64)
	bb = BoundingBox(0, w, 0, h)
	surf = _CairoSurface(stream, mime, w, h)
	ctx = CairoContext(surf)
	render(ctx, plot, bb)
	Cairo.destroy(ctx)
	Cairo.destroy(surf)
end

#There is no PNG surface... just a write function for PNG.
function _write(stream::IO, ::MIMEpng, plot::Plot2D, w::Float64, h::Float64)
	w = round(w); h = round(h)
	bb = BoundingBox(0, w, 0, h)
	surf = Cairo.CairoARGBSurface(w, h)
	ctx = CairoContext(surf)
	render(ctx, plot, bb)
	Cairo.destroy(ctx)
	Cairo.write_to_png(surf, stream)
	Cairo.destroy(surf)
end

function _write(path::AbstractString, mime::MIME, plot::Plot2D, w::Float64, h::Float64)
	io = open(path, "w")
	_write(io, mime, plot, w, h)
	close(io)
end

function _write(path::AbstractString, mime::MIME, plot::Plot2D)
	bb = plotbounds(plot.layout)
	_write(path, mime, plot, bb.xmax, bb.ymax)
end

Base.mimewritable(mime::MIME"text/plain", p::Plot) = true
Base.mimewritable(mime::MIME, p::Plot) = false #Default
Base.mimewritable(mime::MIMEall, p::Plot) = true #Supported
Base.mimewritable(mime::MIMEsvg, p::Plot) = defaults.rendersvg

#Maintain text/plain MIME support (Is this ok?).
Base.writemime(io::IO, ::MIME"text/plain", plot::Plot2D) = Base.showlimited(io, plot)

Base.writemime(io::IO, mime::MIME, plot::Plot2D) =
	throw(MethodError(writemime, (io, mime, plot)))

#Supported MIMEs:
function Base.writemime(io::IO, mime::MIMEall, plot::Plot2D)
	bb = plotbounds(plot.layout)
	_write(io, mime, plot, bb.xmax, bb.ymax)
end


#==Non-MIME write interface (convenience)
===============================================================================#

write_png(path::AbstractString, plot::Plot2D) = _write(path, MIMEpng(), plot)
write_svg(path::AbstractString, plot::Plot2D) = _write(path, MIMEsvg(), plot)
write_eps(path::AbstractString, plot::Plot2D) = _write(path, MIMEeps(), plot)
write_pdf(path::AbstractString, plot::Plot2D) = _write(path, MIMEpdf(), plot)

#Last line
