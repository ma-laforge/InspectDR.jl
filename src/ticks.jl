#InspectDR: Compute tick locations
#-------------------------------------------------------------------------------

#==Constants
===============================================================================#
const MANT_STEPS = DReal[1, 2, 2.5, 5, 10]
const MANT_THRESH = (MANT_STEPS[1:end-1] + MANT_STEPS[2:end]) / 2

#Maps desired # of minor ticks to optimal divisor for each possibility in MANT_STEPS
#TODO: Figure out algorithmically?
#MINOR_TICKS_DIV[index(MANT_STEPS), DESIRED_NUM_TICKS]
#NOTE: dividing major step size by 5 gives 4 ticks (off-by-one)
const MINOR_TICKS_DIV = DReal[
#	1  2  3  4  5  6  7  8  9  - desired # of ticks
	2  2  4  5  5  5  10 10 10; #1
	2  2  4  4  4  8  8  8  10; #2
	1  1  5  5  5  5  10 10 10; #2.5
	2  2  5  5  5  5  10 10 10; #5
	2  2  4  5  5  5  10 10 10; #10 (matches 1)
]


#==Types
===============================================================================#

#Identifies where to place ticks
type Ticks
	first_significant_digit::Int #Relative to most-significant
	major::Vector{DReal}
	minor::Vector{DReal}
end
Ticks() = Ticks(1,[],[])


#==Main algorithm
===============================================================================#

#TODO: Remove dummy algorithm
function ticks_linear1(min::DReal, max::DReal; kwargs...)
	ticks = Ticks()

	idx = 0:10
	ticks.major = min + (max-min) * (idx/10)
	return ticks
end

#Compute pretty step sizer for a given tick
#tgtminor: Targeted number of minor ticks
function step_pretty(tgtstep::DReal, tgtminor::Int)
	lstep = log10(tgtstep)
	ilstep = floor(Int, lstep)
	stepexp = 10.0^(ilstep)
	stepmant = tgtstep / stepexp

	mstep = MANT_STEPS[end]
	istep = length(MANT_STEPS)
	for i in 1:length(MANT_THRESH)
		thresh = MANT_THRESH[i]
		if stepmant < thresh
			istep = i
			mstep = MANT_STEPS[i]
			break
		end
	end

	tgtminor = clamp(tgtminor, 0, 9)
	major = mstep*stepexp
	minor = major
	if tgtminor > 0
		minor /= MINOR_TICKS_DIV[istep, tgtminor]
	end

	return (major, minor)
end

#Compute tick configuration for a linear scale
#tgtmajor: Targeted number of major ticks
#tgtminor: Targeted number of minor ticks
function ticks_linear2(min::DReal, max::DReal; tgtmajor::DReal=3.5, tgtminor::Int=4)
	ticks = Ticks()
	span = max - min

	#Compute major ticks:
	tgtstep = span / (tgtmajor+1)
	(stepmajor, stepminor) = step_pretty(tgtstep, tgtminor)
	tick1 = ceil(Int, min/stepmajor)*stepmajor
	nsteps = trunc(Int, (max-tick1)/stepmajor)
	ticks.major = tick1 + stepmajor * (0:nsteps)

	#Compute minor ticks:
	tick1 = ceil(Int, min/stepminor)*stepminor
	nsteps = trunc(Int, (max-tick1)/stepminor)
	ticks.minor = tick1 + stepminor * (0:nsteps)

	return ticks
end
ticks_linear(min::DReal, max::DReal; kwargs...) = ticks_linear2(min, max; kwargs...)

#TODO: 
#Compute tick configuration for a log10 scale
function ticks_log10(min::DReal, max::DReal)
end

#Compute tick configuration for a log2 scale
function ticks_log2(min::DReal, max::DReal)
end


#Last line
