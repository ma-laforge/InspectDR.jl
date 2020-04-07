#InspectDR: Heatmap tools
#-------------------------------------------------------------------------------

#==Constants
===============================================================================#


#==Main types
===============================================================================#
struct ColorScale
	e::Vector{ARGB32} #Elements of color scale
end
ColorScale() = ColorScale([ARGB32(0, 0, 0, 0)])

#Transform used to map a 1D "z" value to a colour.
struct Transform1DToARGB
	vmin::DReal; span::DReal #Min value; span of colour scale
	s::DReal #scaling factor
	colorscale::ColorScale
end
function Transform1DToARGB(colorscale::ColorScale; vmin::DReal=0, vmax::DReal=1)
	vmin, vmax = minmax(vmin, vmax)
	span = vmax - vmin
	N = length(colorscale.e)
	s = (N-1) / span
	return Transform1DToARGB(vmin, span, s, colorscale)
end


#==Constructor-like functions
===============================================================================#

#Construct ColorScale from vector of color values
#ex: Colors.colormap("blues") returns a vector of RGB{Float64} values
function ColorScale(v::Vector{T}) where T<:Colorant
	return ColorScale([ARGB32(c) for c in v])
end


#==Main functions
===============================================================================#
function apply(xf::Transform1DToARGB, d::Array{T}) where T<:DReal
	result = Array{ARGB32}(undef,size(d))
	for i in 1:length(d)
		v = max(min(d[i] - xf.vmin, xf.span), 0)
		idx = Int(round(v*xf.s)) + 1
		result[i] = xf.colorscale.e[idx]
	end
	return result
end

#Last line
