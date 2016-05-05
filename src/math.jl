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
	prev = v[1]
	for x in v[2:end]
		if x <= prev
			return false
		end
	end
	return true
end

isincreasing(r::Range) = (step(r) > 0)

#Last line
