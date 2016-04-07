#datasetop.jl: 
#-------------------------------------------------------------------------------

function union(e1::PExtents2D, e2::PExtents2D)
	return PExtents2D(
		min(e1.xmin, e2.xmin),
		max(e1.xmax, e2.xmax),
		min(e1.ymin, e2.ymin),
		max(e1.ymax, e2.ymax),
	)
end

#TODO: Specialize for sorted datasets?
function PExtents2D(d::IWaveform)
	ds = d.ds
	(xmin, xmax) = extrema(ds.x)
	(ymin, ymax) = extrema(ds.y)
	return PExtents2D(xmin, xmax, ymin, ymax)
end

function PExtents2D(dlist::Vector{IWaveform})
	result = PExtents2D(DNaN, DNaN, DNaN, DNaN)
	for d in dlist
		result = union(result, PExtents2D(d))
	end
	return result
end

#Last line
