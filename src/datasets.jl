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

#Optimized for functions of 1 argument (F1-acceleration):
#    xres_max: Max number of x-points in data window.
#returns: Vector{Point2D}
function _reduce(input::IDataset{true}, ext::PExtents2D, xres_max::Integer)
	const xres = (ext.xmax - ext.xmin)/ xres_max
	const min_lookahead = 3 #number of xres windows to potentially collapse
	const thresh_xres = min_lookahead*xres #maximum x-distance to look ahead for reduction
	x = input.x; y = input.y
	n_ds = length(x) #numer of points of input dataset
	#FIXME: improve algorithm
	#Algorithm succeptible to cumulative errors (esp w large x-values & large xres_max):
	sz = min(n_ds, xres_max)+1+2*min_lookahead #Allow extra points in case
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
	prevx = x[i]; prevy = y[i]
	n+=1
	result[n] = Point2D(prevx, prevy)
	i+=1

	while i <= n_ds
		if prevx >= ext.xmax; break; end
		xthresh = min(prevx+thresh_xres, ext.xmax)
		ilahead_start = i+(min_lookahead-1) #If we consolidate, must at least reach here
		ilahead = min(ilahead_start, n_ds)
		while ilahead < n_ds
			if x[ilahead] >= xthresh; break; end
			ilahead += 1
		end

		#@assert(ilahead<=nds)

		if ilahead > ilahead_start #More data points than xres allows
			#TODO: make this a function??
			#final point of the data-reduced window:
			ifin = ilahead-1 #ilahead is now beyond minimum xres window
			pfin = Point2D(x[ifin], y[ifin])

			#Find smallest/largest y-value (before/after xres window):
			(ymin, ymax) = minmax(prevy, pfin.y)

			#Add points representing "internal limits"
			#(if they exceed external):
			ywnd = view(y, i:ifin) #y-window ~within 1 xres.
			i_ymin = i-1+indmin(ywnd); i_ymax = i-1+indmax(ywnd)
			ymin_wnd = y[i_ymin]; ymax_wnd = y[i_ymax]
			xint = [x[i_ymin], x[i_ymax]]
			yint = [ymin_wnd, ymax_wnd]
			ysel = Bool[false, false]
			ysel[1] = ymin_wnd < ymin #Don't display twice
			ysel[2] = ymax_wnd > ymax #Don't display twice
#ysel = Bool[true, true] #Debug: add points no matter what
#@show ilahead-i
			#offset: Decide whether to display min or max first - improves look of minres "glitch"
			offset = prevy < pfin.y ?0 :1 #Depending if trend is increasing or decreasing
			for j in (offset+(1:2))
				idx = 1+(j&0x1)
				if !ysel[idx]; continue; end #Only add points if desired
				n+=1;
				result[n] = Point2D(xint[idx],yint[idx])
			end
			#Done adding points

			prevx = pfin.x; prevy = pfin.y
			n+=1;
			result[n] = Point2D(prevx, prevy)
			i = ilahead
		else #Plot actual data points
			while i <= ilahead
				n += 1
				prevx = x[i]
				prevy = y[i]
				result[n] = Point2D(prevx, prevy)
				i += 1
			end
		end
	end

	resize!(result, n)
	return result
end

#Last line
