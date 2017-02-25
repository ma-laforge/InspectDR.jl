#InspectDR: Store/manipulate info about graph bounds, scales, ...
#-------------------------------------------------------------------------------


#==Main types
===============================================================================#

#"Evaluated" information about all strips:
#(Cache for bounds, current extents, text formatting, transforms, etc)
type StripInfo
	graphbb::BoundingBox #Location of graph (device units)
	yfmt::TickLabelFormatting #y tick label formatting
	yixf::InputXfrm1DSpec #Input transform for y-values
	xf::Transform2D #Transform used to render data
	#TODO: axis scaling, ...?
end
StripInfo() = StripInfo([], [], [])


#"Evaluated" information about all graphs on a plot:
#(Cache for bounds, current extents, text formatting, transforms, etc)
type Graph2DInfo
#TODO: store BoundingBox for entire plot??
#TODO: store extents???
	xfmt::TickLabelFormatting #x tick label formatting
	xixf::InputXfrm1DSpec #Input transform for x-values
	strips::Vector{StripInfo}
end


#==Constructor-like functions
===============================================================================#
function Graph2DInfo(plot::Plot2D)
	xfmt = TickLabelFormatting(NoRangeDisplayInfo())
	if length(plot.strips) > 0
		istrip = 1
		strip = plot.strips[istrip]
		ext = getextents_axis(plot, istrip)
		#Get the rectangular coordinate grid:
		grid = coord_grid(strip.grid, plot.xscale, strip.yscale, ext)
		if !isa(grid.xlines, UndefinedGridLines)
			xfmt = TickLabelFormatting(plot.layout.xlabelformat, grid.xlines.rnginfo)
		end
	end
	return Graph2DInfo(xfmt, InputXfrm1DSpec(plot.xscale), [])
end

#bb: bounding box of entire plot
function Graph2DInfo(plot::Plot2D, bb::BoundingBox)
	const dfltfmt = TickLabelFormatting(NoRangeDisplayInfo())
	result = Graph2DInfo(plot)
	databb = databounds(bb, plot.layout, grid1(plot))
	nstrips = length(plot.strips)
	graphbblist = graphbounds_list(databb, plot.layout, nstrips)
	resize!(result.strips, nstrips)

	for istrip in 1:nstrips #Compute x/y label formats:
		strip = plot.strips[istrip]
		graphbb = graphbblist[istrip]
		ext = getextents_axis(plot, istrip)
		grid = coord_grid(strip.grid, plot.xscale, strip.yscale, ext)
		yfmt = dfltfmt
		if !isa(grid.ylines, UndefinedGridLines)
			yfmt = TickLabelFormatting(plot.layout.ylabelformat, grid.ylines.rnginfo)
		end
		result.strips[istrip] = StripInfo(graphbb, yfmt,
			InputXfrm1DSpec(strip.yscale),
			Transform2D(ext, graphbb)
		)
	end
	return result
end
#Want to define/use coord_grid when displaying coordinates???
#Or maybe we deprecate coord_grid???


#==Accessors
===============================================================================#
Transform2D(ginfo::Graph2DInfo, istrip::Int) = ginfo.strips[istrip].xf
InputXfrm2D(ginfo::Graph2DInfo, istrip::Int) =
	InputXfrm2D(ginfo.xixf, ginfo.strips[istrip].yixf)


#==Helper functions
===============================================================================#
#Get numeric formatting/precision with mouse hover:
function hoverfmt(fmt::TickLabelFormatting)
	result = deepcopy(fmt.fmt)
	#Display a bit more precision than tick labels:
	result.ndigits += 2 #TODO: Better algorithm?
	return result
end


#==Main functions
===============================================================================#
#TODO: move some of the computations from base.jl here?

#Last line
