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

function extrema_nan(v::Vector)
	try
		return extrema(v)
	end
	return (DNaN, DNaN)
end

#TODO: Specialize for sorted datasets?
function getextents(ds::IDataset)
	(xmin, xmax) = extrema_nan(ds.x)
	(ymin, ymax) = extrema_nan(ds.y)
	return PExtents2D(xmin, xmax, ymin, ymax)
end
getextents(d::IWaveform) = getextents(d.ds)

function getextents(dlist::Vector{IWaveform})
	result = PExtents2D(DNaN, DNaN, DNaN, DNaN)
	for d in dlist
		result = union(result, d.ext)
	end
	return result
end

#Last line
