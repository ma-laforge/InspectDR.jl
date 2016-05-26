#InspectDR: Operation on datasets
#-------------------------------------------------------------------------------

#==Types declarations
===============================================================================#

#Input dataset data:
#TODO: make x an immutable (read-only) type so data cannot be changed once identified.
type IDataset{DATAF1} #DATAF1::Bool: Data is function of 1 argument (optimization possible)
	x::Vector
	y::Vector
end


#==Accessors
===============================================================================#

Point(ds::IDataset, i::Int) = Point2D(ds.x[i], ds.y[i])
Point(ds::Vector{Point2D}, i::Int) = ds[i]

#TODO: Specialize for sorted datasets?
function getextents(ds::IDataset)
	(xmin, xmax) = extrema_nan(ds.x)
	(ymin, ymax) = extrema_nan(ds.y)
	return PExtents2D(xmin, xmax, ymin, ymax)
end


#==Pre-processing display data
===============================================================================#

#_reduce: Obtain reduced dataset by limiting to the extents & max resolution:
#-------------------------------------------------------------------------------
#Generic algorithm... Just transfer all data for now
#    xres_max: Max number of x-points in data window.
#returns: Vector{Point2D}
#TODO: clip data beyond extents.
#WARNING: not clipping might cause display issues when applying the transform
function _reduce(input::IDataset, ext::PExtents2D, xres_max::Integer)
	x = input.x; y = input.y
	n_ds = length(x) #numer of points of input dataset
	result = Array(Point2D, n_ds)
	for i in 1:n_ds
		result[i] = Point2D(x[i], y[i])
	end
	return result
end

#Optimized for functions of 1 argument:
#    xres_max: Max number of x-points in data window.
#returns: Vector{Point2D}
function _reduce(input::IDataset{true}, ext::PExtents2D, xres_max::Integer)
	xres = (ext.xmax - ext.xmin)/ xres_max
	const min_lookahead = 2
	const thresh_xres = (min_lookahead+1)*xres
	x = input.x; y = input.y
	n_ds = length(x) #numer of points of input dataset
	sz = min(n_ds, xres_max)+4 #Add 4 pts, just in case (TODO: fix)
	result = Array(Point2D, sz)
	n = 0 #Number of points in reduced dataset
	i = 1 #Index into input dataset

	if length(x) != length(y)
		error("x & y - vector length mismatch.")
	elseif length(x) < 1
		resize!(result, 0)
		return result
	end

	#Discard data before visible extents:
	while i < n_ds
		if x[i] > ext.xmin; break; end
		i+=1
	end

	i = max(i-1, 1)
	lastx = x[i]
	lasty = y[i]
	n+=1
	result[n] = Point2D(lastx, lasty)
	i+=1

	while i <= n_ds
		if lastx >= ext.xmax; break; end
		xthresh = min(lastx+thresh_xres, ext.xmax)
		ilahead_start = i+min_lookahead
		ilahead = min(ilahead_start, n_ds)
		while ilahead < n_ds
			if x[ilahead] >= xthresh; break; end
			ilahead += 1
		end

		#@assert(ilahead<=nds)

		if ilahead > ilahead_start #More data than xres allows
			#TODO: make this a function??
			#"Internal limits":
			(ymin_i, ymax_i) = extrema(y[i:(ilahead-1)])
			p1 = Point2D(x[ilahead-1], y[ilahead-1])
			p2 = Point2D(x[ilahead], y[ilahead])
			nexty = interpolate(p1, p2, xthresh)

			#"External limits:
			(ymin, ymax) = minmax(lasty, nexty)

			#Add points representing "internal limits"
			#(if they exceed external):
			yint = [ymin_i, ymax_i]
			ysel = Bool[false, false]
			ysel[1] = ymin_i < ymin
			ysel[2] = ymax_i > ymax
#ysel = Bool[true, true] #Debug: add points no matter what
			curx = lastx + 1.5*xres #TODO: resize to have steps of 1xres?
#@show ilahead-i
			offset = lasty < nexty ?0 :1 #Add min or max first??
			for j in (offset+(1:2))
				idx = 1+(j&0x1)
				if !ysel[idx]; continue; end #Only add points if desired
				n+=1;
				result[n] = Point2D(curx,yint[idx])
			end
			#Done adding points

			n+=1;
			lastx = xthresh
			lasty = nexty
			result[n] = Point2D(lastx, lasty)
			i = ilahead
		else #Plot actual data points
			while i <= ilahead
				n += 1
				lastx = x[i]
				lasty = y[i]
				result[n] = Point2D(lastx, lasty)
				i += 1
			end
		end
	end

	resize!(result, n)
	return result
end

#Last line
