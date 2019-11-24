#InspectDR: Heatmap tools
#-------------------------------------------------------------------------------

#Transform used to normalize and clip a value:
#result = (v + v0) * s
struct TransformNormalizeClip
	v0::DReal; s::DReal
end

function TransformNormalizeClip(;min::DReal=0, max::DReal=1)
	v0 = -min; s = (max-min)
	return TransformNormalizeClip(v0, s)
end

#Transform used to map a [0,1] normalized 1D value to a colour.
#r = v*rs + r0
#g = v*gs + g0
#b = v*bs + b0
#a = v*as + a0
#TODO: Make a more flexible colormap.
struct Transform1DNormToARGB
	rs::DReal; r0::DReal
	gs::DReal; g0::DReal
	bs::DReal; b0::DReal
	as::DReal; a0::DReal
end


function map2axis(d::Array{T}, xf::Transform1DNormToARGB) where T<:DReal
	result = Array{ARGB32}(undef,size(d))
	for i in 1:length(d)
		v = max(min(d[i], 1.0), 0.0)
		r = v*xf.rs+xf.r0
		g = v*xf.gs+xf.g0
		b = v*xf.bs+xf.b0
		a = v*xf.as+xf.a0
		result[i] = ARGB32(r,g,b,a)
	end
	return result
end
#Last line
