#InspectDR: Basic math operations
#-------------------------------------------------------------------------------
#=NOTE:
These tools should eventually be moved to a separate unit.
=#


#==Useful tests
===============================================================================#

#Verifies that v is strictly increasing (no repeating values):
#TODO: support repeating values (non-strict)
function isincreasing(v::Vector)
	if length(v) < 1; return true; end
	prev = v[1]

	for x in v[2:end]
		if !(x > prev) #Make sure works for NaN
			return false
		end
	end
	return true
end

isincreasing(r::AbstractRange) = (step(r) > 0)

#==Basic operations
===============================================================================#

#Safe version of extrema (returns DNaN on error):
#Also ignores NaNs.  TODO: optimize?
function extrema_nan(v::Vector)
	vmin = DInf; vmax = -DInf
	for elem in v
		if !isnan(elem)
			if elem > vmax
				vmax = elem
			end
			if elem < vmin
				vmin = elem
			end
		end
	end
	if vmin>vmax
		vmin = vmax = DNaN
	end
	return (vmin, vmax)
end

#Finds the finite extents of a vector.
#Returns infinite extents if none are found.
#TODO: optimize?
function extents_finite(v::Vector)
	vmin = DInf; vmax = -DInf
	vmin_inf = DInf; vmax_inf = -DInf
	for elem in v
		if isfinite(elem)
			if elem > vmax
				vmax = elem
			end
			if elem < vmin
				vmin = elem
			end
		elseif isinf(elem)
			if elem > vmax_inf
				vmax_inf = elem
			end
			if elem < vmin_inf
				vmin_inf = elem
			end
		end
	end
	if vmin>vmax #Did not find finite values
		vmin = vmin_inf; vmax = vmax_inf

		if vmin>vmax #Did not even find infinite values
			vmin = vmax = DNaN
		end
	end
	return (vmin, vmax)
end

#Last line
