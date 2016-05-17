#InspectDR: Compute grid/tick locations
#-------------------------------------------------------------------------------

#==Constants
===============================================================================#
#TODO: make the following user-configurable:
const GRID_MAJOR_WIDTH = Float64(2)
const GRID_MINOR_WIDTH = Float64(1)
const GRID_MAJOR_COLOR = RGB24(.7, .7, .7)
const GRID_MINOR_COLOR = RGB24(.7, .7, .7)
const TICK_MAJOR_LEN = Float64(5)
const TICK_MINOR_LEN = Float64(3)


#Allowed mantissa values for grid step size:
const GRID_MANTSTEPS = DReal[1, 2, 2.5, 5, 10]
const GRID_MANTTHRESH = (GRID_MANTSTEPS[1:end-1] + GRID_MANTSTEPS[2:end]) / 2

#Maps desired # of minor grid lines to optimal divisor for each possibility in GRID_MANTSTEPS
#TODO: Figure out algorithmically?
#GRID_MINORDIV[index(GRID_MANTSTEPS), DESIRED_NUMBER_OF_MINOR_GRIDLINES]
#NOTE: dividing major step size by 5 gives 4 grid lines (off-by-one)
const GRID_MINORDIV = DReal[
#	1  2  3  4  5  6  7  8  9  - desired # of grid lines
	2  2  4  5  5  5  10 10 10; #1
	2  2  4  4  4  8  8  8  10; #2
	1  1  5  5  5  5  10 10 10; #2.5
	2  2  5  5  5  5  10 10 10; #5
	2  2  4  5  5  5  10 10 10; #10 (matches 1)
]


#==Types
===============================================================================#

abstract AbstractGridLines

#Identifies where to place ticks/grid lines
type GridLines <: AbstractGridLines
	first_significant_digit::Int #Relative to most-significant
	major::Vector{DReal}
	minor::Vector{DReal}
end
GridLines() = GridLines(1,[],[])

type UndefinedGridLines <: AbstractGridLines
	minline::DReal
	maxline::DReal
end

abstract PlotGrid

type GridSmith <: PlotGrid
end

#Curvilinear grid (ex: polar plots):
type GridCurv <: PlotGrid
end

#Rectilinear grid (ex: normal cartesian +logarithmic, ...):
type GridRect <: PlotGrid
	xlines::AbstractGridLines
	ylines::AbstractGridLines
end


#==Main algorithm
===============================================================================#

#Generate grid step size resulting in pretty tick labels
#tgtminor: Targeted number of minor grid lines/ticks
function linearstep_pretty(tgtstep::DReal, tgtminor::Int)
	lstep = log10(tgtstep)
	ilstep = floor(Int, lstep)
	stepexp = 10.0^(ilstep)
	stepmant = tgtstep / stepexp

	mstep = GRID_MANTSTEPS[end]
	istep = length(GRID_MANTSTEPS)
	for i in 1:length(GRID_MANTTHRESH)
		thresh = GRID_MANTTHRESH[i]
		if stepmant < thresh
			istep = i
			mstep = GRID_MANTSTEPS[i]
			break
		end
	end

	tgtminor = clamp(tgtminor, 0, 9)
	major = mstep*stepexp
	minor = major
	if tgtminor > 0
		minor /= GRID_MINORDIV[istep, tgtminor]
	end

	return (major, minor)
end

#Compute grid line configuration for a linear scale
#tgtmajor: Targeted number of major grid lines
#tgtminor: Targeted number of minor grid lines
function gridlines_linear(min::DReal, max::DReal; tgtmajor::DReal=3.5, tgtminor::Int=4)
	if !isfinite(min) || !isfinite(max)
		return UndefinedGridLines(min, max)
	elseif abs(max - min) == 0 #TODO: specify Δmin?
		return UndefinedGridLines(min, max)
	end

	grd = GridLines()
	span = max - min

	#Compute major grid lines:
	tgtstep = span / (tgtmajor+1)
	(stepmajor, stepminor) = linearstep_pretty(tgtstep, tgtminor)
	major1 = ceil(Int, min/stepmajor)*stepmajor
	grd.major = collect(major1:stepmajor:max)

	#Compute minor grid lines:
	minor1 = ceil(Int, min/stepminor)*stepminor
	minorall = minor1:stepminor:max


	#Throw away major points...
	#Yuk... is there not a more elegant solution?
	major_i1 = round(Int, abs(major1-minor1) / stepminor)+1 #Index of first major grid line
	major_ipitch = round(Int, abs(stepmajor/stepminor)) #Index pitch for major grid lines
	npts = length(minorall)
	if major_i1 <= npts
		nredundant = div(npts-major_i1, major_ipitch)+1
		npts = npts-nredundant
	else #Just in case
		npts = 0
	end
	grd.minor = Array(DReal, npts)

	nextmajor = major_i1
	j = 1
	for i in 1:length(minorall)
		if nextmajor == i
			nextmajor += major_ipitch
		else
			grd.minor[j] = minorall[i]
			j+=1
		end
	end

	return grd
end

#TODO: 
#Compute grid line configuration for a log10 scale
function gridlines_log10(min::DReal, max::DReal)
end

#Compute grid line configuration for a log2 scale
function gridlines_log2(min::DReal, max::DReal)
end


#Last line
