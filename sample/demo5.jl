#Demo 5: Logy plots
#-------------------------------------------------------------------------------
using InspectDR
using Colors

#==Input
===============================================================================#

#Constants
#-------------------------------------------------------------------------------
black = RGB24(0, 0, 0)
white = RGB24(1, 1, 1)
red = RGB24(1, 0, 0)
green = RGB24(0, 1, 0)
blue = RGB24(0, 0, 1)

default_line = line(color=blue, width=3)


#Input data
#-------------------------------------------------------------------------------
x = collect(1.0:1.0:100.0)
b = 2.0 #Base
k = 0.2 #Exponential coefficient


#==Generate plot
===============================================================================#
mplot = InspectDR.Multiplot(title="Log-Y Tests")
mplot.ncolumns = 1

plot = add(mplot, InspectDR.Plot2D)
	push!(plot.strips, InspectDR.GraphStrip()) #Add a new strip
	strip_liny, strip_logy = plot.strips

	a = plot.annotation
		a.title = "y = $b^($(k)x)"
		a.xlabel = "x"
		a.ylabels = ["y", "y"]

	#Define extents & scales:
	plot.xscale = InspectDR.AxisScale(:lin)
	strip_liny.yscale = InspectDR.AxisScale(:lin)
	strip_logy.yscale = InspectDR.AxisScale(:log10)
	strip_logy.grid = InspectDR.GridRect(vmajor=true, hmajor=true, hminor=true)

for i in 1:length(plot.strips)
	wfrm = add(plot, x, b.^(k*x), strip=i)
		wfrm.line = default_line
end

gplot = display(InspectDR.GtkDisplay(), mplot)

:DONE
