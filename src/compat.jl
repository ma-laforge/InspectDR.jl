#InspectDR: Compatibility check
#-------------------------------------------------------------------------------


#Check compatibility with Plots.jl:
function checkcompat_plots()
	const compatinfomsg = "See NEWS.md for more details on compatibility."

	#InspectDR => latest compatible version Plots.jl:
	#Keep updating latest known version of InspectDR/Plots.jl.
	const compatlist = Dict(
		#v"0.1.3" => v"0.10.3",
		#Keep old versions in code (above) just for reference.
		#(Never suggest older versions)

		v"0.1.7" => v"0.11.2",
		#Reminder for tagged releases:
			#Update InspectDR version / Latest version of Plots.jl.
	)
	const inspectverkeys = sort(collect(keys(compatlist)))

	function compatstr(vinspect::VersionNumber)
		vplots = compatlist[vinspect]
		return "Plots $vplots => InspectDR $vinspect"
	end

	vPlots = nothing
	vInspect = nothing

	try
		#Adds to load up time... try not to do this...
		vPlots = Pkg.installed("Plots")
	end
	try
		#Adds to load up time... try not to do this...
		vInspect = Pkg.installed("InspectDR")
	end

	#Debug:
#	vPlots = nothing #Assume not installed
#	vPlots = v"0" #small
#	vPlots = v"15" #Large
#	vInspect = v"0.1.4"
#	vInspect = nothing #Unknown

	if nothing == vPlots
		return #No compatibility issues
	elseif nothing == vInspect
		msg  = "Unable to determine compatibility with Plots.jl: Unknown version of InspectDR.\n\n"
		msg *= "Latest known compatible versions:\n"
		msg *= "    " * compatstr(inspectverkeys[end]) * ".\n"
		msg *= compatinfomsg
		info(msg)
		return
	end

	ifirst = findfirst(v->(v >= vInspect), inspectverkeys)
	if ifirst < 1
		#This version appears newer than latest known compatible....
		lastknowncompat = inspectverkeys[end]
		msg  = "InspectDR not known to be compatible with current version of Plots.jl.\n\n"
		msg *= "Latest known compatible versions:\n"
		msg *= "    " * compatstr(lastknowncompat) * ".\n"
		msg *= "If difficulties occur, you can pin to an older version:\n"
		msg *= "    julia> Pkg.pin(\"InspectDR\", v\"$lastknowncompat\")\n"
		msg *= "...don't forget to free to enable future updates:\n"
		msg *= "    julia> Pkg.free(\"InspectDR\")\n"
		msg *= compatinfomsg
		info(msg)
	else
		#InspectDR version probably not smaller than latest known good (so probably equal)...
		#Don't bother user for no reason.
		#If Plots.jl is no longer compatible: hope Pkg.update() to fix things...
	end

	nothing
end

#Last line
