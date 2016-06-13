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
const GRID_MANTSTEP_EXPOFFSET = [0, 0, -1, 0, 0] #Ensure all significant digits show up.
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
	scale::AxisScale #Changes how tick labels are displayed
	major::Vector{DReal}
	minor::Vector{DReal}
	rnginfo::RangeDisplayInfo
end
GridLines(scale::AxisScale) = GridLines(scale, [], [], NoRangeDisplayInfo())

type UndefinedGridLines <: AbstractGridLines
	minline::DReal
	maxline::DReal
end

abstract PlotGrid

type GridSmith <: PlotGrid
	zgrid::Bool #Set to false for Y (admittance)-grid (x -> -x)
	ref::Float64 #Scaling factor
	majorR::Vector{DReal} #Major constant resistance/admittance circles
	minorR::Vector{DReal} #Minor constant resistance/admittance circles
	minorX::Vector{DReal} #Minor constant reactance circles
	labelR::Vector{DReal}
	labelX::Vector{DReal}
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
	#TODO: Rounding errors in calculation of major cause display issues with tick labels

	lstep = log10(tgtstep)
	ilstep = floor(Int, lstep)
	stepexp = 10.0^(ilstep)
	stepmant = tgtstep / stepexp

	istep = length(GRID_MANTSTEPS)
	for i in 1:length(GRID_MANTTHRESH)
		thresh = GRID_MANTTHRESH[i]
		if stepmant < thresh
			istep = i
			break
		end
	end

	mstep = GRID_MANTSTEPS[istep]
	expoffset = GRID_MANTSTEP_EXPOFFSET[istep]
	tgtminor = clamp(tgtminor, 0, 9)
	major = mstep*stepexp
	minor = major
	if tgtminor > 0
		minor /= GRID_MINORDIV[istep, tgtminor]
	end

	return (major, minor, expoffset)
end

#Compute grid line configuration for a linear scale (dB scale is basically linear as well)
#tgtmajor: Targeted number of major grid lines
#tgtminor: Targeted number of minor grid lines
function gridlines(scale::AxisScale, min::DReal, max::DReal; tgtmajor::DReal=3.5, tgtminor::Int=4)
	if !isfinite(min) || !isfinite(max)
		return UndefinedGridLines(min, max)
	elseif abs(max - min) == 0 #TODO: specify Δmin?
		return UndefinedGridLines(min, max)
	end

	grd = GridLines(scale)
	span = max - min

	#Compute major grid lines:
	tgtstep = span / (tgtmajor+1)
	(stepmajor, stepminor, expoffset) = linearstep_pretty(tgtstep, tgtminor)
	major1 = ceil(Int, min/stepmajor)*stepmajor
	grd.major = collect(major1:stepmajor:max)
	grd.rnginfo = LinearRangeDisplayInfo(
		base10exp(major1), base10exp(grd.major[end]),
		base10exp(stepmajor) + expoffset
	)

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

#Compute grid line configuration for a log10 scale
#Ignore keywords
function gridlines(scale::AxisScale{:log10}, logmin::DReal, logmax::DReal; kwargs...)
	if !isfinite(logmin) || !isfinite(logmax)
		return UndefinedGridLines(logmin, logmax)
	elseif abs(logmax - logmin) == 0 #TODO: specify Δmin?
		return UndefinedGridLines(logmin, logmax)
	end
	grd = GridLines(scale)

	major1 = ceil(Int, logmin)
	majorend = floor(Int, logmax)
	grd.major = collect(major1:1:majorend)

	offsets = collect(log10(2:1:9))

	if length(grd.major) > 0
		minor = (grd.major[1]-1)+offsets

		for curline in grd.major
			append!(minor, curline+offsets)
		end

		#Strip out values beyond specified range:
		istart = 1; iend = 0
		for i in 1:length(minor)
			if minor[i] < logmin
				istart = i+1
			end
			if minor[i] < logmax
				iend = i
			end
		end

		grd.minor = minor[istart:iend]
	end

	return grd
end

#Compute grid line configuration for a log2 scale
function gridlines(scale::AxisScale{:log2}, min::DReal, max::DReal)
	return GridLines(scale)
end


#==High-level interface
===============================================================================#
function gridlines(axes::AxesRect, ext::PExtents2D)
	#TODO: make tgtmajor/tgtminor programmable
	xlines = gridlines(axes.xscale, ext.xmin, ext.xmax, tgtmajor=3.5)
	ylines = gridlines(axes.yscale, ext.ymin, ext.ymax, tgtmajor=8.0, tgtminor=2)
	return GridRect(xlines, ylines)
end

function gridlines(axes::AxesSmith, ext::PExtents2D)
	const labelbase = DReal[0.2, 0.4, 0.6, 2, 4, 10]
	const minorextra = DReal[0.8, 1.5, 3, 6, 20]
	#TODO: make grid lines user-selectable
	#TODO: change with ext??
	majorR = DReal[0, 1]
	minorR = vcat(labelbase, minorextra)
	minorX = vcat(labelbase, minorextra, DReal[1])
	labelR = vcat(labelbase, DReal[0, 1])
	labelX = vcat(labelbase, DReal[1, 0.8, 1.5])

	zgrid = isa(axes, AxesSmith{:Z})
	return GridSmith(zgrid, axes.ref, majorR, minorR, minorX, labelR, labelX)
end

#Last line
